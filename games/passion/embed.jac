"""Re-embedding and splicing: an essence laid out anew, or with a region of
another essence in place of one of its own, before it is sculpted.

The essence's places are split into regions: its progression's stages when
it has more than one, else sections across its longest side. Each region is
a rigid piece; the ways between pieces are its connections.

- **Re-embedding** spreads the pieces apart and turns each by its own
  quarter, then joins every connection by a new passage: places laid along
  a path routed through the gaps (blocks of two cells, stairs a lift a
  cell), walked both ways, from where the connection left one piece to
  where it arrived in the other.
- **Splicing** takes one piece out and puts a piece of another essence in
  its place (one with at least as many connections), its connections
  joined to the old ones' ends by passages; what the piece held comes with
  it (its gates and openers, their tokens renamed).

Both edit a copy of the essence's graph; nothing here proves anything. The
level made from the result is proven like any other, and a candidate that
does not prove is passed over."""
import math;
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.formats.aas { TRAVEL_WALK, TRAVEL_TELEPORT, TRAVEL_ELEVATOR }
import from engine.level.graph {
    LevelGraph,
    Place,
    Move,
    Gate,
    Opener,
    Thing,
    Holds,
    Guards,
    Offers,
    Bars,
    DoneFrom,
    Contains,
    StandsIn,
    graph_places,
    graph_gates,
    graph_openers,
    graph_things,
    opener_places,
    barred_places,
    thing_place
}
import from engine.level.prove { prove_level, bits_of }
import from .random { Stream }
import from .transform { copy_graph, turned, turned_box, turned_yaw }

glob EMBED_BLOCK: float = 64.0,
     EMBED_GAP: int = 4,
     EMBED_SEARCH: int = 250000;

"""A piece of an essence: its places, its box (across), and where it is
moved to (a shift, and quarter turns about its middle)."""
obj Piece {
    has number: int,
        areas: list[int] = [],
        low: Vec3 = Vec3(),
        high: Vec3 = Vec3(),
        shift: Vec3 = Vec3(),
        turns: int = 0;

    def middle -> Vec3 {
        return self.low.add(self.high).scale(0.5);
    }

    """A point of the piece where it now stands."""
    def placed(point: Vec3) -> Vec3 {
        middle = self.middle();
        local = turned(point.sub(Vec3(x=middle.x, y=middle.y)), False, self.turns);
        return local.add(Vec3(x=middle.x, y=middle.y)).add(self.shift);
    }
}

"""A connection between two pieces: the move it was, from and to."""
obj Joint {
    has tail: int,
        head: int,
        start: Vec3,
        finish: Vec3,
        from_area: int,
        to_area: int,
        gate: int = 0;
}

"""The pieces of a graph: by its stages when it has more than one (each
stage's places, stages of one or two places joined to their neighbours'),
else three sections across its longest side."""
def split_pieces(atlas: LevelGraph) -> dict[int, int] {
    places = graph_places(atlas);
    stages: dict[int, list[Place]] = {};
    for place in places {
        stages.setdefault(max(0, place.stage), []).append(place);
    }
    owner: dict[int, int] = {};
    big = [stage for stage in stages.keys() if len(stages[stage]) >= 40];
    if len(big) >= 2 {
        for (number, stage) in enumerate(sorted(big)) {
            for place in stages[stage] {
                owner[place.area] = number;
            }
        }
        # The small stages join the piece of the nearest place that has one.
        for place in places {
            if place.area in owner {
                continue;
            }
            best = -1;
            nearest = 1.0e9;
            for other in places {
                if other.area in owner {
                    gap = other.center.sub(place.center).length();
                    if gap < nearest {
                        nearest = gap;
                        best = owner[other.area];
                    }
                }
            }
            owner[place.area] = max(0, best);
        }
        return owner;
    }
    low = Vec3(x=1.0e9, y=1.0e9);
    high = Vec3(x=-1.0e9, y=-1.0e9);
    for place in places {
        low = Vec3(x=min(low.x, place.center.x), y=min(low.y, place.center.y));
        high = Vec3(x=max(high.x, place.center.x), y=max(high.y, place.center.y));
    }
    along_x = high.x - low.x >= high.y - low.y;
    for place in places {
        at = (place.center.x - low.x) / max(1.0, high.x - low.x) if along_x else (place.center.y - low.y) / max(1.0, high.y - low.y);
        owner[place.area] = min(2, int(at * 3.0));
    }
    return owner;
}

