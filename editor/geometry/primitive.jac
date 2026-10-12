"""Quake III's own way of laying a material on a brush's side: "brush
primitives". A side keeps a matrix of two rows of three numbers. The two
ways the texture runs across the face are measured against two axes that
follow from the face's normal alone, and the matrix says how far along the
texture, in whole repeats of it, a step along each axis goes, and where it
starts. A material here lies by two axes of the world, a scale and a shift
in texels (as Valve's form has it); these turn one into the other, given
the texture's size."""
import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Plane3, Mapping, classic_mapping }

"""The two axes Quake III's tools measure a face's texture along, from the
face's normal (their ComputeAxisBase): the first lies level, the second
runs down the face."""
def primitive_base(normal: Vec3) -> list[Vec3] {
    x = 0.0 if abs(normal.x) < 0.000001 else normal.x;
    y = 0.0 if abs(normal.y) < 0.000001 else normal.y;
    z = 0.0 if abs(normal.z) < 0.000001 else normal.z;
    tilt = -math.atan2(z, math.sqrt(y * y + x * x));
    turn = math.atan2(y, x);
    return [
        Vec3(x=-math.sin(turn), y=math.cos(turn), z=0.0),
        Vec3(x=-math.sin(tilt) * math.cos(turn), y=-math.sin(tilt) * math.sin(turn), z=-math.cos(tilt))
    ];
}

"""How a material lies, from a side's matrix (six numbers, a row after a
row) and the texture's size. A matrix that lays the texture flat along a
line is no way to lie: the material then lies as on a new brush."""
def mapping_of_primitive(plane: Plane3, matrix: list[float], wide: int, tall: int) -> Mapping {
    base = primitive_base(plane.normal);
    across = float(max(1, wide));
    down = float(max(1, tall));
    if len(matrix) < 6 {
        return classic_mapping(plane.normal, 0.0, 0.0, 0.0, 1.0, 1.0);
    }
    first = base[0].scale(matrix[0]).add(base[1].scale(matrix[1]));
    second = base[0].scale(matrix[3]).add(base[1].scale(matrix[4]));
    if first.length() < 0.0000001 or second.length() < 0.0000001 or first.cross(second).length() < 0.0000000001 {
        return classic_mapping(plane.normal, 0.0, 0.0, 0.0, 1.0, 1.0);
    }
    return Mapping(
        s_axis=first.normalized(),
        t_axis=second.normalized(),
        s_shift=matrix[2] * across,
        t_shift=matrix[5] * down,
        s_scale=1.0 / (first.length() * across),
        t_scale=1.0 / (second.length() * down)
    );
}

"""A side's matrix, from how its material lies and the texture's size: the
same texel at every point of the face. An axis that leans out of the face
counts only by what lies in it; what it adds at the face's own distance
goes into the shift."""
def primitive_of_mapping(plane: Plane3, mapping: Mapping, wide: int, tall: int) -> list[float] {
    base = primitive_base(plane.normal);
    across = float(max(1, wide));
    down = float(max(1, tall));
    first = mapping.s_axis.scale(1.0 / ((mapping.s_scale if mapping.s_scale != 0.0 else 1.0) * across));
    second = mapping.t_axis.scale(1.0 / ((mapping.t_scale if mapping.t_scale != 0.0 else 1.0) * down));
    return [
        first.dot(base[0]),
        first.dot(base[1]),
        mapping.s_shift / across + first.dot(plane.normal) * plane.dist,
        second.dot(base[0]),
        second.dot(base[1]),
        mapping.t_shift / down + second.dot(plane.normal) * plane.dist
    ];
}

"""Where a point of a face lies on its texture by the face's matrix, in
whole repeats: what Quake III's compiler works out."""
def primitive_place(plane: Plane3, matrix: list[float], point: Vec3) -> list[float] {
    base = primitive_base(plane.normal);
    x = point.dot(base[0]);
    y = point.dot(base[1]);
    return [matrix[0] * x + matrix[1] * y + matrix[2], matrix[3] * x + matrix[4] * y + matrix[5]];
}
