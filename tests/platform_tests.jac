import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.world { Player }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }


def platform_fixture(game: str = "q2", named: bool = False) -> DoorFixture {
    fixture = DoorFixture();
    fixture.setup(
        game,
        {
            "classname": "func_plat",
            "height": "64",
            "speed": "64",
            "targetname": "lift" if named else ""
        }
    );
    return fixture;
}

def ride(fixture: DoorFixture, player: Player, dt: float) {
    fixture.world spawn DoorTick(
        bsp=fixture.bsp,
        collision=fixture.collision,
        player_origin=player.pos.sub(Vec3(z=fixture.collision.eye_height)),
        player=player,
        dt=dt
    );
}

test "all three games share platform carrying up and down without drift" {
    for game in ["q1", "q2", "q3"] {
        fixture = platform_fixture(game);
        platform = [fixture.world->:HasDoor:->][?:Door][0];
        assert platform.enabled and platform.kind == "platform";
        assert fixture.collision.offsets[0].z == -64.0;
        player = Player(pos=Vec3(z=56.03125 + fixture.collision.eye_height));
        before = player.pos.z;
        ride(fixture, player, 0.0);
        assert platform.position == 0.0 and player.pos.z == before;
        # Q2 plats ramp up and down (Think_AccelMove) and take 1.2 s here.
        for i in range(6) {
            if platform.state != "open" {
                ride(fixture, player, 0.25);
            }
        }
        assert platform.position == 1.0 and platform.state == "open";
        assert abs(player.pos.z - before - 64.0) < 0.00001;
        assert fixture.bsp.faces[0].motion.z == 0.0;
        ride(fixture, player, 10.0);
        assert platform.state == "open";
        player.pos.x = 500.0;
        ride(fixture, player, 10.0);
        assert platform.state == "closing";
        player.pos.x = 0.0;
        for i in range(6) {
            if platform.state != "closed" {
                ride(fixture, player, 0.25);
            }
        }
        assert platform.position == 0.0 and platform.state == "closed";
        assert abs(player.pos.z - before) < 0.00001;
        assert fixture.collision.offsets[0].z == -64.0;
        assert fixture.bsp.faces[0].motion.z == -64.0;
    }
}

test "a blocked rider reverses the platform without partially moving anything" {
    fixture = platform_fixture();
    platform = [fixture.world->:HasDoor:->][?:Door][0];
    fixture.collision.add_brush(
        [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=-1.0),
            Vec3(z=1.0)
        ],
        [100.0, 100.0, 100.0, 100.0, -100.0, 200.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    fixture.collision.models.append(0);
    fixture.collision.reindex();
    player = Player(pos=Vec3(z=56.03125 + fixture.collision.eye_height));
    before = player.pos.z;
    ride(fixture, player, 0.5);
    assert player.pos.z == before and platform.position == 0.0;
    assert platform.state == "closing";
    assert fixture.collision.offsets[0].z == -64.0;
    assert fixture.bsp.faces[0].motion.z == -64.0;
}

test "named Q1 and Q2 platforms unlock downward while Q3 starts at the bottom" {
    for game in ["q1", "q2", "q3"] {
        fixture = platform_fixture(game, named=True);
        platform = [fixture.world->:HasDoor:->][?:Door][0];
        assert not platform.automatic;
        if game == "q3" {
            assert platform.position == 0.0;
        } else {
            assert platform.state == "locked" and platform.position == 1.0;
        }
        platform.activation.pending = 1;
        fixture.tick(Vec3(x=500.0), 0.25);
        # Q2's ramp sits still for a frame, then covers 5 and 3.2 units.
        expected = 0.25 if game == "q3" else (0.871875 if game == "q2" else 0.75);
        assert abs(platform.position - expected) < 0.00001;
    }
}

test "jumping players are not attached to a moving platform" {
    fixture = platform_fixture();
    player = Player(
        pos=Vec3(z=56.03125 + fixture.collision.eye_height), velocity=Vec3(z=270.0)
    );
    before = player.pos.z;
    ride(fixture, player, 0.05);
    assert player.pos.z == before and player.velocity.z == 270.0;
}


test "a crouched rider follows the same platform displacement" {
    fixture = platform_fixture("q2");
    fixture.collision.top_drop = 28.0;
    fixture.collision.eye_height = -2.0;
    player = Player(pos=Vec3(z=54.03125), crouched=True);
    before = player.pos.z;
    for i in range(5) {
        ride(fixture, player, 0.25);
    }
    assert abs(player.pos.z - before - 64.0) < 0.00001;
    assert player.crouched and fixture.collision.top_drop == 28.0;
}
