"""Blueprints: an original level read back as Passion builds levels, a grid
of cells 32 units across and 16 up, so its own stretches can be raised
again as prefabs.

Each cell of the grid is sampled at eight points against the level's own
BSP tree: solid, air, water, slime, lava or sky by what most of its points
are. The level's entities come with it, each brush entity with its brush
model's box.

The level is cut into regions (`Region` nodes, joined by `Cut` edges
through the doors between them) by its own level graph (its essence): the
places a body walks, jumps, rides and teleports between without passing
through a door are one region. Each open cell then goes to the region whose
places are nearest it through the air, so a room seen through a window
stays with the places that stand in it.

Only what is read from the player's own game files at run time is used;
nothing of the games is kept in the code."""
import math;
import from engine.math.vec3 { Vec3 }
import from engine.assets.pak { open_pak, PakArchive }
import from engine.assets.content { archive_paths, game_directory }
import from engine.world.level { asset }
import from engine.formats.q1.bsp { parse_bsp }
import from engine.formats.bsp { Bsp }
import from engine.level.graph { LevelGraph, Place, Move, Gate, graph_places, graph_gates, barred_places }
import from .massing { CELL, LIFT }
import from .essence { named_essence }

glob BP_SOLID: int = 0,
     BP_AIR: int = 1,
     BP_WATER: int = 2,
     BP_SLIME: int = 3,
     BP_LAVA: int = 4,
     BP_SKY: int = 5;

"""An entity of an original: its fields, its point (its origin, or the
middle of its brush model), and its brush model's box (empty for a point
entity)."""
obj Thing {
    has classname: str,
        fields: dict[str, str] = {},
        point: Vec3 = Vec3(),
        low: Vec3 = Vec3(),
        high: Vec3 = Vec3(),
        brush: bool = False,
        region: int = -1;
}

"""A stretch of an original between its doors: its cells, its box in
cells, and what it holds."""
node Region {
    has number: int,
        cells: int = 0,
        x0: int = 1 << 30,
        y0: int = 1 << 30,
        z0: int = 1 << 30,
        x1: int = -(1 << 30),
        y1: int = -(1 << 30),
        z1: int = -(1 << 30),
        start: bool = False,
        way_out: bool = False,
        things: list[int] = [];
}

"""A door between two regions (its things' indices in the blueprint)."""
edge Cut: Region --> Region {
    has doors: list[int] = [];
}

"""An original level as cells: the grid (`codes`, x fastest, then y, then
z), where its first cell lies in world cells, its entities, and the region
of each cell (-1 for none)."""
node Blueprint {
    has spec: str,
        game: str = "q1",
        ox: int = 0,
        oy: int = 0,
        oz: int = 0,
        nx: int = 0,
        ny: int = 0,
        nz: int = 0,
        codes: list[int] = [],
        regions: list[int] = [],
        things: list[Thing] = [],
        # Its essence, the level graph it was cut by, and the doors (by
        # model) that stand between two regions.
        atlas: LevelGraph | None = None,
        cuts: set[int] = set(),
        notes: list[str] = [];

    def index(x: int, y: int, z: int) -> int {
        return (z * self.ny + y) * self.nx + x;
    }

    def inside(x: int, y: int, z: int) -> bool {
        return 0 <= x < self.nx and 0 <= y < self.ny and 0 <= z < self.nz;
    }

    def code(x: int, y: int, z: int) -> int {
        if not self.inside(x, y, z) {
            return BP_SOLID;
        }
        return self.codes[self.index(x, y, z)];
    }

    """Whether a body can be in a cell (air or liquid)."""
    def open(x: int, y: int, z: int) -> bool {
        found = self.code(x, y, z);
        return found != BP_SOLID and found != BP_SKY;
    }

    """The cell a world point lies in, [x, y, z] in the grid's own cells."""
    def cell_of(point: Vec3) -> list[int] {
        return [int(math.floor(point.x / CELL)) - self.ox, int(math.floor(point.y / CELL)) - self.oy, int(math.floor(point.z / LIFT)) - self.oz];
    }

    """The region of the open cell nearest a world point (two cells round
    it at most), or -1."""
    def region_at(point: Vec3) -> int {
        at = self.cell_of(point);
        for reach in range(3) {
            for dz in range(-reach, reach + 1) {
                for dy in range(-reach, reach + 1) {
                    for dx in range(-reach, reach + 1) {
                        x = at[0] + dx;
                        y = at[1] + dy;
                        z = at[2] + dz;
                        if self.inside(x, y, z) and self.regions[self.index(x, y, z)] >= 0 {
                            return self.regions[self.index(x, y, z)];
                        }
                    }
                }
            }
        }
        return -1;
    }
}

