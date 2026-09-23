"""Graph-constrained spatial embedding of a mission.

Rooms are rectangles on a macro grid (CELL columns per macro cell, 32 units per
column). Rooms are placed in progression order beside already placed neighbors,
then every link is routed as an A* corridor through free macro cells. Links whose
corridors cannot be routed fall back to paired teleporters when their semantics
allow it. Floor heights are solved afterwards from stair capacity and ledge
constraints, so vertical structure follows the embedding instead of fighting it.
"""
import from .random { Stream }
import from .mission { Expedition, Beat, Link, beats_of, links_of }

glob CELL: int = 5;
glob UNIT: float = 32.0;
glob STEP: int = 16;
glob DROP_MIN: int = 80;
glob DROP_MAX: int = 208;
glob OFFSET: int = 2048;

node Site {
    has width: int = 0,
        height: int = 0,
        teleports: int = 0,
        windows: int = 0,
        failures: str = "";
}

node Room {
    has beat: int,
        kind: str = "room",
        x: int = 0,
        y: int = 0,
        w: int = 3,
        h: int = 3,
        z: int = 0,
        target: int = 0,
        ceiling: int = 256,
        district: int = 0,
        size: int = 1,
        tension: float = 0.0,
        optional: bool = False,
        grants: list[str] = [],
        recipe: str = "hall",
        pattern: str = "",
        order: int = 0,
        span: int = 0;

    def columns -> int {
        return CELL * self.w - 1;
    }

    def rows -> int {
        return CELL * self.h - 1;
    }

    def contains(cx: int, cy: int) -> bool {
        return self.x <= cx < self.x + self.w and self.y <= cy < self.y + self.h;
    }
}

# A socket is a macro position on a room boundary: side 0=+x 1=-x 2=+y 3=-y.
obj Socket {
    has side: int = 0, index: int = 0, offset: int = 0;
}

edge Hosts: Site --> Room {}

edge Realizes: Beat --> Room {}

edge Passage: Room --> Room {
    has link: int = 0,
        mode: str = "open",
        needs: list[str] = [],
        path: list[int] = [],
        teleport: bool = False,
        tail: int = 0,
        head: int = 0,
        tail_socket: Socket = Socket(),
        head_socket: Socket = Socket(),
        capacity: int = 0,
        drop: int = 0,
        danger: float = 0.0,
        window: bool = False;
}

def pack(x: int, y: int) -> int {
    return (x + OFFSET) * 4096 + (y + OFFSET);
}

def unpack_x(key: int) -> int {
    return key // 4096 - OFFSET;
}

def unpack_y(key: int) -> int {
    return key % 4096 - OFFSET;
}

obj Grid {
    has cells: dict[int, int] = {};

    def owner(x: int, y: int) -> int {
        return self.cells.get(pack(x, y), -1);
    }

    def free(x: int, y: int) -> bool {
        return pack(x, y) not in self.cells;
    }

    def claim(x: int, y: int, owner: int) {
        self.cells[pack(x, y)] = owner;
    }

    def rect_free(x: int, y: int, w: int, h: int, margin: int) -> bool {
        for cx in range(x - margin, x + w + margin) {
            for cy in range(y - margin, y + h + margin) {
                if not self.free(cx, cy) {
                    return False;
                }
            }
        }
        return True;
    }
}

def room_extent(size: int, stream: Stream) -> list[int] {
    if size <= 0 {
        return [2 + stream.below(2), 2];
    }
    if size == 1 {
        return [3 + stream.below(2), 3];
    }
    if size == 2 {
        return [4 + stream.below(2), 4];
    }
    return [5 + stream.below(3), 5 + stream.below(2)];
}

def rooms_of(site: Site) -> list[Room] {
    found = [site->:Hosts:->][?:Room];
    by_beat: dict[int, Room] = {};
    for room in found {
        by_beat[room.beat] = room;
    }
    return [by_beat[index] for index in range(len(found))];
}

