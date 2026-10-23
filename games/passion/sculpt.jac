"""The sculptor: a level of brushes made round an essence's places.

The essence's places (`engine/level/graph.jac`), laid on Passion's massing
grid (cells 32 units across, 16 up), are the new level's floor: every grid
column a standing body covers becomes a `Ground` (one per floor level in
the column), each way the essence's moves take between columns a `Way`, so
the sculpture is a graph walked by walkers:

- stairs too steep for the grid are eased until each step is one lift;
- how far each ground lies from the floor's edge (`open`) splits the floor
  into rooms (wide floor) and passages (the rest);
- rooms get ceilings by their size (no lower than most of the essence's),
  sky where the essence was open to it, passages a corridor's; gaps the
  essence jumps across become pits of the district's liquid; lifts keep
  their shafts;
- each stage of the essence's progression takes a district of its own, so
  its regions read apart; trim, pilasters, lamps and railings come from
  Passion's dressing.

What stands in the level (doors, lifts, keys, buttons, monsters, supplies)
is cast from the same graph (`cast.jac`)."""
import math;
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.formats.aas {
    TRAVEL_WALK,
    TRAVEL_BARRIERJUMP,
    TRAVEL_JUMP,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_SWIM,
    TRAVEL_WATERJUMP,
    TRAVEL_TELEPORT,
    TRAVEL_ELEVATOR
}
import from engine.level.graph { LevelGraph, Place, Move, Gate, graph_places, graph_gates }
import from editor.geometry.brush { Side }
import from .random { Stream }
import from .massing { Massing, CELL, LIFT }
import from .space { Space }
import from .kits { KITS, Kit, kit_of, kit_water }
import from .dress { Dressing, Lamp3, dress_steps, box_brush, lamp_strength }

glob SCULPT_HALF: float = 16.0,
     # How much of a cell a body's footprint must cover (square units, summed
     # over the places standing there) for the cell to be floor.
     SCULPT_COVER: float = 150.0,
     # Lifts of air a body needs over a floor, and over floor under floor.
     SCULPT_HEADROOM: int = 5,
     SCULPT_UNDER: int = 4,
     # A passage's ceiling over its floor, in lifts.
     SCULPT_PASSAGE: int = 7,
     # Cells from the floor's edge a ground must lie to be a room's core, and
     # the fewest cores a room is made of.
     SCULPT_CORE: int = 3,
     SCULPT_ROOM_CORES: int = 6,
     # Passages of fewer grounds than this beside a room join the room.
     SCULPT_SLIVER: int = 8,
     # How far a room claims floor round its cores, in cells.
     SCULPT_CLAIM: int = 2,
     # Cells of rock kept round everything.
     SCULPT_MARGIN: int = 3,
     # A pit under a gap jumped across: how deep under the lower side, and
     # how much of it the liquid fills.
     SCULPT_PIT: int = 6,
     SCULPT_PIT_FILL: int = 3;

"""One floor level of one grid column: where the essence's places stood.
`x`, `y` are the cell (32 units) and `z` the floor's lift (16 units);
`base` the essence's floor height; `area` the place covering it most."""
node Ground {
    has x: int,
        y: int,
        z: int,
        base: float = 0.0,
        cover: float = 0.0,
        area: int = 0,
        # Every place of the essence over it.
        areas: list[int] = [],
        spots: int = 0,
        # The liquid it stands in (1 water, 2 slime, 3 lava) and the lift
        # the liquid's top is at.
        liquid: int = 0,
        surface: int = 0,
        # Whether the essence was open to the sky over it, and how many
        # lifts of air it had there.
        sky: bool = False,
        roof: int = 0,
        # The lift it stands on (a BSP model), and whether it is that lift's
        # top (no floor of its own: the lift is its floor).
        plat: int = 0,
        top: bool = False,
        # Its progression stage (the essence place's), cells from the
        # floor's edge, the room core it belongs to, the space it becomes,
        # how many ways from the start it lies.
        stage: int = 0,
        open: int = 9999,
        core: int = -1,
        space: int = -1,
        reach: int = -1,
        # The lift its air rises to (exclusive), once sculpted.
        ceiling: int = 0,
        # How high its air must rise at least (for a way taken over it).
        clear: int = 0;
}

"""A way between two grounds, as the essence's moves go (botlib's travel
types)."""
edge Way: Ground --> Ground {
    has kind: int,
        model: int = 0;
}

"""The sculpture's sculpture: its grounds hang off it."""
node Sculpture {}

edge Spans: Sculpture --> Ground {}

"""A lift of the essence: its box at its top, how far it travels, its
model."""
obj LiftShaft {
    has model: int,
        box: AABB,
        travel: float,
        # A door that lowers once fired rather than a plat.
        lowering: bool = False;
}

