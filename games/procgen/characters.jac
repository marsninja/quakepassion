"""Characters made by code: the monsters of Quake and Quake II and the
players of all three games, with their animations.

A character is a skeleton of bones (a `Bone` node for each, `Child` edges
from each to the bones that hang from it) and a body plan that says what
the skeleton is (two legs, four, wings, a fish's spine) and how bulky each
limb is. Each limb is a tapered capsule that rides on its bone, so a frame
is posed by turning the bones and carrying each limb's points with its own.
A `PoseWalk` walker goes down the skeleton from the hips, turning each bone
by its own angles on top of its parent's.

Every frame the game's own model has is kept, by name and in order, and
posed from its name: the run of frames a name belongs to (`run3` is the
third of `run1`..`run6`) says the action and how far through it the frame
is. Walking and running swing the legs and the arms against them;
attacking lifts the striking arm and brings it down; pain throws the body
back; dying topples it to the floor; standing breathes. Quake III's players
are three models (legs, torso, head) joined by tags, and their animations
come from the frame ranges their `animation.cfg` gives."""
import math;
import from games.passion.random { hash_label, mix32 }
import from engine.math.vec3 { Vec3 }
import from editor.model.document { ModelDoc, Part, Pose, Tag, HasPart, HasPose, HasTag }
import from .shapes { Shaper, Frame, frame_along }
import from .models { ModelFacts, tile_of, sculpt_shaper }
import from .sculpt { Sculpture, Prim }

node Bone {
    has name: str,
        # Where the bone's joint is from its parent's, at rest, and how long
        # it reaches (along its own -z: limbs hang down) and how thick it is.
        offset: Vec3 = Vec3(),
        length: float = 0.3,
        radius: float = 0.08,
        tip_radius: float = 0.06,
        material: str = "flesh",
        # The bone's turn at the frame being posed (degrees about x, y, z).
        pitch: float = 0.0,
        roll: float = 0.0,
        yaw: float = 0.0,
        # Where the bone stands in the frame being posed: its joint and axes.
        world: Frame = Frame();
}

edge Child: Bone --> Bone {}

"""A solid a bone carries: its flesh, armour or horn."""
edge Wears: Bone --> Prim {}

"""A rotation of `v` about x (roll), y (pitch) and z (yaw), degrees."""
def turned(v: Vec3, roll: float, pitch: float, yaw: float) -> Vec3 {
    r = math.radians(roll);
    p = math.radians(pitch);
    y = math.radians(yaw);
    # About x.
    v1 = Vec3(x=v.x, y=v.y * math.cos(r) - v.z * math.sin(r), z=v.y * math.sin(r) + v.z * math.cos(r));
    # About y.
    v2 = Vec3(x=v1.x * math.cos(p) + v1.z * math.sin(p), y=v1.y, z=-v1.x * math.sin(p) + v1.z * math.cos(p));
    # About z.
    return Vec3(x=v2.x * math.cos(y) - v2.y * math.sin(y), y=v2.x * math.sin(y) + v2.y * math.cos(y), z=v2.z);
}

"""Places every bone for the frame being posed: each bone's joint is its
parent's frame carrying its offset, its axes its parent's turned by its
own angles."""
walker PoseWalk {
    has root_at: Vec3 = Vec3(),
        whole_pitch: float = 0.0,
        whole_roll: float = 0.0;

    can place with Bone entry {
        parent = [here<-:Child:<-];
        if not parent {
            axes = Frame(at=self.root_at);
            axes.x = turned(Vec3(x=1.0), self.whole_roll, self.whole_pitch, 0.0);
            axes.y = turned(Vec3(y=1.0), self.whole_roll, self.whole_pitch, 0.0);
            axes.z = turned(Vec3(z=1.0), self.whole_roll, self.whole_pitch, 0.0);
            here.world = carried(axes, Vec3(), here.roll, here.pitch, here.yaw);
        } else {
            above = parent[0].world;
            here.world = carried(above, here.offset, here.roll, here.pitch, here.yaw);
        }
        visit [here->:Child:->];
    }
}

"""A child's frame: its joint at `offset` in its parent's frame, its axes the
parent's turned by its angles."""
def carried(parent: Frame, offset: Vec3, roll: float, pitch: float, yaw: float) -> Frame {
    at = parent.place(offset);
    lx = turned(Vec3(x=1.0), roll, pitch, yaw);
    ly = turned(Vec3(y=1.0), roll, pitch, yaw);
    lz = turned(Vec3(z=1.0), roll, pitch, yaw);
    return Frame(
        at=at, x=parent.x.scale(lx.x).add(parent.y.scale(lx.y)).add(parent.z.scale(lx.z)),
        y=parent.x.scale(ly.x).add(parent.y.scale(ly.y)).add(parent.z.scale(ly.z)),
        z=parent.x.scale(lz.x).add(parent.y.scale(lz.y)).add(parent.z.scale(lz.z))
    );
}

"""Every bone under (and including) `start`, parents before children."""
walker Gather {
    has bones: list[Bone] = [];

    can take with Bone entry {
        self.bones.append(here);
        visit [here->:Child:->];
    }
}

"""A body: its skeleton's first bone (the hips, or a fish's or a flyer's
body), its plan, and how high its hips stand at rest."""
obj Body {
    has hips: Bone,
        plan: str,
        stance: float = 1.0,
        size: float = 0.5;

    def bones -> list[Bone] {
        gathered = self.hips spawn Gather();
        return gathered.bones;
    }

    def named(name: str) -> Bone | None {
        for bone in self.bones() {
            if bone.name == name {
                return bone;
            }
        }
        return None;
    }
}

def:priv bone(name: str, offset: Vec3, length: float, radius: float, tip: float, material: str) -> Bone {
    return Bone(name=name, offset=offset, length=length, radius=radius, tip_radius=tip, material=material);
}

"""What kind of body a character's path calls for, and how big it is."""
def body_plan(path: str) -> tuple[str, float] {
    lower = path.lower();
    plans: list[tuple[str, str, float]] = [
        ("dog", "quadruped", 0.3), ("mutant", "quadruped", 0.6), ("parasite", "quadruped", 0.35), ("fish", "fish", 0.3),
        ("wizard", "flyer", 0.4), ("flyer", "flyer", 0.3), ("hover", "flyer", 0.45), ("floater", "flyer", 0.5),
        ("tarbaby", "blob", 0.3), ("oldone", "blob", 1.0), ("boss", "giant", 1.0), ("shambler", "brute", 0.95),
        ("ogre", "brute", 0.8), ("tank", "brute", 0.9), ("gladiator", "brute", 0.8), ("berserk", "brute", 0.75),
        ("makron", "brute", 1.0), ("jorg", "brute", 1.0), ("brain", "brute", 0.65), ("shalrath", "brute", 0.6),
        ("demon", "brute", 0.7), ("hknight", "biped", 0.65), ("knight", "biped", 0.55), ("zombie", "biped", 0.5),
        ("soldier", "biped", 0.45), ("army", "biped", 0.45), ("enforcer", "biped", 0.5), ("infantry", "biped", 0.5),
        ("gunner", "biped", 0.55), ("medic", "biped", 0.55), ("chick", "biped", 0.4), ("bitch", "biped", 0.4),
        ("insane", "biped", 0.45), ("female", "biped", 0.4), ("cyborg", "biped", 0.5), ("player", "biped", 0.45)
    ];
    for (word, plan, size) in plans {
        if word in lower {
            return (plan, size);
        }
    }
    return ("biped", 0.5);
}

