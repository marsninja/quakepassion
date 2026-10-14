"""The engine's own navigation compiler: a level's AAS made from the level
itself, for maps that ship none (all of Quake's and Quake II's, and any
other map without its `.aas`).

Botlib's bspc carved a map's brushes into convex areas. Here the engine's
own collision does the carving, with the player's box, so what the router
believes is exactly what the player meets: clip hulls, clip brushes and
patches included, in all three games alike.

- Places to stand are flooded outward from every point the map says a body
  can be (starts, spawns, teleporter exits, items, monsters), one grid
  column at a time. Each is a `NavSpot` node; each way between two is a
  `NavStep` edge: walked (steps of up to 18 units included), jumped up onto
  (a barrier), dropped off a ledge, jumped across a gap, teleported or
  lifted by a plat. The flood is the `FloodFloors` walker.
- Movers are compiled where a player needs them: doors open (an extended
  bridge is a floor), plats at the top. Each spot a door closes over keeps
  the door's model, as botlib's AREACONTENTS_MOVER areas do, so routes know
  where they run into it.
- Spots on one floor are merged into convex rectangles: the areas. Each is
  a thin box at its floor's height, and an axis-aligned tree locates them.
- The steps between areas become reachabilities, one per pair and kind,
  and the result is an `Aas` the router reads as it reads the games'."""
import math;
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from ..physics.collision { CollisionMap, Trace }
import from ..formats.aas {
    Aas,
    AasArea,
    AasReach,
    TRAVEL_WALK,
    TRAVEL_BARRIERJUMP,
    TRAVEL_JUMP,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_TELEPORT,
    TRAVEL_ELEVATOR,
    TRAVEL_JUMPPAD,
    TRAVEL_SWIM,
    AREA_GROUNDED,
    AREA_LIQUID,
    AREACONTENTS_WATER,
    AREACONTENTS_SLIME,
    AREACONTENTS_LAVA,
    AREACONTENTS_DONOTENTER,
    AREACONTENTS_MOVER,
    AREACONTENTS_MODELNUMSHIFT,
    PRESENCE_NORMAL
}
import from ..world.world { World }
import from ..world.level { Level }
import from ..world.doors { Door, HasDoor, DoorMember }
import from ..world.trains { Train, HasTrain, TrackPoint, TrackNext }
import from ..world.traversal { Traversal, HasTraversal, Destination, ArrivesAt, touches_volume }
import from ..world.pickups { Pickup, HasPickup }
import from ..world.hazards { Hazard, HasHazard }
import from ..world.combat { Opponent, HasOpponent }

"""How a body moves, for the compiler: the grid's cell, a step, the highest
barrier a jump clears, the furthest fall taken, run and jump speeds and
gravity. Quake's, Quake II's and Quake III's players share all but the run
speed (sv_maxspeed 320, Q2's 300)."""
obj NavRules {
    has cell: float = 16.0,
        step: float = 18.0,
        barrier: float = 40.0,
        drop: float = 320.0,
        speed: float = 320.0,
        jump_speed: float = 270.0,
        gravity: float = 800.0,
        # The longest gap jump looked for, in cells.
        reach: int = 12,
        # The widest an area grows, in cells, and how far its floor may rise.
        area_cells: int = 8,
        area_rise: float = 24.0;
}

"""A place a standing body's origin can be: the middle of grid cell
(`column`, `row`) at the height the box rests at there."""
node NavSpot {
    has index: int,
        column: int,
        row: int,
        origin: Vec3,
        liquid: int = 0,
        # The door this spot is in when the door is shut (its BSP model).
        mover: int = 0,
        area: int = 0,
        # Whether some way out of it is a drop or nothing at all: where
        # gap jumps are looked for; and the directions walked out of it
        # (bits 1, 2, 4, 8 for +x, -x, +y, -y).
        ledge: bool = False,
        walks: int = 0,
        expanded: bool = False,
        # On a floor (else floating in a liquid: a place to swim), and with
        # the head under (no air there).
        grounded: bool = True,
        submerged: bool = False,
        # 1 when found with the movers posed for travel (doors open, plats
        # up); 0 when found with them where the level starts them (a floor
        # that drops, a bridge that is there until it moves).
        pose: int = 1;
}

"""A way from one spot to another and how it is taken (botlib's travel
types). `model` is the plat a lift rides."""
edge NavStep: NavSpot --> NavSpot {
    has kind: int,
        target: int,
        model: int = 0;
}

