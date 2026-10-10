"""Shapes built of brushes: each fills a box and comes back as convex
brushes, one or many. A cone and a ball are one brush; stairs, an arch and a
pipe are several."""
import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side, Plane3, box_sides, classic_mapping }
import from .csg { hull_sides }

"""Every corner of a shape, a rounding error off the grid put on it."""
def:priv tidy(value: float) -> float {
    nearest = float(round(value * 8.0)) / 8.0;
    return nearest if abs(value - nearest) < 0.0001 else value;
}

def:priv spot(x: float, y: float, z: float) -> Vec3 {
    return Vec3(x=tidy(x), y=tidy(y), z=tidy(z));
}

"""The brush round a set of corners, every side in one material."""
def:priv shell(corners: list[Vec3], material: str) -> list[Side] {
    return hull_sides(corners, [], material);
}

"""A cone standing in a box, its tip over the middle: a pyramid when it has
four sides."""
def cone_brushes(low: Vec3, high: Vec3, count: int = 12, material: str = "") -> list[list[Side]] {
    count = max(3, min(32, count));
    middle = low.add(high).scale(0.5);
    corners: list[Vec3] = [spot(middle.x, middle.y, high.z)];
    for i in range(count) {
        # A pyramid's corners are the box's; a cone's go round its ellipse.
        turn = 2.0 * math.pi * (float(i) + (0.5 if count == 4 else 0.0)) / float(count);
        reach = math.sqrt(2.0) if count == 4 else 1.0;
        corners.append(
            spot(
                middle.x + (high.x - low.x) * 0.5 * reach * math.cos(turn),
                middle.y + (high.y - low.y) * 0.5 * reach * math.sin(turn),
                low.z
            )
        );
    }
    made = shell(corners, material);
    return [made] if made else [];
}

