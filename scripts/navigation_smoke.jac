"""Exercise native graph route search and collision-aware pursuit."""
import from engine.world.navigation { ground_route, walk_edge }
import from engine.physics.collision { CollisionMap }
import from engine.world.combat { Opponent, HasOpponent, CombatTick, CombatState }
import from engine.world.world { World, Player }
import from engine.math.vec3 { Vec3 }

with entry {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-500.0, y=-500.0, z=-40.0),
        Vec3(x=500.0, y=500.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    collision.add_box(
        Vec3(x=60.0, y=-80.0), Vec3(x=100.0, y=80.0, z=120.0), Vec3(), Vec3(), Vec3()
    );
    start = Vec3(z=0.03125);
    finish = Vec3(x=192.0, z=0.03125);
    route = ground_route(collision, start, finish);
    assert len(route) > 1;
    previous = start;
    for point in route {
        assert walk_edge(collision, previous, point) is not None;
        previous = point;
    }
    world = World();
    player = Player(pos=finish.add(Vec3(z=22.0)));
    enemy = Opponent(
        pos=start.add(Vec3(z=22.0)),
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
    print("NATIVE NAVIGATION PASS", enemy.pos.x, enemy.pos.y);
}