"""The spots found so far, by grid column, and the collision they were
found in (movers posed for travel)."""
obj NavGrid {
    has rules: NavRules,
        collision: CollisionMap,
        level: Level,
        spots: list[NavSpot] = [],
        columns: dict[tuple[int, int], list[int]] = {},
        # The BSP models of the doors and plats: a spot standing on one is
        # that mover's.
        mover_models: set[int] = set(),
        # The pose new spots are found in, and where they may be (none: anywhere).
        pose: int = 1,
        region: list[AABB] = [],
        # The movers already joined as lifts.
        lifted: set[int] = set(),
        traces: int = 0;

    """Whether a new spot may be added at `point` (inside the region)."""
    def allowed(point: Vec3) -> bool {
        if not self.region {
            return True;
        }
        for box in self.region {
            if box.mins.x <= point.x and point.x <= box.maxs.x and box.mins.y <= point.y and point.y <= box.maxs.y
                and box.mins.z <= point.z and point.z <= box.maxs.z {
                return True;
            }
        }
        return False;
    }

    def column_at(x: float) -> int {
        return int(math.floor(x / self.rules.cell));
    }

    def middle(column: int, row: int) -> Vec3 {
        return Vec3(x=(float(column) + 0.5) * self.rules.cell, y=(float(row) + 0.5) * self.rules.cell);
    }

    def sweep(start: Vec3, finish: Vec3) -> Trace {
        self.traces += 1;
        return self.collision.trace(start, finish);
    }

    """The spot of column (`column`, `row`) at about height `z`, or -1."""
    def find(column: int, row: int, z: float) -> int {
        for index in self.columns.get((column, row), []) {
            if abs(self.spots[index].origin.z - z) < 8.0 {
                return index;
            }
        }
        return -1;
    }

    def add(column: int, row: int, z: float) -> NavSpot {
        middle = self.middle(column, row);
        spot = NavSpot(
            index=len(self.spots), column=column, row=row, origin=Vec3(x=middle.x, y=middle.y, z=z), pose=self.pose
        );
        spot.liquid = self.level.liquid_at(spot.origin.add(Vec3(z=4.0)));
        spot.submerged = spot.liquid > 0 and self.level.liquid_at(spot.origin.add(Vec3(z=22.0))) > 0;
        floor = self.sweep(spot.origin.add(Vec3(z=1.0)), spot.origin.sub(Vec3(z=4.0)));
        spot.grounded = floor.fraction < 1.0 or floor.start_solid;
        if self.mover_models and floor.model in self.mover_models {
            spot.mover = floor.model;
        }
        self.spots.append(spot);
        key = (column, row);
        if key not in self.columns {
            self.columns[key] = [];
        }
        self.columns[key].append(spot.index);
        return spot;
    }

    """Where a box let down from `top` comes to rest, at most `depth` below:
    the origin's height on a floor flat enough to stand on, or None (in
    solid, over nothing, or on a slope it would slide down)."""
    def ground(x: float, y: float, top: float, depth: float) -> float | None {
        down = self.sweep(Vec3(x=x, y=y, z=top), Vec3(x=x, y=y, z=top - depth));
        if down.start_solid or down.fraction >= 1.0 or down.normal.z < 0.7 {
            return None;
        }
        return down.end.z;
    }

    """The ways from `spot` into the column beside it (`across`, `along`):
    each the height arrived at and the travel type. A walk (or a step up or
    down a stair), a drop off a ledge, or a barrier jumped up onto."""
    def moves(spot: NavSpot, across: int, along: int) -> list[tuple[float, int]] {
        rules = self.rules;
        a = spot.origin;
        beside = self.middle(spot.column + across, spot.row + along);
        level = Vec3(x=beside.x, y=beside.y, z=a.z);
        flat = self.sweep(a, level);
        # In water a body swims on at its height while the water goes on.
        if spot.liquid == 1 and not flat.start_solid and flat.fraction >= 1.0
            and self.level.liquid_at(level.add(Vec3(z=4.0))) == 1 {
            return [(a.z, TRAVEL_SWIM)];
        }
        if not flat.start_solid and flat.fraction >= 1.0 {
            landing = self.ground(beside.x, beside.y, a.z, rules.drop + rules.step);
            if landing is None {
                return [];
            }
            if a.z - landing <= rules.step {
                return [(landing, TRAVEL_WALK)];
            }
            return [(landing, TRAVEL_WALKOFFLEDGE)];
        }
        for lift in [rules.step, rules.barrier] {
            up = self.sweep(a, a.add(Vec3(z=lift)));
            if up.start_solid {
                return [];
            }
            top = up.end;
            over = self.sweep(top, Vec3(x=beside.x, y=beside.y, z=top.z));
            if over.start_solid or over.fraction < 1.0 {
                continue;
            }
            landing = self.ground(beside.x, beside.y, top.z, top.z - a.z + rules.drop);
            if landing is None {
                return [];
            }
            rise = landing - a.z;
            if rise <= rules.step and rise >= -rules.step {
                return [(landing, TRAVEL_WALK)];
            }
            if rise > rules.step {
                return [(landing, TRAVEL_BARRIERJUMP)] if rise <= rules.barrier else [];
            }
            return [(landing, TRAVEL_WALKOFFLEDGE)];
        }
        return [];
    }

    """Up and down through the water from `spot` (a body in water swims
    where it likes): the heights reached, 32 units each way, staying in it."""
    def swims(spot: NavSpot) -> list[float] {
        found: list[float] = [];
        if spot.liquid != 1 {
            return found;
        }
        a = spot.origin;
        for rise in [32.0, -32.0] {
            to = a.add(Vec3(z=rise));
            move = self.sweep(a, to);
            if move.start_solid or move.fraction < 1.0 {
                continue;
            }
            if self.level.liquid_at(to.add(Vec3(z=4.0))) == 1 {
                found.append(to.z);
            } elif rise > 0.0 {
                # Out of the water before the next step up: the surface,
                # where a swimmer climbs out.
                top = a.z;
                while top + 4.0 < to.z and self.level.liquid_at(Vec3(x=a.x, y=a.y, z=top + 8.0)) == 1 {
                    top += 4.0;
                }
                if top > a.z + 3.0 {
                    found.append(top);
                }
            }
        }
        return found;
    }

    """Where a running jump from `spot` along (`across`, `along`) lands
    `cells` columns away, if it clears everything on the way: the origin's
    height there, or None."""
    def jump(spot: NavSpot, across: int, along: int, cells: int) -> float | None {
        rules = self.rules;
        a = spot.origin;
        beside = self.middle(spot.column + across * cells, spot.row + along * cells);
        gap = Vec3(x=beside.x - a.x, y=beside.y - a.y);
        span = gap.length();
        # As high as the jump rises, and no lower than it may fall to.
        apex = rules.jump_speed * rules.jump_speed / (2.0 * rules.gravity);
        landing = self.ground(beside.x, beside.y, a.z + apex - 4.0, apex + rules.drop * 0.5);
        if landing is None or landing > a.z + apex - 8.0 {
            return None;
        }
        # The time the arc takes to come down to the landing's height.
        rise = landing - a.z;
        b = rules.jump_speed;
        disc = b * b - 2.0 * rules.gravity * rise;
        if disc < 0.0 {
            return None;
        }
        flight = (b + math.sqrt(disc)) / rules.gravity;
        # With room to spare: a jump taken a little slow still makes it.
        if flight * rules.speed * 0.85 < span {
            return None;
        }
        # Along the arc as run at full speed, then straight down to land.
        run = span / rules.speed;
        last = a;
        for k in range(1, 7) {
            t = run * float(k) / 6.0;
            point = Vec3(
                x=a.x + gap.x * float(k) / 6.0,
                y=a.y + gap.y * float(k) / 6.0,
                z=a.z + b * t - 0.5 * rules.gravity * t * t
            );
            if point.z < landing {
                point.z = landing;
            }
            leg = self.sweep(last, point);
            if leg.start_solid or leg.fraction < 1.0 {
                return None;
            }
            last = point;
        }
        return landing;
    }
}

