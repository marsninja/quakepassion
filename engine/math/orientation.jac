"""Orthonormal model frames: local +X forward, +Y left and +Z up."""
import math;
import from .vec3 { Vec3, forward_from, right_from }

obj Basis {
    has forward: Vec3,
        left: Vec3,
        up: Vec3;

    def apply(value: Vec3) -> Vec3 {
        return self.forward.scale(value.x).add(self.left.scale(value.y)).add(
            self.up.scale(value.z)
        );
    }

    def inverse(value: Vec3) -> Vec3 {
        return Vec3(
            x=value.dot(self.forward), y=value.dot(self.left), z=value.dot(self.up)
        );
    }
}

def model_basis(yaw: float, pitch: float, roll: float = 0.0) -> Basis {
    forward = forward_from(yaw, pitch);
    left = right_from(yaw).scale(-1.0);
    up = forward.cross(left);
    return Basis(
        forward=forward,
        left=left.scale(math.cos(roll)).add(up.scale(math.sin(roll))),
        up=up.scale(math.cos(roll)).sub(left.scale(math.sin(roll)))
    );
}

"""Quake `[pitch, yaw, roll]` degrees (AngleVectors: positive pitch looks down)."""
def quake_basis(angles: Vec3) -> Basis {
    return model_basis(
        math.radians(angles.y), -math.radians(angles.x), math.radians(angles.z)
    );
}
