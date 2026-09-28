"""Q3 bot goals after be_ai_goal.c. Every item on the map a bot knows from
items.c is a `LevelItem` node under the world's `BotItems`, with the AAS area
a bot goes to for it (for an item floating in the air, the jump pad that
throws a bot through it). Items thrown by dying players join as level items
that time out after 30 seconds.

A bot picks items with its fuzzy item weights: BotChooseLTGItem rates every
level item it has seen by weight over travel time, skipping those it still
avoids (its last goals, until they respawn), and BotChooseNBGItem does the
same for items within a short detour. Both are `ChooseItemGoal` walks over the
level items. Goals are kept on the bot's goal stack (GoalState)."""
import math;
import from .world { World, Actor }
import from .pickups { Pickup, HasPickup }
import from .drops { in_flight }
import from .bot_routes { NavMesh, area_travel_time }
import from ..formats.aas { AREACONTENTS_WATER }
import from ..formats.botconfig { ItemInfo, WeightConfig, WeightDice }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

# be_ai_goal.c.
glob AVOID_MINIMUM_TIME: float = 10.0,
    AVOID_DEFAULT_TIME: float = 30.0,
    AVOID_DROPPED_TIME: float = 10.0,
    TRAVELTIME_SCALE: float = 0.01,
    DROPPED_WEIGHT: float = 1000.0,
    DROPPED_TIMEOUT: float = 30.0;

# be_ai_goal.h goal flags.
glob GFL_ITEM: int = 1,
    GFL_ROAM: int = 2,
    GFL_DROPPED: int = 4;

# aasfile.h AREACONTENTS_JUMPPAD: dropped items there are never goals.
glob AREACONTENTS_JUMPPAD_AREA: int = 128;

"""levelitem_t: an item bots know of. `linked` once its entity has been seen
(a powerup is no goal before it first appears); a dropped item's `timeout` is
the clock it is forgotten at."""
node LevelItem {
    has number: int,
        info: ItemInfo,
        pickup: Pickup,
        origin: Vec3,
        goal_area: int = 0,
        goal_origin: Vec3 = Vec3(),
        linked: bool = False,
        timeout: float = 0.0;
}

"""The level items and the clock their timeouts run on (AAS_Time)."""
node BotItems {
    has infos: list[ItemInfo] = [],
        clock: float = 0.0,
        serial: int = -1,
        next_number: int = 1;

    def info_for(classname: str) -> ItemInfo | None {
        for info in self.infos {
            if info.classname == classname {
                return info;
            }
        }
        return None;
    }
}

edge HasBotItems: World --> BotItems {}
edge HasLevelItem: BotItems --> LevelItem {}

def bot_items(world: World) -> BotItems | None {
    found = [world->:HasBotItems:->][?:BotItems];
    return found[0] if found else None;
}

"""bot_goal_t: where a bot is going, with the box it touches the goal in."""
obj BotGoal {
    has origin: Vec3,
        area: int,
        mins: Vec3 = Vec3(x=-8.0, y=-8.0, z=-8.0),
        maxs: Vec3 = Vec3(x=8.0, y=8.0, z=8.0),
        number: int = 0,
        flags: int = 0,
        item: LevelItem | None = None;
}

"""bot_goalstate_t: the goal stack and the goals to avoid, by level item
number, until a clock time."""
obj GoalState {
    has stack: list[BotGoal] = [],
        avoid: dict[int, float] = {},
        last_area: int = 0;

    def top() -> BotGoal | None {
        return self.stack[len(self.stack) - 1] if self.stack else None;
    }

    """BotGetSecondGoal."""
    def second() -> BotGoal | None {
        return self.stack[len(self.stack) - 2] if len(self.stack) > 1 else None;
    }

    def push(goal: BotGoal) {
        self.stack.append(goal);
    }

    def pop() {
        if self.stack {
            self.stack.pop();
        }
    }

    def empty() {
        self.stack = [];
    }

    """BotAvoidGoalTime: seconds the goal is still avoided."""
    def avoid_time(number: int, now: float) -> float {
        until = self.avoid.get(number, 0.0);
        return until - now if until >= now else 0.0;
    }

    """BotAddToAvoidGoals."""
    def add_avoid(number: int, seconds: float, now: float) {
        self.avoid[number] = now + seconds;
    }

    """BotResetAvoidGoals."""
    def reset_avoid() {
        self.avoid = {};
    }
}

