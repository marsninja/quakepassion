"""Changes of the world made about ways that are not the world's own axes:
a turn about any line, and a change of size along any three ways that are
square to each other. For handles that run along a brush's own sides or as
the view sees."""

import math;
import from engine.math.vec3 { Vec3 }
import from .linear { Linear }
import from .mapping { spun_about }

"""A turn by degrees about a way of unit length, the way a right hand's
fingers curl when its thumb points along it."""
def linear_about(way: Vec3, degrees: float) -> Linear {
    angle = math.radians(degrees);
    return Linear(x=spun_about(Vec3(x=1.0), way, angle), y=spun_about(Vec3(y=1.0), way, angle), z=spun_about(Vec3(z=1.0), way, angle));
}

"""A change of size by a factor along each of three ways, of unit length
and square to each other: `factors` has the first way's in x, the second's
in y and the third's in z."""
def linear_along(ways: list[Vec3], factors: Vec3) -> Linear {
    if len(ways) != 3 {
        return Linear();
    }
    sizes = [factors.x, factors.y, factors.z];
    images: list[Vec3] = [];
    for axis in [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)] {
        image = Vec3();
        for (index, way) in enumerate(ways) {
            image = image.add(way.scale(axis.dot(way) * sizes[index]));
        }
        images.append(image);
    }
    return Linear(x=images[0], y=images[1], z=images[2]);
}

"""Whether three ways are the world's own axes, in their order."""
def world_ways(ways: list[Vec3]) -> bool {
    if len(ways) != 3 {
        return True;
    }
    return ways[0].sub(Vec3(x=1.0)).length() + ways[1].sub(Vec3(y=1.0)).length() + ways[2].sub(Vec3(z=1.0)).length() < 0.000001;
}

"""A point as a change of size along three ways about a middle leaves it."""
def point_sized(point: Vec3, middle: Vec3, ways: list[Vec3], factors: Vec3) -> Vec3 {
    return middle.add(linear_along(ways, factors).carry(point.sub(middle)));
}