"""The pieces and their joints: one joint for each pair of pieces the
essence moves between (the move from the place nearest the two pieces'
middles), walking first."""
def pieces_of(atlas: LevelGraph, owner: dict[int, int]) -> tuple[list[Piece], list[Joint]] {
    pieces: dict[int, Piece] = {};
    for place in graph_places(atlas) {
        number = owner[place.area];
        if number not in pieces {
            pieces[number] = Piece(number=number, low=Vec3(x=1.0e9, y=1.0e9, z=1.0e9), high=Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9));
        }
        piece = pieces[number];
        piece.areas.append(place.area);
        piece.low = Vec3(x=min(piece.low.x, place.box.mins.x), y=min(piece.low.y, place.box.mins.y), z=min(piece.low.z, place.floor));
        piece.high = Vec3(x=max(piece.high.x, place.box.maxs.x), y=max(piece.high.y, place.box.maxs.y), z=max(piece.high.z, place.floor));
    }
    best: dict[tuple[int, int], Joint] = {};
    for place in graph_places(atlas) {
        for move in [edge place->:Move:->] {
            if move.fall or move.to not in owner or move.kind in [TRAVEL_TELEPORT, TRAVEL_ELEVATOR] {
                continue;
            }
            a = owner[place.area];
            b = owner[move.to];
            if a == b {
                continue;
            }
            key = (min(a, b), max(a, b));
            joint = Joint(tail=a, head=b, start=move.start, finish=move.finish, from_area=place.area, to_area=move.to, gate=move.gate);
            held = best.get(key, None);
            if held is None or (move.kind == TRAVEL_WALK and joint.gate == 0 and held.gate != 0) {
                best[key] = joint;
            }
        }
    }
    return ([pieces[number] for number in sorted(pieces.keys())], list(best.values()));
}

"""The blocks (64 units) a piece's places cover where it now stands, with
a margin of `margin` blocks."""
def piece_blocks(atlas_places: list[Place], piece: Piece, margin: int) -> dict[tuple[int, int], bool] {
    blocks: dict[tuple[int, int], bool] = {};
    wanted = set(piece.areas);
    for place in atlas_places {
        if place.area not in wanted {
            continue;
        }
        a = piece.placed(place.box.mins);
        b = piece.placed(place.box.maxs);
        for bx in range(int(math.floor(min(a.x, b.x) / EMBED_BLOCK)) - margin, int(math.floor(max(a.x, b.x) / EMBED_BLOCK)) + margin + 1) {
            for block_y in range(int(math.floor(min(a.y, b.y) / EMBED_BLOCK)) - margin, int(math.floor(max(a.y, b.y) / EMBED_BLOCK)) + margin + 1) {
                blocks[(bx, block_y)] = True;
            }
        }
    }
    return blocks;
}

