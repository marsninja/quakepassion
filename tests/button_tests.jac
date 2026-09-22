import from engine.world.doors { Door, HasDoor, connect_targets }
import from engine.world.signals { Signal, Targets }
import from engine.formats.bsp { MapEntity }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }

test "buttons require contact and emit once at the pressed endpoint" {
    for game in ["q1", "q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(game, {"classname": "func_button", "speed": "40", "wait": "1"});
        button = [fixture.world->:HasDoor:->][?:Door][0];
        destination = Signal();
        button.activation +>:Targets:+> destination;
        fixture.tick(Vec3(x=60.0, z=24.0), 1.0);
        assert button.position == 0.0;
        fixture.tick(Vec3(x=24.03125, z=24.0), 0.01);
        assert button.position > 0.0 and destination.pending == 0;
        fixture.tick(Vec3(x=500.0), 4.0);
        assert button.state == "open" and destination.pending == 1;
        fixture.tick(Vec3(x=500.0), 0.5);
        assert destination.pending == 1;
        fixture.tick(Vec3(x=500.0), 1.0);
        fixture.tick(Vec3(x=500.0), 4.0);
        assert button.state == "closed";
    }
}

test "missing button recipients do not disable the button" {
    fixture = DoorFixture();
    fixture.setup("q2", {"classname": "func_button", "target": "missing"});
    button = [fixture.world->:HasDoor:->][?:Door][0];
    assert button.enabled;
    fixture.tick(Vec3(x=24.03125, z=24.0), 1.0);
    assert button.position > 0.0;
}

test "a map button activates a named door through a relay" {
    import from tests.door_support { pair_fixture }
    import from engine.world.doors { load_doors }
    import from engine.world.world { World }
    fixture = pair_fixture("q2");
    fixture.world = World();
    fixture.bsp.entities[0].fields["classname"] = "func_button";
    fixture.bsp.entities[0].fields["team"] = "";
    fixture.bsp.entities[0].fields["target"] = "relay";
    fixture.bsp.entities[1].fields["team"] = "";
    fixture.bsp.entities[1].fields["targetname"] = "gate";
    fixture.bsp.entities.append(
        MapEntity(
            fields={
                "classname": "trigger_relay",
                "targetname": "relay",
                "target": "gate"
            }
        )
    );
    load_doors(fixture.world, fixture.bsp, fixture.collision);
    movers = [fixture.world->:HasDoor:->][?:Door];
    assert len(movers) == 2;
    assert movers[0].enabled and movers[1].enabled;
    assert not movers[1].automatic;
    movers[0].requested = True;
    fixture.tick(Vec3(x=500.0), 4.0);
    assert movers[0].position == 1.0;
    assert movers[1].position > 0.0;
}


test "named Q2 buttons require use while Q1 and Q3 retain touch activation" {
    for game in ["q1", "q2", "q3"] {
        fixture = DoorFixture();
        fixture.setup(
            game, {"classname": "func_button", "targetname": "switch", "wait": "0"}
        );
        button = [fixture.world->:HasDoor:->][?:Door][0];
        fixture.tick(Vec3(x=24.03125, z=24.0), 0.01);
        if game == "q2" {
            assert button.position == 0.0 and button.hold_time == 3.0;
            button.activation.pending = 1;
            fixture.tick(Vec3(x=500.0), 0.01);
        }
        assert button.position > 0.0;
    }
}