"""A level as it is sculpted: the essence, the grounds by column and by
place, the spaces, the massing and the essence's cell (x, y) and lift (z)
its corner stands for, the dressing and liquids."""
obj Sculpting {
    has atlas: LevelGraph | None = None,
        sculpture: Sculpture = Sculpture(),
        columns: dict[tuple[int, int], list[Ground]] = {},
        by_area: dict[int, list[Ground]] = {},
        lifts: list[LiftShaft] = [],
        spaces: list[Space] = [],
        by_space: dict[int, list[Ground]] = {},
        mass: Massing | None = None,
        offset: list[int] = [0, 0, 0],
        dressing: Dressing | None = None,
        liquids: list[list[Side]] = [],
        notes: list[str] = [];

    """A point of the essence as a point of the level."""
    def moved(x: float, y: float, z: float) -> list[float] {
        return [x - float(self.offset[0]) * CELL, y - float(self.offset[1]) * CELL, z - float(self.offset[2]) * LIFT];
    }

    """The ground a thing of the essence stands on: of its place's grounds
    the one under it (nearest across), else the nearest in the columns round
    it at its height; None when none is near."""
    def ground_at(point: Vec3, area: int) -> Ground | None {
        best: Ground | None = None;
        nearest = 1.0e9;
        cx = int(math.floor(point.x / CELL));
        cy = int(math.floor(point.y / CELL));
        candidates = list(self.by_area.get(area, []));
        for dx in [-1, 0, 1] {
            for dy in [-1, 0, 1] {
                for ground in self.columns.get((cx + dx, cy + dy), []) {
                    candidates.append(ground);
                }
            }
        }
        for ground in candidates {
            gap = abs(float(ground.x - cx)) * CELL + abs(float(ground.y - cy)) * CELL + abs(point.z - 24.0 - ground.base);
            if ground.base > point.z + 8.0 {
                gap += 1000.0;
            }
            if gap < nearest {
                nearest = gap;
                best = ground;
            }
        }
        return best if nearest < 640.0 else None;
    }

    """Where a thing that stood at a point of the essence stands in the
    level: over its ground, as high over it as it stood over the essence's
    floor (in the middle of the ground's cell when it stood beside it)."""
    def place_on(point: Vec3, area: int) -> list[float] | None {
        ground = self.ground_at(point, area);
        if ground is None {
            return None;
        }
        x = point.x;
        y = point.y;
        if int(math.floor(x / CELL)) != ground.x or int(math.floor(y / CELL)) != ground.y {
            x = (float(ground.x) + 0.5) * CELL;
            y = (float(ground.y) + 0.5) * CELL;
        }
        return self.moved(x, y, point.z + float(ground.z) * LIFT - ground.base);
    }

    """A ground's middle, standing on it, in the level."""
    def ground_point(ground: Ground) -> list[float] {
        return self.moved((float(ground.x) + 0.5) * CELL, (float(ground.y) + 0.5) * CELL, float(ground.z) * LIFT + 24.0);
    }
}

"""How many tokens a holding has."""
def bits_count(mask: int) -> int {
    count = 0;
    while mask > 0 {
        count += mask & 1;
        mask = mask >> 1;
    }
    return count;
}

"""The grounds of a sculpture."""
def sculpture_grounds(sculpture: Sculpture) -> list[Ground] {
    return [sculpture->:Spans:->][?:Ground];
}

