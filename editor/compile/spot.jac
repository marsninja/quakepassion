"""Lights that shine one way: a lamp with a `target` to aim at, or a
`mangle` that says where it points, lights only what lies inside a cone
about that way. `_cone` is half the cone's angle in degrees (20 when it
does not say), as Quake II's and Quake III's light tools have it."""

import math;
import from engine.math.vec3 { Vec3 }

"""Half the angle of a cone that says nothing of itself, in degrees; how
many degrees wide its rim is, where its light falls off; and the least and
the most a cone's half angle may be."""
glob CONE_DEFAULT: float = 20.0,
     CONE_RIM: float = 4.0,
     CONE_LEAST: float = 1.0,
     CONE_MOST: float = 85.0;

"""The way a `mangle` points: its words are yaw, pitch and roll in degrees,
yaw round the upright from x toward y, and pitch up from level (so -90 is
straight down). None when they are not numbers."""
def mangle_aim(words: str) -> Vec3 | None {
    numbers: list[float] = [];
    for word in words.split() {
        try {
            numbers.append(float(word));
        } except ValueError {
            return None;
        }
    }
    if len(numbers) < 2 {
        return None;
    }
    yaw = math.radians(numbers[0]);
    pitch = math.radians(numbers[1]);
    return Vec3(x=math.cos(pitch) * math.cos(yaw), y=math.cos(pitch) * math.sin(yaw), z=math.sin(pitch));
}

"""Half the angle of a light's cone, in degrees, from its fields."""
def cone_half(fields: dict[str, str]) -> float {
    words = fields.get("_cone", "").split();
    if len(words) > 0 {
        try {
            return max(CONE_LEAST, min(CONE_MOST, float(words[0])));
        } except ValueError {
            return CONE_DEFAULT;
        }
    }
    return CONE_DEFAULT;
}

"""A cone of light: the way it points, of unit length, and half its angle
in degrees."""
obj Cone {
    has aim: Vec3 = Vec3(z=-1.0),
        half: float = 20.0;

    """How much of the lamp's light a point gets: 2 for all of it, inside
    the cone; 1 for half, on its rim; 0 for none."""
    def share(origin: Vec3, point: Vec3) -> int {
        away = point.sub(origin);
        far = away.length();
        if far < 0.0001 {
            return 2;
        }
        along = max(-1.0, min(1.0, away.dot(self.aim) / far));
        off = math.degrees(math.acos(along));
        if off <= self.half - CONE_RIM * 0.5 {
            return 2;
        }
        return 1 if off <= self.half + CONE_RIM * 0.5 else 0;
    }
}

"""The cone a light shines in, or None for one that shines every way:
toward its target when it has one that is somewhere (`target_at`), else
the way its `mangle` points."""
def spot_cone(fields: dict[str, str], origin: Vec3, target_at: Vec3 | None) -> Cone | None {
    aim: Vec3 | None = None;
    if target_at is not None and target_at.sub(origin).length() > 0.01 {
        aim = target_at.sub(origin).normalized();
    } elif fields.get("mangle", "") {
        aim = mangle_aim(fields.get("mangle", ""));
    }
    if aim is None {
        return None;
    }
    return Cone(aim=aim, half=cone_half(fields));
}

"""A way square to another: the one nearest `wanted` (the view's right,
say), or any when `wanted` runs along it."""
def square_to(aim: Vec3, wanted: Vec3) -> Vec3 {
    flat = wanted.sub(aim.scale(wanted.dot(aim)));
    if flat.length() < 0.001 {
        other = Vec3(x=1.0) if abs(aim.x) < 0.9 else Vec3(y=1.0);
        flat = other.sub(aim.scale(other.dot(aim)));
    }
    return flat.normalized();
}

"""The rim of a cone `reach` along it from where it begins: `count` points
round the way it points."""
def cone_rim(origin: Vec3, cone: Cone, reach: float, count: int = 16) -> list[Vec3] {
    side = square_to(cone.aim, Vec3(x=1.0));
    over = cone.aim.cross(side);
    wide = reach * math.tan(math.radians(cone.half));
    rim: list[Vec3] = [];
    for index in range(max(3, count)) {
        turn = 2.0 * math.pi * float(index) / float(max(3, count));
        rim.append(origin.add(cone.aim.scale(reach)).add(side.scale(wide * math.cos(turn))).add(over.scale(wide * math.sin(turn))));
    }
    return rim;
}

"""How many degrees off a cone's way a point lies, seen from where the cone
begins: what half its angle would have to be for its edge to pass through
that point."""
def cone_through(origin: Vec3, aim: Vec3, point: Vec3) -> float {
    away = point.sub(origin);
    if away.length() < 0.0001 {
        return CONE_LEAST;
    }
    along = max(-1.0, min(1.0, away.dot(aim) / away.length()));
    return max(CONE_LEAST, min(CONE_MOST, math.degrees(math.acos(along))));
}