def passages_of(site: Site) -> list[Passage] {
    result: list[Passage] = [];
    for room in rooms_of(site) {
        result.extend([edge room->:Passage:->]);
    }
    return result;
}

def gap(a: Room, b: Room) -> int {
    dx = max(0, max(a.x - (b.x + b.w), b.x - (a.x + a.w)));
    dy = max(0, max(a.y - (b.y + b.h), b.y - (a.y + a.h)));
    return dx + dy;
}

# Place rooms in progression order next to placed neighbors, preferring short
# gaps (corridor space) with projection overlap so straight corridors fit.
def place_rooms(plan: Expedition, site: Site, stream: Stream, grid: Grid) -> bool {
    beats = beats_of(plan);
    order: list[Beat] = [];
    for beat in beats {
        position = len(order);
        while position > 0 and order[position - 1].order > beat.order {
            position -= 1;
        }
        order.insert(position, beat);
    }
    rooms: dict[int, Room] = {};
    for beat in order {
        extent = room_extent(beat.size, stream);
        if stream.chance(0.5) {
            extent = [extent[1], extent[0]];
        }
        room = Room(
            beat=beat.id,
            kind=beat.kind,
            w=extent[0],
            h=extent[1],
            size=beat.size,
            district=beat.district,
            tension=beat.tension,
            optional=beat.optional,
            grants=list(beat.grants),
            pattern=beat.pattern,
            order=beat.order
        );
        placed: list[Room] = [];
        windows: list[Room] = [];
        for link in [edge beat->:Link:->] + [edge beat<-:Link:<-] {
            other = link.head if link.tail == beat.id else link.tail;
            if other in rooms {
                if link.mode == "window" {
                    windows.append(rooms[other]);
                } else {
                    placed.append(rooms[other]);
                }
            }
        }
        if not placed and 0 in rooms {
            placed.append(rooms[0]);
        }
        if not placed {
            room.x = 0;
            room.y = 0;
        } else {
            best_score = 1000000.0;
            best: list[int] = [];
            candidates: list[list[int]] = [];
            for attempt in range(60) {
                anchor = placed[stream.below(len(placed))];
                side = stream.below(4);
                spacing = stream.between(0, 3) if stream.chance(0.8) else stream.between(3, 5);
                candidates.append(beside(anchor, room, side, spacing, stream) + [anchor.beat, spacing]);
            }
            # Deterministic rings around every placed neighbor catch crowded cases.
            for anchor in placed {
                for spacing in range(1, 9) {
                    for side in range(4) {
                        for shift in range(-room.w - room.h, anchor.w + anchor.h + 1, 2) {
                            candidates.append(offset_beside(anchor, room, side, spacing, shift) + [anchor.beat, spacing]);
                        }
                    }
                }
            }
            for index in range(len(candidates)) {
                # Ring candidates are only a fallback for crowded neighborhoods.
                if index == 60 and best {
                    break;
                }
                candidate = candidates[index];
                x = candidate[0];
                y = candidate[1];
                if not grid.rect_free(x, y, room.w, room.h, 0) {
                    continue;
                }
                crowded = False;
                for cx in range(x - 1, x + room.w + 1) {
                    for cy in range(y - 1, y + room.h + 1) {
                        owner = grid.owner(cx, cy);
                        if owner >= 0 and not (candidate[3] == 0 and owner == candidate[2]) {
                            crowded = True;
                        }
                    }
                }
                if crowded {
                    continue;
                }
                room.x = x;
                room.y = y;
                score = 0.0;
                for other in placed {
                    score += float(gap(room, other)) * 1.5;
                }
                for other in windows {
                    score += float(max(0, gap(room, other) - 1)) * 0.7;
                }
                score += stream.unit() * 2.0;
                if score < best_score {
                    best_score = score;
                    best = [x, y];
                }
            }
            if not best {
                site.failures = "placement";
                return False;
            }
            room.x = best[0];
            room.y = best[1];
        }
        for cx in range(room.x, room.x + room.w) {
            for cy in range(room.y, room.y + room.h) {
                grid.claim(cx, cy, room.beat);
            }
        }
        rooms[beat.id] = room;
    }
    for beat in beats {
        site +>:Hosts:+> rooms[beat.id];
        beat +>:Realizes:+> rooms[beat.id];
    }
    return True;
}