"""Lay an essence's places on the grid: each place's footprint (where a
body standing in it reaches) covers the cells under it; in each column the
floors over it gather into grounds; the essence's moves join them, and
grounds side by side on one level are walked between."""
def lay_grounds(made: Sculpting) {
    atlas = made.atlas;
    if atlas is None {
        return;
    }
    places = graph_places(atlas);
    by_area: dict[int, Place] = {};
    columns: dict[tuple[int, int], list[list[float]]] = {};
    for place in places {
        by_area[place.area] = place;
        low_x = place.box.mins.x - 8.0;
        high_x = place.box.maxs.x + 8.0;
        low_y = place.box.mins.y - 8.0;
        high_y = place.box.maxs.y + 8.0;
        for cx in range(int(math.floor(low_x / CELL)), int(math.floor(high_x / CELL)) + 1) {
            over_x = min(high_x, float(cx + 1) * CELL) - max(low_x, float(cx) * CELL);
            if over_x <= 0.0 {
                continue;
            }
            for cy in range(int(math.floor(low_y / CELL)), int(math.floor(high_y / CELL)) + 1) {
                over_y = min(high_y, float(cy + 1) * CELL) - max(low_y, float(cy) * CELL);
                if over_y > 0.0 {
                    columns.setdefault((cx, cy), []).append([place.floor, over_x * over_y, float(place.area)]);
                }
            }
        }
    }
    # Places the essence moves between directly (not by lift or teleporter):
    # two floors of one column that are, meet at a ledge, not one over the
    # other, and only the one covering more of the column keeps it.
    joined: dict[tuple[int, int, int, int], bool] = {};
    for place in places {
        for move in [edge place->:Move:->] {
            if not move.fall and move.kind not in [TRAVEL_TELEPORT, TRAVEL_ELEVATOR] {
                # Where it lands: the floor it leaves must not roof it there.
                cx = int(math.floor(move.finish.x / CELL));
                cy = int(math.floor(move.finish.y / CELL));
                joined[(cx, cy, place.area, move.to)] = True;
            }
        }
    }
    for (cell, bodies) in columns.items() {
        stack = column_grounds(cell[0], cell[1], bodies);
        lipped: list[int] = [];
        for first in range(len(stack)) {
            for second in range(first + 1, len(stack)) {
                meet = False;
                for a in stack[first][1] {
                    for b in stack[second][1] {
                        if (cell[0], cell[1], a, b) in joined or (cell[0], cell[1], b, a) in joined {
                            meet = True;
                        }
                    }
                }
                if meet {
                    lipped.append(first if stack[first][0].cover < stack[second][0].cover else second);
                }
            }
        }
        for (index, pair) in enumerate(stack) {
            if index in lipped {
                continue;
            }
            ground = pair[0];
            members = pair[1];
            ground.areas = members;
            best_cover = -1.0;
            for body in bodies {
                area = int(body[2]);
                if area not in members {
                    continue;
                }
                place = by_area[area];
                ground.liquid = max(ground.liquid, place.liquid);
                if place.liquid > 0 {
                    ground.surface = max(ground.surface, int(math.floor(place.surface / LIFT)));
                }
                ground.roof = max(ground.roof, int(place.roof / LIFT));
                ground.sky = ground.sky or place.sky;
                if body[1] > best_cover {
                    best_cover = body[1];
                    ground.area = area;
                    ground.stage = max(0, place.stage);
                }
            }
            ground.spots = len(members);
            made.sculpture +>:Spans:+> ground;
            made.columns.setdefault(cell, []).append(ground);
            for area in members {
                made.by_area.setdefault(area, []).append(ground);
            }
        }
    }
    # The essence's moves, one way per pair of grounds, the gentlest kind
    # kept: walked ones between the grounds of the two places side by side,
    # the others between their nearest grounds.
    ways: dict[tuple[int, int], list[int]] = {};
    keyed: dict[int, Ground] = {};
    for ground in sculpture_grounds(made.sculpture) {
        keyed[ground_key(ground)] = ground;
    }
    for place in places {
        here = made.by_area.get(place.area, []);
        if not here {
            continue;
        }
        for move in [edge place->:Move:->] {
            if move.fall {
                continue;
            }
            there = made.by_area.get(move.to, []);
            if not there {
                continue;
            }
            pairs: list[list[Ground]] = [];
            if move.kind in [TRAVEL_WALK, TRAVEL_BARRIERJUMP, TRAVEL_SWIM, TRAVEL_WATERJUMP, TRAVEL_WALKOFFLEDGE] {
                for a in here {
                    for b in there {
                        if abs(a.x - b.x) + abs(a.y - b.y) == 1 {
                            pairs.append([a, b]);
                        }
                    }
                }
            }
            if not pairs {
                best: list[Ground] = [];
                nearest = 1.0e9;
                for a in here {
                    for b in there {
                        gap = float(abs(a.x - b.x) + abs(a.y - b.y)) + 0.1 * float(abs(a.z - b.z));
                        if gap < nearest and a is not b {
                            nearest = gap;
                            best = [a, b];
                        }
                    }
                }
                if best {
                    pairs.append(best);
                }
            }
            for pair in pairs {
                key = (ground_key(pair[0]), ground_key(pair[1]));
                if key not in ways or way_rank(move.kind) < way_rank(ways[key][0]) {
                    ways[key] = [move.kind, move.model];
                }
            }
        }
    }
    for ground in sculpture_grounds(made.sculpture) {
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            for other in made.columns.get((ground.x + dx, ground.y + dy), []) {
                if abs(other.z - ground.z) <= 1 {
                    key = (ground_key(ground), ground_key(other));
                    if key not in ways {
                        ways[key] = [TRAVEL_WALK, 0];
                    }
                }
            }
        }
    }
    for (key, way) in ways.items() {
        if key[0] in keyed and key[1] in keyed {
            keyed[key[0]] +>:Way(kind=way[0], model=way[1]):+> keyed[key[1]];
        }
    }
    for place in places {
        if place.start {
            for ground in made.by_area.get(place.area, []) {
                ground.reach = 0;
                ground spawn Paced();
            }
        }
    }
    for gate in graph_gates(atlas) {
        if gate.kind == "lift" and gate.travel > 0.0 {
            # A plat's box is where it rests, at the foot: its top is a
            # travel higher.
            top_box = AABB(mins=gate.box.mins.add(Vec3(z=gate.travel)), maxs=gate.box.maxs.add(Vec3(z=gate.travel)));
            made.lifts.append(LiftShaft(model=gate.model, box=top_box, travel=gate.travel));
        } elif gate.lowers() {
            # A floor that lowers to open is a lift that rides down once.
            made.lifts.append(LiftShaft(model=gate.model, box=gate.box, travel=-gate.motion.z, lowering=True));
        }
    }
    made.notes.append("grounds " + str(len(keyed)) + " ways " + str(len(ways)));
}

"""A lift's foot and top, in lifts."""
def lift_levels(lift: LiftShaft) -> list[int] {
    top = int(math.floor((lift.box.maxs.z - 1.0) / LIFT + 0.5));
    foot = int(math.floor((lift.box.maxs.z - 1.0 - lift.travel) / LIFT + 0.5));
    return [foot, top];
}

"""Sculpt a level round an essence a step at a time, into `made`: lay its
grounds, ease its stairs, find its rooms and passages, carve and dress."""
def sculpt_steps(atlas: LevelGraph, dice: Stream, made: Sculpting) -> Iterator[str] {
    made.atlas = atlas;
    lay_grounds(made);
    yield "lay";
    ease_steep(made.sculpture, made.notes);
    yield "ease";
    find_spaces(made, dice.derive("spaces"));
    yield "spaces";
    sculpt(made, dice.derive("sculpt"));
    mass = made.mass;
    if mass is None {
        raise ValueError("The level was not sculpted");
    }
    yield "carve";
    dressing = Dressing();
    yield from dress_steps(mass, made.spaces, dice.derive("dress"), dressing);
    passage_lamps(made, dressing);
    made.dressing = dressing;
    yield "dress";
}

