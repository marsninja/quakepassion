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
import from .models { ModelFacts, tile_of }

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
    skin = ["flesh", "leather", "green", "darksteel", "brass", "stone"][mix32(seed + 1) % 6];
    armour = ["steel", "darksteel", "leather", "brass", "red", "blue"][mix32(seed + 2) % 6];
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
    torso.pitch = 180.0;
    hips +>:Child:+> torso;
    neck_up = bone("head", Vec3(z=-0.5), 0.2 + 0.03 * bulk, 0.1 + 0.02 * bulk, 0.08, skin);
    torso +>:Child:+> neck_up;
    for (side, sign) in [("l", 1.0), ("r", -1.0)] {
        upper_arm = bone("arm_" + side, Vec3(z=-0.45, y=(0.2 * bulk + 0.04) * sign), 0.28 * (1.0 + 0.3 * (bulk - 1.0)), 0.06 * bulk, 0.05 * bulk, armour);
        upper_arm.pitch = 180.0;
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
    rest: dict[str, float] = {"torso": 180.0, "arm_l": 180.0, "arm_r": 180.0, "spine": -90.0, "head": 0.0};
    for b in body.bones() {
        b.pitch = rest.get(b.name, 0.0);
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
                arm.pitch = 180.0 + swing * amount * 0.7 * sign;
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
            arm_r.pitch = 180.0 - 150.0 * strike;
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
                arm.pitch = 180.0 - 40.0 * jolt;
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
                arm.pitch = 180.0 - 70.0 * ease;
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
            arm.pitch = 180.0 - 160.0 * math.sin(t * math.pi);
            arm.roll = 20.0 * swing;
        }
    } else {
        # Standing: breathing, a little sway.
        torso = body.named("torso");
        if torso is not None {
            torso.roll = 2.0 * swing;
        }
        lift = 0.01 * swing;
    }
    if body.plan == "flyer" {
        lift += 0.05 * math.sin(t * 6.28);
    }
    return (lift + reach, whole_pitch, whole_roll);
}

"""The body's mesh at its current pose: each limb a tapered capsule along its
bone, a gun in a soldier's hands. Each bone's points, at rest, are made in
its own frame, so the same mesh can be posed again."""
def body_mesh(body: Body, lift: float, whole_pitch: float, whole_roll: float, armed: bool) -> Shaper {
    body.hips spawn PoseWalk(root_at=Vec3(z=body.stance + lift), whole_pitch=whole_pitch, whole_roll=whole_roll);
    shaper = Shaper();
    for b in body.bones() {
        if b.length <= 0.0 {
            continue;
        }
        frame = b.world;
        # The limb runs from the joint down the bone's -z.
        flipped = Frame(at=frame.at, x=frame.x, y=frame.y.scale(-1.0), z=frame.z.scale(-1.0));
        segments = 8 if b.name in ["torso", "head", "spine", "hips"] else 6;
        shaper.lathe(
            flipped,
            [(b.radius * 0.6, -b.radius * 0.4), (b.radius, 0.0), (b.tip_radius, b.length), (b.tip_radius * 0.6, b.length + b.tip_radius * 0.4)],
            segments, tile_of(b.material)
        );
        if b.name == "head" {
            # Eyes, glowing.
            for side in [1.0, -1.0] {
                eye = Frame(at=flipped.place(Vec3(x=b.radius * 0.85, y=b.radius * 0.4 * side, z=b.length * 0.45)));
                shaper.ball(eye, Vec3(x=b.radius * 0.18, y=b.radius * 0.18, z=b.radius * 0.18), 3, 4, tile_of("glow"));
            }
        }
        if armed and b.name == "fore_r" {
            hand = flipped.place(Vec3(z=b.length));
            ahead = hand.add(body.hips.world.x.scale(0.45));
            shaper.tube(frame_along(hand, ahead), 0.45, 0.04, 0.035, 6, tile_of("darksteel"));
        }
    }
    return shaper;
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
    rest_mid = rest_low.add(rest_high).scale(0.5);
    mid = low.add(high).scale(0.5);
    return [
        Vec3(x=mid.x + (p.x - rest_mid.x) * scale, y=mid.y + (p.y - rest_mid.y) * scale, z=low.z + (p.z - rest_low.z) * scale)
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
    rest = body_mesh(body, 0.0, 0.0, 0.0, armed);
    (rest_low, rest_high) = bounds_of(rest.points);
    doc = ModelDoc(name=path);
    surfaces = facts.surfaces if facts.surfaces else ["model"];
    part = Part(name=surfaces[0], corners=list(rest.corners), uvs=list(rest.uvs), skins=list(facts.surface_skins[0]) if facts.surface_skins else []);
    doc +>:HasPart(index=0):+> part;
    actions = actions_of(facts.frame_names);
    for frame in range(len(facts.frame_names)) {
        (stem, t) = actions[frame];
        (lift, whole_pitch, whole_roll) = pose_bones(body, action_kind(stem), t, seed);
        posed = body_mesh(body, lift, whole_pitch, whole_roll, armed);
        part +>:HasPose(index=frame):+> Pose(
            name=facts.frame_names[frame], points=fit_to(posed.points, rest_low, rest_high, first_low, first_high)
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

"""Only the bones of a body some of whose names start with one of
`prefixes`, as a mesh at the current pose."""
def part_mesh(body: Body, names: list[str], armed: bool) -> Shaper {
    shaper = Shaper();
    for b in body.bones() {
        if b.length <= 0.0 or b.name not in names {
            continue;
        }
        flipped = Frame(at=b.world.at, x=b.world.x, y=b.world.y.scale(-1.0), z=b.world.z.scale(-1.0));
        shaper.lathe(
            flipped,
            [(b.radius * 0.6, -b.radius * 0.4), (b.radius, 0.0), (b.tip_radius, b.length), (b.tip_radius * 0.6, b.length + b.tip_radius * 0.4)],
            8 if b.name in ["torso", "head"] else 6, tile_of(b.material)
        );
        if b.name == "head" {
            for side in [1.0, -1.0] {
                eye = Frame(at=flipped.place(Vec3(x=b.radius * 0.85, y=b.radius * 0.4 * side, z=b.length * 0.45)));
                shaper.ball(eye, Vec3(x=b.radius * 0.18, y=b.radius * 0.18, z=b.radius * 0.18), 3, 4, tile_of("glow"));
            }
        }
    }
    return shaper;
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
        mesh = part_mesh(body, names, False);
        hips_frame = body.hips.world;
        torso = body.named("torso");
        head = body.named("head");
        hand = body.named("fore_r");
        points = mesh.points;
        if part_name == "upper" {
            points = in_frame(points, hips_frame);
        } elif part_name == "head" and head is not None {
            points = in_frame(points, head.world);
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
