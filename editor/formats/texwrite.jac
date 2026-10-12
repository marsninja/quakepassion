"""Pictures written as the games' own wall textures: a Quake II WAL, a
Quake texture (a "miptex", as a WAD or a level holds it) and a WAD of them.
Both keep a picture at four sizes, each half the one before, as numbers
into the game's palette of 256 colours."""
import struct;
import from ..model.files { palette_indices }

"""A picture at half its size each way: every texel the mean of the four
it takes the place of. Sizes that are odd lose their last row or column."""
def rgba_halved(rgba: bytes, width: int, height: int) -> bytes {
    wide = max(1, width // 2);
    tall = max(1, height // 2);
    made = bytearray(wide * tall * 4);
    for y in range(tall) {
        for x in range(wide) {
            for part in range(4) {
                total = 0;
                count = 0;
                for (across, down) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
                    sx = min(width - 1, x * 2 + across);
                    sy = min(height - 1, y * 2 + down);
                    total += int(rgba[(sy * width + sx) * 4 + part]);
                    count += 1;
                }
                made[(y * wide + x) * 4 + part] = (total + count // 2) // count;
            }
        }
    }
    return bytes(made);
}

"""The four sizes of a picture as numbers into a palette: whole, half, a
quarter and an eighth."""
def mip_indices(rgba: bytes, width: int, height: int, palette: bytes) -> list[bytes] {
    levels: list[bytes] = [];
    held = rgba;
    wide = width;
    tall = height;
    for level in range(4) {
        levels.append(palette_indices(held, palette));
        held = rgba_halved(held, wide, tall);
        wide = max(1, wide // 2);
        tall = max(1, tall // 2);
    }
    return levels;
}

"""Why a picture cannot be a wall texture of the games: its sides must be
whole sixteens, so that its smaller sizes are whole. Empty when it can."""
def texture_refusal(width: int, height: int) -> str {
    if width < 16 or height < 16 or width > 4096 or height > 4096 {
        return "a wall texture is from 16 to 4096 texels a side; this is " + str(width) + " by " + str(height);
    }
    if width % 16 != 0 or height % 16 != 0 {
        return "a wall texture's sides are whole sixteens; this is " + str(width) + " by " + str(height);
    }
    return "";
}

"""A name in so many bytes, cut to fit with a nothing after it."""
def:priv fixed_name(name: str, size: int) -> bytes {
    held = name.encode("utf-8")[:size - 1];
    return held + b"\x00" * (size - len(held));
}

"""A picture as a Quake II WAL: `rgba` is four bytes a texel, a row at a
time from the top, and `palette` Quake II's 256 colours. Empty when the
picture cannot be one (texture_refusal says why)."""
def write_wal(
    name: str, rgba: bytes, width: int, height: int, palette: bytes, flags: int = 0, contents: int = 0, value: int = 0,
    next_name: str = ""
) -> bytes {
    if texture_refusal(width, height) or len(rgba) < width * height * 4 or len(palette) < 768 {
        return b"";
    }
    levels = mip_indices(rgba, width, height, palette);
    offsets: list[int] = [];
    at = 100;
    for level in levels {
        offsets.append(at);
        at += len(level);
    }
    made = bytearray(fixed_name(name, 32));
    made.extend(struct.pack("<I", width));
    made.extend(struct.pack("<I", height));
    for offset in offsets {
        made.extend(struct.pack("<I", offset));
    }
    made.extend(fixed_name(next_name, 32));
    made.extend(struct.pack("<i", flags));
    made.extend(struct.pack("<i", contents));
    made.extend(struct.pack("<i", value));
    for level in levels {
        made.extend(level);
    }
    return bytes(made);
}

"""A picture as a Quake texture: its name, its size, where its four sizes
are, and they. Empty when the picture cannot be one."""
def write_miptex(name: str, rgba: bytes, width: int, height: int, palette: bytes) -> bytes {
    if texture_refusal(width, height) or len(rgba) < width * height * 4 or len(palette) < 768 {
        return b"";
    }
    levels = mip_indices(rgba, width, height, palette);
    made = bytearray(fixed_name(name, 16));
    made.extend(struct.pack("<I", width));
    made.extend(struct.pack("<I", height));
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

"""A Quake WAD of textures: each (name, the texture's bytes as
write_miptex gives them). Names are cut to fifteen letters, as a WAD keeps
them."""
def write_wad(textures: list[tuple[str, bytes]]) -> bytes {
    # Where each lump begins: after the twelve bytes that begin the file, on whole fours.
    places: list[int] = [];
    at = 12;
    for (name, lump) in textures {
        places.append(at);
        at += len(lump);
        at += (4 - at % 4) % 4;
    }
    made = bytearray(b"WAD2");
    made.extend(struct.pack("<i", len(textures)));
    made.extend(struct.pack("<i", at));
    for (name, lump) in textures {
        made.extend(lump);
        while len(made) % 4 != 0 {
            made.append(0);
        }
    }
    for (index, (name, lump)) in enumerate(textures) {
        made.extend(struct.pack("<i", places[index]));
        made.extend(struct.pack("<i", len(lump)));
        made.extend(struct.pack("<i", len(lump)));
        # 68 ('D') is a texture with its four sizes; not packed.
        made.append(68);
        made.append(0);
        made.append(0);
        made.append(0);
        made.extend(fixed_name(name.lower(), 16));
    }
    return bytes(made);
}

"""The name a material's picture goes by as a texture of its own: what
follows its game or `file:`, without folders or an ending, in small
letters ("q2:e1u1/metal1_1" and "file:walls/Metal1_1.png" are both
`metal1_1`)."""
def texture_short(material: str) -> str {
    name = material.split(":", 1)[-1].replace("\\", "/").split("/")[-1];
    dot = name.rfind(".");
    if dot > 0 {
        name = name[:dot];
    }
    return name.lower();
}