"""Lay the pieces out anew, as close as they fit: each turned by the dice,
the largest first where it stood, each after it slid out from the middle
of them all (a block at a time) until a gap of `EMBED_GAP` blocks keeps it
from every piece laid before it."""
def spread(atlas: LevelGraph, pieces: list[Piece], dice: Stream) {
    places = graph_places(atlas);
    middle = Vec3();
    for piece in pieces {
        middle = middle.add(piece.middle());
    }
    middle = middle.scale(1.0 / float(max(1, len(pieces))));
    order: list[int] = [];
    for index in range(len(pieces)) {
        at = len(order);
        while at > 0 and len(pieces[order[at - 1]].areas) < len(pieces[index].areas) {
            at -= 1;
        }
        order.insert(at, index);
    }
    laid: dict[tuple[int, int], bool] = {};
    for index in order {
        piece = pieces[index];
        piece.turns = dice.below(4) if dice.chance(0.6) else 0;
        out = Vec3(x=piece.middle().x - middle.x, y=piece.middle().y - middle.y);
        length = out.length();
        angle = dice.uniform(0.0, 6.2831853);
        way = out.scale(1.0 / length) if length > 64.0 else Vec3(x=math.cos(angle), y=math.sin(angle));
        lift = float(dice.between(-3, 3)) * 16.0;
        for step in range(400) {
            piece.shift = Vec3(x=way.x * float(step) * EMBED_BLOCK, y=way.y * float(step) * EMBED_BLOCK, z=lift);
            mine = piece_blocks(places, piece, EMBED_GAP // 2);
            clear = True;
            for block in mine.keys() {
                if block in laid {
                    clear = False;
                    break;
                }
            }
            if clear {
                break;
            }
        }
        for block in piece_blocks(places, piece, EMBED_GAP // 2).keys() {
            laid[block] = True;
        }
    }
}

"""Move a graph's places, moves, gates, openers and things with their
pieces."""
def place_pieces(atlas: LevelGraph, owner: dict[int, int], pieces: list[Piece]) {
    by_number: dict[int, Piece] = {};
    for piece in pieces {
        by_number[piece.number] = piece;
    }
    for place in graph_places(atlas) {
        piece = by_number[owner[place.area]];
        moved_low = piece.placed(place.box.mins);
        moved_high = piece.placed(place.box.maxs);
        place.box = AABB(
            mins=Vec3(x=min(moved_low.x, moved_high.x), y=min(moved_low.y, moved_high.y), z=place.box.mins.z + piece.shift.z),
            maxs=Vec3(x=max(moved_low.x, moved_high.x), y=max(moved_low.y, moved_high.y), z=place.box.maxs.z + piece.shift.z)
        );
        place.center = piece.placed(place.center);
        place.floor += piece.shift.z;
        place.surface += piece.shift.z if place.liquid > 0 else 0.0;
        for move in [edge place->:Move:->] {
            move.start = piece.placed(move.start);
            move.finish = by_number[owner.get(move.to, owner[place.area])].placed(move.finish);
        }
    }
    for gate in graph_gates(atlas) {
        barred = barred_places(gate);
        holder = by_number[owner[barred[0].area]] if barred else nearest_piece(pieces, gate.box.mins.add(gate.box.maxs).scale(0.5));
        a = holder.placed(gate.box.mins);
        b = holder.placed(gate.box.maxs);
        gate.box = AABB(mins=Vec3(x=min(a.x, b.x), y=min(a.y, b.y), z=gate.box.mins.z + holder.shift.z), maxs=Vec3(x=max(a.x, b.x), y=max(a.y, b.y), z=gate.box.maxs.z + holder.shift.z));
    }
    for opener in graph_openers(atlas) {
        done = opener_places(opener);
        holder = by_number[owner[done[0].area]] if done else nearest_piece(pieces, opener.point);
        opener.point = holder.placed(opener.point);
    }
    for thing in graph_things(atlas) {
        at = thing_place(thing);
        holder = by_number[owner[at.area]] if at is not None else nearest_piece(pieces, thing.point);
        thing.point = holder.placed(thing.point);
        thing.yaw = turned_yaw(thing.yaw, False, holder.turns);
    }
}

"""The piece whose box is nearest a point."""
def nearest_piece(pieces: list[Piece], point: Vec3) -> Piece {
    best = pieces[0];
    nearest = 1.0e9;
    for piece in pieces {
        gap = piece.middle().sub(point).length();
        if gap < nearest {
            nearest = gap;
            best = piece;
        }
    }
    return best;
}

"""The floors (in lifts) of a graph's places in each block (64 units),
spread a margin of blocks: a passage may cross a block only well over or
under them."""
def taken_blocks(atlas: LevelGraph, margin: int) -> dict[tuple[int, int], list[int]] {
    taken: dict[tuple[int, int], list[int]] = {};
    for place in graph_places(atlas) {
        lift = int(math.floor(place.floor / 16.0 + 0.5));
        for bx in range(int(math.floor(place.box.mins.x / EMBED_BLOCK)) - margin, int(math.floor(place.box.maxs.x / EMBED_BLOCK)) + margin + 1) {
            for block_y in range(int(math.floor(place.box.mins.y / EMBED_BLOCK)) - margin, int(math.floor(place.box.maxs.y / EMBED_BLOCK)) + margin + 1) {
                floors = taken.setdefault((bx, block_y), []);
                if lift not in floors {
                    floors.append(lift);
                }
            }
        }
    }
    return taken;
}

"""Whether a passage's floor at lift `z` clears every floor of a block:
nine lifts over or under each (its air and a slab between)."""
def clears(floors: list[int], z: int) -> bool {
    for floor in floors {
        if -9 < z - floor < 9 {
            return False;
        }
    }
    return True;
}

"""Push onto a min-heap of [cost, ...] lists."""
def heap_push(heap: list[list[int]], item: list[int]) {
    heap.append(item);
    at = len(heap) - 1;
    while at > 0 {
        parent = (at - 1) // 2;
        if heap[parent][0] <= heap[at][0] {
            break;
        }
        swap = heap[parent];
        heap[parent] = heap[at];
        heap[at] = swap;
        at = parent;
    }
}

"""Pop the least of a min-heap."""
def heap_pop(heap: list[list[int]]) -> list[int] {
    top = heap[0];
    last = heap.pop();
    if heap {
        heap[0] = last;
        at = 0;
        while True {
            left = 2 * at + 1;
            pick = at;
            if left < len(heap) and heap[left][0] < heap[pick][0] {
                pick = left;
            }
            if left + 1 < len(heap) and heap[left + 1][0] < heap[pick][0] {
                pick = left + 1;
            }
            if pick == at {
                break;
            }
            swap = heap[pick];
            heap[pick] = heap[at];
            heap[at] = swap;
            at = pick;
        }
    }
    return top;
}

"""A passage's blocks from one point to another ([x, y, lift] each, lifts
of 16 units), over or under what stands in the blocks it crosses (the
ends' own excepted), climbing a lift a block at most; empty when none is
found."""
def route_passage(start: Vec3, finish: Vec3, taken: dict[tuple[int, int], list[int]]) -> list[list[int]] {
    a = [int(math.floor(start.x / EMBED_BLOCK)), int(math.floor(start.y / EMBED_BLOCK)), int(math.floor((start.z - 24.0) / 16.0 + 0.5))];
    b = [int(math.floor(finish.x / EMBED_BLOCK)), int(math.floor(finish.y / EMBED_BLOCK)), int(math.floor((finish.z - 24.0) / 16.0 + 0.5))];
    near: dict[tuple[int, int], bool] = {};
    for end in [a, b] {
        for dx in range(-2, 3) {
            for dy in range(-2, 3) {
                near[(end[0] + dx, end[1] + dy)] = True;
            }
        }
    }
    key0 = (a[0], a[1], a[2]);
    came: dict[tuple[int, int, int], tuple[int, int, int]] = {};
    cost: dict[tuple[int, int, int], int] = {key0: 0};
    heap: list[list[int]] = [];
    heap_push(heap, [abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]), a[0], a[1], a[2]]);
    expanded = 0;
    goal: tuple[int, int, int] | None = None;
    while heap and expanded < EMBED_SEARCH {
        item = heap_pop(heap);
        here = (item[1], item[2], item[3]);
        expanded += 1;
        if here[0] == b[0] and here[1] == b[1] and abs(here[2] - b[2]) <= 1 {
            goal = here;
            break;
        }
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            for dz in [-1, 0, 1] {
                nxt = (here[0] + dx, here[1] + dy, here[2] + dz);
                if (nxt[0], nxt[1]) not in near and not clears(taken.get((nxt[0], nxt[1]), []), nxt[2]) {
                    continue;
                }
                step = cost[here] + 4 + (2 if dz != 0 else 0);
                if nxt not in cost or step < cost[nxt] {
                    cost[nxt] = step;
                    came[nxt] = here;
                    heap_push(heap, [step + 4 * (abs(nxt[0] - b[0]) + abs(nxt[1] - b[1])) + 2 * abs(nxt[2] - b[2]), nxt[0], nxt[1], nxt[2]]);
                }
            }
        }
    }
    if goal is None {
        return [];
    }
    path: list[list[int]] = [];
    at = goal;
    while at != key0 {
        path.insert(0, [at[0], at[1], at[2]]);
        at = came[at];
    }
    path.insert(0, [a[0], a[1], a[2]]);
    return path;
}

