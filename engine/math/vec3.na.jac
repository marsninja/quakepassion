"""3D vector math. Pure objects, pure speed — no OSP here on purpose.

Method and function bodies live in impl/vec3.na.impl.jac; this file is the
declaration surface."""

import math;


obj Vec3 {
    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0;

    def add(o: Vec3) -> Vec3;
    def sub(o: Vec3) -> Vec3;
    def scale(s: float) -> Vec3;
    def dot(o: Vec3) -> float;
    def cross(o: Vec3) -> Vec3;
    def length() -> float;
    def normalized() -> Vec3;
    def lerp(o: Vec3, t: float) -> Vec3;
}


"""Forward vector from yaw/pitch in radians. Z-up, Quake-style: yaw 0 looks down +X."""
def forward_from(yaw: float, pitch: float) -> Vec3;


"""Right vector for a given yaw (z-up)."""
def right_from(yaw: float) -> Vec3;
