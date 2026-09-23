"""Room interiors on a 32-unit column grid.

Every room starts from a recipe footprint (hall, clipped, cross, court, cavern,
pit, balcony, terraces, arena). Socket landings are pinned to the heights the
layout solver chose, then a Lipschitz envelope turns any desired shape into a
walkable heightfield: adjacent columns never differ by more than one step
unless a feature deliberately makes a ledge, pit or cover block. Routes between
sockets and anchors are locked before decoration, cover is placed by a small
wave-function-collapse pass, and connectivity is verified before acceptance.
"""
import from .random { Stream }
import from .layout { Room, Socket, CELL, STEP }

glob SOLID: int = -100000;
glob CLEAR: int = 72;
glob CLIMB: int = 18;

obj Interior {
    has width: int,
        height: int,
        floor: list[int] = [],
        ceiling: list[int] = [],
        lock: list[bool] = [],
        liquid: list[int] = [],
        surface: list[int] = [],
        cover: list[int] = [],
        landings: list[int] = [],
        stage: int = -1,
        perches: list[int] = [],
        spots: list[int] = [],
        lamps: list[int] = [],
        recipe: str = "hall",
        pit_depth: int = 0;

    def index(x: int, y: int) -> int {
        return y * self.width + x;
    }

    def inside(x: int, y: int) -> bool {
        return 0 <= x < self.width and 0 <= y < self.height;
    }

    def open(i: int) -> bool {
        return self.floor[i] != SOLID;
    }
}

def fill(count: int, value: int) -> list[int] {
    return [value for _ in range(count)];
}

def neighbors4(interior: Interior, i: int) -> list[int] {
    x = i % interior.width;
    y = i // interior.width;
    result: list[int] = [];
    if x + 1 < interior.width {
        result.append(i + 1);
    }
    if x > 0 {
        result.append(i - 1);
    }
    if y + 1 < interior.height {
        result.append(i + interior.width);
    }
    if y > 0 {
        result.append(i - interior.width);
    }
    return result;
}

# Landing columns: the CELL-1 wide mouth plus three columns of depth.
def landing_cells(interior: Interior, socket: Socket) -> list[int] {
    cells: list[int] = [];
    for along in range(socket.index * CELL, socket.index * CELL + CELL - 1) {
        for depth in range(3) {
            x = 0;
            y = 0;
            if socket.side == 0 {
                x = interior.width - 1 - depth;
                y = along;
            } elif socket.side == 1 {
                x = depth;
                y = along;
            } elif socket.side == 2 {
                x = along;
                y = interior.height - 1 - depth;
            } else {
                x = along;
                y = depth;
            }
            if interior.inside(x, y) {
                cells.append(interior.index(x, y));
            }
        }
    }
    return cells;
}

def mouth_cell(interior: Interior, socket: Socket) -> int {
    along = socket.index * CELL + (CELL - 1) // 2;
    if socket.side == 0 {
        return interior.index(interior.width - 1, along);
    }
    if socket.side == 1 {
        return interior.index(0, along);
    }
    if socket.side == 2 {
        return interior.index(along, interior.height - 1);
    }
    return interior.index(along, 0);
}

def neighbors8(interior: Interior, i: int) -> list[int] {
    x = i % interior.width;
    y = i // interior.width;
    result: list[int] = [];
    for dy in range(-1, 2) {
        for dx in range(-1, 2) {
            if (dx != 0 or dy != 0) and interior.inside(x + dx, y + dy) {
                result.append((y + dy) * interior.width + x + dx);
            }
        }
    }
    return result;
}

# ---------------------------------------------------------------------------
# Footprints
# ---------------------------------------------------------------------------

