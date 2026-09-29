"""Arena bots' contacts with items and teleporters and jump pads, and the
level's bot navigation set up at load: the jump pads' throws, the level items
bots aim for (bot_goals.jac) and their travel tables. Bots choose their goals
in their AI (bot_ai.jac)."""
import math;
import from .world { World, Player }
import from .combat { Opponent, HasOpponent }
import from .bot_routes { NavMesh, HasNavMesh }
import from .bot_goals { LevelItem, HasLevelItem, bot_items, add_level_item, floating_item, jump_pad_area }
import from .pickups { Pickup, HasPickup, PickupTick, touch_reach }
import from .traversal { Traversal, HasTraversal, TraversalTick }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

def contact_bounds(start: Vec3, finish: Vec3, bounds: AABB) -> bool {
    return max(start.x, finish.x) >= bounds.mins.x and min(start.x, finish.x) <= bounds.maxs.x
        and max(start.y, finish.y) >= bounds.mins.y and min(start.y, finish.y) <= bounds.maxs.y
        and max(start.z, finish.z) >= bounds.mins.z and min(start.z, finish.z) <= bounds.maxs.z;
}

glob ARENA_ITEM_KINDS: list[str] = [
    "health", "armor", "powerup", "holdable_medkit", "holdable_teleporter",
    "weapon_shotgun", "weapon_grenadelauncher", "weapon_rocketlauncher",
    "weapon_lightning", "weapon_railgun", "weapon_plasmagun", "weapon_bfg",
    "weapon_machinegun", "bullets", "shells", "grenades", "rockets", "lightning",
    "slugs", "cells", "bfg"
];

# Authored contacts are static; bucket membership is built once for each world.
# Entries hold live nodes, so pickup respawns and disabled portals remain current.
obj ArenaContactIndex {
    has world: World | None = None,
        pickups: list[Pickup] = [],
        portals: list[Traversal] = [],
        items: dict[str, list[Pickup]] = {},
        travels: dict[str, list[Traversal]] = {},
        serial: int = -1;

    def cells(lo: Vec3, hi: Vec3) -> list[str] {
        keys: list[str] = [];
        for x in range(int(math.floor(lo.x / 128.0)), int(math.floor(hi.x / 128.0)) + 1) {
            for y in range(int(math.floor(lo.y / 128.0)), int(math.floor(hi.y / 128.0)) + 1) {
                keys.append(str(x) + ":" + str(y));
            }
        }
        return keys;
    }
    def prepare(world: World) {
        # Dropped items come and go; the index is rebuilt when they do.
        if self.world is world and self.serial == world.item_serial { return; }
        self.world = world;
        self.serial = world.item_serial;
        self.pickups = [world->:HasPickup:->][?:Pickup];
        self.portals = [world->:HasTraversal:->][?:Traversal];
        self.items = {};
        self.travels = {};
        for pickup in self.pickups {
            if pickup.rule.kind not in ARENA_ITEM_KINDS { continue; }
            # Every cell a touching body's origin can be in (touch_reach
            # spans at most 64 either way across, Q1 health and ammo).
            for key in self.cells(pickup.pos.sub(Vec3(x=64.0, y=64.0)), pickup.pos.add(Vec3(x=64.0, y=64.0))) {
                if key not in self.items { self.items[key] = []; }
                self.items[key].append(pickup);
            }
        }
        for portal in self.portals {
            for bounds in portal.volume.bounds {
                for key in self.cells(bounds.mins, bounds.maxs) {
                    if key not in self.travels { self.travels[key] = []; }
                    if portal not in self.travels[key] { self.travels[key].append(portal); }
                }
            }
        }
    }
    def swept_cells(start: Vec3, finish: Vec3) -> list[str] {
        return self.cells(Vec3(x=min(start.x, finish.x), y=min(start.y, finish.y)),
            Vec3(x=max(start.x, finish.x), y=max(start.y, finish.y)));
    }
    def near_items(start: Vec3, finish: Vec3) -> list[Pickup] {
        result: list[Pickup] = [];
        for key in self.swept_cells(start, finish) {
            if key in self.items {
                for item in self.items[key] {
                    if item not in result { result.append(item); }
                }
            }
        }
        return result;
    }
    def near_portals(start: Vec3, finish: Vec3) -> list[Traversal] {
        result: list[Traversal] = [];
        for portal in self.portals {
            if not portal.volume.bounds { result.append(portal); }
        }
        for key in self.swept_cells(start, finish) {
            if key in self.travels {
                for portal in self.travels[key] {
                    if portal not in result { result.append(portal); }
                }
            }
        }
        return result;
    }
}

