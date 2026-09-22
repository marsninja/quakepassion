"""Original-map loading, event scheduling, and persistence acceptance."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.signals { Signal, HasSignal, SignalTick, Fire }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }

with entry {
    for game in ["q1", "q2", "q3"] {
        folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
        maps = ["e1m2", "e2m6"]
            if game == "q1"
            else (["base1", "fact2", "ware2"] if game == "q2" else ["q3dm7", "q3dm17"]);
        for name in maps {
            world = World();
            level = load_level(
                world, os.getenv("HOME", "") + "/quake-assets/" + folder, name, game
            );
            signals = [world->:HasSignal:->][?:Signal];
            scheduled = 0;
            for signal in signals {
                if signal.enabled and signal.delay > 0.0 and signal.relay {
                    signal spawn Fire(emit=False);
                    scheduled += 1;
                }
            }
            for frame in range(15) {
                world spawn SignalTick(dt=1.0 / 120.0);
            }
            player = Player();
            combat = CombatState();
            before = snapshot(world, level, player, combat);
            for frame in range(120) {
                world spawn SignalTick(dt=1.0 / 120.0);
            }
            restore(world, level, player, combat, before);
            assert snapshot(world, level, player, combat) == before;
            print(
                "EVENTS PASS",
                game,
                name,
                len(signals),
                "signals",
                scheduled,
                "delayed relays activated"
            );
        }
    }
}
