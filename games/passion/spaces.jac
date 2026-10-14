"""Spaces: the rooms of an expedition as boxes in the massing, each shaped
by an archetype that gives it height and structure of its own.

A space is a node standing for one mission beat. Its box (`x`, `y`, `z`
low corner in cells, `w` by `d` cells across and `h` lifts high) is carved
into the massing, and its archetype then puts solid back: balconies around
an atrium, a bridge over a chasm, an arcade round an open court, terraces
and stairs. The floor heights that matter (`levels`) are where doorways may
open; `sockets` lists the places along its walls where one can, found from
the carved cells themselves, so any archetype gets them right."""
import math;
import from .random { Stream }
import from .massing { Massing, floor_reached }

glob OPEN_HIGH: int = 6;

# Archetypes, and the ones each kind of beat may take with their weights.
glob ARCHETYPES: list[str] = [
         "hall",
         "atrium",
         "shaft",
         "chasm",
         "court",
         "terraces",
         "stairhall",
         "vault",
         "arena",
         "crypt"
     ];

glob KIND_ARCHETYPES: dict[str, list[float]] = {
         "start": [3.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0],
         "goal": [2.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 2.0, 1.0],
         "key": [1.0, 2.0, 1.5, 2.0, 0.0, 1.0, 0.0, 2.0, 0.0, 1.0],
         "switch": [2.0, 1.0, 1.0, 1.0, 0.0, 2.0, 2.0, 0.0, 0.0, 1.0],
         "arena": [0.0, 2.0, 0.0, 1.0, 2.0, 0.0, 0.0, 0.0, 3.0, 0.0],
         "junction": [2.0, 0.0, 1.0, 0.0, 0.0, 2.0, 2.0, 0.0, 0.0, 1.0],
         "hub": [1.0, 3.0, 0.0, 2.0, 2.0, 1.0, 1.0, 0.0, 1.0, 0.0],
         "room": [2.0, 1.0, 0.5, 1.0, 1.0, 2.0, 1.0, 0.0, 1.0, 1.5],
         "cache": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]
     };

"""Where a doorway can open in a space's wall: the side (0 +x, 1 -x, 2 +y,
3 -y), how far along it (cells from the box's low corner), the floor level
(lift, absolute), its width in cells, and whether a floor meets it inside
(`floored`; a doorway without one is a ledge to drop from)."""
obj Doorway {
    has side: int,
        along: int,
        level: int,
        span: int = 2,
        floored: bool = True,
        used: bool = False;
}

"""A space: one beat of the mission as a room."""
node Space {
    has id: int,
        beat: int = -1,
        role: str = "room",
        kind: str = "hall",
        district: int = 0,
        x: int = 0,
        y: int = 0,
        z: int = 0,
        w: int = 8,
        d: int = 8,
        h: int = 10,
        tension: float = 0.0,
        optional: bool = False,
        order: int = 0,
        size: int = 1,
        sky: bool = False,
        levels: list[int] = [],
        sockets: list[Doorway] = [],
        # A cell to stand an objective on: [x, y, z].
        stage: list[int] = [],
        # Cells kept clear of cover and props: stairs, stage and its path.
        kept: list[list[int]] = [];

    def middle_x -> float {
        return float(self.x) + float(self.w) * 0.5;
    }

    def middle_y -> float {
        return float(self.y) + float(self.d) * 0.5;
    }

    def holds(cx: int, cy: int, cz: int) -> bool {
        return self.x <= cx < self.x + self.w and self.y <= cy < self.y + self.d and self.z <= cz < self.z + self.h;
    }
}