"""Flood out from the spots it is sent to: every column beside a spot that
a body there can move into gets its spot, linked by the way it is reached,
and is visited in turn."""
walker FloodFloors {
    has grid: NavGrid,
        added: int = 0;

    can expand with NavSpot entry {
        if here.expanded {
            return;
        }
        here.expanded = True;
        grid = self.grid;
        fresh: list[NavSpot] = [];
        bit = 1;
        for (across, along) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            found = grid.moves(here, across, along);
            if not found {
                here.ledge = True;
            }
            for (z, kind) in found {
                if kind == TRAVEL_WALKOFFLEDGE {
                    here.ledge = True;
                } elif kind == TRAVEL_WALK {
                    here.walks |= bit;
                }
                column = here.column + across;
                row = here.row + along;
                index = grid.find(column, row, z);
                if index < 0 and not grid.allowed(grid.middle(column, row).add(Vec3(z=z))) {
                    continue;
                }
                spot = grid.spots[index] if index >= 0 else grid.add(column, row, z);
                if index < 0 {
                    fresh.append(spot);
                    self.added += 1;
                }
                # Movers at rest only add ways to the places that exist then:
                # between two places found with them posed, the posed ways
                # stand (a drop through a bridge now out is no way).
                if grid.pose == 0 and here.pose == 1 and spot.pose == 1 {
                    continue;
                }
                here +>:NavStep(kind=kind, target=spot.index):+> spot;
            }
            bit *= 2;
        }
        for z in grid.swims(here) {
            index = grid.find(here.column, here.row, z);
            if index < 0 and not grid.allowed(here.origin.add(Vec3(z=z - here.origin.z))) {
                continue;
            }
            spot = grid.spots[index] if index >= 0 else grid.add(here.column, here.row, z);
            if index < 0 {
                fresh.append(spot);
                self.added += 1;
            }
            if grid.pose == 0 and here.pose == 1 and spot.pose == 1 {
                continue;
            }
            here +>:NavStep(kind=TRAVEL_SWIM, target=spot.index):+> spot;
        }
        visit fresh;
    }
}

"""Gap jumps from the spots at ledges: along each axis, the nearest column a
running jump lands in that the walk and the drop beside it did not reach."""
walker FindJumps {
    has grid: NavGrid,
        fresh: list[NavSpot] = [],
        found: int = 0;

    can leap with NavSpot entry {
        if not here.ledge or here.liquid != 0 {
            return;
        }
        grid = self.grid;
        reached = [step.target for step in [edge here->:NavStep:->]];
        bit = 1;
        for (across, along) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            walked = here.walks & bit != 0;
            bit *= 2;
            # Only where the way on is not walked: off a ledge or at a gap.
            if walked {
                continue;
            }
            for cells in range(3, grid.rules.reach + 1) {
                landing = grid.jump(here, across, along, cells);
                if landing is None {
                    continue;
                }
                column = here.column + across * cells;
                row = here.row + along * cells;
                index = grid.find(column, row, landing);
                if index >= 0 and index in reached {
                    break;
                }
                spot = grid.spots[index] if index >= 0 else grid.add(column, row, landing);
                if index < 0 {
                    self.fresh.append(spot);
                }
                here +>:NavStep(kind=TRAVEL_JUMP, target=spot.index):+> spot;
                self.found += 1;
                break;
            }
        }
    }
}

