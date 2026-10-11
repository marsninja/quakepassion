"""Convex brushes: the solid geometry a document is built from.

A brush is the space behind a set of planes. Each plane carries the material
and mapping of the face it makes; the face's outline (its winding) is what is
left of the plane once every other plane of the brush has cut it. This is the
arithmetic the map formats, the level view and the compiler all share; none
of it knows about the window or the engine's level format."""
import math;
import from engine.math.vec3 { Vec3 }

"""Farther than any map reaches: the size of a plane's uncut winding."""
glob BRUSH_REACH: float = 65536.0;

"""Points closer than this to a plane are on it."""
glob BRUSH_EPSILON: float = 0.01;

"""A plane: the points p with normal . p = dist. A brush is behind its
planes (normal . p <= dist)."""
obj Plane3 {
    has normal: Vec3,
        dist: float;

    """How far a point is in front of the plane."""
    def side(point: Vec3) -> float {
        return self.normal.dot(point) - self.dist;
    }

    def moved(delta: Vec3) -> Plane3 {
        return Plane3(normal=self.normal, dist=self.dist + self.normal.dot(delta));
    }

    def flipped -> Plane3 {
        return Plane3(normal=self.normal.scale(-1.0), dist=-self.dist);
    }
}

"""The plane through three points given clockwise as seen from in front of
it (the map formats' convention), or none when they are in a line."""
def plane_through(a: Vec3, b: Vec3, c: Vec3) -> Plane3 | None {
    normal = c.sub(a).cross(b.sub(a));
    if normal.length() < 0.000001 {
        return None;
    }
    normal = normal.normalized();
    return Plane3(normal=normal, dist=normal.dot(a));
}

"""How a material lies on a face: two axes in the world that its texture's
s and t run along, each with a scale (world units to a texel) and a shift in
texels. This is the Valve 220 form; the classic form converts to it."""
obj Mapping {
    has s_axis: Vec3 = Vec3(x=1.0),
        t_axis: Vec3 = Vec3(y=-1.0),
        s_shift: float = 0.0,
        t_shift: float = 0.0,
        s_scale: float = 1.0,
        t_scale: float = 1.0,
        # The classic form's rotation in degrees, kept so that it writes back.
        rotation: float = 0.0;

    """A point's texel coordinates."""
    def texel(point: Vec3) -> list[float] {
        return [
            point.dot(self.s_axis) / (self.s_scale if self.s_scale != 0.0 else 1.0) + self.s_shift,
            point.dot(self.t_axis) / (self.t_scale if self.t_scale != 0.0 else 1.0) + self.t_shift
        ];
    }
}

"""The classic map format's axes for a face: the texture is projected along
the world axis its normal is closest to (qbsp's TextureAxisFromPlane)."""
def classic_axes(normal: Vec3) -> list[Vec3] {
    bases = [
        [Vec3(z=1.0), Vec3(x=1.0), Vec3(y=-1.0)],
        [Vec3(z=-1.0), Vec3(x=1.0), Vec3(y=-1.0)],
        [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=-1.0)],
        [Vec3(x=-1.0), Vec3(y=1.0), Vec3(z=-1.0)],
        [Vec3(y=1.0), Vec3(x=1.0), Vec3(z=-1.0)],
        [Vec3(y=-1.0), Vec3(x=1.0), Vec3(z=-1.0)]
    ];
    best = 0;
    reach = 0.0;
    for i in range(6) {
        along = normal.dot(bases[i][0]);
        if along > reach {
            reach = along;
            best = i;
        }
    }
    return [bases[best][1], bases[best][2]];
}