edge Splits: Blueprint --> Region {}

"""A Quake leaf's contents as a blueprint code."""
def bp_code_of(contents: int) -> int {
    if contents == -1 {
        return BP_AIR;
    }
    if contents == -3 {
        return BP_WATER;
    }
    if contents == -4 {
        return BP_SLIME;
    }
    if contents == -5 {
        return BP_LAVA;
    }
    if contents == -6 {
        return BP_SKY;
    }
    return BP_SOLID;
}

"""The contents of the world at a point: down the BSP tree from the world
model's head to its leaf."""
def bp_leaf_contents(bsp: Bsp, head: int, x: float, y: float, z: float) -> int {
    at = head;
    while at >= 0 {
        branch = bsp.branches[at];
        plane = bsp.planes[branch.plane];
        side = plane.normal.x * x + plane.normal.y * y + plane.normal.z * z - plane.distance;
        at = branch.front if side >= 0.0 else branch.back;
    }
    return bsp.leaves[-at - 1].contents;
}

"""A world point as a map field's three numbers."""
def bp_vector(text: str) -> Vec3 {
    words = text.split();
    if len(words) != 3 {
        return Vec3();
    }
    return Vec3(x=float(words[0]), y=float(words[1]), z=float(words[2]));
}

"""Read an original (`game:map`, Quake's for now) from the player's files
as a blueprint: its cells, its entities, and its regions."""
def read_blueprint(spec: str) -> Blueprint {
    parts = spec.split(":");
    game = parts[0];
    if game != "q1" {
        raise ValueError("Blueprints read Quake's levels only for now, not " + spec);
    }
    directory = game_directory(game);
    paks: list[PakArchive] = [];
    for path in archive_paths(directory, ".pak") {
        paks.append(open_pak(path));
    }
    bsp = parse_bsp(asset(paks, "maps/" + parts[1] + ".bsp", directory));
    world_model = bsp.models[0];
    ox = int(math.floor(world_model.mins.x / CELL)) - 1;
    oy = int(math.floor(world_model.mins.y / CELL)) - 1;
    oz = int(math.floor(world_model.mins.z / LIFT)) - 1;
    nx = int(math.ceil(world_model.maxs.x / CELL)) + 1 - ox;
    ny = int(math.ceil(world_model.maxs.y / CELL)) + 1 - oy;
    nz = int(math.ceil(world_model.maxs.z / LIFT)) + 1 - oz;
    made = Blueprint(spec=spec, game=game, ox=ox, oy=oy, oz=oz, nx=nx, ny=ny, nz=nz);
    made.codes = [BP_SOLID for _ in range(nx * ny * nz)];
    head = world_model.head;
    # Eight points a cell, a quarter in from each side.
    offsets: list[list[float]] = [];
    for fz in [0.25, 0.75] {
        for fy in [0.25, 0.75] {
            for fx in [0.25, 0.75] {
                offsets.append([fx * CELL, fy * CELL, fz * LIFT]);
            }
        }
    }
    for z in range(nz) {
        wz = float(oz + z) * LIFT;
        for y in range(ny) {
            wy = float(oy + y) * CELL;
            for x in range(nx) {
                wx = float(ox + x) * CELL;
                counts = [0, 0, 0, 0, 0, 0];
                for offset in offsets {
                    counts[bp_code_of(bp_leaf_contents(bsp, head, wx + offset[0], wy + offset[1], wz + offset[2]))] += 1;
                }
                opened = counts[BP_AIR] + counts[BP_WATER] + counts[BP_SLIME] + counts[BP_LAVA];
                code = BP_SOLID;
                if opened >= 4 {
                    code = BP_AIR;
                    wet = counts[BP_WATER] + counts[BP_SLIME] + counts[BP_LAVA];
                    if wet >= counts[BP_AIR] {
                        code = BP_WATER;
                        if counts[BP_SLIME] >= counts[code] {
                            code = BP_SLIME;
                        }
                        if counts[BP_LAVA] >= counts[code] {
                            code = BP_LAVA;
                        }
                    }
                } elif counts[BP_SKY] > 0 and counts[BP_SKY] >= counts[BP_SOLID] {
                    code = BP_SKY;
                }
                made.codes[(z * ny + y) * nx + x] = code;
            }
        }
    }
    for entity in bsp.entities {
        fields = dict(entity.fields);
        kind = fields.get("classname", "");
        thing = Thing(classname=kind, fields=fields);
        model = fields.get("model", "");
        if model.startswith("*") and model[1:].isdigit() and int(model[1:]) < len(bsp.models) {
            record = bsp.models[int(model[1:])];
            shift = bp_vector(fields.get("origin", "0 0 0"));
            thing.low = record.mins.add(shift);
            thing.high = record.maxs.add(shift);
            thing.point = Vec3(x=(thing.low.x + thing.high.x) * 0.5, y=(thing.low.y + thing.high.y) * 0.5, z=(thing.low.z + thing.high.z) * 0.5);
            thing.brush = True;
        } else {
            thing.point = bp_vector(fields.get("origin", "0 0 0"));
        }
        made.things.append(thing);
    }
    atlas = named_essence(spec);
    if atlas is None {
        raise ValueError("No essence of " + spec + " could be read");
    }
    made.atlas = atlas;
    split_regions(made, atlas);
    return made;
}