"""How long a bot avoids an item it has gone for: the item's respawn time
(at least 10 s, 30 s when it has none), or 10 s for a dropped item."""
def item_avoid_time(item: LevelItem) -> float {
    if item.timeout > 0.0 {
        return AVOID_DROPPED_TIME;
    }
    respawn = item.info.respawntime if item.info.respawntime > 0.0 else AVOID_DEFAULT_TIME;
    return max(AVOID_MINIMUM_TIME, respawn);
}

"""A goal for a level item."""
def item_goal(item: LevelItem) -> BotGoal {
    return BotGoal(
        origin=item.goal_origin,
        area=item.goal_area,
        mins=item.info.mins,
        maxs=item.info.maxs,
        number=item.number,
        flags=GFL_ITEM | (GFL_DROPPED if item.timeout > 0.0 else 0),
        item=item
    );
}

"""AAS_BestReachableArea for a resting item: the area of a player's box
dropped from the item's origin to the floor (AAS areas hold player origins)."""
def resting_goal_area(mesh: NavMesh, collision: CollisionMap, origin: Vec3) -> tuple[int, Vec3] {
    floor = collision.trace(origin.add(Vec3(z=0.25)), origin.sub(Vec3(z=50.0)));
    spot = origin if floor.start_solid else floor.end;
    return (mesh.locate(spot), spot);
}

"""Whether an item floats clear of the ground: its box traced 32 units down
meets nothing (BotInitLevelItems' test for suspended items)."""
def floating_item(collision: CollisionMap, info: ItemInfo, origin: Vec3) -> bool {
    lowest = origin.add(Vec3(z=info.mins.z));
    floor = collision.trace_point(lowest, lowest.sub(Vec3(z=32.0)));
    return not floor.start_solid and floor.fraction >= 1.0;
}

"""be_ai_goal.c BotInitLevelItems: a level item for every item on the map
that items.c knows. A floating item's goal is the jump pad area that throws
a bot through it (`pad_areas`, from AAS_BestReachableFromJumpPadArea); one
no pad reaches is no goal."""
def add_level_item(items: BotItems, pickup: Pickup, mesh: NavMesh, collision: CollisionMap, pad_area: int) -> LevelItem | None {
    info = items.info_for(pickup.rule.classname);
    if info is None {
        return None;
    }
    item = LevelItem(number=items.next_number, info=info, pickup=pickup, origin=pickup.pos.add(Vec3()));
    items.next_number += 1;
    if pad_area > 0 {
        item.goal_area = pad_area;
        item.goal_origin = pickup.pos.add(Vec3());
    } else {
        found = resting_goal_area(mesh, collision, pickup.pos);
        item.goal_area = found[0];
        item.goal_origin = found[1];
    }
    items +>:HasLevelItem:+> item;
    return item;
}

