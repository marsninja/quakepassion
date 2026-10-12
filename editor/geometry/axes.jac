"""The three ways a handle may run: the world's, a thing's own, or as the
view sees. A thing's own are a brush's from its sides, or an entity's from
the way it faces; they are given in the order of the world's they lie
nearest, so a thing that has not been turned has the world's own."""

import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side }

"""The world's three, in order."""
def world_axes -> list[Vec3] {
    return [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)];
}

"""Three at right angles, each put where the world's axis it lies nearest
is, and turned to point the way that one does."""
def ordered_axes(found: list[Vec3]) -> list[Vec3] {
    world = world_axes();
    left = list(found);
    ordered: list[Vec3] = [];
    for which in range(3) {
        best = 0;
        for at in range(len(left)) {
            if abs(left[at].dot(world[which])) > abs(left[best].dot(world[which])) {
                best = at;
            }
        }
        taken = left.pop(best);
        ordered.append(taken.scale(-1.0) if taken.dot(world[which]) < 0.0 else taken);
    }
    return ordered;
}

"""A brush's own axes: the way its first side faces, the way of the side
most nearly square to that, and the third square to both. The world's when
the brush has no two sides to tell by."""
def brush_axes(sides: list[Side]) -> list[Vec3] {
    if len(sides) < 2 {
        return world_axes();
    }
    first = sides[0].plane.normal.normalized();
    square = sides[1].plane.normal;
    for side in sides[1:] {
        if abs(side.plane.normal.dot(first)) < abs(square.dot(first)) {
            square = side.plane.normal;
        }
    }
    # Made square to the first, whatever the brush's own slant.
    second = square.sub(first.scale(square.dot(first)));
    if second.length() < 0.001 {
        return world_axes();
    }
    second = second.normalized();
    return ordered_axes([first, second, first.cross(second).normalized()]);
}

"""An entity's own axes from the way it faces, in degrees round the
upright: ahead, to its left, and up."""
def facing_axes(degrees: float) -> list[Vec3] {
    turn = math.radians(degrees);
    ahead = Vec3(x=math.cos(turn), y=math.sin(turn));
    return ordered_axes([ahead, Vec3(x=-math.sin(turn), y=math.cos(turn)), Vec3(z=1.0)]);
}

"""A move kept to one axis: as far as it goes along the axis, in whole
steps of `step`."""
def kept_to_axis(shift: Vec3, axis: Vec3, step: float) -> Vec3 {
    gone = shift.dot(axis);
    notch = step if step > 0.0 else 1.0;
    return axis.scale(float(round(gone / notch)) * notch);
}
