"""Traced levels: a Passion level sculpted round the ways of an original one.

An original level (Quake's e1m1, say) is loaded from the player's own game
files only to be walked. The engine's navigation compiler finds every place
a body can stand there and every way between them: walks and steps, drops,
jumps, swims, lifts and teleporters (`engine/nav/compile.jac`). Those
places, laid on Passion's massing grid (cells 32 units across, 16 up), are
the floor of a new level:

- every grid column a standing body covers becomes a `Ground` (one per
  floor level in the column), and each way between columns a `Way`, so the
  skeleton is a graph walked by walkers;
- stairs too steep for the grid are eased until each step is one lift;
- how far each ground lies from the floor's edge (`open`) splits the floor
  into rooms (wide floor) and passages (the rest);
- rooms get ceilings by their size (taller than the original's for small
  rooms), sky where the original was open to it, passages a corridor's;
  gaps the original was jumped across become pits of the district's
  liquid; lifts keep their shafts, doors their doorways;
- the districts' materials, trim, pilasters, lamps and railings come from
  Passion's own dressing, and the original's doors, lifts, teleporters,
  monsters, items, start and way out stand where they stood.

Nothing of the original level is kept but where a body can go and what
stands there: the architecture round it is Passion's."""
import math;
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.formats.bsp { MapEntity, model_bounds }
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
import from engine.nav.compile { NavBuild, NavSpot, NavStep, compile_navigation }
import from engine.world.world { World }
import from engine.world.level { Level, load_level }
import from engine.world.doors { Door, door_parts }
import from engine.world.trains { Train, HasTrain }
import from engine.world.teardown { destroy_graph, collision_roots }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { Side }
import from .random { Stream, stream_for, hash_label }
import from .massing { Massing, CELL, LIFT }
import from .spaces { Space }
import from .kits { KITS, Kit, kit_of, kit_water }
import from .dress { Dressing, Lamp3, dress_steps, box_brush, plain_box, lamp_strength }
import from .cast { Casting, origin_text, TELEPORT_MATERIAL }
import from .brushwork { map_item_steps }

glob TRACE_PREFIX: str = "trace-",
     # A standing body's origin over its floor, and half its width.
     TRACE_BODY: float = 24.0,
     TRACE_HALF: float = 16.0,
     # How much of a cell a body's footprint must cover (square units, summed
     # over the bodies standing there) for the cell to be floor.
     TRACE_COVER: float = 150.0,
     # Lifts of air a body needs over a floor, and over floor under floor.
     TRACE_HEADROOM: int = 5,
     TRACE_UNDER: int = 4,
     # A passage's ceiling over its floor, in lifts.
     TRACE_PASSAGE: int = 7,
     # Cells from the floor's edge a ground must lie to be a room's core, and
     # the fewest cores a room is made of.
     TRACE_CORE: int = 3,
     TRACE_ROOM_CORES: int = 6,
     # Passages of fewer grounds than this beside a room join the room.
     TRACE_SLIVER: int = 8,
     # How far a room claims floor round its cores, in cells.
     TRACE_CLAIM: int = 2,
     # Cells of rock kept round everything.
     TRACE_MARGIN: int = 3,
     # A pit under a gap jumped across: how deep under the lower side, and
     # how much of it the liquid fills.
     TRACE_PIT: int = 6,
     TRACE_PIT_FILL: int = 3;

"""The original level a traced level is read from: the game and the map,
and which of the sculptures of it (a seed)."""
obj TraceSource {
    has game: str = "q1",
        map: str = "",
        variant: int = 1;
}

"""Which original a traced name stands for: `trace-<map>` or
`trace-<map>-<variant>`; None for any other name."""
def trace_source(name: str) -> TraceSource | None {
    if not name.startswith(TRACE_PREFIX) {
        return None;
    }
    words = name[len(TRACE_PREFIX):].split("-");
    if not words[0] or len(words) > 2 {
        raise ValueError("Expected trace-MAP or trace-MAP-VARIANT");
    }
    for character in words[0] {
        if not (character.isalnum() or character == "_") {
            raise ValueError("Expected trace-MAP or trace-MAP-VARIANT");
        }
    }
    variant = 1;
    if len(words) == 2 {
        variant = int(words[1]);
        if variant < 1 or variant > 9999 or words[1] != str(variant) {
            raise ValueError("A traced level's variant is 1..9999");
        }
    }
    found = TraceSource(map=words[0], variant=variant);
    found.game = trace_game(words[0]);
    return found;
}

"""The game a map is from, by its name: Quake III's arenas and Quake II's
units, else Quake's."""
def trace_game(map: str) -> str {
    if map.startswith("q3") {
        return "q3";
    }
    for prefix in ["base", "bunk", "ware", "jail", "security", "mintro", "mine", "fact", "power", "cool", "waste", "biggun", "hangar", "lab", "command", "strike", "space", "city", "boss", "train", "q2dm"] {
        if map.startswith(prefix) {
            return "q2";
        }
    }
    return "q1";
}

"""The folder a game's files are in, under the games' common parent."""
def trace_folder(game: str) -> str {
    return "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
}

"""The seed of a traced level: from its map and variant."""
def trace_seed(source: TraceSource) -> int {
    return hash_label(source.variant, source.map) % 2147483646 + 1;
}

