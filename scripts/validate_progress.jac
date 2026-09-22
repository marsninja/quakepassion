"""Original-map secret contact, objective activation, and save restoration."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.signals { Signal, HasSignal, Fire, progress_for }
import from engine.world.triggers { TouchTrigger, HasTrigger, Activates, TriggerTick }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }

with entry {
    for game in ["q1", "q2"] {
        world = World();
        name = "e1m1" if game == "q1" else "base1";
        folder = "id1" if game == "q1" else "baseq2";
        level = load_level(
            world, os.getenv("HOME", "") + "/quake-assets/" + folder, name, game
        );
        player = Player();
        state = CombatState();
        progress = progress_for(world);
        assert progress.total_secrets > 0;
        if game == "q1" {
            found = False;
            for trigger in [world->:HasTrigger:->][?:TouchTrigger] {
                if found {
                    continue;
                }
                secrets = [
                    signal
                    for signal in [trigger->:Activates:->][?:Signal]
                    if signal.objective == "secret" and signal.enabled
                ];
                if not secrets {
                    continue;
                }
                for bounds in trigger.volume.bounds {
                    origin = bounds.center();
                    if not trigger.volume.trace(origin, origin).start_solid {
                        continue;
                    }
                    trigger spawn TriggerTick(
                        start=origin, finish=origin, dt=0.01, player=player
                    );
                    assert progress.secrets == 1 and not trigger.enabled;
                    found = True;
                    break;
                }
            }
            assert found;
        } else {
            secrets = [
                signal
                for signal in [world->:HasSignal:->][?:Signal]
                if signal.objective == "secret" and signal.enabled
            ];
            assert len(secrets) > 0;
            secrets[0] spawn Fire(emit=False, inventory=player.inventory);
            secrets[0] spawn Fire(emit=False, inventory=player.inventory);
            assert progress.secrets == 1;
        }
        before = snapshot(world, level, player, state);
        progress.secrets = 0;
        restore(world, level, player, state, before);
        assert progress.secrets == 1
            and snapshot(world, level, player, state) == before;
        print(
            "PROGRESS PASS",
            game,
            name,
            progress.secrets,
            "/",
            progress.total_secrets,
            "secrets",
            progress.total_goals,
            "goals"
        );
    }
}
