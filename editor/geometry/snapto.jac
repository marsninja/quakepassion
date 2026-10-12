"""Two things a pointer does that a grid does not: a loop drawn freehand
round what is to be selected, and a move that ends on something already
there (a corner of another brush, a point along one of its edges, a point
on one of its faces) when it comes within reach of it."""
import from engine.math.vec3 { Vec3 }

"""Whether a point of the screen lies inside a loop drawn on it (`loop` is
x, y, x, y ...; the loop closes itself). A point inside an odd number of
its turns is inside."""
def loop_inside(loop: list[int], x: int, y: int) -> bool {
    count = len(loop) // 2;
    if count < 3 {
        return False;
    }
    inside = False;
    for at in range(count) {
        x0 = float(loop[at * 2]);
        y0 = float(loop[at * 2 + 1]);
        x1 = float(loop[((at + 1) % count) * 2]);
        y1 = float(loop[((at + 1) % count) * 2 + 1]);
        if (y0 > float(y)) != (y1 > float(y)) and float(x) < x0 + (x1 - x0) * (float(y) - y0) / (y1 - y0) {
            inside = not inside;
        }
    }
    return inside;
}

"""A loop with no more than `most` points: every so many of them kept, the
first and the last among them."""
def loop_thinned(loop: list[int], most: int = 48) -> list[int] {
    count = len(loop) // 2;
    if count <= most or most < 3 {
        return loop[:count * 2];
    }
    kept: list[int] = [];
    for place in range(most) {
        at = (place * (count - 1)) // (most - 1);
        kept.append(loop[at * 2]);
        kept.append(loop[at * 2 + 1]);
    }
    return kept;
}

"""The point of a stretch of line nearest a point."""
def:priv nearest_on(point: Vec3, first: Vec3, second: Vec3) -> Vec3 {
    along = second.sub(first);
    long = along.dot(along);
    if long < 0.000001 {
        return first;
    }
    share = max(0.0, min(1.0, point.sub(first).dot(along) / long));
    return first.add(along.scale(share));
}

"""The point of a flat outline's face nearest a point, when the point
stands over the face itself (not past its edges). None otherwise."""
def:priv nearest_within(point: Vec3, outline: list[Vec3]) -> Vec3 | None {
    count = len(outline);
    if count < 3 {
        return None;
    }
    facing = outline[1].sub(outline[0]).cross(outline[2].sub(outline[0]));
    if facing.length() < 0.000001 {
        return None;
    }
    across = facing.normalized();
    down = point.sub(across.scale(point.sub(outline[0]).dot(across)));
    for at in range(count) {
        rim = outline[(at + 1) % count].sub(outline[at]);
        if rim.cross(down.sub(outline[at])).dot(facing) < -0.0001 {
            return None;
        }
    }
    return down;
}

"""A move made to end on something there. Each corner that is moving is
taken to where `delta` would leave it; if one comes within `reach` of a
corner of what stands still ("corners"), of a point along one of its edges
("edges", which takes corners too) or of a point on one of its faces
("faces", which takes edges and corners too), the move is changed by the
least that puts it there. Otherwise the move is as it was asked."""
def snapped_move(
    moving: list[Vec3], delta: Vec3, corners: list[Vec3], edges: list[list[Vec3]], faces: list[list[Vec3]], how: str,
    reach: float
) -> Vec3 {
    if how not in ["corners", "edges", "faces"] or reach <= 0.0 {
        return delta;
    }
    best: Vec3 | None = None;
    least = reach;
    for corner in moving {
        landed = corner.add(delta);
        goals: list[Vec3] = [];
        for still in corners {
            goals.append(still);
        }
        if how != "corners" {
            for stretch in edges {
                if len(stretch) == 2 {
                    goals.append(nearest_on(landed, stretch[0], stretch[1]));
                }
            }
        }
        if how == "faces" {
            for outline in faces {
                over = nearest_within(landed, outline);
                if over is not None {
                    goals.append(over);
                }
            }
        }
        for goal in goals {
            gap = goal.sub(landed);
            # A nearer goal wins; of two as near, the first found.
            if gap.length() < least - 0.0001 {
                least = gap.length();
                best = gap;
            }
        }
    }
    return delta.add(best) if best is not None else delta;
}