"""Whether a thing is a door the level is cut at: a sliding door (not a
secret one) whose model is one of `cut` (the essence's doors that are
doorways)."""
def bp_cut_door(thing: Thing, cut: set[int]) -> bool {
    model = thing.fields.get("model", "");
    return thing.brush and thing.classname == "func_door" and model[1:].isdigit() and int(model[1:]) in cut;
}

"""The essence's doors a level is cut at: its doors that bar a doorway (not
a floor that lowers, a lift, a bridge or a secret wall)."""
def bp_doorways(atlas: LevelGraph) -> set[int] {
    found: set[int] = set();
    for gate in graph_gates(atlas) {
        if gate.kind == "door" and not gate.lowers() {
            found.add(gate.model);
        }
    }
    return found;
}

"""The open cells a brush thing's box takes in (any part of the cell), in
the grid's cells."""
def bp_thing_cells(made: Blueprint, thing: Thing) -> list[list[int]] {
    found: list[list[int]] = [];
    x0 = int(math.floor((thing.low.x + 1.0) / CELL)) - made.ox;
    y0 = int(math.floor((thing.low.y + 1.0) / CELL)) - made.oy;
    z0 = int(math.floor((thing.low.z + 1.0) / LIFT)) - made.oz;
    x1 = int(math.ceil((thing.high.x - 1.0) / CELL)) - made.ox;
    y1 = int(math.ceil((thing.high.y - 1.0) / CELL)) - made.oy;
    z1 = int(math.ceil((thing.high.z - 1.0) / LIFT)) - made.oz;
    for z in range(z0, z1) {
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                if made.open(x, y, z) {
                    found.append([x, y, z]);
                }
            }
        }
    }
    return found;
}