def beside(anchor: Room, room: Room, side: int, spacing: int, stream: Stream) -> list[int] {
    if side == 0 {
        return [anchor.x + anchor.w + spacing, anchor.y + stream.between(1 - room.h, anchor.h - 1)];
    }
    if side == 1 {
        return [anchor.x - room.w - spacing, anchor.y + stream.between(1 - room.h, anchor.h - 1)];
    }
    if side == 2 {
        return [anchor.x + stream.between(1 - room.w, anchor.w - 1), anchor.y + anchor.h + spacing];
    }
    return [anchor.x + stream.between(1 - room.w, anchor.w - 1), anchor.y - room.h - spacing];
}

def offset_beside(anchor: Room, room: Room, side: int, spacing: int, shift: int) -> list[int] {
    if side == 0 {
        return [anchor.x + anchor.w + spacing, anchor.y + shift];
    }
    if side == 1 {
        return [anchor.x - room.w - spacing, anchor.y + shift];
    }
    if side == 2 {
        return [anchor.x + shift, anchor.y + anchor.h + spacing];
    }
    return [anchor.x + shift, anchor.y - room.h - spacing];
}

obj Frontier {
    has key: int, cost: float = 0.0, estimate: float = 0.0, parent: int = -1, heading: int = -1;
}

def neighbor_cell(key: int, side: int) -> int {
    x = unpack_x(key);
    y = unpack_y(key);
    if side == 0 {
        return pack(x + 1, y);
    }
    if side == 1 {
        return pack(x - 1, y);
    }
    if side == 2 {
        return pack(x, y + 1);
    }
    return pack(x, y - 1);
}

# Macro cells outside a room that border its side, keyed to the socket they use.
def border(room: Room) -> dict[int, Socket] {
    result: dict[int, Socket] = {};
    for index in range(room.h) {
        result[pack(room.x + room.w, room.y + index)] = Socket(side=0, index=index);
        result[pack(room.x - 1, room.y + index)] = Socket(side=1, index=index);
    }
    for index in range(room.w) {
        result[pack(room.x + index, room.y + room.h)] = Socket(side=2, index=index);
        result[pack(room.x + index, room.y - 1)] = Socket(side=3, index=index);
    }
    return result;
}

def socket_key(room: Room, socket: Socket) -> int {
    return room.beat * 64 + socket.side * 16 + socket.index;
}

# Direct openings between rooms that share a wall segment.
def shared_socket(a: Room, b: Room, used: dict[int, bool]) -> list[Socket] {
    options: list[list[Socket]] = [];
    if a.x + a.w == b.x or b.x + b.w == a.x {
        east = a.x + a.w == b.x;
        for cy in range(max(a.y, b.y), min(a.y + a.h, b.y + b.h)) {
            sa = Socket(side=0 if east else 1, index=cy - a.y);
            sb = Socket(side=1 if east else 0, index=cy - b.y);
            options.append([sa, sb]);
        }
    }
    if a.y + a.h == b.y or b.y + b.h == a.y {
        north = a.y + a.h == b.y;
        for cx in range(max(a.x, b.x), min(a.x + a.w, b.x + b.w)) {
            sa = Socket(side=2 if north else 3, index=cx - a.x);
            sb = Socket(side=3 if north else 2, index=cx - b.x);
            options.append([sa, sb]);
        }
    }
    for pair in options {
        if socket_key(a, pair[0]) not in used and socket_key(b, pair[1]) not in used {
            return pair;
        }
    }
    return [];
}

