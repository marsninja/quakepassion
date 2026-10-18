"""Wall textures: one recipe for each family of surface (brick, stone, metal
plate, tech panel, wood, rock, ground, lights, buttons, liquids, skies...),
and a walk that chooses a texture's family from its name and what is known
of it.

Families are nodes under a `Families` node (games/procgen/families.jac);
each lists the words that call for it, and a walker over them picks the one
that best fits a texture's name. The
name also seeds everything random in the painting, so a texture looks the
same every time, and a texture's animation frames (Quake's `+0name` to
`+9name`) share one seed and differ only in their frame.

Recipes measure in texels, not in parts of the texture: a brick is about
sixteen texels tall whatever the texture's size, so the world keeps one
scale."""
import math;
import from games.passion.random { hash_label, mix32 }
import from .field { Field, lattice }
import from .image { Picture, Rgb, hex_rgb, filled, along }
import from .graph { Recipe, Op }
import from .families { Families, families_of, choose_family }

"""What a recipe painted: the picture, and where it glows (1 where the texel
should be drawn unlit, as a light is; Quake's fullbright colours)."""
obj Paint {
    has picture: Picture,
        glow: list[float] = [];
}

"""What a painting may vary on: the texture's size, its seed, which of its
family's colourings it takes, its animation frame and the words of its name."""
obj Variation {
    has w: int,
        h: int,
        seed: int,
        group: int = 0,
        frame: int = 0,
        frames: int = 1,
        colouring: int = 0,
        words: list[str] = [],
        game: str = "q1",
        recipes: list[Recipe] = [];

    def recipe() -> Recipe {
        made = Recipe(seed=self.seed, w=self.w, h=self.h);
        self.recipes.append(made);
        return made;
    }

    """Let go of every recipe this painting made."""
    def release() {
        for made in self.recipes {
            made.release();
        }
        self.recipes = [];
    }

    """Of `count` choices, the one this texture takes."""
    def pick(count: int, label: str) -> int {
        return mix32(self.group ^ hash_label(17, label)) % max(1, count);
    }

    """A number from `low` to `high` this texture takes for `label`."""
    def amount(label: str, low: float, high: float) -> float {
        t = float(mix32(self.group ^ hash_label(29, label))) / 4294967296.0;
        return low + (high - low) * t;
    }

    """How many repeats of something `size` texels long fit across `span`."""
    def fit(span: int, size: float) -> int {
        return max(1, int(float(span) / size + 0.5));
    }
}

"""The families and their words, the first time they are asked for."""
obj FamilyBook {
    has shelf: Families | None = None;

    def families -> Families {
        found = self.shelf;
        if found is not None {
            return found;
        }
        table: list[tuple[str, list[str]]] = [
            ("brick", ["brick", "brk", "bric", "city", "castle", "wbrick", "bricka"]),
            ("stone", ["stone", "block", "blok", "ston", "wall", "church", "cop", "grave", "altar", "pillar", "column", "marble", "cath", "gothic", "temple", "mmetal", "arch"]),
            ("rock", ["rock", "cave", "cliff", "boulder", "crag", "dung", "mud"]),
            ("ground", ["ground", "dirt", "sand", "gravel", "earth", "floor", "flr", "ash"]),
            ("grass", ["grass", "moss", "swamp", "leaf", "plant", "vine", "ivy"]),
            ("metal", ["metal", "met", "steel", "iron", "plat", "plate", "girder", "beam", "pipe", "support", "sup", "rail", "base", "bmetal", "emetal", "wizmet", "ceil", "duct", "tank"]),
            ("grate", ["grate", "grill", "mesh", "vent", "fence", "chain", "floorgrate"]),
            ("tech", ["tech", "comp", "panel", "pan", "ctrl", "control", "console", "monitor", "circuit", "machine", "core", "tlight", "slip"]),
            ("wood", ["wood", "plank", "board", "beam_w", "timber", "wd"]),
            ("crate", ["crate", "box", "cargo"]),
            ("door", ["door", "gate", "hatch", "dr0", "edoor"]),
            ("light", ["light", "lite", "lamp", "glow", "bulb", "flare", "lt"]),
            ("button", ["button", "butn", "btn", "switch", "lever", "shoot"]),
            ("rune", ["rune", "glyph", "sigil", "star", "skill", "wiz", "dem", "rw", "symbol", "rune_", "exit", "z_exit", "teleport"]),
            ("flesh", ["flesh", "body", "bodies", "skin", "meat", "gut", "blood", "organ", "teeth"]),
            ("tile", ["tile", "checker", "chk", "mosaic", "sfloor", "afloor"]),
            ("trim", ["trim", "edge", "border", "frame", "step", "stair", "lip", "ledge", "rim", "strip"]),
            ("glass", ["glass", "window", "wndw", "pane"]),
            ("water", ["water", "*04", "*water", "wat"]),
            ("slime", ["slime", "*slime", "acid", "toxic", "sewage"]),
            ("lava", ["lava", "*lava", "magma", "fire", "flame", "burn"]),
            ("teleport", ["*teleport", "*tele", "portal", "warp"]),
            ("sky", ["sky", "cloud", "space", "star_"]),
            ("blank", ["clip", "trigger", "hint", "skip", "origin", "nodraw", "caulk", "black", "null"])
        ];
        made = families_of(table);
        self.shelf = made;
        return made;
    }

    """The family whose words a name has; "" when it has none."""
    def matched(name: str) -> str {
        return choose_family(self.families(), name.lower());
    }

    """The family for a texture name (lowercase, as a game names it)."""
    def choose(name: str) -> str {
        lower = name.lower();
        # The prefixes Quake gives its liquids and animations say what they are.
        if lower.startswith("sky") {
            return "sky";
        }
        if lower.startswith("*") {
            if "lava" in lower {
                return "lava";
            }
            if "slime" in lower {
                return "slime";
            }
            if "tele" in lower {
                return "teleport";
            }
            return "water";
        }
        best = self.matched(lower);
        if best {
            return best;
        }
        # A name that says nothing: stone, metal or brick, by its seed.
        fallback = ["stone", "metal", "brick", "rock"];
        return fallback[mix32(hash_label(5, lower)) % len(fallback)];
    }
}

