import from tests.door_support { DoorFixture }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.doors { Door, HasDoor }
import from engine.math.vec3 { Vec3 }

test "living enemies open automatic doors across games without player proximity" {
    for game in ["q1", "q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(game);
        enemy = Opponent(pos=Vec3(x=40.0, z=46.0));
        fixture.world +>:HasOpponent:+> enemy;
        fixture.tick(Vec3(x=500.0));
        door = [fixture.world->:HasDoor:->][?:Door][0];
        assert door.state == "opening" and door.position > 0.0;
    }
}

test "dead dormant and forbidden monsters do not trigger a door" {
    for mode in ["dead", "dormant", "nomonster", "remote"] {
        fixture = DoorFixture();
        fields: dict[str, str] = {};
        if mode == "nomonster" {
            fields["spawnflags"] = "8";
        }
        if mode == "remote" {
            fields["targetname"] = "switch";
        }
        fixture.setup("q2", fields);
        enemy = Opponent(
            pos=Vec3(x=40.0, z=46.0),
            health=0 if mode == "dead" else 100,
            dormant=mode == "dormant"
        );
        fixture.world +>:HasOpponent:+> enemy;
        fixture.tick(Vec3(x=500.0));
        door = [fixture.world->:HasDoor:->][?:Door][0];
        assert door.enabled and door.state == "closed";
        if mode == "nomonster" {
            fixture.tick(Vec3(x=40.0, z=24.0));
            assert door.state == "opening";
        }
    }
}

test "enemy contact cannot unlock a key door" {
    fixture = DoorFixture();
    fixture.setup("q1", {"spawnflags": "8"});
    fixture.world +>:HasOpponent:+> Opponent(pos=Vec3(x=40.0, z=46.0));
    fixture.tick(Vec3(x=500.0));
    door = [fixture.world->:HasDoor:->][?:Door][0];
    assert not door.unlocked and door.state == "closed";
}

test "closing doors reverse before sweeping through a living enemy" {
    fixture = DoorFixture();
    fixture.setup();
    door = [fixture.world->:HasDoor:->][?:Door][0];
    fixture.tick(Vec3(x=40.0, z=24.0), 2.0);
    assert door.position == 1.0;
    door.automatic = False;
    door.state = "closing";
    fixture.world +>:HasOpponent:+> Opponent(pos=Vec3(z=46.0));
    fixture.tick(Vec3(x=500.0), 2.0);
    assert door.state == "opening" and door.position == 1.0;
    assert fixture.collision.offsets[0].z == 88.0;
}

test "platforms carry enemies up and down without requiring player contact" {
    for game in ["q1", "q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(game, {"classname": "func_plat", "height": "64", "speed": "64"});
        platform = [fixture.world->:HasDoor:->][?:Door][0];
        enemy = Opponent(pos=Vec3(z=56.03125 + fixture.collision.eye_height));
        fixture.world +>:HasOpponent:+> enemy;
        before = enemy.pos.z;
        for i in range(4) {
            fixture.tick(Vec3(x=500.0), 0.25);
        }
        assert platform.position == 1.0 and enemy.grounded;
        assert abs(enemy.pos.z - before - 64.0) < 0.00001;
        platform.state = "closing";
        for i in range(4) {
            fixture.tick(Vec3(x=500.0), 0.25);
        }
        assert platform.position == 0.0;
        assert abs(enemy.pos.z - before) < 0.00001;
    }
}

test "a blocked enemy rider prevents partial platform and player movement" {
    import from engine.world.world { Player }
    import from engine.world.doors { DoorTick }
    fixture = DoorFixture();
    fixture.setup("q2", {"classname": "func_plat", "height": "64", "speed": "64"});
    platform = [fixture.world->:HasDoor:->][?:Door][0];
    # Ceiling above the enemy's half of the platform.
    fixture.collision.add_box(
        Vec3(x=-100.0, y=-100.0, z=100.0),
        Vec3(x=100.0, y=-18.0, z=200.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    fixture.collision.models.append(0);
    fixture.collision.reindex();
    enemy = Opponent(pos=Vec3(y=-20.0, z=78.03125));
    player = Player(pos=Vec3(y=20.0, z=78.03125));
    fixture.world +>:HasOpponent:+> enemy;
    fixture.world spawn DoorTick(
        bsp=fixture.bsp,
        collision=fixture.collision,
        player_origin=player.pos.sub(Vec3(z=22.0)),
        player=player,
        dt=0.5
    );
    assert platform.position == 0.0 and platform.state == "closing";
    assert enemy.pos.z == 78.03125 and player.pos.z == 78.03125;
    assert fixture.collision.offsets[0].z == -64.0;
}
