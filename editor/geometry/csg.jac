"""Brushes cut by brushes: what is left of one outside another, what two
share, a shell of walls, two joined into one, and the brush around a set of
corners. Every result is convex brushes again, so each tool's output is
something every other tool takes."""
import from engine.math.vec3 { Vec3 }
import from .brush { Side, Plane3, Mapping, brush_windings, brush_volume, clip_sides, side_on, classic_mapping }

"""Brushes smaller than this hold nothing worth keeping."""
glob CSG_SLIVER: float = 0.001;

"""Whether two planes are the same plane facing the same way."""
def same_plane(first: Plane3, second: Plane3) -> bool {
    return first.normal.dot(second.normal) > 0.99999 and abs(first.dist - second.dist) < 0.01;
}

"""A brush without the sides the others cut away entirely, and without a
side that repeats an earlier one."""
def pruned_sides(sides: list[Side]) -> list[Side] {
    outlines = brush_windings(sides);
    kept: list[Side] = [];
    for i in range(len(sides)) {
        if len(outlines[i]) < 3 {
            continue;
        }
        repeated = False;
        for earlier in kept {
            if same_plane(earlier.plane, sides[i].plane) {
                repeated = True;
            }
        }
        if not repeated {
            kept.append(sides[i]);
        }
    }
    return kept;
}

"""What two brushes share: one brush, or no sides when they only touch or
are apart."""
def common_sides(first: list[Side], second: list[Side]) -> list[Side] {
    both = pruned_sides(first + second);
    if not both or brush_volume(both) < CSG_SLIVER {
        return [];
    }
    return both;
}

"""What is left of `target` outside `cutter`, as convex pieces: none of them
when the cutter swallows it. Answers None when the two do not overlap, so
the target is left as it was. The cut faces take the target's material, or
the cutter's sides' when `lined`."""
def carve_sides(target: list[Side], cutter: list[Side], lined: bool = False) -> list[list[Side]] | None {
    if not common_sides(target, cutter) {
        return None;
    }
    pieces: list[list[Side]] = [];
    rest = target;
    for side in pruned_sides(cutter) {
        parts = clip_sides(rest, side.plane, side.material if lined else "");
        outside = pruned_sides(parts[1]);
        if outside and brush_volume(outside) >= CSG_SLIVER {
            pieces.append(outside);
        }
        rest = parts[0];
        if not rest {
            break;
        }
    }
    return pieces;
}

"""A brush as a shell of walls `thickness` deep: the brush with its inside
carved out. No pieces when the walls would meet in the middle."""
def hollow_sides(sides: list[Side], thickness: float) -> list[list[Side]] {
    if thickness <= 0.0 {
        return [];
    }
    inner: list[Side] = [];
    for side in pruned_sides(sides) {
        inner.append(side_on(side, Plane3(normal=side.plane.normal, dist=side.plane.dist - thickness)));
    }
    if brush_volume(pruned_sides(inner)) < CSG_SLIVER {
        return [];
    }
    walls = carve_sides(sides, inner);
    return walls if walls is not None else [];
}

"""Every corner of a brush, once."""
def brush_corners(sides: list[Side]) -> list[Vec3] {
    found: list[Vec3] = [];
    for outline in brush_windings(sides) {
        for point in outline {
            known = False;
            for seen in found {
                if seen.sub(point).length() < 0.05 {
                    known = True;
                }
            }
            if not known {
                found.append(point);
            }
        }
    }
    return found;
}

"""Two brushes as one, when together they are convex (a wall cut in two put
back): the sides of both that neither pokes through. No sides otherwise."""
def merged_sides(first: list[Side], second: list[Side]) -> list[Side] {
    corners = brush_corners(first) + brush_corners(second);
    if not corners {
        return [];
    }
    outer: list[Side] = [];
    for side in pruned_sides(first) + pruned_sides(second) {
        inside = True;
        for corner in corners {
            if side.plane.side(corner) > 0.02 {
                inside = False;
            }
        }
        if not inside {
            continue;
        }
        repeated = False;
        for earlier in outer {
            if same_plane(earlier.plane, side.plane) {
                repeated = True;
            }
        }
        if not repeated {
            outer.append(side);
        }
    }
    joined = pruned_sides(outer);
    if not joined {
        return [];
    }
    shared = common_sides(first, second);
    apart = brush_volume(first) + brush_volume(second) - (brush_volume(shared) if shared else 0.0);
    whole = brush_volume(joined);
    if abs(whole - apart) > max(0.01, apart * 0.0001) {
        return [];
    }
    return joined;
}

