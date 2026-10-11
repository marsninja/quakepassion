"""Faces put right: laid through whole points, where a map's planes have
drifted a hair off them, and tilted to whole angles."""

import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side, Plane3, plane_through, brush_windings, side_on }

def:priv near_whole(value: float) -> float {
    nearest = float(round(value));
    return nearest if abs(value - nearest) < 0.0000001 else value;
}

"""A point with each number put on a grid."""
def:priv on_grid(point: Vec3, grid: float) -> Vec3 {
    return Vec3(
        x=float(round(point.x / grid)) * grid, y=float(round(point.y / grid)) * grid, z=float(round(point.z / grid)) * grid
    );
}

"""The plane through the three of some points that are farthest apart,
facing the way `facing` does. None when they lie in a line."""
def:priv plane_of(points: list[Vec3], facing: Vec3) -> Plane3 | None {
    if len(points) < 3 {
        return None;
    }
    first = points[0];
    second = first;
    for point in points {
        if point.sub(first).length() > second.sub(first).length() {
            second = point;
        }
    }
    third = first;
    widest = 0.0;
    for point in points {
        spread = second.sub(first).cross(point.sub(first)).length();
        if spread > widest {
            widest = spread;
            third = point;
        }
    }
    if widest < 0.0001 {
        return None;
    }
    found = plane_through(first, second, third);
    if found is None {
        return None;
    }
    return found if found.normal.dot(facing) > 0.0 else found.flipped();
}

"""How far, at most, a corner of a brush's chosen faces is from a grid."""
def faces_astray(sides: list[Side], chosen: list[int], grid: float = 1.0) -> float {
    step = grid if grid > 0.0 else 1.0;
    outlines = brush_windings(sides);
    worst = 0.0;
    for index in chosen {
        if index < 0 or index >= len(outlines) {
            continue;
        }
        for corner in outlines[index] {
            worst = max(worst, on_grid(corner, step).sub(corner).length());
        }
    }
    return worst;
}

"""A brush's sides with the chosen faces laid through whole points: each
face's corners are put on the grid and the face goes through them, its
material lying as it did. A face whose corners then fall in a line is left
as it is."""
def sides_integral(sides: list[Side], chosen: list[int], grid: float = 1.0) -> list[Side] {
    step = grid if grid > 0.0 else 1.0;
    outlines = brush_windings(sides);
    made = list(sides);
    for index in chosen {
        if index < 0 or index >= len(sides) or len(outlines[index]) < 3 {
            continue;
        }
        laid = plane_of([on_grid(corner, step) for corner in outlines[index]], sides[index].plane.normal);
        if laid is None {
            continue;
        }
        whole = Plane3(
            normal=Vec3(x=near_whole(laid.normal.x), y=near_whole(laid.normal.y), z=near_whole(laid.normal.z)),
            dist=near_whole(laid.dist)
        );
        was = sides[index].plane;
        if whole.normal.sub(was.normal).length() < 0.000000001 and abs(whole.dist - was.dist) < 0.000000001 {
            # It lies through whole points already.
            continue;
        }
        made[index] = side_on(sides[index], whole);
    }
    return made;
}

"""A direction with its heading round the upright and its tilt from the
level each put on the nearest whole step of degrees."""
def normal_snapped(normal: Vec3, step: float = 15.0) -> Vec3 {
    long = normal.length();
    if long < 0.000001 or step <= 0.0 {
        return normal;
    }
    unit = normal.scale(1.0 / long);
    tilt = math.degrees(math.asin(max(-1.0, min(1.0, unit.z))));
    heading = math.degrees(math.atan2(unit.y, unit.x));
    tilt = float(round(tilt / step)) * step;
    heading = float(round(heading / step)) * step;
    level = math.cos(math.radians(tilt));
    return Vec3(
        x=near_whole(level * math.cos(math.radians(heading)) * 1000000.0) / 1000000.0,
        y=near_whole(level * math.sin(math.radians(heading)) * 1000000.0) / 1000000.0,
        z=near_whole(math.sin(math.radians(tilt)) * 1000000.0) / 1000000.0
    );
}

"""A brush's sides with the chosen faces tilted to whole angles: each turns
about the middle of its own outline until its heading and its tilt are
whole steps."""
def sides_angled(sides: list[Side], chosen: list[int], step: float = 15.0) -> list[Side] {
    outlines = brush_windings(sides);
    made = list(sides);
    for index in chosen {
        if index < 0 or index >= len(sides) or len(outlines[index]) < 3 {
            continue;
        }
        middle = Vec3();
        for corner in outlines[index] {
            middle = middle.add(corner);
        }
        middle = middle.scale(1.0 / float(len(outlines[index])));
        facing = normal_snapped(sides[index].plane.normal, step).normalized();
        if facing.sub(sides[index].plane.normal).length() < 0.0000001 {
            continue;
        }
        made[index] = side_on(sides[index], Plane3(normal=facing, dist=facing.dot(middle)));
    }
    return made;
}
