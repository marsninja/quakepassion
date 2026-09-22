import from engine.world.world { World, Player }
import from engine.world.signals {
    Signal,
    HasSignal,
    Fire,
    progress_for,
    progress_summary
}
import from engine.world.doors { load_doors, Door, HasDoor }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.formats.bsp { MapEntity }
import from tests.door_support { DoorFixture }

test "authored secrets and goals count once and emit their targets" {
    for game in ["q1", "q2"] {
        f = DoorFixture();
        f.setup(game, {"targetname": "gate"});
        f.world = World();
        f.bsp.entities.append(
            MapEntity(
                fields={
                    "classname": "trigger_secret" if game == "q1" else "target_secret",
                    "target": "gate"
                }
            )
        );
        if game == "q2" {
            f.bsp.entities.append(MapEntity(fields={"classname": "target_goal"}));
        }
        load_doors(f.world, f.bsp, f.collision);
        progress = progress_for(f.world);
        assert progress.total_secrets == 1 and progress.secrets == 0;
        secret = [
            signal
            for signal in [f.world->:HasSignal:->][?:Signal]
            if signal.objective == "secret"
        ][0];
        fired = secret spawn Fire(emit=False);
        assert fired.message == "Secret found! 1/1" and progress.secrets == 1;
        door = [f.world->:HasDoor:->][?:Door][0];
        assert door.activation.pending == 1;
        secret spawn Fire(emit=False);
        assert progress.secrets == 1 and door.activation.pending == 1;
        if game == "q2" {
            goal = [
                signal
                for signal in [f.world->:HasSignal:->][?:Signal]
                if signal.objective == "goal"
            ][0];
            goal spawn Fire(emit=False);
            goal spawn Fire(emit=False);
            assert progress.goals == 1 and progress.total_goals == 1;
        }
        player = Player();
        state = CombatState();
        level = Level(bsp=f.bsp, collision=f.collision, name="fixture");
        data = snapshot(f.world, level, player, state);
        progress.secrets = 0;
        secret.enabled = True;
        restore(f.world, level, player, state, data);
        assert progress.secrets == 1 and not secret.enabled;
        assert "Secrets: 1/1" in progress_summary(f.world);
    }
}