glob _book: FamilyBook = FamilyBook();

def family_of(name: str) -> str {
    return _book.choose(name);
}

"""Colourings: for each family a few ramps (dark to light) to choose between."""
def colourings(family: str) -> list[str] {
    table = {
        "brick": ["2b1b13,5b3723,7f5333,9b6b47", "231713,4f2f23,734333,8f5b47", "27231f,4b4337,6b5f4b,877b63", "1f1f23,3f3f47,5b5b67,77778b"],
        "stone": ["1f1f1f,3f3b37,5f5b53,7f7b6f", "23201b,47402f,6b5f47,8b7f63", "1b1f23,373f47,535b67,6f7b87", "231b1b,473733,6b5350,876f6b"],
        "rock": ["17130f,37302b,57504b,736b63", "1b170f,3f3323,63533b,7f6f53", "131717,2f3333,4f5353,6b7373"],
        "ground": ["1b130b,3f2f1f,5f4b33,7b6347", "17130f,332b23,4f473b,6b6353", "231f13,4b4327,6f633b,8f8353"],
        "grass": ["0b1307,1f2f13,3b4f23,576f33", "131707,2b3713,474f23,636b33"],
        "metal": ["17171b,33373f,535b67,737f8b", "1b1713,3b3327,5f5343,7f735f", "131b1b,2b3b3b,47575b,63777b", "1f1b1b,3f3737,5f5757,7f7777"],
        "grate": ["0f0f0f,2b2b2f,4b4b53,6b6b77", "130f0b,33271b,53432f,735f47"],
        "tech": ["0f131b,232f3f,3b4b63,577387", "131313,2f2f33,4b4b53,6b6b77", "131311,2f2b27,4f4b43,6f6b63", "0f0f0b,2b2b1f,474733,63634b", "0f1313,232f2f,3b4b4b,576b6b"],
        "wood": ["170f07,3b2713,5f4323,835f37", "1b130b,3f2f1b,63472b,87633f"],
        "crate": ["1b1307,433013,6b4f23,8f6f37"],
        "door": ["17171b,373b43,575f6b,7b8393", "1b130b,3f2b17,63472b,8b673f"],
        "light": ["1b1b1b,3f3f3f,6b6b6b,9b9b9b"],
        "button": ["17171b,373b43,575f6b,7b8393"],
        "rune": ["1b170f,3b3323,5b4f3b,7b6f53", "13131b,2b2b3b,474763,636387"],
        "flesh": ["1b0703,471310,73231b,9b3f2b", "1f0b07,4b1f17,7b3b2b,a35b43"],
        "tile": ["1b1b1b,3f3f3f,636363,8b8b8b", "1b1307,3f2f17,63472b,876b43"],
        "trim": ["17171b,373b43,575f6b,7b8393", "1b1307,3f2f17,634b2b,87673f"],
        "glass": ["0b1317,1f3343,3f5f77,6f93a7"],
        "water": ["030b0f,0b2333,1b3f5b,336787"],
        "slime": ["030b03,0f2b07,234f0f,3f771b"],
        "lava": ["2f0700,6b1b00,b34b07,f39b2b"],
        "teleport": ["07030f,231343,4b2b87,8b67d3"],
        "sky": ["07030b,1b0f2b,3b234f,6b4b7b", "030713,0f1f3b,23436b,4f7ba3", "0b0303,2b0f07,5b2f17,8f5f37"],
        "blank": ["2b2b2b,4b4b4b"]
    };
    return table.get(family, ["1f1f1f,3f3f3f,5f5f5f,7f7f7f"]);
}

"""A recipe's ramp: the family's chosen colouring."""
def:priv ramp_for(family: str, v: Variation) -> str {
    choices = colourings(family);
    return choices[v.pick(len(choices), "colouring")];
}

"""Dirt gathered in creases and grime over the whole, on a lit picture."""
def:priv weathered(r: Recipe, picture: Op, height: Op, v: Variation, amount: float) -> Op {
    dirt = r.op("creases", {"radius": 3.0}, [height]);
    grime = r.op("noise", {"cells": float(v.fit(v.w, 24.0)), "octaves": 4.0, "keep": 0.6});
    grime_mask = r.op("levels", {"low": 0.55, "high": 0.95}, [grime]);
    stained = r.op("stain", {"strength": 0.75 * amount}, [picture, dirt], "0f0b07");
    return r.op("stain", {"strength": 0.35 * amount}, [stained, grime_mask], "17130f");
}

