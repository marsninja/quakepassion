"""Models made by code: pickups, weapons (as the world shows them and as the
player holds them), projectiles, gibs, powerups, keys, flames and the
objects levels are dressed with.

A model is built from shapes (games/procgen/shapes.jac) chosen by what its
path says it is, then fitted into the box the game's own model fills, so it
stands, floats and is held where the original was. It keeps the original's
frames (their names, and for Quake its frame and skin groups), its flags
(which choose a projectile's trail), its surfaces and their shaders, and
its tags, all read from the original's header and tables; its shape and its
motion from frame to frame are its own.

Every generated model lays its pieces on one material atlas: a skin cut
into four by four tiles, each a material (steel, brass, wood, flesh, ...).
So every model skin a game names, whatever model uses it, is painted as
that atlas (`material_atlas`)."""
import math;
import struct;
import from games.passion.random { hash_label, mix32 }
import from engine.math.vec3 { Vec3 }
import from engine.formats.animated { AnimatedModel }
import from engine.formats.anorms { quake_vertex_normal }
import from engine.formats.q1.model { parse_mdl }
import from engine.formats.q2.model { parse_md2 }
import from engine.formats.q3.model { parse_md3 }
import from editor.model.mesh { Mesh }
import from editor.model.document { ModelDoc, Part, Pose, Tag, HasPart, HasPose, HasTag }
import from .shapes { Shaper, Frame, Tile, grid_tile, frame_along }
import from .image { Picture, Rgb, hex_rgb }
import from .textures { paint_named }

"""The atlas's tiles, by material."""
glob MATERIALS: list[str] = [
    "steel", "darksteel", "brass", "wood", "flesh", "bone", "red", "blue", "green", "yellow", "glow", "glowblue",
    "stone", "leather", "rubber", "white"
];

def tile_of(material: str) -> Tile {
    index = 0;
    for k in range(len(MATERIALS)) {
        if MATERIALS[k] == material {
            index = k;
        }
    }
    return grid_tile(index, 4, 4);
}

"""What is known of a model a game names, read from it: its frames (names,
and Quake's grouping), its skins, its flags, its surfaces with their skins
(Quake II's skin files, Quake III's shaders), its tags, and the box all its
frames fill."""
obj ModelFacts {
    has kind: str,
        frame_names: list[str] = [],
        frame_groups: list[tuple[int, int, list[float]]] = [],
        skin_groups: list[tuple[int, int, list[float]]] = [],
        skin_w: int = 64,
        skin_h: int = 64,
        flags: int = 0,
        surfaces: list[str] = [],
        surface_skins: list[list[str]] = [],
        tags: list[str] = [],
        low: Vec3 = Vec3(),
        high: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        # The box of the first frame alone: what a character stands in at rest.
        first_low: Vec3 = Vec3(),
        first_high: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        # The box of the frame the model rests in (one named idle or stand,
        # else the first): where a held weapon is shown.
        rest_low: Vec3 = Vec3(),
        rest_high: Vec3 = Vec3(x=1.0, y=1.0, z=1.0);
}

"""Read a model's facts from its file."""
def read_model_facts(data: bytes, kind: str, palette: bytes) -> ModelFacts | None {
    model = AnimatedModel();
    try {
        if kind == "mdl" {
            model = parse_mdl(data, palette);
        } elif kind == "md2" {
            model = parse_md2(data);
        } elif kind == "md3" {
            model = parse_md3(data);
        } else {
            return None;
        }
    } except Exception {
        return None;
    }
    if not model.surfaces or not model.surfaces[0].frames {
        return None;
    }
    facts = ModelFacts(kind=kind, flags=model.flags);
    first = model.surfaces[0];
    facts.frame_names = [frame.name for frame in first.frames];
    facts.frame_groups = [(group.first, group.count, list(group.intervals)) for group in first.frame_groups];
    facts.skin_groups = [(group.first, group.count, list(group.intervals)) for group in first.skin_groups];
    if kind == "mdl" and len(data) >= 60 {
        facts.skin_w = int.from_bytes(data[52:56], "little");
        facts.skin_h = int.from_bytes(data[56:60], "little");
    } elif kind == "md2" and len(data) >= 16 {
        facts.skin_w = int.from_bytes(data[8:12], "little");
        facts.skin_h = int.from_bytes(data[12:16], "little");
    }
    low = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    high = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for surface in model.surfaces {
        facts.surfaces.append(surface.name);
        facts.surface_skins.append(list(surface.skins));
        for frame in surface.frames {
            for v in frame.vertices {
                low = Vec3(x=min(low.x, v.x), y=min(low.y, v.y), z=min(low.z, v.z));
                high = Vec3(x=max(high.x, v.x), y=max(high.y, v.y), z=max(high.z, v.z));
            }
        }
    }
    if model.tags {
        facts.tags = [tag.name for tag in model.tags[0].tags];
    }
    facts.low = low;
    facts.high = high;
    first_low = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    first_high = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for surface in model.surfaces {
        if surface.frames {
            for v in surface.frames[0].vertices {
                first_low = Vec3(x=min(first_low.x, v.x), y=min(first_low.y, v.y), z=min(first_low.z, v.z));
                first_high = Vec3(x=max(first_high.x, v.x), y=max(first_high.y, v.y), z=max(first_high.z, v.z));
            }
        }
    }
    facts.first_low = first_low;
    facts.first_high = first_high;
    resting = 0;
    for k in range(len(facts.frame_names)) {
        lowered = facts.frame_names[k].lower();
        if lowered.startswith("idle") or lowered.startswith("stand") {
            resting = k;
            break;
        }
    }
    rest_low = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    rest_high = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for surface in model.surfaces {
        if resting < len(surface.frames) {
            for v in surface.frames[resting].vertices {
                rest_low = Vec3(x=min(rest_low.x, v.x), y=min(rest_low.y, v.y), z=min(rest_low.z, v.z));
                rest_high = Vec3(x=max(rest_high.x, v.x), y=max(rest_high.y, v.y), z=max(rest_high.z, v.z));
            }
        }
    }
    facts.rest_low = rest_low;
    facts.rest_high = rest_high;
    return facts;
}

