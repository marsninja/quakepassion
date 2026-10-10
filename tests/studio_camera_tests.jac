import math;
import from engine.math.vec3 { Vec3 }
import from editor.ui.canvas { Rect }
import from editor.camera { EditCamera, ray_enters_box }

def near(a: float, b: float) -> bool {
    return abs(a - b) < 0.0001;
}

test "the camera's axes are forward, right and up in a z-up world" {
    camera = EditCamera();
    assert near(camera.forward().x, 1.0) and near(camera.right().y, -1.0) and near(camera.up().z, 1.0);
    camera.turn(math.pi * 0.5, 0.0);
    assert near(camera.forward().y, 1.0) and near(camera.right().x, 1.0);
    camera.turn(0.0, 10.0);
    assert camera.pitch < math.pi * 0.5;
    camera = EditCamera(eye=Vec3(x=10.0));
    camera.fly(5.0, 2.0, 3.0);
    assert near(camera.eye.x, 15.0) and near(camera.eye.y, -2.0) and near(camera.eye.z, 3.0);
}

test "the ray through a point of the view lands back on that point" {
    view = Rect(x=260, y=60, w=640, h=480);
    camera = EditCamera(eye=Vec3(x=100.0, y=-50.0, z=30.0), yaw=0.7, pitch=-0.3, fov=70.0);
    center = camera.ray(view, 260 + 320, 60 + 240);
    assert near(center.x, camera.forward().x) and near(center.z, camera.forward().z);
    for (x, y) in [(260, 60), (899, 539), (400, 500), (700, 100)] {
        point = camera.eye.add(camera.ray(view, x, y).scale(300.0));
        seen = camera.project(view, point);
        assert seen is not None and abs(seen[0] - x) <= 1 and abs(seen[1] - y) <= 1;
    }
    # The top edge of the view is half the view angle above the line of sight.
    top = camera.ray(view, 580, 60);
    angle = math.degrees(math.acos(max(-1.0, min(1.0, top.dot(camera.forward())))));
    assert abs(angle - 35.0) < 0.01;
    assert camera.project(view, camera.eye.sub(camera.forward().scale(50.0))) is None;
}

test "framing backs the camera off until the ball fits" {
    camera = EditCamera(yaw=1.0, pitch=-0.4, fov=60.0);
    center = Vec3(x=500.0, y=200.0, z=64.0);
    camera.frame(center, 100.0);
    away = center.sub(camera.eye);
    assert near(away.normalized().dot(camera.forward()), 1.0);
    assert near(away.length(), 100.0 / math.sin(math.radians(30.0)) * 1.2);
}

test "a ray enters a box at its near face, misses beside it and starts inside at zero" {
    low = Vec3(x=10.0, y=-5.0, z=-5.0);
    high = Vec3(x=20.0, y=5.0, z=5.0);
    assert near(ray_enters_box(Vec3(), Vec3(x=1.0), low, high), 10.0);
    assert ray_enters_box(Vec3(), Vec3(x=-1.0), low, high) < 0.0;
    assert ray_enters_box(Vec3(y=6.0), Vec3(x=1.0), low, high) < 0.0;
    assert near(ray_enters_box(Vec3(x=15.0), Vec3(z=1.0), low, high), 0.0);
    slanted = Vec3(x=1.0, y=0.4).normalized();
    hit = ray_enters_box(Vec3(), slanted, low, high);
    assert near(hit * slanted.x, 10.0);
}