def:priv brick_paint(v: Variation, rows_size: float, cols_size: float, mortar: float, family: str) -> Paint {
    r = v.recipe();
    rows = float(v.fit(v.h, rows_size));
    cols = float(v.fit(v.w, cols_size));
    shape = {"rows": rows, "cols": cols, "mortar": mortar, "bevel": max(1.5, mortar)};
    laid = r.op("bricks", shape);
    tones = r.op("brick_tones", shape);
    grit = r.op("noise", {"cells": float(v.fit(v.w, 8.0)), "octaves": 4.0, "keep": 0.55});
    chips = r.op("levels", {"low": 0.3, "high": 0.7}, [grit]);
    rough = r.op("combine", {"amount": 0.25}, [laid, chips], "multiply");
    face = r.op("combine", {"amount": 0.45}, [tones, grit], "mix");
    colour = r.op("ramp", {}, [face], ramp_for(family, v));
    mortar_mask = r.op("invert", {}, [laid]);
    mortar_colour = r.op("ramp", {}, [grit], "17130f,3b3329");
    joined = r.op("over", {}, [colour, mortar_colour, mortar_mask]);
    light = r.op("shade", {"depth": 2.5}, [rough]);
    lit = r.op("lit", {"strength": 0.75}, [joined, light]);
    return Paint(picture=r.picture(weathered(r, lit, rough, v, 0.8)));
}

def:priv rock_paint(v: Variation, family: str, count_size: float) -> Paint {
    r = v.recipe();
    count = float(max(4, int(float(v.w * v.h) / (count_size * count_size))));
    rims = r.op("cell_rims", {"count": count, "width": 3.0, "seed": 3.0});
    tones = r.op("cell_tones", {"count": count, "seed": 3.0});
    grit = r.op("noise", {"cells": float(v.fit(v.w, 6.0)), "octaves": 5.0, "keep": 0.6});
    height = r.op("combine", {"amount": 0.5}, [rims, grit], "multiply");
    face = r.op("combine", {"amount": 0.55}, [tones, grit], "mix");
    colour = r.op("ramp", {}, [face], ramp_for(family, v));
    light = r.op("shade", {"depth": 3.0}, [height]);
    lit = r.op("lit", {"strength": 0.8}, [colour, light]);
    return Paint(picture=r.picture(weathered(r, lit, height, v, 0.6)));
}

