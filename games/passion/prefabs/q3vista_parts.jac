"""Moves the later Quake III arenas (q3dm9 to q3dm16) take to stand open as
the real ones do: wide high ways between their courts, so a body sees from
one into the next, floors broken into plates a step apart, and the light
the day gives a court under a high sky."""
import from ..prefab { Raising, Port }
import from ..cast { origin_text }

"""A way a body sees through: eight cells wide and sixteen lifts high, where
the wall it opens in has clear air over its floor that far."""
def vista(face: int, along: float, floor: int) -> Port {
    return Port(face=face, along=along, floor=floor, wide=8, high=16);
}

"""The floor of a hall in three bays along x, climbing from lift 0 by a band
of step at each join: lift 0 up to `one`, lift 2 up to `two`, lift 4 on to
`x1`, over y0..y1."""
def rising_bays(build: Raising, one: int, two: int, y0: int, x1: int, y1: int) {
    build.solid(one, y0, 0, x1, y1, 1);
    build.solid(one + 1, y0, 1, x1, y1, 2);
    build.solid(two, y0, 2, x1, y1, 3);
    build.solid(two + 1, y0, 3, x1, y1, 4);
}

"""The lift a floor made by `rising_bays` stands at at the cell line x."""
def bay_floor(x: int, one: int, two: int) -> int {
    if x < one {
        return 0;
    }
    if x == one {
        return 1;
    }
    if x < two {
        return 2;
    }
    if x == two {
        return 3;
    }
    return 4;
}

"""What the day lights of a court whose sky stands far above it: lamps with
no fitting over the box x0..x1, y0..y1, a grid `every` cells apart, at a
man's height and more over each lift of `floors`."""
def daylight(build: Raising, x0: int, y0: int, x1: int, y1: int, floors: list[int], every: int = 7, strength: int = 300) {
    for z in floors {
        for y in range(y0 + 2, y1 - 1, every) {
            for x in range(x0 + 2, x1 - 1, every) {
                at = build.units(float(x) + 0.5, float(y) + 0.5, float(z));
                build.casting.put({"classname": "light", "origin": origin_text(at.x, at.y, at.z + 128.0), "light": str(strength), "_color": "255 250 235"});
            }
        }
    }
}