"""What a model is, from its path: a kind of thing the shapes below know."""
def model_family(path: str) -> str {
    lower = path.lower();
    if "/players/" in lower or "/monsters/" in lower or lower.startswith("progs/player") {
        return "character";
    }
    q1_monsters = ["army", "dog", "demon", "enforcer", "fish", "hknight", "knight", "ogre", "shambler", "shalrath", "soldier", "tarbaby", "wizard", "zombie", "boss", "oldone"];
    leaf = lower.split("/")[-1].rsplit(".", 1)[0];
    if lower.startswith("progs/") and leaf in q1_monsters {
        return "character";
    }
    # Weapons by their prefixes first (Quake's v_shot is a shotgun, not a shot).
    folder = lower.rsplit("/", 1)[0] if "/" in lower else "";
    for prefix in ["v_", "g_", "w_"] {
        if leaf.startswith(prefix) or folder.split("/")[-1].startswith(prefix) {
            return "weapon";
        }
    }
    if "/weapons/" in lower or "/weapons2/" in lower {
        if "flash" in leaf {
            return "flash";
        }
        return "weapon";
    }
    table: list[tuple[str, list[str]]] = [
        ("flash", ["flash", "muzzle"]),
        ("gib", ["gib", "h_", "/head", "chunk", "meat", "bone", "arm", "leg", "skull"]),
        ("projectile", ["missile", "rocket", "grenade", "spike", "laser", "bolt", "lavaball", "plasma", "bfg", "bullet", "spit", "teleport"]),
        ("weapon", ["v_", "g_", "w_", "weapon", "gun", "launcher", "shotgun", "axe", "gauntlet", "railgun", "lightning", "nail", "blaster", "chaingun", "machinegun", "hyperb"]),
        ("armor", ["armor", "armour", "shard", "jacket", "combat", "body"]),
        ("health", ["health", "medkit", "stimpack", "mega", "medi"]),
        ("ammo", ["ammo", "shells", "bullets", "cells", "slugs", "nails", "rockets", "grenades", "b_", "box"]),
        ("key", ["key", "pass", "card", "cd", "blue_key", "red_key", "pyramid", "skull_key"]),
        ("powerup", ["quad", "invul", "invis", "suit", "enviro", "breather", "silencer", "adrenal", "haste", "regen", "flight", "medkit", "power", "pack", "band", "end"]),
        ("flame", ["flame", "fire", "torch", "candle", "brazier", "lamp", "light"]),
        ("explosion", ["explode", "explosion", "boom", "sphere", "smoke", "ring"]),
        ("flag", ["flag", "banner"]),
        ("debris", ["debris", "rock", "glass", "brick", "wood", "pebble"])
    ];
    for (family, words) in table {
        for word in words {
            if word in leaf or ("/" + word) in lower or (word.endswith("/") and word in lower) {
                return family;
            }
        }
    }
    for (family, words) in table {
        for word in words {
            if word in lower {
                return family;
            }
        }
    }
    return "prop";
}

