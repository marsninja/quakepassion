"""The arrangement: where each space of an expedition stands in three
dimensions, and the corridors that join them.

Spaces are placed one by one in progression order, each beside a space it
links to that is already placed: off one of its sides, a few cells away,
higher or lower as the expedition's verticality asks, never closer than
two cells to anything placed. Then every link of the mission is routed as
a corridor through the massing by an A* search over blocks two cells
square and a doorway high, from a doorway of one space to a doorway of the
other. A corridor climbs or falls by stairs, a lift a cell, and turns
corners on the flat; it keeps a wall's thickness from every other space and
corridor, so it may pass over or under them. A one-way link ends at a ledge
in the wall of the space it leads to; a link that cannot be routed becomes a
pair of teleporters.

The estate (a node) holds the spaces (Encloses) and the corridors (edges
between spaces, which are spaces themselves for their air)."""
import math;
import from .random { Stream }
import from .massing { Massing }
import from .spaces { Space, Doorway, OPEN_HIGH, space_size, pick_archetype, shape_space, socket_cells }
import from .mission { Expedition, Beat, Link, beats_of, links_of }

glob CORRIDOR_HIGH: int = 6,
     GAP_LOW: int = 4,
     GAP_HIGH: int = 9,
     # Cells kept clear between boxes: a wall each and a corridor's width.
     CLEARANCE: int = 4,
     ABUT_CHANCE: float = 0.35,
     MARGIN: int = 4,
     SEARCH_LIMIT: int = 120000;

# Archetypes whose floor runs out to their walls, so two of them can meet
# wall to wall through a doorway.
glob ABUTTERS: list[str] = ["hall", "crypt", "vault", "court", "atrium", "terraces", "stairhall"];

node Estate {
    has seed: int = 0,
        nx: int = 0,
        ny: int = 0,
        nz: int = 0,
        failures: list[str] = [],
        teleports: int = 0,
        windows: int = 0;
}

edge Encloses: Estate --> Space {}

"""A corridor between two spaces: the link it realises, the doorways it
leaves and enters by, its blocks in order ([x, y, z] low corners), the space
that owns its air, and whether it fell back to teleporters or is only a
window."""
edge Corridor: Space --> Space {
    has link: int = 0,
        mode: str = "open",
        needs: list[str] = [],
        tail: int = 0,
        head: int = 0,
        out_door: Doorway | None = None,
        in_door: Doorway | None = None,
        blocks: list[list[int]] = [],
        air: int = -1,
        teleport: bool = False,
        window: bool = False;
}

"""The indices of `scores` from lowest score to highest, ties kept in
order."""
def ranked(scores: list[float]) -> list[int] {
    order: list[int] = [];
    for index in range(len(scores)) {
        at = len(order);
        while at > 0 and scores[order[at - 1]] > scores[index] {
            at -= 1;
        }
        order.insert(at, index);
    }
    return order;
}

"""The spaces of an estate by id (corridors' spaces included)."""
def estate_spaces(estate: Estate) -> list[Space] {
    found = [estate->:Encloses:->][?:Space];
    return [found[index] for index in ranked([float(space.id) for space in found])];
}

"""The corridors of an estate."""
def estate_corridors(estate: Estate) -> list[Corridor] {
    found: list[Corridor] = [];
    for space in estate_spaces(estate) {
        for corridor in [edge space->:Corridor:->] {
            found.append(corridor);
        }
    }
    return found;
}

"""Whether two boxes of cells, each grown by `margin` across and `rise`
up, overlap."""
def boxes_meet(a: Space, b: Space, margin: int, rise: int) -> bool {
    return a.x - margin < b.x + b.w and b.x - margin < a.x + a.w and a.y - margin < b.y + b.d
        and b.y - margin < a.y + a.d and a.z - rise < b.z + b.h and b.z - rise < a.z + a.h;
}

