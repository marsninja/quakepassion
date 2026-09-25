import from engine.world.doors {
    Door,
    HasDoor,
    DoorMember,
    DoorTick,
    load_doors,
    door_direction
}
import from engine.world.world { World }
import from engine.world.signals { chain_notes }
import from engine.formats.bsp { Bsp, Face, Model, MapEntity }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

import from tests.door_support { DoorFixture, pair_fixture }

test "door opens, holds near player, waits and closes without transform drift" {
    fixture = DoorFixture();
    fixture.setup();
    doors = [fixture.world->:HasDoor:->][?:Door];
    assert len(doors) == 1;
    door = doors[0];
    for cycle in range(3) {
        for i in range(25) {
            fixture.tick(Vec3(x=60.0, z=24.0));
        }
        assert door.state == "open" and door.position == 1.0;
        assert fixture.bsp.faces[0].motion.z == 88.0;
        assert fixture.collision.offsets[0].z == 88.0;
        assert not fixture.collision.trace(Vec3(z=24.0), Vec3(z=24.0)).start_solid;
        # This point is beyond the original indexed bounds: moved hull must be found.
        assert fixture.collision.trace(Vec3(z=180.0), Vec3(z=180.0)).start_solid;
        fixture.tick(Vec3(x=500.0), 0.05);
        assert door.state == "open";
        for i in range(30) {
            fixture.tick(Vec3(x=500.0));
        }
        assert door.state == "closed" and door.position == 0.0;
        assert fixture.bsp.faces[0].motion.length() == 0.0;
        assert fixture.collision.offsets[0].length() == 0.0;
        assert fixture.collision.trace(Vec3(z=24.0), Vec3(z=24.0)).start_solid;
    }
}

test "door pauses at zero time and reverses when closing sweep crosses player" {
    fixture = DoorFixture();
    fixture.setup();
    door = [fixture.world->:HasDoor:->][?:Door][0];
    fixture.tick(Vec3(x=60.0, z=24.0), 0.0);
    assert door.state == "closed";
    for i in range(21) {
        fixture.tick(Vec3(x=60.0, z=24.0));
    }
    door.state = "closing";
    # Remove proximity activation to independently exercise obstruction protection.
    door.trigger.mins = Vec3(x=1000.0, y=1000.0, z=1000.0);
    door.trigger.maxs = Vec3(x=1100.0, y=1100.0, z=1100.0);
    fixture.tick(Vec3(z=24.0), 2.0);
    assert door.state == "opening" and door.position == 1.0;
    assert fixture.bsp.faces[0].motion.z == 88.0;
}

test "negative wait stays open and opening cannot sweep through player" {
    fixture = DoorFixture();
    fixture.setup(fields={"wait": "-1"});
    door = [fixture.world->:HasDoor:->][?:Door][0];
    door.state = "opening";
    fixture.tick(Vec3(z=150.0), 2.0);
    assert door.position == 0.0;
    fixture.tick(Vec3(x=60.0, z=24.0), 2.0);
    fixture.tick(Vec3(x=500.0), 20.0);
    assert door.state == "open";
}

test "unknown spawnflags stay static; killtarget and accel doors move" {
    for game in ["q1", "q2", "q3"] {
        for fields in [
            {"killtarget": "event"},
            {"spawnflags": "128"},
            {"accel": "10", "decel": "10"}
        ] {
            fixture = DoorFixture();
            fixture.setup(game, fields);
            active = [
                door
                for door in [fixture.world->:HasDoor:->][?:Door]
                if door.enabled
            ];
            assert len(active) == (0 if "spawnflags" in fields else 1);
            if "spawnflags" in fields {
                notes = chain_notes(fixture.world);
                assert notes and "spawnflags 128" in notes[0].reason;
            }
        }
    }
    # Q2 ANIMATED (16) and ANIMATED_FAST (64) only animate textures.
    for flags in ["16", "64", "80"] {
        fixture = DoorFixture();
        fixture.setup("q2", {"spawnflags": flags});
        assert [door for door in [fixture.world->:HasDoor:->][?:Door] if door.enabled];
    }
    assert door_direction(MapEntity(fields={"angle": "-2"})).z == -1.0;
    assert abs(door_direction(MapEntity(fields={"angle": "90"})).y - 1.0) < 0.000001;
}

test "all formats share door behavior and use their authored defaults" {
    for game in ["q1", "q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(game, {"speed": "0", "wait": "0"});
        door = [fixture.world->:HasDoor:->][?:Door][0];
        assert door.speed == (400.0 if game == "q3" else 100.0);
        assert door.hold_time == (2.0 if game == "q3" else 3.0);
        fixture.tick(Vec3(x=60.0, z=24.0));
        assert door.position > 0.0 and door.state == "opening";
    }
}


test "touching Q1 doors and named Q2 Q3 teams move together" {
    for game in ["q1", "q2", "q3"] {
        fixture = pair_fixture(game);
        leaders = [fixture.world->:HasDoor:->][?:Door];
        assert len(leaders) == 1;
        leader = leaders[0];
        parts = [leader->:DoorMember:->][?:Door];
        assert len(parts) == 1;
        fixture.tick(Vec3(x=60.0, z=24.0), 1.0);
        assert abs(leader.position - 0.5) < 0.00001;
        assert parts[0].position == leader.position;
        assert fixture.bsp.faces[0].motion.z == 44.0;
        assert fixture.bsp.faces[1].motion.z == -44.0;
        fixture.tick(Vec3(x=60.0, z=24.0), 1.0);
        assert leader.state == "open" and parts[0].position == 1.0;
        fixture.tick(Vec3(x=500.0), 1.0);
        fixture.tick(Vec3(x=500.0), 2.0);
        assert leader.state == "closed" and parts[0].position == 0.0;
        assert fixture.collision.offsets[1].y == 64.0;
        assert fixture.collision.offsets[1].z == 0.0;
    }
}

test "one blocked member prevents the whole door group from moving" {
    fixture = pair_fixture("q3");
    leader = [fixture.world->:HasDoor:->][?:Door][0];
    leader.state = "opening";
    fixture.tick(Vec3(y=64.0, z=-80.0), 2.0);
    assert leader.position == 0.0;
    assert fixture.bsp.faces[0].motion.length() == 0.0;
    assert fixture.bsp.faces[1].motion.length() == 0.0;
    assert fixture.collision.offsets[0].z == 0.0;
    assert fixture.collision.offsets[1].z == 0.0;
}

test "a targeted member disables proximity activation for the entire group" {
    for game in ["q1", "q2", "q3"] {
        fixture = pair_fixture(game, locked=True);
        leaders = [fixture.world->:HasDoor:->][?:Door];
        assert len(leaders) == 1 and not leaders[0].automatic;
        fixture.tick(Vec3(x=60.0, z=24.0), 1.0);
        assert leaders[0].position == 0.0;
        leaders[0].requested = True;
        fixture.tick(Vec3(x=500.0), 1.0);
        assert leaders[0].position > 0.0;
    }
}


test "an absent target recipient is a no-op and does not freeze the mover" {
    for game in ["q1", "q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(game, {"target": "lightning"});
        door = [fixture.world->:HasDoor:->][?:Door][0];
        assert door.enabled and door.activation.enabled;
        fixture.tick(Vec3(x=60.0), 1.0);
        assert door.state == "open";
    }
}