"""be_ai_goal.c BotUpdateEntityItems, run as items come and go: a map item is
linked to its entity once that is present; a newly thrown item that has come
to rest becomes a level item for 30 seconds (unless it lies on a jump pad),
and timed-out ones are dropped."""
walker UpdateLevelItems {
    has mesh: NavMesh,
        collision: CollisionMap,
        dt: float,
        known: list[Pickup] = [],
        world: World | None = None;

    can update with BotItems entry {
        here.clock += self.dt;
        for item in [here->:HasLevelItem:->][?:LevelItem] {
            self.known.append(item.pickup);
            if item.timeout > 0.0 and item.timeout < here.clock {
                here del ->:HasLevelItem:-> item;
                continue;
            }
            if not item.linked and item.pickup.active {
                item.linked = True;
            }
        }
        world = self.world;
        if world is None or world.item_serial == here.serial {
            return;
        }
        waiting = False;
        for pickup in [world->:HasPickup:->][?:Pickup] {
            if not pickup.dropped or pickup in self.known {
                continue;
            }
            # "if the entity is still moving"
            if in_flight(pickup) {
                waiting = True;
                continue;
            }
            item = add_level_item(here, pickup, self.mesh, self.collision, 0);
            if item is None {
                continue;
            }
            item.linked = True;
            item.timeout = here.clock + DROPPED_TIMEOUT;
            # "never go for items dropped into jumppads"
            if item.goal_area > 0
                and self.mesh.aas.areas[item.goal_area].contents & AREACONTENTS_JUMPPAD_AREA {
                here del ->:HasLevelItem:-> item;
            }
        }
        if not waiting {
            here.serial = world.item_serial;
        }
    }
}

"""BotChooseLTGItem and BotChooseNBGItem. Each level item the bot has seen
is rated by its character's fuzzy weight over the bot's inventory (drawn
within its balance ranges, FuzzyWeightUndecided; a dropped item gets 1000
more), divided by the travel time to it in hundredths of a second times
TRAVELTIME_SCALE. `weights` are the character's item weights and `numbers`
the weight for each item classname. Items the bot still avoids longer than it takes to get
there are passed over. A nearby-goal choice (`max_time` above zero) only
takes items within that travel time from which the long-term goal (`ltg`)
is no further than from here."""
walker ChooseItemGoal {
    has weights: WeightConfig,
        numbers: dict[str, int],
        inventory: list[int],
        dice: WeightDice,
        goals: GoalState,
        mesh: NavMesh,
        origin: Vec3,
        area: int,
        flags: int,
        now: float,
        max_time: float = 0.0,
        ltg: BotGoal | None = None,
        ltg_time: int = 99999,
        best: LevelItem | None = None,
        best_weight: float = 0.0;

    can survey with BotItems entry {
        ltg = self.ltg;
        if self.max_time > 0.0 and ltg is not None {
            self.ltg_time = area_travel_time(self.mesh, self.area, self.origin, ltg.area, self.flags);
        }
        visit [here->:HasLevelItem:->];
    }

    can rate with LevelItem entry {
        if not here.linked or here.goal_area == 0 {
            return;
        }
        number = self.numbers.get(here.info.classname, -1);
        if number < 0 {
            return;
        }
        weight = self.weights.undecided(self.inventory, number, self.dice);
        if here.timeout > 0.0 {
            weight += DROPPED_WEIGHT;
        }
        if weight <= 0.0 {
            return;
        }
        t = area_travel_time(self.mesh, self.area, self.origin, here.goal_area, self.flags);
        if t <= 0 or (self.max_time > 0.0 and float(t) >= self.max_time) {
            return;
        }
        # "if this item won't respawn before we get there"
        if self.goals.avoid_time(here.number, self.now) - float(t) * 0.009 > 0.0 {
            return;
        }
        weight /= float(t) * TRAVELTIME_SCALE;
        if weight <= self.best_weight {
            return;
        }
        ltg = self.ltg;
        if self.max_time > 0.0 {
            back = 0;
            if ltg is not None and here.timeout <= 0.0 {
                back = area_travel_time(self.mesh, here.goal_area, here.goal_origin, ltg.area, self.flags);
            }
            if back > self.ltg_time {
                return;
            }
        }
        self.best_weight = weight;
        self.best = here;
    }
}

