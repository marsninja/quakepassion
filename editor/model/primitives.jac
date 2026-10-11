"""Meshes made from nothing, each filling a box: a ball, a dome, a cone, a
double cone, a cylinder, a flat fan and a ring. Every one is closed and
faces outward, but the fan, which is one sheet seen from above."""
import math;
import from engine.math.vec3 { Vec3 }
import from .mesh { Mesh }

"""The kinds there are."""
glob PRIMITIVE_KINDS: list[str] = ["sphere", "dome", "cone", "bicone", "cylinder", "fan", "torus"];

"""A ring of `count` points round an ellipse in a box, at a height, drawn in
by `share` (1 for the box's own width). Answers the first point's index."""
def:priv ring(made: Mesh, low: Vec3, high: Vec3, count: int, height: float, share: float, down: float) -> int {
    first = len(made.points);
    middle = low.add(high).scale(0.5);
    for i in range(count) {
        turn = 2.0 * math.pi * float(i) / float(count);
        made.points.append(
            Vec3(
                x=middle.x + (high.x - low.x) * 0.5 * share * math.cos(turn),
                y=middle.y + (high.y - low.y) * 0.5 * share * math.sin(turn),
                z=height
            )
        );
        made.uvs.append(float(i) / float(count));
        made.uvs.append(down);
    }
    return first;
}

"""A point of its own (a pole, the middle of a cap). Answers its index."""
def:priv single(made: Mesh, at: Vec3, across: float, down: float) -> int {
    made.points.append(at);
    made.uvs.append(across);
    made.uvs.append(down);
    return len(made.points) - 1;
}

"""Triangles between two rings of `count` points, the first the lower."""
def:priv band(made: Mesh, lower: int, upper: int, count: int) {
    for i in range(count) {
        j = (i + 1) % count;
        made.corners.extend([lower + i, lower + j, upper + j, lower + i, upper + j, upper + i]);
    }
}

"""Triangles from a ring to one point: above it (`up`), or below."""
def:priv cap(made: Mesh, around: int, tip: int, count: int, up: bool) {
    for i in range(count) {
        j = (i + 1) % count;
        if up {
            made.corners.extend([around + i, around + j, tip]);
        } else {
            made.corners.extend([around + j, around + i, tip]);
        }
    }
}

"""A mesh of a kind filling a box. `count` is how many sides it has round
it; `tube` how many round a ring's own thickness. An empty mesh for a kind
there is not."""
def primitive_mesh(kind: str, low: Vec3, high: Vec3, count: int = 12, tube: int = 6) -> Mesh {
    made = Mesh();
    count = max(3, min(48, count));
    middle = low.add(high).scale(0.5);
    top = Vec3(x=middle.x, y=middle.y, z=high.z);
    foot = Vec3(x=middle.x, y=middle.y, z=low.z);
    if kind == "cone" or kind == "bicone" {
        around = ring(made, low, high, count, low.z if kind == "cone" else middle.z, 1.0, 0.5);
        cap(made, around, single(made, top, 0.5, 0.0), count, True);
        cap(made, around, single(made, foot, 0.5, 1.0), count, False);
    } elif kind == "cylinder" {
        lower = ring(made, low, high, count, low.z, 1.0, 1.0);
        upper = ring(made, low, high, count, high.z, 1.0, 0.0);
        band(made, lower, upper, count);
        cap(made, upper, single(made, top, 0.5, 0.0), count, True);
        cap(made, lower, single(made, foot, 0.5, 1.0), count, False);
    } elif kind == "fan" {
        around = ring(made, low, high, count, middle.z, 1.0, 1.0);
        cap(made, around, single(made, middle, 0.5, 0.0), count, True);
    } elif kind == "sphere" or kind == "dome" {
        # Rings from the bottom (or the middle, for a dome) up to the pole.
        whole = kind == "sphere";
        rows = max(2, count // 2) if whole else max(1, count // 4);
        base_z = middle.z if whole else low.z;
        rise = (high.z - low.z) * 0.5 if whole else high.z - low.z;
        rings: list[int] = [];
        for row in range(1 if whole else 0, rows) {
            lift = -0.5 * math.pi + math.pi * float(row) / float(rows) if whole else 0.5 * math.pi * float(row) / float(rows);
            rings.append(
                ring(made, low, high, count, base_z + rise * math.sin(lift), math.cos(lift), 1.0 - float(row) / float(rows))
            );
        }
        for index in range(len(rings) - 1) {
            band(made, rings[index], rings[index + 1], count);
        }
        cap(made, rings[-1], single(made, top, 0.5, 0.0), count, True);
        cap(made, rings[0], single(made, foot, 0.5, 1.0), count, False);
    } elif kind == "torus" {
        tube = max(3, min(24, tube));
        thick = (high.z - low.z) * 0.5;
        wide_x = (high.x - low.x) * 0.5 - thick;
        wide_y = (high.y - low.y) * 0.5 - thick;
        if wide_x <= 0.0 or wide_y <= 0.0 {
            return Mesh();
        }
        for i in range(count) {
            turn = 2.0 * math.pi * float(i) / float(count);
            for k in range(tube) {
                roll = 2.0 * math.pi * float(k) / float(tube);
                made.points.append(
                    Vec3(
                        x=middle.x + (wide_x + thick * math.cos(roll)) * math.cos(turn),
                        y=middle.y + (wide_y + thick * math.cos(roll)) * math.sin(turn),
                        z=middle.z + thick * math.sin(roll)
                    )
                );
                made.uvs.append(float(i) / float(count));
                made.uvs.append(float(k) / float(tube));
            }
        }
        for i in range(count) {
            j = (i + 1) % count;
            for k in range(tube) {
                m = (k + 1) % tube;
                made.corners.extend([i * tube + k, j * tube + k, j * tube + m, i * tube + k, j * tube + m, i * tube + m]);
            }
        }
    }
    return made;
}