"""Build a body of a plan; proportions from its size and seed."""
def build_body(path: str, seed: int) -> Body {
    (plan, size) = body_plan(path);
    k = float(mix32(seed) % 100) / 100.0;
    # Flesh under gunmetal, mostly, as the games' creatures are; now and
    # then leather, a green hide or stone, brass or red plate.
    skin = ["flesh", "flesh", "flesh", "leather", "green", "stone"][mix32(seed + 1) % 6];
    armour = ["darksteel", "darksteel", "steel", "steel", "brass", "red"][mix32(seed + 2) % 6];
    if plan == "quadruped" {
        hips = bone("hips", Vec3(), 0.0, 0.0, 0.0, skin);
        spine = bone("spine", Vec3(), 0.55, 0.16 + size * 0.08, 0.14 + size * 0.08, skin);
        spine.pitch = -90.0;
        hips +>:Child:+> spine;
        head = bone("head", Vec3(z=-0.55), 0.22, 0.12, 0.08, skin);
        head.pitch = 20.0;
        spine +>:Child:+> head;
        for (name, along, side) in [("leg_fl", -0.5, 1.0), ("leg_fr", -0.5, -1.0), ("leg_bl", -0.02, 1.0), ("leg_br", -0.02, -1.0)] {
            leg = bone(name, Vec3(z=along, y=0.12 * side), 0.4, 0.06, 0.04, skin);
            leg.pitch = 90.0;
            spine +>:Child:+> leg;
        }
        tail = bone("tail", Vec3(), 0.3, 0.04, 0.01, skin);
        tail.pitch = 120.0;
        spine +>:Child:+> tail;
        return Body(hips=hips, plan=plan, stance=0.45, size=size);
    }
    if plan == "fish" {
        hips = bone("hips", Vec3(), 0.0, 0.0, 0.0, skin);
        body = bone("spine", Vec3(), 0.7, 0.18, 0.05, "green");
        body.pitch = 90.0;
        hips +>:Child:+> body;
        head = bone("head", Vec3(), 0.25, 0.16, 0.1, "green");
        head.pitch = -90.0;
        hips +>:Child:+> head;
        fin = bone("tail", Vec3(z=-0.7), 0.25, 0.12, 0.02, "green");
        body +>:Child:+> fin;
        return Body(hips=hips, plan=plan, stance=0.3, size=size);
    }
    if plan == "blob" {
        hips = bone("hips", Vec3(), 0.6 * (0.5 + size), 0.35 + size * 0.3, 0.3, skin);
        hips.pitch = 180.0;
        for k2 in range(4) {
            a = float(k2) * 90.0;
            arm = bone("arm" + str(k2), Vec3(z=-0.3), 0.4, 0.08, 0.02, skin);
            arm.yaw = a;
            arm.pitch = 60.0;
            hips +>:Child:+> arm;
        }
        return Body(hips=hips, plan=plan, stance=0.2, size=size);
    }
    # Two legs (a biped, a brute, a giant, a flyer's dangling ones).
    bulk = 1.0 + (0.6 if plan == "brute" else 0.0) + (1.0 if plan == "giant" else 0.0);
    leg_len = 0.45 if plan != "flyer" else 0.2;
    hips = bone("hips", Vec3(), 0.0, 0.0, 0.0, skin);
    torso = bone("torso", Vec3(), 0.5, 0.15 * bulk, 0.19 * bulk, armour);
    # Turned up by a roll, not a pitch, so it still faces +x as the games'
    # models do.
    torso.roll = 180.0;
    hips +>:Child:+> torso;
    neck_up = bone("head", Vec3(z=-0.5), 0.2 + 0.03 * bulk, 0.1 + 0.02 * bulk, 0.08, skin);
    torso +>:Child:+> neck_up;
    for (side, sign) in [("l", 1.0), ("r", -1.0)] {
        upper_arm = bone("arm_" + side, Vec3(z=-0.45, y=(0.2 * bulk + 0.04) * sign), 0.28 * (1.0 + 0.3 * (bulk - 1.0)), 0.06 * bulk, 0.05 * bulk, armour);
        upper_arm.roll = 180.0;
        torso +>:Child:+> upper_arm;
        fore_arm = bone("fore_" + side, Vec3(z=-0.28 * (1.0 + 0.3 * (bulk - 1.0))), 0.27 * (1.0 + 0.4 * (bulk - 1.0)), 0.05 * bulk, 0.045 * bulk, skin);
        upper_arm +>:Child:+> fore_arm;
        thigh = bone("thigh_" + side, Vec3(y=0.1 * bulk * sign), leg_len * 0.5, 0.08 * bulk, 0.06 * bulk, armour);
        hips +>:Child:+> thigh;
        shin = bone("shin_" + side, Vec3(z=-leg_len * 0.5), leg_len * 0.5, 0.06 * bulk, 0.05 * bulk, skin);
        thigh +>:Child:+> shin;
        if plan == "flyer" {
            wing = bone("wing_" + side, Vec3(z=-0.3, y=0.1 * sign), 0.5, 0.03, 0.01, "leather");
            wing.roll = 100.0 * sign;
            torso +>:Child:+> wing;
        }
    }
    return Body(hips=hips, plan=plan, stance=leg_len, size=size);
}

"""The action a frame's name belongs to and how far through it the frame
is: the name's letters say the action, its number the step, out of how
many frames share those letters."""
def actions_of(names: list[str]) -> list[tuple[str, float]] {
    counts: dict[str, int] = {};
    stems: list[str] = [];
    for name in names {
        stem = name.lower().rstrip("0123456789").rstrip("_");
        stems.append(stem);
        counts[stem] = counts.get(stem, 0) + 1;
    }
    seen: dict[str, int] = {};
    made: list[tuple[str, float]] = [];
    for stem in stems {
        index = seen.get(stem, 0);
        seen[stem] = index + 1;
        count = counts[stem];
        made.append((stem, float(index) / float(max(1, count - 1)) if count > 1 else 0.0));
    }
    return made;
}

