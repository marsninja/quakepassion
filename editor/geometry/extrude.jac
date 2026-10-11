"""Sweeps: a flat outline carried along a line or a path of points, leaving a
brush for each convex piece of the outline along each stretch of the path.
Where the path turns, the stretches are cut on the plane that halves the
turn, so that they meet without a gap and without one running into the next."""
import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side }
import from .csg { hull_sides, brush_corners }

"""The outlines there are names for."""
glob PROFILE_KINDS: list[str] = ["square", "round", "ridge", "ell", "tee", "channel", "rail"];

"""An outline by name: its convex pieces, each the corners of the piece as
(across, up) within a square from -0.5 to 0.5. `count` is how many sides a
round one has."""
def profile_pieces(kind: str, count: int = 8) -> list[list[tuple[float, float]]] {
    if kind == "square" {
        return [[(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]];
    }
    if kind == "round" {
        sides = max(3, min(24, count));
        ring: list[tuple[float, float]] = [];
        for i in range(sides) {
            turn = 2.0 * math.pi * (float(i) + 0.5) / float(sides);
            ring.append((0.5 * math.cos(turn), 0.5 * math.sin(turn)));
        }
        return [ring];
    }
    if kind == "ridge" {
        return [[(-0.5, -0.5), (0.5, -0.5), (0.0, 0.5)]];
    }
    foot = [(-0.5, -0.5), (0.5, -0.5), (0.5, -0.25), (-0.5, -0.25)];
    if kind == "ell" {
        return [foot, [(-0.5, -0.25), (-0.25, -0.25), (-0.25, 0.5), (-0.5, 0.5)]];
    }
    if kind == "tee" {
        return [
            [(-0.5, 0.25), (0.5, 0.25), (0.5, 0.5), (-0.5, 0.5)],
            [(-0.125, -0.5), (0.125, -0.5), (0.125, 0.25), (-0.125, 0.25)]
        ];
    }
    if kind == "channel" {
        return [
            foot,
            [(-0.5, -0.25), (-0.25, -0.25), (-0.25, 0.5), (-0.5, 0.5)],
            [(0.25, -0.25), (0.5, -0.25), (0.5, 0.5), (0.25, 0.5)]
        ];
    }
    if kind == "rail" {
        return [
            foot,
            [(-0.5, 0.25), (0.5, 0.25), (0.5, 0.5), (-0.5, 0.5)],
            [(-0.125, -0.25), (0.125, -0.25), (0.125, 0.25), (-0.125, 0.25)]
        ];
    }
    return [];
}

"""An outline taken from a brush: its corners as seen along the y axis
(across is x, up is z), about the middle of its box, as one piece of the
size it is. Answers the piece and how wide and tall it is."""
def profile_of(sides: list[Side]) -> tuple[list[tuple[float, float]], float, float] {
    corners = brush_corners(sides);
    piece: list[tuple[float, float]] = [];
    if len(corners) == 0 {
        return (piece, 0.0, 0.0);
    }
    low_x = corners[0].x;
    high_x = corners[0].x;
    low_z = corners[0].z;
    high_z = corners[0].z;
    for corner in corners {
        low_x = min(low_x, corner.x);
        high_x = max(high_x, corner.x);
        low_z = min(low_z, corner.z);
        high_z = max(high_z, corner.z);
    }
    wide = high_x - low_x;
    tall = high_z - low_z;
    if wide < 0.01 or tall < 0.01 {
        return (piece, 0.0, 0.0);
    }
    for corner in corners {
        spot = ((corner.x - (low_x + high_x) * 0.5) / wide, (corner.z - (low_z + high_z) * 0.5) / tall);
        fresh = True;
        for known in piece {
            if abs(known[0] - spot[0]) < 0.0001 and abs(known[1] - spot[1]) < 0.0001 {
                fresh = False;
            }
        }
        if fresh {
            piece.append(spot);
        }
    }
    return (piece, wide, tall);
}

"""The path with the points that repeat the one before them left out."""
def:priv distinct(path: list[Vec3]) -> list[Vec3] {
    kept: list[Vec3] = [];
    for point in path {
        if len(kept) == 0 or point.sub(kept[-1]).length() > 0.01 {
            kept.append(point);
        }
    }
    return kept;
}

"""Across and up for a stretch running `along`: square to it, up being the
world's unless the stretch runs straight up or down."""
def sweep_frame(along: Vec3) -> list[Vec3] {
    across = along.cross(Vec3(z=1.0));
    if across.length() < 0.001 {
        across = Vec3(y=-1.0);
    }
    across = across.normalized();
    return [across, across.cross(along).normalized()];
}

"""Where the line through `start` along `along` meets the plane through
`spot` whose normal is `normal`."""
def:priv meets(start: Vec3, along: Vec3, spot: Vec3, normal: Vec3) -> Vec3 {
    slope = along.dot(normal);
    if abs(slope) < 0.000001 {
        return start;
    }
    return start.add(along.scale(spot.sub(start).dot(normal) / slope));
}

"""The plane a stretch is cut on where it meets another: square to the way
that halves the turn between them."""
def:priv joint(before: Vec3, after: Vec3) -> Vec3 {
    between = before.add(after);
    return between.normalized() if between.length() > 0.001 else after;
}

"""Sweep an outline's pieces along a path. `wide` and `tall` are the size of
the outline's square; `closed` joins the path's end to its beginning. A
brush for each piece along each stretch, every side in `material`."""
def sweep_brushes(
    pieces: list[list[tuple[float, float]]],
    path: list[Vec3],
    wide: float,
    tall: float,
    material: str = "",
    closed: bool = False
) -> list[list[Side]] {
    made: list[list[Side]] = [];
    points = distinct(path);
    if closed and len(points) > 2 and points[0].sub(points[-1]).length() <= 0.01 {
        points = points[:-1];
    }
    count = len(points);
    if count < 2 or wide <= 0.0 or tall <= 0.0 {
        return made;
    }
    looped = closed and count > 2;
    stretches = count if looped else count - 1;
    ways: list[Vec3] = [];
    for index in range(stretches) {
        ways.append(points[(index + 1) % count].sub(points[index]).normalized());
    }
    for index in range(stretches) {
        along = ways[index];
        begin = points[index];
        finish = points[(index + 1) % count];
        # Cut square at the path's own ends, on the halving plane at a turn.
        first_cut = along;
        if index > 0 or looped {
            first_cut = joint(ways[(index - 1 + stretches) % stretches], along);
        }
        last_cut = along;
        if index + 1 < stretches or looped {
            last_cut = joint(along, ways[(index + 1) % stretches]);
        }
        frame = sweep_frame(along);
        for piece in pieces {
            corners: list[Vec3] = [];
            for (across, up) in piece {
                base = begin.add(frame[0].scale(across * wide)).add(frame[1].scale(up * tall));
                corners.append(meets(base, along, begin, first_cut));
                corners.append(meets(base, along, finish, last_cut));
            }
            sides = hull_sides(corners, [], material);
            if len(sides) >= 4 {
                made.append(sides);
            }
        }
    }
    return made;
}
