import math;
import from engine.math.vec3 { Vec3 }
import from engine.math.orientation { model_basis }

test "model frames preserve lengths handedness and inverse across pitch and roll" {
    value = Vec3(x=7.0, y=-3.0, z=11.0);
    for yaw in [0.0, 0.7, -2.0] {
        for pitch in [0.0, 0.9, -1.57079632679] {
            for roll in [0.0, 1.2, -2.5] {
                basis = model_basis(yaw, pitch, roll);
                result = basis.apply(value);
                assert abs(result.length() - value.length()) < 0.000001;
                assert basis.inverse(result).sub(value).length() < 0.000001;
                assert abs(basis.forward.dot(basis.left)) < 0.000001;
                assert basis.forward.cross(basis.left).sub(basis.up).length()
                    < 0.000001;
            }
        }
    }
    up = model_basis(0.0, math.pi / 2.0).apply(Vec3(x=1.0));
    assert up.sub(Vec3(z=1.0)).length() < 0.000001;
}
