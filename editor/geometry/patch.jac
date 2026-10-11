"""Curved patches: a grid of control points and the surface they bend.

A patch is `width` by `height` control points, both odd. Each three by three
of them is one biquadratic Bezier sheet: the surface passes through the
corner points and is pulled toward the ones between. The surface is built as
thin prisms, a pair to each small square of it, so a patch is brushes like
everything else in a scene: it draws, collides and takes materials in any
game's rules, and moving a control point builds it again."""
import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side }
import from .csg { hull_sides }

"""Control points as a field keeps them: three numbers each."""
def points_text(points: list[Vec3]) -> str {
    words: list[str] = [];
    for point in points {
        for value in [point.x, point.y, point.z] {
            nearest = float(round(value));
            words.append(str(int(nearest)) if abs(value - nearest) < 0.005 else str(round(value, 2)));
        }
    }
    return " ".join(words);
}

"""Control points from a field, or none when it does not hold `count`."""
def points_from(text: str, count: int) -> list[Vec3] | None {
    numbers: list[float] = [];
    for word in text.split() {
        try {
            numbers.append(float(word));
        } except ValueError {
            return None;
        }
    }
    if count < 1 or len(numbers) != count * 3 {
        return None;
    }
    return [Vec3(x=numbers[i * 3], y=numbers[i * 3 + 1], z=numbers[i * 3 + 2]) for i in range(count)];
}

"""A point of one quadratic curve through three control points."""
def:priv curve_at(a: Vec3, b: Vec3, c: Vec3, t: float) -> Vec3 {
    back = 1.0 - t;
    return a.scale(back * back).add(b.scale(2.0 * t * back)).add(c.scale(t * t));
}

