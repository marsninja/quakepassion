"""A model's mesh as the model editor works on it: points, triangles of
three corners each (anticlockwise seen from outside), and a place on the
skin for each point. Every tool answers a new mesh and leaves the one it was
given alone, so that a change can be kept, shown before it is kept, or
undone by going back to the mesh before it."""
import math;
import from engine.math.vec3 { Vec3 }

obj Mesh {
    has points: list[Vec3] = [],
        # Three to a triangle: indexes into `points`.
        corners: list[int] = [],
        # Two to a point, each from 0 to 1 across and down the skin; empty
        # when the mesh has no skin laid on it.
        uvs: list[float] = [];

    def triangles -> int {
        return len(self.corners) // 3;
    }

    """A triangle's three points."""
    def triangle(index: int) -> list[Vec3] {
        return [
            self.points[self.corners[index * 3]],
            self.points[self.corners[index * 3 + 1]],
            self.points[self.corners[index * 3 + 2]]
        ];
    }

    """The way a triangle faces (of no length when it has no area)."""
    def normal(index: int) -> Vec3 {
        spots = self.triangle(index);
        across = spots[1].sub(spots[0]).cross(spots[2].sub(spots[0]));
        return across.normalized() if across.length() > 0.0000001 else Vec3();
    }

    """The box round it: [low, high] (both the origin when it is empty)."""
    def bounds -> list[Vec3] {
        if len(self.points) == 0 {
            return [Vec3(), Vec3()];
        }
        low = self.points[0];
        high = self.points[0];
        for point in self.points {
            low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
            high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
        }
        return [low, high];
    }

    def copy -> Mesh {
        return Mesh(points=list(self.points), corners=list(self.corners), uvs=list(self.uvs));
    }
}

"""How much a closed mesh holds: above zero when its triangles face outward."""
def mesh_volume(mesh: Mesh) -> float {
    total = 0.0;
    for index in range(mesh.triangles()) {
        spots = mesh.triangle(index);
        total += spots[0].dot(spots[1].cross(spots[2])) / 6.0;
    }
    return total;
}

"""How many of a mesh's edges are not shared by exactly two triangles that
run along it opposite ways: none for a closed mesh that faces one way."""
def open_edges(mesh: Mesh) -> int {
    count = len(mesh.points);
    ways: dict[int, int] = {};
    for index in range(mesh.triangles()) {
        for k in range(3) {
            a = mesh.corners[index * 3 + k];
            b = mesh.corners[index * 3 + (k + 1) % 3];
            ways[a * count + b] = ways.get(a * count + b, 0) + 1;
        }
    }
    loose = 0;
    for key in ways.keys() {
        back = (key % count) * count + key // count;
        if ways[key] != 1 or ways.get(back, 0) != 1 {
            loose += 1;
        }
    }
    return loose;
}

