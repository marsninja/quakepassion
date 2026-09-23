"""Column blueprint: the whole expedition as a 32-unit heightfield.

Each column is solid or open; open columns carry a floor and a ceiling height.
Rooms contribute their interiors, corridors contribute stair slices, doors,
windows and ledges. Any column layout is watertight by construction when it is
compiled (see compile.jac), because walls and floor/ceiling pillars always
extend past every neighboring air interval.
"""
import from .random { Stream }
import from .mission { Expedition, Beat }
import from .layout {
    Site,
    Room,
    Passage,
    Socket,
    CELL,
    STEP,
    DROP_MIN,
    DROP_MAX,
    rooms_of,
    passages_of,
    unpack_x,
    unpack_y,
    direction
}
import from .interior { Interior, build_interior, SOLID }

glob WALL: int = -1;

obj Region {
    has id: int,
        kind: str = "room",
        beat: int = -1,
        link: int = -1,
        district: int = 0;
}

obj DoorSpec {
    has cells: list[int] = [],
        floor: int = 0,
        ceiling: int = 0,
        kind: str = "key",
        keys: list[str] = [],
        name: str = "",
        material: int = 0,
        across_x: bool = True,
        link: int = 0;
}

obj Volume {
    has low: list[float] = [],
        high: list[float] = [],
        kind: str = "once",
        target: str = "",
        fields: dict[str, str] = {};
}

obj Mark {
    has kind: str,
        x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        angle: float = 0.0,
        source: str = "q1",
        fields: dict[str, str] = {},
        beat: int = -1;
}

obj LampSpec {
    has x: float, y: float, z: float, color: int = 0, strength: float = 1.0, radius: float = 480.0;
}

obj Plate {
    has low: list[float] = [], high: list[float] = [], material: int = 0;
}

obj Blueprint {
    has width: int = 0,
        height: int = 0,
        floor: list[int] = [],
        ceiling: list[int] = [],
        region: list[int] = [],
        zone: list[int] = [],
        liquid: list[int] = [],
        surface: list[int] = [],
        style: list[int] = [],
        regions: list[Region] = [],
        doors: list[DoorSpec] = [],
        volumes: list[Volume] = [],
        marks: list[Mark] = [],
        lamps: list[LampSpec] = [],
        plates: list[Plate] = [],
        interiors: dict[int, Interior] = {},
        routes: dict[int, list[list[float]]] = {},
        corridor_ids: dict[int, int] = {};

    def index(x: int, y: int) -> int {
        return y * self.width + x;
    }

    def open(i: int) -> bool {
        return self.region[i] >= 0;
    }

    def carve(x: int, y: int, floor: int, ceiling: int, region: int, zone: int) {
        i = self.index(x, y);
        self.floor[i] = floor;
        self.ceiling[i] = ceiling;
        self.region[i] = region;
        self.zone[i] = zone;
    }
}

# Style codes select materials at compile time.
glob STYLE_PLAIN: int = 0;
glob STYLE_COVER: int = 1;
glob STYLE_STAIR: int = 2;
glob STYLE_WINDOW: int = 3;
glob STYLE_PILLAR: int = 4;
glob STYLE_PAD: int = 5;
glob STYLE_STAGE: int = 6;

def new_blueprint(site: Site) -> Blueprint {
    width = site.width * CELL + 1;
    height = site.height * CELL + 1;
    count = width * height;
    return Blueprint(
        width=width,
        height=height,
        floor=[0 for _ in range(count)],
        ceiling=[0 for _ in range(count)],
        region=[WALL for _ in range(count)],
        zone=[0 for _ in range(count)],
        liquid=[0 for _ in range(count)],
        surface=[0 for _ in range(count)],
        style=[0 for _ in range(count)]
    );
}

def room_origin(room: Room) -> list[int] {
    return [CELL * room.x + 1, CELL * room.y + 1];
}

def room_sockets(site: Site, room: Room) -> list[Socket] {
    result: list[Socket] = [];
    for passage in passages_of(site) {
        if passage.teleport {
            continue;
        }
        if passage.tail == room.beat {
            result.append(passage.tail_socket);
        }
        if passage.head == room.beat {
            result.append(passage.head_socket);
        }
    }
    return result;
}

def ceiling_for(room: Room, stream: Stream, verticality: float) -> int {
    base = [160, 192, 256, 320][min(3, room.size)];
    extra = STEP * stream.below(4 + int(verticality * 6.0));
    if room.kind in ["arena", "guardian", "hub"] {
        extra += 64;
    }
    return base + extra;
}

