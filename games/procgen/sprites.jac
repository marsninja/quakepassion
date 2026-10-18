"""Sprites: the flat pictures the games draw facing the eye (explosions,
bubbles, flashes, BFG blasts), a picture for each frame of their animation.

A sprite is drawn from its name and how far through its frames the picture
is: an explosion is a fireball that swells and burns out, a bubble a ring of
light, a flash or a light a star of glow. Quake keeps a sprite's pictures
inside its .spr; Quake II keeps them as .pcx files its .sp2 names."""
import math;
import struct;
import from games.passion.random { hash_label }
import from .field { fbm }
import from .image { Picture, Rgb, along, hex_rgb }

"""One frame of the sprite `name`, `phase` (0 to 1) of the way through it."""
def sprite_picture(name: str, w: int, h: int, phase: float) -> Picture {
    lower = name.lower();
    seed = hash_label(18, lower);
    noise = fbm(w, h, 4, 4, 0.55, seed + int(phase * 16.0));
    made = Picture(w=w, h=h, a=[0.0] * (w * h));
    fire = [hex_rgb("3b0700"), hex_rgb("b33b07"), hex_rgb("ff9b2b"), hex_rgb("ffefa3")];
    if "bfg" in lower {
        fire = [hex_rgb("033b07"), hex_rgb("1bb33b"), hex_rgb("7bff7b"), hex_rgb("efffef")];
    } elif "bubble" in lower or "water" in lower {
        fire = [hex_rgb("0b1b2b"), hex_rgb("3b6b9b"), hex_rgb("9bcbff"), hex_rgb("ffffff")];
    }
    for y in range(h) {
        for x in range(w) {
            u = (float(x) + 0.5) / float(w) * 2.0 - 1.0;
            v = (float(y) + 0.5) / float(h) * 2.0 - 1.0;
            d = math.sqrt(u * u + v * v);
            i = y * w + x;
            heat = 0.0;
            if "bubble" in lower {
                heat = max(0.0, 1.0 - abs(d - 0.7) * 6.0);
            } elif "light" in lower or "flash" in lower or "flare" in lower {
                star = max(0.0, 1.0 - min(abs(u), abs(v)) * 8.0) * max(0.0, 1.0 - d);
                heat = max(star, max(0.0, 1.0 - d * 1.6));
            } else {
                # A fireball: as wide as the phase swells it, burning out.
                radius = 0.35 + 0.65 * phase;
                edge_noise = (noise.v[i] - 0.5) * 0.5;
                heat = max(0.0, (radius - d + edge_noise) / max(0.1, radius)) * (1.0 - phase * 0.7);
                heat = heat * (0.6 + noise.v[i] * 0.8);
            }
            heat = max(0.0, min(1.0, heat));
            if heat > 0.02 {
                made.put(i, along(fire, heat));
                made.a[i] = min(1.0, heat * 2.0);
            }
        }
    }
    return made;
}

"""A Quake .spr: the original's header with the frames' greatest size, then
each frame (its pivot, its size and its pixels as palette numbers)."""
def spr_bytes(header: bytes, frames: list[tuple[int, int, int, int, bytes]]) -> bytes {
    wide = 0;
    tall = 0;
    for (w, h, ox, oy, pixels) in frames {
        wide = max(wide, w);
        tall = max(tall, h);
    }
    made = bytearray(header[:8]);
    made.extend(header[8:16]);
    made.extend(struct.pack("<iii", wide, tall, len(frames)));
    made.extend(header[28:36]);
    for (w, h, ox, oy, pixels) in frames {
        made.extend(struct.pack("<iiiii", 0, -ox, h - oy, w, h));
        made.extend(pixels);
    }
    return bytes(made);
}

"""A Quake II .sp2: each frame's size, pivot and picture's name."""
def sp2_bytes(frames: list[tuple[int, int, int, int, str]]) -> bytes {
    made = bytearray(b"IDS2");
    made.extend(struct.pack("<ii", 2, len(frames)));
    for (w, h, x, y, name) in frames {
        made.extend(struct.pack("<iiii", w, h, x, y));
        raw = name.encode("latin-1")[:63];
        made.extend(raw + bytes(64 - len(raw)));
    }
    return bytes(made);
}
