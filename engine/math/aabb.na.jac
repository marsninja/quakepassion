"""Axis-aligned bounding box. Method bodies live in impl/aabb.na.impl.jac."""

import from .vec3 { Vec3 }


obj AABB {
    has mins: Vec3,
        maxs: Vec3;

    def contains(p: Vec3) -> bool;
    def center() -> Vec3;
    def size() -> Vec3;
}
