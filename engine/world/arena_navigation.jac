"""Arena-specific goals and traversal; campaign monsters retain local pursuit."""
import math;
import from .world { World, Player }
import from .combat { Opponent, HasOpponent }
import from .bot_routes { NavMesh, HasNavMesh, reachable }
import from .pickups { Pickup, HasPickup, PickupTick }
import from .inventory { quantity }
import from .powerups { stored_kinds }
import from .traversal { Traversal, HasTraversal, ArrivesAt, Destination, TraversalTick }
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

# Which weapon each Q3 ammo type feeds.
glob AMMO_WEAPONS: dict[str, str] = {
    "bullets": "machinegun",
    "shells": "shotgun",
    "grenades": "grenadelauncher",
    "rockets": "rocketlauncher",
    "lightning": "lightning",
    "slugs": "railgun",
    "cells": "plasmagun",
    "bfg": "bfg"
};

"""Whether an item is worth a detour to a bot: health and armor it lacks,
powerups, a holdable when it has none, a weapon it does not own, and ammo for
a weapon it carries that is running low (the fw_items.c needs, simplified)."""
def bot_wants(bot: Opponent, kind: str, amount: int, holding: bool) -> bool {
    if kind == "health" {
        return bot.health < bot.max_health;
    }
    if kind == "armor" {
        return bot.armor < amount;
    }
    if kind == "powerup" {
        return True;
    }
    if kind.startswith("holdable_") {
        return not holding;
    }
    if kind.startswith("weapon_") {
        return quantity(bot.inventory, kind) <= 0;
    }
    if kind in AMMO_WEAPONS {
        return quantity(bot.inventory, "weapon_" + AMMO_WEAPONS[kind]) > 0
            and quantity(bot.inventory, kind) < 50;
    }
    return False;
}

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
            for key in self.cells(pickup.pos.sub(Vec3(x=32.0, y=32.0)), pickup.pos.add(Vec3(x=32.0, y=32.0))) {
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

# Build authored directed links once at level load. Jump-pad trajectories are
# checked against the live hull; actor movement still performs live collision.
def prepare_arena_links(world: World, collision: CollisionMap) {
    for portal in [world->:HasTraversal:->][?:Traversal] {
        if not portal.volume.bounds { continue; }
        center = portal.volume.bounds[0].center();
        floor = collision.trace(center.add(Vec3(z=48.0)), center.sub(Vec3(z=128.0)));
        if floor.start_solid or floor.fraction == 1.0 or floor.normal.z < 0.7 { continue; }
        portal.nav_entry = floor.end;
        if portal.kind == "teleport" {
            destinations = [portal->:ArrivesAt:->][?:Destination];
            if destinations { portal.nav_exit = destinations[0].origin; }
        } elif portal.kind == "push" {
            pos = floor.end;
            velocity = portal.velocity.add(Vec3());
            for i in range(360) {
                velocity.z -= 800.0 / 120.0;
                next_pos = pos.add(velocity.scale(1.0 / 120.0));
                hit = collision.trace(pos, next_pos);
                if hit.start_solid { break; }
                if hit.fraction < 1.0 {
                    if velocity.z < 0.0 and hit.normal.z >= 0.7 { portal.nav_exit = hit.end; }
                    break;
                }
                pos = next_pos;
            }
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
            for pickup in self.index.near_items(before, finish) {
                if not pickup.active or pickup.rule.kind not in ARENA_ITEM_KINDS { continue; }
                if contact_bounds(before, finish, AABB(
                    mins=pickup.pos.sub(Vec3(x=32.0, y=32.0, z=48.0)),
                    maxs=pickup.pos.add(Vec3(x=32.0, y=32.0, z=40.0))
                )) { items.append(pickup); }
            }
            if items {
                self.world spawn PickupTick(player=here, start=before, finish=finish,
                    dt=self.dt, advance_time=False, kinds=ARENA_ITEM_KINDS,
                    targets=items, selected_only=True);
            }
            return;
        }
        here.arena_origin = here.pos.sub(Vec3(z=here.eye_height));
        here.arena_goal_wait -= self.dt;
        if here.arena_goal_wait > 0.0 { return; }
        here.arena_goal_wait = 0.5;
        here.arena_goal = None;
        # Battle nodes steer to their own goals: a chase to where the enemy
        # was last seen, a nearby item grabbed mid-fight (Battle_NBG).
        battle = here.bot_state.battle;
        if battle == "chase" {
            here.arena_goal = here.bot_state.chase_target.add(Vec3());
            here.alert = max(here.alert, 1.0);
            return;
        }
        grab = here.bot_state.nearby_goal;
        if battle == "nbg" and grab is not None {
            here.arena_goal = grab.add(Vec3());
            here.alert = max(here.alert, 1.0);
            return;
        }
        retreating = battle == "retreat";
        target = here.last_seen;
        best = 1500.0;
        for pickup in self.pickups {
            if not pickup.active or pickup.waiting_for_use { continue; }
            kind = pickup.rule.kind;
            holding = any([quantity(here.inventory, held) > 0 for held in stored_kinds("q3")]);
            if not bot_wants(here, kind, pickup.rule.amount, holding) { continue; }
            mesh = self.mesh;
            if mesh is not None
                and not reachable(mesh, here.pos.sub(Vec3(z=here.eye_height)), pickup.pos) {
                continue;
            }
            distance = pickup.pos.sub(here.pos).length();
            # Powerups and new weapons outweigh an ongoing fight, as in the
            # bots' item weights.
            if kind == "powerup" { distance *= 0.5; }
            if kind.startswith("weapon_") { distance *= 0.6; }
            if distance < best
                and (
                    not here.pursuing
                        or retreating
                        or kind == "powerup"
                        or here.health < here.max_health // 2
                ) {
                best = distance;
                target = pickup.pos.add(Vec3(z=here.eye_height));
                here.arena_goal = target;
            }
        }
        # Like ai_dmq3.c long-term goals: with no enemy and nothing needed, head
        # for a distant item and pick another on arrival, so bots meet.
        if here.arena_goal is None and (not here.pursuing or retreating) {
            roam = here.roam_goal;
            if roam is not None and roam.sub(here.pos).length() < 96.0 {
                roam = None;
            }
            if roam is None {
                # With the map's AAS any item is a reachable long-term goal;
                # bounded ground routing only reaches nearby items, so hopping
                # between them carries a bot across the map.
                mesh = self.mesh;
                reach = 100000.0 if mesh is not None else 900.0;
                spots = [
                    pickup.pos.add(Vec3(z=here.eye_height))
                    for pickup in self.pickups
                    if not pickup.waiting_for_use
                        and pickup.pos.sub(here.pos).length() > 256.0
                        and pickup.pos.sub(here.pos).length() < reach
                ];
                if mesh is not None {
                    origin = here.pos.sub(Vec3(z=here.eye_height));
                    spots = [spot for spot in spots if reachable(mesh, origin, spot.sub(Vec3(z=here.eye_height)))];
                }
                if spots {
                    here.shot_random = (here.shot_random * 48271) % 2147483647;
                    roam = spots[here.shot_random % len(spots)];
                }
            }
            here.roam_goal = roam;
            if roam is not None {
                target = roam;
                here.arena_goal = roam;
            }
        }
        # Teleporters are directed connections. Choose one only when it improves
        # the remaining travel estimate; ground routing still validates its entry.
        direct = target.sub(here.pos).length();
        for portal in self.traversals {
            if not portal.enabled or portal.nav_entry is None or portal.nav_exit is None { continue; }
            entrance = portal.nav_entry.add(Vec3(z=here.eye_height));
            cost = entrance.sub(here.pos).length() + portal.nav_exit.add(Vec3(z=here.eye_height)).sub(target).length() + 64.0;
            if cost < direct {
                direct = cost;
                here.arena_goal = entrance;
            }
        }
        if here.arena_goal is not None { here.alert = max(here.alert, 1.0); }
    }
}