"""What is wrong with a mesh, a line a fault: corners that point at no
point, triangles with no area, points no triangle uses, a skin that does
not match the points."""
def mesh_faults(mesh: Mesh) -> list[str] {
    faults: list[str] = [];
    count = len(mesh.points);
    if len(mesh.corners) % 3 != 0 {
        faults.append("The corners do not come in threes (" + str(len(mesh.corners)) + ")");
    }
    used: list[bool] = [False for point in mesh.points];
    flat = 0;
    lost = 0;
    for index in range(mesh.triangles()) {
        a = mesh.corners[index * 3];
        b = mesh.corners[index * 3 + 1];
        c = mesh.corners[index * 3 + 2];
        if a < 0 or b < 0 or c < 0 or a >= count or b >= count or c >= count {
            lost += 1;
            continue;
        }
        used[a] = True;
        used[b] = True;
        used[c] = True;
        if a == b or b == c or a == c or mesh.normal(index).length() < 0.5 {
            flat += 1;
        }
    }
    if lost > 0 {
        faults.append(str(lost) + " triangles have a corner at no point");
    }
    if flat > 0 {
        faults.append(str(flat) + " triangles have no area");
    }
    idle = len([each for each in used if not each]);
    if idle > 0 {
        faults.append(str(idle) + " points are used by no triangle");
    }
    if len(mesh.uvs) != 0 and len(mesh.uvs) != count * 2 {
        faults.append("The skin has " + str(len(mesh.uvs) // 2) + " places for " + str(count) + " points");
    }
    return faults;
}

# ----------------------------------------------------------------------
# What is picked

"""The points the chosen triangles use, each once, in order."""
def points_of_faces(mesh: Mesh, faces: list[int]) -> list[int] {
    marked: list[bool] = [False for point in mesh.points];
    for index in faces {
        if index >= 0 and index < mesh.triangles() {
            for k in range(3) {
                marked[mesh.corners[index * 3 + k]] = True;
            }
        }
    }
    return [index for index in range(len(marked)) if marked[index]];
}

"""The triangles all of whose corners are among the chosen points."""
def faces_of_points(mesh: Mesh, picks: list[int]) -> list[int] {
    marked: list[bool] = [False for point in mesh.points];
    for index in picks {
        if index >= 0 and index < len(marked) {
            marked[index] = True;
        }
    }
    return [
        index for index in range(mesh.triangles())
        if marked[mesh.corners[index * 3]] and marked[mesh.corners[index * 3 + 1]] and marked[mesh.corners[index * 3 + 2]]
    ];
}

"""The triangles that face toward where one looks from (`front`), or away."""
def faces_toward(mesh: Mesh, sight: Vec3, front: bool = True) -> list[int] {
    found: list[int] = [];
    for index in range(mesh.triangles()) {
        # Edge on, a triangle faces neither way.
        lean = mesh.normal(index).dot(sight);
        if (front and lean < -0.0001) or (not front and lean > 0.0001) {
            found.append(index);
        }
    }
    return found;
}

"""How far along a line a triangle is met (below zero when it is not).
Either side of the triangle counts."""
def ray_meets(start: Vec3, along: Vec3, first: Vec3, second: Vec3, third: Vec3) -> float {
    one = second.sub(first);
    two = third.sub(first);
    across = along.cross(two);
    lean = one.dot(across);
    if abs(lean) < 0.0000001 {
        return -1.0;
    }
    from_first = start.sub(first);
    u = from_first.dot(across) / lean;
    if u < 0.0 or u > 1.0 {
        return -1.0;
    }
    other = from_first.cross(one);
    v = along.dot(other) / lean;
    if v < 0.0 or u + v > 1.0 {
        return -1.0;
    }
    reach = two.dot(other) / lean;
    return reach if reach > 0.0 else -1.0;
}

"""The triangle a line of sight meets first (-1 when it meets none). With
`facing`, only triangles that face where the line comes from."""
def face_under(mesh: Mesh, start: Vec3, along: Vec3, facing: bool = True) -> int {
    best = -1;
    nearest = 1000000000.0;
    for index in range(mesh.triangles()) {
        spots = mesh.triangle(index);
        reach = ray_meets(start, along, spots[0], spots[1], spots[2]);
        if reach < 0.0 or reach >= nearest {
            continue;
        }
        if facing and mesh.normal(index).dot(along) >= 0.0 {
            continue;
        }
        nearest = reach;
        best = index;
    }
    return best;
}

"""The point a line of sight passes: the nearest to the eye of those within
`slack` of the line for each unit of distance along it (-1 when none is)."""
def point_under(mesh: Mesh, start: Vec3, along: Vec3, slack: float = 0.02) -> int {
    best = -1;
    nearest = 1000000000.0;
    for (index, point) in enumerate(mesh.points) {
        away = point.sub(start);
        reach = away.dot(along);
        if reach <= 0.0 or reach >= nearest {
            continue;
        }
        if away.sub(along.scale(reach)).length() <= slack * reach {
            nearest = reach;
            best = index;
        }
    }
    return best;
}

# ----------------------------------------------------------------------
# Moving points

"""The chosen points moved."""
def mesh_moved(mesh: Mesh, picks: list[int], delta: Vec3) -> Mesh {
    made = mesh.copy();
    for index in picks {
        if index >= 0 and index < len(made.points) {
            made.points[index] = made.points[index].add(delta);
        }
    }
    return made;
}

"""The chosen points turned about an axis (0 x, 1 y, 2 z) through `pivot`."""
def mesh_turned(mesh: Mesh, picks: list[int], pivot: Vec3, axis: int, degrees: float) -> Mesh {
    made = mesh.copy();
    cosine = math.cos(math.radians(degrees));
    sine = math.sin(math.radians(degrees));
    for index in picks {
        if index < 0 or index >= len(made.points) {
            continue;
        }
        from_pivot = made.points[index].sub(pivot);
        if axis == 0 {
            from_pivot = Vec3(x=from_pivot.x, y=from_pivot.y * cosine - from_pivot.z * sine, z=from_pivot.y * sine + from_pivot.z * cosine);
        } elif axis == 1 {
            from_pivot = Vec3(x=from_pivot.x * cosine + from_pivot.z * sine, y=from_pivot.y, z=-from_pivot.x * sine + from_pivot.z * cosine);
        } else {
            from_pivot = Vec3(x=from_pivot.x * cosine - from_pivot.y * sine, y=from_pivot.x * sine + from_pivot.y * cosine, z=from_pivot.z);
        }
        made.points[index] = pivot.add(from_pivot);
    }
    return made;
}

"""The chosen points stretched about `pivot`, each axis by its own factor."""
def mesh_scaled(mesh: Mesh, picks: list[int], pivot: Vec3, factors: Vec3) -> Mesh {
    made = mesh.copy();
    for index in picks {
        if index >= 0 and index < len(made.points) {
            from_pivot = made.points[index].sub(pivot);
            made.points[index] = pivot.add(Vec3(x=from_pivot.x * factors.x, y=from_pivot.y * factors.y, z=from_pivot.z * factors.z));
        }
    }
    return made;
}

"""The whole mesh mirrored across a plane square to an axis at `at`, its
triangles turned round so that they still face outward."""
def mesh_mirrored(mesh: Mesh, axis: int, at: float = 0.0) -> Mesh {
    made = mesh.copy();
    for (index, point) in enumerate(made.points) {
        made.points[index] = Vec3(
            x=2.0 * at - point.x if axis == 0 else point.x,
            y=2.0 * at - point.y if axis == 1 else point.y,
            z=2.0 * at - point.z if axis == 2 else point.z
        );
    }
    return mesh_flipped(made, list(range(made.triangles())));
}

# ----------------------------------------------------------------------
# Changing triangles

"""The chosen triangles turned round to face the other way."""
def mesh_flipped(mesh: Mesh, faces: list[int]) -> Mesh {
    made = mesh.copy();
    for index in faces {
        if index >= 0 and index < made.triangles() {
            kept = made.corners[index * 3 + 1];
            made.corners[index * 3 + 1] = made.corners[index * 3 + 2];
            made.corners[index * 3 + 2] = kept;
        }
    }
    return made;
}

"""A point added between two others (its place on the skin between theirs).
Answers its index."""
def:priv between(made: Mesh, first: int, second: int, share: float = 0.5) -> int {
    made.points.append(made.points[first].add(made.points[second].sub(made.points[first]).scale(share)));
    if len(made.uvs) >= len(made.points) * 2 - 2 and len(made.uvs) > 0 {
        made.uvs.append(made.uvs[first * 2] + (made.uvs[second * 2] - made.uvs[first * 2]) * share);
        made.uvs.append(made.uvs[first * 2 + 1] + (made.uvs[second * 2 + 1] - made.uvs[first * 2 + 1]) * share);
    }
    return len(made.points) - 1;
}

"""The chosen triangles each cut into 2 (across the longest side), 3 (about
the middle) or 4 (through the middles of the sides). Sides shared by two
chosen triangles are cut at one new point."""
def mesh_subdivided(mesh: Mesh, faces: list[int], parts: int, guide: Mesh | None = None) -> Mesh {
    made = mesh.copy();
    if parts not in [2, 3, 4] {
        return made;
    }
    # Which side of a triangle is the longest is measured on `guide` when
    # one is given: the same cut then falls on every pose of a model.
    measured = guide if guide is not None and len(guide.points) == len(mesh.points) else mesh;
    count = len(mesh.points);
    middles: dict[int, int] = {};
    chosen: list[bool] = [False for index in range(mesh.triangles())];
    for index in faces {
        if index >= 0 and index < len(chosen) {
            chosen[index] = True;
        }
    }
    corners: list[int] = [];
    for index in range(mesh.triangles()) {
        a = mesh.corners[index * 3];
        b = mesh.corners[index * 3 + 1];
        c = mesh.corners[index * 3 + 2];
        if not chosen[index] {
            corners.extend([a, b, c]);
            continue;
        }
        if parts == 3 {
            # A point in the middle, and a triangle to each side.
            first = between(made, a, b);
            made.points[first] = made.points[a].add(made.points[b]).add(made.points[c]).scale(1.0 / 3.0);
            if len(made.uvs) == len(made.points) * 2 {
                made.uvs[first * 2] = (made.uvs[a * 2] + made.uvs[b * 2] + made.uvs[c * 2]) / 3.0;
                made.uvs[first * 2 + 1] = (made.uvs[a * 2 + 1] + made.uvs[b * 2 + 1] + made.uvs[c * 2 + 1]) / 3.0;
            }
            corners.extend([a, b, first, b, c, first, c, a, first]);
            continue;
        }
        trio = [a, b, c];
        if parts == 2 {
            # Turned so that the longest side is the first.
            longest = 0;
            reach = 0.0;
            for k in range(3) {
                span = measured.points[trio[k]].sub(measured.points[trio[(k + 1) % 3]]).length();
                if span > reach {
                    reach = span;
                    longest = k;
                }
            }
            trio = [trio[longest], trio[(longest + 1) % 3], trio[(longest + 2) % 3]];
        }
        cuts: list[int] = [];
        for k in range(3 if parts == 4 else 1) {
            low = min(trio[k], trio[(k + 1) % 3]);
            high = max(trio[k], trio[(k + 1) % 3]);
            key = low * count + high;
            if key not in middles {
                middles[key] = between(made, low, high);
            }
            cuts.append(middles[key]);
        }
        if parts == 2 {
            corners.extend([trio[0], cuts[0], trio[2], cuts[0], trio[1], trio[2]]);
        } else {
            corners.extend(
                [trio[0], cuts[0], cuts[2], cuts[0], trio[1], cuts[1], cuts[2], cuts[1], trio[2], cuts[0], cuts[1], cuts[2]]
            );
        }
    }
    made.corners = corners;
    return made;
}

"""The chosen triangles cut along a plane (through `base`, across `normal`):
a triangle the plane passes through becomes three, or two when the plane
goes through one of its corners, with new points where its sides cross
the plane. Sides shared by two chosen triangles are cut at one new point.
Which sides are crossed, and how far along, is measured on `guide` when
one is given: the same cut then falls on every pose of a model."""
def mesh_cut(mesh: Mesh, faces: list[int], base: Vec3, normal: Vec3, guide: Mesh | None = None) -> Mesh {
    made = mesh.copy();
    if normal.length() < 0.000001 {
        return made;
    }
    across = normal.normalized();
    measured = guide if guide is not None and len(guide.points) == len(mesh.points) else mesh;
    count = len(mesh.points);
    # How far each point stands off the plane; within a hair of it is on it.
    off: list[float] = [];
    for point in measured.points {
        gap = point.sub(base).dot(across);
        off.append(0.0 if abs(gap) < 0.0001 else gap);
    }
    chosen: list[bool] = [False for index in range(mesh.triangles())];
    for index in faces {
        if index >= 0 and index < len(chosen) {
            chosen[index] = True;
        }
    }
    crossings: dict[int, int] = {};
    corners: list[int] = [];
    for index in range(mesh.triangles()) {
        trio = [mesh.corners[index * 3], mesh.corners[index * 3 + 1], mesh.corners[index * 3 + 2]];
        above = len([at for at in trio if off[at] > 0.0]);
        below = len([at for at in trio if off[at] < 0.0]);
        if not chosen[index] or above == 0 or below == 0 {
            corners.extend(trio);
            continue;
        }
        # Turned so that the first corner is the one alone on its side, or the one on the plane.
        lone = 0;
        for k in range(3) {
            others = [off[trio[(k + 1) % 3]], off[trio[(k + 2) % 3]]];
            if above + below == 2 {
                if off[trio[k]] == 0.0 {
                    lone = k;
                }
            } elif (off[trio[k]] > 0.0) != (others[0] > 0.0) and (off[trio[k]] > 0.0) != (others[1] > 0.0) {
                lone = k;
            }
        }
        trio = [trio[lone], trio[(lone + 1) % 3], trio[(lone + 2) % 3]];
        cuts: list[int] = [];
        sides = [(trio[1], trio[2])] if above + below == 2 else [(trio[0], trio[1]), (trio[0], trio[2])];
        for (one, two) in sides {
            low = min(one, two);
            high = max(one, two);
            key = low * count + high;
            if key not in crossings {
                crossings[key] = between(made, low, high, off[low] / (off[low] - off[high]));
            }
            cuts.append(crossings[key]);
        }
        if above + below == 2 {
            corners.extend([trio[0], trio[1], cuts[0], trio[0], cuts[0], trio[2]]);
        } else {
            corners.extend([trio[0], cuts[0], cuts[1], cuts[0], trio[1], trio[2], cuts[0], trio[2], cuts[1]]);
        }
    }
    made.corners = corners;
    return made;
}

"""The chosen triangles pushed out along the way they face, on average, by
`distance`, with walls from where they stood. With `bulk` the triangles
that were there are left in place under the new ones (bulkheads); without,
only the walls and the pushed-out triangles are left."""
def mesh_extruded(mesh: Mesh, faces: list[int], distance: float, bulk: bool = False) -> Mesh {
    made = mesh.copy();
    chosen: list[bool] = [False for index in range(mesh.triangles())];
    way = Vec3();
    for index in faces {
        if index >= 0 and index < len(chosen) and not chosen[index] {
            chosen[index] = True;
            way = way.add(mesh.normal(index));
        }
    }
    if way.length() < 0.0001 {
        return made;
    }
    push = way.normalized().scale(distance);
    # Each point of the chosen triangles has a twin, pushed out.
    twin: dict[int, int] = {};
    for index in points_of_faces(mesh, [each for each in range(len(chosen)) if chosen[each]]) {
        made.points.append(mesh.points[index].add(push));
        if len(mesh.uvs) == len(mesh.points) * 2 {
            made.uvs.append(mesh.uvs[index * 2]);
            made.uvs.append(mesh.uvs[index * 2 + 1]);
        }
        twin[index] = len(made.points) - 1;
    }
    count = len(mesh.points);
    # The sides of the chosen patch that no other chosen triangle shares.
    edges: dict[int, int] = {};
    for index in range(mesh.triangles()) {
        if chosen[index] {
            for k in range(3) {
                a = mesh.corners[index * 3 + k];
                b = mesh.corners[index * 3 + (k + 1) % 3];
                edges[a * count + b] = 1;
            }
        }
    }
    corners: list[int] = [];
    for index in range(mesh.triangles()) {
        a = mesh.corners[index * 3];
        b = mesh.corners[index * 3 + 1];
        c = mesh.corners[index * 3 + 2];
        if not chosen[index] {
            corners.extend([a, b, c]);
            continue;
        }
        if bulk {
            corners.extend([a, b, c]);
        }
        corners.extend([twin[a], twin[b], twin[c]]);
        for k in range(3) {
            first = mesh.corners[index * 3 + k];
            second = mesh.corners[index * 3 + (k + 1) % 3];
            if second * count + first not in edges {
                # A wall from the old side to the new, facing outward.
                corners.extend([first, second, twin[second], first, twin[second], twin[first]]);
            }
        }
    }
    made.corners = corners;
    # Without bulkheads a point only the old triangles used is left behind.
    return made if bulk else mesh_pruned(made);
}

"""The mesh without the points no triangle uses, the rest renumbered in the
order they stood in. Which points go depends only on the triangles, so
every pose of a model loses the same ones."""
def mesh_pruned(mesh: Mesh) -> Mesh {
    used = points_of_faces(mesh, list(range(mesh.triangles())));
    if len(used) == len(mesh.points) {
        return mesh;
    }
    skinned = len(mesh.uvs) == len(mesh.points) * 2;
    made = Mesh();
    stands: list[int] = [-1 for point in mesh.points];
    for index in used {
        stands[index] = len(made.points);
        made.points.append(mesh.points[index]);
        if skinned {
            made.uvs.append(mesh.uvs[index * 2]);
            made.uvs.append(mesh.uvs[index * 2 + 1]);
        }
    }
    made.corners = [stands[corner] for corner in mesh.corners];
    return made;
}

"""Points that stand in the same place made one, and the points no
triangle uses left out."""
def mesh_welded(mesh: Mesh, slack: float = 0.001) -> Mesh {
    made = Mesh();
    skinned = len(mesh.uvs) == len(mesh.points) * 2;
    stands: list[int] = [-1 for point in mesh.points];
    used = points_of_faces(mesh, list(range(mesh.triangles())));
    for index in used {
        found = -1;
        for other in range(len(made.points)) {
            if made.points[other].sub(mesh.points[index]).length() <= slack {
                found = other;
                break;
            }
        }
        if found < 0 {
            made.points.append(mesh.points[index]);
            if skinned {
                made.uvs.append(mesh.uvs[index * 2]);
                made.uvs.append(mesh.uvs[index * 2 + 1]);
            }
            found = len(made.points) - 1;
        }
        stands[index] = found;
    }
    for index in range(mesh.triangles()) {
        a = stands[mesh.corners[index * 3]];
        b = stands[mesh.corners[index * 3 + 1]];
        c = stands[mesh.corners[index * 3 + 2]];
        if a != b and b != c and a != c {
            made.corners.extend([a, b, c]);
        }
    }
    return made;
}
