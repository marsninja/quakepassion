import from engine.world.exits {
    LevelExit,
    HasExit,
    ExitTick,
    load_exits,
    exit_map,
    exit_spawn
}
import from engine.world.signals { Signal, HasSignal }
import from engine.world.doors { load_doors }
import from engine.world.triggers { load_triggers, TriggerTick }
import from engine.world.world { World }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { MapEntity }
import from tests.trigger_support { trigger_fixture }


test "Q1 exit contacts request a map once and pause or fly suppresses transitions" {
    world = World();
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-8.0, y=-8.0, z=-8.0), Vec3(x=8.0, y=8.0, z=8.0), Vec3(), Vec3(), Vec3()
    );
    world +>:HasExit:+> LevelExit(destination="e1m2", contact=True, volume=volume);
    paused = world spawn ExitTick(start=Vec3(), finish=Vec3(), dt=0.0);
    fly = world spawn ExitTick(start=Vec3(), finish=Vec3(), dt=0.01, touching=False);
    assert not paused.request and not fly.request;
    hit = world spawn ExitTick(start=Vec3(x=-20.0), finish=Vec3(x=20.0), dt=0.01);
    assert hit.request == "e1m2";
    again = world spawn ExitTick(start=Vec3(), finish=Vec3(), dt=0.01);
    assert not again.request;
}

test "Q2 map trigger dispatches to a registered changelevel target" {
    fixture = trigger_fixture("q2");
    fixture.world = World();
    fixture.bsp.entities[1].fields["target"] = "next";
    fixture.bsp.entities.append(
        MapEntity(
            fields={
                "classname": "target_changelevel",
                "targetname": "next",
                "map": "*base2$entry"
            }
        )
    );
    load_exits(fixture.world, fixture.bsp);
    load_doors(fixture.world, fixture.bsp, fixture.collision);
    load_triggers(fixture.world, fixture.bsp);
    fixture.world spawn TriggerTick(
        start=Vec3(x=100.0, z=24.0), finish=Vec3(x=300.0, z=24.0), dt=0.01
    );
    hit = fixture.world spawn ExitTick(start=Vec3(), finish=Vec3(), dt=0.01);
    assert hit.request == "*base2$entry";
    assert exit_map(hit.request) == "base2" and exit_spawn(hit.request) == "entry";
}

test "exit names preserve named starts but reject path traversal" {
    assert exit_map("e1m2") == "e1m2" and exit_spawn("e1m2") == "";
    assert exit_map("*jail1$base") == "jail1";
    for bad in ["", "../base1", "dir/base1", "base1.bsp"] {
        rejected = False;
        try {
            exit_map(bad);
        } except ValueError {
            rejected = True;
        }
        assert rejected;
    }
}