"""Cells from the floor's edge: flooded inward from the grounds at an edge
(those with fewer than four level neighbours), a cell a way."""
walker Inward {
    has edges: list[Ground] = [];

    can begin with Sculpture entry {
        visit self.edges;
    }

    can spread with Ground entry {
        for other in level_neighbours(here) {
            if other.open > here.open + 1 {
                other.open = here.open + 1;
                visit [other];
            }
        }
    }
}

"""Room cores joined into rooms: from each core ground, every core ground
it walks to on the level takes its number."""
walker Cores {
    has number: int = 0;

    can join with Ground entry {
        for other in level_neighbours(here) {
            if other.open >= SCULPT_CORE and other.core < 0 {
                other.core = self.number;
                visit [other];
            }
        }
    }
}

"""Rooms claim the floor round their cores, the nearest room first, out to
`SCULPT_CLAIM` cells; what no room claims is passage."""
walker Claims {
    has seeds: list[Ground] = [],
        distance: dict[int, int] = {};

    can begin with Sculpture entry {
        visit self.seeds;
    }

    can claim with Ground entry {
        here_key = ground_key(here);
        step = self.distance.get(here_key, 0);
        if step >= SCULPT_CLAIM {
            return;
        }
        for other in level_neighbours(here) {
            key = ground_key(other);
            if other.space < 0 and key not in self.distance {
                other.space = here.space;
                self.distance[key] = step + 1;
                visit [other];
            }
        }
    }
}

"""Passages: from an unclaimed ground, every unclaimed ground it walks to
on the level becomes the same passage."""
walker Passage {
    has number: int = 0;

    can join with Ground entry {
        for other in level_neighbours(here) {
            if other.space < 0 {
                other.space = self.number;
                visit [other];
            }
        }
    }
}

"""Ways from the start, counted outward over every way there is."""
walker Paced {
    can pace with Ground entry {
        for other in [here->:Way:->][?:Ground] {
            if other.reach < 0 or other.reach > here.reach + 1 {
                other.reach = here.reach + 1;
                visit [other];
            }
        }
    }
}

"""A key for a ground: its cell and floor."""
def ground_key(ground: Ground) -> int {
    return ((ground.z + 4096) * 8192 + (ground.y + 4096)) * 8192 + (ground.x + 4096);
}

"""The grounds beside a ground (its four neighbour cells) on its level: a
lift up or down at most, so they are walked between."""
def level_neighbours(ground: Ground) -> list[Ground] {
    found: list[Ground] = [];
    for other in [ground->:Way:->][?:Ground] {
        if abs(other.x - ground.x) + abs(other.y - ground.y) == 1 and abs(other.z - ground.z) <= 1 {
            found.append(other);
        }
    }
    return found;
}

"""How gentle a way is, for keeping one way per pair: walking first."""
def way_rank(kind: int) -> int {
    order = [TRAVEL_WALK, TRAVEL_SWIM, TRAVEL_BARRIERJUMP, TRAVEL_WATERJUMP, TRAVEL_WALKOFFLEDGE, TRAVEL_JUMP, TRAVEL_ELEVATOR, TRAVEL_TELEPORT];
    for (rank, known) in enumerate(order) {
        if known == kind {
            return rank;
        }
    }
    return len(order);
}

"""The grounds of one column from the floors over it ([floor, cover,
spot]): floors within a lift and a half of each other gather into one;
gathered floors too close above one another for a body between keep only
the one covered most. Each ground comes with the spots it gathered."""
def column_grounds(cx: int, cy: int, bodies: list[list[float]]) -> list[tuple[Ground, list[int]]] {
    ordered: list[list[float]] = [];
    for body in bodies {
        at = len(ordered);
        while at > 0 and ordered[at - 1][0] > body[0] {
            at -= 1;
        }
        ordered.insert(at, body);
    }
    groups: list[list[list[float]]] = [];
    for body in ordered {
        if groups and body[0] - groups[-1][-1][0] <= 24.0 {
            groups[-1].append(body);
        } else {
            groups.append([body]);
        }
    }
    kept: list[tuple[Ground, list[int]]] = [];
    for group in groups {
        cover = 0.0;
        weighted = 0.0;
        members: list[int] = [];
        for body in group {
            cover += body[1];
            weighted += body[0] * body[1];
            index = int(body[2]);
            if index not in members {
                members.append(index);
            }
        }
        if cover < SCULPT_COVER {
            continue;
        }
        base = weighted / cover;
        ground = Ground(x=cx, y=cy, z=int(math.floor(base / LIFT + 0.5)), base=base, cover=cover);
        if kept and ground.z - kept[-1][0].z < SCULPT_UNDER + 1 {
            if ground.cover > kept[-1][0].cover {
                kept[-1] = (ground, members);
            }
            continue;
        }
        kept.append((ground, members));
    }
    return kept;
}

"""The ways the grid made too steep: walked or stepped in the essence,
but more than a lift apart now (two for a barrier jumped). Answers them
as [lower, higher] pairs."""
def steep_ways(sculpture: Sculpture) -> list[list[Ground]] {
    found: list[list[Ground]] = [];
    for ground in sculpture_grounds(sculpture) {
        targets = [ground->:Way:->][?:Ground];
        ways = [edge ground->:Way:->];
        for at in range(len(ways)) {
            other = targets[at];
            kind = ways[at].kind;
            if abs(other.x - ground.x) + abs(other.y - ground.y) != 1 {
                continue;
            }
            rise = other.z - ground.z;
            limit = 2 if kind == TRAVEL_BARRIERJUMP else 1;
            if kind in [TRAVEL_WALK, TRAVEL_BARRIERJUMP, TRAVEL_SWIM, TRAVEL_WATERJUMP] and rise > limit {
                found.append([ground, other]);
            }
        }
    }
    return found;
}