"""A ball filling a box (`dome`: its upper half, standing on the box's
floor), with `count` sides round it."""
def ball_brushes(
    low: Vec3, high: Vec3, count: int = 8, material: str = "", dome: bool = False
) -> list[list[Side]] {
    count = max(4, min(16, count));
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    rings = max(2, count // 2);
    corners: list[Vec3] = [];
    floor = low.z if dome else middle.z;
    tall = (high.z - low.z) if dome else half.z;
    corners.append(spot(middle.x, middle.y, floor + tall));
    if not dome {
        corners.append(spot(middle.x, middle.y, low.z));
    }
    first = 0 if dome else 1 - rings;
    for ring in range(first, rings) {
        lift = (math.pi * 0.5) * float(ring) / float(rings);
        for i in range(count) {
            turn = 2.0 * math.pi * float(i) / float(count);
            corners.append(
                spot(
                    middle.x + half.x * math.cos(lift) * math.cos(turn),
                    middle.y + half.y * math.cos(lift) * math.sin(turn),
                    floor + tall * math.sin(lift)
                )
            );
        }
    }
    made = shell(corners, material);
    return [made] if made else [];
}

"""Straight stairs rising toward +y: `steps` blocks, each a step higher and
a step further, every one standing on the floor."""
def stair_brushes(low: Vec3, high: Vec3, steps: int = 8, material: str = "") -> list[list[Side]] {
    steps = max(1, min(64, steps));
    deep = (high.y - low.y) / float(steps);
    rise = (high.z - low.z) / float(steps);
    made: list[list[Side]] = [];
    for i in range(steps) {
        made.append(
            box_sides(
                spot(low.x, low.y + deep * float(i), low.z),
                spot(high.x, low.y + deep * float(i + 1), low.z + rise * float(i + 1)),
                material
            )
        );
    }
    return made;
}

"""Stairs winding once round the middle of a box: each step a wedge of the
circle, a step higher than the last."""
def spiral_brushes(
    low: Vec3, high: Vec3, steps: int = 12, material: str = "", turns: float = 1.0
) -> list[list[Side]] {
    steps = max(3, min(64, steps));
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    rise = (high.z - low.z) / float(steps);
    made: list[list[Side]] = [];
    for i in range(steps) {
        first = 2.0 * math.pi * turns * float(i) / float(steps);
        second = 2.0 * math.pi * turns * float(i + 1) / float(steps);
        base = low.z + rise * float(i);
        corners: list[Vec3] = [];
        for level in [base, base + rise] {
            corners.append(spot(middle.x, middle.y, level));
            corners.append(spot(middle.x + half.x * math.cos(first), middle.y + half.y * math.sin(first), level));
            corners.append(spot(middle.x + half.x * math.cos(second), middle.y + half.y * math.sin(second), level));
        }
        step = shell(corners, material);
        if step {
            made.append(step);
        }
    }
    return made;
}

"""A ring of `count` blocks between two ellipses `thickness` apart, in the
plane of two axes and as deep as the box along the third: `sweep` of a turn
of it, from `start`."""
def:priv ring_brushes(
    low: Vec3, high: Vec3, count: int, thickness: float, material: str, upright: bool, sweep: float, start: float
) -> list[list[Side]] {
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    # Upright: the ring lies in x/y and is as tall as the box. Otherwise it
    # stands in x/z, as deep as the box along y, from the box's floor.
    wide = half.x;
    tall = half.y if upright else (high.z - low.z);
    thickness = max(1.0, min(thickness, min(wide, tall) - 1.0));
    made: list[list[Side]] = [];
    for i in range(count) {
        corners: list[Vec3] = [];
        for turn in [start + sweep * float(i) / float(count), start + sweep * float(i + 1) / float(count)] {
            for (across, up) in [(wide, tall), (wide - thickness, tall - thickness)] {
                a = across * math.cos(turn);
                b = up * math.sin(turn);
                if upright {
                    corners.append(spot(middle.x + a, middle.y + b, low.z));
                    corners.append(spot(middle.x + a, middle.y + b, high.z));
                } else {
                    corners.append(spot(middle.x + a, low.y, low.z + b));
                    corners.append(spot(middle.x + a, high.y, low.z + b));
                }
            }
        }
        block = shell(corners, material);
        if block {
            made.append(block);
        }
    }
    return made;
}

"""An arch spanning a box along x and as deep as it along y: a half ring of
`count` blocks, `thickness` through."""
def arch_brushes(
    low: Vec3, high: Vec3, count: int = 8, thickness: float = 16.0, material: str = ""
) -> list[list[Side]] {
    return ring_brushes(low, high, max(2, min(32, count)), thickness, material, False, math.pi, 0.0);
}

"""An upright pipe filling a box: a ring of `count` blocks, `thickness`
through, open down the middle."""
def pipe_brushes(
    low: Vec3, high: Vec3, count: int = 12, thickness: float = 16.0, material: str = ""
) -> list[list[Side]] {
    return ring_brushes(low, high, max(3, min(32, count)), thickness, material, True, 2.0 * math.pi, 0.0);
}

"""The kinds `shape_brushes` knows."""
glob SHAPE_KINDS: list[str] = ["cone", "pyramid", "ball", "dome", "stairs", "spiral", "arch", "pipe"];

"""A shape by name filling a box. `count` is its sides or steps (0 takes the
shape's own) and `thickness` an arch's or a pipe's wall."""
def shape_brushes(
    kind: str, low: Vec3, high: Vec3, count: int = 0, thickness: float = 16.0, material: str = ""
) -> list[list[Side]] {
    if kind == "cone" {
        return cone_brushes(low, high, count if count > 0 else 12, material);
    }
    if kind == "pyramid" {
        return cone_brushes(low, high, 4, material);
    }
    if kind == "ball" {
        return ball_brushes(low, high, count if count > 0 else 8, material);
    }
    if kind == "dome" {
        return ball_brushes(low, high, count if count > 0 else 8, material, True);
    }
    if kind == "stairs" {
        return stair_brushes(low, high, count if count > 0 else 8, material);
    }
    if kind == "spiral" {
        return spiral_brushes(low, high, count if count > 0 else 12, material);
    }
    if kind == "arch" {
        return arch_brushes(low, high, count if count > 0 else 8, thickness, material);
    }
    if kind == "pipe" {
        return pipe_brushes(low, high, count if count > 0 else 12, thickness, material);
    }
    return [];
}