"""How a model's frames move: its pose at a frame (a transform of each point
from the rest shape), by its family and the frame's name."""
obj Motion {
    has family: str,
        count: int,
        names: list[str],
        seed: int;

    """A frame's name without its number, and how far through the run of
    frames sharing that name it is."""
    def step_of(frame: int) -> tuple[str, float] {
        if frame >= len(self.names) {
            return ("", 0.0);
        }
        stem = self.names[frame].lower().rstrip("0123456789").rstrip("_");
        first = frame;
        while first > 0 and self.names[first - 1].lower().rstrip("0123456789").rstrip("_") == stem {
            first -= 1;
        }
        last = frame;
        while last + 1 < len(self.names) and self.names[last + 1].lower().rstrip("0123456789").rstrip("_") == stem {
            last += 1;
        }
        return (stem, float(frame - first) / float(max(1, last - first)));
    }

    def pose(points: list[Vec3], frame: int) -> list[Vec3] {
        if self.count <= 1 {
            return points;
        }
        t = float(frame) / float(self.count - 1);
        name = self.names[frame].lower() if frame < len(self.names) else "";
        if self.family == "weapon" {
            # By the frame's name: raised from below as it is taken up,
            # lowered as it is put away, kicked back on a shot; still
            # otherwise.
            (stem, phase) = self.step_of(frame);
            drop = 0.0;
            kick = 0.0;
            if stem.startswith("activ") or stem.startswith("raise") or stem.startswith("select") {
                drop = (1.0 - phase) * 12.0;
            } elif stem.startswith("putaw") or stem.startswith("putway") or stem.startswith("deact") or stem.startswith("drop") {
                drop = phase * 12.0;
            } elif stem.startswith("pow") or stem.startswith("fire") or stem.startswith("shot") or stem.startswith("attack") or stem.startswith("nail") or stem.startswith("rock") or stem.startswith("light") {
                kick = math.sin(math.pi * phase) * 3.0;
            } elif not stem.startswith("idle") and not stem.startswith("stand") and frame > 0 and len(self.names) <= 16 {
                # Quake's view weapons name their frames by number alone:
                # the first stands, the rest fire.
                kick = math.sin(math.pi * t) * 3.0;
            }
            return [Vec3(x=p.x - kick, y=p.y, z=p.z - drop + kick * 0.2) for p in points];
        }
        if self.family == "flame" or self.family == "explosion" {
            pulse = 1.0 + 0.15 * math.sin(float(frame) * 1.7 + float(self.seed % 7));
            grow = 1.0 + (t * 1.5 if self.family == "explosion" else 0.0);
            return [Vec3(x=p.x * grow * (2.0 - pulse), y=p.y * grow * (2.0 - pulse), z=p.z * grow * pulse) for p in points];
        }
        if self.family == "flag" {
            return [Vec3(x=p.x, y=p.y + math.sin(p.x * 0.2 + float(frame) * 0.8) * 2.0, z=p.z) for p in points];
        }
        # Anything else turns slowly about its height (a model the game does
        # not turn itself keeps its frames' small sway).
        a = 0.2 * math.sin(float(frame) * 0.9);
        c = math.cos(a);
        s = math.sin(a);
        return [Vec3(x=p.x * c - p.y * s, y=p.x * s + p.y * c, z=p.z) for p in points];
    }
}

"""A gun, along +x: a body, one or two barrels, a grip, and what the kind of
gun adds (a drum, coils, a fat tube)."""
def build_gun(shaper: Shaper, lower: str, seed: int) {
    length = 1.0;
    bulk = 0.22;
    barrels = 2 if ("super" in lower or "shot2" in lower or "sshot" in lower or "nail2" in lower or "chain" in lower) else 1;
    tube = 0.06;
    if "rock" in lower or "launch" in lower or "rl" in lower.split("/")[-1][:3] {
        tube = 0.16;
        bulk = 0.3;
    } elif "gren" in lower {
        tube = 0.13;
        length = 0.7;
    } elif "light" in lower or "lg" in lower {
        tube = 0.09;
    } elif "rail" in lower {
        length = 1.3;
        tube = 0.05;
    } elif "bfg" in lower {
        bulk = 0.4;
        tube = 0.18;
        length = 0.8;
    } elif "axe" in lower or "gauntlet" in lower {
        shaper.tube(frame_along(Vec3(x=-0.4), Vec3(x=0.6)), 1.0, 0.04, 0.04, 6, tile_of("wood"));
        shaper.slab(Frame(at=Vec3(x=0.5, z=0.1), x=Vec3(x=1.0), y=Vec3(z=1.0), z=Vec3(y=1.0)), [(-0.12, -0.3), (0.12, -0.2), (0.15, 0.25), (-0.1, 0.3)], 0.04, tile_of("steel"));
        return;
    }
    body_len = length * 0.45;
    shaper.box(Frame(at=Vec3(x=-body_len * 0.5)), Vec3(x=body_len, y=bulk, z=bulk * 1.1), tile_of("darksteel"));
    for k in range(barrels) {
        offset = (float(k) - float(barrels - 1) * 0.5) * tube * 2.4;
        shaper.tube(frame_along(Vec3(y=offset, z=bulk * 0.2), Vec3(x=1.0, y=offset, z=bulk * 0.2)), length * 0.65, tube, tube, 8, tile_of("steel"));
    }
    shaper.box(Frame(at=Vec3(x=-body_len * 0.7, z=-bulk * 0.8)), Vec3(x=bulk * 0.6, y=bulk * 0.6, z=bulk * 1.4), tile_of("leather"));
    if "nail" in lower or "chain" in lower or "machine" in lower {
        shaper.tube(frame_along(Vec3(x=-body_len * 0.3, y=-bulk * 0.6), Vec3(x=-body_len * 0.3, y=bulk * 0.6)), bulk * 1.2, bulk * 0.45, bulk * 0.45, 10, tile_of("brass"));
    }
    if "light" in lower or "lg" in lower or "plasma" in lower or "bfg" in lower {
        for k in range(3) {
            x = float(k) * 0.15 + 0.1;
            shaper.ring(frame_along(Vec3(x=x, z=bulk * 0.2), Vec3(x=x + 1.0, z=bulk * 0.2)), tube * 1.6, tube * 0.4, 10, 5, tile_of("glowblue"));
        }
    }
}

