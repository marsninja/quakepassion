import from engine.world.navigation {
    RouteSearch, RouteQueue, WalkProbe, NavigationGraph, walk_edge
}
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.world.combat { CombatTick, CombatState, HasOpponent, Opponent }
import from engine.world.world { World, Player }

def budget_floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(Vec3(x=-500.0, y=-500.0, z=-40.0), Vec3(x=500.0, y=500.0), Vec3(), Vec3(), Vec3());
    return collision;
}

test "navigation queue shares a strict sample budget fairly" {
    collision = budget_floor();
    queue = RouteQueue();
    for i in range(20) {
        queue.jobs.append(RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=480.0, z=0.03125), collision=collision));
    }
    jobs = queue.jobs[:];
    queue.advance(7);
    assert queue.last_work == 7;
    assert sum([1 if job.initialized else 0 for job in jobs]) == 7;
    for i in range(3) { queue.advance(7); }
    for job in jobs { assert job.initialized; }
    queue.advance(0);
    assert queue.last_work == 0;
    for job in jobs { job.cancelled = True; }
    queue.advance();
    assert not queue.jobs and queue.last_work == 0;
}

test "incremental walk probes agree with complete stair and pit validation" {
    collision = budget_floor();
    collision.add_box(Vec3(x=20.0, y=-100.0), Vec3(x=100.0, y=100.0, z=16.0), Vec3(), Vec3(), Vec3());
    probe = WalkProbe(start=Vec3(z=0.03125), finish=Vec3(x=48.0, z=16.03125));
    for i in range(3) {
        probe.advance(collision);
        assert not probe.done;
        assert probe.index == i + 1;
    }
    probe.advance(collision);
    expected = walk_edge(collision, probe.start, probe.finish);
    assert probe.done and probe.reached is not None and expected is not None;
    assert probe.reached.sub(expected).length() < 0.001;
}

test "shared connectivity reuses probes and invalidates changed collision" {
    collision = budget_floor();
    network = NavigationGraph();
    network.refresh(collision);
    for i in range(2) {
        search = RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=192.0, z=0.03125), collision=collision, network=network);
        while not search.done { search.advance(); }
        assert len(search.result) == 1;
    }
    assert network.hits > 0;
    collision.add_box(Vec3(x=60.0, y=-500.0), Vec3(x=100.0, y=500.0, z=120.0), Vec3(), Vec3(), Vec3());
    network.refresh(collision);
    assert not network.connections;
    search = RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=192.0, z=0.03125), collision=collision, network=network, budget=8);
    while not search.done { search.advance(); }
    assert not search.result;
}

test "completed asynchronous route preserves the wall detour" {
    collision = budget_floor();
    collision.add_box(Vec3(x=60.0, y=-80.0), Vec3(x=100.0, y=80.0, z=120.0), Vec3(), Vec3(), Vec3());
    queue = RouteQueue();
    search = RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=192.0, z=0.03125), collision=collision, network=queue.network);
    queue.jobs.append(search);
    for i in range(2000) {
        queue.advance(3);
        assert queue.last_work <= 3;
        if search.done { break; }
    }
    assert search.done and len(search.result) > 1;
    pos = search.start;
    for point in search.result {
        assert walk_edge(collision, pos, point) is not None;
        pos = point;
    }
}

test "neighbor buckets include nearby actors across negative cell boundaries" {
    world = World();
    near = Opponent(pos=Vec3(x=-1.0));
    across = Opponent(pos=Vec3(x=1.0));
    distant = Opponent(pos=Vec3(x=300.0));
    world +>:HasOpponent:+> near;
    world +>:HasOpponent:+> across;
    world +>:HasOpponent:+> distant;
    tick = world spawn CombatTick(player=Player(), collision=CollisionMap(), state=CombatState(), dt=0.0, active=False);
    neighbors = tick.nearby(near.pos);
    assert near in neighbors and across in neighbors;
    assert distant not in neighbors;
}