glob BP_REGION_LEAST: int = 40;

"""The group a place is in (union and find over `owner`)."""
def bp_root(owner: dict[int, int], area: int) -> int {
    at = area;
    while owner[at] != at {
        owner[at] = owner[owner[at]];
        at = owner[at];
    }
    return at;
}

"""Cut a blueprint into regions by its essence: the places joined by moves
that pass no doorway (`bp_doorways`) are one region, and each open cell,
flooded from the places outward a cell a step and never through a door,
goes to the region that reaches it first. The doors between two regions are
`Cut` edges."""
def split_regions(made: Blueprint, atlas: LevelGraph) {
    count = made.nx * made.ny * made.nz;
    made.regions = [-1 for _ in range(count)];
    cut = bp_doorways(atlas);
    blocked: dict[int, int] = {};
    for (number, thing) in enumerate(made.things) {
        if bp_cut_door(thing, cut) {
            for cell in bp_thing_cells(made, thing) {
                blocked[made.index(cell[0], cell[1], cell[2])] = number;
            }
        }
    }
    # The places in doorways belong to no region.
    places = graph_places(atlas);
    doorway: set[int] = set();
    for gate in graph_gates(atlas) {
        if gate.model in cut {
            for place in barred_places(gate) {
                doorway.add(place.area);
            }
        }
    }
    owner: dict[int, int] = {};
    for place in places {
        owner[place.area] = place.area;
    }
    for place in places {
        if place.area in doorway {
            continue;
        }
        for move in [edge place->:Move:->] {
            if move.gate in cut or move.to in doorway or move.to not in owner {
                continue;
            }
            a = bp_root(owner, place.area);
            b = bp_root(owner, move.to);
            if a != b {
                owner[a] = b;
            }
        }
    }
    # Each group of places is a region, seeded at the cells its places
    # stand in.
    labels: dict[int, int] = {};
    sizes: list[int] = [];
    todo: list[int] = [];
    for place in places {
        if place.area in doorway {
            continue;
        }
        group = bp_root(owner, place.area);
        if group not in labels {
            labels[group] = len(labels);
            sizes.append(0);
        }
        label = labels[group];
        sizes[label] += 1;
        # The place's floor patch and the room over it, up to its roof (ten
        # lifts at most).
        corner = made.cell_of(Vec3(x=place.box.mins.x + 1.0, y=place.box.mins.y + 1.0, z=place.floor + 8.0));
        across = made.cell_of(Vec3(x=place.box.maxs.x - 1.0, y=place.box.maxs.y - 1.0, z=place.floor + 8.0 + min(place.roof, 160.0)));
        for z in range(corner[2], across[2] + 1) {
            for y in range(corner[1], across[1] + 1) {
                for x in range(corner[0], across[0] + 1) {
                    if not made.open(x, y, z) {
                        continue;
                    }
                    index = made.index(x, y, z);
                    if made.regions[index] < 0 and index not in blocked {
                        made.regions[index] = label;
                        todo.append(index);
                    }
                }
            }
        }
    }
    head = 0;
    while head < len(todo) {
        index = todo[head];
        head += 1;
        label = made.regions[index];
        x = index % made.nx;
        y = (index // made.nx) % made.ny;
        z = index // (made.nx * made.ny);
        for (dx, dy, dz) in [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)] {
            cx = x + dx;
            cy = y + dy;
            cz = z + dz;
            if not made.open(cx, cy, cz) {
                continue;
            }
            other = made.index(cx, cy, cz);
            if made.regions[other] < 0 and other not in blocked {
                made.regions[other] = label;
                todo.append(other);
            }
        }
    }
    regions: list[Region] = [];
    sizes = [0 for _ in sizes];
    for index in range(count) {
        if made.regions[index] >= 0 {
            sizes[made.regions[index]] += 1;
        }
    }
    # Regions too small to be a stretch (pockets, the gaps round a door)
    # belong to none; the rest are renumbered in order.
    renumber: dict[int, int] = {};
    for (old, size) in enumerate(sizes) {
        if size >= BP_REGION_LEAST {
            renumber[old] = len(regions);
            regions.append(Region(number=len(regions)));
        }
    }
    for index in range(count) {
        old = made.regions[index];
        if old < 0 {
            continue;
        }
        if old not in renumber {
            made.regions[index] = -1;
            continue;
        }
        fresh = renumber[old];
        made.regions[index] = fresh;
        region = regions[fresh];
        x = index % made.nx;
        y = (index // made.nx) % made.ny;
        z = index // (made.nx * made.ny);
        region.cells += 1;
        region.x0 = min(region.x0, x);
        region.y0 = min(region.y0, y);
        region.z0 = min(region.z0, z);
        region.x1 = max(region.x1, x + 1);
        region.y1 = max(region.y1, y + 1);
        region.z1 = max(region.z1, z + 1);
    }
    for region in regions {
        made +>:Splits:+> region;
    }
    for (number, thing) in enumerate(made.things) {
        if bp_cut_door(thing, cut) {
            continue;
        }
        thing.region = made.region_at(thing.point);
        if thing.region >= 0 {
            regions[thing.region].things.append(number);
            if thing.classname == "info_player_start" {
                regions[thing.region].start = True;
            }
            if thing.classname == "trigger_changelevel" {
                regions[thing.region].way_out = True;
            }
        }
    }
    # Each door joins the regions its cells lie beside.
    for (number, thing) in enumerate(made.things) {
        if not bp_cut_door(thing, cut) {
            continue;
        }
        # The regions its cells touch, the two it touches most when more
        # (a room over a doorway touches it too).
        touches: dict[int, int] = {};
        for cell in bp_thing_cells(made, thing) {
            for (dx, dy, dz) in [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)] {
                cx = cell[0] + dx;
                cy = cell[1] + dy;
                cz = cell[2] + dz;
                if made.inside(cx, cy, cz) {
                    found = made.regions[made.index(cx, cy, cz)];
                    if found >= 0 {
                        touches[found] = touches.get(found, 0) + 1;
                    }
                }
            }
        }
        beside: list[int] = [];
        for found in touches.keys() {
            beside.append(found);
        }
        # Most touched first (a few at most, so sorted by hand).
        for index in range(len(beside)) {
            for later in range(index + 1, len(beside)) {
                if touches[beside[later]] > touches[beside[index]] {
                    held = beside[index];
                    beside[index] = beside[later];
                    beside[later] = held;
                }
            }
        }
        beside = beside[:2];
        thing.region = beside[0] if len(beside) == 1 else -1;
        # A door with the same region on both sides of it (or none beside
        # it, then the region nearest its middle) is a door within that
        # region: its cells are the region's air, and it stands there as the
        # original's did.
        inner = beside[0] if len(beside) == 1 else (made.region_at(thing.point) if not beside else -1);
        if inner >= 0 {
            thing.region = inner;
            for cell in bp_thing_cells(made, thing) {
                made.regions[made.index(cell[0], cell[1], cell[2])] = inner;
                regions[inner].cells += 1;
            }
            regions[inner].things.append(number);
        }
        if len(beside) == 2 {
            model = thing.fields.get("model", "");
            made.cuts.add(int(model[1:]));
            low = min(beside[0], beside[1]);
            high = max(beside[0], beside[1]);
            joined = [edge regions[low]->:Cut:->regions[high]];
            if joined {
                joined[0].doors.append(number);
            } else {
                regions[low] +>:Cut(doors=[number]):+> regions[high];
            }
        } elif len(beside) > 2 {
            made.notes.append(thing.classname + " " + str(number) + " lies beside " + str(len(beside)) + " regions");
        }
    }
}

"""The regions of a blueprint, in order."""
def blueprint_regions(made: Blueprint) -> list[Region] {
    return [made->:Splits:->][?:Region];
}