"""Build the rest shape of a model of `family`; empty for one this does not
make."""
def build_shape(family: str, lower: str, seed: int) -> Shaper {
    shaper = Shaper();
    pick = mix32(seed) % 4;
    if family == "weapon" {
        build_gun(shaper, lower, seed);
    } elif family == "projectile" {
        if "rocket" in lower or "missile" in lower {
            shaper.lathe(Frame(at=Vec3(x=-0.5), x=Vec3(y=1.0), y=Vec3(z=1.0), z=Vec3(x=1.0)), [(0.0, 0.0), (0.1, 0.05), (0.1, 0.75), (0.0, 1.0)], 8, tile_of("steel"));
            for k in range(4) {
                a = float(k) * math.pi * 0.5;
                shaper.box(Frame(at=Vec3(x=-0.4, y=math.cos(a) * 0.14, z=math.sin(a) * 0.14)), Vec3(x=0.2, y=0.02 + abs(math.cos(a)) * 0.1, z=0.02 + abs(math.sin(a)) * 0.1), tile_of("red"));
            }
        } elif "grenade" in lower {
            shaper.ball(Frame(), Vec3(x=0.5, y=0.4, z=0.4), 6, 8, tile_of("green"));
        } elif "spike" in lower or "nail" in lower or "laser" in lower or "bolt" in lower {
            shaper.lathe(Frame(at=Vec3(x=-0.5), x=Vec3(y=1.0), y=Vec3(z=1.0), z=Vec3(x=1.0)), [(0.0, 0.0), (0.06, 0.1), (0.04, 0.85), (0.0, 1.0)], 6, tile_of("glow" if "laser" in lower or "bolt" in lower else "steel"));
        } else {
            shaper.ball(Frame(), Vec3(x=0.5, y=0.5, z=0.5), 6, 8, tile_of("glow"), 0.3, seed);
        }
    } elif family == "gib" {
        material = "bone" if ("bone" in lower or "skull" in lower or "h_" in lower) else "flesh";
        shaper.ball(Frame(), Vec3(x=0.5, y=0.4 + float(pick) * 0.05, z=0.35), 5, 7, tile_of(material), 0.5, seed);
        if "h_" in lower or "head" in lower or "skull" in lower {
            shaper.ball(Frame(at=Vec3(x=0.2, y=0.15, z=0.1)), Vec3(x=0.08, y=0.08, z=0.08), 4, 6, tile_of("rubber"));
            shaper.ball(Frame(at=Vec3(x=0.2, y=-0.15, z=0.1)), Vec3(x=0.08, y=0.08, z=0.08), 4, 6, tile_of("rubber"));
        }
    } elif family == "armor" {
        colour = "green" if ("1" in lower or "shard" in lower or "jacket" in lower or "green" in lower) else ("yellow" if ("2" in lower or "combat" in lower or "yellow" in lower) else "red");
        shaper.lathe(Frame(at=Vec3(z=-0.5)), [(0.25, 0.0), (0.45, 0.2), (0.5, 0.6), (0.35, 0.95), (0.15, 1.0)], 10, tile_of(colour), 0.6);
        shaper.ring(Frame(at=Vec3(z=0.42)), 0.3, 0.05, 10, 4, tile_of("darksteel"));
    } elif family == "health" {
        if "mega" in lower or "sphere" in lower or "stim" in lower {
            shaper.ball(Frame(), Vec3(x=0.5, y=0.5, z=0.5), 8, 10, tile_of("white" if "stim" not in lower else "glowblue"));
        }
        shaper.box(Frame(), Vec3(x=0.25, y=0.25, z=0.8), tile_of("red"));
        shaper.box(Frame(), Vec3(x=0.8, y=0.25, z=0.25), tile_of("red"));
    } elif family == "ammo" {
        shaper.box(Frame(), Vec3(x=1.0, y=0.7, z=0.6), tile_of(["darksteel", "wood", "green", "brass"][pick]));
        shaper.box(Frame(at=Vec3(z=0.32)), Vec3(x=0.8, y=0.5, z=0.06), tile_of("steel"));
    } elif family == "key" {
        if "card" in lower or "pass" in lower or "cd" in lower {
            shaper.box(Frame(), Vec3(x=0.8, y=0.08, z=0.5), tile_of(["blue", "red", "yellow", "green"][pick]));
        } else {
            material = "brass" if ("g_key" in lower or "gold" in lower) else "steel";
            shaper.ring(Frame(at=Vec3(z=0.3), x=Vec3(x=1.0), y=Vec3(z=1.0), z=Vec3(y=1.0)), 0.18, 0.06, 10, 5, tile_of(material));
            shaper.tube(frame_along(Vec3(z=0.12), Vec3(z=-0.5)), 0.62, 0.05, 0.05, 6, tile_of(material));
            shaper.box(Frame(at=Vec3(x=0.08, z=-0.4)), Vec3(x=0.16, y=0.06, z=0.08), tile_of(material));
        }
    } elif family == "powerup" {
        if "quad" in lower {
            shaper.ball(Frame(), Vec3(x=0.5, y=0.5, z=0.5), 4, 4, tile_of("glowblue"));
            shaper.ring(Frame(), 0.45, 0.05, 12, 4, tile_of("blue"));
        } elif "invul" in lower or "pent" in lower {
            shaper.ball(Frame(), Vec3(x=0.35, y=0.35, z=0.35), 5, 6, tile_of("red"), 1.0, seed);
            for k in range(5) {
                a = float(k) * math.pi * 0.4;
                shaper.lathe(frame_along(Vec3(), Vec3(x=math.cos(a), y=math.sin(a), z=0.3)), [(0.12, 0.0), (0.0, 0.5)], 5, tile_of("red"));
            }
        } elif "invis" in lower or "ring" in lower {
            shaper.ring(Frame(), 0.4, 0.1, 14, 6, tile_of("yellow"));
            shaper.ball(Frame(at=Vec3(x=0.4)), Vec3(x=0.12, y=0.12, z=0.12), 4, 6, tile_of("glow"));
        } elif "suit" in lower or "enviro" in lower {
            shaper.lathe(Frame(at=Vec3(z=-0.5)), [(0.3, 0.0), (0.4, 0.4), (0.35, 0.8), (0.2, 1.0)], 10, tile_of("green"));
        } else {
            shaper.lathe(Frame(at=Vec3(z=-0.5)), [(0.0, 0.0), (0.35, 0.15), (0.4, 0.5), (0.3, 0.85), (0.0, 1.0)], 8, tile_of(["glow", "glowblue", "brass", "green"][pick]));
        }
    } elif family == "flame" {
        shaper.lathe(Frame(at=Vec3(z=-0.5)), [(0.0, 0.0), (0.35, 0.15), (0.3, 0.45), (0.15, 0.75), (0.0, 1.0)], 8, tile_of("glow"));
    } elif family == "explosion" {
        shaper.ball(Frame(), Vec3(x=0.5, y=0.5, z=0.5), 6, 8, tile_of("glow"), 0.4, seed);
    } elif family == "flag" {
        shaper.tube(frame_along(Vec3(x=-0.5, z=-0.5), Vec3(x=-0.5, z=0.5)), 1.0, 0.03, 0.03, 6, tile_of("darksteel"));
        shaper.box(Frame(at=Vec3(z=0.25)), Vec3(x=0.9, y=0.02, z=0.5), tile_of("red" if "red" in lower else "blue"));
    } elif family == "debris" {
        shaper.ball(Frame(), Vec3(x=0.5, y=0.4, z=0.3), 3, 5, tile_of("stone"), 0.6, seed);
    } elif family == "prop" {
        # A dressing object: a turned column of some sort.
        heights = [0.0, 0.1, 0.15, 0.85, 0.9, 1.0];
        radii = [0.45, 0.45, 0.3, 0.3, 0.45, 0.45];
        if pick == 1 {
            radii = [0.3, 0.5, 0.5, 0.4, 0.25, 0.0];
        } elif pick == 2 {
            radii = [0.2, 0.45, 0.35, 0.45, 0.2, 0.15];
        }
        profile = [(radii[k], heights[k]) for k in range(len(heights))];
        shaper.lathe(Frame(at=Vec3(z=-0.5)), profile, 10, tile_of(["stone", "brass", "darksteel", "wood"][pick]));
    }
    return shaper;
}