"""What an action's name means for the body."""
def action_kind(stem: str) -> str {
    table: list[tuple[str, list[str]]] = [
        ("death", ["death", "die", "dead", "fall", "gib"]),
        ("pain", ["pain", "hit", "flinch"]),
        ("attack", ["attack", "atk", "shoot", "fire", "swing", "smash", "slash", "punch", "magic", "melee", "shot", "bite", "leap", "throw", "charge", "kick", "claw"]),
        ("run", ["run", "rn", "charge"]),
        ("walk", ["walk", "wk", "back"]),
        ("jump", ["jump", "jmp", "land"]),
        ("swim", ["swim"]),
        ("crouch", ["crouch", "duck", "crawl", "crwl", "crstnd", "crwalk", "crattak", "crpain", "crdeath"]),
        ("taunt", ["taunt", "flip", "wave", "salute", "point", "gesture"])
    ];
    for (kind, words) in table {
        for word in words {
            if word in stem {
                return kind;
            }
        }
    }
    return "stand";
}

"""Turn the body's bones for one frame of an action, `t` from 0 to 1 through
it (an action that loops comes round to its start)."""
def pose_bones(body: Body, kind: str, t: float, seed: int) -> tuple[float, float, float] {
    for b in body.bones() {
        b.roll = 0.0;
        b.yaw = 0.0;
    }
    # The rest angles each plan's builder set: limbs hang, torsos point up.
    rest: dict[str, float] = {"spine": -90.0, "head": 0.0};
    for b in body.bones() {
        b.pitch = rest.get(b.name, 0.0);
        if b.name in ["torso", "arm_l", "arm_r"] and body.plan not in ["quadruped", "fish", "blob"] {
            b.roll = 180.0;
        }
        # Arms held a little away from the body, elbows a little bent, and a
        # brute's back hunched: a body ready to move, not a statue's.
        if body.plan in ["biped", "brute", "giant", "flyer"] {
            spread = ARM_SPREAD * (1.8 if body.plan in ["brute", "giant"] else 1.0);
            if b.name == "arm_l" {
                b.roll = 180.0 - spread;
            } elif b.name == "arm_r" {
                b.roll = 180.0 + spread;
            } elif b.name in ["fore_l", "fore_r"] {
                b.pitch = -25.0;
            } elif b.name == "torso" and body.plan in ["brute", "giant"] {
                b.pitch = HUNCH;
            }
        }
        if body.plan == "quadruped" {
            if b.name.startswith("leg_") {
                b.pitch = 90.0;
            } elif b.name == "head" {
                b.pitch = 20.0;
            } elif b.name == "tail" {
                b.pitch = 120.0;
            }
        } elif body.plan == "fish" {
            if b.name == "spine" {
                b.pitch = 90.0;
            } elif b.name == "head" {
                b.pitch = -90.0;
            }
        } elif body.plan == "blob" {
            if b.name == "hips" {
                b.pitch = 180.0;
            } elif b.name.startswith("arm") {
                b.pitch = 60.0 + 20.0 * math.sin(t * 6.28 + float(len(b.name)));
                b.yaw = float(int(b.name[-1:]) if b.name[-1:].isdigit() else 0) * 90.0;
            }
        } elif b.name.startswith("wing_") {
            b.roll = (100.0 if b.name.endswith("l") else -100.0) + 30.0 * math.sin(t * 6.28) * (1.0 if b.name.endswith("l") else -1.0);
        }
    }
    swing = math.sin(t * 2.0 * math.pi);
    lift = 0.0;
    whole_pitch = 0.0;
    whole_roll = 0.0;
    reach = 0.0;
    if kind == "walk" or kind == "run" {
        amount = 30.0 if kind == "walk" else 50.0;
        for (name, sign) in [("thigh_l", 1.0), ("thigh_r", -1.0)] {
            leg = body.named(name);
            if leg is not None {
                leg.pitch = -swing * amount * sign;
            }
        }
        for (name, sign) in [("shin_l", 1.0), ("shin_r", -1.0)] {
            shin = body.named(name);
            if shin is not None {
                shin.pitch = max(0.0, swing * sign) * amount * 1.2;
            }
        }
        for (name, sign) in [("arm_l", -1.0), ("arm_r", 1.0)] {
            arm = body.named(name);
            if arm is not None {
                arm.pitch = swing * amount * 0.7 * sign;
            }
        }
        for (name, sign) in [("leg_fl", 1.0), ("leg_br", 1.0), ("leg_fr", -1.0), ("leg_bl", -1.0)] {
            leg2 = body.named(name);
            if leg2 is not None {
                leg2.pitch = 90.0 + swing * amount * sign;
            }
        }
        lift = abs(swing) * 0.03;
        whole_pitch = 8.0 if kind == "run" else 3.0;
        tail = body.named("tail");
        if tail is not None {
            tail.yaw = swing * 25.0;
        }
    } elif kind == "attack" {
        # Wind up, strike, follow through.
        strike = math.sin(min(1.0, t * 1.3) * math.pi);
        arm_r = body.named("arm_r");
        fore_r = body.named("fore_r");
        if arm_r is not None {
            arm_r.pitch = -150.0 * strike;
        }
        if fore_r is not None {
            fore_r.pitch = -40.0 * strike;
        }
        head = body.named("head");
        if head is not None and body.plan == "quadruped" {
            head.pitch = 20.0 - 30.0 * strike;
            reach = strike * 0.1;
        }
        whole_pitch = 10.0 * strike;
    } elif kind == "pain" {
        jolt = math.sin(t * math.pi);
        whole_pitch = -18.0 * jolt;
        for name in ["arm_l", "arm_r"] {
            arm = body.named(name);
            if arm is not None {
                arm.pitch = -40.0 * jolt;
            }
        }
    } elif kind == "death" {
        # Over backwards (or to a side, by seed), the knees giving first.
        fall = min(1.0, t * 1.15);
        ease = fall * fall * (3.0 - 2.0 * fall);
        sideways = mix32(seed) % 3 == 0;
        if sideways {
            whole_roll = 85.0 * ease;
        } else {
            whole_pitch = -85.0 * ease;
        }
        for name in ["shin_l", "shin_r"] {
            shin = body.named(name);
            if shin is not None {
                shin.pitch = 50.0 * math.sin(fall * math.pi);
            }
        }
        for name in ["arm_l", "arm_r"] {
            arm = body.named(name);
            if arm is not None {
                arm.pitch = -70.0 * ease;
            }
        }
        lift = -body.stance * 0.8 * ease;
    } elif kind == "jump" {
        for name in ["thigh_l", "thigh_r"] {
            leg = body.named(name);
            if leg is not None {
                leg.pitch = -60.0 * math.sin(t * math.pi);
            }
        }
        for name in ["shin_l", "shin_r"] {
            shin = body.named(name);
            if shin is not None {
                shin.pitch = 90.0 * math.sin(t * math.pi);
            }
        }
        lift = 0.1 * math.sin(t * math.pi);
    } elif kind == "swim" {
        spine = body.named("spine");
        if spine is not None {
            spine.yaw = swing * 15.0;
        }
        tail2 = body.named("tail");
        if tail2 is not None {
            tail2.yaw = swing * 40.0;
        }
    } elif kind == "crouch" {
        for name in ["thigh_l", "thigh_r"] {
            leg = body.named(name);
            if leg is not None {
                leg.pitch = -70.0;
            }
        }
        for name in ["shin_l", "shin_r"] {
            shin = body.named(name);
            if shin is not None {
                shin.pitch = 110.0;
            }
        }
        lift = -body.stance * 0.4;
    } elif kind == "taunt" {
        arm = body.named("arm_l");
        if arm is not None {
            arm.pitch = -160.0 * math.sin(t * math.pi);
            arm.roll = 180.0 + 20.0 * swing;
        }
    } else {
        # Standing: breathing, a little sway.
        torso = body.named("torso");
        if torso is not None and torso.roll != 0.0 {
            torso.roll = 180.0 + 2.0 * swing;
        }
        lift = 0.01 * swing;
    }
    if body.plan == "flyer" {
        lift += 0.05 * math.sin(t * 6.28);
    }
    return (lift + reach, whole_pitch, whole_roll);
}

