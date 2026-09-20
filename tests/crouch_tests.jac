import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { SetStance, MovePlayer }
import from engine.world.world { Player, World }
import from engine.world.triggers { TouchTrigger, HasTrigger, TriggerTick }
import from engine.world.traversal {
    Traversal,
    Destination,
    ArrivesAt,
    HasTraversal,
    TraversalTick
}
import from engine.math.vec3 { Vec3 }


def corridor(game: str) -> CollisionMap {
    map = CollisionMap(eye_height=26.0 if game == "q3" else 22.0);
    mins = Vec3(x=-16.0, y=-16.0, z=-24.0);
    maxs = Vec3(x=16.0, y=16.0, z=32.0);
    map.add_box(
        Vec3(x=-500.0, y=-100.0, z=-10.0), Vec3(x=500.0, y=100.0), Vec3(), mins, maxs
    );
    map.add_box(
        Vec3(x=0.0, y=-100.0, z=45.0),
        Vec3(x=100.0, y=100.0, z=100.0),
        Vec3(),
        mins,
        maxs
    );
    map.reindex();
    return map;
}

test "crouching clears a low tunnel and cannot stand inside its ceiling" {
    for game in ["q2", "q3"] {
        collision = corridor(game);
        origin = Vec3(x=-40.0, z=24.03125);
        player = Player(pos=origin.add(Vec3(z=collision.eye_height)));
        assert collision.trace(origin, origin.add(Vec3(x=100.0))).fraction < 1.0;
        player spawn SetStance(collision=collision, game=game, crouch=True, dt=0.01);
        assert player.crouched;
        assert player.pos.sub(Vec3(z=collision.eye_height)).sub(origin).length()
            < 0.00001;
        assert collision.trace(origin, origin.add(Vec3(x=100.0))).fraction == 1.0;
        player.pos.x = 40.0;
        player spawn SetStance(collision=collision, game=game, crouch=False, dt=0.01);
        assert player.crouched;
        player.pos.x = 200.0;
        player spawn SetStance(collision=collision, game=game, crouch=False, dt=0.01);
        assert not player.crouched and collision.top_drop == 0.0;
        assert abs(player.pos.z - origin.z - collision.eye_height) < 0.00001;
    }
}

test "paused stance and Q1 do not resize the player" {
    collision = corridor("q2");
    player = Player(pos=Vec3(x=-40.0, z=46.03125));
    player spawn SetStance(collision=collision, game="q2", crouch=True, dt=0.0);
    assert not player.crouched and collision.eye_height == 22.0;
    player spawn SetStance(collision=collision, game="q1", crouch=True, dt=0.01);
    assert not player.crouched and collision.top_drop == 0.0;
}

test "shortened patch sweeps match a directly expanded crouching hull" {
    standing = CollisionMap();
    duck = CollisionMap();
    a = Vec3(x=-100.0, y=-100.0, z=40.0);
    b = Vec3(x=100.0, y=-100.0, z=60.0);
    c = Vec3(y=100.0, z=50.0);
    mins = Vec3(x=-15.0, y=-15.0, z=-24.0);
    standing.add_triangle(a, b, c, mins, Vec3(x=15.0, y=15.0, z=32.0), Vec3());
    duck.add_triangle(a, b, c, mins, Vec3(x=15.0, y=15.0, z=16.0), Vec3());
    for z in [10.0, 20.0, 30.0, 40.0] {
        start = Vec3(x=-80.0, z=z);
        finish = Vec3(x=80.0, z=z);
        expected = duck.trace(start, finish);
        actual = standing.trace(start, finish, top_drop=16.0);
        assert actual.start_solid == expected.start_solid;
        assert abs(actual.fraction - expected.fraction) < 0.00001;
    }
}

test "overhead touch triggers respect the shorter body" {
    world = World();
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-10.0, y=-10.0, z=45.0),
        Vec3(x=10.0, y=10.0, z=55.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    trigger = TouchTrigger(model=1, volume=volume, interval=0.1);
    world +>:HasTrigger:+> trigger;
    world spawn TriggerTick(
        start=Vec3(z=24.0), finish=Vec3(z=24.0), dt=0.01, top_drop=28.0
    );
    assert trigger.activations == 0;
    world spawn TriggerTick(start=Vec3(z=24.0), finish=Vec3(z=24.0), dt=0.01);
    assert trigger.activations == 1;
}

test "crouched teleport arrival checks the same shortened hull" {
    world = World();
    collision = corridor("q2");
    player = Player(pos=Vec3(x=-40.0, z=46.03125));
    player spawn SetStance(collision=collision, game="q2", crouch=True, dt=0.01);
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-100.0, y=-100.0, z=-100.0),
        Vec3(x=100.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    portal = Traversal(kind="teleport", volume=volume);
    portal +>:ArrivesAt:+> Destination(origin=Vec3(x=40.0, z=24.03125), exit_speed=0.0);
    world +>:HasTraversal:+> portal;
    world spawn TraversalTick(
        player=player, collision=collision, start=Vec3(x=-40.0, z=24.03125), dt=0.01
    );
    assert portal.activations == 1 and player.pos.x == 40.0;
    player spawn SetStance(collision=collision, game="q2", crouch=False, dt=0.01);
    assert player.crouched;
}