def carve_rooms(bp: Blueprint, site: Site, stream: Stream, verticality: float) -> bool {
    for room in rooms_of(site) {
        room.ceiling = ceiling_for(room, stream, verticality);
        sockets = room_sockets(site, room);
        interior: Interior | None = None;
        try {
            interior = build_interior(room, sockets, stream.child("room", room.beat), room.district);
        } except ValueError {
            return False;
        }
        if interior is None {
            return False;
        }
        region = len(bp.regions);
        bp.regions.append(Region(id=region, kind="room", beat=room.beat, district=room.district));
        origin = room_origin(room);
        for ly in range(interior.height) {
            for lx in range(interior.width) {
                li = interior.index(lx, ly);
                if not interior.open(li) {
                    continue;
                }
                floor = room.z + interior.floor[li];
                ceiling = room.z + interior.ceiling[li];
                x = origin[0] + lx;
                y = origin[1] + ly;
                cover = interior.cover[li];
                if cover == 3 {
                    # Pillars stay solid but keep the room's zone for materials.
                    i = bp.index(x, y);
                    bp.zone[i] = room.district;
                    bp.style[i] = STYLE_PILLAR;
                    continue;
                }
                bp.carve(x, y, floor, ceiling, region, room.district);
                i = bp.index(x, y);
                if cover == 1 {
                    bp.floor[i] = floor + 40;
                    bp.style[i] = STYLE_COVER;
                } elif cover == 2 {
                    bp.floor[i] = floor + 88;
                    bp.style[i] = STYLE_COVER;
                }
                if interior.liquid[li] != 0 {
                    bp.liquid[i] = interior.liquid[li];
                    bp.surface[i] = room.z + interior.surface[li];
                }
            }
        }
        bp.interiors[room.beat] = interior;
    }
    return True;
}

# ---------------------------------------------------------------------------
# Corridors as ordered slices. A slice is a set of columns sharing one floor.
# ---------------------------------------------------------------------------

obj Slice {
    has cells: list[list[int]] = [], line: bool = True, across_x: bool = True, travel: int = 0;
}

def strip(x0: int, y0: int, vertical: bool) -> Slice {
    # vertical=True: a column of CELL-1 cells at x0 spanning y0..y0+CELL-2.
    cells: list[list[int]] = [];
    for k in range(CELL - 1) {
        if vertical {
            cells.append([x0, y0 + k]);
        } else {
            cells.append([x0 + k, y0]);
        }
    }
    return Slice(cells=cells, line=True, across_x=not vertical);
}

# The boundary strip between a room and the macro cell outside its side.
def boundary_strip(room: Room, socket: Socket) -> Slice {
    if socket.side == 0 {
        return strip(CELL * (room.x + room.w), CELL * (room.y + socket.index) + 1, True);
    }
    if socket.side == 1 {
        return strip(CELL * room.x, CELL * (room.y + socket.index) + 1, True);
    }
    if socket.side == 2 {
        return strip(CELL * (room.x + socket.index) + 1, CELL * (room.y + room.h), False);
    }
    return strip(CELL * (room.x + socket.index) + 1, CELL * room.y, False);
}

def between_strip(a: int, b: int) -> Slice {
    ax = unpack_x(a);
    ay = unpack_y(a);
    bx = unpack_x(b);
    bcy = unpack_y(b);
    if bx > ax {
        return strip(CELL * bx, CELL * ay + 1, True);
    }
    if bx < ax {
        return strip(CELL * ax, CELL * ay + 1, True);
    }
    if bcy > ay {
        return strip(CELL * ax + 1, CELL * bcy, False);
    }
    return strip(CELL * ax + 1, CELL * ay, False);
}

def cell_slices(key: int, before: int, after: int) -> list[Slice] {
    cx = CELL * unpack_x(key) + 1;
    cy = CELL * unpack_y(key) + 1;
    if before != after {
        cells: list[list[int]] = [];
        for dy in range(CELL - 1) {
            for dx in range(CELL - 1) {
                cells.append([cx + dx, cy + dy]);
            }
        }
        return [Slice(cells=cells, line=False)];
    }
    result: list[Slice] = [];
    for k in range(CELL - 1) {
        # Order slices along the travel direction.
        step = k if before in [0, 2] else CELL - 2 - k;
        if before in [0, 1] {
            result.append(strip(cx + step, cy, True));
        } else {
            result.append(strip(cx, cy + step, False));
        }
    }
    return result;
}

def away(side: int) -> int {
    # Travel direction leaving a room through a socket on `side`.
    return side;
}

