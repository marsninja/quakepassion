"""How materials lie on faces, changed: slid, scaled, turned, fitted to a
face, laid flat on it; and sides carried through a mirror, a stretch or a
turn about any axis with their materials staying where they were on them."""
import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side, Plane3, Mapping, classic_mapping }

"""A copy of a side with another material, another mapping, or both."""
def side_like(side: Side, material: str | None = None, mapping: Mapping | None = None) -> Side {
    return Side(
        plane=side.plane,
        points=side.points,
        material=material if material is not None else side.material,
        mapping=mapping if mapping is not None else side.mapping,
        contents=side.contents,
        flags=side.flags,
        value=side.value
    );
}

"""A mapping slid by texels."""
def mapping_slid(mapping: Mapping, s: float, t: float) -> Mapping {
    return Mapping(
        s_axis=mapping.s_axis,
        t_axis=mapping.t_axis,
        s_shift=mapping.s_shift + s,
        t_shift=mapping.t_shift + t,
        s_scale=mapping.s_scale,
        t_scale=mapping.t_scale,
        rotation=mapping.rotation
    );
}

"""A mapping with other scales (world units to a texel; negative mirrors).
A zero keeps the scale it had."""
def mapping_sized(mapping: Mapping, s_scale: float, t_scale: float) -> Mapping {
    return Mapping(
        s_axis=mapping.s_axis,
        t_axis=mapping.t_axis,
        s_shift=mapping.s_shift,
        t_shift=mapping.t_shift,
        s_scale=s_scale if s_scale != 0.0 else mapping.s_scale,
        t_scale=t_scale if t_scale != 0.0 else mapping.t_scale,
        rotation=mapping.rotation
    );
}

"""A vector turned about a unit axis by an angle in radians."""
def spun_about(vector: Vec3, axis: Vec3, angle: float) -> Vec3 {
    cosine = math.cos(angle);
    sine = math.sin(angle);
    return vector.scale(cosine).add(axis.cross(vector).scale(sine)).add(
        axis.scale(axis.dot(vector) * (1.0 - cosine))
    );
}

def:priv whole(value: float) -> float {
    nearest = float(round(value));
    return nearest if abs(value - nearest) < 0.0000001 else value;
}

def:priv whole_vector(vector: Vec3) -> Vec3 {
    return Vec3(x=whole(vector.x), y=whole(vector.y), z=whole(vector.z));
}

"""A mapping turned by degrees about the line its texture is projected
along, so one that follows the world's axes or a face goes on doing so."""
def mapping_spun(mapping: Mapping, degrees: float) -> Mapping {
    along = mapping.s_axis.cross(mapping.t_axis);
    if along.length() < 0.000001 {
        return mapping;
    }
    along = along.normalized();
    angle = math.radians(degrees);
    return Mapping(
        s_axis=whole_vector(spun_about(mapping.s_axis, along, angle)),
        t_axis=whole_vector(spun_about(mapping.t_axis, along, angle)),
        s_shift=mapping.s_shift,
        t_shift=mapping.t_shift,
        s_scale=mapping.s_scale,
        t_scale=mapping.t_scale,
        rotation=(mapping.rotation + degrees) % 360.0
    );
}

"""A mapping that lies flat on a face: its texture plane is the face's own,
with t running down the face as nearly as the face allows."""
def mapping_flat(normal: Vec3) -> Mapping {
    down = Vec3(z=-1.0);
    if abs(normal.z) > 0.999 {
        down = Vec3(y=-1.0);
    }
    s_axis = down.cross(normal);
    if normal.z < -0.999 {
        s_axis = s_axis.scale(-1.0);
    }
    s_axis = whole_vector(s_axis.normalized());
    t_axis = whole_vector(normal.cross(s_axis).normalized());
    if t_axis.dot(down) < 0.0 {
        t_axis = t_axis.scale(-1.0);
    }
    return Mapping(s_axis=s_axis, t_axis=t_axis);
}

