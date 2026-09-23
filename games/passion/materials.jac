"""Curated district palettes; source formats retain independent namespaces.

Material indices are fixed whether or not assets are loaded: six districts of
five slots (floor, wall, ceiling, trim, accent), then liquids, set-piece
surfaces and emissive lamp colors. Headless generation uses the same indices.
"""
import from engine.assets.catalog { AssetCatalog }
import from engine.formats.bsp { Texture }
import from engine.formats.q1.bsp { parse_bsp }
import from engine.formats.q2.bsp { parse_wal }

glob FLOOR: int = 0,
     WALL_SLOT: int = 1,
     CEILING: int = 2,
     TRIM: int = 3,
     ACCENT: int = 4,
     SLOTS: int = 5,
     DISTRICTS: int = 6;

glob MAT_WATER: int = 30,
     MAT_SLIME: int = 31,
     MAT_LAVA: int = 32,
     MAT_TELEPORT: int = 33,
     MAT_BUTTON: int = 34,
     MAT_SHOOT: int = 35,
     MAT_KEYDOOR: int = 36,
     MAT_SIGN: int = 37,
     MAT_LAMP: int = 38,
     LAMP_COLORS: int = 16;

# District names double as the in-game briefing vocabulary.
glob DISTRICT_NAMES: list[str] = [
         "Stone Keep",
         "Slipgate Base",
         "Strogg Outpost",
         "Deep Mines",
         "Gothic Ruin",
         "Arena Works"
     ];

# (source, map or directory, name) per district slot.
glob DISTRICT_TEXTURES: list[list[list[str]]] = [
         [
             ["q1", "e1m2", "stone1_3"],
             ["q1", "e1m2", "wbrick1_5"],
             ["q1", "e1m2", "wizmet1_2"],
             ["q1", "e1m2", "wizmet1_7"],
             ["q1", "e1m2", "wizwood1_5"]
         ],
         [
             ["q1", "e1m1", "sfloor4_2"],
             ["q1", "e1m1", "tech04_1"],
             ["q1", "e1m1", "tech01_1"],
             ["q1", "e1m1", "tech08_1"],
             ["q1", "e1m1", "crate0_side"]
         ],
         [
             ["q2", "", "e1u1/floor3_1"],
             ["q2", "", "e1u1/metal3_2"],
             ["q2", "", "e1u1/ceil1_1"],
             ["q2", "", "e1u1/box1_3"],
             ["q2", "", "e1u1/box3_1"]
         ],
         [
             ["q2", "", "e2u1/florr1_1"],
             ["q2", "", "e2u1/mine02_1"],
             ["q2", "", "e2u1/metal3_1"],
             ["q2", "", "e2u1/metal37_1"],
             ["q2", "", "e2u1/crys1_1"]
         ],
         [
             ["q3", "", "textures/gothic_floor/metalbridge06"],
             ["q3", "", "textures/gothic_block/blocks15"],
             ["q3", "", "textures/gothic_block/blocks18c"],
             ["q3", "", "textures/gothic_trim/baseboard09_c"],
             ["q3", "", "textures/gothic_wall/iron01_e"]
         ],
         [
             ["q3", "", "textures/base_floor/diamond2c"],
             ["q3", "", "textures/base_wall/concrete"],
             ["q3", "", "textures/base_wall/basewall01"],
             ["q3", "", "textures/base_trim/pewter"],
             ["q3", "", "textures/base_wall/bluemetal2"]
         ]
     ];

glob SPECIAL_TEXTURES: list[list[str]] = [
         ["q1", "e1m1", "*water0"],
         ["q1", "e1m1", "*slime0"],
         ["q1", "e3m2", "*lava1"],
         ["q1", "e1m1", "*teleport"],
         ["q1", "e1m1", "+0basebtn"],
         ["q1", "e1m2", "+0shoot"],
         ["q1", "e1m2", "wkey02_2"],
         ["q1", "e1m2", "exit02_2"]
     ];

