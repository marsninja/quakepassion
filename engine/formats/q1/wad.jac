"""Quake's gfx.wad (WAD2): the 2D art for the status bar, inventory bar and
console characters. Pictures are `qpic` lumps (width, height, palette indices);
`conchars` is a raw 128x128 sheet. Palette index 255 is transparent."""
import from ..bsp { Texture, i32_at, require_range }

obj WadLump {
    has name: str,
        offset: int,
        size: int,
        kind: int;
}

def wad_lumps(data: bytes) -> list[WadLump] {
    require_range(data, 0, 12);
    if data[0:4] != b"WAD2" {
        raise ValueError("Expected a WAD2 file");
    }
    count = i32_at(data, 4);
    table = i32_at(data, 8);
    if count < 0 or count > 4096 {
        raise ValueError("Invalid WAD lump count");
    }
    require_range(data, table, count * 32);
    lumps: list[WadLump] = [];
    for i in range(count) {
        p = table + i * 32;
        raw = data[p + 16:p + 32];
        end = raw.find(b"\x00");
        name = (raw[:end] if end >= 0 else raw).decode("utf-8").lower();
        lump = WadLump(name=name, offset=i32_at(data, p), size=i32_at(data, p + 4), kind=int(data[p + 12]));
        require_range(data, lump.offset, lump.size);
        lumps.append(lump);
    }
    return lumps;
}

"""Palette indices to RGBA, with index 255 transparent as the original draws."""
def indexed_rgba(indices: bytes, palette: bytes) -> bytes {
    pixels: list[int] = [];
    for index in indices {
        value = int(index);
        pixels.extend(
            [
                int(palette[value * 3]),
                int(palette[value * 3 + 1]),
                int(palette[value * 3 + 2]),
                0 if value == 255 else 255
            ]
        );
    }
    return bytes(pixels);
}

"""Every picture in the WAD by lump name; `conchars` becomes a 128x128 sheet."""
def wad_pictures(data: bytes, palette: bytes) -> dict[str, Texture] {
    require_range(palette, 0, 768);
    pictures: dict[str, Texture] = {};
    for lump in wad_lumps(data) {
        if lump.name == "conchars" {
            if lump.size < 128 * 128 {
                raise ValueError("Truncated conchars");
            }
            pictures[lump.name] = Texture(
                name=lump.name,
                width=128,
                height=128,
                pixels=indexed_rgba(data[lump.offset:lump.offset + 128 * 128], palette)
            );
            continue;
        }
        # TYP_QPIC lumps are type 0x42 ('B').
        if lump.kind != 66 or lump.size < 8 {
            continue;
        }
        width = i32_at(data, lump.offset);
        height = i32_at(data, lump.offset + 4);
        if width <= 0 or height <= 0 or width > 1024 or height > 1024 or 8 + width * height > lump.size {
            raise ValueError("Invalid qpic " + lump.name);
        }
        start = lump.offset + 8;
        pictures[lump.name] = Texture(
            name=lump.name,
            width=width,
            height=height,
            pixels=indexed_rgba(data[start:start + width * height], palette)
        );
    }
    return pictures;
}
