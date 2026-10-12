"""Materials that move: which frame of a row is shown at a time, and a
picture warped the way the games draw their liquids. Nothing is drawn."""

import math;

"""Whether a material's name says it warps: Quake's liquids begin with a
star (after whatever folder or game the name is kept under)."""
def warps_name(name: str) -> bool {
    tail = name.split("/")[-1].split(":")[-1];
    return tail.startswith("*");
}

"""How many frames a second a game shows a row of them at: Quake five,
Quake II two."""
def frames_rate(material: str) -> float {
    return 2.0 if material.startswith("q2:") else 5.0;
}

"""The frame of a row of `count` shown at `clock` seconds by a material
that is itself frame `lead` of the row: every one of the row goes round
in step, each beginning from itself."""
def frame_now(count: int, clock: float, rate: float, lead: int = 0) -> int {
    if count <= 1 {
        return 0;
    }
    return (max(0, lead) + int(max(0.0, clock) * rate)) % count;
}

"""A picture warped as at `clock` seconds: each way across it is pushed by
a wave that runs along the other, an eighth of the picture at its most
(Quake pushes 8 texels of a 64 texel picture), wrapping at the edges as
the texture tiles. `rgba` is four bytes a texel."""
def warped(rgba: bytes, width: int, height: int, clock: float) -> bytes {
    if width <= 0 or height <= 0 or len(rgba) < width * height * 4 {
        return rgba;
    }
    made = bytearray(width * height * 4);
    along = [int(round((float(width) / 8.0) * math.sin(2.0 * math.pi * float(y) / float(height) + clock))) for y in range(height)];
    down = [int(round((float(height) / 8.0) * math.sin(2.0 * math.pi * float(x) / float(width) + clock))) for x in range(width)];
    for y in range(height) {
        for x in range(width) {
            sx = (x + along[y]) % width;
            sy = (y + down[x]) % height;
            source = (sy * width + sx) * 4;
            at = (y * width + x) * 4;
            made[at] = u8(rgba[source]);
            made[at + 1] = u8(rgba[source + 1]);
            made[at + 2] = u8(rgba[source + 2]);
            made[at + 3] = u8(rgba[source + 3]);
        }
    }
    return bytes(made);
}