def footprint(interior: Interior, recipe: str, stream: Stream) -> list[bool] {
    w = interior.width;
    h = interior.height;
    mask = [True for _ in range(w * h)];
    if recipe == "clipped" {
        cut = max(2, min(w, h) // 4);
        for y in range(h) {
            for x in range(w) {
                dx = min(x, w - 1 - x);
                dy = min(y, h - 1 - y);
                if dx + dy < cut {
                    mask[y * w + x] = False;
                }
            }
        }
    } elif recipe == "cross" {
        arm_x = max(4, w // 3);
        arm_y = max(4, h // 3);
        for y in range(h) {
            for x in range(w) {
                in_x = arm_x <= x < w - arm_x;
                in_y = arm_y <= y < h - arm_y;
                if not in_x and not in_y {
                    mask[y * w + x] = False;
                }
            }
        }
    } elif recipe == "court" {
        ring = max(4, min(w, h) // 3);
        for y in range(ring, h - ring) {
            for x in range(ring, w - ring) {
                mask[y * w + x] = False;
            }
        }
    } elif recipe == "cavern" {
        # Cellular automata: noisy fill, then smoothing into organic walls.
        for i in range(w * h) {
            mask[i] = stream.chance(0.58);
        }
        for step in range(4) {
            nxt = list(mask);
            for y in range(h) {
                for x in range(w) {
                    walls = 0;
                    for dy in range(-1, 2) {
                        for dx in range(-1, 2) {
                            nx = x + dx;
                            ny = y + dy;
                            if nx < 0
                                or ny < 0
                                or nx >= w
                                or ny >= h
                                or not mask[ny * w + nx] {
                                walls += 1;
                            }
                        }
                    }
                    nxt[y * w + x] = walls < 5;
                }
            }
            mask = nxt;
        }
        # A guaranteed core keeps the blob in one piece.
        for y in range(h // 4, h - h // 4) {
            for x in range(w // 4, w - w // 4) {
                mask[y * w + x] = True;
            }
        }
    }
    return mask;
}

# Carve straight channels from every landing to the core so a footprint can
# never isolate a socket.
def connect_mask(interior: Interior, mask: list[bool], sockets: list[Socket]) {
    cx = interior.width // 2;
    cy = interior.height // 2;
    for socket in sockets {
        start = mouth_cell(interior, socket);
        x = start % interior.width;
        y = start // interior.width;
        for cell in landing_cells(interior, socket) {
            mask[cell] = True;
        }
        guard = 0;
        while (x != cx or y != cy) and guard < 400 {
            guard += 1;
            for dy in range(-1, 3) {
                for dx in range(-1, 3) {
                    if interior.inside(x + dx, y + dy) {
                        mask[interior.index(x + dx, y + dy)] = True;
                    }
                }
            }
            if socket.side in [0, 1] {
                if x != cx {
                    x += 1 if cx > x else -1;
                } else {
                    y += 1 if cy > y else -1;
                }
            } else {
                if y != cy {
                    y += 1 if cy > y else -1;
                } else {
                    x += 1 if cx > x else -1;
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Height fields
# ---------------------------------------------------------------------------

# Geodesic Lipschitz envelope: the largest field no higher than `desired` whose
# neighbors (diagonals included, so any 2x2 hull footprint spans at most one
# step) differ by at most one step, with pinned cells kept exactly.
def lipschitz(
    interior: Interior, desired: list[int], pinned: dict[int, int]
) -> list[int] {
    n = len(desired);
    field = list(desired);
    for key in pinned {
        field[key] = pinned[key];
    }
    # Lower bounds from pins keep the downward pass from undercutting them.
    lower = fill(n, -1000000);
    queue: list[int] = [];
    for key in pinned {
        lower[key] = pinned[key];
        queue.append(key);
    }
    cursor = 0;
    while cursor < len(queue) {
        i = queue[cursor];
        cursor += 1;
        for j in neighbors8(interior, i) {
            if not interior.open(j) {
                continue;
            }
            candidate = lower[i] - STEP;
            if candidate > lower[j] {
                lower[j] = candidate;
                queue.append(j);
            }
        }
    }
    for i in range(n) {
        if interior.open(i) and field[i] < lower[i] {
            field[i] = lower[i];
        }
    }
    # Downward chamfer relaxation: field_i <= field_j + STEP.
    changed = True;
    rounds = 0;
    while changed and rounds < 400 {
        changed = False;
        rounds += 1;
        for i in range(n) {
            if not interior.open(i) {
                continue;
            }
            for j in neighbors8(interior, i) {
                if interior.open(j) and field[i] > field[j] + STEP {
                    field[i] = field[j] + STEP;
                    changed = True;
                }
            }
        }
    }
    return field;
}

def desired_field(
    interior: Interior, recipe: str, stream: Stream, span: int
) -> list[int] {
    w = interior.width;
    h = interior.height;
    desired = fill(w * h, 0);
    if span <= 0 {
        return desired;
    }
    if recipe == "terraces" {
        bands = 2 + stream.below(2);
        horizontal = stream.chance(0.5);
        for y in range(h) {
            for x in range(w) {
                t = float(x) / float(max(1, w - 1))
                    if horizontal
                    else float(y) / float(max(1, h - 1));
                level = int(t * float(bands) - 0.0001);
                desired[y * w + x] = (level * span // max(1, bands - 1)) // STEP * STEP;
            }
        }
    } elif recipe == "balcony" {
        ring = 3 + stream.below(2);
        for y in range(h) {
            for x in range(w) {
                rim = min(min(x, w - 1 - x), min(y, h - 1 - y));
                if rim < ring {
                    desired[y * w + x] = span;
                }
            }
        }
    } elif recipe == "cavern" {
        phase_x = stream.uniform(0.0, 6.0);
        phase_y = stream.uniform(0.0, 6.0);
        for y in range(h) {
            for x in range(w) {
                wave = triangle(float(x) * 0.21 + phase_x)
                    + triangle(float(y) * 0.17 + phase_y);
                desired[y * w + x] = int(wave * 0.5 * float(span)) // STEP * STEP;
            }
        }
    } elif recipe == "split" {
        horizontal = stream.chance(0.5);
        for y in range(h) {
            for x in range(w) {
                far = x >= w // 2 if horizontal else y >= h // 2;
                desired[y * w + x] = span if far else 0;
            }
        }
    }
    return desired;
}

def triangle(value: float) -> float {
    t = value - float(int(value / 2.0)) * 2.0;
    if t < 0.0 {
        t += 2.0;
    }
    return t if t < 1.0 else 2.0 - t;
}

# ---------------------------------------------------------------------------
# Walkability
# ---------------------------------------------------------------------------

def walkable(interior: Interior, a: int, b: int) -> bool {
    if not interior.open(a) or not interior.open(b) {
        return False;
    }
    if interior.cover[a] != 0 or interior.cover[b] != 0 {
        return False;
    }
    if abs(interior.floor[a] - interior.floor[b]) > CLIMB {
        return False;
    }
    top = min(interior.ceiling[a], interior.ceiling[b]);
    return top - max(interior.floor[a], interior.floor[b]) >= CLEAR;
}

def reach_from(interior: Interior, start: int) -> list[bool] {
    seen = [False for _ in range(interior.width * interior.height)];
    if start < 0 or not interior.open(start) {
        return seen;
    }
    seen[start] = True;
    queue = [start];
    cursor = 0;
    while cursor < len(queue) {
        i = queue[cursor];
        cursor += 1;
        for j in neighbors4(interior, i) {
            if not seen[j] and walkable(interior, i, j) {
                seen[j] = True;
                queue.append(j);
            }
        }
    }
    return seen;
}

# Breadth-first route over walkable columns; used to lock traffic lanes.
def lane(interior: Interior, start: int, finish: int) -> list[int] {
    parent: dict[int, int] = {start: -1};
    queue = [start];
    cursor = 0;
    while cursor < len(queue) and finish not in parent {
        i = queue[cursor];
        cursor += 1;
        for j in neighbors4(interior, i) {
            if j not in parent and walkable(interior, i, j) {
                parent[j] = i;
                queue.append(j);
            }
        }
    }
    if finish not in parent {
        return [];
    }
    result: list[int] = [];
    cursor = finish;
    while cursor >= 0 {
        result.append(cursor);
        cursor = parent[cursor];
    }
    return result;
}

def lock_lane(interior: Interior, cells: list[int]) {
    for i in cells {
        for j in [i] + neighbors4(interior, i) {
            interior.lock[j] = True;
            for k in neighbors4(interior, j) {
                interior.lock[k] = True;
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Features
# ---------------------------------------------------------------------------

def free_rect(interior: Interior, x0: int, y0: int, w: int, h: int) -> bool {
    for y in range(y0, y0 + h) {
        for x in range(x0, x0 + w) {
            if not interior.inside(x, y) {
                return False;
            }
            i = interior.index(x, y);
            if interior.lock[i] or not interior.open(i) {
                return False;
            }
        }
    }
    return True;
}

# A raised block with stairs down one side: sniper perch or key dais.
def raise_platform(
    interior: Interior, x0: int, y0: int, w: int, h: int, rise: int, stair_side: int
) -> bool {
    if not free_rect(interior, x0, y0, w, h) {
        return False;
    }
    base = interior.floor[interior.index(x0, y0)];
    for y in range(y0, y0 + h) {
        for x in range(x0, x0 + w) {
            if interior.floor[interior.index(x, y)] != base {
                return False;
            }
        }
    }
    top = base + rise;
    for y in range(y0, y0 + h) {
        for x in range(x0, x0 + w) {
            interior.floor[interior.index(x, y)] = top;
        }
    }
    steps = rise // STEP;
    for s in range(1, steps) {
        level = top - s * STEP;
        for k in range(3) {
            x = 0;
            y = 0;
            if stair_side == 0 {
                x = x0 + w - 1 + s;
                y = y0 + h // 2 - 1 + k;
            } elif stair_side == 1 {
                x = x0 - s;
                y = y0 + h // 2 - 1 + k;
            } elif stair_side == 2 {
                x = x0 + w // 2 - 1 + k;
                y = y0 + h - 1 + s;
            } else {
                x = x0 + w // 2 - 1 + k;
                y = y0 - s;
            }
            if interior.inside(x, y) {
                i = interior.index(x, y);
                if interior.open(i) and interior.floor[i] < level {
                    interior.floor[i] = level;
                }
            }
        }
    }
    return True;
}

def sink_pit(
    interior: Interior, x0: int, y0: int, w: int, h: int, depth: int, liquid: int
) -> bool {
    if not free_rect(interior, x0, y0, w, h) {
        return False;
    }
    base = interior.floor[interior.index(x0, y0)];
    for y in range(y0, y0 + h) {
        for x in range(x0, x0 + w) {
            i = interior.index(x, y);
            interior.floor[i] = base - depth;
            interior.liquid[i] = liquid;
            interior.surface[i] = base - 24;
        }
    }
    # Stairs inside one pit wall let anything that falls in climb back out.
    steps = depth // STEP;
    for s in range(steps - 1) {
        for k in range(3) {
            x = x0 + s;
            y = y0 + h // 2 - 1 + k;
            if interior.inside(x, y) and x < x0 + w {
                i = interior.index(x, y);
                interior.floor[i] = base - STEP * (s + 1);
            }
        }
    }
    interior.pit_depth = depth;
    return True;
}

# Tiled cover via wave-function collapse: 2x2 column tiles with adjacency rules
# (pillars never touch, crates cluster, walls of cover stay broken by gaps).
glob TILES: list[str] = ["empty", "crate", "tall", "pillar"];

def compatible(a: int, b: int) -> bool {
    if a == 3 and b == 3 {
        return False;
    }
    if (a == 3 and b == 2) or (a == 2 and b == 3) {
        return False;
    }
    return True;
}

def collapse_cover(
    interior: Interior, stream: Stream, density: float, style: int
) -> int {
    tw = interior.width // 2;
    th = interior.height // 2;
    count = tw * th;
    weights = [1.0 - density, density * 0.55, density * 0.25, density * 0.2];
    if style == 1 {
        weights = [1.0 - density, density * 0.2, density * 0.2, density * 0.6];
    } elif style == 2 {
        weights = [1.0 - density, density * 0.75, density * 0.25, 0.0];
    }
    options: list[list[bool]] = [];
    for t in range(count) {
        x = (t % tw) * 2;
        y = (t // tw) * 2;
        usable = free_rect(interior, x, y, 2, 2);
        if usable {
            base = interior.floor[interior.index(x, y)];
            for dy in range(2) {
                for dx in range(2) {
                    if interior.floor[interior.index(x + dx, y + dy)] != base {
                        usable = False;
                    }
                }
            }
        }
        options.append([True, usable, usable, usable]);
    }
    for attempt in range(4) {
        state = [list(option) for option in options];
        failed = False;
        for iteration in range(count) {
            # Lowest entropy first; ties broken by the stream.
            best = -1;
            best_count = 99;
            for t in range(count) {
                open_count = len(
                    [
                        o
                        for o in state[t]
                        if o
                    ]
                );
                if open_count > 1 and open_count < best_count {
                    best = t;
                    best_count = open_count;
                }
            }
            if best < 0 {
                break;
            }
            weighted = [weights[k] if state[best][k] else 0.0 for k in range(4)];
            if sum(weighted) <= 0.0 {
                weighted = [1.0 if state[best][k] else 0.0 for k in range(4)];
            }
            pick = stream.weighted(weighted);
            state[best] = [k == pick for k in range(4)];
            # Propagate adjacency constraints.
            queue = [best];
            cursor = 0;
            while cursor < len(queue) {
                t = queue[cursor];
                cursor += 1;
                tx = t % tw;
                ty = t // tw;
                for delta in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
                    nx = tx + delta[0];
                    ny = ty + delta[1];
                    if nx < 0 or ny < 0 or nx >= tw or ny >= th {
                        continue;
                    }
                    u = ny * tw + nx;
                    changed = False;
                    for k in range(4) {
                        if not state[u][k] {
                            continue;
                        }
                        supported = False;
                        for m in range(4) {
                            if state[t][m] and compatible(m, k) {
                                supported = True;
                            }
                        }
                        if not supported {
                            state[u][k] = False;
                            changed = True;
                        }
                    }
                    if not any(state[u]) {
                        failed = True;
                    }
                    if changed {
                        queue.append(u);
                    }
                }
            }
            if failed {
                break;
            }
        }
        if failed {
            continue;
        }
        placed = 0;
        for t in range(count) {
            kind = 0;
            for k in range(4) {
                if state[t][k] {
                    kind = k;
                }
            }
            if state[t][0] {
                kind = 0;
            }
            if kind == 0 {
                continue;
            }
            x = (t % tw) * 2;
            y = (t // tw) * 2;
            for dy in range(2) {
                for dx in range(2) {
                    interior.cover[interior.index(x + dx, y + dy)] = kind;
                }
            }
            placed += 1;
        }
        return placed;
    }
    return 0;
}

# ---------------------------------------------------------------------------
# Recipe selection and assembly
# ---------------------------------------------------------------------------

def choose_recipe(room: Room, stream: Stream, sockets: list[Socket]) -> str {
    spread = 0;
    for socket in sockets {
        spread = max(spread, socket.offset);
    }
    if room.kind in ["start", "goal", "cache"] {
        return ["hall", "clipped"][stream.below(2)];
    }
    options = [
        "hall",
        "clipped",
        "cross",
        "court",
        "cavern",
        "pit",
        "balcony",
        "terraces",
        "split",
        "arena",
        "colonnade"
    ];
    weights = [1.0, 1.0, 0.7, 0.6, 0.8, 0.8, 0.8, 0.6, 0.5, 0.0, 0.8];
    if room.size >= 3 {
        weights[9] = 2.5;
        weights[3] = 1.2;
        weights[5] = 1.4;
        weights[6] = 1.2;
    }
    if room.size <= 1 {
        weights[3] = 0.0;
        weights[5] = 0.2;
        weights[6] = 0.2;
    }
    if room.kind in ["arena", "guardian"] {
        weights[9] += 2.0;
    }
    if room.kind == "vista" {
        weights[6] += 1.5;
    }
    if spread > 0 {
        weights[7] += 1.0;
        weights[8] += 1.0;
        weights[4] += 0.5;
    }
    return options[stream.weighted(weights)];
}

def build_interior(
    room: Room, sockets: list[Socket], stream: Stream, district: int
) -> Interior {
    w = room.columns();
    h = room.rows();
    for attempt in range(6) {
        recipe = choose_recipe(room, stream, sockets) if attempt < 5 else "hall";
        interior = Interior(width=w, height=h, recipe=recipe);
        n = w * h;
        interior.floor = fill(n, 0);
        interior.ceiling = fill(n, 0);
        interior.lock = [False for _ in range(n)];
        interior.liquid = fill(n, 0);
        interior.surface = fill(n, 0);
        interior.cover = fill(n, 0);
        shape = recipe if recipe in ["clipped", "cross", "court", "cavern"] else "hall";
        mask = footprint(interior, shape, stream);
        connect_mask(interior, mask, sockets);
        for i in range(n) {
            if not mask[i] {
                interior.floor[i] = SOLID;
            }
        }
        pinned: dict[int, int] = {};
        for socket in sockets {
            for cell in landing_cells(interior, socket) {
                pinned[cell] = socket.offset;
            }
        }
        span = room.span;
        desired = desired_field(interior, recipe, stream, span);
        for i in range(n) {
            if not interior.open(i) {
                desired[i] = SOLID;
            }
        }
        field = lipschitz(interior, desired, pinned);
        conflict = False;
        for key in pinned {
            if field[key] != pinned[key] {
                conflict = True;
            }
        }
        if conflict {
            continue;
        }
        for i in range(n) {
            if interior.open(i) {
                interior.floor[i] = max(0, field[i]);
            }
        }
        top = 0;
        for i in range(n) {
            if interior.open(i) {
                top = max(top, interior.floor[i]);
            }
        }
        interior.landings = [mouth_cell(interior, socket) for socket in sockets];
        ceiling = top + room.ceiling;
        for i in range(n) {
            interior.ceiling[i] = ceiling;
        }
        # Lock lanes between sockets and to the room center before decorating.
        center = nearest_open(interior, interior.index(w // 2, h // 2));
        interior.stage = center;
        for landing in interior.landings {
            for cell in landing_cells_for(interior, landing, sockets) {
                interior.lock[cell] = True;
            }
            lock_lane(interior, lane(interior, landing, center));
        }
        decorate(interior, room, stream);
        if not verified(interior) {
            continue;
        }
        collect_spots(interior, room, stream);
        return interior;
    }
    raise ValueError("Room interior could not be connected");
}

def landing_cells_for(
    interior: Interior, landing: int, sockets: list[Socket]
) -> list[int] {
    for socket in sockets {
        if mouth_cell(interior, socket) == landing {
            return landing_cells(interior, socket);
        }
    }
    return [landing];
}

def nearest_open(interior: Interior, start: int) -> int {
    if interior.open(start) {
        return start;
    }
    seen: dict[int, bool] = {start: True};
    queue = [start];
    cursor = 0;
    while cursor < len(queue) {
        i = queue[cursor];
        cursor += 1;
        if interior.open(i) {
            return i;
        }
        for j in neighbors4(interior, i) {
            if j not in seen {
                seen[j] = True;
                queue.append(j);
            }
        }
    }
    return -1;
}

def:priv decorate(interior: Interior, room: Room, stream: Stream) {
    w = interior.width;
    h = interior.height;
    recipe = interior.recipe;
    stage = interior.stage;
    sx = stage % w;
    sy = stage // w;
    if room.kind in ["key", "switch", "goal"] {
        # A central dais presents the objective; the stage stays on top.
        size = 4;
        if raise_platform_centered(
            interior, sx, sy, size, 32 + STEP * stream.below(2), stream.below(4)
        ) {
            interior.stage = interior.index(sx, sy);
        }
    }
    if recipe == "pit" or (recipe == "arena" and stream.chance(0.35)) {
        liquid = 0;
        roll = stream.unit();
        if roll < 0.3 {
            liquid = 32;
        } elif roll < 0.5 {
            liquid = 16;
        } elif roll < 0.65 {
            liquid = 8;
        }
        pw = max(4, w // 3);
        ph = max(4, h // 3);
        for attempt in range(8) {
            x0 = stream.between(2, max(2, w - pw - 2));
            y0 = stream.between(2, max(2, h - ph - 2));
            if sink_pit(
                interior, x0, y0, pw, ph, 64 + STEP * stream.below(4), liquid
            ) {
                break;
            }
        }
    }
    if recipe in ["arena", "court", "balcony", "colonnade"] or room.size >= 3 {
        perches = 1 + stream.below(3);
        for p in range(perches) {
            for attempt in range(10) {
                pw = 3 + stream.below(3);
                ph = 3 + stream.below(3);
                x0 = stream.between(1, max(1, w - pw - 1));
                y0 = stream.between(1, max(1, h - ph - 1));
                rise = 64 + STEP * stream.below(3);
                if raise_platform(interior, x0, y0, pw, ph, rise, stream.below(4)) {
                    interior.perches.append(interior.index(x0 + pw // 2, y0 + ph // 2));
                    break;
                }
            }
        }
    }
    if recipe == "colonnade" {
        spacing = 4 + stream.below(2);
        for y in range(2, h - 2, spacing) {
            for x in range(2, w - 2, spacing) {
                if free_rect(interior, x, y, 2, 2) {
                    for dy in range(2) {
                        for dx in range(2) {
                            interior.cover[interior.index(x + dx, y + dy)] = 3;
                        }
                    }
                }
            }
        }
    } else {
        density = 0.08 + room.tension * 0.22;
        if room.kind in ["recovery", "vista", "start", "goal", "cache"] {
            density *= 0.4;
        }
        collapse_cover(interior, stream, density, stream.below(3));
    }
}

def raise_platform_centered(
    interior: Interior, cx: int, cy: int, size: int, rise: int, side: int
) -> bool {
    x0 = cx - size // 2;
    y0 = cy - size // 2;
    # The objective dais may occupy the locked center; clear its lock locally.
    saved: list[int] = [];
    for y in range(y0, y0 + size) {
        for x in range(x0, x0 + size) {
            if interior.inside(x, y) and interior.lock[interior.index(x, y)] {
                interior.lock[interior.index(x, y)] = False;
                saved.append(interior.index(x, y));
            }
        }
    }
    made = raise_platform(interior, x0, y0, size, size, rise, side);
    for i in saved {
        interior.lock[i] = True;
    }
    return made;
}

def verified(interior: Interior) -> bool {
    if not interior.landings {
        return True;
    }
    seen = reach_from(interior, interior.landings[0]);
    for landing in interior.landings {
        if not seen[landing] {
            return False;
        }
    }
    if interior.stage >= 0 and not seen[interior.stage] {
        return False;
    }
    return True;
}

def collect_spots(interior: Interior, room: Room, stream: Stream) {
    seen = reach_from(
        interior, interior.landings[0] if interior.landings else interior.stage
    );
    landing_zone: list[bool] = [False for _ in range(interior.width * interior.height)];
    for landing in interior.landings {
        lx = landing % interior.width;
        ly = landing // interior.width;
        for y in range(ly - 4, ly + 5) {
            for x in range(lx - 4, lx + 5) {
                if interior.inside(x, y) {
                    landing_zone[interior.index(x, y)] = True;
                }
            }
        }
    }
    candidates: list[int] = [];
    for y in range(1, interior.height - 1, 2) {
        for x in range(1, interior.width - 1, 2) {
            i = interior.index(x, y);
            if seen[i]
                and not landing_zone[i]
                and interior.liquid[i] == 0
                and interior.cover[i] == 0 {
                # Spots need a 3x3 clear standing area on one level.
                good = True;
                for j in neighbors4(interior, i) {
                    if not walkable(interior, i, j) {
                        good = False;
                    }
                }
                if good {
                    candidates.append(i);
                }
            }
        }
    }
    order = stream.order(len(candidates));
    interior.spots = [candidates[k] for k in order];
    interior.perches = [
        p
        for p in interior.perches
        if seen[p]
    ];
    # Lamps sit on a coarse grid over open space, avoiding solid cover.
    step = 8 if interior.width * interior.height > 500 else 7;
    for y in range(step // 2, interior.height, step) {
        for x in range(step // 2, interior.width, step) {
            i = interior.index(x, y);
            if interior.open(i) and interior.cover[i] != 3 {
                interior.lamps.append(i);
            }
        }
    }
    if not interior.lamps and interior.stage >= 0 {
        interior.lamps.append(interior.stage);
    }
}