"""The grounds of a sculpture by their column."""
def ground_columns(sculpture: Sculpture) -> dict[tuple[int, int], list[Ground]] {
    columns: dict[tuple[int, int], list[Ground]] = {};
    for ground in sculpture_grounds(sculpture) {
        columns.setdefault((ground.x, ground.y), []).append(ground);
    }
    return columns;
}

"""How many of a ground's level neighbours a move to lift `z` would leave
more than a lift away."""
def strain(ground: Ground, z: int) -> int {
    count = 0;
    for other in level_neighbours(ground) {
        if abs(other.z - z) > 1 {
            count += 1;
        }
    }
    return count;
}

"""Whether a ground may move to lift `z` without crowding the floors over
and under it in its column."""
def column_allows(columns: dict[tuple[int, int], list[Ground]], ground: Ground, z: int) -> bool {
    for other in columns.get((ground.x, ground.y), []) {
        if other is not ground and abs(other.z - z) < SCULPT_UNDER + 1 {
            return False;
        }
    }
    return True;
}

"""Ease the stairs the grid made too steep: of the two ends of each steep
way, the one whose other neighbours mind least is moved a lift toward the
other, round after round, until every way the essence walked is a lift
a step (two for a barrier it jumped)."""
def ease_steep(sculpture: Sculpture, notes: list[str]) {
    columns = ground_columns(sculpture);
    eased = 0;
    for round_index in range(16) {
        steep = steep_ways(sculpture);
        if not steep {
            break;
        }
        for pair in steep {
            lower = pair[0];
            higher = pair[1];
            if higher.z - lower.z <= 1 {
                continue;
            }
            up_cost = strain(lower, lower.z + 1) + (0 if column_allows(columns, lower, lower.z + 1) else 99);
            down_cost = strain(higher, higher.z - 1) + (0 if column_allows(columns, higher, higher.z - 1) else 99);
            if min(up_cost, down_cost) >= 99 {
                continue;
            }
            if up_cost < down_cost or (up_cost == down_cost and lower.spots <= higher.spots) {
                lower.z += 1;
            } else {
                higher.z -= 1;
            }
            eased += 1;
        }
    }
    notes.append("eased " + str(eased) + " steps, " + str(len(steep_ways(sculpture))) + " still steep");
}

"""Rooms and passages: how far each ground lies from the floor's edge,
wide floor gathered into room cores, each room claiming the floor round
its cores, the rest passages. Each is a `Space`; the districts follow the
way through the level, a section each."""
def find_spaces(made: Sculpting, dice: Stream) {
    sculpture = made.sculpture;
    grounds = sculpture_grounds(sculpture);
    edges: list[Ground] = [];
    for ground in grounds {
        ground.open = 9999;
        ground.core = -1;
        ground.space = -1;
        if len(level_neighbours(ground)) < 4 {
            ground.open = 0;
            edges.append(ground);
        }
    }
    sculpture spawn Inward(edges=edges);
    cores = 0;
    sizes: dict[int, int] = {};
    for ground in grounds {
        if ground.open >= SCULPT_CORE and ground.core < 0 {
            ground.core = cores;
            ground spawn Cores(number=cores);
            cores += 1;
        }
        if ground.core >= 0 {
            sizes[ground.core] = sizes.get(ground.core, 0) + 1;
        }
    }
    spaces: list[Space] = [];
    room_of: dict[int, int] = {};
    for core in range(cores) {
        if sizes.get(core, 0) >= SCULPT_ROOM_CORES {
            room_of[core] = len(spaces);
            spaces.append(Space(id=len(spaces), role="room", kind="traced"));
        }
    }
    seeds: list[Ground] = [];
    for ground in grounds {
        if ground.core in room_of {
            ground.space = room_of[ground.core];
            seeds.append(ground);
        }
    }
    sculpture spawn Claims(seeds=seeds);
    for ground in grounds {
        if ground.space < 0 {
            ground.space = len(spaces);
            spaces.append(Space(id=len(spaces), role="corridor", kind="corridor"));
            ground spawn Passage(number=ground.space);
        }
    }
    by_space: dict[int, list[Ground]] = {};
    for ground in grounds {
        by_space.setdefault(ground.space, []).append(ground);
    }
    # A sliver of passage beside a room (a step, a nook) is part of it.
    for space in spaces {
        members = by_space.get(space.id, []);
        if space.role != "corridor" or not members or len(members) >= SCULPT_SLIVER {
            continue;
        }
        touching: dict[int, int] = {};
        for ground in members {
            for other in [ground->:Way:->][?:Ground] {
                if other.space != space.id and spaces[other.space].role == "room" and abs(other.x - ground.x) + abs(other.y - ground.y) == 1 {
                    touching[other.space] = touching.get(other.space, 0) + 1;
                }
            }
        }
        if not touching {
            continue;
        }
        best = -1;
        for (room, count) in touching.items() {
            if best < 0 or count > touching[best] {
                best = room;
            }
        }
        for ground in members {
            ground.space = best;
            by_space[best].append(ground);
        }
        by_space[space.id] = [];
    }
    # Spaces left empty are dropped and the rest numbered again.
    kept_spaces: list[Space] = [];
    renumber: dict[int, int] = {};
    for space in spaces {
        if by_space.get(space.id, []) {
            renumber[space.id] = len(kept_spaces);
            space.id = len(kept_spaces);
            kept_spaces.append(space);
        }
    }
    spaces = kept_spaces;
    by_space = {};
    for ground in grounds {
        ground.space = renumber[ground.space];
        by_space.setdefault(ground.space, []).append(ground);
    }
    # Districts: a kit for each stage of the progression, in the order the
    # stages are reached (kits cycle when stages outnumber them), none the
    # essence's own level's; a level of one stage takes two or three kits,
    # a section of the way through it each.
    essence_map = made.atlas.name if made.atlas is not None else "";
    kits = [index for index in dice.order(len(KITS)) if KITS[index].source != essence_map];
    stage_of: dict[int, int] = {};
    for (space_id, members) in by_space.items() {
        votes: dict[int, int] = {};
        for ground in members {
            votes[ground.stage] = votes.get(ground.stage, 0) + 1;
        }
        best = members[0].stage;
        for (stage, count) in votes.items() {
            if count > votes[best] {
                best = stage;
            }
        }
        stage_of[space_id] = best;
    }
    ordered_stages: list[int] = [];
    for stage in sorted(set(stage_of.values())) {
        at = len(ordered_stages);
        while at > 0 and bits_count(ordered_stages[at - 1]) > bits_count(stage) {
            at -= 1;
        }
        ordered_stages.insert(at, stage);
    }
    reach_of: dict[int, float] = {};
    furthest = 1.0;
    for (space_id, members) in by_space.items() {
        total = 0.0;
        for ground in members {
            total += float(max(0, ground.reach));
        }
        reach_of[space_id] = total / float(len(members));
        furthest = max(furthest, reach_of[space_id]);
    }
    count = min(len(kits), 2 + dice.below(2));
    for space in spaces {
        if len(ordered_stages) > 1 {
            section = ordered_stages.index(stage_of.get(space.id, ordered_stages[0])) % len(kits);
        } else {
            section = min(count - 1, int(reach_of.get(space.id, 0.0) / furthest * float(count)));
        }
        space.district = kits[section];
        # Rooms take one of their district's looks; passages its own.
        space.variant = dice.below(24) if space.role == "room" and dice.chance(0.55) else 0;
    }
    made.spaces = spaces;
    made.by_space = by_space;
    made.notes.append(
        "rooms " + str(len(room_of)) + " passages " + str(len(spaces) - len(room_of)) + " districts "
            + ", ".join(sorted(set([KITS[space.district].name for space in spaces])))
    );
}

