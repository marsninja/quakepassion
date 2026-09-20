"""Native asset-backed brush-trigger/door activation checks."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World }
import from engine.world.triggers { TouchTrigger, HasTrigger, Activates, TriggerTick }
import from engine.world.doors { Door, HasDoor, DoorTick, model_bounds }
import from engine.math.vec3 { Vec3 }

with entry {
    game = os.getenv("QP_GAME", "q1");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv(
        "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + folder
    );
    maps = ["e1m1", "e1m2", "e2m1", "e3m1", "e4m1"];
    if game == "q2" {
        maps = ["base1", "base2", "base3", "bunk1", "ware1", "jail1"];
    }
    if game == "q3" {
        maps = ["q3dm2", "q3dm7", "q3dm11", "q3ctf1", "q3tourney4"];
    }
    total = 0;
    for name in maps {
        world = World();
        level = load_level(world, directory, name, game);
        triggers = [world->:HasTrigger:->][?:TouchTrigger];
        for trigger in triggers {
            offset = Vec3();
            for entity in level.bsp.entities {
                if entity.fields.get("model", "") == "*" + str(trigger.model) {
                    coords = entity.fields.get("origin", "0 0 0").split();
                    offset = Vec3(
                        x=float(coords[0]), y=float(coords[1]), z=float(coords[2])
                    );
                }
            }
            candidates = [model_bounds(level.bsp, trigger.model).center().add(offset)];
            model = level.bsp.models[trigger.model];
            for f in range(model.first_face, model.first_face + model.face_count) {
                for v in level.bsp.faces[f].vertices {
                    candidates.append(v.add(offset));
                }
            }
            for bounds in trigger.volume.bounds {
                candidates.append(bounds.center());
            }
            found = False;
            point = Vec3();
            for candidate in candidates {
                if trigger.volume.trace(candidate, candidate).start_solid {
                    point = candidate;
                    found = True;
                    break;
                }
            }
            assert found;
            doors = [world->:HasDoor:->][?:Door];
            # Reset only this test's recipients to verify a fresh request.
            for door in doors {
                door.activation.pending = 0;
            }
            trigger spawn TriggerTick(start=point, finish=point, dt=0.01);
            assert trigger.activations == 1;
            receivers = [door for door in doors if door.activation.pending > 0];
            assert len(receivers) > 0;
            for door in receivers {
                assert door.enabled;
                door spawn DoorTick(
                    bsp=level.bsp,
                    collision=level.collision,
                    player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                    dt=0.01
                );
                assert door.activation.pending == 0 and door.position > 0.0;
            }
            total += 1;
        }
        print(game, name, len(triggers), "brush triggers passed");
    }
    assert total > 0;
    print("TRIGGERS PASS", game, total);
}