"""Lay a passage's blocks as places (each a block of floor), walked both
ways from block to block and from its ends to the places it joins."""
def lay_passage(atlas: LevelGraph, path: list[list[int]], tail: Place, head: Place, stage: int) -> int {
    count = max([place.area for place in graph_places(atlas)] + [0]);
    made: list[Place] = [];
    for block in path {
        count += 1;
        floor = float(block[2]) * 16.0;
        low = Vec3(x=float(block[0]) * EMBED_BLOCK + 8.0, y=float(block[1]) * EMBED_BLOCK + 8.0, z=floor + 20.0);
        high = Vec3(x=float(block[0] + 1) * EMBED_BLOCK - 8.0, y=float(block[1] + 1) * EMBED_BLOCK - 8.0, z=floor + 32.0);
        place = Place(area=count, box=AABB(mins=low, maxs=high), center=low.add(high).scale(0.5), floor=floor, flags=1, roof=112.0, stage=stage);
        atlas +>:Holds:+> place;
        made.append(place);
    }
    chain = [tail] + made + [head];
    for index in range(len(chain) - 1) {
        a = chain[index];
        b = chain[index + 1];
        a +>:Move(kind=TRAVEL_WALK, to=b.area, start=a.center, finish=b.center, time=40):+> b;
        b +>:Move(kind=TRAVEL_WALK, to=a.area, start=b.center, finish=a.center, time=40):+> a;
    }
    return len(made);
}