def route(
    grid: Grid,
    a: Room,
    b: Room,
    stream: Stream,
    used: dict[int, bool],
    corridor: int
) -> list[int] {
    starts = border(a);
    goals = border(b);
    target_x = b.x * 2 + b.w;
    target_y = b.y * 2 + b.h;
    open_list: list[int] = [];
    records: dict[int, Frontier] = {};
    for key in starts {
        if not grid.free(unpack_x(key), unpack_y(key)) {
            continue;
        }
        if socket_key(a, starts[key]) in used {
            continue;
        }
        record = Frontier(key=key, cost=1.0 + stream.unit() * 0.3, heading=starts[key].side);
        record.estimate = record.cost + heuristic(key, target_x, target_y);
        records[key] = record;
        open_list.append(key);
    }
    closed: dict[int, bool] = {};
    expansions = 0;
    while open_list and expansions < 5000 {
        expansions += 1;
        best_index = 0;
        for index in range(1, len(open_list)) {
            if records[open_list[index]].estimate < records[open_list[best_index]].estimate {
                best_index = index;
            }
        }
        key = open_list.pop(best_index);
        if key in closed {
            continue;
        }
        closed[key] = True;
        current = records[key];
        if key in goals and socket_key(b, goals[key]) not in used {
            path: list[int] = [];
            cursor = key;
            while cursor >= 0 {
                path.insert(0, cursor);
                cursor = records[cursor].parent;
            }
            return path;
        }
        for side in range(4) {
            nxt = neighbor_cell(key, side);
            if nxt in closed or not grid.free(unpack_x(nxt), unpack_y(nxt)) {
                continue;
            }
            turn = 0.6 if side != current.heading else 0.0;
            cost = current.cost + 1.0 + turn + stream.unit() * 0.25;
            if nxt not in records or cost < records[nxt].cost {
                records[nxt] = Frontier(
                    key=nxt,
                    cost=cost,
                    estimate=cost + heuristic(nxt, target_x, target_y),
                    parent=key,
                    heading=side
                );
                open_list.append(nxt);
            }
        }
    }
    return [];
}

def heuristic(key: int, tx2: int, ty2: int) -> float {
    return float(abs(unpack_x(key) * 2 + 1 - tx2) + abs(unpack_y(key) * 2 + 1 - ty2)) * 0.5;
}

# Every corridor is a sequence of slices whose floors change by at most one
# step; turn cells are single landings and straight cells hold CELL-1 steps.
def slice_count(path: list[int]) -> int {
    if not path {
        return 1;
    }
    total = len(path) + 1;
    for index in range(len(path)) {
        before = heading_into(path, index);
        after = heading_out(path, index);
        total += (CELL - 1) if before == after else 1;
    }
    return total;
}

def heading_into(path: list[int], index: int) -> int {
    if index == 0 {
        return -1;
    }
    return direction(path[index - 1], path[index]);
}

def heading_out(path: list[int], index: int) -> int {
    if index == len(path) - 1 {
        return -1;
    }
    return direction(path[index], path[index + 1]);
}

def direction(a: int, b: int) -> int {
    dx = unpack_x(b) - unpack_x(a);
    dy = unpack_y(b) - unpack_y(a);
    if dx > 0 {
        return 0;
    }
    if dx < 0 {
        return 1;
    }
    if dy > 0 {
        return 2;
    }
    return 3;
}