"""The size of a space for its archetype and the beat's size: [w, d, h]."""
def space_size(kind: str, size: int, dice: Stream) -> list[int] {
    grow = max(0, min(3, size));
    if kind == "atrium" {
        side = dice.between(13, 15) + grow;
        return [side, dice.between(13, 15) + grow, dice.between(26, 30)];
    }
    if kind == "shaft" {
        side = dice.between(8, 9);
        return [side, side, dice.between(30, 38)];
    }
    if kind == "chasm" {
        return [dice.between(10, 13) + grow, dice.between(13, 17) + grow, dice.between(22, 28)];
    }
    if kind == "court" {
        return [dice.between(14, 17) + grow, dice.between(14, 17) + grow, dice.between(18, 22)];
    }
    if kind == "terraces" {
        return [dice.between(10, 13) + grow, dice.between(13, 16) + grow, dice.between(14, 18)];
    }
    if kind == "stairhall" {
        return [dice.between(10, 13) + grow, dice.between(14, 18) + grow, dice.between(16, 20)];
    }
    if kind == "vault" {
        return [dice.between(7, 9), dice.between(7, 9), dice.between(10, 12)];
    }
    if kind == "arena" {
        side = dice.between(15, 18) + grow;
        return [side, dice.between(15, 18) + grow, dice.between(14, 18)];
    }
    if kind == "crypt" {
        return [dice.between(10, 13) + grow, dice.between(12, 16) + grow, dice.between(9, 11)];
    }
    return [dice.between(8, 12) + grow * 2, dice.between(9, 13) + grow * 2, dice.between(10, 14) + grow];
}

"""An archetype for a beat's kind."""
def pick_archetype(role: str, dice: Stream) -> str {
    weights = KIND_ARCHETYPES.get(role, KIND_ARCHETYPES["room"]);
    return ARCHETYPES[dice.weighted(weights)];
}