"""Cut the moves between pieces (their joints are passages now)."""
def cut_joints(atlas: LevelGraph, owner: dict[int, int]) {
    for place in graph_places(atlas) {
        for target in [place->:Move:->][?:Place] {
            if target.area in owner and place.area in owner and owner[target.area] != owner[place.area] {
                place del->:Move:-> target;
            }
        }
    }
}

"""An essence re-embedded: a copy split into pieces, spread and turned, its
pieces joined by routed passages. None when a joint cannot be routed."""
def reembed(atlas: LevelGraph, dice: Stream, why: list[str]) -> LevelGraph | None {
    copied = copy_graph(atlas);
    owner = split_pieces(copied);
    found = pieces_of(copied, owner);
    pieces = found[0];
    joints = found[1];
    if len(pieces) < 2 or not joints {
        why.append("re-embed: " + str(len(pieces)) + " pieces, " + str(len(joints)) + " joints");
        return None;
    }
    spread(copied, pieces, dice);
    by_number: dict[int, Piece] = {};
    for piece in pieces {
        by_number[piece.number] = piece;
    }
    ends: list[list[Vec3]] = [];
    for joint in joints {
        ends.append([by_number[joint.tail].placed(joint.start), by_number[joint.head].placed(joint.finish)]);
    }
    cut_joints(copied, owner);
    place_pieces(copied, owner, pieces);
    by_area: dict[int, Place] = {};
    for place in graph_places(copied) {
        by_area[place.area] = place;
    }
    laid = 0;
    for (index, joint) in enumerate(joints) {
        taken = taken_blocks(copied, 1);
        path = route_passage(ends[index][0], ends[index][1], taken);
        if not path {
            why.append("re-embed: no passage from " + str(int(ends[index][0].x)) + "," + str(int(ends[index][0].y)) + "," + str(int(ends[index][0].z)) + " to " + str(int(ends[index][1].x)) + "," + str(int(ends[index][1].y)) + "," + str(int(ends[index][1].z)));
            return None;
        }
        tail = by_area[joint.from_area];
        head = by_area[joint.to_area];
        laid += lay_passage(copied, path, tail, head, max(0, min(tail.stage, head.stage) if tail.stage >= 0 and head.stage >= 0 else 0));
    }
    copied.notes.append("re-embedded: " + str(len(pieces)) + " pieces, " + str(len(joints)) + " passages of " + str(laid) + " blocks");
    prove_level(copied, False);
    return copied;
}

