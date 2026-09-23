import from engine.world.navigation { ground_route, walk_edge }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "a visible passage narrower than the actor is not a ground route" {
    collision = CollisionMap();
    mins = Vec3(x=-16.0, y=-16.0, z=-24.0);
    maxs = Vec3(x=16.0, y=16.0, z=32.0);
    collision.add_box(
        Vec3(x=-100.0, y=-100.0, z=-40.0), Vec3(x=250.0, y=100.0), Vec3(), mins, maxs
    );
    collision.add_box(
        Vec3(x=60.0, y=12.0), Vec3(x=100.0, y=200.0, z=120.0), Vec3(), mins, maxs
    );
    collision.add_box(
        Vec3(x=60.0, y=-200.0), Vec3(x=100.0, y=-12.0, z=120.0), Vec3(), mins, maxs
    );
    start = Vec3(z=24.03125);
    finish = Vec3(x=192.0, z=24.03125);
    assert collision.trace_point(start, finish).fraction == 1.0;
    assert walk_edge(collision, start, finish) is None;
    assert not ground_route(collision, start, finish, 32);
}

test "ground connections cannot step into insufficient headroom" {
    collision = CollisionMap();
    mins = Vec3(x=-16.0, y=-16.0, z=-24.0);
    maxs = Vec3(x=16.0, y=16.0, z=32.0);
    collision.add_box(
        Vec3(x=-100.0, y=-100.0, z=-40.0), Vec3(x=250.0, y=100.0), Vec3(), mins, maxs
    );
    collision.add_box(
        Vec3(x=40.0, y=-100.0, z=48.0),
        Vec3(x=120.0, y=100.0, z=100.0),
        Vec3(),
        mins,
        maxs
    );
    assert walk_edge(collision, Vec3(z=24.03125), Vec3(x=160.0, z=24.03125)) is None;
}