"""The shape scaled evenly (keeping its proportions) to fit within the box
from `low` to `high`, centred in it, standing on its floor."""
def placed_points(points: list[Vec3], low: Vec3, high: Vec3, by_length: bool = False) -> list[Vec3] {
    if not points {
        return points;
    }
    a = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    b = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for p in points {
        a = Vec3(x=min(a.x, p.x), y=min(a.y, p.y), z=min(a.z, p.z));
        b = Vec3(x=max(b.x, p.x), y=max(b.y, p.y), z=max(b.z, p.z));
    }
    scale = min(
        (high.x - low.x) / max(1.0e-6, b.x - a.x), min((high.y - low.y) / max(1.0e-6, b.y - a.y), (high.z - low.z) / max(1.0e-6, b.z - a.z))
    );
    if by_length {
        # A weapon is as long as the original's box, whatever else the box
        # holds (a held weapon's box takes in the hand and arm too).
        scale = (high.x - low.x) / max(1.0e-6, b.x - a.x);
    }
    if scale <= 0.0 {
        scale = 1.0;
    }
    mid_from = a.add(b).scale(0.5);
    mid_to = low.add(high).scale(0.5);
    return [
        Vec3(
            x=mid_to.x + (p.x - mid_from.x) * scale, y=mid_to.y + (p.y - mid_from.y) * scale,
            z=(mid_to.z + (p.z - mid_from.z) * scale) if by_length else (low.z + (p.z - a.z) * scale)
        )
        for p in points
    ];
}

