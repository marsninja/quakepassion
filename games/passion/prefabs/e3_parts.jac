"""Builders the modules of Quake's third episode share, for floors the way its
levels break them: walls across a hall with an arch and a sill, floors sunk
in terraces, the beds of flooded ways.

- `cross_wall`, `long_wall`: a partition across a hall, its arch's sill a step
  high, so the two sides are two floors.
- `sunken`: a part of a floor sunk in terraces a step high each, walked in and
  out of anywhere.
- `flooded_way`: a passage under a walkway, full of liquid to the slab's
  underside, swum from one pool to the next.
- `ridged_bed`: the bed of a flooded way in bands a step apart."""
import from ..prefab { Raising }
import from ..space { Space }

"""A wall along y at cell x from y0 to y1, standing on lift z up to `top`, an
arch `wide` cells across at y `at`, `high` lifts tall over a sill `sill` lifts
high."""
def cross_wall(build: Raising, x: int, y0: int, y1: int, z: int, top: int, at: int, wide: int = 4, high: int = 7, sill: int = 1) {
    build.solid(x, y0, z, x + 1, at, top);
    build.solid(x, at + wide, z, x + 1, y1, top);
    if z + high < top {
        build.solid(x, at, z + high, x + 1, at + wide, top);
    }
    if sill > 0 {
        build.solid(x, at, z, x + 1, at + wide, z + sill);
    }
}

"""A wall along x at cell y from x0 to x1, standing on lift z up to `top`, an
arch `wide` cells across at x `at`, `high` lifts tall over a sill `sill` lifts
high."""
def long_wall(build: Raising, y: int, x0: int, x1: int, z: int, top: int, at: int, wide: int = 4, high: int = 7, sill: int = 1) {
    build.solid(x0, y, z, at, y + 1, top);
    build.solid(at + wide, y, z, x1, y + 1, top);
    if z + high < top {
        build.solid(at, y, z + high, at + wide, y + 1, top);
    }
    if sill > 0 {
        build.solid(at, y, z, at + wide, y + 1, z + sill);
    }
}

"""The box x0..x1, y0..y1 of the floor on lift z sunk `tiers` lifts, a lift a
terrace and a cell in from the last, so a body steps down and up anywhere.
What stands on the floor there (a pillar, a stair, a lift) would be left
hanging: keep the box clear of them."""
def sunken(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, tiers: int) {
    for tier in range(tiers) {
        build.widen(space, x0 + tier, y0 + tier, z - tier - 1, x1 - tier, y1 - tier, z - tier);
    }
}

"""A passage of the box x0..x1, y0..y1 from lift `bottom` up to lift `top`,
full of liquid `code` to its roof: joined to pools either side whose surface
stands at `top`, a body swims from one to the other under the floor over it."""
def flooded_way(build: Raising, x0: int, y0: int, x1: int, y1: int, bottom: int, top: int, code: int) -> Space {
    return build.pool(x0, y0, bottom, x1, y1, top, code, True, False);
}

"""The bed of a flooded way (the box x0..x1, y0..y1 on lift `bottom`) in bands
`every` cells long along x, every other one a lift higher: what is under the
surface is several floors, as an old cistern's is."""
def ridged_bed(build: Raising, x0: int, y0: int, x1: int, y1: int, bottom: int, every: int) {
    high = False;
    for x in range(x0, x1, every) {
        if high {
            build.solid(x, y0, bottom, min(x + every, x1), y1, bottom + 1);
        }
        high = not high;
    }
}
