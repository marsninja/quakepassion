"""What the arenas open to the sky share (q3dm17 to q3dm19, q3tourney3 and
q3tourney6 above all): how high their sky stands, how far their void falls,
the low shelves a fall lands on and the small chambers behind their walls."""
import from ..prefab { Raising }
import from ..space { Space }
import from .q3late_parts { deck, keep_box, throw }

"""Lifts of air over a stretch's highest floor where the sky is open, as the
originals' skies stand a thousand units up; and lifts from a stretch's lowest
ledge down to its void's floor, further than a body is reckoned to fall, so
the void is a void and no place to walk (its hurt and its ways back are still
there for who falls)."""
glob OPEN_AIR: int = 48,
     VOID_DROP: int = 26;

"""A rock shelf low in the void, the cells x0..x1, y0..y1 with its top on lift
`z`, under the edge `lip` ([x0, y0, x1, y1] on lift `lip_z`), kept clear of
railings to step off: who lands on it, a pad at (px, py) throws back up to
(lx, ly) on lift `lz`, `land` that landing's edge kept clear (the foot of
q3dm19's void, the floor of q3tourney3's abyss)."""
def foot_shelf(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, lip: list[int], lip_z: int, px: float, py: float, lx: float, ly: float, lz: int, land: list[int] | None = None) {
    deck(build, x0, y0, x1, y1, z, 4);
    build.level(space, z);
    keep_box(build, space, lip[0], lip[1], lip[2], lip[3], lip_z);
    throw(build, space, px, py, z, lx, ly, lz, None, land);
}

"""Chambers behind a wall, in a row along x: the cells x0..x1, y0..y1 on lift
`z`, the wall on the cell line `wall_y` (y0, or y1 - 1), a partition every
`every` cells and a way in three cells wide through the wall to each. Their
floors stand a lift over `z`, their ceilings `high` over it, rock from there
up to lift `top`. Answers each one's middle [x, y]."""
def chambers(build: Raising, x0: int, y0: int, x1: int, y1: int, wall_y: int, z: int, high: int, top: int, every: int) -> list[list[float]] {
    found: list[list[float]] = [];
    inner0 = y0 + 1 if wall_y == y0 else y0;
    inner1 = y1 if wall_y == y0 else y1 - 1;
    x = x0;
    while x + every <= x1 {
        on = x + every;
        door = x + 1 + (every - 4) // 2;
        build.solid(x, y0, z, x + 1, y1, z + high);
        build.solid(x + 1, wall_y, z, door, wall_y + 1, z + high);
        build.solid(door + 3, wall_y, z, on, wall_y + 1, z + high);
        build.solid(door, wall_y, z + 7, door + 3, wall_y + 1, z + high);
        build.solid(x + 1, inner0, z, on, inner1, z + 1);
        found.append([float(x + 1 + on) * 0.5, float(inner0 + inner1) * 0.5]);
        x = on;
    }
    build.solid(x, y0, z, x + 1, y1, z + high);
    if top > z + high {
        build.solid(x0, y0, z + high, x + 1, y1, top);
    }
    return found;
}

"""The same in a row along y: the cells x0..x1, y0..y1, the wall on the cell
line `wall_x` (x0, or x1 - 1). Answers each one's middle [x, y]."""
def chambers_across(build: Raising, x0: int, y0: int, x1: int, y1: int, wall_x: int, z: int, high: int, top: int, every: int) -> list[list[float]] {
    found: list[list[float]] = [];
    inner0 = x0 + 1 if wall_x == x0 else x0;
    inner1 = x1 if wall_x == x0 else x1 - 1;
    y = y0;
    while y + every <= y1 {
        on = y + every;
        door = y + 1 + (every - 4) // 2;
        build.solid(x0, y, z, x1, y + 1, z + high);
        build.solid(wall_x, y + 1, z, wall_x + 1, door, z + high);
        build.solid(wall_x, door + 3, z, wall_x + 1, on, z + high);
        build.solid(wall_x, door, z + 7, wall_x + 1, door + 3, z + high);
        build.solid(inner0, y + 1, z, inner1, on, z + 1);
        found.append([float(inner0 + inner1) * 0.5, float(y + 1 + on) * 0.5]);
        y = on;
    }
    build.solid(x0, y, z, x1, y + 1, z + high);
    if top > z + high {
        build.solid(x0, y0, z + high, x1, y + 1, top);
    }
    return found;
}