"""What the compiler made of a level, and how long each stage took."""
obj NavBuild {
    has aas: Aas,
        grid: NavGrid | None = None,
        spots: int = 0,
        steps: int = 0,
        jumps: int = 0,
        teleports: int = 0,
        lifts: int = 0,
        resting: int = 0,
        # The areas found with the movers at rest (see NavSpot.pose).
        rest_areas: list[int] = [],
        notes: list[str] = [],
        traces: int = 0,
        seeds: int = 0,
        seconds: float = 0.0;

    def summary -> str {
        return "spots=" + str(self.spots) + " resting=" + str(self.resting) + " steps=" + str(self.steps) + " jumps=" + str(self.jumps)
            + " teleports=" + str(self.teleports) + " lifts=" + str(self.lifts) + " areas="
            + str(len(self.aas.areas) - 1) + " reaches=" + str(len(self.aas.reaches) - 1) + " traces="
            + str(self.traces) + " seeds=" + str(self.seeds);
    }
}

"""Every door, plat and button of the level: each team's leader and its
members (a double door's other leaf)."""
def:priv nav_movers(world: World) -> list[Door] {
    found: list[Door] = [];
    for leader in [world->:HasDoor:->][?:Door] {
        found.append(leader);
        for part in [leader->:DoorMember:->][?:Door] {
            if part not in found {
                found.append(part);
            }
        }
    }
    return found;
}

"""The secret doors (two-stage movers on a track of four points) and the
motion of each fully open: its third point."""
def:priv nav_secret_doors(world: World) -> list[tuple[Train, Vec3]] {
    found: list[tuple[Train, Vec3]] = [];
    for train in [world->:HasTrain:->][?:Train] {
        if train.kind != "secret" {
            continue;
        }
        step = train.current;
        for k in range(2) {
            following = [step->:TrackNext:->][?:TrackPoint];
            if following {
                step = following[0];
            }
        }
        found.append((train, step.origin.sub(train.anchor)));
    }
    return found;
}

"""The level's collision with every mover where a traveller needs it: doors
open, plats up, rotating doors out of the way. The live map is left as it
is."""
def:priv nav_posed_collision(world: World, collision: CollisionMap) -> CollisionMap {
    posed = collision.for_body(collision.eye_height);
    posed.offsets = [offset.add(Vec3()) for offset in collision.offsets];
    posed.disabled = set(collision.disabled);
    for door in nav_movers(world) {
        if door.kind == "button" {
            continue;
        }
        turning = door.rotation.length() > 0.0 or door.rest_angles.length() > 0.0;
        for k in range(len(door.hulls)) {
            hull = door.hulls[k];
            if turning {
                posed.disabled.add(hull);
            } elif k < len(door.origins) {
                posed.offsets[hull] = door.origins[k].add(door.rest).add(door.travel);
            }
        }
    }
    # Secret doors open: stepped aside and slid back.
    for (train, opened) in nav_secret_doors(world) {
        for k in range(len(train.hulls)) {
            if k < len(train.origins) {
                posed.offsets[train.hulls[k]] = train.origins[k].add(opened);
            }
        }
    }
    return posed;
}

"""Where a body put at `point` comes to stand: the point raised clear of
the floor it is on, then let down to it. None when there is no room."""
def:priv nav_seed_height(grid: NavGrid, point: Vec3) -> float | None {
    for lift in [24.0, 8.0, 40.0, 0.0, 56.0] {
        top = point.add(Vec3(z=lift));
        if grid.sweep(top, top).start_solid {
            continue;
        }
        return grid.ground(point.x, point.y, top.z, lift + 256.0);
    }
    return None;
}

"""Add the spot a seed point stands at, unless one is there; returns it."""
def:priv nav_seed(grid: NavGrid, point: Vec3) -> NavSpot | None {
    column = grid.column_at(point.x);
    row = grid.column_at(point.y);
    middle = grid.middle(column, row);
    z = nav_seed_height(grid, Vec3(x=middle.x, y=middle.y, z=point.z));
    if z is None {
        return None;
    }
    index = grid.find(column, row, z);
    if index >= 0 {
        return grid.spots[index];
    }
    return grid.add(column, row, z);
}

"""Every point the map says a body can stand at: player starts and arena
spawns, teleporter exits, items and monsters."""
def:priv nav_seed_points(world: World, level: Level) -> list[Vec3] {
    points: list[Vec3] = [];
    for entity in level.bsp.entities {
        name = entity.fields.get("classname", "");
        if name.startswith("info_player") or name in ["info_teleport_destination", "misc_teleporter_dest"] {
            parts = entity.fields.get("origin", "").split();
            if len(parts) == 3 {
                points.append(Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2])));
            }
        }
    }
    for traversal in [world->:HasTraversal:->][?:Traversal] {
        for place in [traversal->:ArrivesAt:->][?:Destination] {
            points.append(place.origin);
        }
    }
    for item in [world->:HasPickup:->][?:Pickup] {
        points.append(item.pos);
    }
    for body in [world->:HasOpponent:->][?:Opponent] {
        points.append(body.pos.sub(Vec3(z=body.eye_height)));
    }
    return points;
}

