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
import from .field { fbm, streaks, panels, rivets }
import from .sculpt { Sculpture, Prim, SculptMesh }

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
        rest_high: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        # Each tag's place and axes at each frame: how the game hangs one
        # model on another (a weapon in the hand, a head on a torso), which
        # are rules, as an animation.cfg's numbers are, not a shape.
        tag_origins: list[list[Vec3]] = [],
        tag_axes: list[list[list[Vec3]]] = [];

    """Where tag `name` hangs at each frame, or [] when it is not known."""
    def tag_track(name: str) -> tuple[list[Vec3], list[list[Vec3]]] {
        index = self.tags.index(name) if name in self.tags else -1;
        if index < 0 or index >= len(self.tag_origins) {
            return ([], []);
        }
        return (self.tag_origins[index], self.tag_axes[index]);
    }
}

"""Every tag's place and axes, frame by frame, into `facts`."""
def:priv keep_tags(facts: ModelFacts, model: AnimatedModel) {
    if not model.tags {
        return;
    }
    facts.tags = [tag.name for tag in model.tags[0].tags];
    facts.tag_origins = [[] for name in facts.tags];
    facts.tag_axes = [[] for name in facts.tags];
    for frame in model.tags {
        for (k, tag) in enumerate(frame.tags) {
            if k < len(facts.tags) {
                facts.tag_origins[k].append(tag.origin);
                facts.tag_axes[k].append(list(tag.axes));
            }
        }
    }
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
    if kind == "md3" and not model.surfaces and model.tags {
        # A model of tags alone (a player's hand, where a weapon hangs).
        held = ModelFacts(kind=kind, frame_names=["frame " + str(k) for k in range(len(model.tags))]);
        keep_tags(held, model);
        held.low = Vec3(x=-1.0, y=-1.0, z=-1.0);
        held.high = Vec3(x=1.0, y=1.0, z=1.0);
        held.first_low = held.low;
        held.first_high = held.high;
        held.rest_low = held.low;
        held.rest_high = held.high;
        return held;
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
    keep_tags(facts, model);
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
    if leaf.endswith("_hand") {
        return "hand";
    }
    # Quake III keeps its pickups by kind (models/ammo/ holds its rockets
    # and grenades in flight, which are projectiles).
    for (kept, family) in [("/powerups/ammo/", "ammo"), ("/powerups/armor/", "armor"), ("/powerups/health/", "health"), ("/powerups/instant/", "powerup"), ("/powerups/holdable/", "powerup")] {
        if kept in lower {
            return family;
        }
    }
    if "/weapons/" in lower or "/weapons2/" in lower or "/objects/flash" in lower {
        if "flash" in leaf or "/flash" in lower {
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

"""A sculpted mesh as a shaper's: each triangle takes the material most of
its corners have, and a point where materials meet is made once for each,
so every material keeps to its own tile. Returns the shaper and, for each
of its points, the sculpted point it came from."""
def sculpt_shaper(made: SculptMesh) -> tuple[Shaper, list[int]] {
    shaper = Shaper();
    sources: list[int] = [];
    made_for: dict[str, int] = {};
    for f in range(len(made.corners) // 3) {
        a = made.corners[f * 3];
        b = made.corners[f * 3 + 1];
        c = made.corners[f * 3 + 2];
        material = made.materials[a];
        if made.materials[b] == made.materials[c] {
            material = made.materials[b];
        }
        picked: list[int] = [];
        for corner in [a, b, c] {
            key = str(corner) + ":" + material;
            if key not in made_for {
                made_for[key] = shaper.point(made.points[corner], tile_of(material), made.tiles[corner * 2], made.tiles[corner * 2 + 1]);
                sources.append(corner);
            }
            picked.append(made_for[key]);
        }
        shaper.triangle(picked[0], picked[1], picked[2]);
    }
    return (shaper, sources);
}

"""A sculpted solid on the gun's line (+x forward, z up)."""
def:priv part(kind: str, at: Vec3, size: Vec3, material: str, round: float = 0.01, blend: float = 0.012) -> Prim {
    return Prim(kind=kind, at=at, size=size, material=material, round=round, blend=blend);
}

"""A cylinder along the gun's line from `x0` to `x1`."""
def:priv barrel(x0: float, x1: float, y: float, z: float, radius: float, material: str, carve: bool = False) -> Prim {
    return Prim(kind="cylinder", at=Vec3(x=(x0 + x1) * 0.5, y=y, z=z), x=Vec3(y=1.0), y=Vec3(z=1.0), z=Vec3(x=1.0), size=Vec3(x=radius, y=abs(x1 - x0) * 0.5), round=min(radius * 0.3, 0.01), material=material, blend=0.008, carve=carve);
}

"""A ring round the gun's line at `x`."""
def:priv band(x: float, z: float, radius: float, tube: float, material: str) -> Prim {
    return Prim(kind="ring", at=Vec3(x=x, z=z), x=Vec3(y=1.0), y=Vec3(z=1.0), z=Vec3(x=1.0), size=Vec3(x=radius, y=tube), material=material, blend=0.006);
}

"""A weapon sculpted from parts by what its name says it is: a receiver,
a grip and a trigger guard, then the parts of its kind (a shotgun's pump
and long barrels, a machinegun's barrel cluster and drum, a rocket
launcher's tube and sight, the lightning gun's prongs and coils, the
railgun's rings, the plasma gun's cell, the BFG's bulk and dish, an axe's
head, a gauntlet's blade). Measured along +x, about a unit long."""
def sculpt_gun(lower: str, seed: int, held: bool) -> Shaper {
    s = Sculpture(seed=seed);
    p = s.prims;
    leaf = lower.split("/")[-1];
    if "axe" in lower {
        p.append(barrel(-0.5, 0.45, 0.0, 0.0, 0.035, "wood"));
        p.append(part("box", Vec3(x=0.4, z=0.12), Vec3(x=0.09, y=0.02, z=0.16), "steel", 0.008));
        p.append(part("box", Vec3(x=0.33, z=0.0), Vec3(x=0.05, y=0.035, z=0.05), "darksteel"));
        return sculpt_shaper(s.mesh(700, 40))[0];
    }
    if "gauntlet" in lower {
        p.append(part("box", Vec3(x=-0.15), Vec3(x=0.25, y=0.11, z=0.1), "darksteel", 0.03));
        p.append(barrel(0.05, 0.3, 0.0, 0.0, 0.06, "steel"));
        p.append(Prim(kind="cylinder", at=Vec3(x=0.38), x=Vec3(y=1.0), y=Vec3(z=1.0), z=Vec3(x=1.0), size=Vec3(x=0.2, y=0.01), material="steel", blend=0.004));
        p.append(band(0.0, 0.0, 0.09, 0.02, "glowblue"));
        return sculpt_shaper(s.mesh(700, 44))[0];
    }
    # The kind decides the body's bulk and the barrel's reach and bore.
    bulk = 0.085;
    reach = 0.55;
    bore = 0.03;
    if "rocket" in lower or "rl" in leaf[:3] or "launch" in lower {
        bulk = 0.11;
        bore = 0.085;
    } elif "gren" in lower {
        bulk = 0.1;
        reach = 0.3;
        bore = 0.05;
    } elif "rail" in lower {
        reach = 0.7;
        bore = 0.022;
    } elif "bfg" in lower {
        bulk = 0.16;
        reach = 0.3;
        bore = 0.1;
    } elif "plasma" in lower or "hyper" in lower or "blast" in lower {
        bulk = 0.1;
        reach = 0.35;
        bore = 0.04;
    } elif "light" in lower or "lg" in leaf[:3] {
        reach = 0.4;
        bore = 0.04;
    }
    # The receiver, a rail along its top, the grip and its guard.
    p.append(part("box", Vec3(x=-0.12, z=0.0), Vec3(x=0.26, y=bulk * 0.8, z=bulk), "darksteel", 0.02));
    p.append(part("box", Vec3(x=-0.1, z=bulk * 0.95), Vec3(x=0.2, y=bulk * 0.3, z=0.015), "steel", 0.006));
    grip = Prim(kind="box", at=Vec3(x=-0.2, z=-bulk - 0.08), size=Vec3(x=0.04, y=bulk * 0.45, z=0.1), material="rubber", round=0.015, blend=0.02);
    grip_axes = turned_axes_for(15.0);
    grip.x = grip_axes[0];
    grip.y = grip_axes[1];
    grip.z = grip_axes[2];
    p.append(grip);
    p.append(Prim(kind="ring", at=Vec3(x=-0.12, z=-bulk - 0.03), x=Vec3(x=1.0), y=Vec3(z=1.0), z=Vec3(y=1.0), size=Vec3(x=0.05, y=0.008), material="steel", blend=0.004));
    if "shot" in lower or "sg" in leaf[:3] or "ssg" in lower {
        double = "super" in lower or "sshot" in lower or "ssg" in lower;
        p.append(part("box", Vec3(x=-0.5, z=-0.02), Vec3(x=0.16, y=bulk * 0.6, z=bulk * 0.9), "wood", 0.03));
        for side in ([-1.0, 1.0] if double else [0.0]) {
            p.append(barrel(0.1, 0.62, side * 0.035, 0.03, 0.03, "steel"));
            p.append(barrel(0.55, 0.64, side * 0.035, 0.03, 0.018, "steel", True));
        }
        if not double {
            p.append(part("box", Vec3(x=0.3, z=-0.04), Vec3(x=0.12, y=0.04, z=0.03), "wood", 0.015));
        }
    } elif "machine" in lower or "chain" in lower or "nail" in lower or "mg" in leaf[:3] {
        count = 6 if "chain" in lower or "super" in lower or "nail2" in lower else 3;
        for k in range(count) {
            a = float(k) / float(count) * 2.0 * math.pi;
            p.append(barrel(0.1, 0.5, math.cos(a) * 0.035, math.sin(a) * 0.035 + 0.01, 0.016, "steel"));
        }
        p.append(band(0.15, 0.01, 0.05, 0.015, "darksteel"));
        p.append(band(0.45, 0.01, 0.05, 0.012, "darksteel"));
        p.append(barrel(-0.05, 0.0, 0.0, -bulk - 0.06, 0.07, "brass"));
    } elif "rocket" in lower or "rl" in leaf[:3] or "launch" in lower {
        p.append(barrel(-0.4, 0.55, 0.0, 0.02, 0.09, "darksteel"));
        p.append(barrel(0.5, 0.6, 0.0, 0.02, 0.11, "steel"));
        p.append(barrel(-0.45, -0.38, 0.0, 0.02, 0.1, "steel"));
        p.append(barrel(0.45, 0.62, 0.0, 0.02, 0.065, "steel", True));
        p.append(part("box", Vec3(x=0.0, y=0.08, z=0.12), Vec3(x=0.08, y=0.02, z=0.03), "steel", 0.008));
        p.append(band(0.2, 0.02, 0.09, 0.012, "red"));
    } elif "gren" in lower {
        p.append(barrel(-0.05, 0.15, 0.0, 0.0, 0.1, "darksteel"));
        for k in range(6) {
            a = float(k) / 6.0 * 2.0 * math.pi;
            p.append(barrel(-0.04, 0.14, math.cos(a) * 0.06, math.sin(a) * 0.06, 0.022, "green", True));
        }
        p.append(barrel(0.1, 0.35, 0.0, 0.02, 0.05, "steel"));
    } elif "light" in lower or "lg" in leaf[:3] {
        p.append(barrel(0.1, 0.3, 0.0, 0.0, 0.05, "darksteel"));
        for k in range(3) {
            a = float(k) / 3.0 * 2.0 * math.pi;
            p.append(Prim(kind="capsule", at=Vec3(x=0.28, y=math.cos(a) * 0.03, z=math.sin(a) * 0.03), to=Vec3(x=0.45, y=math.cos(a) * 0.055, z=math.sin(a) * 0.055), r1=0.012, r2=0.006, material="steel", blend=0.006));
        }
        for x in [0.0, 0.08, 0.16] {
            p.append(band(x, 0.0, 0.07, 0.012, "glowblue"));
        }
    } elif "rail" in lower {
        p.append(barrel(0.1, 0.75, 0.0, 0.02, 0.025, "steel"));
        p.append(part("box", Vec3(x=0.42, y=0.0, z=-0.03), Vec3(x=0.3, y=0.018, z=0.012), "darksteel", 0.004));
        for k in range(5) {
            p.append(band(0.18 + float(k) * 0.12, 0.02, 0.045, 0.01, "glowblue"));
        }
        p.append(part("box", Vec3(x=-0.45, z=-0.01), Vec3(x=0.12, y=0.035, z=0.06), "darksteel", 0.02));
    } elif "bfg" in lower {
        p.append(part("box", Vec3(x=-0.05, z=0.03), Vec3(x=0.3, y=0.16, z=0.14), "darksteel", 0.05));
        p.append(barrel(0.2, 0.32, 0.0, 0.03, 0.15, "steel"));
        p.append(Prim(kind="ellipsoid", at=Vec3(x=0.28, z=0.03), size=Vec3(x=0.05, y=0.1, z=0.1), material="glow", blend=0.01));
        p.append(barrel(0.28, 0.4, 0.0, 0.03, 0.09, "steel", True));
    } elif "plasma" in lower or "hyper" in lower or "blast" in lower {
        p.append(barrel(0.05, 0.38, 0.0, 0.02, 0.05, "darksteel"));
        p.append(barrel(0.34, 0.4, 0.0, 0.02, 0.03, "steel", True));
        p.append(Prim(kind="ellipsoid", at=Vec3(x=-0.05, z=bulk + 0.03), size=Vec3(x=0.09, y=0.05, z=0.05), material="glowblue", blend=0.015));
        for x in [0.12, 0.2, 0.28] {
            p.append(band(x, 0.02, 0.055, 0.012, "darksteel"));
        }
    } else {
        p.append(barrel(0.1, 0.1 + reach, 0.0, 0.02, bore + 0.01, "steel"));
        p.append(barrel(0.05 + reach, 0.12 + reach, 0.0, 0.02, bore, "steel", True));
    }
    if held {
        # The hand that holds it, gloved, and the forearm behind it.
        p.append(Prim(kind="ellipsoid", at=Vec3(x=-0.2, y=0.0, z=-bulk - 0.06), size=Vec3(x=0.07, y=0.065, z=0.06), material="leather", blend=0.02));
        # The forearm runs back and a little down, most of the length
        # of what the player sees (the gun at its end).
        p.append(Prim(kind="capsule", at=Vec3(x=-0.26, y=0.02, z=-bulk - 0.08), to=Vec3(x=-1.0, y=0.1, z=-bulk - 0.25), r1=0.055, r2=0.068, material="leather", blend=0.03));
        p.append(Prim(kind="capsule", at=Vec3(x=-1.0, y=0.1, z=-bulk - 0.25), to=Vec3(x=-1.6, y=0.14, z=-bulk - 0.38), r1=0.068, r2=0.08, material="flesh", blend=0.04));
    }
    return sculpt_shaper(s.mesh(900, 52))[0];
}

"""A grip's axes: tilted back `degrees` about the gun's side."""
def:priv turned_axes_for(degrees: float) -> list[Vec3] {
    r = math.radians(degrees);
    return [Vec3(x=math.cos(r), z=-math.sin(r)), Vec3(y=1.0), Vec3(x=math.sin(r), z=math.cos(r))];
}

"""Build the rest shape of a model of `family`; empty for one this does not
make."""
def build_shape(family: str, lower: str, seed: int) -> Shaper {
    shaper = Shaper();
    pick = mix32(seed) % 4;
    if family == "weapon" {
        # Quake II's view weapons are held in a hand (Quake's show the gun
        # alone).
        held = "/weapons/v_" in lower;
        shaper = sculpt_gun(lower, seed, held);
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
        if "shard" in lower {
            shaper.lathe(Frame(at=Vec3(z=-0.5)), [(0.0, 0.0), (0.35, 0.2), (0.3, 0.7), (0.0, 1.0)], 6, tile_of(colour));
        } else {
            # A breastplate (wider across the shoulders than deep), its two
            # shoulder guards and a collar.
            shaper.lathe(Frame(at=Vec3(z=-0.5)), [(0.2, 0.0), (0.3, 0.15), (0.34, 0.55), (0.3, 0.8), (0.18, 0.9)], 12, tile_of(colour), 0.55);
            for side in [-1.0, 1.0] {
                shaper.ball(Frame(at=Vec3(y=side * 0.36, z=0.3)), Vec3(x=0.2, y=0.16, z=0.13), 5, 8, tile_of(colour));
            }
            shaper.ring(Frame(at=Vec3(z=0.4)), 0.15, 0.04, 10, 4, tile_of("darksteel"));
        }
    } elif family == "health" {
        if "mega" in lower or "sphere" in lower or "stim" in lower {
            shaper.ball(Frame(), Vec3(x=0.5, y=0.5, z=0.5), 8, 10, tile_of("white" if "stim" not in lower else "glowblue"));
        }
        shaper.box(Frame(), Vec3(x=0.25, y=0.25, z=0.8), tile_of("red"));
        shaper.box(Frame(), Vec3(x=0.8, y=0.25, z=0.25), tile_of("red"));
    } elif family == "ammo" {
        # Coloured by what it feeds, as the games colour their ammunition.
        material = ["darksteel", "wood", "green", "brass"][pick];
        for (words, kind) in [(["machinegun", "bullet"], "yellow"), (["shotgun", "shell"], "brass"), (["rocket"], "red"), (["plasma", "cell"], "blue"), (["lightning"], "white"), (["rail", "slug"], "green"), (["grenade"], "green"), (["bfg"], "glowblue"), (["nail"], "steel")] {
            for word in words {
                if word in lower {
                    material = kind;
                }
            }
        }
        shaper.box(Frame(), Vec3(x=1.0, y=0.7, z=0.6), tile_of(material));
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
    } elif family == "flash" {
        # A muzzle flash: a star of glow across the muzzle (two crossed
        # blades and a disc), a little deep along +x.
        shaper.box(Frame(), Vec3(x=0.15, y=1.0, z=0.18), tile_of("glow"));
        shaper.box(Frame(), Vec3(x=0.15, y=0.18, z=1.0), tile_of("glow"));
        shaper.lathe(Frame(x=Vec3(y=1.0), y=Vec3(z=1.0), z=Vec3(x=1.0)), [(0.0, -0.1), (0.35, 0.0), (0.2, 0.3), (0.0, 0.5)], 10, tile_of("glow"));
    } elif family == "hand" {
        # Nothing to see: where a weapon hangs, by its tags.
        shaper.ball(Frame(), Vec3(x=0.01, y=0.01, z=0.01), 2, 3, tile_of("rubber"));
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

"""The shape turned a quarter about its up axis when its long side would
then lie along the box's long side."""
def turned_to_fit(points: list[Vec3], low: Vec3, high: Vec3) -> list[Vec3] {
    if not points {
        return points;
    }
    a = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    b = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for p in points {
        a = Vec3(x=min(a.x, p.x), y=min(a.y, p.y), z=min(a.z, p.z));
        b = Vec3(x=max(b.x, p.x), y=max(b.y, p.y), z=max(b.z, p.z));
    }
    shape_long_x = (b.x - a.x) >= (b.y - a.y);
    box_long_x = (high.x - low.x) >= (high.y - low.y);
    if shape_long_x == box_long_x {
        return points;
    }
    return [Vec3(x=-p.y, y=p.x, z=p.z) for p in points];
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
    fitted: list[Vec3] = [];
    if family in ["armor", "health", "ammo", "powerup", "key", "flash", "explosion"] {
        fitted = fitted_points(turned_to_fit(shaper.points, facts.first_low, facts.first_high), facts.first_low, facts.first_high);
    } else {
        fitted = placed_points(
            shaper.points, facts.rest_low if family == "weapon" else facts.first_low,
            facts.rest_high if family == "weapon" else facts.first_high, family == "weapon"
        );
    }
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
        (origins, axes) = facts.tag_track(name);
        if len(origins) >= len(facts.frame_names) and origins {
            tag.origins = origins[:len(facts.frame_names)];
            tag.axes = axes[:len(facts.frame_names)];
        } else {
            # Not known: a weapon's muzzle at its front, anything else at
            # its middle.
            spot = middle;
            if "flash" in name or "barrel" in name {
                spot = Vec3(x=facts.first_high.x, y=middle.y, z=middle.z);
            }
            tag.origins = [spot for frame in range(len(facts.frame_names))];
            tag.axes = [[Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)] for frame in range(len(facts.frame_names))];
        }
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
    tints = {
        "steel": "8b939b", "darksteel": "4b4f57", "brass": "c39b4b", "wood": "8b6b43", "flesh": "9b6b53", "bone": "d3c3a3",
        "red": "b32b1b", "blue": "2b4bb3", "green": "3b8b2b", "yellow": "d3b32b", "glow": "ffb34b", "glowblue": "6bb3ff",
        "stone": "7b7b73", "leather": "5b3b23", "rubber": "232323", "white": "dbdbdb"
    };
    seed = hash_label(19, name.lower());
    for k in range(16) {
        material = MATERIALS[k];
        tile = material_tile(material, tile_w, tile_h, seed + k * 101, hex_rgb(tints[material]));
        x0 = (k % 4) * w // 4;
        y0 = (k // 4) * h // 4;
        x1 = ((k % 4) + 1) * w // 4;
        y1 = ((k // 4) + 1) * h // 4;
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                made.put(y * w + x, tile.colour(((y - y0) % tile_h) * tile_w + ((x - x0) % tile_w)));
            }
        }
    }
    return made;
}

"""A tile of a model's skin painted as its material is, not as a wall:
plate metal brushed, seamed, riveted and worn at its edges (paint chipped
to the metal beneath); flesh mottled and veined; leather grained and
stitched; bone cracked; rubber matte; a glow bright at its heart."""
def material_tile(material: str, w: int, h: int, seed: int, tint: Rgb) -> Picture {
    made = Picture(w=w, h=h);
    broad = fbm(w, h, 4, 4, 0.55, seed);
    fine = fbm(w, h, 16, 3, 0.5, seed + 1);
    lines = fbm(w, h, 6, 3, 0.5, seed + 2);
    brushed = streaks(w, h, max(4, w // 2), 8, seed + 3);
    plates = panels(w, h, 2, 2, 1.5, 2.5).height;
    studs = rivets(w, h, 4, 4, max(1.0, float(w) / 40.0), 0.12);
    metal = material in ["steel", "darksteel", "brass", "red", "blue", "green", "yellow", "white"];
    painted = material in ["red", "blue", "green", "yellow", "white"];
    bare = Rgb(r=0.62, g=0.62, b=0.6);
    for y in range(h) {
        for x in range(w) {
            i = y * w + x;
            colour = tint;
            if metal {
                k = 0.72 + 0.22 * brushed.v[i] + 0.16 * (broad.v[i] - 0.5);
                # Seams between plates dark, their bevels catching light.
                if plates.v[i] < 0.15 {
                    k *= 0.45;
                } elif plates.v[i] < 0.55 {
                    k *= 1.18;
                }
                colour = tint.scaled(k);
                if painted and (fine.v[i] > 0.74 or (plates.v[i] < 0.6 and fine.v[i] > 0.6)) {
                    # Paint worn off where knocks and edges take it.
                    colour = bare.scaled(0.7 + 0.3 * brushed.v[i]);
                }
                if studs.v[i] > 0.2 {
                    colour = colour.scaled(0.9 + 0.5 * studs.v[i]);
                }
                if fine.v[i] < 0.22 {
                    colour = colour.mixed(Rgb(r=0.32, g=0.18, b=0.08), 0.35);
                }
            } elif material == "flesh" {
                colour = tint.scaled(0.68 + 0.5 * broad.v[i] + 0.1 * (fine.v[i] - 0.5));
                if abs(lines.v[i] - 0.5) < 0.025 {
                    colour = colour.mixed(Rgb(r=0.35, g=0.08, b=0.08), 0.45);
                }
            } elif material == "leather" {
                colour = tint.scaled(0.72 + 0.35 * fine.v[i] + 0.12 * (broad.v[i] - 0.5));
                if (y % (h // 2)) == h // 4 and (x // 3) % 2 == 0 {
                    colour = colour.scaled(1.45);
                }
            } elif material == "bone" {
                colour = tint.scaled(0.82 + 0.18 * broad.v[i]);
                if abs(lines.v[i] - 0.5) < 0.015 {
                    colour = colour.scaled(0.55);
                }
            } elif material == "glow" or material == "glowblue" {
                u = (float(x) + 0.5) / float(w) * 2.0 - 1.0;
                v = (float(y) + 0.5) / float(h) * 2.0 - 1.0;
                heart = max(0.0, 1.0 - math.sqrt(u * u + v * v));
                colour = tint.mixed(Rgb(r=1.0, g=1.0, b=0.92), heart * 0.7);
            } elif material == "rubber" {
                colour = tint.scaled(0.8 + 0.5 * fine.v[i]);
            } else {
                colour = tint.scaled(0.7 + 0.3 * broad.v[i] + 0.15 * (brushed.v[i] - 0.5));
            }
            made.put(i, Rgb(r=max(0.0, min(1.0, colour.r)), g=max(0.0, min(1.0, colour.g)), b=max(0.0, min(1.0, colour.b))));
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
