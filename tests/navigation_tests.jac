import from engine.world.navigation { ground_route, walk_edge }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

def nav_box(collision: CollisionMap, lo: Vec3, hi: Vec3) {
    collision.add_box(lo, hi, Vec3(), Vec3(), Vec3());
}

def nav_floor() -> CollisionMap {
    collision = CollisionMap();
    nav_box(collision, Vec3(x=-500.0, y=-500.0, z=-40.0), Vec3(x=500.0, y=500.0));
    return collision;
}

test "ground routes detour around a wall instead of steering into it" {
    collision = nav_floor();
    nav_box(collision, Vec3(x=60.0, y=-80.0), Vec3(x=100.0, y=80.0, z=120.0));
    start = Vec3(z=0.03125);
    finish = Vec3(x=192.0, z=0.03125);
    assert walk_edge(collision, start, finish) is None;
    route = ground_route(collision, start, finish);
    assert len(route) > 1;
    previous = start;
    for point in route {
        assert walk_edge(collision, previous, point) is not None;
        previous = point;
    }
    assert previous.sub(finish).length() < 0.1;
}

test "routes reject pits even when the endpoint has support" {
    collision = CollisionMap();
    nav_box(collision, Vec3(x=-100.0, y=-100.0, z=-40.0), Vec3(x=20.0, y=100.0));
    nav_box(collision, Vec3(x=60.0, y=-100.0, z=-40.0), Vec3(x=160.0, y=100.0));
    start = Vec3(z=0.03125);
    finish = Vec3(x=96.0, z=0.03125);
    assert walk_edge(collision, start, finish) is None;
    assert not ground_route(collision, start, finish, 32);
}

test "walk edges climb normal steps and reject tall steps" {
    collision = nav_floor();
    nav_box(collision, Vec3(x=20.0, y=-100.0), Vec3(x=100.0, y=100.0, z=16.0));
    assert walk_edge(collision, Vec3(z=0.03125), Vec3(x=48.0, z=16.03125)) is not None;
    tall = nav_floor();
    nav_box(tall, Vec3(x=20.0, y=-100.0), Vec3(x=100.0, y=100.0, z=24.0));
    assert walk_edge(tall, Vec3(z=0.03125), Vec3(x=48.0, z=24.03125)) is None;
}

test "navigation budget fails closed and moving blockers invalidate edges" {
    collision = nav_floor();
    start = Vec3(z=0.03125);
    finish = Vec3(x=192.0, z=0.03125);
    assert len(ground_route(collision, start, finish)) == 1;
    nav_box(collision, Vec3(x=60.0, y=-80.0), Vec3(x=100.0, y=80.0, z=120.0));
    assert walk_edge(collision, start, finish) is None;
    assert not ground_route(collision, start, finish, 0);
}

test "alerted opponent follows the detour through actual movement ticks" {
    import from engine.world.combat { Opponent, HasOpponent, CombatTick, CombatState }
    import from engine.world.world { World, Player }
    collision = nav_floor();
    nav_box(collision, Vec3(x=60.0, y=-80.0), Vec3(x=100.0, y=80.0, z=120.0));
    world = World();
    player = Player(pos=Vec3(x=192.0, z=22.03125));
    enemy = Opponent(
        pos=Vec3(z=22.03125),
        grounded=True,
        alert=8.0,
        last_seen=player.pos,
        attack_wait=1000.0
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    for i in range(600) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=1.0 / 120.0
        );
    }
    assert enemy.pos.x > 120.0;
    assert not collision.trace(
        enemy.pos.sub(Vec3(z=22.0)), enemy.pos.sub(Vec3(z=22.0))
    ).start_solid;
}

test "projected connections can climb several individually valid stair risers" {
    collision = nav_floor();
    for i in range(4) {
        nav_box(
            collision,
            Vec3(x=8.0 + float(i) * 12.0, y=-100.0),
            Vec3(x=100.0, y=100.0, z=float(i + 1) * 8.0)
        );
    }
    start = Vec3(z=0.03125);
    projected = walk_edge(
        collision, start, Vec3(x=48.0, z=0.03125), match_height=False
    );
    assert projected is not None and projected.z > 32.0;
    assert walk_edge(collision, start, Vec3(x=48.0, z=0.03125)) is None;
    assert walk_edge(collision, start, Vec3(x=48.0, z=32.03125)) is not None;
}