"""Place a space beside `anchor`: tried at many spots off its sides, the
nearest that keeps clear of everything placed (and nearest to the other
placed spaces it links to) taken. False when none fits."""
def place_beside(space: Space, anchor: Space, placed: list[Space], friends: list[Space], dice: Stream, verticality: float) -> bool {
    best_score = -1.0;
    best: list[int] = [];
    for attempt in range(48) {
        side = dice.below(4);
        # Now and then the rooms abut, wall to wall on one floor, a doorway
        # straight through: the plan packs as id's levels do.
        abut = space.kind in ABUTTERS and anchor.kind in ABUTTERS and dice.chance(ABUT_CHANCE);
        gap = 2 if abut else dice.between(GAP_LOW, GAP_HIGH);
        span_x = anchor.w + space.w;
        span_y = anchor.d + space.d;
        # Abutting rooms share at least four cells of wall.
        lead = 6 if abut else 1;
        if side == 0 {
            x = anchor.x + anchor.w + gap;
            y = anchor.y - space.d + lead + dice.below(max(1, span_y - 2 * lead));
        } elif side == 1 {
            x = anchor.x - gap - space.w;
            y = anchor.y - space.d + lead + dice.below(max(1, span_y - 2 * lead));
        } elif side == 2 {
            y = anchor.y + anchor.d + gap;
            x = anchor.x - space.w + lead + dice.below(max(1, span_x - 2 * lead));
        } else {
            y = anchor.y - gap - space.d;
            x = anchor.x - space.w + lead + dice.below(max(1, span_x - 2 * lead));
        }
        # Higher or lower than the anchor: onto one of its floor levels
        # often, otherwise by as much as the verticality wants.
        reach = int(4.0 + 12.0 * verticality);
        if abut {
            z = anchor.z;
        } elif anchor.levels and dice.chance(0.45) {
            level = anchor.levels[dice.below(len(anchor.levels))];
            z = level + dice.between(-1, 1) * (0 if dice.chance(0.6) else dice.between(2, 4));
        } else {
            z = anchor.z + dice.between(-reach, reach);
        }
        space.x = x;
        space.y = y;
        space.z = z;
        clear = True;
        for other in placed {
            if boxes_meet(space, other, 2 if (abut and other is anchor) else CLEARANCE, 2) {
                clear = False;
                break;
            }
        }
        if not clear {
            continue;
        }
        score = abs(space.middle_x() - anchor.middle_x()) + abs(space.middle_y() - anchor.middle_y())
            + 0.15 * float(abs(space.z - anchor.z)) - (6.0 if abut else 0.0);
        for friend in friends {
            score += 0.5 * (abs(space.middle_x() - friend.middle_x()) + abs(space.middle_y() - friend.middle_y()));
        }
        if best_score < 0.0 or score < best_score {
            best_score = score;
            best = [x, y, z];
        }
    }
    if not best {
        return False;
    }
    space.x = best[0];
    space.y = best[1];
    space.z = best[2];
    return True;
}

"""What each cell is reserved by: -1 nothing, otherwise the id of the space
(or corridor) whose air or wall it is."""
obj Reserve {
    has mass: Massing,
        held: list[int] = [],
        # For each cell, how many cells from it upward are free (solid and
        # held by nothing): a block fits where four columns run high enough.
        runs: list[int] = [];

    def postinit {
        if len(self.held) != self.mass.nx * self.mass.ny * self.mass.nz {
            self.held = [-1 for _ in range(self.mass.nx * self.mass.ny * self.mass.nz)];
        }
        if len(self.runs) != len(self.held) {
            self.runs = [0 for _ in range(len(self.held))];
            self.refresh(0, 0, self.mass.nx, self.mass.ny);
        }
    }

    """Count the free runs again in the columns of a box (x and y)."""
    def refresh(x0: int, y0: int, x1: int, y1: int) {
        mass = self.mass;
        layer = mass.nx * mass.ny;
        for y in range(max(0, y0), min(mass.ny, y1)) {
            for x in range(max(0, x0), min(mass.nx, x1)) {
                run = 0;
                for z in range(mass.nz - 1, -1, -1) {
                    index = z * layer + y * mass.nx + x;
                    if self.held[index] == -1 and mass.owner[index] == 0 {
                        run += 1;
                    } else {
                        run = 0;
                    }
                    self.runs[index] = run;
                }
            }
        }
    }

    def at(x: int, y: int, z: int) -> int {
        if not self.mass.inside(x, y, z) {
            return -2;
        }
        return self.held[(z * self.mass.ny + y) * self.mass.nx + x];
    }

    """Hold every cell within a cell of the given air for `owner`."""
    def hold_box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, owner: int) {
        for z in range(max(0, z0 - 1), min(self.mass.nz, z1 + 1)) {
            for y in range(max(0, y0 - 1), min(self.mass.ny, y1 + 1)) {
                for x in range(max(0, x0 - 1), min(self.mass.nx, x1 + 1)) {
                    index = (z * self.mass.ny + y) * self.mass.nx + x;
                    if self.held[index] == -1 {
                        self.held[index] = owner;
                    }
                }
            }
        }
    }
}

