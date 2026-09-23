import from engine.world.signals { SignalTick }
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

import from tests.trigger_support { trigger_fixture, touch }

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


test "unsupported flags and partial target fan-out do not activate doors" {
    # Q2 MONSTER-only triggers remain unsupported; named, directional,
    # killtarget and random triggers now load.
    fixture = trigger_fixture();
    fixture.bsp.entities[1].fields["spawnflags"] = "1";
    load_triggers(fixture.world, fixture.bsp);
    assert len([fixture.world->:HasTrigger:->][?:TouchTrigger]) == 0;
    for fields in [
        {"killtarget": "other"},
        {"angle": "90"},
        {"random": "1"},
        {"targetname": "remote"}
    ] {
        fixture = trigger_fixture();
        for key in fields {
            fixture.bsp.entities[1].fields[key] = fields[key];
        }
        load_triggers(fixture.world, fixture.bsp);
        assert len([fixture.world->:HasTrigger:->][?:TouchTrigger]) == 1;
    }
    fixture = trigger_fixture();
    fixture.bsp.entities.append(
        MapEntity(fields={"classname": "target_relay", "targetname": "gate"})
    );
    load_triggers(fixture.world, fixture.bsp);
    assert len([fixture.world->:HasTrigger:->][?:TouchTrigger]) == 0;
}

test "delayed contact queues output even when a one shot trigger disables" {
    fixture = trigger_fixture(once=True);
    fixture.bsp.entities[1].fields["delay"] = "1";
    load_triggers(fixture.world, fixture.bsp);
    door = [fixture.world->:HasDoor:->][?:Door][0];
    touch(fixture, Vec3(x=190.0), Vec3(x=200.0));
    assert door.activation.pending == 0;
    fixture.world spawn SignalTick(dt=0.5);
    assert door.activation.pending == 0;
    fixture.world spawn SignalTick(dt=0.5);
    assert door.activation.pending == 1;
}