"""A mapping scaled and slid so a `width` by `height` texture covers a face's
outline `across` times one way and `down` times the other."""
def mapping_fitted(
    mapping: Mapping, outline: list[Vec3], width: int, height: int, across: float = 1.0, down: float = 1.0
) -> Mapping {
    if len(outline) < 3 or width <= 0 or height <= 0 or across <= 0.0 or down <= 0.0 {
        return mapping;
    }
    s_low = outline[0].dot(mapping.s_axis);
    s_high = s_low;
    t_low = outline[0].dot(mapping.t_axis);
    t_high = t_low;
    for point in outline {
        s = point.dot(mapping.s_axis);
        t = point.dot(mapping.t_axis);
        s_low = min(s_low, s);
        s_high = max(s_high, s);
        t_low = min(t_low, t);
        t_high = max(t_high, t);
    }
    if s_high - s_low < 0.001 or t_high - t_low < 0.001 {
        return mapping;
    }
    s_scale = (s_high - s_low) / (float(width) * across);
    t_scale = (t_high - t_low) / (float(height) * down);
    return Mapping(
        s_axis=mapping.s_axis,
        t_axis=mapping.t_axis,
        s_shift=-s_low / s_scale,
        t_shift=-t_low / t_scale,
        s_scale=s_scale,
        t_scale=t_scale,
        rotation=mapping.rotation
    );
}

"""A mapping's axes carried through a change of the world that sends a point
p to pivot + M (p - pivot), given what M's inverse transpose makes of each
axis: the material stays where it was on the face."""
def:priv mapping_carried(mapping: Mapping, pivot: Vec3, s_after: Vec3, t_after: Vec3) -> Mapping {
    s_long = s_after.length();
    t_long = t_after.length();
    if s_long < 0.000001 or t_long < 0.000001 {
        return mapping;
    }
    return Mapping(
        s_axis=whole_vector(s_after.scale(1.0 / s_long)),
        t_axis=whole_vector(t_after.scale(1.0 / t_long)),
        s_shift=mapping.s_shift + (pivot.dot(mapping.s_axis) - pivot.dot(s_after)) / mapping.s_scale,
        t_shift=mapping.t_shift + (pivot.dot(mapping.t_axis) - pivot.dot(t_after)) / mapping.t_scale,
        s_scale=mapping.s_scale / s_long,
        t_scale=mapping.t_scale / t_long,
        rotation=mapping.rotation
    );
}

"""A side stretched about a pivot by a factor along each axis (-1 mirrors),
its material stretching with it."""
def side_stretched(side: Side, pivot: Vec3, factors: Vec3) -> Side {
    if factors.x == 0.0 or factors.y == 0.0 or factors.z == 0.0 {
        return side;
    }
    old = side.plane;
    normal = Vec3(x=old.normal.x / factors.x, y=old.normal.y / factors.y, z=old.normal.z / factors.z);
    normal = whole_vector(normal.normalized());
    on_plane = old.normal.scale(old.dist).sub(pivot);
    carried = pivot.add(Vec3(x=on_plane.x * factors.x, y=on_plane.y * factors.y, z=on_plane.z * factors.z));
    mapping = side.mapping;
    return Side(
        plane=Plane3(normal=normal, dist=whole(normal.dot(carried))),
        material=side.material,
        mapping=mapping_carried(
            mapping,
            pivot,
            Vec3(x=mapping.s_axis.x / factors.x, y=mapping.s_axis.y / factors.y, z=mapping.s_axis.z / factors.z),
            Vec3(x=mapping.t_axis.x / factors.x, y=mapping.t_axis.y / factors.y, z=mapping.t_axis.z / factors.z)
        ),
        contents=side.contents,
        flags=side.flags,
        value=side.value
    );
}

"""The unit vector along an axis: 0 is x, 1 is y, anything else z."""
def axis_vector(axis: int) -> Vec3 {
    if axis == 0 {
        return Vec3(x=1.0);
    }
    if axis == 1 {
        return Vec3(y=1.0);
    }
    return Vec3(z=1.0);
}

