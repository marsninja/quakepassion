import math;
import from engine.math.vec3 { Vec3 }
import from editor.compile.spot { Cone, mangle_aim, cone_half, spot_cone, square_to, cone_rim, cone_through }

def close(a: Vec3 | None, b: Vec3) -> bool {
    return a is not None and a.sub(b).length() < 0.0001;
}

test "a mangle is yaw and pitch, and a cone's half angle is kept within bounds" {
    assert close(mangle_aim("0 0 0"), Vec3(x=1.0)) and close(mangle_aim("90 0 0"), Vec3(y=1.0));
    assert close(mangle_aim("0 -90 0"), Vec3(z=-1.0)) and close(mangle_aim("45 0"), Vec3(x=math.sqrt(0.5), y=math.sqrt(0.5)));
    assert mangle_aim("up") is None and mangle_aim("90") is None;
    assert cone_half({}) == 20.0 and cone_half({"_cone": "35"}) == 35.0 and cone_half({"_cone": "0"}) == 1.0;
    assert cone_half({"_cone": "170"}) == 85.0 and cone_half({"_cone": "wide"}) == 20.0;
}

test "a light is a spot when it has something to aim at or a mangle" {
    lamp = Vec3(z=100.0);
    assert spot_cone({}, lamp, None) is None;
    aimed = spot_cone({"_cone": "30"}, lamp, Vec3());
    assert aimed is not None and close(aimed.aim, Vec3(z=-1.0)) and aimed.half == 30.0;
    turned = spot_cone({"mangle": "0 0 0"}, lamp, None);
    assert turned is not None and close(turned.aim, Vec3(x=1.0)) and turned.half == 20.0;
    # A target where the light itself is says nothing of a way; a mangle that is not numbers neither.
    assert spot_cone({}, lamp, lamp) is None and spot_cone({"mangle": "down"}, lamp, None) is None;
    # The target has the say over the mangle.
    both = spot_cone({"mangle": "0 0 0"}, lamp, Vec3());
    assert both is not None and close(both.aim, Vec3(z=-1.0));
}

test "a cone lights what is inside it, half lights its rim and leaves the rest dark" {
    cone = Cone(aim=Vec3(z=-1.0), half=30.0);
    lamp = Vec3(z=100.0);
    assert cone.share(lamp, Vec3()) == 2 and cone.share(lamp, lamp) == 2;
    # 100 below and as far out as the tangent of the angle off says.
    assert cone.share(lamp, Vec3(x=100.0 * math.tan(math.radians(25.0)))) == 2;
    assert cone.share(lamp, Vec3(x=100.0 * math.tan(math.radians(30.0)))) == 1;
    assert cone.share(lamp, Vec3(x=100.0 * math.tan(math.radians(40.0)))) == 0;
    assert cone.share(lamp, Vec3(z=200.0)) == 0;
}

test "a cone's rim is round its way, and a point says how wide a cone through it is" {
    cone = Cone(aim=Vec3(z=-1.0), half=45.0);
    rim = cone_rim(Vec3(z=100.0), cone, 100.0, 8);
    assert len(rim) == 8;
    for point in rim {
        assert abs(point.z) < 0.0001 and abs(math.sqrt(point.x * point.x + point.y * point.y) - 100.0) < 0.001;
    }
    assert abs(cone_through(Vec3(z=100.0), Vec3(z=-1.0), Vec3(x=100.0)) - 45.0) < 0.001;
    assert cone_through(Vec3(z=100.0), Vec3(z=-1.0), Vec3(z=300.0)) == 85.0 and cone_through(Vec3(), Vec3(z=-1.0), Vec3(z=-5.0)) == 1.0;
    assert close(square_to(Vec3(z=-1.0), Vec3(x=1.0)), Vec3(x=1.0)) and abs(square_to(Vec3(x=1.0), Vec3(x=1.0)).x) < 0.0001;
}
