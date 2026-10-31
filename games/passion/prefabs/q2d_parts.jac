"""Shapes the cities, the boss levels, the cooling facility and the waste
dump share to break a hall into the rooms their originals have and to run
water through them, drawn in a prefab's own cells through its `Raising`:
partition walls whose openings stand on a sill, chambers walled off in a
hall's corner, a step up to a way, flooded culverts between pools."""
import from ..prefab { Prefab, Port, Raising }
import from ..space { Space }

"""A wall a cell thick in the column `x` from y0 to y1, lifts z0 to z1, its
openings `gaps` ([y0, y1] each) of `space`'s air, `door` lifts high on a
sill `sill` lifts over z0 (a threshold: one lift is stepped over)."""
def wall_x(build: Raising, space: Space, x: int, y0: int, y1: int, z0: int, z1: int, gaps: list[list[int]] | None = None, sill: int = 1, door: int = 8) {
    build.solid(x, y0, z0, x + 1, y1, z1);
    for gap in (gaps or []) {
        build.widen(space, x, gap[0], z0 + sill, x + 1, gap[1], min(z1, z0 + sill + door));
    }
}

"""A wall a cell thick in the row `y` from x0 to x1, lifts z0 to z1, as
`wall_x`, its `gaps` ([x0, x1] each)."""
def wall_y(build: Raising, space: Space, y: int, x0: int, x1: int, z0: int, z1: int, gaps: list[list[int]] | None = None, sill: int = 1, door: int = 8) {
    build.solid(x0, y, z0, x1, y + 1, z1);
    for gap in (gaps or []) {
        build.widen(space, gap[0], y, z0 + sill, gap[1], y + 1, min(z1, z0 + sill + door));
    }
}

"""A chamber walled off in a hall: the box x0..x1, y0..y1 solid from lift z
to z1, a room inside it `high` lifts tall at most (walls a cell thick), its mouth
three cells wide on the face `face` (0 +x ... 3 -y) from `at` along that
face, on a sill a lift high. Answers the room."""
def chamber(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, z1: int, face: int, at: int, high: int = 7, mouth: int = 3) -> Space {
    high = min(high, z1 - z);
    build.solid(x0, y0, z, x1, y1, z1);
    room = build.room(x0 + 1, y0 + 1, z, x1 - 1, y1 - 1, z + high);
    if face == 0 {
        build.widen(room, x1 - 1, at, z + 1, x1, at + mouth, z + high);
    } elif face == 2 {
        build.widen(room, x0, at, z + 1, x0 + 1, at + mouth, z + high);
    } elif face == 1 {
        build.widen(room, at, y1 - 1, z + 1, at + mouth, y1, z + high);
    } else {
        build.widen(room, at, y0, z + 1, at + mouth, y0 + 1, z + high);
    }
    return room;
}

"""The step up to a way (the prefab's port, on the floor a lift over the
floor of its room): a landing `depth` cells deep before its opening, so what
lies beyond is a step apart from the room."""
def step_way(build: Raising, prefab: Prefab, port: Port, depth: int = 3) {
    lo = int(port.along - float(port.wide) * 0.5) - 1;
    hi = lo + port.wide + 2;
    z = port.floor;
    if port.face == 0 {
        build.solid(prefab.long - 1 - depth, lo, z - 1, prefab.long - 1, hi, z);
    } elif port.face == 2 {
        build.solid(1, lo, z - 1, 1 + depth, hi, z);
    } elif port.face == 1 {
        build.solid(lo, prefab.wide - 1 - depth, z - 1, hi, prefab.wide - 1, z);
    } else {
        build.solid(lo, 1, z - 1, hi, 1 + depth, z);
    }
}

"""Water in every cell of the box that has air: a culvert swum through, a
well, the flooded part of an undercroft (`code` 2 water, 3 slime)."""
def drown(build: Raising, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, code: int = 2) {
    for z in range(z0, z1) {
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                build.liquid(x, y, z, code);
            }
        }
    }
}

"""A culvert swum through from one pool to another: a tunnel of water over
the box x0..x1, y0..y1, lifts z0 to z1, the air of its own room."""
def culvert(build: Raising, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, code: int = 2) -> Space {
    tunnel = build.room(x0, y0, z0, x1, y1, z1);
    drown(build, x0, y0, z0, x1, y1, z1, code);
    return tunnel;
}

"""The steps up to the ways in and out of a prefab that stand on the lift
`floor` (a lift over its room's floor), as `step_way`; a way into where a
level begins leads from nothing and needs none."""
def step_ways(build: Raising, prefab: Prefab, floor: int = 1, depth: int = 3) {
    if prefab.via is not None and prefab.enter.floor == floor {
        step_way(build, prefab, prefab.enter, depth);
    }
    for port in prefab.taken {
        if port.floor == floor {
            step_way(build, prefab, port, depth);
        }
    }
}