def:priv ground_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    base = r.op("noise", {"cells": float(v.fit(v.w, 16.0)), "octaves": 6.0, "keep": 0.6});
    pebbles = r.op("cells", {"count": float(max(8, v.w * v.h // 96))});
    bumps = r.op("invert", {}, [pebbles]);
    bumps2 = r.op("levels", {"low": 0.55, "high": 1.0}, [bumps]);
    height = r.op("combine", {"amount": 0.6}, [base, bumps2], "add");
    colour = r.op("ramp", {}, [height], ramp_for(family, v));
    light = r.op("shade", {"depth": 2.0}, [height]);
    return Paint(picture=r.picture(r.op("lit", {"strength": 0.6}, [colour, light])));
}

def:priv metal_paint(v: Variation, family: str, rivets: bool) -> Paint {
    r = v.recipe();
    plate_size = [32.0, 64.0, 16.0][v.pick(3, "plate")];
    shape = {
        "rows": float(v.fit(v.h, plate_size)), "cols": float(v.fit(v.w, plate_size)), "mortar": 1.5, "bevel": 2.5
    };
    plate = r.op("panels", shape);
    height = plate;
    if v.pick(4, "diamond") == 0 {
        # Diamond plate: raised studs on two offset grids.
        a = r.op("rivets", {"nx": float(v.fit(v.w, 8.0)), "ny": float(v.fit(v.h, 8.0)), "radius": 1.8, "inset": 0.25});
        b = r.op("rivets", {"nx": float(v.fit(v.w, 8.0)), "ny": float(v.fit(v.h, 8.0)), "radius": 1.8, "inset": 0.75});
        studs = r.op("combine", {}, [a, b], "max");
        height = r.op("combine", {"amount": 0.5}, [plate, studs], "add");
    } elif rivets {
        bolts = r.op(
            "rivets",
            {"nx": float(v.fit(v.w, 8.0)), "ny": float(v.fit(v.h, plate_size)), "radius": 1.6, "inset": 0.5}
        );
        height = r.op("combine", {"amount": 0.5}, [plate, bolts], "add");
    }
    brushed = r.op("streaks", {"cells": float(max(8, v.w // 2)), "stretch": 12.0});
    grit = r.op("noise", {"cells": float(v.fit(v.w, 12.0)), "octaves": 5.0, "keep": 0.6});
    tone = r.op("combine", {"amount": 0.35}, [grit, brushed], "mix");
    tint = r.op("panel_tones", shape);
    tone2 = r.op("combine", {"amount": 0.25}, [tone, tint], "mix");
    colour = r.op("ramp", {}, [tone2], ramp_for(family, v));
    light = r.op("shade", {"depth": 3.0}, [height]);
    lit = r.op("lit", {"strength": 0.9}, [colour, light]);
    rust_noise = r.op("noise", {"cells": float(v.fit(v.w, 20.0)), "octaves": 5.0, "keep": 0.6});
    rust = r.op("levels", {"low": v.amount("rust", 0.6, 0.8), "high": 0.9}, [rust_noise]);
    rusted = r.op("stain", {"strength": 0.6}, [lit, rust], "4b2b13");
    return Paint(picture=r.picture(weathered(r, rusted, height, v, 0.5)));
}

def:priv grate_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    bars = {"rows": float(v.fit(v.h, 8.0)), "cols": float(v.fit(v.w, 8.0)), "mortar": 3.0, "bevel": 1.0};
    holes = r.op("panels", bars);
    frame = r.op("invert", {}, [holes]);
    outer = r.op(
        "panels", {"rows": float(v.fit(v.h, 64.0)), "cols": float(v.fit(v.w, 64.0)), "mortar": 4.0, "bevel": 2.0}
    );
    rim = r.op("invert", {}, [outer]);
    height = r.op("combine", {}, [frame, rim], "max");
    grit = r.op("noise", {"cells": float(v.fit(v.w, 8.0)), "octaves": 4.0, "keep": 0.5});
    metal = r.op("ramp", {}, [grit], ramp_for(family, v));
    dark = r.op("ramp", {}, [grit], "000000,0b0b0b");
    joined = r.op("over", {}, [dark, metal, height]);
    light = r.op("shade", {"depth": 2.5}, [height]);
    return Paint(picture=r.picture(r.op("lit", {"strength": 0.9}, [joined, light])));
}

"""Small glowing lights set into a field: where they are, 1 in a light."""
def:priv lamps(r: Recipe, v: Variation, size: float, radius: float, phase: int) -> Op {
    spots = r.op("rivets", {"nx": float(v.fit(v.w, size)), "ny": float(v.fit(v.h, size)), "radius": radius, "inset": 0.5});
    blink = r.op("smooth_noise", {"cells": float(v.fit(v.w, size)), "seed": float(37 + phase)});
    on = r.op("levels", {"low": 0.6, "high": 0.65}, [blink]);
    lit_spots = r.op("combine", {"amount": 1.0}, [spots, on], "multiply");
    return r.op("levels", {"low": 0.2, "high": 0.4}, [lit_spots]);
}

def:priv tech_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    layout = v.pick(4, "layout");
    grit = r.op("noise", {"cells": float(v.fit(v.w, 16.0)), "octaves": 4.0, "keep": 0.5});
    plate = [64.0, 128.0, 64.0, 32.0][v.pick(4, "plate")];
    shape = {
        "rows": float(v.fit(v.h, plate)), "cols": float(v.fit(v.w, plate * [1.0, 2.0][v.pick(2, "wide")])),
        "mortar": 2.0, "bevel": 3.0
    };
    tones = r.op("panel_tones", shape);
    height = r.op("panels", shape);
    if layout == 0 {
        # Bands across, with rows of vent slots in every other one.
        bands = r.op("panels", {"rows": float(v.fit(v.h, 16.0)), "cols": 1.0, "mortar": 2.0, "bevel": 2.0});
        slots = r.op(
            "panels", {"rows": float(v.fit(v.h, 4.0)), "cols": float(v.fit(v.w, 16.0)), "mortar": 1.5, "bevel": 0.8}
        );
        vents = r.op("invert", {}, [slots]);
        vent_rows = r.op("stripes", {"count": float(v.fit(v.h, 32.0)), "across": 0.0});
        vent_mask = r.op("levels", {"low": 0.6, "high": 0.7}, [vent_rows]);
        vent_cut = r.op("combine", {"amount": 1.0}, [vents, vent_mask], "multiply");
        height = r.op("invert", {}, [r.op("combine", {"amount": 0.9}, [r.op("invert", {}, [bands]), vent_cut], "add")]);
    } elif layout == 1 {
        # A grid of small plates, some raised more than others.
        small = {"rows": float(v.fit(v.h, 32.0)), "cols": float(v.fit(v.w, 32.0)), "mortar": 1.5, "bevel": 2.0};
        plates = r.op("panels", small);
        lifts = r.op("panel_tones", small);
        height = r.op("combine", {"amount": 0.5}, [plates, lifts], "multiply");
        tones = lifts;
    } elif layout == 2 {
        # Circuitry: thin raised traces over a plate.
        traces = r.op("cell_rims", {"count": float(max(6, v.w * v.h // 160)), "width": 1.2, "seed": 5.0});
        lines = r.op("invert", {}, [traces]);
        thin = r.op("levels", {"low": 0.8, "high": 0.95}, [lines]);
        height = r.op("combine", {"amount": 0.35}, [height, thin], "add");
    } else {
        # Pipes running down.
        pipes = r.op("stripes", {"count": float(v.fit(v.w, 12.0)), "across": 1.0});
        tubes = r.op("levels", {"low": 0.1, "high": 1.0}, [pipes]);
        collars = r.op("panels", {"rows": float(v.fit(v.h, 32.0)), "cols": 1.0, "mortar": 3.0, "bevel": 1.0});
        rings = r.op("invert", {}, [collars]);
        height = r.op("combine", {"amount": 0.4}, [tubes, rings], "add");
    }
    face = r.op("combine", {"amount": 0.35}, [tones, grit], "mix");
    colour = r.op("ramp", {}, [face], ramp_for(family, v));
    light = r.op("shade", {"depth": 3.0}, [height]);
    lit = r.op("lit", {"strength": 0.9}, [colour, light]);
    weathered_lit = weathered(r, lit, height, v, 0.5);
    if v.pick(4, "lamps") != 0 {
        return Paint(picture=r.picture(weathered_lit));
    }
    glow = lamps(r, v, [32.0, 64.0][v.pick(2, "lamp_size")], 1.5, v.frame);
    glow_colour = r.op("ramp", {}, [grit], ["ff3b1b,ff9b3b", "3bff6b,9bffbb", "3b9bff,9bdbff", "ffdb3b,ffffbb"][v.pick(4, "lamp")]);
    shown = r.op("over", {}, [weathered_lit, glow_colour, glow]);
    paint = Paint(picture=r.picture(shown));
    paint.glow = r.field(glow).v;
    return paint;
}

def:priv wood_paint(v: Variation, family: str, crate: bool) -> Paint {
    r = v.recipe();
    planks = {"rows": float(v.fit(v.h, 16.0)), "cols": float(v.fit(v.w, 64.0)), "mortar": 1.0, "bevel": 1.0};
    laid = r.op("bricks", planks);
    tones = r.op("brick_tones", planks);
    grain = r.op("stripes", {"count": float(v.fit(v.h, 3.0)), "across": 0.0});
    wobble_x = r.op("noise", {"cells": float(v.fit(v.w, 32.0)), "octaves": 3.0, "keep": 0.5});
    wobble_y = r.op("noise", {"cells": float(v.fit(v.w, 16.0)), "octaves": 3.0, "keep": 0.5});
    warped = r.op("warp", {"amount": 6.0}, [grain, wobble_x, wobble_y]);
    face = r.op("combine", {"amount": 0.35}, [warped, tones], "mix");
    colour = r.op("ramp", {}, [face], ramp_for(family, v));
    height = laid;
    if crate {
        frame = r.op(
            "panels", {"rows": float(v.fit(v.h, 64.0)), "cols": float(v.fit(v.w, 64.0)), "mortar": 10.0, "bevel": 2.0}
        );
        rim = r.op("invert", {}, [frame]);
        height = r.op("combine", {}, [laid, rim], "max");
    }
    light = r.op("shade", {"depth": 2.5}, [height]);
    lit = r.op("lit", {"strength": 0.8}, [colour, light]);
    return Paint(picture=r.picture(weathered(r, lit, height, v, 0.6)));
}

def:priv light_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    housing = r.op(
        "panels", {"rows": float(v.fit(v.h, 32.0)), "cols": float(v.fit(v.w, 32.0)), "mortar": 2.0, "bevel": 3.0}
    );
    core = r.op(
        "panels", {"rows": float(v.fit(v.h, 32.0)), "cols": float(v.fit(v.w, 32.0)), "mortar": 9.0, "bevel": 4.0}
    );
    grit = r.op("noise", {"cells": float(v.fit(v.w, 8.0)), "octaves": 3.0, "keep": 0.5});
    metal = r.op("ramp", {}, [grit], ramp_for(family, v));
    lamp_colour = r.op("ramp", {}, [core], ["ffb35b,ffffdb", "9bbbff,ffffff", "ff6b3b,ffdb9b", "dbdbdb,ffffff"][v.pick(4, "light")]);
    glow = r.op("levels", {"low": 0.25, "high": 0.6}, [core]);
    joined = r.op("over", {}, [metal, lamp_colour, glow]);
    light = r.op("shade", {"depth": 2.5}, [housing]);
    shown = r.op("lit", {"strength": 0.6}, [joined, light]);
    paint = Paint(picture=r.picture(shown));
    paint.glow = r.field(glow).v;
    return paint;
}

def:priv button_paint(v: Variation, family: str, pressed: bool) -> Paint {
    r = v.recipe();
    plate = r.op("panels", {"rows": 1.0, "cols": 1.0, "mortar": 2.0, "bevel": 3.0});
    knob = r.op("rivets", {"nx": 1.0, "ny": 1.0, "radius": float(min(v.w, v.h)) * 0.3, "inset": 0.5});
    height = r.op("combine", {"amount": 0.6}, [plate, knob], "add");
    grit = r.op("noise", {"cells": float(v.fit(v.w, 8.0)), "octaves": 3.0, "keep": 0.5});
    metal = r.op("ramp", {}, [grit], ramp_for(family, v));
    light = r.op("shade", {"depth": 3.0}, [height]);
    lit = r.op("lit", {"strength": 0.8}, [metal, light]);
    if pressed {
        return Paint(picture=r.picture(lit));
    }
    glow = r.op("levels", {"low": 0.3, "high": 0.6}, [knob]);
    lamp = r.op("ramp", {}, [knob], ["ff1b0b,ffbb5b", "1bff3b,bbffbb"][v.pick(2, "button")]);
    paint = Paint(picture=r.picture(r.op("over", {}, [lit, lamp, glow])));
    paint.glow = r.field(glow).v;
    return paint;
}

def:priv rune_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    stone = r.op("noise", {"cells": float(v.fit(v.w, 16.0)), "octaves": 5.0, "keep": 0.55});
    carve_a = r.op("cell_rims", {"count": float(max(3, v.w * v.h // 512)), "width": 1.5, "seed": 9.0});
    carve = r.op("invert", {}, [carve_a]);
    lines = r.op("levels", {"low": 0.75, "high": 0.95}, [carve]);
    frame = r.op("panels", {"rows": 1.0, "cols": 1.0, "mortar": 4.0, "bevel": 3.0});
    cut = r.op("combine", {"amount": 0.6}, [frame, lines], "multiply");
    height = r.op("combine", {"amount": 0.2}, [cut, stone], "add");
    colour = r.op("ramp", {}, [stone], ramp_for(family, v));
    light = r.op("shade", {"depth": 3.0}, [height]);
    lit = r.op("lit", {"strength": 0.9}, [colour, light]);
    if v.pick(2, "glowing") == 0 {
        return Paint(picture=r.picture(lit));
    }
    glow = r.op("levels", {"low": 0.4, "high": 0.8}, [lines]);
    lamp = r.op("ramp", {}, [stone], ["ff7b1b,ffdb7b", "7b9bff,dbe7ff"][v.pick(2, "rune")]);
    paint = Paint(picture=r.picture(r.op("over", {}, [lit, lamp, glow])));
    paint.glow = r.field(glow).v;
    return paint;
}

def:priv flesh_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    cells = r.op("cells", {"count": float(max(6, v.w * v.h // 200))});
    veins = r.op("cell_rims", {"count": float(max(6, v.w * v.h // 200)), "width": 2.0});
    wet = r.op("noise", {"cells": float(v.fit(v.w, 12.0)), "octaves": 5.0, "keep": 0.6});
    height = r.op("combine", {"amount": 0.5}, [veins, wet], "multiply");
    face = r.op("combine", {"amount": 0.5}, [cells, wet], "mix");
    colour = r.op("ramp", {}, [face], ramp_for(family, v));
    light = r.op("shade", {"depth": 4.0}, [height]);
    return Paint(picture=r.picture(r.op("lit", {"strength": 1.0}, [colour, light])));
}

def:priv tile_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    shape = {"rows": float(v.fit(v.h, 16.0)), "cols": float(v.fit(v.w, 16.0)), "mortar": 1.5, "bevel": 1.0};
    laid = r.op("panels", shape);
    tones = r.op("panel_tones", shape);
    grit = r.op("noise", {"cells": float(v.fit(v.w, 8.0)), "octaves": 4.0, "keep": 0.5});
    face = r.op("combine", {"amount": 0.3}, [tones, grit], "mix");
    colour = r.op("ramp", {}, [face], ramp_for(family, v));
    grout = r.op("ramp", {}, [grit], "17130f,2b2723");
    mask = r.op("invert", {}, [laid]);
    joined = r.op("over", {}, [colour, grout, mask]);
    light = r.op("shade", {"depth": 2.0}, [laid]);
    lit = r.op("lit", {"strength": 0.7}, [joined, light]);
    return Paint(picture=r.picture(weathered(r, lit, laid, v, 0.5)));
}

def:priv trim_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    across = v.w >= v.h;
    ridges = r.op("stripes", {"count": float(max(1, (v.h if across else v.w) // 8)), "across": 0.0 if across else 1.0});
    grit = r.op("noise", {"cells": float(v.fit(v.w, 8.0)), "octaves": 4.0, "keep": 0.5});
    tone = r.op("combine", {"amount": 0.3}, [grit, ridges], "mix");
    colour = r.op("ramp", {}, [tone], ramp_for(family, v));
    light = r.op("shade", {"depth": 3.0}, [ridges]);
    lit = r.op("lit", {"strength": 0.8}, [colour, light]);
    return Paint(picture=r.picture(weathered(r, lit, ridges, v, 0.4)));
}

def:priv door_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    frame = r.op("panels", {"rows": 1.0, "cols": float(v.fit(v.w, 64.0)), "mortar": 3.0, "bevel": 4.0});
    bands = r.op(
        "panels", {"rows": float(v.fit(v.h, 32.0)), "cols": float(v.fit(v.w, 64.0)), "mortar": 2.0, "bevel": 2.0}
    );
    bolts = r.op("rivets", {"nx": float(v.fit(v.w, 16.0)), "ny": float(v.fit(v.h, 32.0)), "radius": 1.6, "inset": 0.15});
    height0 = r.op("combine", {"amount": 0.4}, [frame, bands], "multiply");
    height = r.op("combine", {"amount": 0.5}, [height0, bolts], "add");
    grain = r.op("streaks", {"cells": float(max(8, v.w // 2)), "stretch": 10.0});
    grit = r.op("noise", {"cells": float(v.fit(v.w, 12.0)), "octaves": 4.0, "keep": 0.6});
    tone = r.op("combine", {"amount": 0.4}, [grit, grain], "mix");
    colour = r.op("ramp", {}, [tone], ramp_for(family, v));
    light = r.op("shade", {"depth": 3.0}, [height]);
    lit = r.op("lit", {"strength": 0.9}, [colour, light]);
    return Paint(picture=r.picture(weathered(r, lit, height, v, 0.5)));
}

def:priv glass_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    panes = r.op(
        "panels", {"rows": float(v.fit(v.h, 32.0)), "cols": float(v.fit(v.w, 32.0)), "mortar": 3.0, "bevel": 1.0}
    );
    sheen = r.op("streaks", {"cells": float(max(4, v.w // 8)), "stretch": 2.0});
    tone = r.op("combine", {"amount": 0.5}, [sheen, panes], "multiply");
    colour = r.op("ramp", {}, [tone], ramp_for(family, v));
    lead = r.op("ramp", {}, [sheen], "0b0b0b,1f1f1f");
    mask = r.op("invert", {}, [panes]);
    return Paint(picture=r.picture(r.op("over", {}, [colour, lead, mask])));
}

"""A liquid: a slowly swirling noise, the same at every frame (the games
warp it as they draw it), bright where it glows (lava)."""
def:priv liquid_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    base = r.op("noise", {"cells": float(v.fit(v.w, 16.0)), "octaves": 5.0, "keep": 0.55});
    swirl_x = r.op("noise", {"cells": float(v.fit(v.w, 32.0)), "octaves": 3.0, "keep": 0.5});
    swirl_y = r.op("noise", {"cells": float(v.fit(v.w, 32.0)), "octaves": 3.0, "keep": 0.5});
    swirled = r.op("warp", {"amount": float(v.w) * 0.25}, [base, swirl_x, swirl_y]);
    shaped = r.op("normalize", {}, [swirled]);
    colour = r.op("ramp", {}, [shaped], ramp_for(family, v));
    if family == "lava" {
        crust = r.op("cell_rims", {"count": float(max(6, v.w * v.h // 256)), "width": 3.0});
        hot = r.op("invert", {}, [crust]);
        glow = r.op("levels", {"low": 0.55, "high": 0.9}, [hot]);
        hot_colour = r.op("ramp", {}, [shaped], "ff7b0b,ffdb5b");
        return Paint(picture=r.picture(r.op("over", {}, [colour, hot_colour, glow])));
    }
    return Paint(picture=r.picture(colour));
}

"""Quake's sky: a texture twice as wide as tall, its right half the far
layer and its left the near clouds, black where the far layer shows
through."""
def:priv sky_paint(v: Variation, family: str) -> Paint {
    half = v.w // 2;
    far_v = Variation(w=half, h=v.h, seed=v.seed, group=v.group, words=v.words, game=v.game);
    r = far_v.recipe();
    deep = r.op("noise", {"cells": 4.0, "octaves": 6.0, "keep": 0.6});
    far_colour = r.op("ramp", {}, [deep], ramp_for(family, v));
    far = r.picture(far_colour);
    near_v = Variation(w=half, h=v.h, seed=mix32(v.seed + 1), group=v.group, words=v.words, game=v.game);
    rn = near_v.recipe();
    puffs = rn.op("noise", {"cells": 4.0, "octaves": 6.0, "keep": 0.65});
    mask = rn.op("levels", {"low": 0.5, "high": 0.7}, [puffs]);
    cloud = rn.op("ramp", {}, [puffs], "3b3b4b,8b8b9b,c7c7d7");
    near_mask = rn.field(mask);
    near_colour = rn.picture(cloud);
    made = Picture(w=v.w, h=v.h);
    for y in range(v.h) {
        for x in range(half) {
            i = y * half + x;
            left = y * v.w + x;
            right = y * v.w + half + x;
            if near_mask.v[i] > 0.05 {
                made.put(left, near_colour.colour(i).scaled(max(0.2, near_mask.v[i])));
            }
            made.put(right, far.colour(i));
        }
    }
    far_v.release();
    near_v.release();
    return Paint(picture=made);
}

def:priv blank_paint(v: Variation, family: str) -> Paint {
    r = v.recipe();
    grit = r.op("noise", {"cells": 4.0, "octaves": 2.0, "keep": 0.5});
    return Paint(picture=r.picture(r.op("ramp", {}, [grit], ramp_for(family, v))));
}

"""Paint a texture of a family."""
def paint(family: str, v: Variation) -> Paint {
    if family == "brick" {
        return brick_paint(v, 16.0, 32.0, 2.0, family);
    } elif family == "stone" {
        return brick_paint(v, 32.0, 48.0, 2.0, family);
    } elif family == "rock" {
        return rock_paint(v, family, 28.0);
    } elif family == "ground" {
        return ground_paint(v, family);
    } elif family == "grass" {
        return ground_paint(v, family);
    } elif family == "metal" {
        return metal_paint(v, family, v.pick(2, "rivets") == 0);
    } elif family == "grate" {
        return grate_paint(v, family);
    } elif family == "tech" {
        return tech_paint(v, family);
    } elif family == "wood" {
        return wood_paint(v, family, False);
    } elif family == "crate" {
        return wood_paint(v, family, True);
    } elif family == "door" {
        return door_paint(v, family);
    } elif family == "light" {
        return light_paint(v, family);
    } elif family == "button" {
        return button_paint(v, family, v.frame > 0 and "+a" in v.words);
    } elif family == "rune" {
        return rune_paint(v, family);
    } elif family == "flesh" {
        return flesh_paint(v, family);
    } elif family == "tile" {
        return tile_paint(v, family);
    } elif family == "trim" {
        return trim_paint(v, family);
    } elif family == "glass" {
        return glass_paint(v, family);
    } elif family in ["water", "slime", "lava", "teleport"] {
        return liquid_paint(v, family);
    } elif family == "sky" {
        return sky_paint(v, family);
    }
    return blank_paint(v, family);
}

"""A texture's name without the frame prefix Quake gives animations
(`+0name`, `+aname`), and its frame: 0-9 for the first sequence, 10-19 for
the alternate one."""
def animation_of(name: str) -> tuple[str, int] {
    if len(name) > 2 and name[0] == "+" {
        mark = name[1].lower();
        if mark >= "0" and mark <= "9" {
            return (name[2:], ord(mark) - ord("0"));
        }
        if mark >= "a" and mark <= "j" {
            return (name[2:], 10 + ord(mark) - ord("a"));
        }
    }
    return (name, 0);
}

"""Paint the texture a game names `name` at its size: its family chosen from
its name (and, for Quake II, its surface flags), seeded by its name."""
def paint_named(name: str, w: int, h: int, game: str, family_hint: str = "") -> Paint {
    (base, frame) = animation_of(name);
    stem = base.lower();
    cut = stem.rfind("/");
    leaf = stem[cut + 1:] if cut >= 0 else stem;
    family = family_hint;
    if not family and game != "q1" and not leaf.startswith("sky") and not leaf.startswith("*") {
        # The file's own name first, then its folder's (base_floor/diamond2c).
        family = _book.matched(leaf);
        if not family {
            family = _book.matched(stem);
        }
    }
    if not family {
        family = family_of(leaf if game != "q1" else stem);
    }
    words = [stem];
    if name.startswith("+a") or (len(name) > 1 and name[0] == "+" and name[1] >= "a") {
        words.append("+a");
    }
    v = Variation(
        w=w,
        h=h,
        seed=hash_label(1, game + ":" + leaf),
        group=hash_label(2, game + ":" + leaf.rstrip("0123456789_")),
        frame=frame,
        words=words,
        game=game
    );
    painted = paint(family, v);
    v.release();
    return painted;
}

"""A Quake III image painted for the way its shaders draw it (games/procgen/
manifest.jac shader_roles): an ordinary surface ("base"); one cut out by
its alpha ("alpha": bars, mesh, leaves); a glow added over what is behind
it, black where nothing shows ("add": flames, flares, beams, lights); a
light detail multiplied over a surface ("filter"); a decal laid over by its
alpha ("blend"); or a sheen ("env")."""
def paint_role(path: str, w: int, h: int, role: str) -> Paint {
    lower = path.lower();
    stem = lower.rsplit(".", 1)[0];
    seed = hash_label(1, "q3:" + stem);
    group = hash_label(2, "q3:" + stem.rstrip("0123456789_"));
    v = Variation(w=w, h=h, seed=seed, group=group, words=[stem], game="q3");
    painted_role = paint_role_with(v, path, stem, w, h, role);
    v.release();
    return painted_role;
}

def:priv paint_role_with(v: Variation, path: str, stem: str, w: int, h: int, role: str) -> Paint {
    if role == "add" {
        return glow_paint(v, stem);
    }
    if role == "filter" {
        r = v.recipe();
        grain = r.op("noise", {"cells": float(v.fit(w, 16.0)), "octaves": 5.0, "keep": 0.6});
        light = r.op("levels", {"low": -1.5, "high": 1.0}, [grain]);
        return Paint(picture=r.picture(r.op("ramp", {}, [light], "9b9b9b,ffffff")));
    }
    if role == "env" {
        r = v.recipe();
        sheen = r.op("streaks", {"cells": 8.0, "stretch": 4.0});
        return Paint(picture=r.picture(r.op("ramp", {}, [sheen], "1b1f2b,6b7b9b,dbe3f3,7b6b5b")));
    }
    painted = paint_named(stem, w, h, "q3");
    if role == "alpha" {
        r = v.recipe();
        cut = r.op("panels", {"rows": float(v.fit(h, 8.0)), "cols": float(v.fit(w, 8.0)), "mortar": 3.0, "bevel": 0.5});
        if "leaf" in stem or "plant" in stem or "vine" in stem or "ivy" in stem or "tree" in stem {
            cut = r.op("cells", {"count": float(max(8, w * h // 128))});
        }
        holes = r.field(cut);
        for i in range(w * h) {
            painted.picture.a[i] = 0.0 if holes.v[i] > 0.5 else 1.0;
        }
    } elif role == "blend" {
        r = v.recipe();
        edge_noise = r.field(r.op("noise", {"cells": 6.0, "octaves": 4.0, "keep": 0.6}));
        for y in range(h) {
            for x in range(w) {
                dx = (float(x) + 0.5) / float(w) * 2.0 - 1.0;
                dy = (float(y) + 0.5) / float(h) * 2.0 - 1.0;
                d = math.sqrt(dx * dx + dy * dy) + (edge_noise.v[y * w + x] - 0.5) * 0.4;
                painted.picture.a[y * w + x] = max(0.0, min(1.0, (1.0 - d) * 2.0));
            }
        }
    }
    return painted;
}

"""Something that glows, on black: a flame, a flare, a beam or a lamp's
light, as the name says."""
def:priv glow_paint(v: Variation, stem: str) -> Paint {
    r = v.recipe();
    hue = ["ff9b3b,ffffbb", "5b9bff,dbefff", "ff3b2b,ffbb7b", "7bff7b,dbffdb", "ffdb5b,ffffff"][v.pick(5, "hue")];
    if "flame" in stem or "fire" in stem {
        hue = "ff5b0b,ffdb7b";
    }
    if "blue" in stem or "bluelight" in stem {
        hue = "3b6bff,cbdbff";
    }
    if "red" in stem {
        hue = "ff2b1b,ffab8b";
    }
    shape = Field(w=v.w, h=v.h);
    flicker = r.field(r.op("noise", {"cells": float(v.fit(v.w, 8.0)), "octaves": 4.0, "keep": 0.6}));
    for y in range(v.h) {
        for x in range(v.w) {
            u = (float(x) + 0.5) / float(v.w) * 2.0 - 1.0;
            t = (float(y) + 0.5) / float(v.h) * 2.0 - 1.0;
            i = y * v.w + x;
            value = 0.0;
            if "flame" in stem or "fire" in stem {
                # A tongue of flame rising from the bottom.
                width = 0.6 * (1.0 - (1.0 - t) * 0.5) + (flicker.v[i] - 0.5) * 0.5;
                value = max(0.0, 1.0 - abs(u) / max(0.05, width)) * max(0.0, (t + 1.0) * 0.5);
            } elif "beam" in stem or "ray" in stem or "bolt" in stem or "line" in stem {
                value = max(0.0, 1.0 - abs(t) * 2.0) * (0.6 + 0.4 * flicker.v[i]);
            } elif "flare" in stem or "glow" in stem or "light" in stem or "spot" in stem {
                d = math.sqrt(u * u + t * t);
                value = max(0.0, 1.0 - d) ** 2;
            } else {
                value = max(0.0, flicker.v[i] * 1.6 - 0.6);
            }
            shape.v[i] = max(0.0, min(1.0, value));
        }
    }
    ramp = ramp_of_text("000000," + hue);
    made = Picture(w=v.w, h=v.h);
    for i in range(v.w * v.h) {
        made.put(i, along(ramp, shape.v[i]));
    }
    return Paint(picture=made);
}

def:priv ramp_of_text(text: str) -> list[Rgb] {
    made: list[Rgb] = [];
    for word in text.split(",") {
        if len(word.strip()) == 6 {
            made.append(hex_rgb(word.strip()));
        }
    }
    return made;
}