glob ARM_SPREAD: float = 14.0,
     HUNCH: float = -12.0;

"""What a creature's name says of how it is made: armoured, helmeted,
horned, spiked, clawed, lumpy (living flesh, not plate), carrying a pack."""
obj Traits {
    has armoured: bool = False,
        helmet: bool = False,
        horns: bool = False,
        spikes: bool = False,
        claws: bool = False,
        lumpy: bool = False,
        pack: bool = False,
        blade: bool = False;
}

def:priv says_any(lower: str, words: list[str]) -> bool {
    for word in words {
        if word in lower {
            return True;
        }
    }
    return False;
}

def traits_of(path: str) -> Traits {
    lower = path.lower();
    made = Traits();
    made.armoured = says_any(lower, ["soldier", "army", "enforcer", "infantry", "gunner", "tank", "gladiator", "medic", "makron", "jorg", "knight", "player", "cyborg", "berserk", "brain", "chick", "bitch"]);
    made.helmet = says_any(lower, ["soldier", "army", "enforcer", "infantry", "gunner", "knight", "medic", "tank", "visor", "grunt", "crash", "major", "razor", "uriel"]);
    made.horns = says_any(lower, ["demon", "fiend", "hknight", "makron", "boss", "jorg", "mutant", "anarki", "xaero"]);
    made.spikes = says_any(lower, ["berserk", "hknight", "gladiator", "tank", "makron", "razor"]);
    made.claws = says_any(lower, ["shambler", "demon", "fiend", "mutant", "parasite", "dog"]);
    made.lumpy = says_any(lower, ["ogre", "shambler", "zombie", "demon", "fiend", "mutant", "tarbaby", "oldone", "dog", "fish", "wizard", "shalrath", "parasite", "brain", "boss"]);
    made.blade = says_any(lower, ["knight", "ogre", "berserk", "hknight"]);
    made.pack = says_any(lower, ["soldier", "army", "infantry", "gunner", "medic", "enforcer"]);
    return made;
}

"""A place on a bone at rest: `f` of the way along it, `ahead` forward of
it and `side` to its side."""
def:priv on_bone(b: Bone, f: float, ahead: float = 0.0, side: float = 0.0) -> Vec3 {
    return b.world.place(Vec3(x=ahead, y=side, z=-f * b.length));
}

"""A bone's flesh along it: a tapered capsule."""
def:priv limb(b: Bone, r1: float, r2: float, material: str, blend: float, f0: float = 0.0, f1: float = 1.0) -> Prim {
    return Prim(kind="capsule", at=on_bone(b, f0), to=on_bone(b, f1), r1=r1, r2=r2, material=material, blend=blend);
}

"""A lump on a bone: an ellipsoid with the bone's axes (`rx` forward, `ry`
across, `rz` along it)."""
def:priv lump(b: Bone, f: float, ahead: float, side: float, rx: float, ry: float, rz: float, material: str, blend: float) -> Prim {
    return Prim(kind="ellipsoid", at=on_bone(b, f, ahead, side), x=b.world.x, y=b.world.y, z=b.world.z, size=Vec3(x=rx, y=ry, z=rz), material=material, blend=blend);
}

"""A plate on a bone: a rounded box with the bone's axes."""
def:priv slab(b: Bone, f: float, ahead: float, side: float, hx: float, hy: float, hz: float, round: float, material: str, blend: float) -> Prim {
    return Prim(kind="box", at=on_bone(b, f, ahead, side), x=b.world.x, y=b.world.y, z=b.world.z, size=Vec3(x=hx, y=hy, z=hz), round=round, material=material, blend=blend);
}

"""A horn, spike or claw: a capsule tapering to a point."""
def:priv point_from(start: Vec3, end: Vec3, r: float, material: str) -> Prim {
    return Prim(kind="capsule", at=start, to=end, r1=r, r2=r * 0.12, material=material, blend=r * 0.6);
}

