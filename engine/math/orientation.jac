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

"""`share` of the way from one orientation to another (no turn is the
identity), re-orthonormalised: a mover's turn between two physics ticks."""
def blend_basis(start: Basis | None, finish: Basis | None, share: float) -> Basis | None {
    if share >= 1.0 or (start is None and finish is None) {
        return finish;
    }
    a = start
        if start is not None
        else Basis(forward=Vec3(x=1.0), left=Vec3(y=1.0), up=Vec3(z=1.0));
    b = finish
        if finish is not None
        else Basis(forward=Vec3(x=1.0), left=Vec3(y=1.0), up=Vec3(z=1.0));
    forward = a.forward.lerp(b.forward, share).normalized();
    up = forward.cross(a.left.lerp(b.left, share)).normalized();
    return Basis(forward=forward, left=up.cross(forward), up=up);
}
