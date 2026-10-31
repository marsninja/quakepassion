"""What breaks the big floors of the Quake II base, depot, warehouse and
prison stretches into the rooms their originals have, drawn in a prefab's own
cells through its `Raising`: walls across a floor with a raised sill in each
opening, humps across an aisle, rows of small side rooms standing a step over
the floor, and an end's way out into a yard under the sky."""
import from ..random { Stream }
import from ..prefab { Raising, Port }
import from ..space { Space }
import from .common { apart }

"""Boulders against the walls of a floor (the box x0..x1, y0..y1 on lift `z`):
`count` lumps of rock a cell or two across and two to five lifts high, each
touching the box's edge, clear of `clear` and of the box's corners, and two
cells from each other, so no pocket is left between them to fall into."""
def spaced_boulders(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, z: int, count: int, clear: list[list[int]]) {
    taken = clear + [[x0, y0, x0 + 3, y0 + 3], [x1 - 3, y0, x1, y0 + 3], [x0, y1 - 3, x0 + 3, y1], [x1 - 3, y1 - 3, x1, y1]];
    placed = 0;
    tries = 0;
    while placed < count and tries < count * 8 {
        tries += 1;
        wide = dice.between(1, 2);
        deep = dice.between(1, 2);
        side = dice.below(4);
        if side < 2 {
            rock_x = x0 if side == 0 else x1 - wide;
            rock_y = dice.between(y0, max(y0, y1 - deep));
        } else {
            rock_x = dice.between(x0, max(x0, x1 - wide));
            rock_y = y0 if side == 2 else y1 - deep;
        }
        box = [rock_x, rock_y, rock_x + wide, rock_y + deep];
        if apart(box, taken) {
            build.solid(rock_x, rock_y, z, rock_x + wide, rock_y + deep, z + dice.between(2, 5));
            taken.append([rock_x - 1, rock_y - 1, rock_x + wide + 1, rock_y + deep + 1]);
            placed += 1;
        }
    }
}

"""A wall across a floor on lift `z`: the box x0..x1, y0..y1 (a cell thick
one way) up to lift `top`, with openings (`gaps`, [a, b] each along the wall's
length) `high` lifts tall over a sill a lift high, so the floor either side of
it is a floor of its own and a body steps over."""
def partition(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, top: int, gaps: list[list[int]], high: int = 7) {
    build.solid(x0, y0, z, x1, y1, top);
    for gap in gaps {
        if x1 - x0 < y1 - y0 {
            build.widen(space, x0, gap[0], z + 1, x1, gap[1], min(top, z + 1 + high));
        } else {
            build.widen(space, gap[0], y0, z + 1, gap[1], y1, min(top, z + 1 + high));
        }
    }
}

"""A row of `count` side rooms each `width` cells along by `deep` cells in,
standing a step over the floor on lift `z`, cut from a block of solid: along x
from `x` when `along_x`, else along y from `y`. (`x`, `y`) is the block's
corner; the rooms open the way `out` goes (+1 or -1 across the row) through a
wall a cell thick, each opening three cells wide. Answers each room's middle
[x, y], on lift z + 1."""
def side_rooms(build: Raising, x: int, y: int, z: int, count: int, width: int, deep: int, high: int, along_x: bool, out: int) -> list[list[float]] {
    found: list[list[float]] = [];
    span = count * (width + 1) + 1;
    if along_x {
        build.solid(x, y, z, x + span, y + deep + 1, z + high + 2);
    } else {
        build.solid(x, y, z, x + deep + 1, y + span, z + high + 2);
    }
    for index in range(count) {
        at = index * (width + 1) + 1;
        door = (width - 3) // 2;
        if along_x {
            room_y = y if out > 0 else y + 1;
            wall_y = y + deep if out > 0 else y;
            room = build.room(x + at, room_y, z + 1, x + at + width, room_y + deep, z + 1 + high);
            build.widen(room, x + at + door, wall_y, z + 1, x + at + door + 3, wall_y + 1, z + 1 + min(high, 7));
            found.append([float(x + at) + float(width) * 0.5, float(room_y) + float(deep) * 0.5]);
        } else {
            room_x = x if out > 0 else x + 1;
            wall_x = x + deep if out > 0 else x;
            room = build.room(room_x, y + at, z + 1, room_x + deep, y + at + width, z + 1 + high);
            build.widen(room, wall_x, y + at + door, z + 1, wall_x + 1, y + at + door + 3, z + 1 + min(high, 7));
            found.append([float(room_x) + float(deep) * 0.5, float(y + at) + float(width) * 0.5]);
        }
    }
    return found;
}

"""An end's way in out of doors: a hall from the near wall to the cell line
`wall`, its way in cut, and a pair of doors through `wall` into a yard under
the sky (from `wall` to the far wall, lifts `low` to `tall`), the door `panels`
panels two cells wide each, all wanting `key` when one is given. Answers the
yard."""
def gate_yard(build: Raising, variants: list[int], enter: Port, long: int, wide: int, wall: int, low: int, tall: int, key: str, panels: int = 2) -> Space {
    middle = wide // 2;
    hall = build.room(1, 1, 0, wall, wide - 1, 10, variant=variants[0]);
    yard = build.room(wall + 1, 1, low, long - 1, wide - 1, tall, variant=variants[1], sky=True);
    if low < 0 {
        build.level(yard, 0);
    }
    build.doorway(hall, enter);
    build.widen(yard, wall, middle - panels, 0, wall + 1, middle + panels, 8);
    if key {
        for panel in range(panels) {
            y = middle - panels + panel * 2;
            build.rising_door(float(wall), float(y), 0.0, float(wall + 1), float(y + 2), 8.0, {"key": key, "wait": "-1"});
        }
    }
    return yard;
}