"""Set up the level's bot navigation as it loads: where each teleporter and
jump pad is entered (the floor under its trigger), the level items bots aim
for with their goal areas (be_ai_goal.c BotInitLevelItems; a floating item's
is the jump pad that throws a bot through it, AAS_BestReachableFromJumpPadArea)
and the travel tables to them, built now rather than in play."""
def prepare_arena_links(world: World, collision: CollisionMap) {
    for portal in [world->:HasTraversal:->][?:Traversal] {
        if not portal.volume.bounds { continue; }
        center = portal.volume.bounds[0].center();
        floor = collision.trace(center.add(Vec3(z=48.0)), center.sub(Vec3(z=128.0)));
        if floor.start_solid or floor.fraction == 1.0 or floor.normal.z < 0.7 { continue; }
        portal.nav_entry = floor.end;
    }
    meshes = [world->:HasNavMesh:->][?:NavMesh];
    items = bot_items(world);
    if not meshes or items is None or [items->:HasLevelItem:->] {
        return;
    }
    mesh = meshes[0];
    # AAS_GetJumpPadInfo: where each pad's throw starts, the throw as botlib
    # estimates it (the horizontal speed a tenth over the game's) and the
    # pad's area.
    pads: list[tuple[Vec3, Vec3, int]] = [];
    for portal in [world->:HasTraversal:->][?:Traversal] {
        start = portal.nav_entry;
        if portal.kind == "push" and start is not None {
            throw = Vec3(x=portal.velocity.x * 1.1, y=portal.velocity.y * 1.1, z=portal.velocity.z);
            pads.append((start, throw, mesh.locate(start)));
        }
    }
    for pickup in [world->:HasPickup:->][?:Pickup] {
        info = items.info_for(pickup.rule.classname);
        if pickup.dropped or info is None {
            continue;
        }
        pad = 0;
        if floating_item(collision, info, pickup.pos) {
            pad = jump_pad_area(collision, info, pickup.pos, pads);
            if pad == 0 {
                continue;
            }
        }
        add_level_item(items, pickup, mesh, collision, pad);
    }
    for item in [items->:HasLevelItem:->][?:LevelItem] {
        if item.goal_area != 0 {
            mesh.times_to(item.goal_area);
        }
    }
}

# Contacts use the shared gameplay walkers so teleport cooldowns, launch speeds,
# item capacities and pickup availability have one implementation.
walker ArenaNavigationTick {
    has collision: CollisionMap,
        dt: float,
        contacts: bool = False,
        index: ArenaContactIndex = ArenaContactIndex(),
        world: World | None = None,
        pickups: list[Pickup] = [],
        traversals: list[Traversal] = [],
        mesh: NavMesh | None = None,
        bystander: Player | None = None,
        bystander_height: float = 22.0;

    can begin with World entry {
        self.world = here;
        self.index.prepare(here);
        self.pickups = self.index.pickups;
        self.traversals = self.index.portals;
        meshes = [here->:HasNavMesh:->][?:NavMesh];
        self.mesh = meshes[0] if meshes else None;
        # Tables for new goals (dropped weapons, chased foes) build a budget
        # at a time, once per tick.
        if self.mesh is not None and not self.contacts {
            self.mesh.advance_tables();
        }
        visit [here->:HasOpponent:->];
    }

    can navigate with Opponent entry {
        if not here.arena or here.health <= 0 or here.dormant or self.world is None { return; }
        if self.contacts {
            origin = here.pos.sub(Vec3(z=here.eye_height));
            before = here.arena_origin;
            nearby: list[Traversal] = [];
            for portal in self.index.near_portals(before, origin) {
                if not portal.enabled { continue; }
                if not portal.volume.bounds { nearby.append(portal); continue; }
                for bounds in portal.volume.bounds {
                    if contact_bounds(before, origin, bounds) {
                        nearby.append(portal); break;
                    }
                }
            }
            traversal = self.world spawn TraversalTick(
                player=here, collision=self.collision.for_body(here.eye_height),
                start=before, dt=self.dt, targets=nearby, selected_only=True,
                bystander=self.bystander, bystander_height=self.bystander_height
            );
            if traversal.relocated {
                here.route = [];
                here.route_areas = [];
                here.route_launches = [];
                if here.route_search is not None { here.route_search.cancelled = True; here.route_search = None; }
                here.arena_goal = None;
                here.arena_goal_wait = 0.0;
                here.decision_wait = 0.0;
            }
            # Item timers are advanced once by the main world tick. Actor
            # contacts collect active items without advancing respawns.
            finish = here.pos.sub(Vec3(z=here.eye_height));
            if traversal.relocated { before = finish; }
            items: list[Pickup] = [];
            body_mins = self.collision.hull_mins;
            body_maxs = self.collision.hull_maxs;
            for pickup in self.index.near_items(before, finish) {
                if not pickup.active or pickup.rule.kind not in ARENA_ITEM_KINDS { continue; }
                reach = touch_reach(here.game, pickup.rule, body_mins, body_maxs);
                if contact_bounds(before, finish, AABB(
                    mins=pickup.pos.add(reach.mins), maxs=pickup.pos.add(reach.maxs)
                )) { items.append(pickup); }
            }
            if items {
                self.world spawn PickupTick(player=here, start=before, finish=finish,
                    dt=self.dt, game=here.game, body_mins=body_mins, body_maxs=body_maxs,
                    advance_time=False, kinds=ARENA_ITEM_KINDS, targets=items,
                    selected_only=True);
            }
            return;
        }
        here.arena_origin = here.pos.sub(Vec3(z=here.eye_height));
    }
}