"""The surface as a grid of points: `steps` to each stretch between corner
control points. Answers (columns, rows, points row by row); no points when
the control grid is not odd by odd."""
def patch_surface(points: list[Vec3], width: int, height: int, steps: int = 4) -> tuple[int, int, list[Vec3]] {
    if width < 3 or height < 3 or width % 2 == 0 or height % 2 == 0 or len(points) != width * height or steps < 1 {
        return (0, 0, []);
    }
    columns = (width - 1) // 2 * steps + 1;
    rows = (height - 1) // 2 * steps + 1;
    found: list[Vec3] = [];
    for row in range(rows) {
        block_row = min(row // steps, (height - 1) // 2 - 1);
        v = float(row - block_row * steps) / float(steps);
        for column in range(columns) {
            block_column = min(column // steps, (width - 1) // 2 - 1);
            u = float(column - block_column * steps) / float(steps);
            # Along each of the block's three rows of control points, then across them.
            across: list[Vec3] = [];
            for k in range(3) {
                base = (block_row * 2 + k) * width + block_column * 2;
                across.append(curve_at(points[base], points[base + 1], points[base + 2], u));
            }
            found.append(curve_at(across[0], across[1], across[2], v));
        }
    }
    return (columns, rows, found);
}

"""The prisms of a patch: for each small square of its surface two, each a
triangle of the surface and the same triangle `thickness` behind it. A
square pinched to nothing (a cone's tip) makes none."""
def patch_brushes(
    points: list[Vec3],
    width: int,
    height: int,
    steps: int = 4,
    thickness: float = 8.0,
    material: str = "",
    like: list[Side] = []
) -> list[list[Side]] {
    grid = patch_surface(points, width, height, steps);
    columns = grid[0];
    rows = grid[1];
    surface = grid[2];
    made: list[list[Side]] = [];
    if columns < 2 or rows < 2 {
        return made;
    }
    # A way out of the surface at each point: the mean of its squares'.
    normals: list[Vec3] = [Vec3() for point in surface];
    for row in range(rows - 1) {
        for column in range(columns - 1) {
            a = row * columns + column;
            b = a + 1;
            c = a + columns + 1;
            d = a + columns;
            for trio in [[a, b, c], [a, c, d]] {
                out = surface[trio[1]].sub(surface[trio[0]]).cross(surface[trio[2]].sub(surface[trio[0]]));
                for index in trio {
                    normals[index] = normals[index].add(out);
                }
            }
        }
    }
    backs: list[Vec3] = [];
    for (index, point) in enumerate(surface) {
        out = normals[index];
        if out.length() < 0.000001 {
            backs.append(point);
        } else {
            backs.append(point.sub(out.normalized().scale(thickness)));
        }
    }
    for row in range(rows - 1) {
        for column in range(columns - 1) {
            a = row * columns + column;
            b = a + 1;
            c = a + columns + 1;
            d = a + columns;
            for trio in [[a, b, c], [a, c, d]] {
                area = surface[trio[1]].sub(surface[trio[0]]).cross(surface[trio[2]].sub(surface[trio[0]])).length();
                if area < 0.5 {
                    continue;
                }
                corners: list[Vec3] = [];
                for index in trio {
                    corners.append(surface[index]);
                    corners.append(backs[index]);
                }
                prism = hull_sides(corners, like, material);
                if len(prism) >= 4 {
                    made.append(prism);
                }
            }
        }
    }
    return made;
}

"""The kinds `patch_points` knows."""
glob PATCH_KINDS: list[str] = ["sheet", "arch", "bevel", "cylinder", "cone", "endcap"];

"""The control points of a patch of a kind, filling a box: (width, height,
points). A sheet lies flat across the top of the box; an arch spans it
along x and runs its depth; a bevel rounds one upright corner; a cylinder
and a cone stand in it; an endcap is half a pipe standing upright, open
toward the box's near side."""
def patch_points(kind: str, low: Vec3, high: Vec3) -> tuple[int, int, list[Vec3]] {
    middle = low.add(high).scale(0.5);
    points: list[Vec3] = [];
    if kind == "endcap" {
        # Five points round the far half of the box, at each of three heights.
        for z in [low.z, middle.z, high.z] {
            for (x, y) in [(low.x, low.y), (low.x, high.y), (middle.x, high.y), (high.x, high.y), (high.x, low.y)] {
                points.append(Vec3(x=x, y=y, z=z));
            }
        }
        return (5, 3, points);
    }
    if kind == "sheet" {
        for y in [low.y, middle.y, high.y] {
            for x in [low.x, middle.x, high.x] {
                points.append(Vec3(x=x, y=y, z=high.z));
            }
        }
        return (3, 3, points);
    }
    if kind == "arch" {
        # Five points across: up one side, over the top, down the other.
        for y in [high.y, middle.y, low.y] {
            for (x, z) in [(low.x, low.z), (low.x, high.z), (middle.x, high.z), (high.x, high.z), (high.x, low.z)] {
                points.append(Vec3(x=x, y=y, z=z));
            }
        }
        return (5, 3, points);
    }
    if kind == "bevel" {
        for z in [low.z, middle.z, high.z] {
            for (x, y) in [(low.x, high.y), (low.x, low.y), (high.x, low.y)] {
                points.append(Vec3(x=x, y=y, z=z));
            }
        }
        return (3, 3, points);
    }
    if kind == "cylinder" or kind == "cone" {
        # Round the box by the middles of its sides, pulled toward its corners.
        ring = [
            (middle.x, low.y), (high.x, low.y), (high.x, middle.y), (high.x, high.y), (middle.x, high.y),
            (low.x, high.y), (low.x, middle.y), (low.x, low.y), (middle.x, low.y)
        ];
        for (level, pinch) in [(low.z, 1.0), (middle.z, 0.5 if kind == "cone" else 1.0), (high.z, 0.0 if kind == "cone" else 1.0)] {
            for (x, y) in ring {
                points.append(
                    Vec3(x=middle.x + (x - middle.x) * pinch, y=middle.y + (y - middle.y) * pinch, z=level)
                );
            }
        }
        return (9, 3, points);
    }
    return (0, 0, points);
}

"""Control points kept as a field, every one moved by `delta`."""
def points_shifted(text: str, delta: Vec3) -> str {
    words = text.split();
    points = points_from(text, len(words) // 3);
    if points is None {
        return text;
    }
    return points_text([point.add(delta) for point in points]);
}

"""Control points kept as a field, every one carried by a change of the
world that sends a point p to pivot + M (p - pivot): `across`, `along` and
`upward` are what M makes of the x, y and z axes."""
def points_carried(text: str, pivot: Vec3, across: Vec3, along: Vec3, upward: Vec3) -> str {
    words = text.split();
    points = points_from(text, len(words) // 3);
    if points is None {
        return text;
    }
    moved: list[Vec3] = [];
    for point in points {
        away = point.sub(pivot);
        moved.append(pivot.add(across.scale(away.x)).add(along.scale(away.y)).add(upward.scale(away.z)));
    }
    return points_text(moved);
}

"""Control points kept as a field, each row of `width` turned end for end: a
mirrored patch laid out this way faces the way its mirror image should."""
def points_reversed(text: str, width: int) -> str {
    words = text.split();
    points = points_from(text, len(words) // 3);
    if points is None or width < 2 or len(points) % width != 0 {
        return text;
    }
    turned: list[Vec3] = [];
    for row in range(len(points) // width) {
        for column in range(width) {
            turned.append(points[row * width + width - 1 - column]);
        }
    }
    return points_text(turned);
}

"""A grid of control points with one more curve across it ("u": two more
columns) or up it ("v": two more rows), each carrying on from the last two
as they were going: (width, height, points)."""
def grid_grown(points: list[Vec3], width: int, height: int, way: str) -> tuple[int, int, list[Vec3]] {
    if width < 3 or height < 3 or len(points) != width * height {
        return (width, height, points);
    }
    grown: list[Vec3] = [];
    if way == "u" {
        for row in range(height) {
            last = points[row * width + width - 1];
            step = last.sub(points[row * width + width - 2]);
            for column in range(width) {
                grown.append(points[row * width + column]);
            }
            grown.append(last.add(step));
            grown.append(last.add(step.scale(2.0)));
        }
        return (width + 2, height, grown);
    }
    for point in points {
        grown.append(point);
    }
    for more in [1.0, 2.0] {
        for column in range(width) {
            last = points[(height - 1) * width + column];
            grown.append(last.add(last.sub(points[(height - 2) * width + column]).scale(more)));
        }
    }
    return (width, height + 2, grown);
}

"""A grid without its last curve across ("u") or up ("v"). Unchanged when
that would leave less than one curve."""
def grid_shrunk(points: list[Vec3], width: int, height: int, way: str) -> tuple[int, int, list[Vec3]] {
    if len(points) != width * height or (way == "u" and width < 5) or (way != "u" and height < 5) {
        return (width, height, points);
    }
    kept: list[Vec3] = [];
    if way == "u" {
        for row in range(height) {
            for column in range(width - 2) {
                kept.append(points[row * width + column]);
            }
        }
        return (width - 2, height, kept);
    }
    for index in range(width * (height - 2)) {
        kept.append(points[index]);
    }
    return (width, height - 2, kept);
}
