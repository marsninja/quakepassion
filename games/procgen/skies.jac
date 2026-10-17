"""Skies: Quake II's and Quake III's sky boxes, six square sides about the
eye. Each texel of a side is painted from the direction it looks along,
with noise in three dimensions, so the sides meet without a seam: a
gradient from horizon to zenith, clouds or nebulae over it, and stars where
the sky is dark."""
import math;
import from games.passion.random { hash_label, mix32 }
import from .field { fbm3, lattice3 }
import from .image { Picture, Rgb, hex_rgb, along }
import from .graph { ramp_of }

# gl_warp.c st_to_vec, as the engine's sky box draws it (engine/render/
# world_mesh.jac SKY_BOX_AXES): for each side, in the order the images
# load, which of (s, t, 1) each world axis takes, negative for reversed.
glob SKY_SIDES: list[str] = ["rt", "lf", "bk", "ft", "up", "dn"],
     SKY_AXES: list[list[int]] = [[3, -1, 2], [-3, 1, 2], [1, 3, 2], [-1, -3, 2], [-2, -1, 3], [2, -1, -3]];

"""The direction a texel (u, v from 0 to 1, from the top left) of a side
looks along, unit length."""
def side_direction(side: int, u: float, v: float) -> tuple[float, float, float] {
    s = u * 2.0 - 1.0;
    t = 1.0 - v * 2.0;
    base = [s, t, 1.0];
    axes = SKY_AXES[side];
    point: list[float] = [];
    for component in axes {
        point.append(base[abs(component) - 1] * (-1.0 if component < 0 else 1.0));
    }
    length = math.sqrt(point[0] * point[0] + point[1] * point[1] + point[2] * point[2]);
    return (point[0] / length, point[1] / length, point[2] / length);
}

"""Which side a sky image's name is (its last two letters), or -1."""
def side_of(name: str) -> int {
    lower = name.lower();
    dot = lower.rfind(".");
    stem = lower[:dot] if dot >= 0 else lower;
    suffix = stem[-2:];
    for k in range(len(SKY_SIDES)) {
        if SKY_SIDES[k] == suffix {
            return k;
        }
    }
    return -1;
}

"""The colourings a sky takes: horizon, zenith, cloud and haze."""
glob SKY_MOODS: list[str] = [
    "4b2b1b,0b0713,c39b7b,7b4b33",
    "3b4b5b,07131f,bbc7d3,6b7b8b",
    "5b1b0b,130303,d38b4b,8b3b1b",
    "1b2b1b,030b07,8bab7b,3b5b3b",
    "2b1b3b,07030f,9b7bbb,4b2b5b",
    "6b6b73,1f2b3b,e3e3eb,9b9ba3"
];

"""Paint one side of a sky named `stem` (its sides share it), `size` texels
square."""
def sky_side(stem: str, side: int, size: int) -> Picture {
    seed = hash_label(9, stem.lower());
    mood = ramp_of(SKY_MOODS[mix32(seed) % len(SKY_MOODS)]);
    horizon = mood[0];
    zenith = mood[1];
    cloud = mood[2];
    haze = mood[3];
    cover = 0.35 + float(mix32(seed ^ 77) % 1000) / 1000.0 * 0.4;
    made = Picture(w=size, h=size);
    for y in range(size) {
        for x in range(size) {
            (dx, dy, dz) = side_direction(side, (float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size));
            up = max(-1.0, min(1.0, dz));
            sky = horizon.mixed(zenith, math.pow(max(0.0, up), 0.6));
            if up < 0.0 {
                sky = horizon.mixed(haze.scaled(0.5), min(1.0, -up * 2.0));
            }
            # Clouds lie in a layer: flattened toward the horizon.
            spread = 1.0 / max(0.15, abs(up) + 0.15);
            n = fbm3(dx * 2.0 * spread, dy * 2.0 * spread, dz * 3.0, 6, 0.55, seed);
            amount = max(0.0, min(1.0, (n - (1.0 - cover)) * 3.0)) * min(1.0, abs(up) * 4.0 + 0.2);
            colour = sky.mixed(cloud.mixed(haze, 1.0 - n), amount);
            # Stars where the sky above is dark and clear.
            if up > 0.1 and amount < 0.1 and zenith.r + zenith.g + zenith.b < 0.4 {
                star = lattice3(seed, int(dx * 300.0), int(dy * 300.0), int(dz * 300.0));
                if star > 0.996 {
                    colour = Rgb(r=1.0, g=1.0, b=0.95).scaled((star - 0.996) * 250.0);
                }
            }
            made.put(y * size + x, colour);
        }
    }
    return made;
}