"""The block a corridor starts or ends with at a doorway: two cells square
across the wall, beginning in the wall."""
def doorway_block(space: Space, door: Doorway) -> list[int] {
    if door.side == 0 {
        return [space.x + space.w, space.y + door.along, door.level];
    }
    if door.side == 1 {
        return [space.x - 2, space.y + door.along, door.level];
    }
    if door.side == 2 {
        return [space.x + door.along, space.y + space.d, door.level];
    }
    return [space.x + door.along, space.y - 2, door.level];
}

"""The way a doorway faces out of its space, as a heading (0 +x, 1 -x, 2 +y,
3 -y): the side itself."""
def heading_step(heading: int) -> list[int] {
    if heading == 0 {
        return [1, 0];
    }
    if heading == 1 {
        return [-1, 0];
    }
    if heading == 2 {
        return [0, 1];
    }
    return [0, -1];
}

"""A min-heap of [cost, counter, state] for the search."""
obj Frontier {
    has items: list[list[float]] = [];

    def push(cost: float, state: int, counter: int) {
        self.items.append([cost, float(counter), float(state)]);
        at = len(self.items) - 1;
        while at > 0 {
            parent = (at - 1) // 2;
            if self.items[parent][0] < self.items[at][0]
                or (self.items[parent][0] == self.items[at][0] and self.items[parent][1] <= self.items[at][1]) {
                break;
            }
            swap = self.items[parent];
            self.items[parent] = self.items[at];
            self.items[at] = swap;
            at = parent;
        }
    }

    def pop -> int {
        top = self.items[0];
        last = self.items.pop();
        if self.items {
            self.items[0] = last;
            at = 0;
            count = len(self.items);
            while True {
                left = 2 * at + 1;
                right = left + 1;
                pick = at;
                if left < count and (self.items[left][0] < self.items[pick][0]
                    or (self.items[left][0] == self.items[pick][0] and self.items[left][1] < self.items[pick][1])) {
                    pick = left;
                }
                if right < count and (self.items[right][0] < self.items[pick][0]
                    or (self.items[right][0] == self.items[pick][0] and self.items[right][1] < self.items[pick][1])) {
                    pick = right;
                }
                if pick == at {
                    break;
                }
                swap = self.items[pick];
                self.items[pick] = self.items[at];
                self.items[at] = swap;
                at = pick;
            }
        }
        return int(top[2]);
    }
}