"""One floor level of one grid column of the traced level: where a body
stood in the original. `x`, `y` are the cell (world cells, 32 units) and
`z` the floor's lift (16 units); `base` the original floor's height."""
node Ground {
    has x: int,
        y: int,
        z: int,
        base: float = 0.0,
        cover: float = 0.0,
        # Where a body stood on it in the original (to sound the original).
        px: float = 0.0,
        py: float = 0.0,
        spots: int = 0,
        # The liquid it stands in (1 water, 2 slime, 3 lava) and the lift
        # the liquid's top is at.
        liquid: int = 0,
        surface: int = 0,
        # Whether the original was open to the sky over it, and how many
        # lifts of air it had there.
        sky: bool = False,
        roof: int = 0,
        # The lift it stands on (a BSP model), and whether it is that lift's
        # top (no floor of its own: the lift is its floor).
        plat: int = 0,
        top: bool = False,
        # Cells from the floor's edge, the room core it belongs to, the
        # space it becomes, how many ways from the start it lies.
        open: int = 9999,
        core: int = -1,
        space: int = -1,
        reach: int = -1,
        # The lift its air rises to (exclusive), once sculpted.
        ceiling: int = 0,
        # How high its air must rise at least (for a way taken over it).
        clear: int = 0;
}

"""A way between two grounds, as the original was taken: walked, dropped,
jumped, swum, lifted or teleported (botlib's travel types)."""
edge Way: Ground --> Ground {
    has kind: int,
        model: int = 0;
}

"""A mover of the original: its box when shut (a door) or up (a lift), its
model, how far it travels (a lift), the keys it wants and whether it is a
secret that opens to a shot."""
obj TraceMover {
    has model: int,
        box: AABB,
        travel: float = 0.0,
        keys: list[str] = [],
        secret: bool = False;
}

"""A trigger of the original (a teleporter's): its fields and its box."""
obj TraceTrigger {
    has fields: dict[str, str] = {},
        box: AABB = AABB(mins=Vec3(), maxs=Vec3());
}

"""The traced level's skeleton: its grounds (Spans) and what the original
held, read off it."""
node Skeleton {
    has source: str = "",
        game: str = "q1",
        start: Vec3 = Vec3(),
        start_yaw: int = 0,
        # Notes on what was read and eased, for tools.
        notes: list[str] = [],
        # The original's entities (skill applied), its doors' and lifts'
        # boxes, and its way out.
        entities: list[MapEntity] = [],
        doors: list[TraceMover] = [],
        lifts: list[TraceMover] = [],
        teleports: list[TraceTrigger] = [],
        exits: list[AABB] = [];
}

edge Spans: Skeleton --> Ground {}

"""Every spot of the original's navigation that a body can get to from
where it starts, over every kind of way."""
walker Trodden {
    has reached: set[int] = set();

    can tread with NavSpot entry {
        if here.index in self.reached {
            return;
        }
        self.reached.add(here.index);
        visit [here->:NavStep:->];
    }
}

"""Cells from the floor's edge: flooded inward from the grounds at an edge
(those with fewer than four level neighbours), a cell a way."""
walker Inward {
    has edges: list[Ground] = [];

    can begin with Skeleton entry {
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
            if other.open >= TRACE_CORE and other.core < 0 {
                other.core = self.number;
                visit [other];
            }
        }
    }
}