"""Each spot inside a teleporter's trigger leads to the spot at its exit."""
def:priv nav_teleports(world: World, grid: NavGrid) -> int {
    count = 0;
    for traversal in [world->:HasTraversal:->][?:Traversal] {
        if traversal.kind != "teleport" or not traversal.volume.bounds {
            continue;
        }
        places = [traversal->:ArrivesAt:->][?:Destination];
        if not places {
            continue;
        }
        exit_spot = nav_seed(grid, places[0].origin);
        if exit_spot is None {
            continue;
        }
        for spot in grid.spots {
            if spot.index != exit_spot.index and touches_volume(traversal.volume, spot.origin) {
                spot +>:NavStep(kind=TRAVEL_TELEPORT, target=exit_spot.index):+> exit_spot;
                count += 1;
            }
        }
    }
    return count;
}

"""Lifts: plats, and doors that move up or down (a floor lowered as a lift).
Each is compiled at one end of its travel (a plat up, a door open): the spot
on its top there is flooded from, and joined both ways to the nearest spot
by the shaft at the other end: beside the top for a mover compiled down,
under it for one compiled up. Returns how many were joined, the spots on
the movers (to flood from), and a line on each that was not."""
def:priv nav_lifts(world: World, grid: NavGrid, level: Level) -> tuple[int, list[NavSpot], list[str]] {
    count = 0;
    tops: list[NavSpot] = [];
    notes: list[str] = [];
    for door in nav_movers(world) {
        if door.kind == "button" or not door.hulls or not door.origins or door.model in grid.lifted {
            continue;
        }
        travel = door.travel;
        if abs(travel.z) < 24.0 or abs(travel.x) + abs(travel.y) > 1.0 {
            continue;
        }
        record = level.bsp.models[door.model];
        if record.maxs.x - record.mins.x < 32.0 or record.maxs.y - record.mins.y < 32.0 {
            continue;
        }
        posed = door.origins[0].add(door.rest).add(travel);
        other = door.origins[0].add(door.rest);
        lo = record.mins.add(posed);
        hi = record.maxs.add(posed);
        middle = Vec3(x=(lo.x + hi.x) * 0.5, y=(lo.y + hi.y) * 0.5, z=hi.z + 24.0);
        on_top = nav_seed(grid, middle);
        if on_top is None or abs(on_top.origin.z - middle.z) > 4.0 {
            notes.append("mover " + str(door.model) + ": no room on top");
            continue;
        }
        tops.append(on_top);
        far_z = record.maxs.z + other.z + 24.0;
        rises = posed.z > other.z;
        found: NavSpot | None = None;
        under: NavSpot | None = None;
        for spot in grid.spots {
            o = spot.origin;
            inside = o.x >= lo.x and o.x <= hi.x and o.y >= lo.y and o.y <= hi.y;
            near = o.x >= lo.x - 40.0 and o.x <= hi.x + 40.0 and o.y >= lo.y - 40.0 and o.y <= hi.y + 40.0;
            # Beside its top where the other end of its travel leaves it;
            # failing that, for one compiled up, at the foot of its shaft.
            if near and not inside and abs(o.z - far_z) <= grid.rules.step {
                if found is None or o.sub(middle).length() < found.origin.sub(middle).length() {
                    found = spot;
                }
            } elif rises and inside and o.z < on_top.origin.z - 40.0 {
                if under is None or o.sub(middle).length() < under.origin.sub(middle).length() {
                    under = spot;
                }
            }
        }
        if found is None {
            found = under;
        }
        if found is None {
            notes.append("mover " + str(door.model) + ": nothing at the far end");
            continue;
        }
        grid.lifted.add(door.model);
        on_top +>:NavStep(kind=TRAVEL_ELEVATOR, target=found.index, model=door.model):+> found;
        found +>:NavStep(kind=TRAVEL_ELEVATOR, target=on_top.index, model=door.model):+> on_top;
        count += 1;
    }
    return (count, tops, notes);
}

"""Mark the spots each door closes over (its shut box grown by the
player's), so the areas there are the door's, and the spots in damaging
volumes as places not to go."""
def:priv nav_mark_movers(world: World, grid: NavGrid, level: Level) {
    for door in nav_movers(world) {
        if door.kind != "door" or not door.hulls {
            continue;
        }
        record = level.bsp.models[door.model];
        shift = door.origins[0].add(door.rest) if door.origins else Vec3();
        lo = record.mins.add(shift).sub(Vec3(x=16.0, y=16.0, z=32.0));
        hi = record.maxs.add(shift).add(Vec3(x=16.0, y=16.0, z=24.0));
        for spot in grid.spots {
            o = spot.origin;
            if spot.pose == 1 and o.x > lo.x and o.x < hi.x and o.y > lo.y and o.y < hi.y and o.z > lo.z and o.z < hi.z {
                spot.mover = door.model;
            }
        }
    }
    # A secret door's doorway is the door's, as a door's is.
    for (train, opened) in nav_secret_doors(world) {
        lo = train.bounds.mins.sub(Vec3(x=16.0, y=16.0, z=32.0));
        hi = train.bounds.maxs.add(Vec3(x=16.0, y=16.0, z=24.0));
        for spot in grid.spots {
            o = spot.origin;
            if spot.pose == 1 and o.x > lo.x and o.x < hi.x and o.y > lo.y and o.y < hi.y and o.z > lo.z and o.z < hi.z {
                spot.mover = train.model;
            }
        }
    }
    for hazard in [world->:HasHazard:->][?:Hazard] {
        if not hazard.enabled or hazard.damage <= 0 {
            continue;
        }
        for spot in grid.spots {
            if touches_volume(hazard.volume, spot.origin) {
                spot.liquid = -1;
            }
        }
    }
}

