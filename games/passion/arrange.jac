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
     MARGIN: int = 4,
     SEARCH_LIMIT: int = 120000;

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
        gap = dice.between(GAP_LOW, GAP_HIGH);
        span_x = anchor.w + space.w;
        span_y = anchor.d + space.d;
        if side == 0 {
            x = anchor.x + anchor.w + gap;
            y = anchor.y - space.d + 1 + dice.below(max(1, span_y - 2));
        } elif side == 1 {
            x = anchor.x - gap - space.w;
            y = anchor.y - space.d + 1 + dice.below(max(1, span_y - 2));
        } elif side == 2 {
            y = anchor.y + anchor.d + gap;
            x = anchor.x - space.w + 1 + dice.below(max(1, span_x - 2));
        } else {
            y = anchor.y - gap - space.d;
            x = anchor.x - space.w + 1 + dice.below(max(1, span_x - 2));
        }
        # Higher or lower than the anchor: onto one of its floor levels
        # often, otherwise by as much as the verticality wants.
        reach = int(4.0 + 12.0 * verticality);
        if anchor.levels and dice.chance(0.45) {
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
            if boxes_meet(space, other, CLEARANCE, 2) {
                clear = False;
                break;
            }
        }
        if not clear {
            continue;
        }
        score = abs(space.middle_x() - anchor.middle_x()) + abs(space.middle_y() - anchor.middle_y())
            + 0.15 * float(abs(space.z - anchor.z));
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
        held: list[int] = [];

    def postinit {
        if len(self.held) != self.mass.nx * self.mass.ny * self.mass.nz {
            self.held = [-1 for _ in range(self.mass.nx * self.mass.ny * self.mass.nz)];
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
def block_free(mass: Massing, reserve: Reserve, x: int, y: int, z: int, allowed: dict[int, bool]) -> bool {
    if x < 1 or y < 1 or z < 1 or x + 3 > mass.nx or y + 3 > mass.ny or z + CORRIDOR_HIGH + 1 > mass.nz {
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
    best: dict[int, float] = {begin: 0.0};
    came: dict[int, int] = {};
    frontier = Frontier();
    counter = 0;
    frontier.push(0.0, begin, counter);
    expanded = 0;
    while frontier.items and expanded < SEARCH_LIMIT {
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
                if not block_free(mass, reserve, nx_, ny_, nz_, allowed) {
                    continue;
                }
                if rise != 0 and not block_free(mass, reserve, nx_, ny_, max(z, nz_), allowed) {
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
            if climb > 0.0 and gap < climb + 2.0 {
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
            size=beat.size
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
    # Links: the main way first (in progression order), loops after.
    link_rank: list[float] = [];
    for link in links {
        tail_order = spaces[link.tail].order if link.tail in spaces else 999;
        head_order = spaces[link.head].order if link.head in spaces else 999;
        link_rank.append(float(max(tail_order, head_order)));
    }
    ordered_links = [links[index] for index in ranked(link_rank)];
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
            estate.windows += 1;
            tail +>:Corridor(link=link.id, mode=link.mode, needs=link.needs, tail=tail.id, head=head.id, window=True):+> head;
            continue;
        }
        one_way = link.mode == "valve";
        tries = 0;
        for pair in doorway_pairs(tail, head, one_way) {
            if tries >= 16 or made {
                break;
            }
            tries += 1;
            out = pair[0];
            into = pair[1];
            start = doorway_block(tail, out);
            goal = doorway_block(head, into);
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
    return [estate, mass];
}