"""The shape fitted into the box from `low` to `high` (each axis stretched
to fill it)."""
def fitted_points(points: list[Vec3], low: Vec3, high: Vec3) -> list[Vec3] {
    if not points {
        return points;
    }
    a = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    b = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for p in points {
        a = Vec3(x=min(a.x, p.x), y=min(a.y, p.y), z=min(a.z, p.z));
        b = Vec3(x=max(b.x, p.x), y=max(b.y, p.y), z=max(b.z, p.z));
    }
    made: list[Vec3] = [];
    for p in points {
        made.append(
            Vec3(
                x=low.x + (p.x - a.x) / max(1.0e-6, b.x - a.x) * (high.x - low.x),
                y=low.y + (p.y - a.y) / max(1.0e-6, b.y - a.y) * (high.y - low.y),
                z=low.z + (p.z - a.z) / max(1.0e-6, b.z - a.z) * (high.z - low.z)
            )
        );
    }
    return made;
}

"""The model `path` as a document: its shape fitted into the original's box,
a pose at each of the original's frames, a part for each of its surfaces
(the first carries the shape, the others a small piece each, so every
surface and shader is still there), and its tags. None for a character
(made elsewhere) or a shape this does not make."""
def model_doc(path: str, facts: ModelFacts) -> ModelDoc | None {
    family = model_family(path);
    if family == "character" {
        return None;
    }
    seed = hash_label(12, path.lower());
    shaper = build_shape(family, path.lower(), seed);
    if not shaper.points {
        return None;
    }
    fitted = placed_points(
        shaper.points, facts.rest_low if family == "weapon" else facts.first_low,
        facts.rest_high if family == "weapon" else facts.first_high, family == "weapon"
    );
    motion = Motion(family=family, count=len(facts.frame_names), names=facts.frame_names, seed=seed);
    doc = ModelDoc(name=path);
    surfaces = facts.surfaces if facts.surfaces else ["model"];
    middle = facts.first_low.add(facts.first_high).scale(0.5);
    span = facts.first_high.sub(facts.first_low);
    for k in range(len(surfaces)) {
        points = fitted;
        corners = list(shaper.corners);
        uvs = list(shaper.uvs);
        if k > 0 {
            extra = Shaper();
            extra.ball(Frame(at=Vec3(x=0.0)), Vec3(x=0.5, y=0.5, z=0.5), 3, 4, tile_of("glow"));
            small = span.scale(0.15);
            points = placed_points(extra.points, middle.sub(small), middle.add(small));
            corners = list(extra.corners);
            uvs = list(extra.uvs);
        }
        skins = facts.surface_skins[k] if k < len(facts.surface_skins) else [];
        part = Part(name=surfaces[k], corners=corners, uvs=uvs, skins=list(skins));
        doc +>:HasPart(index=k):+> part;
        for frame in range(len(facts.frame_names)) {
            part +>:HasPose(index=frame):+> Pose(name=facts.frame_names[frame], points=motion.pose(points, frame));
        }
    }
    for name in facts.tags {
        tag = Tag(name=name);
        # A weapon's muzzle at its front, anything else at its middle.
        spot = middle;
        if "flash" in name or "barrel" in name {
            spot = Vec3(x=facts.first_high.x, y=middle.y, z=middle.z);
        }
        tag.origins = [spot for frame in range(len(facts.frame_names))];
        tag.axes = [[Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)] for frame in range(len(facts.frame_names))];
        doc +>:HasTag:+> tag;
    }
    return doc;
}