"""A classic mapping (shift, rotation in degrees, scale) as axes."""
def classic_mapping(
    normal: Vec3, s_shift: float, t_shift: float, rotation: float, s_scale: float, t_scale: float
) -> Mapping {
    axes = classic_axes(normal);
    s_axis = axes[0];
    t_axis = axes[1];
    if rotation != 0.0 {
        # Turn both axes about the projection axis.
        turn = math.radians(rotation);
        cosine = math.cos(turn);
        sine = math.sin(turn);
        # The two world axes the texture plane spans.
        first = 0 if abs(s_axis.x) > 0.5 else (1 if abs(s_axis.y) > 0.5 else 2);
        second = 0 if abs(t_axis.x) > 0.5 else (1 if abs(t_axis.y) > 0.5 else 2);
        s_parts = [s_axis.x, s_axis.y, s_axis.z];
        t_parts = [t_axis.x, t_axis.y, t_axis.z];
        for parts in [s_parts, t_parts] {
            one = cosine * parts[first] - sine * parts[second];
            two = sine * parts[first] + cosine * parts[second];
            parts[first] = one;
            parts[second] = two;
        }
        s_axis = Vec3(x=s_parts[0], y=s_parts[1], z=s_parts[2]);
        t_axis = Vec3(x=t_parts[0], y=t_parts[1], z=t_parts[2]);
    }
    return Mapping(
        s_axis=s_axis,
        t_axis=t_axis,
        s_shift=s_shift,
        t_shift=t_shift,
        s_scale=s_scale if s_scale != 0.0 else 1.0,
        t_scale=t_scale if t_scale != 0.0 else 1.0,
        rotation=rotation
    );
}

"""One face of a brush: its plane, three points on it (kept as written, so a
map reads back as it was), its material and how the material lies."""
obj Side {
    has plane: Plane3,
        points: list[Vec3] = [],
        material: str = "",
        mapping: Mapping = Mapping(),
        # Q2 and Q3: the face's content, surface flags and value.
        contents: int = 0,
        flags: int = 0,
        value: int = 0;
}

"""A square on a plane, big enough to be cut down to any face."""
def plane_winding(plane: Plane3) -> list[Vec3] {
    normal = plane.normal;
    # An up vector not along the normal.
    major = Vec3(z=1.0);
    if abs(normal.z) > abs(normal.x) and abs(normal.z) > abs(normal.y) {
        major = Vec3(x=1.0);
    }
    up = major.sub(normal.scale(major.dot(normal))).normalized();
    right = up.cross(normal);
    origin = normal.scale(plane.dist);
    up = up.scale(BRUSH_REACH);
    right = right.scale(BRUSH_REACH);
    return [
        origin.sub(right).add(up),
        origin.add(right).add(up),
        origin.add(right).sub(up),
        origin.sub(right).sub(up)
    ];
}

"""The part of a winding behind a plane."""
def clip_winding(points: list[Vec3], plane: Plane3) -> list[Vec3] {
    count = len(points);
    if count == 0 {
        return [];
    }
    sides = [plane.side(point) for point in points];
    kept: list[Vec3] = [];
    for i in range(count) {
        here = points[i];
        there = points[(i + 1) % count];
        near = sides[i];
        far = sides[(i + 1) % count];
        if near <= BRUSH_EPSILON {
            kept.append(here);
        }
        if (near > BRUSH_EPSILON and far < -BRUSH_EPSILON) or (near < -BRUSH_EPSILON and far > BRUSH_EPSILON) {
            # The edge crosses the plane: keep where it does.
            part = near / (near - far);
            kept.append(here.add(there.sub(here).scale(part)));
        }
    }
    return kept if len(kept) >= 3 else [];
}

"""The outline of each side of a brush: its plane cut by all the others.
A side the others cut away entirely has an empty outline."""
def brush_windings(sides: list[Side]) -> list[list[Vec3]] {
    result: list[list[Vec3]] = [];
    for i in range(len(sides)) {
        winding = plane_winding(sides[i].plane);
        for j in range(len(sides)) {
            if i != j and winding {
                winding = clip_winding(winding, sides[j].plane);
            }
        }
        result.append(tidy_winding(winding));
    }
    return result;
}

"""A winding without the points that repeat their neighbour."""
def tidy_winding(points: list[Vec3]) -> list[Vec3] {
    kept: list[Vec3] = [];
    for point in points {
        if kept and point.sub(kept[-1]).length() < BRUSH_EPSILON {
            continue;
        }
        kept.append(point);
    }
    if len(kept) > 1 and kept[0].sub(kept[-1]).length() < BRUSH_EPSILON {
        kept.pop();
    }
    return kept if len(kept) >= 3 else [];
}

"""The six sides of a box."""
def box_sides(low: Vec3, high: Vec3, material: str = "") -> list[Side] {
    faces = [
        (Vec3(x=1.0), high.x),
        (Vec3(x=-1.0), -low.x),
        (Vec3(y=1.0), high.y),
        (Vec3(y=-1.0), -low.y),
        (Vec3(z=1.0), high.z),
        (Vec3(z=-1.0), -low.z)
    ];
    sides: list[Side] = [];
    for (normal, dist) in faces {
        plane = Plane3(normal=normal, dist=dist);
        sides.append(
            Side(plane=plane, material=material, mapping=classic_mapping(normal, 0.0, 0.0, 0.0, 1.0, 1.0))
        );
    }
    return sides;
}