"""Dress a body at rest: every bone `Wears` its solids, by the body's plan
and its name's traits. The body's bones must stand where the rest pose
puts them."""
def dress(body: Body, path: str, seed: int, armed: bool) {
    t = traits_of(path);
    bones = body.bones();
    skin = bones[0].material;
    armour = "steel";
    for b in bones {
        if b.name == "torso" or b.name == "arm_l" {
            armour = b.material;
        }
    }
    flesh = "flesh" if t.lumpy and skin in ["darksteel", "brass", "steel"] else skin;
    bumps = 0.012 if t.lumpy else 0.0;
    bulk = 1.0 + (0.6 if body.plan == "brute" else 0.0) + (1.0 if body.plan == "giant" else 0.0);
    named: dict[str, Bone] = {};
    for b in bones {
        named[b.name] = b;
    }
    worn: list[tuple[Bone, Prim]] = [];
    if body.plan in ["biped", "brute", "giant", "flyer"] and "torso" in named {
        torso = named["torso"];
        worn.append((torso, lump(torso, 0.04, 0.0, 0.0, 0.1 * bulk, 0.15 * bulk, 0.09, armour if t.armoured else flesh, 0.05)));
        worn.append((torso, limb(torso, 0.1 * bulk, 0.115 * bulk, flesh, 0.035, 0.0, 0.55)));
        # A brute is broad, but not so broad its arms vanish into it.
        broad = 1.0 + (bulk - 1.0) * 0.45;
        chest = lump(torso, 0.7, 0.012, 0.0, 0.12 * broad, 0.2 * broad, 0.13 * broad, armour if t.armoured else flesh, 0.035);
        worn.append((torso, chest));
        if not t.armoured {
            for side in [-1.0, 1.0] {
                worn.append((torso, lump(torso, 0.74, 0.08 * bulk, side * 0.075 * bulk, 0.05 * bulk, 0.08 * bulk, 0.065 * bulk, flesh, 0.04)));
            }
        } else {
            worn.append((torso, slab(torso, 0.7, -0.1 * bulk, 0.0, 0.035, 0.17 * bulk, 0.14 * bulk, 0.03, "darksteel", 0.03)));
            worn.append((torso, slab(torso, 0.74, 0.11 * bulk, 0.0, 0.025, 0.12 * bulk, 0.1 * bulk, 0.025, armour, 0.025)));
        }
        belt = Prim(kind="ring", at=on_bone(torso, 0.12), x=torso.world.x, y=torso.world.y, z=torso.world.z, size=Vec3(x=0.12 * bulk, y=0.024), material="leather", blend=0.02);
        worn.append((torso, belt));
        if t.pack {
            worn.append((torso, slab(torso, 0.62, -0.17 * bulk, 0.0, 0.06, 0.12 * bulk, 0.13, 0.03, "darksteel", 0.03)));
        }
        if t.spikes {
            for side in [-1.0, 1.0] {
                base = on_bone(torso, 0.9, -0.02, side * 0.18 * bulk);
                worn.append((torso, point_from(base, on_bone(torso, 1.15, -0.06, side * 0.3 * bulk), 0.035 * bulk, "bone")));
            }
        }
        if "head" in named {
            head = named["head"];
            worn.append((torso, limb(torso, 0.055 * bulk, 0.05 * bulk, flesh, 0.04, 0.9, 1.05)));
            worn.append((head, lump(head, 0.5, 0.0, 0.0, 0.095, 0.085, 0.11, flesh, 0.03)));
            worn.append((head, lump(head, 0.25, 0.035, 0.0, 0.06, 0.07, 0.05, flesh, 0.03)));
            if t.helmet {
                worn.append((head, lump(head, 0.62, -0.005, 0.0, 0.112, 0.102, 0.1, armour, 0.02)));
                worn.append((head, slab(head, 0.52, 0.09, 0.0, 0.02, 0.075, 0.03, 0.012, "darksteel", 0.01)));
                worn.append((head, slab(head, 0.53, 0.105, 0.0, 0.008, 0.06, 0.006, 0.003, "glow", 0.004)));
            } else {
                # A face: eyes under a heavy brow, a nose, cheekbones, ears.
                for side in [-1.0, 1.0] {
                    worn.append((head, lump(head, 0.55, 0.085, side * 0.035, 0.016, 0.016, 0.014, "glow", 0.005)));
                    worn.append((head, lump(head, 0.42, 0.07, side * 0.05, 0.03, 0.03, 0.025, flesh, 0.015)));
                    worn.append((head, lump(head, 0.5, -0.005, side * 0.088, 0.022, 0.014, 0.032, flesh, 0.012)));
                }
                worn.append((head, lump(head, 0.63, 0.08, 0.0, 0.028, 0.082, 0.02, flesh, 0.015)));
                worn.append((head, Prim(kind="capsule", at=on_bone(head, 0.55, 0.088), to=on_bone(head, 0.43, 0.112), r1=0.014, r2=0.017, material=flesh, blend=0.012)));
            }
            if t.horns {
                for side in [-1.0, 1.0] {
                    worn.append((head, point_from(on_bone(head, 0.75, 0.0, side * 0.06), on_bone(head, 1.4, -0.07, side * 0.16), 0.032, "bone")));
                }
            }
        }
        for side_name in ["l", "r"] {
            if ("arm_" + side_name) not in named {
                continue;
            }
            arm = named["arm_" + side_name];
            fore = named["fore_" + side_name];
            worn.append((arm, lump(arm, 0.08, 0.0, 0.0, 0.085 * bulk, 0.085 * bulk, 0.075 * bulk, armour if t.armoured else flesh, 0.04)));
            if t.armoured {
                worn.append((arm, slab(arm, 0.02, 0.0, 0.0, 0.1 * bulk, 0.09 * bulk, 0.03, 0.02, armour, 0.02)));
            }
            worn.append((arm, limb(arm, 0.06 * bulk, 0.05 * bulk, flesh, 0.04)));
            worn.append((arm, lump(arm, 0.45, 0.025, 0.0, 0.05 * bulk, 0.05 * bulk, 0.09 * bulk, flesh, 0.03)));
            worn.append((fore, limb(fore, 0.05 * bulk, 0.04 * bulk, flesh, 0.035)));
            if t.armoured {
                worn.append((fore, lump(fore, 0.55, 0.0, 0.0, 0.058 * bulk, 0.058 * bulk, 0.1 * bulk, armour, 0.025)));
            }
            worn.append((fore, lump(fore, 1.05, 0.01, 0.0, 0.042 * bulk, 0.036 * bulk, 0.055 * bulk, "leather" if t.armoured else flesh, 0.025)));
            if t.claws {
                for k in [-1.0, 0.0, 1.0] {
                    worn.append((fore, point_from(on_bone(fore, 1.1, 0.02, k * 0.022 * bulk), on_bone(fore, 1.35, 0.08, k * 0.035 * bulk), 0.014 * bulk, "bone")));
                }
            }
            if side_name == "r" and t.blade {
                # A blade held forward and up from the fist.
                worn.append((fore, slab(fore, 1.05, 0.06, 0.0, 0.03, 0.03, 0.04, 0.01, "darksteel", 0.01)));
                blade = slab(fore, 1.05, 0.32, 0.0, 0.26, 0.012, 0.035, 0.006, "steel", 0.006);
                worn.append((fore, blade));
            }
            if armed and side_name == "r" {
                worn.append((fore, slab(fore, 1.05, 0.16, 0.0, 0.17, 0.03, 0.04, 0.012, "darksteel", 0.012)));
                worn.append((fore, Prim(kind="capsule", at=on_bone(fore, 1.05, 0.3, 0.0), to=on_bone(fore, 1.05, 0.52, 0.0), r1=0.022, r2=0.02, material="steel", blend=0.01)));
            }
        }
        for side_name in ["l", "r"] {
            if ("thigh_" + side_name) not in named {
                continue;
            }
            thigh = named["thigh_" + side_name];
            shin = named["shin_" + side_name];
            worn.append((thigh, limb(thigh, 0.085 * bulk, 0.064 * bulk, armour if t.armoured else flesh, 0.05)));
            worn.append((thigh, lump(thigh, 0.4, 0.02, 0.0, 0.07 * bulk, 0.068 * bulk, 0.12, flesh if not t.armoured else armour, 0.04)));
            worn.append((shin, lump(shin, 0.03, 0.035, 0.0, 0.05, 0.05, 0.05, armour if t.armoured else flesh, 0.02)));
            worn.append((shin, limb(shin, 0.06 * bulk, 0.045 * bulk, flesh, 0.035)));
            worn.append((shin, slab(shin, 0.97, 0.045, 0.0, 0.085 * bulk, 0.045 * bulk, 0.045, 0.02, "darksteel" if t.armoured else flesh, 0.03)));
        }
        if body.plan == "flyer" {
            for side_name in ["l", "r"] {
                if ("wing_" + side_name) in named {
                    wing = named["wing_" + side_name];
                    worn.append((wing, slab(wing, 0.5, 0.0, 0.0, 0.14, 0.008, wing.length * 0.5, 0.006, "leather", 0.02)));
                    worn.append((wing, limb(wing, 0.025, 0.008, "bone", 0.015)));
                }
            }
        }
    } elif body.plan == "quadruped" and "spine" in named {
        spine = named["spine"];
        worn.append((spine, lump(spine, 0.45, 0.0, 0.0, 0.1, 0.09, 0.3, flesh, 0.04)));
        worn.append((spine, lump(spine, 0.8, 0.03, 0.0, 0.13, 0.1, 0.15, flesh, 0.04)));
        worn.append((spine, lump(spine, 0.12, 0.0, 0.0, 0.09, 0.085, 0.1, flesh, 0.035)));
        if "head" in named {
            head = named["head"];
            worn.append((head, lump(head, 0.3, 0.0, 0.0, 0.085, 0.075, 0.085, flesh, 0.03)));
            worn.append((head, limb(head, 0.055, 0.03, flesh, 0.02, 0.4, 1.3)));
            worn.append((head, limb(head, 0.035, 0.02, flesh, 0.015, 0.5, 1.2)));
            for side in [-1.0, 1.0] {
                worn.append((head, point_from(on_bone(head, 0.2, -0.04, side * 0.05), on_bone(head, 0.0, -0.12, side * 0.1), 0.03, flesh)));
                worn.append((head, lump(head, 0.55, 0.06, side * 0.04, 0.012, 0.012, 0.012, "glow", 0.004)));
            }
        }
        for b in bones {
            if b.name.startswith("leg_") {
                worn.append((b, limb(b, 0.035, 0.02, flesh, 0.02)));
                worn.append((b, lump(b, 0.25, 0.02, 0.0, 0.045, 0.035, 0.09, flesh, 0.02)));
                worn.append((b, lump(b, 1.02, 0.025, 0.0, 0.035, 0.028, 0.02, flesh, 0.012)));
                if t.claws {
                    worn.append((b, point_from(on_bone(b, 1.02, 0.06, 0.0), on_bone(b, 1.08, 0.12, 0.0), 0.012, "bone")));
                }
            } elif b.name == "tail" {
                worn.append((b, limb(b, 0.04, 0.012, flesh, 0.03)));
            }
        }
    } elif body.plan == "fish" and "spine" in named {
        spine = named["spine"];
        worn.append((spine, lump(spine, 0.45, 0.0, 0.0, 0.16, 0.08, 0.4, flesh, 0.05)));
        worn.append((spine, slab(spine, 0.45, 0.16, 0.0, 0.08, 0.008, 0.18, 0.006, flesh, 0.03)));
        if "head" in named {
            head = named["head"];
            worn.append((head, lump(head, 0.4, 0.0, 0.0, 0.13, 0.08, 0.15, flesh, 0.05)));
            worn.append((head, slab(head, 0.9, -0.03, 0.0, 0.03, 0.06, 0.02, 0.01, "bone", 0.01)));
        }
        if "tail" in named {
            tail = named["tail"];
            worn.append((tail, slab(tail, 0.7, 0.0, 0.0, 0.14, 0.008, 0.1, 0.006, flesh, 0.03)));
        }
    } else {
        hips = bones[0];
        worn.append((hips, lump(hips, 0.5, 0.0, 0.0, 0.42 * (0.6 + body.size), 0.4 * (0.6 + body.size), 0.38 * (0.6 + body.size), flesh, 0.1)));
        for b in bones[1:] {
            worn.append((b, limb(b, 0.08, 0.02, flesh, 0.06)));
        }
        bumps = max(bumps, 0.03);
    }
    for (b, prim) in worn {
        if prim.material in ["flesh", "green", "leather", "stone"] {
            prim.bumps = bumps;
        }
        b +>:Wears:+> prim;
    }
}

