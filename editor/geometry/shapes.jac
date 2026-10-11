"""Shapes built of brushes: each fills a box and comes back as convex
brushes, one or many. A cone and a ball are one brush; stairs, an arch and a
pipe are several."""
import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side, Plane3, box_sides, classic_mapping, brush_windings, brush_holds }
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

"""Two cones base to base in a box: one brush, a point above and below."""
def bicone_brushes(low: Vec3, high: Vec3, count: int = 12, material: str = "") -> list[list[Side]] {
    count = max(3, min(32, count));
    middle = low.add(high).scale(0.5);
    corners: list[Vec3] = [spot(middle.x, middle.y, high.z), spot(middle.x, middle.y, low.z)];
    for i in range(count) {
        turn = 2.0 * math.pi * float(i) / float(count);
        corners.append(
            spot(
                middle.x + (high.x - low.x) * 0.5 * math.cos(turn),
                middle.y + (high.y - low.y) * 0.5 * math.sin(turn),
                middle.z
            )
        );
    }
    made = shell(corners, material);
    return [made] if made else [];
}

"""A ring lying in a box (a torus): `count` blocks round it, each the brush
between two slices of the tube, the tube `thickness` across."""
def torus_brushes(
    low: Vec3, high: Vec3, count: int = 12, thickness: float = 16.0, material: str = ""
) -> list[list[Side]] {
    count = max(4, min(32, count));
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    tube = max(1.0, min(thickness * 0.5, min(min(half.x, half.y) * 0.5 - 0.5, half.z)));
    made: list[list[Side]] = [];
    for i in range(count) {
        corners: list[Vec3] = [];
        for turn in [2.0 * math.pi * float(i) / float(count), 2.0 * math.pi * float(i + 1) / float(count)] {
            # Eight points round the tube's slice at this turn.
            for part in range(8) {
                round_tube = 2.0 * math.pi * float(part) / 8.0;
                out = 1.0 - (tube / max(half.x, 1.0)) * (1.0 - math.cos(round_tube));
                out_y = 1.0 - (tube / max(half.y, 1.0)) * (1.0 - math.cos(round_tube));
                corners.append(
                    spot(
                        middle.x + half.x * out * math.cos(turn),
                        middle.y + half.y * out_y * math.sin(turn),
                        middle.z + min(tube, half.z) * math.sin(round_tube)
                    )
                );
            }
        }
        block = shell(corners, material);
        if block {
            made.append(block);
        }
    }
    return made;
}

"""Thin walls crossed at the middle of a box, as a tree or a bush is faked:
`count` of them, each two units through."""
def xtree_brushes(low: Vec3, high: Vec3, count: int = 2, material: str = "") -> list[list[Side]] {
    count = max(2, min(12, count));
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    made: list[list[Side]] = [];
    for i in range(count) {
        turn = math.pi * float(i) / float(count);
        along = Vec3(x=math.cos(turn), y=math.sin(turn));
        across = Vec3(x=-math.sin(turn), y=math.cos(turn));
        corners: list[Vec3] = [];
        for (run, side) in [(1.0, 1.0), (1.0, -1.0), (-1.0, 1.0), (-1.0, -1.0)] {
            for height in [low.z, high.z] {
                corners.append(
                    spot(
                        middle.x + along.x * half.x * run + across.x * side,
                        middle.y + along.y * half.y * run + across.y * side,
                        height
                    )
                );
            }
        }
        wall = shell(corners, material);
        if wall {
            made.append(wall);
        }
    }
    return made;
}

"""A fan of wedges from a line to an arc, standing in x/z and as deep as
the box along y: `sweep` of a circle, from `start`, about `hub`."""
def:priv fan_brushes(
    low: Vec3, high: Vec3, count: int, material: str, hub_x: float, hub_z: float, reach_x: float, reach_z: float,
    start: float, sweep: float
) -> list[list[Side]] {
    made: list[list[Side]] = [];
    for i in range(count) {
        corners: list[Vec3] = [];
        for deep in [low.y, high.y] {
            corners.append(spot(hub_x, deep, hub_z));
            for turn in [start + sweep * float(i) / float(count), start + sweep * float(i + 1) / float(count)] {
                corners.append(spot(hub_x + reach_x * math.cos(turn), deep, hub_z + reach_z * math.sin(turn)));
            }
        }
        wedge = shell(corners, material);
        if wedge {
            made.append(wedge);
        }
    }
    return made;
}

"""A cap: the half disc an arch leaves open, filled, in `count` wedges."""
def cap_brushes(low: Vec3, high: Vec3, count: int = 8, material: str = "") -> list[list[Side]] {
    middle = low.add(high).scale(0.5);
    return fan_brushes(
        low, high, max(2, min(32, count)), material, middle.x, low.z, (high.x - low.x) * 0.5, high.z - low.z, 0.0, math.pi
    );
}

"""A rounded corner: a quarter disc standing in the box's low corner, in
`count` wedges (one wedge is a bevel)."""
def corner_brushes(low: Vec3, high: Vec3, count: int = 6, material: str = "") -> list[list[Side]] {
    return fan_brushes(
        low, high, max(1, min(32, count)), material, low.x, low.z, high.x - low.x, high.z - low.z, 0.0, math.pi * 0.5
    );
}