def toward(side: int) -> int {
    # Travel direction entering a room through its socket on `side`.
    return [1, 0, 3, 2][side];
}

def corridor_slices(site: Site, passage: Passage) -> list[Slice] {
    rooms = rooms_of(site);
    a = rooms[passage.tail];
    b = rooms[passage.head];
    if not passage.path {
        return [boundary_strip(a, passage.tail_socket)];
    }
    slices: list[Slice] = [boundary_strip(a, passage.tail_socket)];
    path = passage.path;
    for index in range(len(path)) {
        before = away(passage.tail_socket.side) if index == 0 else direction(path[index - 1], path[index]);
        after = toward(passage.head_socket.side) if index == len(path) - 1 else direction(path[index], path[index + 1]);
        slices.extend(cell_slices(path[index], before, after));
        if index < len(path) - 1 {
            slices.append(between_strip(path[index], path[index + 1]));
        }
    }
    slices.append(boundary_strip(b, passage.head_socket));
    return slices;
}

def slice_center(sl: Slice) -> list[float] {
    sx = 0.0;
    sy = 0.0;
    for cell in sl.cells {
        sx += float(cell[0]) + 0.5;
        sy += float(cell[1]) + 0.5;
    }
    return [sx / float(len(sl.cells)) * 32.0, sy / float(len(sl.cells)) * 32.0];
}

def carve_corridors(bp: Blueprint, site: Site, plan: Expedition, stream: Stream, beats: list[Beat]) -> bool {
    rooms = rooms_of(site);
    for passage in passages_of(site) {
        if passage.teleport or passage.window {
            continue;
        }
        a = rooms[passage.tail];
        b = rooms[passage.head];
        slices = corridor_slices(site, passage);
        start = a.z + passage.tail_socket.offset;
        end = b.z + passage.head_socket.offset;
        target_end = end;
        if passage.mode == "valve" {
            reach = STEP * len(slices);
            ledge = max(end + DROP_MIN, min(end + DROP_MAX, start));
            ledge = max(ledge, start - reach);
            ledge = min(ledge, start + reach);
            if ledge - end < DROP_MIN or ledge - end > DROP_MAX {
                return False;
            }
            target_end = ledge;
        }
        heights = stair_heights(start, target_end, len(slices), passage.mode == "valve");
        if not heights {
            return False;
        }
        district = a.district if a.order <= b.order else b.district;
        clearance = 128 + STEP * stream.below(3);
        region = len(bp.regions);
        bp.regions.append(Region(id=region, kind="corridor", link=passage.link, district=district));
        bp.corridor_ids[passage.link] = region;
        for index in range(len(slices)) {
            sl = slices[index];
            floor = heights[index];
            for cell in sl.cells {
                bp.carve(cell[0], cell[1], floor, floor + clearance, region, district);
                if index > 0 and heights[index - 1] != floor {
                    bp.style[bp.index(cell[0], cell[1])] = STYLE_STAIR;
                }
            }
        }
        place_doors(bp, passage, slices, heights, clearance, district, beats);
        # Route waypoints for playtesting and the director.
        waypoints: list[list[float]] = [];
        for index in range(len(slices)) {
            center = slice_center(slices[index]);
            waypoints.append([center[0], center[1], float(heights[index])]);
        }
        bp.routes[passage.link] = waypoints;
        corridor_lamps(bp, slices, heights, clearance, district, passage);
    }
    return True;
}