"""Whether a corridor block (two cells square, CORRIDOR_HIGH lifts high from
`z`) may go here: inside the grid, every cell solid and held by nothing but
the cells in `allowed`."""
def block_free(mass: Massing, reserve: Reserve, x: int, y: int, z: int, allowed: dict[int, bool], near: list[int] = []) -> bool {
    if x < 1 or y < 1 or z < 1 or x + 3 > mass.nx or y + 3 > mass.ny or z + CORRIDOR_HIGH + 1 > mass.nz {
        return False;
    }
    base = (z * mass.ny + y) * mass.nx + x;
    if reserve.runs[base] >= CORRIDOR_HIGH and reserve.runs[base + 1] >= CORRIDOR_HIGH
        and reserve.runs[base + mass.nx] >= CORRIDOR_HIGH and reserve.runs[base + mass.nx + 1] >= CORRIDOR_HIGH {
        return True;
    }
    # Only by the doorways at the ends may held cells be cut through.
    if not near or x + 1 < near[0] or x > near[1] or y + 1 < near[2] or y > near[3] {
        return False;
    }
    for cz in range(z, z + CORRIDOR_HIGH) {
        for cy in range(y, y + 2) {
            for cx in range(x, x + 2) {
                index = (cz * mass.ny + cy) * mass.nx + cx;
                if index in allowed {
                    continue;
                }
                if reserve.held[index] != -1 or mass.owner[index] != 0 {
                    return False;
                }
            }
        }
    }
    return True;
}

