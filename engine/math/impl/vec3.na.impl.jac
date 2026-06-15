"""Implementations for the vec3 module: Vec3 methods and the yaw/pitch
basis-vector helpers. Declarations (and the `import math`) live in vec3.na.jac."""

impl Vec3.add(o: Vec3) -> Vec3 {
    return Vec3(x=self.x + o.x, y=self.y + o.y, z=self.z + o.z);
}

impl Vec3.sub(o: Vec3) -> Vec3 {
    return Vec3(x=self.x - o.x, y=self.y - o.y, z=self.z - o.z);
}

impl Vec3.scale(s: float) -> Vec3 {
    return Vec3(x=self.x * s, y=self.y * s, z=self.z * s);
}

impl Vec3.dot(o: Vec3) -> float {
    return self.x * o.x + self.y * o.y + self.z * o.z;
}

impl Vec3.cross(o: Vec3) -> Vec3 {
    return Vec3(
        x=self.y * o.z - self.z * o.y,
        y=self.z * o.x - self.x * o.z,
        z=self.x * o.y - self.y * o.x
    );
}

impl Vec3.length() -> float {
    return math.sqrt(self.dot(self));
}

impl Vec3.normalized() -> Vec3 {
    l = self.length();
    if l < 0.000001 {
        return Vec3();
    }
    return self.scale(1.0 / l);
}

impl Vec3.lerp(o: Vec3, t: float) -> Vec3 {
    return self.add(o.sub(self).scale(t));
}


impl forward_from(yaw: float, pitch: float) -> Vec3 {
    cp = math.cos(pitch);
    return Vec3(
        x=math.cos(yaw) * cp,
        y=math.sin(yaw) * cp,
        z=math.sin(pitch)
    );
}

impl right_from(yaw: float) -> Vec3 {
    return Vec3(x=math.sin(yaw), y=-math.cos(yaw), z=0.0);
}
