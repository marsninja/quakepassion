"""Curated floor/wall palettes; source formats retain independent namespaces."""
import from engine.assets.catalog { AssetCatalog }
import from engine.formats.bsp { Texture }
import from engine.formats.q1.bsp { parse_bsp }
import from engine.formats.q2.bsp { parse_wal }

def expand(texture: Texture, palette: bytes, source: str) -> Texture {
    if len(palette) != 768 or len(texture.pixels) != texture.width * texture.height {
        raise ValueError("Invalid indexed material");
    }
    rgba = bytearray();
    for pixel in texture.pixels {
        index = int(pixel) * 3;
        rgba.extend([palette[index], palette[index + 1], palette[index + 2], u8(255)]);
    }
    return Texture(name=source + ":" + texture.name, width=texture.width,
        height=texture.height, rgba=bytes(rgba));
}

def load_materials(directory: str) -> list[Texture] {
    catalog = AssetCatalog(game="passion", directory=directory);
    result: list[Texture] = [];
    try {
        q1 = catalog.source("q1");
        palette = q1.read("gfx/palette.lmp");
        map1 = parse_bsp(q1.read("maps/e1m2.bsp"));
        for name in ["stone1_3", "wbrick1_5"] {
            found = [texture for texture in map1.textures if texture.name == name];
            if not found { raise ValueError("Missing Q1 material: " + name); }
            result.append(expand(found[0], palette, "q1"));
        }
        q2 = catalog.source("q2");
        pcx = q2.read("pics/colormap.pcx");
        palette = pcx[len(pcx) - 768:];
        for name in ["e1u1/floor3_1", "e1u1/metal3_2"] {
            result.append(expand(parse_wal(q2.read("textures/" + name + ".wal"), name), palette, "q2"));
        }
        q3 = catalog.source("q3");
        for name in ["textures/gothic_floor/metalbridge06", "textures/gothic_block/blocks15"] {
            texture = Texture(name=name);
            q3.pk3.texture(texture);
            if not texture.encoded { raise ValueError("Missing Q3 material: " + name); }
            texture.name = "q3:" + name;
            result.append(texture);
        }
        signs = [texture for texture in map1.textures if texture.name == "exit02_2"];
        if not signs { raise ValueError("Missing Q1 extraction sign"); }
        result.append(expand(signs[0], q1.read("gfx/palette.lmp"), "q1"));
    } finally { catalog.close(); }
    return result;
}