"""The spot beside `spot` along (`across`, `along`) that is walked to and
from it, or None."""
def:priv nav_walk_beside(grid: NavGrid, spot: NavSpot, across: int, along: int) -> NavSpot | None {
    for step in [edge spot->:NavStep:->] {
        if step.kind != TRAVEL_WALK and step.kind != TRAVEL_SWIM {
            continue;
        }
        other = grid.spots[step.target];
        if other.column != spot.column + across or other.row != spot.row + along {
            continue;
        }
        for back in [edge other->:NavStep:->] {
            if back.kind == step.kind and back.target == spot.index {
                return other;
            }
        }
    }
    return None;
}

"""Whether `other` may join the area begun at `first`."""
def:priv nav_alike(grid: NavGrid, first: NavSpot, other: NavSpot) -> bool {
    return other.area == 0
        and other.pose == first.pose
        and other.grounded == first.grounded
        and other.liquid == first.liquid
        and other.mover == first.mover
        and abs(other.origin.z - first.origin.z) <= grid.rules.area_rise;
}

"""Merge the spots into areas: from each spot not yet in one, a rectangle
grown along its row and then row by row, while every spot in it is walked
to from its neighbours and lies near the first's height. Returns each
area's spots (area n is entry n - 1)."""
def:priv nav_group(grid: NavGrid) -> list[list[NavSpot]] {
    groups: list[list[NavSpot]] = [];
    keys = sorted([(spot.row, spot.column, spot.origin.z, spot.index) for spot in grid.spots]);
    ordered = [grid.spots[key[3]] for key in keys];
    limit = grid.rules.area_cells;
    for first in ordered {
        if first.area != 0 {
            continue;
        }
        area = len(groups) + 1;
        first.area = area;
        row_spots: list[NavSpot] = [first];
        current = first;
        while len(row_spots) < limit {
            nxt = nav_walk_beside(grid, current, 1, 0);
            if nxt is None or not nav_alike(grid, first, nxt) {
                break;
            }
            nxt.area = area;
            row_spots.append(nxt);
            current = nxt;
        }
        members: list[NavSpot] = list(row_spots);
        last_row = row_spots;
        rows = 1;
        while rows < limit {
            above: list[NavSpot] = [];
            whole = True;
            for spot in last_row {
                up = nav_walk_beside(grid, spot, 0, 1);
                if up is None or not nav_alike(grid, first, up) {
                    whole = False;
                    break;
                }
                above.append(up);
            }
            # The new row must also be walked along, spot to spot.
            if whole {
                for k in range(len(above) - 1) {
                    if nav_walk_beside(grid, above[k], 1, 0) is not above[k + 1] {
                        whole = False;
                        break;
                    }
                }
            }
            if not whole {
                break;
            }
            for spot in above {
                spot.area = area;
            }
            members.extend(above);
            last_row = above;
            rows += 1;
        }
        groups.append(members);
    }
    return groups;
}