# Floors per slice: one step per slice at most, flat ends, valve ends on a ledge.
def stair_heights(start: int, finish: int, count: int, valve: bool) -> list[int] {
    steps = count + 1 if not valve else count;
    diff = finish - start;
    if abs(diff) > STEP * steps {
        return [];
    }
    result: list[int] = [];
    for index in range(count) {
        progress = float(index + 1) / float(steps);
        value = start + int(float(diff) * progress);
        value = (value // STEP) * STEP if diff >= 0 else -((-value) // STEP) * STEP;
        result.append(value);
    }
    if valve {
        result[-1] = finish;
    }
    # Repair any quantization overshoot so every step is legal.
    previous = start;
    for index in range(count) {
        if result[index] > previous + STEP {
            result[index] = previous + STEP;
        } elif result[index] < previous - STEP {
            result[index] = previous - STEP;
        }
        previous = result[index];
    }
    if valve and result[-1] != finish {
        return [];
    }
    if not valve and abs(result[-1] - finish) > STEP {
        return [];
    }
    return result;
}

# Doors occupy line slices, working back from the locked side. Keys share one
# door; every remote token (switch, relay, guardian) gets its own leaf.
def place_doors(bp: Blueprint, passage: Passage, slices: list[Slice], heights: list[int], clearance: int, district: int, beats: list[Beat]) {
    if passage.mode not in ["locked", "gate", "shortcut", "secret"] {
        return;
    }
    specs: list[DoorSpec] = [];
    if passage.mode == "shortcut" {
        specs.append(DoorSpec(kind="shortcut", name="short_" + str(passage.link), link=passage.link));
    } elif passage.mode == "secret" {
        specs.append(DoorSpec(kind="secret", name="secret_" + str(passage.link), link=passage.link));
    } else {
        keys = [token for token in passage.needs if token.startswith("key_")];
        if keys {
            specs.append(DoorSpec(kind="key", keys=keys, link=passage.link));
        }
        counter = 0;
        for token in passage.needs {
            if token.startswith("key_") {
                continue;
            }
            counter += 1;
            kind = "guardian" if token.startswith("guardian:") else "remote";
            specs.append(DoorSpec(kind=kind, keys=[token], name="gate_" + str(passage.link) + "_" + str(counter), link=passage.link));
        }
    }
    # Secret doors sit flush with the tail room's wall; the rest guard the head.
    positions: list[int] = [];
    if passage.mode == "secret" {
        positions = [0];
    } else {
        index = len(slices) - 1;
        while index >= 0 and len(positions) < len(specs) {
            if slices[index].line {
                positions.append(index);
                index -= 2;
            } else {
                index -= 1;
            }
        }
    }
    for k in range(min(len(specs), len(positions))) {
        spec = specs[k];
        sl = slices[positions[k]];
        spec.cells = [bp.index(cell[0], cell[1]) for cell in sl.cells];
        spec.floor = heights[positions[k]];
        spec.ceiling = heights[positions[k]] + clearance;
        spec.across_x = sl.across_x;
        spec.material = district;
        bp.doors.append(spec);
    }
    if len(positions) < len(specs) {
        # Not enough line slices: mark the passage so candidate selection rejects it.
        bp.doors.append(DoorSpec(kind="invalid", link=passage.link));
    }
}

def corridor_lamps(bp: Blueprint, slices: list[Slice], heights: list[int], clearance: int, district: int, passage: Passage) {
    spacing = 6;
    for index in range(2, len(slices) - 1, spacing) {
        center = slice_center(slices[index]);
        bp.lamps.append(
            LampSpec(
                x=center[0],
                y=center[1],
                z=float(heights[index] + clearance - 6),
                color=district,
                strength=0.9,
                radius=360.0
            )
        );
    }
}

# Sightline slots: impassable 40-unit slits between rooms joined by window links.
def carve_windows(bp: Blueprint, site: Site) {
    rooms = rooms_of(site);
    for passage in passages_of(site) {
        if not passage.window {
            continue;
        }
        a = rooms[passage.tail];
        b = rooms[passage.head];
        top_a = a.z + a.ceiling;
        top_b = b.z + b.ceiling;
        sill = max(a.z, b.z) + 72;
        lintel = sill + 40;
        if lintel > min(top_a, top_b) - 24 {
            continue;
        }
        region = len(bp.regions);
        bp.regions.append(Region(id=region, kind="window", link=passage.link, district=a.district));
        slices: list[Slice] = [boundary_strip(a, passage.tail_socket)];
        for index in range(len(passage.path)) {
            before = away(passage.tail_socket.side);
            slices.extend(cell_slices(passage.path[index], before, before));
            if index < len(passage.path) - 1 {
                slices.append(between_strip(passage.path[index], passage.path[index + 1]));
            }
        }
        slices.append(boundary_strip(b, passage.head_socket));
        for sl in slices {
            for k in range(1, len(sl.cells) - 1) {
                cell = sl.cells[k];
                i = bp.index(cell[0], cell[1]);
                if bp.open(i) {
                    continue;
                }
                bp.carve(cell[0], cell[1], sill, lintel, region, a.district);
                bp.style[i] = STYLE_WINDOW;
            }
        }
    }
}

def world_point(room: Room, cell: int, interior: Interior, lift: float) -> list[float] {
    origin = room_origin(room);
    lx = cell % interior.width;
    ly = cell // interior.width;
    return [
        float(origin[0] + lx) * 32.0 + 16.0,
        float(origin[1] + ly) * 32.0 + 16.0,
        float(room.z + interior.floor[cell]) + lift
    ];
}
