import from engine.world.combat {
    Opponent,
    HasOpponent,
    CombatTick,
    CombatState,
    Aim,
    actor_fraction
}
import from engine.world.world { World, Player }
import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { SetStance }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }
import from engine.world.doors { Door, HasDoor }

test "player crouching does not move a grounded enemy vertically" {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-500.0, y=-500.0, z=-40.0),
        Vec3(x=500.0, y=500.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    player = Player(pos=Vec3(x=300.0, z=22.03125), grounded=True);
    enemy = Opponent(pos=Vec3(z=22.03125), grounded=True, attack_wait=1000.0);
    world = World();
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    player spawn SetStance(collision=collision, game="q2", crouch=True, dt=0.01);
    assert collision.eye_height == -2.0;
    for i in range(120) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=1.0 / 120.0
        );
    }
    assert abs(enemy.pos.z - 22.03125) < 0.001;
    assert collision.eye_height == -2.0 and collision.top_drop == 28.0;
}

test "enemy hit bounds stay fixed when the shooter crouches" {
    world = World();
    enemy = Opponent(pos=Vec3(x=100.0, z=22.0));
    world +>:HasOpponent:+> enemy;
    query = world spawn Aim(
        start=Vec3(z=-12.0), finish=Vec3(x=200.0, z=-12.0), height=-2.0
    );
    assert query.target == enemy;
    # The player's crouched box does reject a shot above their head.
    assert actor_fraction(
        Vec3(z=20.0), Vec3(x=200.0, z=20.0), Vec3(x=100.0, z=-2.0), -2.0, 28.0
    )
        == 1.0;
    assert actor_fraction(
        Vec3(z=0.0), Vec3(x=200.0, z=0.0), Vec3(x=100.0, z=-2.0), -2.0, 28.0
    )
        < 1.0;
}

test "body collision views preserve standing headroom and live mover offsets" {
    collision = CollisionMap(eye_height=-2.0, top_drop=28.0);
    collision.add_box(
        Vec3(x=40.0, y=-100.0, z=40.0),
        Vec3(x=100.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    body = collision.for_body(22.0);
    start = Vec3(x=0.0, z=24.03125);
    finish = Vec3(x=120.0, z=24.03125);
    assert collision.trace(start, finish).fraction == 1.0;
    assert body.trace(start, finish).fraction < 1.0;
    collision.offsets[0] = Vec3(z=100.0);
    assert body.trace(start, finish).fraction == 1.0;
    assert collision.eye_height == -2.0 and body.eye_height == 22.0;
}

test "an enemy rides a platform while the player remains crouched elsewhere" {
    fixture = DoorFixture();
    fixture.setup("q2", {"classname": "func_plat", "height": "64", "speed": "64"});
    fixture.collision.eye_height = -2.0;
    fixture.collision.top_drop = 28.0;
    enemy = Opponent(pos=Vec3(z=78.03125));
    fixture.world +>:HasOpponent:+> enemy;
    for i in range(4) {
        fixture.tick(Vec3(x=500.0), 0.25);
    }
    platform = [fixture.world->:HasDoor:->][?:Door][0];
    assert platform.position == 1.0;
    assert abs(enemy.pos.z - 142.03125) < 0.001;
    assert fixture.collision.eye_height == -2.0;
}
