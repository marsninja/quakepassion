"""Flooded works the Quake II stretches of the hangars, the command centre and
the station share: pools whose beds shelve up to their rims, so the water the
originals keep is walked out of from anywhere and its bed is no one great
floor, and offices, the small rooms between their halls."""
import from ..prefab { Raising }
import from ..space { Space }

"""A pool whose bed shelves up to its rim, a lift a row, so a body walks out
of it from anywhere: the cells x0..x1, y0..y1 under a floor on lift `top`,
`deep` lifts down at its deep end, rising the way `direction` goes (0 +x ...
3 -y) to meet the floor at that side; the rows spread evenly when the pool is
longer than it is deep. Answers its space."""
def shelving(build: Raising, x0: int, y0: int, x1: int, y1: int, top: int, deep: int, direction: int, code: int = 2) -> Space {
    water = build.pool(x0, y0, top - deep, x1, y1, top, code, steps=False);
    rows = x1 - x0 if direction % 2 == 0 else y1 - y0;
    run = max(1, rows // deep);
    for row in range(rows) {
        bed = top - row // run;
        if bed <= top - deep {
            continue;
        }
        if direction == 0 {
            build.solid(x1 - 1 - row, y0, top - deep, x1 - row, y1, bed);
        } elif direction == 2 {
            build.solid(x0 + row, y0, top - deep, x0 + row + 1, y1, bed);
        } elif direction == 1 {
            build.solid(x0, y1 - 1 - row, top - deep, x1, y1 - row, bed);
        } else {
            build.solid(x0, y0 + row, top - deep, x1, y0 + row + 1, bed);
        }
    }
    return water;
}

"""An office in a block of solid standing on a floor on lift `z`: the block
over the cells x0..x1, y0..y1, `high` lifts tall, a room in it a wall thick
all round whose floor is a step up from the floor outside, its way in three
cells wide (fewer in a narrow wall) on the block's face `face` (0 +x ... 3 -y)
at `at` along that face. `high` wants at least seven. Answers the room's
space."""
def office(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, high: int, face: int, at: int) -> Space {
    build.solid(x0, y0, z, x1, y1, z + high);
    inner = build.room(x0 + 1, y0 + 1, z + 1, x1 - 1, y1 - 1, z + high - 1);
    if face == 0 {
        build.widen(inner, x1 - 1, at, z + 1, x1, at + 3, z + 6);
    } elif face == 2 {
        build.widen(inner, x0, at, z + 1, x0 + 1, at + 3, z + 6);
    } elif face == 1 {
        build.widen(inner, at, y1 - 1, z + 1, at + 3, y1, z + 6);
    } else {
        build.widen(inner, at, y0, z + 1, at + 3, y0 + 1, z + 6);
    }
    return inner;
}
