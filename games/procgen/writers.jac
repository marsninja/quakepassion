"""Generated pictures and sounds written as the games' own files: Quake's
miptex (as `miptex/<name>.mip`), Quake II's WAL and PCX, Quake III's TGA,
and WAV for all three.

A Quake or Quake II texture keeps four sizes of its picture, each half the
last; each is made by averaging the size above it (glow too), then put into
the palette, so a light stays a light as it shrinks."""
import struct;
import from .image { Picture, Rgb }
import from .palette { Palette }
import from .textures { Paint }

"""A picture and its glow at half the size each way."""
def halved(picture: Picture, glow: list[float]) -> tuple[Picture, list[float]] {
    w = max(1, picture.w // 2);
    h = max(1, picture.h // 2);
    made = Picture(w=w, h=h);
    shrunk: list[float] = [0.0] * (w * h) if glow else [];
    for y in range(h) {
        for x in range(w) {
            i = y * w + x;
            r = 0.0;
            g = 0.0;
            b = 0.0;
            a = 0.0;
            lit = 0.0;
            for dy in range(2) {
                for dx in range(2) {
                    j = min(picture.h - 1, y * 2 + dy) * picture.w + min(picture.w - 1, x * 2 + dx);
                    r += picture.r[j];
                    g += picture.g[j];
                    b += picture.b[j];
                    a += picture.a[j];
                    if glow {
                        lit += glow[j];
                    }
                }
            }
            made.r[i] = r * 0.25;
            made.g[i] = g * 0.25;
            made.b[i] = b * 0.25;
            made.a[i] = a * 0.25;
            if glow {
                shrunk[i] = lit * 0.25;
            }
        }
    }
    return (made, shrunk);
}

"""The four sizes of a painting as numbers into a palette."""
def mip_levels(paint: Paint, palette: Palette, glows: bool) -> list[bytes] {
    levels: list[bytes] = [];
    picture = paint.picture;
    glow = paint.glow if glows else [];
    for level in range(4) {
        levels.append(palette.indices(picture, glow));
        (picture, glow) = halved(picture, glow);
    }
    return levels;
}

def:priv fixed_name(name: str, size: int) -> bytes {
    held = name.encode("latin-1", "replace")[:size - 1];
    return held + b"\x00" * (size - len(held));
}

"""A Quake texture as a map holds it (a miptex), empty when its sides are
not whole sixteens. A sky keeps its fullbright colours out (Quake draws a
sky unlit anyway, and clears its near layer where it is black)."""
def miptex_bytes(name: str, paint: Paint, palette: Palette, sky: bool = False) -> bytes {
    w = paint.picture.w;
    h = paint.picture.h;
    if w < 1 or h < 1 or w % 8 != 0 or h % 8 != 0 {
        return b"";
    }
    levels = mip_levels(paint, palette, not sky);
    made = bytearray(fixed_name(name, 16));
    made.extend(struct.pack("<II", w, h));
    at = 40;
    for level in levels {
        made.extend(struct.pack("<I", at));
        at += len(level);
    }
    for level in levels {
        made.extend(level);
    }
    return bytes(made);
}

"""A Quake II WAL: the name, the size, where its four pictures are, the next
frame of its animation, and the flags, contents and value a map compiler
gives the faces using it."""
def wal_bytes(
    name: str, paint: Paint, palette: Palette, next_name: str, flags: int, contents: int, value: int
) -> bytes {
    w = paint.picture.w;
    h = paint.picture.h;
    if w < 1 or h < 1 {
        return b"";
    }
    levels = mip_levels(paint, palette, False);
    made = bytearray(fixed_name(name, 32));
    made.extend(struct.pack("<II", w, h));
    at = 100;
    for level in levels {
        made.extend(struct.pack("<I", at));
        at += len(level);
    }
    made.extend(fixed_name(next_name, 32));
    made.extend(struct.pack("<iii", flags, contents, value));
    for level in levels {
        made.extend(level);
    }
    return bytes(made);
}

"""A PCX: eight bits a texel run-length coded, with the palette after it,
as Quake II keeps its pictures and skins."""
def pcx_bytes(indices: bytes, w: int, h: int, palette: Palette) -> bytes {
    made = bytearray();
    made.extend(bytes([10, 5, 1, 8]));
    made.extend(struct.pack("<HHHH", 0, 0, w - 1, h - 1));
    made.extend(struct.pack("<HH", 72, 72));
    made.extend(bytes(48));
    made.append(0);
    made.append(1);
    made.extend(struct.pack("<HH", w + (w % 2), 1));
    made.extend(bytes(58));
    stride = w + (w % 2);
    for y in range(h) {
        row = bytearray(indices[y * w:(y + 1) * w]);
        if stride > w {
            row.append(0);
        }
        x = 0;
        while x < stride {
            value = row[x];
            run = 1;
            while x + run < stride and row[x + run] == value and run < 63 {
                run += 1;
            }
            if run > 1 or value >= 192 {
                made.append(192 | run);
            }
            made.append(value);
            x += run;
        }
    }
    made.append(12);
    made.extend(palette.bytes768());
    return bytes(made);
}

"""A TGA: uncompressed, 32 bits a texel (24 when the picture is opaque),
rows from the top."""
def tga_bytes(picture: Picture, keep_alpha: bool = True) -> bytes {
    depth = 32 if keep_alpha else 24;
    made = bytearray();
    made.extend(bytes([0, 0, 2]));
    made.extend(bytes(9));
    made.extend(struct.pack("<HH", picture.w, picture.h));
    made.append(depth);
    made.append(0x28 if keep_alpha else 0x20);
    for i in range(picture.w * picture.h) {
        made.append(channel(picture.b[i]));
        made.append(channel(picture.g[i]));
        made.append(channel(picture.r[i]));
        if keep_alpha {
            made.append(channel(picture.a[i]));
        }
    }
    return bytes(made);
}

def:priv channel(value: float) -> int {
    return max(0, min(255, int(value * 255.0 + 0.5)));
}

"""A WAV of one channel: 8 bits (Quake's) or 16, with a cue marking where it
loops when `loop` is not negative (Quake loops an ambient sound from its
cue)."""
def wav_bytes(samples: list[float], rate: int, bits: int = 16, loop: int = -1) -> bytes {
    width = 1 if bits == 8 else 2;
    body = bytearray();
    for sample in samples {
        held = max(-1.0, min(1.0, sample));
        if width == 1 {
            body.append(max(0, min(255, int(held * 127.0 + 128.5))));
        } else {
            body.extend(struct.pack("<h", max(-32768, min(32767, int(held * 32767.0)))));
        }
    }
    data_size = len(body);
    if len(body) % 2 == 1 {
        body.append(128 if width == 1 else 0);
    }
    cue = bytearray();
    if loop >= 0 {
        cue.extend(b"cue ");
        cue.extend(struct.pack("<II", 28, 1));
        cue.extend(struct.pack("<II", 1, loop));
        cue.extend(b"data");
        cue.extend(struct.pack("<III", 0, 0, loop));
    }
    made = bytearray(b"RIFF");
    made.extend(struct.pack("<I", 4 + 24 + 8 + len(body) + len(cue)));
    made.extend(b"WAVEfmt ");
    made.extend(struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * width, width, width * 8));
    made.extend(cue);
    made.extend(b"data");
    made.extend(struct.pack("<I", data_size));
    made.extend(body);
    return bytes(made);
}