# Lamp colors: six district tints, then gold, silver, green, red and white
# accents for objectives, teleporters, switches, guardians and extraction.
glob LAMP_RGB: list[list[float]] = [
         [1.0, 0.77, 0.5],
         [0.68, 0.86, 1.0],
         [0.95, 0.94, 0.86],
         [1.0, 0.62, 0.36],
         [1.0, 0.68, 0.78],
         [0.58, 0.72, 1.0],
         [0.9, 0.9, 0.9],
         [0.9, 0.9, 0.9],
         [0.9, 0.9, 0.9],
         [0.9, 0.9, 0.9],
         [1.0, 0.84, 0.32],
         [0.72, 0.9, 1.0],
         [0.45, 1.0, 0.52],
         [1.0, 0.36, 0.3],
         [1.0, 1.0, 1.0],
         [0.9, 0.9, 0.9]
     ];

def material(zone: int, slot: int) -> int {
    return (zone % DISTRICTS) * SLOTS + slot;
}

def expand(texture: Texture, palette: bytes, source: str) -> Texture {
    if len(palette) != 768 or len(texture.pixels) != texture.width * texture.height {
        raise ValueError("Invalid indexed material");
    }
    rgba = bytearray();
    for pixel in texture.pixels {
        index = int(pixel) * 3;
        rgba.extend([palette[index], palette[index + 1], palette[index + 2], u8(255)]);
    }
    return Texture(
        name=source + ":" + texture.name,
        width=texture.width,
        height=texture.height,
        rgba=bytes(rgba)
    );
}

def lamp_textures -> list[Texture] {
    result: list[Texture] = [];
    for index in range(LAMP_COLORS) {
        rgb = LAMP_RGB[index];
        pixel = bytearray();
        pixel.extend(
            [
                u8(int(rgb[0] * 255.0)),
                u8(int(rgb[1] * 255.0)),
                u8(int(rgb[2] * 255.0)),
                u8(255)
            ]
        );
        result.append(
            Texture(
                name="passion:lamp-" + str(index), width=1, height=1, rgba=bytes(pixel)
            )
        );
    }
    return result;
}

obj Loader {
    has catalog: AssetCatalog,
        q1_maps: dict[str, list[Texture]] = {},
        q1_palette: bytes = b"",
        q2_palette: bytes = b"";

    def q1(map_name: str, name: str) -> Texture {
        if not self.q1_palette {
            self.q1_palette = self.catalog.source("q1").read("gfx/palette.lmp");
        }
        if map_name not in self.q1_maps {
            self.q1_maps[map_name] = parse_bsp(
                self.catalog.source("q1").read("maps/" + map_name + ".bsp")
            ).textures;
        }
        found = [
            texture
            for texture in self.q1_maps[map_name]
            if texture.name == name
        ];
        if not found {
            raise ValueError("Missing Q1 material: " + name);
        }
        return expand(found[0], self.q1_palette, "q1");
    }

    def q2(name: str) -> Texture {
        if not self.q2_palette {
            pcx = self.catalog.source("q2").read("pics/colormap.pcx");
            self.q2_palette = pcx[len(pcx) - 768:];
        }
        return expand(
            parse_wal(
                self.catalog.source("q2").read("textures/" + name + ".wal"), name
            ),
            self.q2_palette,
            "q2"
        );
    }

    def q3(name: str) -> Texture {
        texture = Texture(name=name);
        self.catalog.source("q3").pk3.texture(texture);
        if not texture.encoded {
            raise ValueError("Missing Q3 material: " + name);
        }
        texture.name = "q3:" + name;
        return texture;
    }

    def load(spec: list[str]) -> Texture {
        if spec[0] == "q1" {
            return self.q1(spec[1], spec[2]);
        }
        if spec[0] == "q2" {
            return self.q2(spec[2]);
        }
        return self.q3(spec[2]);
    }
}

def load_materials(directory: str) -> list[Texture] {
    catalog = AssetCatalog(game="passion", directory=directory);
    result: list[Texture] = [];
    try {
        loader = Loader(catalog=catalog);
        for district in DISTRICT_TEXTURES {
            for spec in district {
                result.append(loader.load(spec));
            }
        }
        for spec in SPECIAL_TEXTURES {
            result.append(loader.load(spec));
        }
    } finally {
        catalog.close();
    }
    return result + lamp_textures();
}