"""Rooms claim the floor round their cores, the nearest room first, out to
`TRACE_CLAIM` cells; what no room claims is passage."""
walker Claims {
    has seeds: list[Ground] = [],
        distance: dict[int, int] = {};

    can begin with Skeleton entry {
        visit self.seeds;
    }

    can claim with Ground entry {
        here_key = ground_key(here);
        step = self.distance.get(here_key, 0);
        if step >= TRACE_CLAIM {
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

"""The grounds of a skeleton."""
def skeleton_grounds(skeleton: Skeleton) -> list[Ground] {
    return [skeleton->:Spans:->][?:Ground];
}

"""The contents of the original level at a point (Q1's leaf contents: -1
empty, -2 solid, -3 water, -4 slime, -5 lava, -6 sky)."""
def original_contents(level: Level, point: Vec3) -> int {
    return level.bsp.leaves[level.locate(point)].contents;
}

"""Read a traced level's skeleton off the original: load it, compile its
navigation, and lay the places a body gets to on the grid."""
def read_skeleton(source: TraceSource, directory: str) -> Skeleton {
    world = World();
    level = load_level(world, directory + "/" + trace_folder(source.game), source.map, source.game);
    build = compile_navigation(world, level);
    skeleton = Skeleton(source=source.map, game=source.game);
    skeleton.notes.append("navigation " + build.summary());
    skeleton.entities = [entity for entity in level.bsp.entities];
    for door in door_parts(world) {
        if door.kind == "button" or door.model <= 0 {
            continue;
        }
        origin = door.origins[0] if door.origins else Vec3();
        box = model_bounds(level.bsp, door.model);
        mover = TraceMover(model=door.model, box=AABB(mins=box.mins.add(origin), maxs=box.maxs.add(origin)), keys=list(door.keys));
        if door.kind == "platform" {
            mover.travel = -door.rest.z;
            skeleton.lifts.append(mover);
        } else {
            skeleton.doors.append(mover);
        }
    }
    for train in [world->:HasTrain:->][?:Train] {
        if train.kind == "secret" {
            skeleton.doors.append(TraceMover(model=train.model, box=train.bounds, secret=True));
        }
    }
    for entity in level.bsp.entities {
        model = entity.fields.get("model", "");
        if not model.startswith("*") {
            continue;
        }
        kind = entity.fields.get("classname", "");
        if kind == "trigger_changelevel" {
            skeleton.exits.append(model_bounds(level.bsp, int(model[1:])));
        } elif kind == "trigger_teleport" {
            skeleton.teleports.append(TraceTrigger(fields=dict(entity.fields), box=model_bounds(level.bsp, int(model[1:]))));
        }
    }
    lay_grounds(skeleton, level, build);
    # The original's graph is done with once read.
    grid = build.grid;
    roots = collision_roots(level.collision);
    if grid is not None {
        for spot in grid.spots {
            roots.append(spot);
        }
    }
    destroy_graph(world, roots);
    return skeleton;
}

"""The start's spot: the reached spot nearest the original's start."""
def start_spot(build: NavBuild, start: Vec3) -> NavSpot | None {
    grid = build.grid;
    if grid is None {
        return None;
    }
    best: NavSpot | None = None;
    nearest = 96.0;
    for spot in grid.spots {
        gap = spot.origin.sub(start).length();
        if gap < nearest {
            nearest = gap;
            best = spot;
        }
    }
    return best;
}

"""Lay the places a body reaches in the original on the grid: each spot's
footprint covers the cells under it; in each column the floors it covers
gather into grounds; the original's ways join them."""
def lay_grounds(skeleton: Skeleton, level: Level, build: NavBuild) {
    grid = build.grid;
    if grid is None {
        raise ValueError("The original's navigation was not compiled");
    }
    start = Vec3();
    for entity in skeleton.entities {
        if entity.fields.get("classname", "") == "info_player_start" {
            parts = entity.fields.get("origin", "0 0 0").split();
            start = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            skeleton.start_yaw = int(float(entity.fields.get("angle", "0")));
        }
    }
    skeleton.start = start;
    first = start_spot(build, start);
    if first is None {
        raise ValueError("No place to stand at the original's start");
    }
    tread = first spawn Trodden();
    reached = tread.reached;
    # Each column's floors: [floor, cover, spot] for each body over it.
    columns: dict[tuple[int, int], list[list[float]]] = {};
    for index in sorted(reached) {
        spot = grid.spots[index];
        o = spot.origin;
        floor = o.z - TRACE_BODY;
        if not spot.grounded {
            # Swimming: the floor is the liquid's bottom under it.
            floor = original_bottom(level, o);
        }
        low_x = int(math.floor((o.x - TRACE_HALF) / CELL));
        low_y = int(math.floor((o.y - TRACE_HALF) / CELL));
        for cx in range(low_x, low_x + 2) {
            for cy in range(low_y, low_y + 2) {
                over_x = min(o.x + TRACE_HALF, float(cx + 1) * CELL) - max(o.x - TRACE_HALF, float(cx) * CELL);
                over_y = min(o.y + TRACE_HALF, float(cy + 1) * CELL) - max(o.y - TRACE_HALF, float(cy) * CELL);
                if over_x <= 0.0 or over_y <= 0.0 {
                    continue;
                }
                columns.setdefault((cx, cy), []).append([floor, over_x * over_y, float(index)]);
            }
        }
    }
    # Each spot's ground: the one in the column its origin stands in.
    owner: dict[int, Ground] = {};
    for (cell, bodies) in columns.items() {
        made = column_grounds(cell[0], cell[1], bodies);
        for (ground, members) in made {
            ground.spots = len(members);
            liquid = 0;
            for index in members {
                spot = grid.spots[index];
                liquid = max(liquid, spot.liquid);
                o = spot.origin;
                if int(math.floor(o.x / CELL)) == ground.x and int(math.floor(o.y / CELL)) == ground.y {
                    owner[index] = ground;
                    ground.px = o.x;
                    ground.py = o.y;
                }
                if spot.mover > 0 {
                    for lift in skeleton.lifts {
                        if lift.model == spot.mover {
                            ground.plat = lift.model;
                        }
                    }
                }
            }
            ground.liquid = max(0, liquid);
            if ground.px == 0.0 and ground.py == 0.0 and members {
                ground.px = grid.spots[members[0]].origin.x;
                ground.py = grid.spots[members[0]].origin.y;
            }
            skeleton +>:Spans:+> ground;
        }
    }
    # A spot whose own column gave its floor to another: the ground nearest
    # it at its height.
    by_cell: dict[tuple[int, int], list[Ground]] = {};
    for ground in skeleton_grounds(skeleton) {
        by_cell.setdefault((ground.x, ground.y), []).append(ground);
    }
    for index in sorted(reached) {
        if index in owner {
            continue;
        }
        spot = grid.spots[index];
        o = spot.origin;
        floor = (o.z - TRACE_BODY) / LIFT;
        best: Ground | None = None;
        nearest = 1.0e9;
        cx = int(math.floor(o.x / CELL));
        cy = int(math.floor(o.y / CELL));
        for dx in [-1, 0, 1] {
            for dy in [-1, 0, 1] {
                for ground in by_cell.get((cx + dx, cy + dy), []) {
                    gap = abs(float(ground.z) - floor) + float(abs(dx) + abs(dy));
                    if gap < nearest {
                        nearest = gap;
                        best = ground;
                    }
                }
            }
        }
        if best is not None and nearest < 4.0 {
            owner[index] = best;
        }
    }
    # The ways: one per pair of grounds, the gentlest kind kept.
    ways: dict[tuple[int, int], list[int]] = {};
    keyed: dict[int, Ground] = {};
    for ground in skeleton_grounds(skeleton) {
        keyed[ground_key(ground)] = ground;
    }
    for (index, ground) in owner.items() {
        spot = grid.spots[index];
        for step in [edge spot->:NavStep:->] {
            if step.target not in owner {
                continue;
            }
            other = owner[step.target];
            if other is ground {
                continue;
            }
            pair = (ground_key(ground), ground_key(other));
            if pair not in ways or way_rank(step.kind) < way_rank(ways[pair][0]) {
                ways[pair] = [step.kind, step.model];
            }
        }
    }
    # Neighbouring grounds on one level are walked between whatever the
    # original said: the new floor runs on between them.
    for ground in skeleton_grounds(skeleton) {
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            for other in by_cell.get((ground.x + dx, ground.y + dy), []) {
                if abs(other.z - ground.z) <= 1 {
                    pair = (ground_key(ground), ground_key(other));
                    if pair not in ways {
                        ways[pair] = [TRAVEL_WALK, 0];
                    }
                }
            }
        }
    }
    for (pair, way) in ways.items() {
        keyed[pair[0]] +>:Way(kind=way[0], model=way[1]):+> keyed[pair[1]];
    }
    origin_ground = owner.get(first.index, None);
    if origin_ground is not None {
        origin_ground.reach = 0;
        origin_ground spawn Paced();
    }
    skeleton.notes.append(
        "reached " + str(len(reached)) + " spots, " + str(len(skeleton_grounds(skeleton))) + " grounds, " + str(len(ways)) + " ways"
    );
    sound_grounds(skeleton, level);
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
        if cover < TRACE_COVER {
            continue;
        }
        base = weighted / cover;
        ground = Ground(x=cx, y=cy, z=int(math.floor(base / LIFT + 0.5)), base=base, cover=cover);
        if kept and ground.z - kept[-1][0].z < TRACE_UNDER + 1 {
            if ground.cover > kept[-1][0].cover {
                kept[-1] = (ground, members);
            }
            continue;
        }
        kept.append((ground, members));
    }
    return kept;
}

"""Where a swimmer at `point` would touch bottom: down through the liquid
to the first solid (or the depth of six bodies)."""
def original_bottom(level: Level, point: Vec3) -> float {
    z = point.z;
    floor_limit = point.z - 384.0;
    while z > floor_limit and original_contents(level, Vec3(x=point.x, y=point.y, z=z - 4.0)) != -2 {
        z -= 4.0;
    }
    return z;
}

"""What the original had over each ground: its liquid's top, whether sky
closed it, and how much air (in lifts)."""
def sound_grounds(skeleton: Skeleton, level: Level) {
    for ground in skeleton_grounds(skeleton) {
        x = ground.px;
        y = ground.py;
        z = ground.base + 8.0;
        if ground.liquid > 0 {
            while z < ground.base + 512.0 and original_contents(level, Vec3(x=x, y=y, z=z)) in [-3, -4, -5] {
                z += 4.0;
            }
            ground.surface = int(math.floor(z / LIFT));
        }
        top = z;
        while top < ground.base + 1024.0 and original_contents(level, Vec3(x=x, y=y, z=top)) in [-1, -3, -4, -5] {
            top += 8.0;
        }
        ground.roof = max(0, int((top - ground.base) / LIFT));
        ground.sky = original_sky(level, Vec3(x=x, y=y, z=top - 8.0));
    }
}

"""Whether the ceiling over a point of the original is its sky: a face of
the leaf the point is in, drawn with a sky texture, facing down over it.
(Quake's sky is solid to every hull, so only its faces say where it is.)"""
def original_sky(level: Level, point: Vec3) -> bool {
    leaf = level.bsp.leaves[level.locate(point)];
    for index in leaf.faces {
        face = level.bsp.faces[index];
        if face.normal.z > -0.5 or not face.vertices {
            continue;
        }
        name = level.bsp.textures[face.texture].name.lower() if 0 <= face.texture < len(level.bsp.textures) else "";
        if not name.startswith("sky") and "/sky" not in name {
            continue;
        }
        low_x = min([vertex.x for vertex in face.vertices]);
        high_x = max([vertex.x for vertex in face.vertices]);
        low_y = min([vertex.y for vertex in face.vertices]);
        high_y = max([vertex.y for vertex in face.vertices]);
        if low_x <= point.x <= high_x and low_y <= point.y <= high_y {
            return True;
        }
    }
    return False;
}

"""The ways the grid made too steep: walked or stepped in the original,
but more than a lift apart now (two for a barrier jumped). Answers them
as [lower, higher] pairs."""
def steep_ways(skeleton: Skeleton) -> list[list[Ground]] {
    found: list[list[Ground]] = [];
    for ground in skeleton_grounds(skeleton) {
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

"""A line of numbers about a skeleton, for tools: grounds, ways by kind,
steep ways, columns with floor over floor, liquids, sky, lifts, doors."""
def skeleton_report(skeleton: Skeleton) -> list[str] {
    grounds = skeleton_grounds(skeleton);
    kinds: dict[int, int] = {};
    for ground in grounds {
        for way in [edge ground->:Way:->] {
            kinds[way.kind] = kinds.get(way.kind, 0) + 1;
        }
    }
    columns: dict[tuple[int, int], int] = {};
    for ground in grounds {
        columns[(ground.x, ground.y)] = columns.get((ground.x, ground.y), 0) + 1;
    }
    stacked = len([count for count in columns.values() if count > 1]);
    lines = list(skeleton.notes);
    lines.append(
        "grounds " + str(len(grounds)) + " columns " + str(len(columns)) + " stacked " + str(stacked) + " liquid "
            + str(len([g for g in grounds if g.liquid > 0])) + " sky " + str(len([g for g in grounds if g.sky])) + " plat "
            + str(len([g for g in grounds if g.plat > 0])) + " unreached " + str(len([g for g in grounds if g.reach < 0]))
    );
    lines.append("ways " + " ".join([str(kind) + ":" + str(kinds[kind]) for kind in sorted(kinds.keys())]));
    lines.append("steep " + str(len(steep_ways(skeleton))));
    lines.append("doors " + str(len(skeleton.doors)) + " lifts " + str(len(skeleton.lifts)) + " exits " + str(len(skeleton.exits)));
    if grounds {
        lines.append(
            "cells x " + str(min([g.x for g in grounds])) + ".." + str(max([g.x for g in grounds])) + " y "
                + str(min([g.y for g in grounds])) + ".." + str(max([g.y for g in grounds])) + " z "
                + str(min([g.z for g in grounds])) + ".." + str(max([g.z for g in grounds]))
        );
    }
    return lines;
}

"""The grounds of a skeleton by their column."""
def ground_columns(skeleton: Skeleton) -> dict[tuple[int, int], list[Ground]] {
    columns: dict[tuple[int, int], list[Ground]] = {};
    for ground in skeleton_grounds(skeleton) {
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
        if other is not ground and abs(other.z - z) < TRACE_UNDER + 1 {
            return False;
        }
    }
    return True;
}

"""Ease the stairs the grid made too steep: of the two ends of each steep
way, the one whose other neighbours mind least is moved a lift toward the
other, round after round, until every way the original walked is a lift
a step (two for a barrier it jumped)."""
def ease_steep(skeleton: Skeleton) {
    columns = ground_columns(skeleton);
    eased = 0;
    for round_index in range(16) {
        steep = steep_ways(skeleton);
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
    skeleton.notes.append("eased " + str(eased) + " steps, " + str(len(steep_ways(skeleton))) + " still steep");
}

"""A traced level as it is made: the original it is read from, its
skeleton, the spaces sculpted out of it, the massing and the original's
cell (x, y) and lift (z) the massing's corner stands for, the dressing,
what was cast, liquids, and the map items."""
obj Tracing {
    has source: TraceSource | None = None,
        skeleton: Skeleton | None = None,
        columns: dict[tuple[int, int], list[Ground]] = {},
        spaces: list[Space] = [],
        by_space: dict[int, list[Ground]] = {},
        mass: Massing | None = None,
        offset: list[int] = [0, 0, 0],
        dressing: Dressing | None = None,
        casting: Casting | None = None,
        liquids: list[list[Side]] = [],
        items: list[MapItem] = [],
        briefing: str = "",
        notes: list[str] = [];

    """A point of the original as a point of the traced level."""
    def moved(x: float, y: float, z: float) -> list[float] {
        return [x - float(self.offset[0]) * CELL, y - float(self.offset[1]) * CELL, z - float(self.offset[2]) * LIFT];
    }

    """Where a thing that stood at a point of the original stands in the
    traced level: over the ground nearest under it (its own column first),
    as high over that ground as it stood over the original's floor; None
    when no ground is near."""
    def place(x: float, y: float, z: float) -> list[float] | None {
        cx = int(math.floor(x / CELL));
        cy = int(math.floor(y / CELL));
        best: Ground | None = None;
        nearest = 1.0e9;
        for dx in [-1, 0, 1] {
            for dy in [-1, 0, 1] {
                for ground in self.columns.get((cx + dx, cy + dy), []) {
                    gap = abs(z - TRACE_BODY - ground.base) + 64.0 * float(abs(dx) + abs(dy));
                    if ground.base > z + 8.0 {
                        gap += 1000.0;
                    }
                    if gap < nearest {
                        nearest = gap;
                        best = ground;
                    }
                }
            }
        }
        if best is None or nearest > 480.0 {
            return None;
        }
        if best.x != cx or best.y != cy {
            x = (float(best.x) + 0.5) * CELL;
            y = (float(best.y) + 0.5) * CELL;
        }
        return self.moved(x, y, z + float(best.z) * LIFT - best.base);
    }
}

"""Make a traced level a step at a time, into `made`: read the original,
ease its stairs, find its rooms and passages, sculpt and dress them, cast
what the original held, and turn it all into map items."""
def trace_steps(source: TraceSource, directory: str, made: Tracing) -> Iterator[str] {
    made.source = source;
    dice = stream_for(trace_seed(source), "trace");
    skeleton = read_skeleton(source, directory);
    made.skeleton = skeleton;
    yield "read";
    ease_steep(skeleton);
    made.columns = ground_columns(skeleton);
    yield "ease";
    find_spaces(made, dice.derive("spaces"));
    yield "spaces";
    sculpt(made, dice.derive("sculpt"));
    mass = made.mass;
    if mass is None {
        raise ValueError("The traced level was not sculpted");
    }
    yield "sculpt";
    dressing = Dressing();
    yield from dress_steps(mass, made.spaces, dice.derive("dress"), dressing);
    passage_lamps(made, dressing);
    made.dressing = dressing;
    yield "dress";
    casting = trace_cast(made);
    made.casting = casting;
    yield "cast";
    names = ", ".join([kit_of(district).name for district in sorted(set([space.district for space in made.spaces]))]);
    made.briefing = names + " | Reach the way out";
    items: list[MapItem] = [];
    yield from map_item_steps(mass, made.spaces, dressing, casting.items, made.briefing, items);
    if items {
        for brush in made.liquids {
            items[0].brushes.append(brush);
        }
        items[0].fields["generator"] = "passion-trace";
    }
    made.items = items;
    made.notes = list(skeleton.notes);
    yield "brushwork";
}

"""Rooms and passages: how far each ground lies from the floor's edge,
wide floor gathered into room cores, each room claiming the floor round
its cores, the rest passages. Each is a `Space`; the districts follow the
way through the level, a section each."""
def find_spaces(made: Tracing, dice: Stream) {
    skeleton = made.skeleton;
    if skeleton is None {
        return;
    }
    grounds = skeleton_grounds(skeleton);
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
    skeleton spawn Inward(edges=edges);
    cores = 0;
    sizes: dict[int, int] = {};
    for ground in grounds {
        if ground.open >= TRACE_CORE and ground.core < 0 {
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
        if sizes.get(core, 0) >= TRACE_ROOM_CORES {
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
    skeleton spawn Claims(seeds=seeds);
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
        if space.role != "corridor" or not members or len(members) >= TRACE_SLIVER {
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
    # Districts: two or three kits, none the original's own, a section of
    # the way through the level each.
    source = made.source;
    kits = [index for index in dice.order(len(KITS)) if source is None or KITS[index].source != source.map];
    count = min(len(kits), 2 + dice.below(2));
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
    for space in spaces {
        section = min(count - 1, int(reach_of.get(space.id, 0.0) / furthest * float(count)));
        space.district = kits[section];
        # Rooms take one of their district's looks; passages its own.
        space.variant = dice.below(24) if space.role == "room" and dice.chance(0.55) else 0;
    }
    made.spaces = spaces;
    made.by_space = by_space;
    skeleton.notes.append(
        "rooms " + str(len(room_of)) + " passages " + str(len(spaces) - len(room_of)) + " districts "
            + ", ".join([KITS[kits[index]].name for index in range(count)])
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

"""A lift's top and foot, in lifts."""
def lift_levels(lift: TraceMover) -> list[int] {
    top = int(math.floor((lift.box.maxs.z - 1.0) / LIFT + 0.5));
    foot = int(math.floor((lift.box.maxs.z - 1.0 - lift.travel) / LIFT + 0.5));
    return [foot, top];
}

"""Sculpt the traced level's air: ceilings for rooms by their size and for
passages by their floor, raised wherever a way passes over; lift shafts;
pits under gaps the original was jumped across; liquids; then the massing
carved, and each space's box, stage and kept cells found."""
def sculpt(made: Tracing, dice: Stream) {
    skeleton = made.skeleton;
    if skeleton is None {
        return;
    }
    grounds = skeleton_grounds(skeleton);
    columns = made.columns;
    spaces = made.spaces;
    # Lifts: the ground on a lift's top has no floor of its own; its shaft
    # runs down to the lift's foot.
    shafts: dict[tuple[int, int], list[int]] = {};
    for lift in skeleton.lifts {
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
    # most of the original's), a passage's over each floor.
    tops: dict[int, int] = {};
    passages: dict[int, int] = {};
    for space in spaces {
        members = made.by_space.get(space.id, []);
        if not members {
            continue;
        }
        if space.role == "corridor" {
            passages[space.id] = TRACE_PASSAGE + dice.between(-1, 1);
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
            ground.ceiling = ground.z + passages.get(ground.space, TRACE_PASSAGE);
        }
        ground.ceiling = max(ground.ceiling, ground.z + TRACE_HEADROOM);
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
            ground.clear = max(ground.clear, other.z + TRACE_HEADROOM);
            other.clear = max(other.clear, ground.z + TRACE_HEADROOM);
            if kind != TRAVEL_JUMP {
                continue;
            }
            # A gap jumped across: what lies between is air over the jump,
            # and where nothing stood in the original, a pit.
            low = min(ground.z, other.z);
            high = max(ground.z, other.z) + TRACE_HEADROOM;
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
                held = pits.get((cx, cy), [low - TRACE_PIT, pit_high, ground.space]);
                pits[(cx, cy)] = [min(held[0], low - TRACE_PIT), max(held[1], pit_high), held[2]];
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
            ground.ceiling = max(ground.ceiling, ground.z + TRACE_UNDER);
        }
    }
    # The massing: everything with a margin of rock.
    low_x = min([ground.x for ground in grounds] + [cell[0] for cell in pits.keys()]) - TRACE_MARGIN;
    low_y = min([ground.y for ground in grounds] + [cell[1] for cell in pits.keys()]) - TRACE_MARGIN;
    low_z = min([ground.z for ground in grounds] + [held[0] for held in pits.values()] + [held[0] for held in shafts.values()]) - TRACE_MARGIN;
    high_x = max([ground.x for ground in grounds] + [cell[0] for cell in pits.keys()]) + TRACE_MARGIN + 1;
    high_y = max([ground.y for ground in grounds] + [cell[1] for cell in pits.keys()]) + TRACE_MARGIN + 1;
    high_z = max([ground.ceiling for ground in grounds] + [held[1] for held in pits.values()]) + TRACE_MARGIN;
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
        roof = shaft[1] + TRACE_HEADROOM;
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
        runs.append([cell[0] - low_x, cell[1] - low_y, pit[0] - low_z, pit[0] + TRACE_PIT_FILL - low_z, 3, pit[2]]);
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
    skeleton.notes.append(
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
def passage_lamps(made: Tracing, dressing: Dressing) {
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

"""The fields of an original entity to keep: all but where it stood and
what it was wired to (nothing it fires or is fired by comes along)."""
def kept_fields(entity: MapEntity, game: str) -> dict[str, str] {
    fields: dict[str, str] = {};
    for (key, value) in entity.fields.items() {
        if key not in ["origin", "target", "targetname", "killtarget", "model"] {
            fields[key] = value;
        }
    }
    fields["asset_game"] = game;
    return fields;
}

"""What a traced level holds: the original's start, its monsters, items
and weapons where they stood, its doors and lifts in their places, its
teleporters, and a gate where its way out was."""
def trace_cast(made: Tracing) -> Casting {
    casting = Casting();
    skeleton = made.skeleton;
    mass = made.mass;
    if skeleton is None or mass is None {
        return casting;
    }
    game = skeleton.game;
    start = made.place(skeleton.start.x, skeleton.start.y, skeleton.start.z);
    if start is not None {
        casting.start = start;
        casting.items.append(MapItem(fields={"classname": "info_player_start", "origin": origin_text(start[0], start[1], start[2]), "angle": str(skeleton.start_yaw)}));
    }
    for entity in skeleton.entities {
        name = entity.fields.get("classname", "");
        parts = entity.fields.get("origin", "").split();
        if len(parts) != 3 {
            continue;
        }
        wanted = name.startswith("monster_") or name.startswith("item_") or name.startswith("weapon_") or name.startswith("misc_explobox")
            or name == "info_teleport_destination";
        if not wanted {
            continue;
        }
        point = made.place(float(parts[0]), float(parts[1]), float(parts[2]));
        if point is None {
            continue;
        }
        fields = kept_fields(entity, game);
        fields["origin"] = origin_text(point[0], point[1], point[2]);
        if name == "info_teleport_destination" {
            fields["targetname"] = entity.fields.get("targetname", "");
        }
        if name.startswith("monster_") {
            casting.monsters += 1;
        }
        casting.items.append(MapItem(fields=fields));
    }
    cast_teleporters(made, casting);
    cast_movers(made, casting);
    cast_exit(made, casting);
    return casting;
}

"""The ground under the middle of a box of the original, nearest its
floor."""
def ground_under(made: Tracing, box: AABB) -> Ground | None {
    best: Ground | None = None;
    nearest = 1.0e9;
    middle = box.mins.add(box.maxs).scale(0.5);
    for cell in box_cells(box, 0.0) {
        for ground in made.columns.get(cell, []) {
            gap = abs(ground.base - box.mins.z) + 0.01 * (abs((float(ground.x) + 0.5) * CELL - middle.x) + abs((float(ground.y) + 0.5) * CELL - middle.y));
            if gap < nearest {
                nearest = gap;
                best = ground;
            }
        }
    }
    return best;
}

"""Teleporters where the original's stood: a trigger over its floor and a
pad under it."""
def cast_teleporters(made: Tracing, casting: Casting) {
    skeleton = made.skeleton;
    if skeleton is None {
        return;
    }
    for trigger in skeleton.teleports {
        ground = ground_under(made, trigger.box);
        if ground is None {
            continue;
        }
        low = made.moved(trigger.box.mins.x, trigger.box.mins.y, 0.0);
        high = made.moved(trigger.box.maxs.x, trigger.box.maxs.y, 0.0);
        base = float(ground.z - made.offset[2]) * LIFT;
        fields = {"classname": "trigger_teleport", "target": trigger.fields.get("target", "")};
        if trigger.fields.get("spawnflags", "") {
            fields["spawnflags"] = trigger.fields["spawnflags"];
        }
        item = MapItem(fields=fields);
        item.brushes = [plain_box(Vec3(x=low[0], y=low[1], z=base + 4.0), Vec3(x=high[0], y=high[1], z=base + 68.0), "trigger", 1.0)];
        casting.items.append(item);
        pad = MapItem(fields={"classname": "func_wall", "_passion": "teleporter"});
        pad.brushes = [plain_box(Vec3(x=low[0], y=low[1], z=base), Vec3(x=high[0], y=high[1], z=base + 4.0), TELEPORT_MATERIAL, 1.0)];
        casting.items.append(pad);
        middle = [(low[0] + high[0]) * 0.5, (low[1] + high[1]) * 0.5];
        casting.items.append(MapItem(fields={"classname": "light", "origin": origin_text(middle[0], middle[1], base + 64.0), "light": "180", "_color": "180 200 255"}));
    }
}

"""The original's doors in the doorways they shut (each across the whole
width of the new doorway, floor to ceiling, opening upward), and its lifts
in their shafts."""
def cast_movers(made: Tracing, casting: Casting) {
    skeleton = made.skeleton;
    if skeleton is None {
        return;
    }
    for door in skeleton.doors {
        cells = box_cells(door.box, 4.0);
        low_lift = int(math.floor(door.box.mins.z / LIFT)) - 2;
        high_lift = int(math.ceil(door.box.maxs.z / LIFT));
        hits: list[Ground] = [];
        for cell in cells {
            for ground in made.columns.get(cell, []) {
                if low_lift <= ground.z <= high_lift and not ground.top {
                    hits.append(ground);
                }
            }
        }
        if not hits {
            continue;
        }
        floor = min([ground.z for ground in hits]);
        roof = max([ground.ceiling for ground in hits]);
        size = door.box.maxs.sub(door.box.mins);
        if size.x <= size.y {
            middle = (door.box.mins.x + door.box.maxs.x) * 0.5;
            half = max(4.0, size.x * 0.5);
            low = Vec3(x=middle - half, y=float(min([ground.y for ground in hits])) * CELL, z=float(floor) * LIFT);
            high = Vec3(x=middle + half, y=float(max([ground.y for ground in hits]) + 1) * CELL, z=float(roof) * LIFT);
        } else {
            middle = (door.box.mins.y + door.box.maxs.y) * 0.5;
            half = max(4.0, size.y * 0.5);
            low = Vec3(x=float(min([ground.x for ground in hits])) * CELL, y=middle - half, z=float(floor) * LIFT);
            high = Vec3(x=float(max([ground.x for ground in hits]) + 1) * CELL, y=middle + half, z=float(roof) * LIFT);
        }
        a = made.moved(low.x, low.y, low.z);
        b = made.moved(high.x, high.y, high.z);
        kit = kit_of(made.spaces[hits[0].space].district);
        fields = {"classname": "func_door", "angle": "-1", "speed": "60" if door.secret else "160", "wait": "-1", "lip": "8"};
        if door.keys {
            fields["key"] = " ".join(door.keys);
        }
        if door.secret {
            fields["health"] = "1";
            fields["_secret"] = "1";
        }
        item = MapItem(fields=fields);
        item.brushes = [plain_box(Vec3(x=a[0], y=a[1], z=a[2]), Vec3(x=b[0], y=b[1], z=b[2]), kit.wall if door.secret else kit.door, kit.scale)];
        casting.items.append(item);
        casting.doors += 1;
    }
    for lift in skeleton.lifts {
        cells = box_cells(lift.box, 8.0);
        if not cells {
            continue;
        }
        levels = lift_levels(lift);
        low_x = min([cell[0] for cell in cells]);
        high_x = max([cell[0] for cell in cells]) + 1;
        low_y = min([cell[1] for cell in cells]);
        high_y = max([cell[1] for cell in cells]) + 1;
        a = made.moved(float(low_x) * CELL, float(low_y) * CELL, float(levels[1]) * LIFT - 8.0);
        b = made.moved(float(high_x) * CELL, float(high_y) * CELL, float(levels[1]) * LIFT);
        owner = made.spaces[0];
        for ground in made.columns.get(cells[0], []) {
            owner = made.spaces[ground.space];
        }
        kit = kit_of(owner.district);
        item = MapItem(fields={"classname": "func_plat", "height": str((levels[1] - levels[0]) * int(LIFT)), "speed": "150"});
        item.brushes = [plain_box(Vec3(x=a[0], y=a[1], z=a[2]), Vec3(x=b[0], y=b[1], z=b[2]), kit.step, kit.scale)];
        casting.items.append(item);
    }
}

"""The way out where the original's was: a gate of light on the floor under
it, touched by a body's feet. A level whose way out was not found ends at
the ground furthest from the start."""
def cast_exit(made: Tracing, casting: Casting) {
    skeleton = made.skeleton;
    if skeleton is None {
        return;
    }
    target: Ground | None = None;
    box: AABB | None = None;
    for found in skeleton.exits {
        ground = ground_under(made, found);
        if ground is not None {
            target = ground;
            box = found;
        }
    }
    if target is None {
        for ground in skeleton_grounds(skeleton) {
            if target is None or ground.reach > target.reach {
                target = ground;
            }
        }
    }
    if target is None {
        return;
    }
    middle = made.moved((float(target.x) + 0.5) * CELL, (float(target.y) + 0.5) * CELL, float(target.z) * LIFT);
    floor = middle[2];
    low = [middle[0] - 32.0, middle[1] - 32.0];
    high = [middle[0] + 32.0, middle[1] + 32.0];
    if box is not None {
        a = made.moved(box.mins.x, box.mins.y, 0.0);
        b = made.moved(box.maxs.x, box.maxs.y, 0.0);
        low = [max(a[0], middle[0] - 64.0), max(a[1], middle[1] - 64.0)];
        high = [min(b[0], middle[0] + 64.0), min(b[1], middle[1] + 64.0)];
    }
    gate = MapItem(fields={"classname": "func_wall", "_passion": "exit"});
    gate.brushes = [plain_box(Vec3(x=low[0], y=low[1], z=floor), Vec3(x=high[0], y=high[1], z=floor + 8.0), TELEPORT_MATERIAL, 1.0)];
    casting.items.append(gate);
    casting.items.append(MapItem(fields={"classname": "light", "origin": origin_text((low[0] + high[0]) * 0.5, (low[1] + high[1]) * 0.5, floor + 56.0), "light": "300", "_color": "200 220 255"}));
    casting.exit_low = [low[0], low[1], floor + 2.0];
    casting.exit_high = [high[0], high[1], floor + 96.0];
}