"""An essence with one of its pieces replaced by a piece of another (one
with at least as many joints), the new piece's connections joined to the
old ones' ends by passages. None when it cannot be done."""
def splice(atlas: LevelGraph, donor: LevelGraph, dice: Stream, why: list[str]) -> LevelGraph | None {
    copied = copy_graph(atlas);
    owner = split_pieces(copied);
    found = pieces_of(copied, owner);
    pieces = found[0];
    joints = found[1];
    giving = copy_graph(donor);
    their_owner = split_pieces(giving);
    theirs = pieces_of(giving, their_owner);
    if len(pieces) < 2 or len(theirs[0]) < 2 {
        return None;
    }
    # The piece to replace: one that holds neither the start nor a way out.
    choices: list[Piece] = [];
    by_area: dict[int, Place] = {};
    for place in graph_places(copied) {
        by_area[place.area] = place;
    }
    for piece in pieces {
        held = [by_area[area] for area in piece.areas];
        if not [place for place in held if place.start or place.way_out] {
            choices.append(piece);
        }
    }
    if not choices {
        return None;
    }
    out = choices[dice.below(len(choices))];
    needed = [joint for joint in joints if joint.tail == out.number or joint.head == out.number];
    donors: list[Piece] = [];
    for piece in theirs[0] {
        their_joints = [joint for joint in theirs[1] if joint.tail == piece.number or joint.head == piece.number];
        if len(their_joints) >= len(needed) and len(piece.areas) >= 20 {
            donors.append(piece);
        }
    }
    if not donors {
        return None;
    }
    taken_piece = donors[dice.below(len(donors))];
    their_by_area: dict[int, Place] = {};
    for place in graph_places(giving) {
        their_by_area[place.area] = place;
    }
    # Out with the old piece: its places, and what stood or was done there.
    gone = set(out.areas);
    for place in graph_places(copied) {
        if place.area in gone {
            copied del->:Holds:-> place;
            continue;
        }
        for target in [place->:Move:->][?:Place] {
            if target.area in gone {
                place del->:Move:-> target;
            }
        }
    }
    for thing in graph_things(copied) {
        at = thing_place(thing);
        if at is not None and at.area in gone {
            copied del->:Contains:-> thing;
        }
    }
    for gate in graph_gates(copied) {
        if [place for place in barred_places(gate) if place.area in gone] {
            copied del->:Guards:-> gate;
        }
    }
    for opener in graph_openers(copied) {
        done = opener_places(opener);
        if done and [place for place in done if place.area in gone] and len([place for place in done if place.area not in gone]) == 0 {
            copied del->:Offers:-> opener;
        }
    }
    # In with the new: its places renumbered past the essence's, set down
    # where the old piece stood (middle on middle, floor on floor).
    base = max([place.area for place in graph_places(copied)] + [0]) + 1;
    shift = out.middle().sub(taken_piece.middle());
    shift = Vec3(x=shift.x, y=shift.y, z=out.low.z - taken_piece.low.z);
    renumber: dict[int, int] = {};
    for (index, area) in enumerate(sorted(taken_piece.areas)) {
        renumber[area] = base + index;
    }
    stage = min([by_area[joint.from_area].stage if joint.tail != out.number else by_area[joint.to_area].stage for joint in needed] + [0]);
    fresh: dict[int, Place] = {};
    for area in sorted(taken_piece.areas) {
        theirs_place = their_by_area[area];
        place = Place(
            area=renumber[area],
            box=AABB(mins=theirs_place.box.mins.add(shift), maxs=theirs_place.box.maxs.add(shift)),
            center=theirs_place.center.add(shift),
            floor=theirs_place.floor + shift.z,
            liquid=theirs_place.liquid,
            surface=theirs_place.surface + shift.z,
            roof=theirs_place.roof,
            sky=theirs_place.sky,
            deadly=theirs_place.deadly,
            flags=theirs_place.flags,
            contents=theirs_place.contents,
            stage=max(0, stage)
        );
        copied +>:Holds:+> place;
        fresh[area] = place;
    }
    for area in sorted(taken_piece.areas) {
        for move in [edge their_by_area[area]->:Move:->] {
            if move.to in fresh and not move.fall {
                fresh[area] +>:Move(kind=move.kind, to=renumber[move.to], must=move.must, start=move.start.add(shift), finish=move.finish.add(shift), time=move.time):+> fresh[move.to];
            }
        }
    }
    # Its things come with it (re-cast like the rest).
    for thing in graph_things(giving) {
        at = thing_place(thing);
        if at is not None and at.area in fresh {
            copy = Thing(classname=thing.classname, game=thing.game, point=thing.point.add(shift), spawnflags=thing.spawnflags, yaw=thing.yaw);
            copied +>:Contains:+> copy;
            copy +>:StandsIn:+> fresh[at.area];
        }
    }
    # Its joints, matched to the old piece's: the new piece's places nearest
    # where its own joints were, joined by passages to the old ends.
    their_joints = [joint for joint in theirs[1] if joint.tail == taken_piece.number or joint.head == taken_piece.number];
    for place in graph_places(copied) {
        by_area[place.area] = place;
    }
    laid = 0;
    for (index, joint) in enumerate(needed) {
        outside_area = joint.from_area if joint.tail != out.number else joint.to_area;
        if outside_area not in by_area {
            return None;
        }
        outside = by_area[outside_area];
        theirs_joint = their_joints[index % len(their_joints)];
        inside_area = theirs_joint.from_area if theirs_joint.tail == taken_piece.number else theirs_joint.to_area;
        if inside_area not in fresh {
            return None;
        }
        inside = fresh[inside_area];
        taken = taken_blocks(copied, 0);
        path = route_passage(outside.center, inside.center, taken);
        if not path {
            return None;
        }
        laid += lay_passage(copied, path, outside, inside, max(0, outside.stage));
    }
    copied.notes.append("spliced: a piece of " + donor.name + " (" + str(len(fresh)) + " places) for one of " + str(len(out.areas)) + ", " + str(laid) + " passage blocks");
    prove_level(copied, False);
    return copied;
}
