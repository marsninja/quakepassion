import from engine.world.triggers {
    TouchTrigger,
    HasTrigger,
    Activates,
    TriggerTick,
    load_triggers
}
import from engine.world.doors { Door, HasDoor }
import from engine.formats.bsp { Brush, Plane, Model, MapEntity }
import from engine.formats.brush_collision { build_brush_collision }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }


def trigger_fixture(game: str = "q2", once: bool = False) -> DoorFixture {
    fixture = DoorFixture();
    fixture.setup(game, {"targetname": "gate"});
    fixture.bsp.models.append(Model(head=0, first_face=1, face_count=0, brushes=[0]));
    for normal in [
        Vec3(x=1.0),
        Vec3(x=-1.0),
        Vec3(y=1.0),
        Vec3(y=-1.0),
        Vec3(z=1.0),
        Vec3(z=-1.0)
    ] {
        fixture.bsp.planes.append(Plane(normal=normal, distance=8.0));
    }
    fixture.bsp.planes.append(
        Plane(normal=Vec3(x=1.0, y=1.0).normalized(), distance=0.0)
    );
    fixture.bsp.brushes.append(
        Brush(planes=[0, 1, 2, 3, 4, 5, 6], contents=1073741824)
    );
    fixture.bsp.entities.append(
        MapEntity(
            fields={
                "classname": "trigger_once" if once else "trigger_multiple",
                "model": "*2",
                "origin": "200 0 0",
                "target": "gate",
                "wait": "0.2"
            }
        )
    );
    return fixture;
}


def touch(
    fixture: DoorFixture,
    start: Vec3,
    finish: Vec3,
    dt: float = 0.01,
    touching: bool = True
) {
    fixture.world spawn TriggerTick(
        start=start, finish=finish, dt=dt, touching=touching
    );
}


test "exact trigger brushes reject empty corners and catch swept contacts" {
    for game in ["q2", "q3"] {
        fixture = trigger_fixture(game);
        load_triggers(fixture.world, fixture.bsp);
        triggers = [fixture.world->:HasTrigger:->][?:TouchTrigger];
        assert len(triggers) == 1;
        door = [fixture.world->:HasDoor:->][?:Door][0];
        fixture.tick(Vec3(x=60.0, z=24.0));
        assert door.position == 0.0;
        touch(fixture, Vec3(x=220.0, y=20.0, z=24.0), Vec3(x=220.0, y=20.0, z=24.0));
        assert triggers[0].activations == 0 and door.activation.pending == 0;
        touch(fixture, Vec3(x=100.0, z=24.0), Vec3(x=300.0, z=24.0));
        assert triggers[0].activations == 1 and door.activation.pending == 1;
        fixture.tick(Vec3(x=300.0, z=24.0));
        assert door.position > 0.0 and door.activation.pending == 0;
        solids = build_brush_collision(fixture.bsp);
        assert 2 not in solids.models;
    }
}


test "repeat triggers honor cooldown, pause and walking-only contact" {
    fixture = trigger_fixture();
    load_triggers(fixture.world, fixture.bsp);
    trigger = [fixture.world->:HasTrigger:->][?:TouchTrigger][0];
    point = Vec3(x=200.0, z=24.0);
    touch(fixture, point, point, 0.0);
    touch(fixture, point, point, touching=False);
    assert trigger.activations == 0;
    touch(fixture, point, point);
    assert trigger.activations == 1;
    touch(fixture, point, point, 0.1);
    assert trigger.activations == 1;
    before = trigger.cooldown;
    touch(fixture, point, point, 0.0);
    assert trigger.cooldown == before;
    touch(fixture, point, point, 0.11);
    assert trigger.activations == 2;
}


test "one-shot and negative wait triggers cannot fire twice" {
    for once in [True, False] {
        fixture = trigger_fixture(once=once);
        if not once {
            fixture.bsp.entities[1].fields["wait"] = "-1";
        }
        load_triggers(fixture.world, fixture.bsp);
        trigger = [fixture.world->:HasTrigger:->][?:TouchTrigger][0];
        point = Vec3(x=200.0, z=24.0);
        touch(fixture, point, point);
        touch(fixture, point, point, 10.0);
        assert trigger.activations == 1 and not trigger.enabled;
    }
}


test "unsupported trigger rules and partial target fan-out do not activate doors" {
    for fields in [
        {"health": "1"},
        {"delay": "1"},
        {"killtarget": "other"},
        {"angle": "90"},
        {"spawnflags": "1"},
        {"random": "1"},
        {"targetname": "remote"}
    ] {
        fixture = trigger_fixture();
        for key in fields {
            fixture.bsp.entities[1].fields[key] = fields[key];
        }
        load_triggers(fixture.world, fixture.bsp);
        assert len([fixture.world->:HasTrigger:->][?:TouchTrigger]) == 0;
    }
    fixture = trigger_fixture();
    fixture.bsp.entities.append(
        MapEntity(fields={"classname": "target_relay", "targetname": "gate"})
    );
    load_triggers(fixture.world, fixture.bsp);
    assert len([fixture.world->:HasTrigger:->][?:TouchTrigger]) == 0;
}