"""Route a corridor from one block to another: the blocks in order, or an
empty list when no way is found within the search's limit."""
def route_blocks(
    mass: Massing,
    reserve: Reserve,
    start: list[int],
    start_heading: int,
    goal: list[int],
    allowed: dict[int, bool],
    stats: list[int] = []
) -> list[list[int]] {
    nx = mass.nx;
    ny = mass.ny;
    nz = mass.nz;
    begin = ((start[2] * ny + start[1]) * nx + start[0]) * 4 + start_heading;
    near: list[int] = [nx, -1, ny, -1];
    for key in allowed.keys() {
        cell_x = key % nx;
        cell_y = (key // nx) % ny;
        near = [min(near[0], cell_x), max(near[1], cell_x), min(near[2], cell_y), max(near[3], cell_y)];
    }
    best: dict[int, float] = {begin: 0.0};
    came: dict[int, int] = {};
    frontier = Frontier();
    counter = 0;
    frontier.push(0.0, begin, counter);
    expanded = 0;
    # A search gives up in proportion to how far it has to go.
    reach = abs(goal[0] - start[0]) + abs(goal[1] - start[1]) + abs(goal[2] - start[2]);
    limit = min(SEARCH_LIMIT, 6000 + reach * 900);
    while frontier.items and expanded < limit {
        state = frontier.pop();
        expanded += 1;
        heading = state % 4;
        cell = state // 4;
        x = cell % nx;
        y = (cell // nx) % ny;
        z = cell // (nx * ny);
        if x == goal[0] and y == goal[1] and z == goal[2] {
            path: list[list[int]] = [];
            at = state;
            while True {
                spot = at // 4;
                path.append([spot % nx, (spot // nx) % ny, spot // (nx * ny)]);
                if at not in came {
                    break;
                }
                at = came[at];
            }
            path.reverse();
            stats.append(expanded);
            return path;
        }
        spent = best.get(state, 0.0);
        for turn in range(4) {
            if (turn == 0 and heading == 1) or (turn == 1 and heading == 0) or (turn == 2 and heading == 3)
                or (turn == 3 and heading == 2) {
                continue;
            }
            step = heading_step(turn);
            for rise in [0, 1, -1] {
                if rise != 0 and turn != heading {
                    continue;
                }
                nx_ = x + step[0];
                ny_ = y + step[1];
                nz_ = z + rise;
                if not block_free(mass, reserve, nx_, ny_, nz_, allowed, near) {
                    continue;
                }
                if rise != 0 and not block_free(mass, reserve, nx_, ny_, max(z, nz_), allowed, near) {
                    continue;
                }
                cost = spent + 1.0 + (0.5 if rise != 0 else 0.0) + (2.0 if turn != heading else 0.0);
                next_state = ((nz_ * ny + ny_) * nx + nx_) * 4 + turn;
                if next_state in best and best[next_state] <= cost {
                    continue;
                }
                best[next_state] = cost;
                came[next_state] = state;
                guess = float(max(abs(goal[0] - nx_) + abs(goal[1] - ny_), abs(goal[2] - nz_)));
                counter += 1;
                frontier.push(cost + guess, next_state, counter);
            }
        }
    }
    stats.append(expanded);
    stats.append(len(frontier.items));
    return [];
}

"""Carve a doorway straight through two walls (a block two cells deep along
`side`): the cell of the first wall at a floor a step from the first room's
toward the second's, the cell of the second at a floor a step on, so a
difference of two lifts is walked as two steps."""
def carve_through(mass: Massing, block: list[int], side: int, from_level: int, to_level: int, owner: int) {
    step = [1, 0] if side == 0 else ([-1, 0] if side == 1 else ([0, 1] if side == 2 else [0, -1]));
    across = [0, 1] if side < 2 else [1, 0];
    # The block's two cells along the crossing, from the first room's side.
    first = [block[0], block[1]];
    if step[0] < 0 or step[1] < 0 {
        first = [block[0] + (1 if step[0] < 0 else 0), block[1] + (1 if step[1] < 0 else 0)];
    }
    top = max(from_level, to_level) + CORRIDOR_HIGH;
    difference = to_level - from_level;
    for deep in range(2) {
        floor = to_level;
        if deep == 0 {
            floor = from_level + (1 if difference > 0 else -1) if abs(difference) == 2 else from_level;
        }
        cx = first[0] + step[0] * deep;
        cy = first[1] + step[1] * deep;
        for wide in range(2) {
            x = cx + across[0] * wide;
            y = cy + across[1] * wide;
            mass.carve(x, y, floor, x + 1, y + 1, top, owner);
        }
    }
}

"""The cells of a doorway's block that its own space holds (its wall),
which a corridor may cut through."""
def doorway_allowed(mass: Massing, block: list[int]) -> dict[int, bool] {
    found: dict[int, bool] = {};
    for cz in range(block[2], block[2] + CORRIDOR_HIGH) {
        for cy in range(block[1], block[1] + 2) {
            for cx in range(block[0], block[0] + 2) {
                if mass.inside(cx, cy, cz) {
                    found[(cz * mass.ny + cy) * mass.nx + cx] = True;
                }
            }
        }
    }
    return found;
}

"""Doorway pairs for a link, nearest first: the tail's doorways that face
the head and the head's that face the tail (a ledge at the head for a
one-way link)."""
def doorway_pairs(tail: Space, head: Space, one_way: bool) -> list[list[Doorway]] {
    scored: list[list[float]] = [];
    pairs: list[list[Doorway]] = [];
    for out in tail.sockets {
        if out.used or not out.floored {
            continue;
        }
        start = doorway_block(tail, out);
        for into in head.sockets {
            if into.used or (into.floored == one_way) {
                continue;
            }
            finish = doorway_block(head, into);
            gap = float(abs(start[0] - finish[0]) + abs(start[1] - finish[1]));
            climb = float(abs(start[2] - finish[2]));
            # Stairs climb a lift a block, with a flat block at each end: a
            # pair too close for its climb cannot be joined.
            # (Rooms wall to wall may meet through a doorway with steps in
            # its thickness, two lifts at most.)
            if climb > 0.0 and gap < climb + 2.0 and not (gap == 0.0 and climb <= 2.0) {
                continue;
            }
            scored.append([gap + 0.6 * climb, float(len(pairs))]);
            pairs.append([out, into]);
        }
    }
    return [pairs[index] for index in ranked([item[0] for item in scored])];
}

"""Arrange an expedition: place and shape its spaces, route its links.
Answers the estate and the massing carved."""
def arrange(plan: Expedition, dice: Stream) -> list[any] {
    estate = Estate(seed=plan.seed);
    every_beat = beats_of(plan);
    beats = [
        every_beat[index]
        for index in ranked([float(beat.order if beat.order >= 0 else 1000 + beat.id) for beat in every_beat])
    ];
    links = links_of(plan);
    spaces: dict[int, Space] = {};
    placed: list[Space] = [];
    for beat in beats {
        kind = pick_archetype(beat.kind, dice);
        dims = space_size(kind, beat.size, dice);
        space = Space(
            id=len(placed),
            beat=beat.id,
            role=beat.kind,
            kind=kind,
            district=beat.district,
            w=dims[0],
            d=dims[1],
            h=dims[2],
            tension=beat.tension,
            optional=beat.optional,
            order=beat.order,
            size=beat.size,
            variant=dice.below(24) if dice.chance(0.55) else 0
        );
        # Placeholder levels for placement: the archetype's are known once
        # shaped, so a guess from the kind.
        space.levels = [0];
        if not placed {
            space.x = 0;
            space.y = 0;
            space.z = 0;
        } else {
            friends: list[Space] = [];
            for link in links {
                other = link.head if link.tail == beat.id else (link.tail if link.head == beat.id else -1);
                if other >= 0 and other in spaces {
                    friends.append(spaces[other]);
                }
            }
            anchor = friends[0] if friends else placed[-1];
            placed_ok = place_beside(space, anchor, placed, friends[1:], dice.child("place", beat.id), plan.verticality);
            if not placed_ok {
                # Further out, anywhere round the last placed space.
                for spread in range(1, 4) {
                    if not placed_ok {
                        placed_ok = place_beside(space, placed[dice.below(len(placed))], placed, [], dice.child("again", beat.id * 8 + spread), plan.verticality);
                    }
                }
            }
            if not placed_ok {
                estate.failures.append("unplaced beat " + str(beat.id));
                continue;
            }
        }
        spaces[beat.id] = space;
        placed.append(space);
        estate +>:Encloses:+> space;
    }
    # Shift everything into the grid with a margin all round.
    low_x = min([space.x for space in placed]) - MARGIN;
    low_y = min([space.y for space in placed]) - MARGIN;
    low_z = min([space.z for space in placed]) - MARGIN;
    high_x = max([space.x + space.w for space in placed]) + MARGIN;
    high_y = max([space.y + space.d for space in placed]) + MARGIN;
    high_z = max([space.z + space.h for space in placed]) + MARGIN;
    for space in placed {
        space.x -= low_x;
        space.y -= low_y;
        space.z -= low_z;
    }
    estate.nx = high_x - low_x;
    estate.ny = high_y - low_y;
    estate.nz = high_z - low_z + CORRIDOR_HIGH;
    mass = Massing(nx=estate.nx, ny=estate.ny, nz=estate.nz);
    reserve = Reserve(mass=mass);
    for space in placed {
        shape_space(space, mass, dice.child("shape", space.beat));
        reserve.hold_box(space.x, space.y, space.z, space.x + space.w, space.y + space.d, space.z + space.h, space.id);
    }
    reserve.refresh(0, 0, mass.nx, mass.ny);
    # Links: the main way first (in progression order), loops after.
    link_rank: list[float] = [];
    for link in links {
        tail_order = spaces[link.tail].order if link.tail in spaces else 999;
        head_order = spaces[link.head].order if link.head in spaces else 999;
        link_rank.append(float(max(tail_order, head_order)));
    }
    ordered_links = [links[index] for index in ranked(link_rank)];
    wanted_windows: list[list[int]] = [];
    for link in ordered_links {
        if link.tail not in spaces or link.head not in spaces {
            estate.failures.append("link " + str(link.id) + " lost a space");
            continue;
        }
        tail = spaces[link.tail];
        head = spaces[link.head];
        corridor_space = Space(id=len(placed), role="corridor", kind="corridor", district=tail.district, tension=tail.tension);
        corridor_space.levels = [];
        made = False;
        if link.mode == "window" {
            wanted_windows.append([tail.id, head.id]);
            tail +>:Corridor(link=link.id, mode=link.mode, needs=link.needs, tail=tail.id, head=head.id, window=True):+> head;
            continue;
        }
        one_way = link.mode == "valve";
        tries = 0;
        # A one-way link wants a ledge to drop from; where none can be had
        # it is a way like any other (a way back only adds to the level).
        pairs = doorway_pairs(tail, head, one_way);
        if one_way {
            pairs = pairs[:6] + doorway_pairs(tail, head, False);
        }
        for pair in pairs {
            if tries >= 12 or made {
                break;
            }
            tries += 1;
            out = pair[0];
            into = pair[1];
            start = doorway_block(tail, out);
            goal = doorway_block(head, into);
            if start[0] == goal[0] and start[1] == goal[1] {
                # Wall to wall: a doorway straight through both walls, a
                # step down (or up) in each wall's cell where the floors
                # differ.
                out.used = True;
                into.used = True;
                carve_through(mass, start, out.side, out.level, into.level, corridor_space.id);
                reserve.hold_box(start[0], start[1], min(out.level, into.level), start[0] + 2, start[1] + 2, max(out.level, into.level) + CORRIDOR_HIGH, corridor_space.id);
                reserve.refresh(start[0] - 1, start[1] - 1, start[0] + 3, start[1] + 3);
                corridor_space.x = start[0];
                corridor_space.y = start[1];
                corridor_space.z = min(out.level, into.level);
                corridor_space.w = 2;
                corridor_space.d = 2;
                corridor_space.h = abs(out.level - into.level) + CORRIDOR_HIGH;
                placed.append(corridor_space);
                estate +>:Encloses:+> corridor_space;
                tail +>:Corridor(
                    link=link.id,
                    mode=link.mode,
                    needs=link.needs,
                    tail=tail.id,
                    head=head.id,
                    out_door=out,
                    in_door=into,
                    blocks=[start],
                    air=corridor_space.id
                ):+> head;
                made = True;
                continue;
            }
            allowed = doorway_allowed(mass, start);
            for (key, value) in doorway_allowed(mass, goal).items() {
                allowed[key] = value;
            }
            path = route_blocks(mass, reserve, start, out.side, goal, allowed);
            if not path {
                continue;
            }
            out.used = True;
            into.used = True;
            for block in path {
                mass.carve(block[0], block[1], block[2], block[0] + 2, block[1] + 2, block[2] + CORRIDOR_HIGH, corridor_space.id);
            }
            for block in path {
                reserve.hold_box(block[0], block[1], block[2], block[0] + 2, block[1] + 2, block[2] + CORRIDOR_HIGH, corridor_space.id);
            }
            reserve.refresh(
                min([block[0] for block in path]) - 1,
                min([block[1] for block in path]) - 1,
                max([block[0] for block in path]) + 3,
                max([block[1] for block in path]) + 3
            );
            corridor_space.x = min([block[0] for block in path]);
            corridor_space.y = min([block[1] for block in path]);
            corridor_space.z = min([block[2] for block in path]);
            corridor_space.w = max([block[0] for block in path]) + 2 - corridor_space.x;
            corridor_space.d = max([block[1] for block in path]) + 2 - corridor_space.y;
            corridor_space.h = max([block[2] for block in path]) + CORRIDOR_HIGH - corridor_space.z;
            placed.append(corridor_space);
            estate +>:Encloses:+> corridor_space;
            tail +>:Corridor(
                link=link.id,
                mode=link.mode,
                needs=link.needs,
                tail=tail.id,
                head=head.id,
                out_door=out,
                in_door=into,
                blocks=path,
                air=corridor_space.id
            ):+> head;
            made = True;
        }
        if not made {
            estate.teleports += 1;
            tail +>:Corridor(link=link.id, mode=link.mode, needs=link.needs, tail=tail.id, head=head.id, teleport=True):+> head;
        }
    }
    cut_windows(estate, mass, reserve, placed, wanted_windows, dice.derive("windows"));
    return [estate, mass];
}

"""A window between two rooms whose boxes face each other across a gap of
two to six cells: [axis (0 x, 1 y), the gap's first cell along it and its
end, the span across it and up (low, high each)], or none. The window
stands where both rooms have air from its sill to its head, the sill
`sill` lifts over the higher floor."""
def window_between(a: Space, b: Space, mass: Massing, sill: int) -> list[int] | None {
    for axis in range(2) {
        first = a if (a.x if axis == 0 else a.y) < (b.x if axis == 0 else b.y) else b;
        second = b if first is a else a;
        near_end = (first.x + first.w) if axis == 0 else (first.y + first.d);
        far_start = second.x if axis == 0 else second.y;
        gap = far_start - near_end;
        if gap < 2 or gap > 6 {
            continue;
        }
        across_low = max(first.y, second.y) if axis == 0 else max(first.x, second.x);
        across_high = min(first.y + first.d, second.y + second.d) if axis == 0 else min(first.x + first.w, second.x + second.w);
        if across_high - across_low < 5 {
            continue;
        }
        bottom = max(first.z, second.z) + sill;
        top = bottom + 4;
        if top > min(first.z + first.h, second.z + second.h) - 1 {
            continue;
        }
        middle = (across_low + across_high) // 2 - 1;
        # Air just inside each room at every cell of the window's face.
        clear = True;
        for across in range(middle, middle + 3) {
            for up in range(bottom, top) {
                inside_first = [near_end - 1, across] if axis == 0 else [across, near_end - 1];
                inside_second = [far_start, across] if axis == 0 else [across, far_start];
                if not mass.air(inside_first[0], inside_first[1], up) or not mass.air(inside_second[0], inside_second[1], up) {
                    clear = False;
                }
            }
        }
        if clear {
            return [axis, near_end, far_start, middle, middle + 3, bottom, top];
        }
    }
    return None;
}

"""Windows: openings between rooms near each other, barred so nothing
passes but sight. The mission's own windows first (a room seen before it
is reached), then a few more where rooms overlook each other."""
def cut_windows(estate: Estate, mass: Massing, reserve: Reserve, placed: list[Space], wanted: list[list[int]], dice: Stream) {
    rooms = [space for space in placed if space.role not in ["corridor", "window"]];
    by_id: dict[int, Space] = {};
    for space in rooms {
        by_id[space.id] = space;
    }
    pairs: list[list[int]] = [pair for pair in wanted];
    scores: list[float] = [];
    others: list[list[int]] = [];
    for (index, a) in enumerate(rooms) {
        for b in rooms[index + 1:] {
            others.append([a.id, b.id]);
            scores.append(-float(abs(a.z - b.z)) - dice.unit() * 4.0);
        }
    }
    for at in ranked(scores) {
        pairs.append(others[at]);
    }
    made = 0;
    for pair in pairs {
        if made >= 6 or pair[0] not in by_id or pair[1] not in by_id {
            continue;
        }
        a = by_id[pair[0]];
        b = by_id[pair[1]];
        shape = window_between(a, b, mass, dice.between(4, 6));
        if shape is None {
            continue;
        }
        axis = shape[0];
        # Through the walls and the gap: only rock, held by nothing but the
        # two rooms' walls.
        free = True;
        for along in range(shape[1], shape[2]) {
            for across in range(shape[3], shape[4]) {
                for up in range(shape[5], shape[6]) {
                    cx = along if axis == 0 else across;
                    cy = across if axis == 0 else along;
                    held = reserve.at(cx, cy, up);
                    if mass.air(cx, cy, up) or (held != -1 and held != a.id and held != b.id) {
                        free = False;
                    }
                }
            }
        }
        if not free {
            continue;
        }
        window = Space(id=len(placed), role="window", kind="window_x" if axis == 0 else "window_y", district=a.district, tension=a.tension);
        if axis == 0 {
            window.x = shape[1];
            window.y = shape[3];
            window.w = shape[2] - shape[1];
            window.d = shape[4] - shape[3];
        } else {
            window.x = shape[3];
            window.y = shape[1];
            window.w = shape[4] - shape[3];
            window.d = shape[2] - shape[1];
        }
        window.z = shape[5];
        window.h = shape[6] - shape[5];
        window.levels = [];
        mass.carve(window.x, window.y, window.z, window.x + window.w, window.y + window.d, window.z + window.h, window.id);
        reserve.hold_box(window.x, window.y, window.z, window.x + window.w, window.y + window.d, window.z + window.h, window.id);
        reserve.refresh(window.x - 1, window.y - 1, window.x + window.w + 1, window.y + window.d + 1);
        placed.append(window);
        estate +>:Encloses:+> window;
        estate.windows += 1;
        made += 1;
    }
}
