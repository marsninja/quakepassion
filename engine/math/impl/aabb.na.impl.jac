"""Implementations for the AABB object. Declarations live in aabb.na.jac."""

impl AABB.contains(p: Vec3) -> bool {
    return (
        p.x >= self.mins.x and p.x <= self.maxs.x
        and p.y >= self.mins.y and p.y <= self.maxs.y
        and p.z >= self.mins.z and p.z <= self.maxs.z
    );
}

impl AABB.center() -> Vec3 {
    return self.mins.add(self.maxs).scale(0.5);
}

impl AABB.size() -> Vec3 {
    return self.maxs.sub(self.mins);
}
