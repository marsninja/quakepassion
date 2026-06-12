"""Axis-aligned bounding box."""

import from .vec3 { Vec3 }


obj AABB {
    has mins: Vec3,
        maxs: Vec3;

    def contains(p: Vec3) -> bool {
        return (
            p.x >= self.mins.x and p.x <= self.maxs.x
            and p.y >= self.mins.y and p.y <= self.maxs.y
            and p.z >= self.mins.z and p.z <= self.maxs.z
        );
    }

    def center() -> Vec3 {
        return self.mins.add(self.maxs).scale(0.5);
    }

    def size() -> Vec3 {
        return self.maxs.sub(self.mins);
    }
}
