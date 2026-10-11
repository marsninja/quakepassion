"""Faces that meet: whether two flat outlines in one plane share a length
of edge or lie over one another, and which faces of a brush share an edge
with one of them. A pick spreads by these: over a floor made of many
brushes without leaping to a floor across the room, or from a face to the
faces round it."""
import from engine.math.vec3 { Vec3 }

"""How long two edges run along each other, when they lie on one line."""
def:priv shared_run(a0: Vec3, a1: Vec3, b0: Vec3, b1: Vec3, slack: float) -> float {
    along = a1.sub(a0);
    long = along.length();
    if long < slack {
        return 0.0;
    }
    way = along.scale(1.0 / long);
    # Both ends of the other edge on this edge's line.
    for end in [b0, b1] {
        off = end.sub(a0);
        if off.sub(way.scale(off.dot(way))).length() > slack {
            return 0.0;
        }
    }
    first = b0.sub(a0).dot(way);
    second = b1.sub(a0).dot(way);
    return min(long, max(first, second)) - max(0.0, min(first, second));
}

"""Whether a point lies inside a flat outline (a convex one, its corners in
order), in the outline's own plane and not on its edge."""
def:priv inside_outline(point: Vec3, outline: list[Vec3], slack: float) -> bool {
    count = len(outline);
    if count < 3 {
        return False;
    }
    facing = outline[1].sub(outline[0]).cross(outline[2].sub(outline[0]));
    for at in range(count) {
        rim = outline[(at + 1) % count].sub(outline[at]);
        if rim.cross(point.sub(outline[at])).dot(facing) <= slack {
            return False;
        }
    }
    return True;
}

"""Whether two outlines that lie in one plane adjoin: they share more than
a point of edge, or one lies over part of the other. Two that only touch
at a corner do not."""
def outlines_adjoin(first: list[Vec3], second: list[Vec3], slack: float = 0.05) -> bool {
    if len(first) < 3 or len(second) < 3 {
        return False;
    }
    for at in range(len(first)) {
        for other in range(len(second)) {
            if shared_run(first[at], first[(at + 1) % len(first)], second[other], second[(other + 1) % len(second)], slack)
                > slack * 4.0 {
                return True;
            }
        }
    }
    # No edge in common: one over part of the other still counts. A corner of one inside the
    # other, or its middle (when the two are the same shape), or two edges that cross.
    for (inner, outer) in [(first, second), (second, first)] {
        middle = Vec3();
        for corner in inner {
            middle = middle.add(corner);
            if inside_outline(corner, outer, slack) {
                return True;
            }
        }
        if inside_outline(middle.scale(1.0 / float(len(inner))), outer, slack) {
            return True;
        }
    }
    facing = first[1].sub(first[0]).cross(first[2].sub(first[0]));
    for at in range(len(first)) {
        a0 = first[at];
        a1 = first[(at + 1) % len(first)];
        for other in range(len(second)) {
            b0 = second[other];
            b1 = second[(other + 1) % len(second)];
            one = b1.sub(b0).cross(a0.sub(b0)).dot(facing);
            two = b1.sub(b0).cross(a1.sub(b0)).dot(facing);
            three = a1.sub(a0).cross(b0.sub(a0)).dot(facing);
            four = a1.sub(a0).cross(b1.sub(a0)).dot(facing);
            if ((one > slack and two < -slack) or (one < -slack and two > slack))
                and ((three > slack and four < -slack) or (three < -slack and four > slack)) {
                return True;
            }
        }
    }
    return False;
}

"""The faces of a brush that share an edge with one of its faces: their
places among the brush's outlines. A side that makes no face has none."""
def faces_beside(outlines: list[list[Vec3]], side: int, slack: float = 0.05) -> list[int] {
    found: list[int] = [];
    if side < 0 or side >= len(outlines) or len(outlines[side]) < 3 {
        return found;
    }
    mine = outlines[side];
    for (other, outline) in enumerate(outlines) {
        if other == side or len(outline) < 3 {
            continue;
        }
        touching = False;
        for at in range(len(mine)) {
            for place in range(len(outline)) {
                if shared_run(mine[at], mine[(at + 1) % len(mine)], outline[place], outline[(place + 1) % len(outline)], slack)
                    > slack * 4.0 {
                    touching = True;
                }
            }
        }
        if touching {
            found.append(other);
        }
    }
    return found;
}

"""The sides of a brush that make a face, given its outlines: the places of
those with three corners or more."""
def sides_used(outlines: list[list[Vec3]]) -> list[int] {
    return [index for (index, outline) in enumerate(outlines) if len(outline) >= 3];
}