"""A body's mesh carried by its bones: each point at rest, the two bones
that hold it most and how much, and where it sits in each one's frame at
rest, so it can be posed with them."""
obj Skin {
    has shaper: Shaper,
        holders: list[Bone] = [],
        firsts: list[int] = [],
        seconds: list[int] = [],
        shares: list[float] = [],
        first_places: list[Vec3] = [],
        second_places: list[Vec3] = [];

    """Its points at the bones' present pose."""
    def posed -> list[Vec3] {
        made: list[Vec3] = [];
        for k in range(len(self.firsts)) {
            a = self.holders[self.firsts[k]].world.place(self.first_places[k]);
            b = self.holders[self.seconds[k]].world.place(self.second_places[k]);
            made.append(a.lerp(b, 1.0 - self.shares[k]));
        }
        return made;
    }
}

"""The skin of a dressed body at rest, its points those of the bones in
`names` (all of them when empty), at most `budget` of them."""
def skin_of(body: Body, names: list[str], budget: int, seed: int) -> Skin {
    sculpture = Sculpture(seed=seed);
    owners: list[Bone] = [];
    for b in body.bones() {
        if names and b.name not in names {
            continue;
        }
        for prim in [b->:Wears:->] {
            if isinstance(prim, Prim) {
                prim.owner = len(owners);
                owners.append(b);
                sculpture.prims.append(prim);
            }
        }
    }
    if not sculpture.prims {
        empty = Shaper();
        empty.ball(Frame(), Vec3(x=0.01, y=0.01, z=0.01), 2, 3, tile_of("rubber"));
        made_empty = Skin(shaper=empty, holders=body.bones()[:1]);
        for k in range(len(empty.points)) {
            made_empty.firsts.append(0);
            made_empty.seconds.append(0);
            made_empty.shares.append(1.0);
            made_empty.first_places.append(in_frame([empty.points[k]], made_empty.holders[0].world)[0]);
            made_empty.second_places.append(made_empty.first_places[-1]);
        }
        return made_empty;
    }
    # Where materials meet a point is made once for each, so the mesh is
    # sampled more coarsely until the whole still fits.
    sculpted = sculpture.mesh(budget, 46);
    (shaper, sources) = sculpt_shaper(sculpted);
    tries = budget;
    while len(shaper.points) > budget and tries > 200 {
        tries = int(float(tries) * 0.85);
        sculpted = sculpture.mesh(tries, 46);
        (shaper, sources) = sculpt_shaper(sculpted);
    }
    made = Skin(shaper=shaper, holders=owners);
    for (k, source) in enumerate(sources) {
        first = sculpted.holders[source * 2];
        second = sculpted.holders[source * 2 + 1];
        made.firsts.append(first);
        made.seconds.append(second);
        made.shares.append(sculpted.shares[source * 2]);
        point = shaper.points[k];
        made.first_places.append(in_frame([point], owners[first].world)[0]);
        made.second_places.append(in_frame([point], owners[second].world)[0]);
    }
    return made;
}