"""A skin painted as the material atlas, `w` by `h`: each tile its material,
seeded by the skin's name so no two skins are quite alike."""
def material_atlas(name: str, w: int, h: int, game: str) -> Picture {
    made = Picture(w=w, h=h);
    tile_w = max(16, (w // 4 + 15) // 16 * 16);
    tile_h = max(16, (h // 4 + 15) // 16 * 16);
    words = {
        "steel": "metal", "darksteel": "metal", "brass": "metal", "wood": "wood", "flesh": "flesh", "bone": "rock",
        "red": "metal", "blue": "metal", "green": "metal", "yellow": "metal", "glow": "light", "glowblue": "light",
        "stone": "stone", "leather": "ground", "rubber": "metal", "white": "tile"
    };
    tints = {
        "steel": "8b939b", "darksteel": "4b4f57", "brass": "c39b4b", "wood": "8b6b43", "flesh": "b3634b", "bone": "d3c3a3",
        "red": "b32b1b", "blue": "2b4bb3", "green": "3b8b2b", "yellow": "d3b32b", "glow": "ffb34b", "glowblue": "6bb3ff",
        "stone": "7b7b73", "leather": "5b3b23", "rubber": "232323", "white": "dbdbdb"
    };
    for k in range(16) {
        material = MATERIALS[k];
        painted = paint_named(material + "_" + name.lower(), tile_w, tile_h, game, words[material]);
        tint = hex_rgb(tints[material]);
        x0 = (k % 4) * w // 4;
        y0 = (k // 4) * h // 4;
        x1 = ((k % 4) + 1) * w // 4;
        y1 = ((k // 4) + 1) * h // 4;
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                source = painted.picture.colour(((y - y0) % tile_h) * tile_w + ((x - x0) % tile_w));
                grey = (source.r + source.g + source.b) / 3.0;
                shade = 0.45 + grey * 1.1;
                colour = Rgb(r=min(1.0, tint.r * shade), g=min(1.0, tint.g * shade), b=min(1.0, tint.b * shade));
                if material == "glow" or material == "glowblue" {
                    colour = tint.mixed(Rgb(r=1.0, g=1.0, b=0.9), grey * 0.5);
                }
                made.put(y * w + x, colour);
            }
        }
    }
    return made;
}

"""Which of Quake's 162 normals is nearest a direction."""
def normal_index(facing: Vec3) -> int {
    best = 0;
    most = -2.0;
    for index in range(162) {
        lean = quake_vertex_normal(index).dot(facing);
        if lean > most {
            most = lean;
            best = index;
        }
    }
    return best;
}

"""Each point's normal: the sum of its triangles' faces about it."""
def point_facing(points: list[Vec3], corners: list[int]) -> list[Vec3] {
    sums: list[Vec3] = [Vec3() for p in points];
    for k in range(len(corners) // 3) {
        a = points[corners[k * 3]];
        b = points[corners[k * 3 + 1]];
        c = points[corners[k * 3 + 2]];
        n = b.sub(a).cross(c.sub(a));
        for j in range(3) {
            sums[corners[k * 3 + j]] = sums[corners[k * 3 + j]].add(n);
        }
    }
    return [s.normalized() if s.length() > 1.0e-9 else Vec3(z=1.0) for s in sums];
}

def:priv packed_vec(v: Vec3) -> bytes {
    return struct.pack("<fff", v.x, v.y, v.z);
}

def:priv packed_name(name: str, size: int) -> bytes {
    raw = name.encode("latin-1", "replace")[:size - 1];
    return raw + bytes(size - len(raw));
}

"""A Quake MDL of a document, keeping the original's skin groups (`skins`:
one picture of palette numbers for each skin, in order), its frame groups,
its flags and its skin size."""
def mdl_bytes(doc: ModelDoc, facts: ModelFacts, skins: list[bytes]) -> bytes {
    parts = doc.parts();
    frames = doc.frames();
    points: list[list[Vec3]] = [[] for f in range(frames)];
    corners: list[int] = [];
    places: list[float] = [];
    base = 0;
    for part in parts {
        poses = doc.poses(part);
        count = len(poses[0].points);
        for f in range(frames) {
            points[f].extend(poses[f].points);
        }
        # The editor winds triangles the other way round from the games.
        for k in range(len(part.corners) // 3) {
            corners.extend([base + part.corners[k * 3], base + part.corners[k * 3 + 2], base + part.corners[k * 3 + 1]]);
        }
        for at in range(count) {
            places.append(part.uvs[at * 2] if at * 2 + 1 < len(part.uvs) else 0.0);
            places.append(part.uvs[at * 2 + 1] if at * 2 + 1 < len(part.uvs) else 0.0);
        }
        base += count;
    }
    if base < 1 or base > 1024 or len(corners) // 3 > 2048 or frames < 1 {
        return b"";
    }
    low = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    high = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for stood in points {
        for p in stood {
            low = Vec3(x=min(low.x, p.x), y=min(low.y, p.y), z=min(low.z, p.z));
            high = Vec3(x=max(high.x, p.x), y=max(high.y, p.y), z=max(high.z, p.z));
        }
    }
    extent = high.sub(low);
    scale = Vec3(
        x=extent.x / 255.0 if extent.x > 1.0e-4 else 1.0, y=extent.y / 255.0 if extent.y > 1.0e-4 else 1.0,
        z=extent.z / 255.0 if extent.z > 1.0e-4 else 1.0
    );
    w = facts.skin_w;
    h = facts.skin_h;
    groups = facts.frame_groups if facts.frame_groups else [(f, 1, []) for f in range(frames)];
    skin_groups = facts.skin_groups if facts.skin_groups else [(0, 1, [])];
    out = bytearray(b"IDPO");
    out.extend(struct.pack("<i", 6));
    out.extend(packed_vec(scale));
    out.extend(packed_vec(low));
    out.extend(struct.pack("<f", max(high.length(), low.length())));
    out.extend(packed_vec(Vec3(z=high.z)));
    out.extend(struct.pack("<iiiiii", len(skin_groups), w, h, base, len(corners) // 3, len(groups)));
    out.extend(struct.pack("<iif", 0, facts.flags, max(1.0, extent.length() / 16.0)));
    blank = bytes([8]) * (w * h);
    for (first, count, intervals) in skin_groups {
        if count == 1 and not intervals {
            out.extend(struct.pack("<i", 0));
            out.extend(skins[first] if first < len(skins) and len(skins[first]) == w * h else blank);
        } else {
            out.extend(struct.pack("<ii", 1, count));
            for k in range(count) {
                out.extend(struct.pack("<f", intervals[k] if k < len(intervals) else 0.1 * float(k + 1)));
            }
            for k in range(count) {
                at = first + k;
                out.extend(skins[at] if at < len(skins) and len(skins[at]) == w * h else blank);
            }
        }
    }
    for at in range(base) {
        out.extend(struct.pack("<iii", 0, max(0, min(w - 1, int(places[at * 2] * float(w)))), max(0, min(h - 1, int(places[at * 2 + 1] * float(h))))));
    }
    for k in range(len(corners) // 3) {
        out.extend(struct.pack("<iiii", 1, corners[k * 3], corners[k * 3 + 1], corners[k * 3 + 2]));
    }
    names = [doc.frame_name(f) for f in range(frames)];
    for (first, count, intervals) in groups {
        if count == 1 and not intervals {
            out.extend(struct.pack("<i", 0));
            out.extend(simple_frame(points[min(first, frames - 1)], corners, low, scale, names[min(first, frames - 1)]));
        } else {
            out.extend(struct.pack("<ii", 1, count));
            out.extend(bytes([0, 0, 0, 0, 255, 255, 255, 0]));
            for k in range(count) {
                out.extend(struct.pack("<f", intervals[k] if k < len(intervals) else 0.1 * float(k + 1)));
            }
            for k in range(count) {
                at = min(first + k, frames - 1);
                out.extend(simple_frame(points[at], corners, low, scale, names[at]));
            }
        }
    }
    return bytes(out);
}

"""One frame as an MDL keeps it: its box, its name and each point packed into
the model's box, with its normal's number."""
def:priv simple_frame(stood: list[Vec3], corners: list[int], low: Vec3, scale: Vec3, name: str) -> bytes {
    facing = point_facing(stood, corners);
    packed = bytearray();
    least = [255, 255, 255];
    most = [0, 0, 0];
    for k in range(len(stood)) {
        p = stood[k];
        trio = [
            max(0, min(255, int(round((p.x - low.x) / scale.x)))), max(0, min(255, int(round((p.y - low.y) / scale.y)))),
            max(0, min(255, int(round((p.z - low.z) / scale.z))))
        ];
        for axis in range(3) {
            least[axis] = min(least[axis], trio[axis]);
            most[axis] = max(most[axis], trio[axis]);
        }
        packed.extend(bytes([trio[0], trio[1], trio[2], normal_index(facing[k])]));
    }
    made = bytearray(bytes([least[0], least[1], least[2], 0, most[0], most[1], most[2], 0]));
    made.extend(packed_name(name, 16));
    made.extend(packed);
    return bytes(made);
}

"""Let go of a document's frames and parts once it is written, so a bake
that makes hundreds of models does not keep every pose of every one."""
def release_doc(doc: ModelDoc) {
    for part in doc.parts() {
        for pose in doc.poses(part) {
            pose.points = [];
            part del --> pose;
        }
        doc del --> part;
    }
    for tag in doc.tags() {
        doc del --> tag;
    }
}