"""The box around a set of windings: [low, high], or none when empty."""
def windings_bounds(windings: list[list[Vec3]]) -> list[Vec3] | None {
    low = Vec3(x=BRUSH_REACH, y=BRUSH_REACH, z=BRUSH_REACH);
    high = Vec3(x=-BRUSH_REACH, y=-BRUSH_REACH, z=-BRUSH_REACH);
    seen = False;
    for winding in windings {
        for point in winding {
            low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
            high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
            seen = True;
        }
    }
    return [low, high] if seen else None;
}

"""Whether a point is inside (or on) a brush."""
def brush_holds(sides: list[Side], point: Vec3) -> bool {
    for side in sides {
        if side.plane.side(point) > BRUSH_EPSILON {
            return False;
        }
    }
    return True;
}

"""How far along a ray it enters a brush, with the side it enters by, or
(-1, -1) when it misses. The ray starts outside."""
def ray_enters_brush(sides: list[Side], start: Vec3, direction: Vec3) -> tuple[float, int] {
    enter = 0.0;
    leave = BRUSH_REACH * 4.0;
    entered = -1;
    for i in range(len(sides)) {
        plane = sides[i].plane;
        ahead = plane.side(start);
        turn = plane.normal.dot(direction);
        if abs(turn) < 0.0000001 {
            if ahead > 0.0 {
                return (-1.0, -1);
            }
            continue;
        }
        at = -ahead / turn;
        if turn < 0.0 {
            if at > enter {
                enter = at;
                entered = i;
            }
        } else {
            leave = min(leave, at);
        }
        if enter > leave {
            return (-1.0, -1);
        }
    }
    if entered < 0 {
        return (-1.0, -1);
    }
    return (enter, entered);
}

"""The area of a winding."""
def winding_area(points: list[Vec3]) -> float {
    total = Vec3();
    for i in range(1, len(points) - 1) {
        total = total.add(points[i].sub(points[0]).cross(points[i + 1].sub(points[0])));
    }
    return total.length() * 0.5;
}

"""A brush's volume: the pyramids from a point inside to each face."""
def brush_volume(sides: list[Side]) -> float {
    windings = brush_windings(sides);
    bounds = windings_bounds(windings);
    if bounds is None {
        return 0.0;
    }
    inside = bounds[0].add(bounds[1]).scale(0.5);
    total = 0.0;
    for i in range(len(sides)) {
        if windings[i] {
            total += winding_area(windings[i]) * abs(sides[i].plane.side(inside)) / 3.0;
        }
    }
    return total;
}

"""A copy of a side with another plane (its points go: they were the old
plane's)."""
def side_on(side: Side, plane: Plane3) -> Side {
    return Side(
        plane=plane,
        material=side.material,
        mapping=side.mapping,
        contents=side.contents,
        flags=side.flags,
        value=side.value
    );
}

"""Cut a brush in two along a plane: the part behind it and the part in
front, each closed with a new side that takes `material` (or the material of
the brush's first side). A part the plane leaves nothing of is empty."""
def clip_sides(sides: list[Side], plane: Plane3, material: str = "") -> tuple[list[Side], list[Side]] {
    if not sides {
        return ([], []);
    }
    skin = material if material else sides[0].material;
    behind = False;
    ahead = False;
    for outline in brush_windings(sides) {
        for point in outline {
            reach = plane.side(point);
            if reach < -BRUSH_EPSILON {
                behind = True;
            } elif reach > BRUSH_EPSILON {
                ahead = True;
            }
        }
    }
    back: list[Side] = [];
    front: list[Side] = [];
    if behind {
        back = list(sides);
        if ahead {
            back.append(
                Side(plane=plane, material=skin, mapping=classic_mapping(plane.normal, 0.0, 0.0, 0.0, 1.0, 1.0))
            );
        }
    }
    if ahead {
        front = list(sides);
        if behind {
            turned = plane.flipped();
            front.append(
                Side(plane=turned, material=skin, mapping=classic_mapping(turned.normal, 0.0, 0.0, 0.0, 1.0, 1.0))
            );
        }
    }
    return (back, front);
}