"""How many points a model of `kind` may have (Quake's 1024, Quake II's
2048, about a thousand a Quake III surface), room left for its other
surfaces' tokens."""
def point_budget(kind: str) -> int {
    if kind == "mdl" {
        return 990;
    }
    if kind == "md2" {
        return 1600;
    }
    return 990;
}

"""Whether a character carries a gun in its hands."""
def armed_kind(path: str) -> bool {
    lower = path.lower();
    for word in ["soldier", "army", "enforcer", "infantry", "gunner", "player", "male", "female", "cyborg", "tank", "makron", "jorg", "chick", "bitch", "medic"] {
        if word in lower {
            return True;
        }
    }
    return False;
}

"""Points scaled and moved so the body's rest pose fills the original's
first frame: as tall as it, its feet on its floor, centred on it."""
def fit_to(points: list[Vec3], rest_low: Vec3, rest_high: Vec3, low: Vec3, high: Vec3) -> list[Vec3] {
    height = max(1.0e-4, rest_high.z - rest_low.z);
    scale = (high.z - low.z) / height;
    # Each way across as far as the original's box reaches, but never
    # more than 1.8 times (or less than 0.6 of) the height's scale: a
    # weapon held out at arm's length should not stretch the body.
    sx = max(scale * 0.6, min(scale * 1.8, (high.x - low.x) / max(1.0e-4, rest_high.x - rest_low.x)));
    sy = max(scale * 0.6, min(scale * 1.8, (high.y - low.y) / max(1.0e-4, rest_high.y - rest_low.y)));
    rest_mid = rest_low.add(rest_high).scale(0.5);
    mid = low.add(high).scale(0.5);
    return [
        Vec3(x=mid.x + (p.x - rest_mid.x) * sx, y=mid.y + (p.y - rest_mid.y) * sy, z=low.z + (p.z - rest_low.z) * scale)
        for p in points
    ];
}

def:priv bounds_of(points: list[Vec3]) -> tuple[Vec3, Vec3] {
    low = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
    high = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
    for p in points {
        low = Vec3(x=min(low.x, p.x), y=min(low.y, p.y), z=min(low.z, p.z));
        high = Vec3(x=max(high.x, p.x), y=max(high.y, p.y), z=max(high.z, p.z));
    }
    return (low, high);
}

"""A character model (Quake's or Quake II's, one piece) as a document: a pose
for each of the original's frames, by its name, fitted into the original's
first frame. `first_low`/`first_high` are that frame's box."""
def character_doc(path: str, facts: ModelFacts, first_low: Vec3, first_high: Vec3) -> ModelDoc | None {
    seed = hash_label(14, path.lower());
    body = build_body(path, seed);
    armed = armed_kind(path);
    (lift0, pitch0, roll0) = pose_bones(body, "stand", 0.0, seed);
    body.hips spawn PoseWalk(root_at=Vec3(z=body.stance + lift0), whole_pitch=pitch0, whole_roll=roll0);
    dress(body, path, seed, armed);
    skin = skin_of(body, [], point_budget(facts.kind), seed);
    rest = skin.shaper;
    (rest_low, rest_high) = bounds_of(rest.points);
    doc = ModelDoc(name=path);
    surfaces = facts.surfaces if facts.surfaces else ["model"];
    part = Part(name=surfaces[0], corners=list(rest.corners), uvs=list(rest.uvs), skins=list(facts.surface_skins[0]) if facts.surface_skins else []);
    doc +>:HasPart(index=0):+> part;
    actions = actions_of(facts.frame_names);
    for frame in range(len(facts.frame_names)) {
        (stem, t) = actions[frame];
        (lift, whole_pitch, whole_roll) = pose_bones(body, action_kind(stem), t, seed);
        body.hips spawn PoseWalk(root_at=Vec3(z=body.stance + lift), whole_pitch=whole_pitch, whole_roll=whole_roll);
        part +>:HasPose(index=frame):+> Pose(
            name=facts.frame_names[frame], points=fit_to(skin.posed(), rest_low, rest_high, first_low, first_high)
        );
    }
    # Any further surfaces keep their names with a token piece each.
    for k in range(1, len(surfaces)) {
        token = Shaper();
        token.ball(Frame(), Vec3(x=0.01, y=0.01, z=0.01), 2, 3, tile_of("rubber"));
        extra = Part(name=surfaces[k], corners=list(token.corners), uvs=list(token.uvs), skins=list(facts.surface_skins[k]) if k < len(facts.surface_skins) else []);
        doc +>:HasPart(index=k):+> extra;
        for frame in range(len(facts.frame_names)) {
            extra +>:HasPose(index=frame):+> Pose(name=facts.frame_names[frame], points=fit_to(token.points, rest_low, rest_high, first_low, first_high));
        }
    }
    return doc;
}

# The animations of a Quake III player's animation.cfg, in its order
# (bg_public.h animNumber_t).
glob Q3_ANIMATIONS: list[str] = [
    "BOTH_DEATH1", "BOTH_DEAD1", "BOTH_DEATH2", "BOTH_DEAD2", "BOTH_DEATH3", "BOTH_DEAD3", "TORSO_GESTURE",
    "TORSO_ATTACK", "TORSO_ATTACK2", "TORSO_DROP", "TORSO_RAISE", "TORSO_STAND", "TORSO_STAND2", "LEGS_WALKCR",
    "LEGS_WALK", "LEGS_RUN", "LEGS_BACK", "LEGS_SWIM", "LEGS_JUMP", "LEGS_LAND", "LEGS_JUMPB", "LEGS_LANDB",
    "LEGS_IDLE", "LEGS_IDLECR", "LEGS_TURN"
];

"""The frame ranges of an animation.cfg: (first, count) for each animation
in order."""
def animation_ranges(text: str) -> list[tuple[int, int]] {
    ranges: list[tuple[int, int]] = [];
    for raw in text.replace("\r", "\n").split("\n") {
        line = raw.strip();
        cut = line.find("//");
        if cut >= 0 {
            line = line[:cut].strip();
        }
        words = line.split();
        if len(words) >= 2 and words[0].lstrip("-").isdigit() and words[1].lstrip("-").isdigit() {
            ranges.append((int(words[0]), int(words[1])));
        }
    }
    return ranges;
}