"""A column: a shaft of `count` sides between a foot and a head as wide as
the box, each an eighth of its height."""
def column_brushes(low: Vec3, high: Vec3, count: int = 8, material: str = "") -> list[list[Side]] {
    count = max(3, min(32, count));
    tall = high.z - low.z;
    foot = max(1.0, tall / 8.0);
    middle = low.add(high).scale(0.5);
    half = high.sub(low).scale(0.5);
    made: list[list[Side]] = [
        box_sides(spot(low.x, low.y, low.z), spot(high.x, high.y, low.z + foot), material),
        box_sides(spot(low.x, low.y, high.z - foot), spot(high.x, high.y, high.z), material)
    ];
    corners: list[Vec3] = [];
    for i in range(count) {
        turn = 2.0 * math.pi * float(i) / float(count);
        for height in [low.z + foot, high.z - foot] {
            corners.append(
                spot(middle.x + half.x * 0.75 * math.cos(turn), middle.y + half.y * 0.75 * math.sin(turn), height)
            );
        }
    }
    shaft = shell(corners, material);
    if shaft {
        made.append(shaft);
    }
    return made;
}

"""Stairs that turn back on themselves: up the left half of the box to a
landing across its far end, and back up the right half."""
def landing_brushes(low: Vec3, high: Vec3, steps: int = 8, material: str = "") -> list[list[Side]] {
    steps = max(2, min(64, steps));
    first = steps // 2;
    second = steps - first;
    middle_x = (low.x + high.x) * 0.5;
    # The landing takes the far quarter of the box, at half its height.
    turn_y = high.y - (high.y - low.y) * 0.25;
    half_z = low.z + (high.z - low.z) * 0.5;
    made = stair_brushes(Vec3(x=low.x, y=low.y, z=low.z), Vec3(x=middle_x, y=turn_y, z=half_z), first, material);
    made.append(box_sides(spot(low.x, turn_y, low.z), spot(high.x, high.y, half_z), material));
    # The second flight comes back toward the near end, from the landing up.
    deep = (turn_y - low.y) / float(second);
    rise = (high.z - half_z) / float(second);
    for i in range(second) {
        made.append(
            box_sides(
                spot(middle_x, turn_y - deep * float(i + 1), low.z),
                spot(high.x, turn_y - deep * float(i), half_z + rise * float(i + 1)),
                material
            )
        );
    }
    return made;
}

"""Brushes with the faces another of them covers given a material that is
not drawn: what is inside a shape of several brushes costs nothing."""
def caulked(brushes: list[list[Side]], material: str = "caulk") -> list[list[Side]] {
    outlines = [brush_windings(sides) for sides in brushes];
    result: list[list[Side]] = [];
    for (index, sides) in enumerate(brushes) {
        fresh: list[Side] = [];
        for (which, side) in enumerate(sides) {
            outline = outlines[index][which];
            covered = False;
            if len(outline) >= 3 {
                for (other, cover) in enumerate(brushes) {
                    if other == index or covered {
                        continue;
                    }
                    # Covered: another brush has a side facing this one in the
                    # same plane, and holds every corner of this face.
                    facing = False;
                    for theirs in cover {
                        if theirs.plane.normal.dot(side.plane.normal) < -0.9999
                            and abs(theirs.plane.dist + side.plane.dist) < 0.05 {
                            facing = True;
                        }
                    }
                    if not facing {
                        continue;
                    }
                    held = True;
                    for point in outline {
                        if not brush_holds(cover, point) {
                            held = False;
                        }
                    }
                    covered = held;
                }
            }
            if covered and side.material != material {
                fresh.append(
                    Side(
                        plane=side.plane,
                        points=side.points,
                        material=material,
                        mapping=side.mapping,
                        contents=side.contents,
                        flags=side.flags,
                        value=side.value
                    )
                );
            } else {
                fresh.append(side);
            }
        }
        result.append(fresh);
    }
    return result;
}

"""The kinds `shape_brushes` knows."""
glob SHAPE_KINDS: list[str] = [
    "cone", "pyramid", "ball", "dome", "stairs", "spiral", "arch", "pipe", "bicone", "torus", "xtree", "cap",
    "corner", "bevel", "column", "landing"
];

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
    if kind == "bicone" {
        return bicone_brushes(low, high, count if count > 0 else 12, material);
    }
    if kind == "torus" {
        return torus_brushes(low, high, count if count > 0 else 12, thickness, material);
    }
    if kind == "xtree" {
        return xtree_brushes(low, high, count if count > 0 else 2, material);
    }
    if kind == "cap" {
        return cap_brushes(low, high, count if count > 0 else 8, material);
    }
    if kind == "corner" {
        return corner_brushes(low, high, count if count > 0 else 6, material);
    }
    if kind == "bevel" {
        return corner_brushes(low, high, 1, material);
    }
    if kind == "column" {
        return column_brushes(low, high, count if count > 0 else 8, material);
    }
    if kind == "landing" {
        return landing_brushes(low, high, count if count > 0 else 8, material);
    }
    return [];
}