def route_all(plan: Expedition, site: Site, stream: Stream, grid: Grid) -> bool {
    rooms = rooms_of(site);
    links = [link for link in links_of(plan) if link.mode != "window"];
    # Constrained links first: they cannot fall back to teleporters.
    ranked: list[Link] = [];
    for priority in [["locked", "gate", "shortcut", "secret"], ["valve"], ["open"]] {
        for link in links {
            if link.mode in priority {
                ranked.append(link);
            }
        }
    }
    used: dict[int, bool] = {};
    corridor = 1000;
    for link in ranked {
        a = rooms[link.tail];
        b = rooms[link.head];
        passage = Passage(
            link=link.id,
            mode=link.mode,
            needs=list(link.needs),
            tail=link.tail,
            head=link.head,
            danger=link.danger
        );
        direct = shared_socket(a, b, used) if gap(a, b) == 0 else [];
        path: list[int] = [];
        if direct {
            passage.tail_socket = direct[0];
            passage.head_socket = direct[1];
        } else {
            path = route(grid, a, b, stream, used, corridor);
            if not path {
                if link.mode not in ["open", "valve"] or site.teleports >= 4 {
                    site.failures = "route " + link.mode;
                    return False;
                }
                passage.teleport = True;
                site.teleports += 1;
                a +>:Passage(
                    link=passage.link,
                    mode=passage.mode,
                    needs=passage.needs,
                    teleport=True,
                    tail=passage.tail,
                    head=passage.head,
                    danger=passage.danger
                ):+> b;
                continue;
            }
            passage.tail_socket = border(a)[path[0]];
            passage.head_socket = border(b)[path[-1]];
            for key in path {
                grid.claim(unpack_x(key), unpack_y(key), corridor);
            }
        }
        used[socket_key(a, passage.tail_socket)] = True;
        used[socket_key(b, passage.head_socket)] = True;
        passage.path = path;
        passage.capacity = STEP * (slice_count(path) + 1);
        corridor += 1;
        a +>:Passage(
            link=passage.link,
            mode=passage.mode,
            needs=passage.needs,
            path=passage.path,
            tail=passage.tail,
            head=passage.head,
            tail_socket=passage.tail_socket,
            head_socket=passage.head_socket,
            capacity=passage.capacity,
            danger=passage.danger
        ):+> b;
    }
    return True;
}

# Straight free sightline slots between rooms joined by window links.
def:priv carve_windows(plan: Expedition, site: Site, grid: Grid) {
    rooms = rooms_of(site);
    for link in links_of(plan) {
        if link.mode != "window" {
            continue;
        }
        a = rooms[link.tail];
        b = rooms[link.head];
        slot = window_slot(grid, a, b);
        if slot is None {
            continue;
        }
        cells = slot.path;
        for key in cells {
            grid.claim(unpack_x(key), unpack_y(key), 999);
        }
        site.windows += 1;
        a +>:Passage(
            link=link.id,
            mode="window",
            window=True,
            path=cells,
            tail=a.beat,
            head=b.beat,
            tail_socket=slot.tail_socket,
            head_socket=slot.head_socket
        ):+> b;
    }
}

obj Slot {
    has path: list[int] = [], tail_socket: Socket = Socket(), head_socket: Socket = Socket();
}

def window_slot(grid: Grid, a: Room, b: Room) -> Slot | None {
    # Horizontal sightline.
    for flip in [False, True] {
        first = b if flip else a;
        second = a if flip else b;
        if first.x + first.w <= second.x {
            for cy in range(max(first.y, second.y), min(first.y + first.h, second.y + second.h)) {
                cells: list[int] = [];
                clear = True;
                for cx in range(first.x + first.w, second.x) {
                    if not grid.free(cx, cy) {
                        clear = False;
                    }
                    cells.append(pack(cx, cy));
                }
                if clear and len(cells) <= 3 {
                    tail_socket = Socket(side=0, index=cy - first.y);
                    head_socket = Socket(side=1, index=cy - second.y);
                    if flip {
                        return Slot(path=list(reversed(cells)), tail_socket=head_socket, head_socket=tail_socket);
                    }
                    return Slot(path=cells, tail_socket=tail_socket, head_socket=head_socket);
                }
            }
        }
        if first.y + first.h <= second.y {
            for cx in range(max(first.x, second.x), min(first.x + first.w, second.x + second.w)) {
                cells: list[int] = [];
                clear = True;
                for cy in range(first.y + first.h, second.y) {
                    if not grid.free(cx, cy) {
                        clear = False;
                    }
                    cells.append(pack(cx, cy));
                }
                if clear and len(cells) <= 3 {
                    tail_socket = Socket(side=2, index=cx - first.x);
                    head_socket = Socket(side=3, index=cx - second.x);
                    if flip {
                        return Slot(path=list(reversed(cells)), tail_socket=head_socket, head_socket=tail_socket);
                    }
                    return Slot(path=cells, tail_socket=tail_socket, head_socket=head_socket);
                }
            }
        }
    }
    return None;
}