"""A side turned about the line through `pivot` along an axis, its material
turning with it."""
def side_spun(side: Side, pivot: Vec3, axis: int, angle: float) -> Side {
    about = axis_vector(axis);
    normal = whole_vector(spun_about(side.plane.normal, about, angle));
    carried = pivot.add(spun_about(side.plane.normal.scale(side.plane.dist).sub(pivot), about, angle));
    mapping = side.mapping;
    return Side(
        plane=Plane3(normal=normal, dist=whole(normal.dot(carried))),
        material=side.material,
        mapping=mapping_carried(
            mapping, pivot, spun_about(mapping.s_axis, about, angle), spun_about(mapping.t_axis, about, angle)
        ),
        contents=side.contents,
        flags=side.flags,
        value=side.value
    );
}

"""A mapping as the classic one for a face: no shift, no turn, one texel a
unit."""
def mapping_plain(normal: Vec3) -> Mapping {
    return classic_mapping(normal, 0.0, 0.0, 0.0, 1.0, 1.0);
}

"""Whether two mappings lay a material the same way."""
def mapping_same(first: Mapping, second: Mapping) -> bool {
    return first.s_axis.sub(second.s_axis).length() < 0.000001
        and first.t_axis.sub(second.t_axis).length() < 0.000001
        and abs(first.s_shift - second.s_shift) < 0.000001
        and abs(first.t_shift - second.t_shift) < 0.000001
        and abs(first.s_scale - second.s_scale) < 0.000001
        and abs(first.t_scale - second.t_scale) < 0.000001;
}

"""A mapping scaled and slid so the texture repeats a whole number of times
across a face's outline each way, as near one texel to a unit as that
allows: the fit that distorts least."""
def mapping_min_fitted(mapping: Mapping, outline: list[Vec3], width: int, height: int) -> Mapping {
    if len(outline) < 3 or width <= 0 or height <= 0 {
        return mapping;
    }
    s_low = outline[0].dot(mapping.s_axis);
    s_high = s_low;
    t_low = outline[0].dot(mapping.t_axis);
    t_high = t_low;
    for point in outline {
        s_low = min(s_low, point.dot(mapping.s_axis));
        s_high = max(s_high, point.dot(mapping.s_axis));
        t_low = min(t_low, point.dot(mapping.t_axis));
        t_high = max(t_high, point.dot(mapping.t_axis));
    }
    across = max(1.0, float(round((s_high - s_low) / float(width))));
    down = max(1.0, float(round((t_high - t_low) / float(height))));
    return mapping_fitted(mapping, outline, width, height, across, down);
}

"""A mapping carried from one face round the edge it shares with another:
turned about the line where the two planes meet, by the angle between
them, so the material runs on unbroken across the corner. None when the
planes do not meet (they are parallel)."""
def mapping_wrapped(mapping: Mapping, source: Plane3, target: Plane3) -> Mapping | None {
    hinge = source.normal.cross(target.normal);
    if hinge.length() < 0.0001 {
        return None;
    }
    along = hinge.normalized();
    angle = math.atan2(hinge.length(), source.normal.dot(target.normal));
    # A point on both planes, to turn about: where the hinge line passes
    # nearest the origin.
    between = source.normal.dot(target.normal);
    span = 1.0 - between * between;
    first = (source.dist - target.dist * between) / span;
    second = (target.dist - source.dist * between) / span;
    pivot = source.normal.scale(first).add(target.normal.scale(second));
    return mapping_carried(
        mapping, pivot, spun_about(mapping.s_axis, along, angle), spun_about(mapping.t_axis, along, angle)
    );
}

"""Whether a mapping's two axes run nearly the same way, or it has no scale:
a material laid like that is smeared into a line."""
def mapping_bad(mapping: Mapping) -> bool {
    if abs(mapping.s_scale) < 0.0001 or abs(mapping.t_scale) < 0.0001 {
        return True;
    }
    s_long = mapping.s_axis.length();
    t_long = mapping.t_axis.length();
    if s_long < 0.0001 or t_long < 0.0001 {
        return True;
    }
    return mapping.s_axis.cross(mapping.t_axis).length() / (s_long * t_long) < 0.05;
}