"""The side of `like` that faces most nearly the way `normal` does."""
def:priv nearest_side(like: list[Side], normal: Vec3) -> Side | None {
    best: Side | None = None;
    reach = -2.0;
    for side in like {
        along = side.plane.normal.dot(normal);
        if along > reach {
            reach = along;
            best = side;
        }
    }
    return best;
}

"""The brush around a set of corners (their convex hull). Each side takes
its material from the side of `like` that faces most nearly its way, and
that side's mapping too when the two are the same plane turned a little.
No sides when the corners lie flat."""
def hull_sides(corners: list[Vec3], like: list[Side], material: str = "") -> list[Side] {
    planes: list[Plane3] = [];
    count = len(corners);
    for i in range(count) {
        for j in range(i + 1, count) {
            for k in range(j + 1, count) {
                normal = corners[j].sub(corners[i]).cross(corners[k].sub(corners[i]));
                if normal.length() < 0.0001 {
                    continue;
                }
                normal = normal.normalized();
                dist = normal.dot(corners[i]);
                ahead = False;
                behind = False;
                for corner in corners {
                    reach = normal.dot(corner) - dist;
                    if reach > 0.02 {
                        ahead = True;
                    } elif reach < -0.02 {
                        behind = True;
                    }
                }
                if ahead and behind {
                    continue;
                }
                if not ahead and not behind {
                    # Every corner is on this plane: nothing is enclosed.
                    return [];
                }
                plane = Plane3(normal=normal, dist=dist);
                if ahead {
                    plane = plane.flipped();
                }
                known = False;
                for earlier in planes {
                    if same_plane(earlier, plane) {
                        known = True;
                    }
                }
                if not known {
                    planes.append(plane);
                }
            }
        }
    }
    if len(planes) < 4 {
        return [];
    }
    sides: list[Side] = [];
    for plane in planes {
        model = nearest_side(like, plane.normal);
        if model is None {
            sides.append(
                Side(plane=plane, material=material, mapping=classic_mapping(plane.normal, 0.0, 0.0, 0.0, 1.0, 1.0))
            );
        } elif model.plane.normal.dot(plane.normal) > 0.7 {
            sides.append(side_on(model, plane));
        } else {
            sides.append(
                Side(
                    plane=plane,
                    material=model.material,
                    mapping=classic_mapping(plane.normal, 0.0, 0.0, 0.0, 1.0, 1.0)
                )
            );
        }
    }
    return sides;
}

"""A brush with the corners nearest `spots` moved by `delta`: the brush
around its corners afterwards. No sides when that would be flat."""
def corners_moved(sides: list[Side], spots: list[Vec3], delta: Vec3) -> list[Side] {
    corners = brush_corners(sides);
    moved: list[Vec3] = [];
    touched = False;
    for corner in corners {
        grabbed = False;
        for spot in spots {
            if corner.sub(spot).length() < 0.1 {
                grabbed = True;
            }
        }
        if grabbed {
            moved.append(corner.add(delta));
            touched = True;
        } else {
            moved.append(corner);
        }
    }
    if not touched {
        return [];
    }
    return hull_sides(moved, pruned_sides(sides));
}

"""The edges of a brush, each once, as pairs of corners."""
def brush_edges(sides: list[Side]) -> list[list[Vec3]] {
    found: list[list[Vec3]] = [];
    for outline in brush_windings(sides) {
        for i in range(len(outline)) {
            a = outline[i];
            b = outline[(i + 1) % len(outline)];
            known = False;
            for seen in found {
                if (seen[0].sub(a).length() < 0.05 and seen[1].sub(b).length() < 0.05)
                    or (seen[0].sub(b).length() < 0.05 and seen[1].sub(a).length() < 0.05) {
                    known = True;
                }
            }
            if not known {
                found.append([a, b]);
            }
        }
    }
    return found;
}
