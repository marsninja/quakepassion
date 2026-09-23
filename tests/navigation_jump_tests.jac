import from engine.world.navigation { JumpProbe, RouteSearch, RouteQueue }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

def jump_gap() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(Vec3(x=-100.0, y=-100.0, z=-40.0), Vec3(x=20.0, y=100.0), Vec3(), Vec3(), Vec3());
    collision.add_box(Vec3(x=60.0, y=-100.0, z=-40.0), Vec3(x=200.0, y=100.0), Vec3(), Vec3(), Vec3());
    return collision;
}

test "arena flight validation crosses a supported gap incrementally" {
    collision = jump_gap();
    probe = JumpProbe(start=Vec3(z=0.03125), finish=Vec3(x=96.0, z=0.03125));
    for i in range(100) {
        before = probe.steps;
        probe.advance(collision);
        assert probe.steps <= before + 1;
        if probe.done { break; }
    }
    assert probe.done and probe.reached is not None;
    assert abs(probe.reached.x - 96.0) < 16.0;
}

test "arena flights reject a ceiling above the gap" {
    collision = jump_gap();
    collision.add_box(Vec3(x=-100.0, y=-100.0, z=20.0), Vec3(x=200.0, y=100.0, z=50.0), Vec3(), Vec3(), Vec3());
    probe = JumpProbe(start=Vec3(z=0.03125), finish=Vec3(x=96.0, z=0.03125));
    while not probe.done { probe.advance(collision); }
    assert probe.reached is None;
}

test "only arena searches produce jump actions across a gap" {
    collision = jump_gap();
    walk = RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=96.0, z=0.03125), collision=collision, budget=8);
    while not walk.done { walk.advance(); }
    assert not walk.result;
    jump = RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=96.0, z=0.03125), collision=collision, allow_jumps=True, budget=8);
    queue = RouteQueue(jobs=[jump]);
    for i in range(2000) {
        queue.advance(12);
        if jump.done { break; }
    }
    assert jump.done and jump.result;
    assert any([launch.z > 0.0 for launch in jump.launches]);
}