# Initial heights follow a tension-driven random walk; verticality scales it.
def target_heights(site: Site, stream: Stream, verticality: float) {
    rooms = rooms_of(site);
    ordered: list[Room] = [];
    for room in rooms {
        position = len(ordered);
        while position > 0 and ordered[position - 1].order > room.order {
            position -= 1;
        }
        ordered.insert(position, room);
    }
    level = 0.0;
    for room in ordered {
        swing = verticality * 160.0;
        level += stream.uniform(-swing, swing * 1.2);
        if room.kind in ["vista"] {
            level += verticality * 96.0;
        }
        room.target = quantize(level);
        room.z = room.target;
        spans = [0, 64, 128, 192];
        room.span = quantize(float(spans[min(3, room.size)]) * (0.5 + verticality));
        if room.kind in ["start", "goal", "cache"] {
            room.span = 0;
        }
    }
}

def quantize(value: float) -> int {
    steps = int(value / float(STEP));
    if value < 0.0 and float(steps * STEP) != value {
        steps -= 1;
    }
    return steps * STEP;
}

# Local interior coordinates of a socket's landing, in columns.
def socket_point(room: Room, socket: Socket) -> list[float] {
    along = float(socket.index * CELL) + float(CELL - 2) * 0.5;
    if socket.side == 0 {
        return [float(room.columns() - 1), along];
    }
    if socket.side == 1 {
        return [0.0, along];
    }
    if socket.side == 2 {
        return [along, float(room.rows() - 1)];
    }
    return [along, 0.0];
}

# Interior stairs need horizontal run: three landing columns at each end, then
# one step per column, with a safety margin for routing around obstacles.
def socket_slack(room: Room, a: Socket, b: Socket) -> int {
    pa = socket_point(room, a);
    pb = socket_point(room, b);
    run = abs(pa[0] - pb[0]) + abs(pa[1] - pb[1]);
    return STEP * max(0, int(run * 0.7) - 6);
}

def clamp_int(value: int, low: int, high: int) -> int {
    return max(low, min(high, value));
}

obj Bound {
    has tail: int, head: int, weight: int;
}

