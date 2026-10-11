"""Brushes changed and made by their faces: a side dropped or turned to face
the other way, and brushes that stand on a face: a cone, a prism the face
pushed out, walls round its edge."""
import from engine.math.vec3 { Vec3 }
import from .brush { Side, Plane3, BRUSH_REACH, brush_windings, brush_volume }
import from .csg { hull_sides, pruned_sides }

"""Whether a brush closes on every side: none of its faces runs out to the
edge of the world."""
def brush_bounded(sides: list[Side]) -> bool {
    faces = 0;
    for outline in brush_windings(sides) {
        if len(outline) < 3 {
            continue;
        }
        faces += 1;
        for point in outline {
            if max(abs(point.x), max(abs(point.y), abs(point.z))) > BRUSH_REACH * 0.5 {
                return False;
            }
        }
    }
    return faces >= 4;
}

"""A brush without some of its sides: the others reach on to close it. No
sides when they do not close without them."""
def sides_dropped(sides: list[Side], gone: list[int]) -> list[Side] {
    kept = [sides[index] for index in range(len(sides)) if index not in gone];
    if len(kept) < 4 or not brush_bounded(kept) {
        return [];
    }
    return kept;
}

"""A brush with one side facing the other way: what lay beyond that face,
as far as the other sides close it. No sides when they do not."""
def side_flipped(sides: list[Side], index: int) -> list[Side] {
    turned: list[Side] = [];
    for place in range(len(sides)) {
        side = sides[place];
        if place != index {
            turned.append(side);
            continue;
        }
        turned.append(
            Side(
                plane=side.plane.flipped(),
                material=side.material,
                mapping=side.mapping,
                contents=side.contents,
                flags=side.flags,
                value=side.value
            )
        );
    }
    if not brush_bounded(turned) or brush_volume(turned) < 0.001 {
        return [];
    }
    return pruned_sides(turned);
}

"""How wide a face is at its narrowest: the least, over its edges, of how
far the face reaches from that edge's line."""
def outline_width(outline: list[Vec3]) -> float {
    narrowest = 1000000.0;
    for index in range(len(outline)) {
        start = outline[index];
        run = outline[(index + 1) % len(outline)].sub(start);
        if run.length() < 0.0001 {
            continue;
        }
        along = run.normalized();
        reach = 0.0;
        for point in outline {
            away = point.sub(start);
            reach = max(reach, away.sub(along.scale(away.dot(along))).length());
        }
        narrowest = min(narrowest, reach);
    }
    return narrowest;
}

def:priv outline_middle(outline: list[Vec3]) -> Vec3 {
    middle = Vec3();
    for point in outline {
        middle = middle.add(point);
    }
    return middle.scale(1.0 / float(max(1, len(outline))));
}

"""A cone standing on a face: its outline for a base, its point `height`
out from the middle. No sides when the face has no outline."""
def cone_on(outline: list[Vec3], face: Side, height: float) -> list[Side] {
    if len(outline) < 3 or height <= 0.0 {
        return [];
    }
    corners = list(outline);
    corners.append(outline_middle(outline).add(face.plane.normal.scale(height)));
    return hull_sides(corners, [face], face.material);
}

"""A face pushed out into a brush of its own, `depth` deep."""
def prism_on(outline: list[Vec3], face: Side, depth: float) -> list[Side] {
    if len(outline) < 3 or depth <= 0.0 {
        return [];
    }
    corners = list(outline);
    for point in outline {
        corners.append(point.add(face.plane.normal.scale(depth)));
    }
    return hull_sides(corners, [face], face.material);
}

"""Walls round a face's edge: one brush an edge, `depth` out from the face
and `thickness` in from the edge."""
def walls_on(outline: list[Vec3], face: Side, depth: float, thickness: float) -> list[list[Side]] {
    walls: list[list[Side]] = [];
    if len(outline) < 3 or depth <= 0.0 or thickness <= 0.0 {
        return walls;
    }
    middle = outline_middle(outline);
    out = face.plane.normal.scale(depth);
    for index in range(len(outline)) {
        start = outline[index];
        finish = outline[(index + 1) % len(outline)];
        run = finish.sub(start);
        if run.length() < 0.01 {
            continue;
        }
        # Into the face from this edge.
        inward = face.plane.normal.cross(run).normalized();
        if inward.dot(middle.sub(start)) < 0.0 {
            inward = inward.scale(-1.0);
        }
        deep = inward.scale(thickness);
        corners = [
            start,
            finish,
            start.add(deep),
            finish.add(deep),
            start.add(out),
            finish.add(out),
            start.add(deep).add(out),
            finish.add(deep).add(out)
        ];
        wall = hull_sides(corners, [face], face.material);
        if len(wall) >= 4 {
            walls.append(wall);
        }
    }
    return walls;
}