"""A vector turned about the vertical axis by an angle in radians."""
def turned_z(vector: Vec3, angle: float) -> Vec3 {
    cosine = math.cos(angle);
    sine = math.sin(angle);
    return Vec3(x=vector.x * cosine - vector.y * sine, y=vector.x * sine + vector.y * cosine, z=vector.z);
}

"""A component within a rounding error of a whole number, made whole: a
quarter turn leaves a box's planes exactly on its axes."""
def:priv settled(value: float) -> float {
    nearest = float(round(value));
    return nearest if abs(value - nearest) < 0.0000001 else value;
}

def:priv settled_vector(vector: Vec3) -> Vec3 {
    return Vec3(x=settled(vector.x), y=settled(vector.y), z=settled(vector.z));
}

"""A side turned about the vertical line through `pivot`, its material
turning with it."""
def side_turned(side: Side, pivot: Vec3, angle: float) -> Side {
    normal = settled_vector(turned_z(side.plane.normal, angle));
    # A point of the old plane, carried round the pivot.
    carried = pivot.add(turned_z(side.plane.normal.scale(side.plane.dist).sub(pivot), angle));
    mapping = side.mapping;
    s_axis = settled_vector(turned_z(mapping.s_axis, angle));
    t_axis = settled_vector(turned_z(mapping.t_axis, angle));
    return Side(
        plane=Plane3(normal=normal, dist=settled(normal.dot(carried))),
        material=side.material,
        mapping=Mapping(
            s_axis=s_axis,
            t_axis=t_axis,
            # What the pivot's own texel would otherwise slip by.
            s_shift=mapping.s_shift - (pivot.dot(s_axis) - pivot.dot(mapping.s_axis)) / mapping.s_scale,
            t_shift=mapping.t_shift - (pivot.dot(t_axis) - pivot.dot(mapping.t_axis)) / mapping.t_scale,
            s_scale=mapping.s_scale,
            t_scale=mapping.t_scale,
            rotation=mapping.rotation
        ),
        contents=side.contents,
        flags=side.flags,
        value=side.value
    );
}

"""An upright prism with `count` sides inscribed in a box: a cylinder when
there are many."""
def cylinder_sides(low: Vec3, high: Vec3, count: int = 12, material: str = "") -> list[Side] {
    count = max(3, min(64, count));
    middle = low.add(high).scale(0.5);
    across = (high.x - low.x) * 0.5;
    deep = (high.y - low.y) * 0.5;
    sides: list[Side] = [];
    for (normal, dist) in [(Vec3(z=1.0), high.z), (Vec3(z=-1.0), -low.z)] {
        sides.append(
            Side(
                plane=Plane3(normal=normal, dist=dist),
                material=material,
                mapping=classic_mapping(normal, 0.0, 0.0, 0.0, 1.0, 1.0)
            )
        );
    }
    for i in range(count) {
        # The wall through two neighbouring points of the ellipse.
        first = 2.0 * math.pi * float(i) / float(count);
        second = 2.0 * math.pi * float(i + 1) / float(count);
        a = Vec3(x=middle.x + across * math.cos(first), y=middle.y + deep * math.sin(first), z=low.z);
        b = Vec3(x=middle.x + across * math.cos(second), y=middle.y + deep * math.sin(second), z=low.z);
        along = b.sub(a);
        normal = Vec3(x=along.y, y=-along.x).normalized();
        sides.append(
            Side(
                plane=Plane3(normal=normal, dist=normal.dot(a)),
                material=material,
                mapping=classic_mapping(normal, 0.0, 0.0, 0.0, 1.0, 1.0)
            )
        );
    }
    return sides;
}

"""A ramp filling a box: full height along its far side (+y), nothing along
its near one."""
def wedge_sides(low: Vec3, high: Vec3, material: str = "") -> list[Side] {
    slope = Vec3(y=-(high.z - low.z), z=high.y - low.y).normalized();
    faces = [
        (Vec3(x=1.0), high.x),
        (Vec3(x=-1.0), -low.x),
        (Vec3(y=1.0), high.y),
        (Vec3(z=-1.0), -low.z),
        (slope, slope.dot(Vec3(x=low.x, y=low.y, z=low.z)))
    ];
    sides: list[Side] = [];
    for (normal, dist) in faces {
        sides.append(
            Side(
                plane=Plane3(normal=normal, dist=dist),
                material=material,
                mapping=classic_mapping(normal, 0.0, 0.0, 0.0, 1.0, 1.0)
            )
        );
    }
    return sides;
}