"""The body action and its progress for frame `frame` of a player's `part`
("lower" or "upper"), from its animation ranges; legs' frames are
numbered after the both-part ones, as cg_players.c CG_ParseAnimationFile
renumbers them."""
def q3_action(ranges: list[tuple[int, int]], part: str, frame: int) -> tuple[str, float] {
    if len(ranges) < len(Q3_ANIMATIONS) {
        return ("stand", 0.0);
    }
    shift_legs = ranges[13][0] - ranges[6][0];
    for k in range(len(Q3_ANIMATIONS)) {
        name = Q3_ANIMATIONS[k];
        if part == "lower" and name.startswith("TORSO") {
            continue;
        }
        if part == "upper" and name.startswith("LEGS") {
            continue;
        }
        (first, count) = ranges[k];
        if name.startswith("LEGS") {
            first -= shift_legs;
        }
        if frame >= first and frame < first + max(1, count) {
            t = float(frame - first) / float(max(1, count - 1)) if count > 1 else 0.0;
            if "DEAD" in name {
                return ("death", 1.0);
            }
            word = name.split("_", 1)[1].lower();
            kinds = {
                "death1": "death", "death2": "death", "death3": "death", "gesture": "taunt", "attack": "attack",
                "attack2": "attack", "drop": "pain", "raise": "pain", "stand": "stand", "stand2": "stand",
                "walkcr": "crouch", "walk": "walk", "run": "run", "back": "walk", "swim": "swim", "jump": "jump",
                "land": "jump", "jumpb": "jump", "landb": "jump", "idle": "stand", "idlecr": "crouch", "turn": "walk"
            };
            return (kinds.get(word, "stand"), t);
        }
    }
    return ("stand", 0.0);
}

"""Points in world space as seen from a tag's frame."""
def in_frame(points: list[Vec3], frame: Frame) -> list[Vec3] {
    made: list[Vec3] = [];
    for p in points {
        d = p.sub(frame.at);
        made.append(Vec3(x=d.dot(frame.x), y=d.dot(frame.y), z=d.dot(frame.z)));
    }
    return made;
}

glob LEGS_BONES: list[str] = ["thigh_l", "thigh_r", "shin_l", "shin_r"],
     TORSO_BONES: list[str] = ["torso", "arm_l", "arm_r", "fore_l", "fore_r"],
     HEAD_BONES: list[str] = ["head"];

"""One part of a Quake III player ("lower", "upper" or "head") as a document:
a pose at each frame from its animation, its tags (tag_torso on the legs;
tag_head and tag_weapon on the torso) where the skeleton puts them, each
part's points in the frame of the tag it hangs from, all scaled so the legs
stand as tall as the original's (`legs_low`/`legs_high`, the legs' first
frame)."""
def player_part_doc(path: str, part_name: str, facts: ModelFacts, ranges: list[tuple[int, int]], legs_low: Vec3, legs_high: Vec3) -> ModelDoc {
    character = path.lower().rsplit("/", 1)[0];
    seed = hash_label(15, character);
    body = build_body(character + "/player", seed);
    # The scale: the rest pose's hips over its feet to the original legs.
    body.hips spawn PoseWalk(root_at=Vec3(z=body.stance));
    scale = (legs_high.z - legs_low.z) / max(0.05, body.stance + 0.1);
    floor = legs_low.z;
    doc = ModelDoc(name=path);
    surfaces = facts.surfaces if facts.surfaces else [part_name];
    names = LEGS_BONES if part_name == "lower" else (TORSO_BONES if part_name == "upper" else HEAD_BONES);
    (lift0, pitch0, roll0) = pose_bones(body, "stand", 0.0, seed);
    body.hips spawn PoseWalk(root_at=Vec3(z=body.stance + lift0), whole_pitch=pitch0, whole_roll=roll0);
    dress(body, character + "/player", seed, False);
    skin = skin_of(body, names, point_budget("md3"), seed);
    shaped: list[list[Vec3]] = [];
    corners: list[int] = [];
    uvs: list[float] = [];
    tag_frames: dict[str, list[Frame]] = {};
    for tag in facts.tags {
        tag_frames[tag] = [];
    }
    for frame in range(max(1, len(facts.frame_names))) {
        (kind, t) = q3_action(ranges, part_name, frame) if part_name != "head" else ("stand", 0.0);
        (lift, whole_pitch, whole_roll) = pose_bones(body, kind, t, seed);
        if part_name == "upper" {
            # The torso moves on the legs' tag: its own frame has no lean of the whole.
            whole_pitch = 0.0;
            whole_roll = 0.0;
            lift = 0.0;
        }
        body.hips spawn PoseWalk(root_at=Vec3(z=body.stance + lift), whole_pitch=whole_pitch, whole_roll=whole_roll);
        mesh = skin.shaper;
        hips_frame = body.hips.world;
        torso = body.named("torso");
        head = body.named("head");
        hand = body.named("fore_r");
        points = skin.posed();
        if part_name == "upper" {
            points = in_frame(points, hips_frame);
        } elif part_name == "head" and head is not None {
            # A bone grows down its frame (limbs hang); the head stands up
            # from the neck its tag is at, so it is turned half about its
            # forward axis.
            points = [Vec3(x=p.x, y=-p.y, z=-p.z) for p in in_frame(points, head.world)];
        }
        scaled: list[Vec3] = [];
        for p in points {
            if part_name == "lower" {
                scaled.append(Vec3(x=p.x * scale, y=p.y * scale, z=floor + p.z * scale));
            } else {
                scaled.append(p.scale(scale));
            }
        }
        shaped.append(scaled);
        corners = mesh.corners;
        uvs = mesh.uvs;
        for tag in facts.tags {
            spot = Frame();
            if tag == "tag_torso" {
                spot = Frame(at=Vec3(x=hips_frame.at.x * scale, y=hips_frame.at.y * scale, z=floor + hips_frame.at.z * scale), x=hips_frame.x, y=hips_frame.y, z=hips_frame.z);
            } elif tag == "tag_head" and head is not None and torso is not None {
                local = in_frame([head.world.at], hips_frame)[0].scale(scale);
                spot = Frame(at=local);
            } elif tag == "tag_weapon" and hand is not None {
                tip = hand.world.place(Vec3(z=-hand.length));
                local2 = in_frame([tip], hips_frame)[0].scale(scale);
                spot = Frame(at=local2);
            }
            tag_frames[tag].append(spot);
        }
    }
    part = Part(name=surfaces[0], corners=list(corners), uvs=list(uvs), skins=list(facts.surface_skins[0]) if facts.surface_skins else []);
    doc +>:HasPart(index=0):+> part;
    for frame in range(len(shaped)) {
        name = facts.frame_names[frame] if frame < len(facts.frame_names) else "frame " + str(frame);
        part +>:HasPose(index=frame):+> Pose(name=name, points=shaped[frame]);
    }
    for k in range(1, len(surfaces)) {
        token = Shaper();
        token.ball(Frame(), Vec3(x=0.01, y=0.01, z=0.01), 2, 3, tile_of("rubber"));
        extra = Part(name=surfaces[k], corners=list(token.corners), uvs=list(token.uvs), skins=list(facts.surface_skins[k]) if k < len(facts.surface_skins) else []);
        doc +>:HasPart(index=k):+> extra;
        for frame in range(len(shaped)) {
            extra +>:HasPose(index=frame):+> Pose(name="", points=list(token.points));
        }
    }
    for tag in facts.tags {
        made = Tag(name=tag);
        made.origins = [f.at for f in tag_frames[tag]];
        made.axes = [[f.x, f.y, f.z] for f in tag_frames[tag]];
        doc +>:HasTag:+> made;
    }
    return doc;
}
