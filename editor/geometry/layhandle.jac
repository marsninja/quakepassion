"""Handles that lie on a face and say how its material lies there: a dot,
and from the dot an arm along each of the two ways the material runs, each
as long as one repeat of it. Taking the dot somewhere slides the material;
taking the end of an arm somewhere stretches the material that way and
swings that way round, the other staying as it was (so the two need not
stay square: a shear); or turns both together; or only stretches."""

import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Plane3, Mapping }
import from .mapping { mapping_through, mapping_place, mapping_slid, mapping_same }

"""Two unit vectors at right angles in the plane a normal faces."""
def:priv plane_frame(normal: Vec3) -> list[Vec3] {
    seed = Vec3(z=1.0) if abs(normal.z) < 0.9 else Vec3(x=1.0);
    first = seed.cross(normal).normalized();
    return [first, normal.cross(first)];
}

"""A vector lying in a plane, turned in it by an angle in radians
(anticlockwise seen from the side the normal points to)."""
def:priv turned_in(vector: Vec3, normal: Vec3, angle: float) -> Vec3 {
    return vector.scale(math.cos(angle)).add(normal.cross(vector).scale(math.sin(angle)));
}

"""A point dropped straight onto a plane."""
def onto_plane(plane: Plane3, point: Vec3) -> Vec3 {
    return point.sub(plane.normal.scale(plane.side(point)));
}

"""The two arms of a face's material: in the face's plane, how far and which
way a point goes for the material to run `wide` texels along its first way
and none along its second, and `tall` along its second and none along its
first. None when the material lies edge on to the face."""
def lay_arms(normal: Vec3, mapping: Mapping, wide: float, tall: float) -> list[Vec3] | None {
    frame = plane_frame(normal);
    s_scale = mapping.s_scale if mapping.s_scale != 0.0 else 1.0;
    t_scale = mapping.t_scale if mapping.t_scale != 0.0 else 1.0;
    # How fast the material runs each of its ways along each of the frame's.
    s_first = frame[0].dot(mapping.s_axis) / s_scale;
    s_second = frame[1].dot(mapping.s_axis) / s_scale;
    t_first = frame[0].dot(mapping.t_axis) / t_scale;
    t_second = frame[1].dot(mapping.t_axis) / t_scale;
    cross = s_first * t_second - s_second * t_first;
    if abs(cross) < 0.000000001 {
        return None;
    }
    return [
        frame[0].scale(wide * t_second / cross).sub(frame[1].scale(wide * t_first / cross)),
        frame[1].scale(tall * s_first / cross).sub(frame[0].scale(tall * s_second / cross))
    ];
}

"""The angle in degrees from one vector of a plane round to another."""
def swept_between(first: Vec3, second: Vec3, normal: Vec3) -> float {
    return math.degrees(math.atan2(normal.dot(first.cross(second)), first.dot(second)));
}

"""How a face's material lies once a handle on it has been taken to a place.
The handles stand at `anchor`; `part` 0 is the dot there (the material
slides with it), 1 the end of the arm along the material's first way and 2
of the arm along its second. An arm's end follows the pointer, stretching
and swinging that way alone (in steps of `turn_step` degrees when given);
`how` "turn" turns both ways together and stretches neither, and "size"
stretches the one way and swings nothing. None when nothing would change."""
def lay_dragged(
    plane: Plane3, mapping: Mapping, anchor: Vec3, sizes: list[float], part: int, toward: Vec3, how: str = "",
    turn_step: float = 0.0
) -> Mapping | None {
    arms = lay_arms(plane.normal, mapping, sizes[0], sizes[1]);
    if arms is None or part < 0 or part > 2 {
        return None;
    }
    stand = onto_plane(plane, anchor);
    goal = onto_plane(plane, toward);
    made: Mapping | None = None;
    if part == 0 {
        gone = goal.sub(stand);
        # What was under the dot is under it still, where it has gone.
        made = mapping_slid(
            mapping,
            -gone.dot(mapping.s_axis) / (mapping.s_scale if mapping.s_scale != 0.0 else 1.0),
            -gone.dot(mapping.t_axis) / (mapping.t_scale if mapping.t_scale != 0.0 else 1.0)
        );
    } else {
        held = arms[part - 1];
        other = arms[2 - part];
        reach = goal.sub(stand);
        if reach.length() < 0.01 or held.length() < 0.000001 {
            return None;
        }
        swept = swept_between(held, reach, plane.normal);
        if turn_step > 0.0 {
            swept = float(round(swept / turn_step)) * turn_step;
        }
        if how == "turn" {
            held = turned_in(held, plane.normal, math.radians(swept));
            other = turned_in(other, plane.normal, math.radians(swept));
        } elif how == "size" {
            held = held.scale(max(0.01, reach.dot(held) / held.dot(held)));
        } else {
            held = turned_in(held, plane.normal, math.radians(swept)).scale(reach.length() / held.length());
        }
        at = mapping_place(mapping, stand);
        first = held if part == 1 else other;
        second = other if part == 1 else held;
        made = mapping_through(
            [stand, stand.add(first), stand.add(second)],
            [at[0], at[1], at[0] + sizes[0], at[1], at[0], at[1] + sizes[1]]
        );
    }
    if made is None or mapping_same(made, mapping) {
        return None;
    }
    return made;
}
