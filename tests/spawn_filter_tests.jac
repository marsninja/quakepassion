import from engine.formats.bsp { Bsp, MapEntity, Model, Leaf }
import from engine.world.spawns { active_entities }
import from engine.world.level { Level, prepare_level }
import from engine.world.world { World }
import from engine.math.vec3 { Vec3 }
import from engine.world.signals { Signal, HasSignal, SignalTick, progress_for }

test "campaign difficulty applies to every entity and preserves authored input" {
    for game in ["q1", "q2"] {
        for kind in ["trigger_always", "monster_army", "item_health", "func_door"] {
            entities = [
                MapEntity(fields={"classname": kind, "spawnflags": "1792"}),
                MapEntity(fields={"classname": kind, "spawnflags": "2049"})
            ];
            active = active_entities(game, entities);
            assert len(active) == 1;
            assert active[0].fields["spawnflags"] == "1";
            assert entities[1].fields["spawnflags"] == "2049";
        }
    }
}

test "excluded startup triggers cannot award campaign secrets" {
    world = World();
    level = Level(
        bsp=Bsp(
            game="q2",
            models=[Model(head=-1, first_face=0, face_count=0)],
            leaves=[Leaf(contents=0, vis_offset=-1, mins=Vec3(), maxs=Vec3())],
            entities=[
                MapEntity(fields={"classname": "worldspawn"}),
                MapEntity(
                    fields={
                        "classname": "target_secret",
                        "targetname": "t91",
                        "spawnflags": "2048"
                    }
                ),
                MapEntity(
                    fields={
                        "classname": "trigger_always",
                        "target": "t91",
                        "spawnflags": "1792"
                    }
                )
            ]
        )
    );
    prepare_level(world, level);
    world spawn SignalTick(dt=1.0);
    progress = progress_for(world);
    assert progress.total_secrets == 1 and progress.secrets == 0;
    # The excluded trigger_always (entity 2) is never loaded.
    for signal in [world->:HasSignal:->][?:Signal] {
        assert 2 not in signal.entities;
    }
}

test "local Q3 arena respects free-for-all and base-game exclusions" {
    entities = [
        MapEntity(fields={"classname": "worldspawn", "notfree": "1"}),
        MapEntity(fields={"classname": "item_health", "notfree": "1"}),
        MapEntity(fields={"classname": "item_health", "notq3a": "1"}),
        MapEntity(fields={"classname": "item_health", "gametype": "ctf team"}),
        MapEntity(
            fields={
                "classname": "item_health",
                "gametype": "ffa team",
                "notsingle": "1",
                "notteam": "1",
                "spawnflags": "512"
            }
        )
    ];
    active = active_entities("q3", entities);
    assert len(active) == 2;
    assert active[1].fields["spawnflags"] == "512";
    assert len(active_entities("passion", entities)) == len(entities);
}
