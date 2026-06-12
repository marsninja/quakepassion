"""3D vector math. Pure objects, pure speed — no OSP here on purpose."""

import math;


obj Vec3 {
    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0;

    def add(o: Vec3) -> Vec3 {
        return Vec3(x=self.x + o.x, y=self.y + o.y, z=self.z + o.z);
    }

    def sub(o: Vec3) -> Vec3 {
        return Vec3(x=self.x - o.x, y=self.y - o.y, z=self.z - o.z);
    }

    def scale(s: float) -> Vec3 {
        return Vec3(x=self.x * s, y=self.y * s, z=self.z * s);
    }

    def dot(o: Vec3) -> float {
        return self.x * o.x + self.y * o.y + self.z * o.z;
    }

    def cross(o: Vec3) -> Vec3 {
        return Vec3(
            x=self.y * o.z - self.z * o.y,
            y=self.z * o.x - self.x * o.z,
            z=self.x * o.y - self.y * o.x
        );
    }

    def length() -> float {
        return math.sqrt(self.dot(self));
    }

    def normalized() -> Vec3 {
        l = self.length();
        if l < 0.000001 {
            return Vec3();
        }
        return self.scale(1.0 / l);
    }

    def lerp(o: Vec3, t: float) -> Vec3 {
        return self.add(o.sub(self).scale(t));
    }
}


"""Forward vector from yaw/pitch in radians. Z-up, Quake-style: yaw 0 looks down +X."""
def forward_from(yaw: float, pitch: float) -> Vec3 {
    cp = math.cos(pitch);
    return Vec3(
        x=math.cos(yaw) * cp,
        y=math.sin(yaw) * cp,
        z=math.sin(pitch)
    );
}


"""Right vector for a given yaw (z-up)."""
def right_from(yaw: float) -> Vec3 {
    return Vec3(x=math.sin(yaw), y=-math.cos(yaw), z=0.0);
}