# Heights form a system of difference constraints (x_head - x_tail <= weight)
# over room floors and socket landings, in STEP units. Bellman-Ford decides it
# exactly; anchoring edges keep rooms near their tension-driven targets, and the
# anchor tolerance widens until the system becomes feasible.
def solve_heights(site: Site) -> bool {
    rooms = rooms_of(site);
    passages = [passage for passage in passages_of(site) if not passage.teleport and not passage.window];
    count = len(rooms) + 1;
    base: list[Bound] = [];
    ends: dict[int, list[int]] = {};
    sockets: list[Socket] = [];
    owners: list[int] = [];

    for passage in passages {
        for pair in [[passage.tail, 0], [passage.head, 1]] {
            room = rooms[pair[0]];
            socket = passage.tail_socket if pair[1] == 0 else passage.head_socket;
            index = count;
            count += 1;
            sockets.append(socket);
            owners.append(room.beat);
            ends.setdefault(room.beat, []).append(index);
            base.append(bound_of(room.beat, index, room.span // STEP));
            base.append(bound_of(index, room.beat, 0));
        }
        a = count - 2;
        b = count - 1;
        low = -passage.capacity;
        high = passage.capacity;
        if passage.mode == "valve" {
            # The final slice is the ledge itself, one step short of a corridor.
            reach = passage.capacity - STEP;
            low = DROP_MIN - reach;
            high = DROP_MAX + reach;
        }
        # low <= h_a - h_b <= high
        base.append(bound_of(b, a, high // STEP));
        base.append(bound_of(a, b, -(ceil_div(low, STEP))));
    }
    for room in rooms {
        members = ends.get(room.beat, []);
        for i in range(len(members)) {
            for j in range(i + 1, len(members)) {
                slack = socket_slack(room, sockets[members[i] - len(rooms) - 1], sockets[members[j] - len(rooms) - 1]) // STEP;
                base.append(bound_of(members[i], members[j], slack));
                base.append(bound_of(members[j], members[i], slack));
            }
        }
    }
    anchor = len(rooms);
    for tolerance in [4, 8, 16, 32, -1] {
        bounds = list(base);
        for room in rooms {
            target = room.target // STEP;
            if tolerance >= 0 {
                bounds.append(Bound(tail=anchor, head=room.beat, weight=target + tolerance));
                bounds.append(Bound(tail=room.beat, head=anchor, weight=tolerance - target));
            }
        }
        distance = [0 for _ in range(count)];
        stable = False;
        for round in range(count + 1) {
            changed = False;
            for bound in bounds {
                candidate = distance[bound.tail] + bound.weight;
                if candidate < distance[bound.head] {
                    distance[bound.head] = candidate;
                    changed = True;
                }
            }
            if not changed {
                stable = True;
                break;
            }
        }
        if not stable {
            continue;
        }
        lowest = min([distance[room.beat] for room in rooms]);
        for room in rooms {
            room.z = (distance[room.beat] - lowest) * STEP;
        }
        for index in range(len(sockets)) {
            sockets[index].offset = (distance[len(rooms) + 1 + index] - distance[owners[index]]) * STEP;
        }
        return True;
    }
    site.failures = "heights";
    return False;
}

def bound_of(tail: int, head: int, weight: int) -> Bound {
    return Bound(tail=tail, head=head, weight=weight);
}

def ceil_div(value: int, divisor: int) -> int {
    return -((-value) // divisor);
}

def normalize(site: Site) {
    rooms = rooms_of(site);
    min_x = 100000;
    min_y = 100000;
    max_x = -100000;
    max_y = -100000;
    for room in rooms {
        min_x = min(min_x, room.x);
        min_y = min(min_y, room.y);
        max_x = max(max_x, room.x + room.w);
        max_y = max(max_y, room.y + room.h);
    }
    for passage in passages_of(site) {
        for key in passage.path {
            min_x = min(min_x, unpack_x(key));
            min_y = min(min_y, unpack_y(key));
            max_x = max(max_x, unpack_x(key) + 1);
            max_y = max(max_y, unpack_y(key) + 1);
        }
    }
    # One solid macro ring keeps every carved column inside the world.
    shift_x = 1 - min_x;
    shift_y = 1 - min_y;
    for room in rooms {
        room.x += shift_x;
        room.y += shift_y;
    }
    for passage in passages_of(site) {
        passage.path = [pack(unpack_x(key) + shift_x, unpack_y(key) + shift_y) for key in passage.path];
    }
    site.width = max_x - min_x + 2;
    site.height = max_y - min_y + 2;
}

def embed(plan: Expedition, stream: Stream) -> Site {
    site = Site();
    grid = Grid();
    if not place_rooms(plan, site, stream.derive("place"), grid) {
        return site;
    }
    if not route_all(plan, site, stream.derive("route"), grid) {
        return site;
    }
    carve_windows(plan, site, grid);
    normalize(site);
    return site;
}