"""The cells a box covers by more than `inset` units on each axis."""
def box_cells(box: AABB, inset: float) -> list[tuple[int, int]] {
    cells: list[tuple[int, int]] = [];
    for cx in range(int(math.floor(box.mins.x / CELL)), int(math.floor(box.maxs.x / CELL)) + 1) {
        over_x = min(box.maxs.x, float(cx + 1) * CELL) - max(box.mins.x, float(cx) * CELL);
        if over_x <= inset {
            continue;
        }
        for cy in range(int(math.floor(box.mins.y / CELL)), int(math.floor(box.maxs.y / CELL)) + 1) {
            over_y = min(box.maxs.y, float(cy + 1) * CELL) - max(box.mins.y, float(cy) * CELL);
            if over_y > inset {
                cells.append((cx, cy));
            }
        }
    }
    return cells;
}

"""Sculpt the level's air: ceilings for rooms by their size and for
passages by their floor, raised wherever a way passes over; lift shafts;
pits under gaps the essence was jumped across; liquids; then the massing
carved, and each space's box, stage and kept cells found."""
def sculpt(made: Sculpting, dice: Stream) {
    sculpture = made.sculpture;
    grounds = sculpture_grounds(sculpture);
    columns = made.columns;
    spaces = made.spaces;
    # Lifts: the ground on a lift's top has no floor of its own; its shaft
    # runs down to the lift's foot.
    shafts: dict[tuple[int, int], list[int]] = {};
    for lift in made.lifts {
        levels = lift_levels(lift);
        for cell in box_cells(lift.box, 8.0) {
            for ground in columns.get(cell, []) {
                if abs(ground.z - levels[1]) <= 1 {
                    ground.top = True;
                    ground.plat = lift.model;
                }
            }
            shafts[cell] = [levels[0], levels[1], lift.model];
        }
    }
    # Ceilings: a room's over its highest floor by its size (no lower than
    # most of the essence's), a passage's over each floor.
    tops: dict[int, int] = {};
    passages: dict[int, int] = {};
    for space in spaces {
        members = made.by_space.get(space.id, []);
        if not members {
            continue;
        }
        if space.role == "corridor" {
            passages[space.id] = SCULPT_PASSAGE + dice.between(-1, 1);
            continue;
        }
        highest = max([ground.z for ground in members]);
        size = float(len(members));
        rise = max(9, min(24, int(4.0 + 1.7 * math.sqrt(size)) + dice.between(-1, 2)));
        roofs = sorted([ground.z + min(ground.roof, 30) for ground in members]);
        sky = len([ground for ground in members if ground.sky]) * 2 >= len(members);
        space.sky = sky;
        tops[space.id] = max(highest + rise, roofs[len(roofs) // 2]) + (dice.between(2, 6) if sky else 0);
    }
    for ground in grounds {
        if ground.space in tops {
            ground.ceiling = tops[ground.space];
        } else {
            ground.ceiling = ground.z + passages.get(ground.space, SCULPT_PASSAGE);
        }
        ground.ceiling = max(ground.ceiling, ground.z + SCULPT_HEADROOM);
        if ground.liquid > 0 {
            ground.ceiling = max(ground.ceiling, ground.surface + 3);
        }
    }
    # Every way taken between two grounds keeps a body's room over both.
    pits: dict[tuple[int, int], list[int]] = {};
    for ground in grounds {
        targets = [ground->:Way:->][?:Ground];
        ways = [edge ground->:Way:->];
        for at in range(len(ways)) {
            other = targets[at];
            kind = ways[at].kind;
            if kind in [TRAVEL_TELEPORT, TRAVEL_ELEVATOR] {
                continue;
            }
            ground.clear = max(ground.clear, other.z + SCULPT_HEADROOM);
            other.clear = max(other.clear, ground.z + SCULPT_HEADROOM);
            if kind != TRAVEL_JUMP {
                continue;
            }
            # A gap jumped across: what lies between is air over the jump,
            # and where nothing stood in the essence, a pit.
            low = min(ground.z, other.z);
            high = max(ground.z, other.z) + SCULPT_HEADROOM;
            span = abs(other.x - ground.x) + abs(other.y - ground.y);
            for step in range(1, span) {
                cx = ground.x + (step if other.x > ground.x else (-step if other.x < ground.x else 0));
                cy = ground.y + (step if other.y > ground.y else (-step if other.y < ground.y else 0));
                under = [below for below in columns.get((cx, cy), []) if below.z <= high];
                for below in under {
                    below.clear = max(below.clear, high);
                }
                if under {
                    continue;
                }
                over = [above.z for above in columns.get((cx, cy), [])];
                pit_high = min([high] + [z - 1 for z in over]);
                held = pits.get((cx, cy), [low - SCULPT_PIT, pit_high, ground.space]);
                pits[(cx, cy)] = [min(held[0], low - SCULPT_PIT), max(held[1], pit_high), held[2]];
            }
        }
    }
    for ground in grounds {
        ground.ceiling = max(ground.ceiling, ground.clear);
    }
    # Floor over floor: each ground's air stops under the next floor up (a
    # lift's top is no floor: the shaft runs on).
    for (cell, stack) in columns.items() {
        for ground in stack {
            for above in stack {
                if above is not ground and above.z > ground.z and not above.top {
                    ground.ceiling = min(ground.ceiling, above.z - 1);
                }
            }
            ground.ceiling = max(ground.ceiling, ground.z + SCULPT_UNDER);
        }
    }
    # The massing: everything with a margin of rock.
    low_x = min([ground.x for ground in grounds] + [cell[0] for cell in pits.keys()]) - SCULPT_MARGIN;
    low_y = min([ground.y for ground in grounds] + [cell[1] for cell in pits.keys()]) - SCULPT_MARGIN;
    low_z = min([ground.z for ground in grounds] + [held[0] for held in pits.values()] + [held[0] for held in shafts.values()]) - SCULPT_MARGIN;
    high_x = max([ground.x for ground in grounds] + [cell[0] for cell in pits.keys()]) + SCULPT_MARGIN + 1;
    high_y = max([ground.y for ground in grounds] + [cell[1] for cell in pits.keys()]) + SCULPT_MARGIN + 1;
    high_z = max([ground.ceiling for ground in grounds] + [held[1] for held in pits.values()]) + SCULPT_MARGIN;
    made.offset = [low_x, low_y, low_z];
    mass = Massing(nx=high_x - low_x, ny=high_y - low_y, nz=high_z - low_z);
    made.mass = mass;
    for ground in grounds {
        mass.carve(
            ground.x - low_x,
            ground.y - low_y,
            ground.z - low_z,
            ground.x - low_x + 1,
            ground.y - low_y + 1,
            ground.ceiling - low_z,
            ground.space
        );
    }
    for (cell, shaft) in shafts.items() {
        stack = columns.get(cell, []);
        owner = -1;
        roof = shaft[1] + SCULPT_HEADROOM;
        for ground in stack {
            if ground.top {
                owner = ground.space;
                roof = max(roof, ground.ceiling);
            }
        }
        if owner < 0 and stack {
            owner = stack[0].space;
        }
        if owner >= 0 {
            mass.carve(cell[0] - low_x, cell[1] - low_y, shaft[0] - low_z, cell[0] - low_x + 1, cell[1] - low_y + 1, roof - low_z, owner);
        }
    }
    for (cell, pit) in pits.items() {
        mass.carve(cell[0] - low_x, cell[1] - low_y, pit[0] - low_z, cell[0] - low_x + 1, cell[1] - low_y + 1, pit[1] - low_z, pit[2]);
    }
    # Liquids: each liquid ground's up to its top, and the pits' deadly pools.
    runs: list[list[int]] = [];
    for ground in grounds {
        if ground.liquid > 0 and ground.surface > ground.z {
            runs.append([ground.x - low_x, ground.y - low_y, ground.z - low_z, min(ground.surface, ground.ceiling) - low_z, ground.liquid, ground.space]);
        }
    }
    for (cell, pit) in pits.items() {
        runs.append([cell[0] - low_x, cell[1] - low_y, pit[0] - low_z, pit[0] + SCULPT_PIT_FILL - low_z, 3, pit[2]]);
    }
    made.liquids = liquid_brushes(runs, spaces);
    # Each space's box, stage and floor levels; the cells by a drop or a
    # jump kept clear of railings.
    for space in spaces {
        members = made.by_space.get(space.id, []);
        if not members {
            continue;
        }
        space.x = min([ground.x for ground in members]) - low_x;
        space.y = min([ground.y for ground in members]) - low_y;
        space.z = min([ground.z for ground in members]) - low_z;
        space.w = max([ground.x for ground in members]) - low_x + 1 - space.x;
        space.d = max([ground.y for ground in members]) - low_y + 1 - space.y;
        space.h = max([ground.ceiling for ground in members]) - low_z - space.z;
        stage = members[0];
        counts: dict[int, int] = {};
        for ground in members {
            if ground.open > stage.open {
                stage = ground;
            }
            counts[ground.z] = counts.get(ground.z, 0) + 1;
        }
        space.stage = [stage.x - low_x, stage.y - low_y, stage.z - low_z];
        common = sorted([level for level in counts.keys() if counts[level] >= 12 and level != stage.z]);
        space.levels = [stage.z - low_z] + [level - low_z for level in common[:3]];
    }
    for ground in grounds {
        targets = [ground->:Way:->][?:Ground];
        ways = [edge ground->:Way:->];
        for at in range(len(ways)) {
            other = targets[at];
            if ways[at].kind in [TRAVEL_JUMP, TRAVEL_WALKOFFLEDGE, TRAVEL_BARRIERJUMP] or other.z < ground.z - 2 {
                spaces[ground.space].kept.append([ground.x - low_x, ground.y - low_y, ground.z - low_z]);
            }
        }
    }
    made.notes.append(
        "massing " + str(mass.nx) + "x" + str(mass.ny) + "x" + str(mass.nz) + " pits " + str(len(pits)) + " shafts " + str(len(shafts))
            + " sky rooms " + str(len([space for space in spaces if space.sky]))
    );
}

"""Liquid brushes for runs of cells ([x, y, low, high, liquid, space], in
the massing's cells): runs along x of one liquid at one depth merged into
one box each, in the material the space's district has for it; each side
says its contents outright (lava 8, slime 16, water 32)."""
def liquid_brushes(runs: list[list[int]], spaces: list[Space]) -> list[list[Side]] {
    keyed: dict[tuple[int, int, int, int, int], list[int]] = {};
    for run in runs {
        if run[3] <= run[2] {
            continue;
        }
        kit = kit_of(spaces[run[5]].district);
        material_index = 0 if run[4] == 1 else 1;
        keyed.setdefault((run[1], run[2], run[3], material_index, kit_index(kit)), []).append(run[0]);
    }
    brushes: list[list[Side]] = [];
    for (key, xs) in keyed.items() {
        kit = KITS[key[4]];
        material = kit_water(kit) if key[3] == 0 else (kit.liquid if ("lava" in kit.liquid.lower() or "slime" in kit.liquid.lower()) else "q1:e3m2/*lava1");
        lowered = material.lower();
        contents = 8 if "lava" in lowered else (16 if "slime" in lowered else 32);
        ordered = sorted(xs);
        start = ordered[0];
        last = ordered[0];
        for x in ordered[1:] + [ordered[-1] + 2] {
            if x == last + 1 {
                last = x;
                continue;
            }
            low = Vec3(x=float(start) * CELL, y=float(key[0]) * CELL, z=float(key[1]) * LIFT);
            high = Vec3(x=float(last + 1) * CELL, y=float(key[0] + 1) * CELL, z=float(key[2]) * LIFT - 4.0);
            liquid = box_brush(low, high, [material, material, material, material, material, material], 1.0);
            for side in liquid {
                side.contents = contents;
            }
            brushes.append(liquid);
            start = x;
            last = x;
        }
    }
    return brushes;
}

"""A kit's place in the list of kits."""
def kit_index(kit: Kit) -> int {
    for (index, known) in enumerate(KITS) {
        if known.name == kit.name {
            return index;
        }
    }
    return 0;
}

"""Lamps along the passages, under their ceilings, no two within four
cells, in the order the way reaches them."""
def passage_lamps(made: Sculpting, dressing: Dressing) {
    for space in made.spaces {
        if space.role != "corridor" {
            continue;
        }
        members = made.by_space.get(space.id, []);
        order: list[Ground] = [];
        for ground in members {
            at = len(order);
            while at > 0 and order[at - 1].reach > ground.reach {
                at -= 1;
            }
            order.insert(at, ground);
        }
        kit = kit_of(space.district);
        lit: list[Ground] = [];
        for ground in order {
            if ground.ceiling - ground.z > 18 or ground.liquid > 0 {
                continue;
            }
            near = False;
            for other in lit {
                if max(abs(other.x - ground.x), abs(other.y - ground.y)) < 5 {
                    near = True;
                }
            }
            if near {
                continue;
            }
            lit.append(ground);
            spot = made.moved((float(ground.x) + 0.5) * CELL, (float(ground.y) + 0.5) * CELL, float(ground.ceiling) * LIFT);
            dressing.brushes.append(
                box_brush(
                    Vec3(x=spot[0] - 12.0, y=spot[1] - 12.0, z=spot[2] - 6.0),
                    Vec3(x=spot[0] + 12.0, y=spot[1] + 12.0, z=spot[2]),
                    [kit.trim, kit.trim, kit.trim, kit.trim, kit.trim, kit.light],
                    kit.scale,
                    [5]
                )
            );
            dressing.add_lamp(space, Lamp3(x=spot[0], y=spot[1], z=spot[2] - 28.0, level=int(float(lamp_strength(kit, space)) * 0.85), color=kit.lamp_color));
        }
    }
}

