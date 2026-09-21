import math;
import from engine.render.models { sphere_in_view }
import from engine.math.vec3 { Vec3 }

test "model bounds preserve intersecting silhouettes at frustum edges" {
    assert sphere_in_view(Vec3(x=100.0), 10.0, 0.0, 0.0, 90.0, 1.0);
    assert not sphere_in_view(Vec3(x=-100.0), 10.0, 0.0, 0.0, 90.0, 1.0);
    assert sphere_in_view(Vec3(x=-1.0), 10.0, 0.0, 0.0, 90.0, 1.0);
    assert sphere_in_view(Vec3(x=100.0, y=110.0), 10.0, 0.0, 0.0, 90.0, 1.0);
    assert not sphere_in_view(Vec3(x=100.0, y=120.0), 10.0, 0.0, 0.0, 90.0, 1.0);
    assert sphere_in_view(Vec3(y=100.0), 10.0, math.pi / 2.0, 0.0, 90.0, 1.0);
    assert sphere_in_view(Vec3(z=100.0), 10.0, 0.0, math.pi / 2.0, 90.0, 1.0);
    assert sphere_in_view(Vec3(x=100.0, y=180.0), 10.0, 0.0, 0.0, 90.0, 2.0);
}