"""Carve a space into the massing and shape it by its archetype; then find
its sockets."""
def shape_space(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    x1 = space.x + space.w;
    y1 = space.y + space.d;
    z1 = space.z + space.h;
    owner = space.id;
    mass.carve(x0, y0, z0, x1, y1, z1, owner);
    space.levels = [z0];
    space.stage = [x0 + space.w // 2, y0 + space.d // 2, z0];
    kind = space.kind;
    if kind == "hall" {
        shape_hall(space, mass, dice);
    } elif kind == "atrium" {
        shape_atrium(space, mass, dice);
    } elif kind == "shaft" {
        shape_shaft(space, mass, dice);
    } elif kind == "chasm" {
        shape_chasm(space, mass, dice);
    } elif kind == "court" {
        shape_court(space, mass, dice);
    } elif kind == "terraces" {
        shape_terraces(space, mass, dice);
    } elif kind == "stairhall" {
        shape_stairhall(space, mass, dice);
    } elif kind == "vault" {
        shape_vault(space, mass, dice);
    } elif kind == "arena" {
        shape_arena(space, mass, dice);
    } elif kind == "crypt" {
        shape_crypt(space, mass, dice);
    }
    # Only floor levels the stage can be walked to are kept for doorways.
    reached = floor_reached(mass, space.stage[0], space.stage[1], space.stage[2]);
    kept_levels: list[int] = [];
    for level in space.levels {
        found = False;
        for cy in range(space.y, space.y + space.d) {
            for cx in range(space.x, space.x + space.w) {
                if not found and ((level * mass.ny + cy) * mass.nx + cx) in reached {
                    found = True;
                }
            }
        }
        if found {
            kept_levels.append(level);
        }
    }
    space.levels = kept_levels;
    find_sockets(space, mass);
}

"""A flight of stairs from (sx, sy) running `length` cells along (dx, dy),
`wide` cells across, rising a lift a cell from `base` (each step solid down
to `base`, or only a slab of `slab` lifts when `slab` > 0, for stairs that
fly over space)."""
def lay_stairs(
    space: Space,
    mass: Massing,
    sx: int,
    sy: int,
    dx: int,
    dy: int,
    length: int,
    wide: int,
    base: int,
    slab: int = 0,
    rise: int = 1
) {
    across_x = 0 if dx != 0 else 1;
    across_y = 0 if dy != 0 else 1;
    for step in range(length) {
        top = base + (step + 1) * rise;
        for side in range(wide) {
            cx = sx + dx * step + across_x * side;
            cy = sy + dy * step + across_y * side;
            bottom = base if slab <= 0 else max(base, top - slab);
            mass.fill(cx, cy, bottom, cx + 1, cy + 1, top);
            space.kept.append([cx, cy, top]);
        }
    }
}

"""A hall: one floor, sometimes a dais at one end with steps up to it, and
rows of pillars when it is wide enough."""
def shape_hall(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    if space.d >= 9 and dice.chance(0.6) {
        depth = 3;
        mass.fill(x0, space.y + space.d - depth, z0, x0 + space.w, space.y + space.d, z0 + 2);
        # Two steps across the middle third.
        third = max(2, space.w // 3);
        start = x0 + (space.w - third) // 2;
        mass.fill(start, space.y + space.d - depth - 1, z0, start + third, space.y + space.d - depth, z0 + 1);
        for cx in range(start, start + third) {
            space.kept.append([cx, space.y + space.d - depth - 1, z0 + 1]);
        }
        space.levels.append(z0 + 2);
        space.stage = [x0 + space.w // 2, space.y + space.d - 2, z0 + 2];
    }
    if space.w >= 10 and space.h >= 9 and dice.chance(0.7) {
        place_pillar_rows(space, mass, dice, 2);
    }
}

"""Pillars a cell square in two rows `inset` cells in from the long walls."""
def place_pillar_rows(space: Space, mass: Massing, dice: Stream, inset: int) {
    gap = dice.between(3, 4);
    along_x = space.w >= space.d;
    length = space.w if along_x else space.d;
    for at in range(2, length - 2, gap) {
        for row in [inset, (space.d if along_x else space.w) - inset - 1] {
            cx = space.x + at if along_x else space.x + row;
            cy = space.y + row if along_x else space.y + at;
            if mass.standing(cx, cy, space.z) {
                mass.fill(cx, cy, space.z, cx + 1, cy + 1, space.z + space.h);
            }
        }
    }
}

"""An atrium: tall, with a balcony round its walls at a second floor and a
flight of stairs up to it along the inside of the balcony, on the longer
side; the balcony is set no higher than the stairs can climb."""
def shape_atrium(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    ring = dice.between(2, 3);
    along_x = space.w >= space.d;
    room = (space.w if along_x else space.d) - 2 * ring - 2;
    rise = min(dice.between(8, 10), room);
    level = z0 + rise;
    # The balcony: a slab a lift thick round the walls.
    for cy in range(y0, y0 + space.d) {
        for cx in range(x0, x0 + space.w) {
            inset = min(min(cx - x0, x0 + space.w - 1 - cx), min(cy - y0, y0 + space.d - 1 - cy));
            if inset < ring {
                mass.fill(cx, cy, level - 1, cx + 1, cy + 1, level);
            }
        }
    }
    # Stairs just inside the balcony, rising from one corner, their top
    # step a lift under the balcony beside it.
    if along_x {
        lay_stairs(space, mass, x0 + ring, y0 + ring, 1, 0, rise - 1, 2, z0);
        mass.fill(x0 + ring + rise - 1, y0 + ring, level - 1, x0 + ring + rise + 1, y0 + ring + 2, level);
    } else {
        lay_stairs(space, mass, x0 + ring, y0 + ring, 0, 1, rise - 1, 2, z0);
        mass.fill(x0 + ring, y0 + ring + rise - 1, level - 1, x0 + ring + 2, y0 + ring + rise + 1, level);
    }
    space.levels.append(level);
    space.stage = [x0 + space.w // 2, y0 + space.d // 2, z0];
    if dice.chance(0.5) {
        # Pillars hold the balcony up at its inner corners.
        for (cx, cy) in [
            (x0 + ring, y0 + space.d - ring - 1),
            (x0 + space.w - ring - 1, y0 + space.d - ring - 1),
            (x0 + space.w - ring - 1, y0 + ring)
        ] {
            mass.fill(cx, cy, z0, cx + 1, cy + 1, level);
        }
    }
}

"""A shaft: narrow and tall, its stairs winding up round the walls as a
ribbon two cells wide with a landing where each wall begins, open in the
middle."""
def shape_shaft(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    x1 = space.x + space.w;
    y1 = space.y + space.d;
    z0 = space.z;
    # The ribbon's positions in order round the walls, each two cells
    # across, and where each wall's leg begins.
    path: list[list[int]] = [];
    starts: list[int] = [];
    starts.append(len(path));
    for cx in range(x0, x1) {
        path.append([cx, y0, cx, y0 + 1]);
    }
    starts.append(len(path));
    for cy in range(y0 + 2, y1) {
        path.append([x1 - 1, cy, x1 - 2, cy]);
    }
    starts.append(len(path));
    for cx in range(x1 - 3, x0 - 1, -1) {
        path.append([cx, y1 - 1, cx, y1 - 2]);
    }
    starts.append(len(path));
    for cy in range(y1 - 3, y0 + 1, -1) {
        path.append([x0, cy, x0 + 1, cy]);
    }
    height = z0;
    top = z0 + space.h - OPEN_HIGH - 2;
    levels: list[int] = [z0];
    laps = 0;
    while height < top and laps < 8 {
        for (index, cells) in enumerate(path) {
            landing = False;
            for start in starts {
                if index == start or index == start + 1 {
                    landing = True;
                }
            }
            if not landing {
                if height + 1 >= top {
                    break;
                }
                height += 1;
            } elif height not in levels {
                levels.append(height);
            }
            for pick in [0, 2] {
                cx = cells[pick];
                cy = cells[pick + 1];
                if height > z0 {
                    mass.fill(cx, cy, height - 1, cx + 1, cy + 1, height);
                }
                space.kept.append([cx, cy, height]);
            }
        }
        laps += 1;
    }
    space.levels = levels;
    space.stage = [x0 + space.w // 2, y0 + space.d // 2, z0];
}

"""A chasm: a deep pit crossed by a bridge, so one way runs over another."""
def shape_chasm(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    # The stairs from the pit run along the far wall, clear of the bridge,
    # up to a ledge, and must fit between the two ledges.
    rise = min(dice.between(9, 12), space.w - 3);
    level = z0 + rise;
    width = dice.between(2, 3);
    middle = y0 + (space.d - width) // 2;
    mass.fill(x0, middle, level - 1, x0 + space.w, middle + width, level);
    # Ledges along both ends where the bridge lands.
    for cx in [x0, x0 + space.w - 2] {
        mass.fill(cx, y0 + 1, level - 1, cx + 2, y0 + space.d - 1, level);
    }
    space.levels.append(level);
    space.stage = [x0 + space.w // 2, middle + width // 2, level] if dice.chance(0.5) else [
        x0 + space.w // 2,
        y0 + 2,
        z0
    ];
    # Stairs from the floor of the pit up to the first ledge, along the far
    # wall, their top step beside the ledge.
    lay_stairs(space, mass, x0 + rise, y0 + space.d - 2, -1, 0, rise - 1, 1, z0);
}

"""An open court under the sky, with a covered arcade round its walls."""
def shape_court(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    space.sky = True;
    ring = 3;
    roof = z0 + dice.between(8, 9);
    for cy in range(y0, y0 + space.d) {
        for cx in range(x0, x0 + space.w) {
            inset = min(min(cx - x0, x0 + space.w - 1 - cx), min(cy - y0, y0 + space.d - 1 - cy));
            if inset < ring {
                mass.fill(cx, cy, roof, cx + 1, cy + 1, roof + 2);
            }
        }
    }
    gap = 3;
    for at in range(ring - 1, space.w - ring + 1, gap) {
        for cy in [y0 + ring - 1, y0 + space.d - ring] {
            mass.fill(x0 + at, cy, z0, x0 + at + 1, cy + 1, roof);
        }
    }
    for at in range(ring - 1, space.d - ring + 1, gap) {
        for cx in [x0 + ring - 1, x0 + space.w - ring] {
            mass.fill(cx, y0 + at, z0, cx + 1, y0 + at + 1, roof);
        }
    }
    space.stage = [x0 + space.w // 2, y0 + space.d // 2, z0];
}

"""Terraces: the floor in tiers up the room's length, joined by stairs."""
def shape_terraces(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    tiers = 3 if space.d >= 13 else 2;
    band = space.d // tiers;
    rise = dice.between(3, 4);
    stair_x = x0 + dice.between(1, max(1, space.w - 4));
    for tier in range(1, tiers) {
        top = z0 + tier * rise;
        mass.fill(x0, y0 + tier * band, z0, x0 + space.w, y0 + space.d, top);
        lay_stairs(space, mass, stair_x, y0 + tier * band - rise, 0, 1, rise, 3, z0 + (tier - 1) * rise);
        space.levels.append(top);
        stair_x = x0 + space.w - 4 - (stair_x - x0) if space.w > 6 else stair_x;
    }
    space.stage = [x0 + space.w // 2, y0 + space.d - 2, z0 + (tiers - 1) * rise];
}

"""A stair hall: a low floor and a high one joined by a broad flight."""
def shape_stairhall(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    rise = dice.between(5, 7);
    upper = y0 + space.d // 2 + rise // 2;
    mass.fill(x0, upper, z0, x0 + space.w, y0 + space.d, z0 + rise);
    wide = max(3, space.w - 4);
    lay_stairs(space, mass, x0 + (space.w - wide) // 2, upper - rise, 0, 1, rise, wide, z0);
    space.levels.append(z0 + rise);
    space.stage = [x0 + space.w // 2, y0 + space.d - 2, z0 + rise];
}

"""A vault: small, with a dais in the middle for what it keeps."""
def shape_vault(space: Space, mass: Massing, dice: Stream) {
    middle_x = space.x + space.w // 2 - 1;
    middle_y = space.y + space.d // 2 - 1;
    mass.fill(middle_x - 1, middle_y - 1, space.z, middle_x + 3, middle_y + 3, space.z + 1);
    mass.fill(middle_x, middle_y, space.z + 1, middle_x + 2, middle_y + 2, space.z + 2);
    space.stage = [middle_x, middle_y, space.z + 2];
    space.levels.append(space.z + 2);
}

"""An arena: a sunken floor ringed by a raised walk, with stairs down on
each side and pillars at the corners of the pit."""
def shape_arena(space: Space, mass: Massing, dice: Stream) {
    x0 = space.x;
    y0 = space.y;
    z0 = space.z;
    rise = 3;
    ring = dice.between(3, 4);
    for cy in range(y0, y0 + space.d) {
        for cx in range(x0, x0 + space.w) {
            inset = min(min(cx - x0, x0 + space.w - 1 - cx), min(cy - y0, y0 + space.d - 1 - cy));
            if inset < ring {
                mass.fill(cx, cy, z0, cx + 1, cy + 1, z0 + rise);
            }
        }
    }
    middle_x = x0 + space.w // 2 - 1;
    middle_y = y0 + space.d // 2 - 1;
    for step in range(rise - 1) {
        # Down from the ring on each side: the cell beside the pit a lift
        # above it, each further out a lift higher, up to the ring.
        floor = z0 + 1 + step;
        for side in range(2) {
            mass.carve(middle_x + side, y0 + ring - 1 - step, floor, middle_x + side + 1, y0 + ring - step, z0 + rise, space.id);
            mass.carve(middle_x + side, y0 + space.d - ring + step, floor, middle_x + side + 1, y0 + space.d - ring + step + 1, z0 + rise, space.id);
            mass.carve(x0 + ring - 1 - step, middle_y + side, floor, x0 + ring - step, middle_y + side + 1, z0 + rise, space.id);
            mass.carve(x0 + space.w - ring + step, middle_y + side, floor, x0 + space.w - ring + step + 1, middle_y + side + 1, z0 + rise, space.id);
            space.kept.append([middle_x + side, y0 + ring - 1 - step, floor]);
            space.kept.append([middle_x + side, y0 + space.d - ring + step, floor]);
            space.kept.append([x0 + ring - 1 - step, middle_y + side, floor]);
            space.kept.append([x0 + space.w - ring + step, middle_y + side, floor]);
        }
    }
    for (cx, cy) in [
        (x0 + ring, y0 + ring),
        (x0 + space.w - ring - 1, y0 + ring),
        (x0 + ring, y0 + space.d - ring - 1),
        (x0 + space.w - ring - 1, y0 + space.d - ring - 1)
    ] {
        mass.fill(cx, cy, z0, cx + 1, cy + 1, z0 + space.h);
    }
    space.levels = [z0 + rise, z0];
    space.stage = [middle_x, middle_y, z0];
}

"""A crypt: low, with a grid of squat pillars holding up its ceiling."""
def shape_crypt(space: Space, mass: Massing, dice: Stream) {
    gap = 3;
    for cx in range(space.x + 2, space.x + space.w - 2, gap) {
        for cy in range(space.y + 2, space.y + space.d - 2, gap) {
            mass.fill(cx, cy, space.z, cx + 1, cy + 1, space.z + space.h);
        }
    }
    space.stage = [space.x + space.w // 2, space.y + space.d - 2, space.z];
    if not mass.standing(space.stage[0], space.stage[1], space.stage[2]) {
        space.stage = [space.x + space.w // 2 + 1, space.y + space.d - 2, space.z];
    }
}

"""The wall cells of a side at `along`: the cell outside the box, for each
cell of the span, as [x, y]; and the cell just inside."""
def socket_cells(space: Space, side: int, along: int, span: int) -> list[list[int]] {
    cells: list[list[int]] = [];
    for offset in range(span) {
        if side == 0 {
            cells.append([space.x + space.w, space.y + along + offset, space.x + space.w - 1, space.y + along + offset]);
        } elif side == 1 {
            cells.append([space.x - 1, space.y + along + offset, space.x, space.y + along + offset]);
        } elif side == 2 {
            cells.append([space.x + along + offset, space.y + space.d, space.x + along + offset, space.y + space.d - 1]);
        } else {
            cells.append([space.x + along + offset, space.y - 1, space.x + along + offset, space.y]);
        }
    }
    return cells;
}

"""Find where doorways can open: along every side, at every level, a span
of two cells whose inside cells are floor at that level with headroom for a
doorway; and, high on each wall, ledges to drop from."""
def find_sockets(space: Space, mass: Massing) {
    space.sockets = [];
    for side in range(4) {
        length = space.d if side < 2 else space.w;
        for along in range(1, length - 2) {
            for level in space.levels {
                cells = socket_cells(space, side, along, 2);
                good = True;
                for cell in cells {
                    if not mass.standing(cell[2], cell[3], level) or mass.headroom(cell[2], cell[3], level) < OPEN_HIGH {
                        good = False;
                    }
                }
                if good {
                    space.sockets.append(Doorway(side=side, along=along, level=level));
                }
            }
            # Ledges: openings high in the wall over open floor.
            for drop in [6, 8, 10] {
                level = space.z + drop;
                if level + OPEN_HIGH >= space.z + space.h {
                    continue;
                }
                cells = socket_cells(space, side, along, 2);
                good = True;
                for cell in cells {
                    if not mass.air(cell[2], cell[3], level) or mass.headroom(cell[2], cell[3], level) < OPEN_HIGH
                        or mass.standing(cell[2], cell[3], level) {
                        good = False;
                    }
                }
                if good {
                    space.sockets.append(Doorway(side=side, along=along, level=level, floored=False));
                }
            }
        }
    }
}