"""BotChooseLTGItem / BotChooseNBGItem: push the best item goal, avoided from
now on for its respawn time; False when there is none."""
def choose_item_goal(
    items: BotItems,
    weights: WeightConfig,
    numbers: dict[str, int],
    inventory: list[int],
    dice: WeightDice,
    goals: GoalState,
    mesh: NavMesh,
    origin: Vec3,
    flags: int,
    max_time: float = 0.0,
    ltg: BotGoal | None = None
) -> bool {
    area = mesh.locate(origin);
    # "use the last valid area the bot was in"
    if area == 0 or mesh.aas.areas[area].reach_count == 0 {
        area = goals.last_area;
    }
    goals.last_area = area;
    if area == 0 {
        return False;
    }
    choice = items spawn ChooseItemGoal(
        weights=weights,
        numbers=numbers,
        inventory=inventory,
        dice=dice,
        goals=goals,
        mesh=mesh,
        origin=origin,
        area=area,
        flags=flags,
        now=items.clock,
        max_time=max_time,
        ltg=ltg
    );
    best = choice.best;
    if best is None {
        return False;
    }
    goals.add_avoid(best.number, item_avoid_time(best), items.clock);
    goals.push(item_goal(best));
    return True;
}

"""BotTouchingGoal: the bot's box (its origin, -15..15 by -24..32) overlaps
the goal's box."""
def touching_goal(origin: Vec3, goal: BotGoal) -> bool {
    low = goal.origin.add(goal.mins).sub(Vec3(x=15.0, y=15.0, z=32.0));
    high = goal.origin.add(goal.maxs).add(Vec3(x=15.0, y=15.0, z=24.0));
    return origin.x >= low.x and origin.x <= high.x
        and origin.y >= low.y and origin.y <= high.y
        and origin.z >= low.z and origin.z <= high.z;
}

"""ai_dmnet.c BotReachedGoal for an item goal: touching it (then avoided
until it respawns), its spot in sight with the item gone
(BotItemGoalInVisButNotVisible), or standing within its box's width in its
area when not swimming."""
def reached_goal(
    goal: BotGoal,
    goals: GoalState,
    origin: Vec3,
    eye: Vec3,
    area: int,
    swimming: bool,
    collision: CollisionMap,
    now: float
) -> bool {
    item = goal.item;
    if goal.flags & GFL_ITEM == 0 or item is None {
        return touching_goal(origin, goal);
    }
    if touching_goal(origin, goal) {
        if goal.flags & GFL_DROPPED == 0 {
            goals.add_avoid(goal.number, item_avoid_time(item), now);
        }
        return True;
    }
    # The middle of the goal's box, as botlib figures it (origin + mins).
    middle = goal.origin.add(goal.mins);
    sight = collision.trace_point(eye, middle);
    if not sight.start_solid and sight.fraction >= 1.0 and not item.pickup.active {
        return True;
    }
    if area == goal.area
        and origin.x > goal.origin.x + goal.mins.x
        and origin.x < goal.origin.x + goal.maxs.x
        and origin.y > goal.origin.y + goal.mins.y
        and origin.y < goal.origin.y + goal.maxs.y
        and not swimming {
        return True;
    }
    return False;
}

"""AAS_BestReachableFromJumpPadArea for a floating item: the jump pad whose
throw carries a player's box through the item's box within three seconds.
Each pad is (`start`, `velocity`, `area`): where its throw starts, botlib's
estimate of the throw (AAS_GetJumpPadInfo, horizontal speed a tenth over the
game's) and the pad's AAS area. Returns the area, or 0."""
def jump_pad_area(collision: CollisionMap, info: ItemInfo, origin: Vec3, pads: list[tuple[Vec3, Vec3, int]]) -> int {
    low = origin.add(info.mins).sub(Vec3(x=15.0, y=15.0, z=32.0));
    high = origin.add(info.maxs).add(Vec3(x=15.0, y=15.0, z=24.0));
    for pad in pads {
        position = pad[0].add(Vec3(z=0.125));
        velocity = pad[1].add(Vec3());
        steps = 0;
        while steps < 360 {
            velocity.z -= 800.0 / 120.0;
            after = position.add(velocity.scale(1.0 / 120.0));
            if after.x >= low.x and after.x <= high.x
                and after.y >= low.y and after.y <= high.y
                and after.z >= low.z and after.z <= high.z {
                return pad[2];
            }
            hit = collision.trace(position, after);
            if hit.start_solid or hit.fraction < 1.0 {
                break;
            }
            position = after;
            steps += 1;
        }
    }
    return 0;
}
