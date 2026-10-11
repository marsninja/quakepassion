import math;
import from engine.math.vec3 { Vec3 }
import from editor.ui.canvas { Rect }
import from editor.camera { EditCamera, ray_enters_box, axis_camera }

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

test "the axis cameras put the level's axes where a map editor does" {
    top = axis_camera("top");
    assert near(top.forward().z, -1.0) and near(top.right().x, 1.0) and near(top.up().y, 1.0);
    front = axis_camera("front");
    assert near(front.forward().y, 1.0) and near(front.right().x, 1.0) and near(front.up().z, 1.0);
    side = axis_camera("side");
    assert near(side.forward().x, -1.0) and near(side.right().y, 1.0) and near(side.up().z, 1.0);
}

test "an orthographic view maps screen units to world units and back" {
    view = Rect(x=100, y=50, w=400, h=200);
    top = axis_camera("top", 800.0);
    top.eye = Vec3(x=64.0, y=-32.0, z=0.0);
    # 800 units across 200 screen units: four units each.
    middle = top.project(view, Vec3(x=64.0, y=-32.0, z=500.0));
    assert middle == [300, 150];
    east = top.project(view, Vec3(x=64.0 + 400.0, y=-32.0, z=-90.0));
    north = top.project(view, Vec3(x=64.0, y=-32.0 + 200.0, z=0.0));
    assert east == [400, 150] and north == [300, 100];
    line = top.sight(view, 400, 100);
    assert near(line[1].z, -1.0) and near(line[0].x, 464.0) and near(line[0].y, 168.0) and line[0].z > 10000.0;
    # The line through a point of the view lands back on it at any depth.
    for depth in [0.0, 5000.0, 20000.0] {
        seen = top.project(view, line[0].add(line[1].scale(depth)));
        assert seen == [400, 100];
    }
    # A perspective camera's lines all start at its eye.
    free = EditCamera(eye=Vec3(x=1.0, y=2.0, z=3.0));
    assert near(free.sight(view, 120, 60)[0].z, 3.0) and near(free.sight(view, 480, 240)[0].x, 1.0);
}

test "an orthographic view pans by screen units, zooms within limits and frames" {
    view = Rect(x=0, y=0, w=400, h=200);
    front = axis_camera("front", 400.0);
    front.pan(view, 50, 0);
    # Dragging right by 50 at two units each slides the view 100 to the left.
    assert near(front.eye.x, -100.0) and near(front.eye.z, 0.0);
    front.pan(view, 0, 25);
    assert near(front.eye.z, 50.0);
    front.zoom(0.5);
    assert near(front.span, 200.0);
    front.zoom(0.0001);
    assert near(front.span, 16.0);
    front.zoom(1000000.0);
    assert near(front.span, 65536.0);
    front.frame(Vec3(x=10.0, y=20.0, z=30.0), 100.0);
    assert near(front.eye.x, 10.0) and near(front.eye.z, 30.0) and near(front.span, 260.0);
}

test "the camera swings round a point at its distance, and faces a point from another" {
    camera = EditCamera();
    camera.look_from(Vec3(x=-192.0, y=-340.0, z=32.0), Vec3(x=-192.0, y=160.0, z=32.0));
    # Looking along +y, level.
    ahead = camera.forward();
    assert abs(ahead.x) < 0.001 and abs(ahead.y - 1.0) < 0.001 and abs(ahead.z) < 0.001;
    pivot = Vec3(x=-192.0, y=160.0, z=32.0);
    camera.orbit(pivot, math.radians(90.0), 0.0);
    # A quarter round: facing -x from the +x side, as far off as before.
    assert abs(camera.eye.x - 308.0) < 0.01 and abs(camera.eye.y - 160.0) < 0.01 and abs(camera.eye.z - 32.0) < 0.01;
    assert abs(camera.eye.sub(pivot).length() - 500.0) < 0.01;
    assert abs(camera.forward().x + 1.0) < 0.001;
    # Up over it: the pivot stays dead ahead.
    camera.orbit(pivot, 0.0, math.radians(-45.0));
    toward = pivot.sub(camera.eye).normalized();
    assert toward.sub(camera.forward()).length() < 0.001 and camera.eye.z > 300.0;
    # From below, looking up, as far as the camera tips.
    camera.look_from(Vec3(z=-100.0), Vec3(x=1.0));
    assert camera.forward().z > 0.9 and camera.eye.z == -100.0;
    # A point to face that is where it stands changes nothing.
    camera.look_from(Vec3(x=5.0), Vec3(x=5.0));
    assert camera.eye.z == -100.0;
}

test "a view held to a band of depth leaves out what lies wholly outside it" {
    top = axis_camera("top");
    low_box = [Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=64.0, y=64.0, z=32.0)];
    high_box = [Vec3(x=0.0, y=0.0, z=200.0), Vec3(x=64.0, y=64.0, z=232.0)];
    # Not held to a band, a view shows everything.
    assert not top.out_of_depth(low_box[0], low_box[1]) and not top.out_of_depth(high_box[0], high_box[1]);
    top.bounded = True;
    top.depth_low = -32.0;
    top.depth_high = 64.0;
    axis = top.depth_axis();
    assert axis.z == 1.0 and axis.x == 0.0;
    assert not top.out_of_depth(low_box[0], low_box[1]) and top.out_of_depth(high_box[0], high_box[1]);
    # What only reaches into the band is in it.
    assert not top.out_of_depth(Vec3(z=48.0), Vec3(x=8.0, y=8.0, z=400.0));
    assert top.out_of_depth(Vec3(z=-200.0), Vec3(x=8.0, y=8.0, z=-40.0));
    # The side view looks along -x: its band is still in the world's x.
    side = axis_camera("side");
    side.bounded = True;
    side.depth_low = 100.0;
    side.depth_high = 300.0;
    assert side.depth_axis().x == 1.0;
    assert side.out_of_depth(low_box[0], low_box[1]) and not side.out_of_depth(Vec3(x=250.0), Vec3(x=260.0, y=8.0, z=8.0));
    # A camera with perspective has no band.
    free = EditCamera(bounded=True, depth_low=0.0, depth_high=1.0);
    assert not free.out_of_depth(high_box[0], high_box[1]);
}

test "an orthographic view turned off the axes is oblique, and measures depth along its sight" {
    top = axis_camera("top");
    front = axis_camera("front");
    assert not top.oblique() and not front.oblique() and not axis_camera("side").oblique();
    assert not EditCamera(yaw=0.7, pitch=-0.4).oblique();
    front.turn(math.radians(45.0), math.radians(-30.0));
    assert front.oblique();
    axis = front.depth_axis();
    ahead = front.forward();
    assert abs(axis.x - ahead.x) < 0.0001 and abs(axis.z - ahead.z) < 0.0001;
    front.bounded = True;
    front.depth_low = -50.0;
    front.depth_high = 50.0;
    # A box about the origin is in the band; one far along the line of sight is not.
    assert not front.out_of_depth(Vec3(x=-8.0, y=-8.0, z=-8.0), Vec3(x=8.0, y=8.0, z=8.0));
    far = ahead.scale(400.0);
    assert front.out_of_depth(far.sub(Vec3(x=8.0, y=8.0, z=8.0)), far.add(Vec3(x=8.0, y=8.0, z=8.0)));
}