"""The tree that locates areas, built over their boxes: each node an
axis-aligned plane; a box alone is carved out by its six faces."""
obj NavTree {
    has aas: Aas,
        boxes: list[AABB];

    def plane(axis: int, at: float, front: int, back: int) -> int {
        aas = self.aas;
        aas.normals.append(Vec3(x=1.0) if axis == 0 else (Vec3(y=1.0) if axis == 1 else Vec3(z=1.0)));
        aas.dists.append(at);
        aas.node_planes.append(len(aas.normals) - 1);
        aas.front.append(front);
        aas.back.append(back);
        return len(aas.node_planes) - 1;
    }

    def low(box: AABB, axis: int) -> float {
        return box.mins.x if axis == 0 else (box.mins.y if axis == 1 else box.mins.z);
    }

    def high(box: AABB, axis: int) -> float {
        return box.maxs.x if axis == 0 else (box.maxs.y if axis == 1 else box.maxs.z);
    }

    """Area `area` alone: inside its box it is that area, outside nowhere."""
    def carve(area: int) -> int {
        box = self.boxes[area];
        child = -area;
        for axis in [2, 1, 0] {
            # Above the low face (front) goes on; above the high face is out.
            child = self.plane(axis, self.high(box, axis), 0, child);
            child = self.plane(axis, self.low(box, axis), child, 0);
        }
        return child;
    }

    def build(areas: list[int]) -> int {
        if not areas {
            return 0;
        }
        if len(areas) == 1 {
            return self.carve(areas[0]);
        }
        best_axis = -1;
        best_at = 0.0;
        best_score = 1000000000;
        for axis in [0, 1, 2] {
            faces = sorted([self.high(self.boxes[a], axis) for a in areas]);
            stride = max(1, len(faces) // 16);
            for k in range(0, len(faces), stride) {
                at = faces[k];
                below = 0;
                above = 0;
                for a in areas {
                    if self.high(self.boxes[a], axis) <= at {
                        below += 1;
                    } elif self.low(self.boxes[a], axis) >= at {
                        above += 1;
                    }
                }
                if below == 0 or above == 0 {
                    continue;
                }
                straddle = len(areas) - below - above;
                score = max(below, above) + 3 * straddle;
                if score < best_score {
                    best_score = score;
                    best_axis = axis;
                    best_at = at;
                }
            }
        }
        if best_axis < 0 {
            # No sampled face divides them: try every face.
            for axis in [0, 1, 2] {
                for a in areas {
                    at = self.high(self.boxes[a], axis);
                    below = len([b for b in areas if self.high(self.boxes[b], axis) <= at]);
                    above = len([b for b in areas if self.low(self.boxes[b], axis) >= at]);
                    if below > 0 and above > 0 and best_axis < 0 {
                        best_axis = axis;
                        best_at = at;
                    }
                }
            }
        }
        if best_axis < 0 {
            # Overlapping boxes: the first wins.
            return self.carve(areas[0]);
        }
        back_side = [a for a in areas if self.low(self.boxes[a], best_axis) < best_at];
        front_side = [a for a in areas if self.high(self.boxes[a], best_axis) > best_at];
        back_node = self.build(back_side);
        front_node = self.build(front_side);
        if back_node == 0 and front_node == 0 {
            return 0;
        }
        return self.plane(best_axis, best_at, front_node, back_node);
    }
}

"""How long a step takes, in hundredths of a second as the router counts."""
def:priv nav_step_time(kind: int, start: Vec3, finish: Vec3, rules: NavRules) -> int {
    flat = Vec3(x=finish.x - start.x, y=finish.y - start.y).length();
    run = int(flat * 100.0 / rules.speed);
    if kind == TRAVEL_TELEPORT {
        return 5;
    }
    if kind == TRAVEL_ELEVATOR {
        return int(abs(finish.z - start.z) / 1.5) + 100;
    }
    if kind == TRAVEL_BARRIERJUMP {
        return run + 50;
    }
    if kind == TRAVEL_SWIM {
        return max(1, int(start.sub(finish).length() * 100.0 / (rules.speed * 0.7)));
    }
    if kind == TRAVEL_JUMP {
        return run + 70;
    }
    if kind == TRAVEL_WALKOFFLEDGE {
        fall = max(0.0, start.z - finish.z);
        return run + int(math.sqrt(2.0 * fall / rules.gravity) * 100.0) + 1;
    }
    return max(1, run);
}

"""Flood again round each mover with the movers where the level starts
them: a floor that drops or a bridge that moves away is walked on until it
does. Only places within reach of a mover are added (posed `0`); the spots
already found there are expanded again in this pose. Returns how many were
added."""
def:priv nav_rest_flood(world: World, grid: NavGrid, level: Level, flood: FloodFloors) -> int {
    boxes: list[AABB] = [];
    for door in nav_movers(world) {
        if door.kind == "button" or not door.hulls or not door.origins {
            continue;
        }
        record = level.bsp.models[door.model];
        rest = door.origins[0].add(door.rest);
        posed = rest.add(door.travel);
        lo = Vec3(x=min(rest.x, posed.x), y=min(rest.y, posed.y), z=min(rest.z, posed.z)).add(record.mins);
        hi = Vec3(x=max(rest.x, posed.x), y=max(rest.y, posed.y), z=max(rest.z, posed.z)).add(record.maxs);
        boxes.append(AABB(mins=lo.sub(Vec3(x=48.0, y=48.0, z=64.0)), maxs=hi.add(Vec3(x=48.0, y=48.0, z=96.0))));
    }
    for (train, opened) in nav_secret_doors(world) {
        box = train.bounds;
        lo = Vec3(x=min(0.0, opened.x), y=min(0.0, opened.y), z=min(0.0, opened.z)).add(box.mins);
        hi = Vec3(x=max(0.0, opened.x), y=max(0.0, opened.y), z=max(0.0, opened.z)).add(box.maxs);
        boxes.append(AABB(mins=lo.sub(Vec3(x=48.0, y=48.0, z=64.0)), maxs=hi.add(Vec3(x=48.0, y=48.0, z=96.0))));
    }
    if not boxes {
        return 0;
    }
    before = len(grid.spots);
    posed_collision = grid.collision;
    grid.collision = level.collision.for_body(level.collision.eye_height);
    grid.pose = 0;
    grid.region = boxes;
    near: list[NavSpot] = [];
    for spot in list(grid.spots) {
        if grid.allowed(spot.origin) {
            spot.expanded = False;
            near.append(spot);
        }
    }
    for spot in near {
        spot spawn flood;
    }
    grid.collision = posed_collision;
    grid.pose = 1;
    grid.region = [];
    return len(grid.spots) - before;
}

"""Compile the navigation of the level loaded in `world`."""
def compile_navigation(world: World, level: Level, rules: NavRules | None = None) -> NavBuild {
    if rules is None {
        rules = NavRules(speed=300.0 if level.bsp.game == "q2" else 320.0);
    }
    collision = nav_posed_collision(world, level.collision);
    grid = NavGrid(rules=rules, collision=collision, level=level);
    grid.mover_models = set([door.model for door in nav_movers(world) if door.kind != "button"]);
    build = NavBuild(aas=Aas());
    seeds: list[NavSpot] = [];
    for point in nav_seed_points(world, level) {
        spot = nav_seed(grid, point);
        if spot is not None {
            seeds.append(spot);
        }
    }
    build.seeds = len(seeds);
    flood = FloodFloors(grid=grid);
    for seed in seeds {
        seed spawn flood;
    }
    # Plats and gap jumps open more floors; flood those too, until no more.
    lifted = nav_lifts(world, grid, level);
    build.lifts = lifted[0];
    build.notes = lifted[2];
    for summit in lifted[1] {
        summit spawn flood;
    }
    for round in range(3) {
        leaps = FindJumps(grid=grid);
        for spot in list(grid.spots) {
            spot spawn leaps;
        }
        build.jumps += leaps.found;
        if not leaps.fresh {
            break;
        }
        for spot in leaps.fresh {
            spot spawn flood;
        }
    }
    build.resting = nav_rest_flood(world, grid, level, flood);
    # The far end of a lift that starts at the other end of its travel (one
    # waiting at the foot of its shaft) is only found with the movers at
    # rest: join those lifts now, and flood from their tops.
    late = nav_lifts(world, grid, level);
    build.lifts += late[0];
    build.notes = late[2];
    for summit in late[1] {
        summit spawn flood;
    }
    build.teleports = nav_teleports(world, grid);
    nav_mark_movers(world, grid, level);
    groups = nav_group(grid);
    aas = build.aas;
    aas.areas.append(AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3()));
    boxes: list[AABB] = [AABB(mins=Vec3(), maxs=Vec3())];
    half = rules.cell * 0.5;
    for members in groups {
        lo = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
        hi = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
        total = Vec3();
        for spot in members {
            o = spot.origin;
            lo = Vec3(x=min(lo.x, o.x - half), y=min(lo.y, o.y - half), z=min(lo.z, o.z));
            hi = Vec3(x=max(hi.x, o.x + half), y=max(hi.y, o.y + half), z=max(hi.z, o.z));
            total = total.add(o);
        }
        first = members[0];
        contents = 0;
        flags = AREA_GROUNDED if first.grounded else 0;
        if first.liquid == -1 {
            contents |= AREACONTENTS_DONOTENTER;
        } elif first.liquid > 0 {
            flags |= AREA_LIQUID;
            contents |= AREACONTENTS_LAVA if first.liquid == 3 else (AREACONTENTS_SLIME if first.liquid == 2 else AREACONTENTS_WATER);
        }
        if first.mover > 0 {
            contents |= AREACONTENTS_MOVER | (first.mover << AREACONTENTS_MODELNUMSHIFT);
        }
        if first.pose == 0 {
            build.rest_areas.append(len(aas.areas));
        }
        box = AABB(mins=lo.sub(Vec3(z=4.0)), maxs=hi.add(Vec3(z=8.0)));
        boxes.append(box);
        aas.areas.append(
            AasArea(
                center=total.scale(1.0 / float(len(members))),
                mins=box.mins,
                maxs=box.maxs,
                flags=flags,
                contents=contents,
                presence=PRESENCE_NORMAL
            )
        );
    }
    # One reachability per pair of areas and travel type: of the steps
    # between them, the one nearest the middle of them all.
    aas.reaches.append(AasReach(area=0, start=Vec3(), finish=Vec3(), kind=0, time=0));
    steps = 0;
    for members in groups {
        source = members[0].area;
        chosen: dict[tuple[int, int], list[tuple[NavSpot, NavSpot, int]]] = {};
        for spot in members {
            for step in [edge spot->:NavStep:->] {
                steps += 1;
                other = grid.spots[step.target];
                if other.area == source or other.area == 0 {
                    continue;
                }
                key = (other.area, step.kind);
                if key not in chosen {
                    chosen[key] = [];
                }
                chosen[key].append((spot, other, step.model));
            }
        }
        area = aas.areas[source];
        area.first_reach = len(aas.reaches);
        for key in sorted(chosen.keys()) {
            options = chosen[key];
            middle = Vec3();
            for option in options {
                middle = middle.add(option[0].origin);
            }
            middle = middle.scale(1.0 / float(len(options)));
            best = options[0];
            for option in options {
                if option[0].origin.sub(middle).length() < best[0].origin.sub(middle).length() {
                    best = option;
                }
            }
            kind = key[1];
            start = best[0].origin;
            finish = best[1].origin;
            aas.reaches.append(
                AasReach(
                    area=key[0],
                    start=start,
                    finish=finish,
                    kind=kind,
                    # Under water a swimmer runs out of air: dry ways first.
                    time=nav_step_time(kind, start, finish, rules) * (3 if best[1].submerged else 1),
                    face_num=best[2] if kind == TRAVEL_ELEVATOR else 0
                )
            );
        }
        area.reach_count = len(aas.reaches) - area.first_reach;
    }
    # The tree: node 0 is solid, node 1 the root, which sends every point on.
    aas.normals.append(Vec3(z=1.0));
    aas.dists.append(-1000000.0);
    aas.node_planes = [0, 0];
    aas.front = [0, 0];
    aas.back = [0, 0];
    tree = NavTree(aas=aas, boxes=boxes);
    top = tree.build(list(range(1, len(aas.areas))));
    aas.front[1] = top;
    aas.back[1] = top;
    build.grid = grid;
    build.spots = len(grid.spots);
    build.steps = steps;
    build.traces = grid.traces;
    return build;
}
