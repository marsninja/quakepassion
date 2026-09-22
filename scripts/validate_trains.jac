"""Original-map train route, transform, and persistence acceptance."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.trains { Train, HasTrain, TrainTick }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }

with entry {
    for game in ["q1", "q2"] {
        directory = os.getenv("HOME", "")
            + "/quake-assets/"
            + ("id1" if game == "q1" else "baseq2");
        maps = ["e1m2", "e1m3", "e2m6"]
            if game == "q1"
            else ["base1", "fact2", "ware2"];
        for name in maps {
            world = World();
            level = load_level(world, directory, name, game);
            trains = [world->:HasTrain:->][?:Train];
            assert len(trains) > 0;
            starts = [train.motion for train in trains];
            for train in trains {
                train.activation.pending = 1;
            }
            for frame in range(120) {
                world spawn TrainTick(
                    bsp=level.bsp, collision=level.collision, dt=1.0 / 120.0
                );
            }
            moved = 0;
            positions = [train.motion for train in trains];
            for i in range(len(trains)) {
                train = trains[i];
                if train.motion.sub(starts[i]).length() > 0.001 {
                    moved += 1;
                }
                for face in train.faces {
                    assert level.bsp.faces[face].motion.sub(train.motion).length()
                        < 0.0001;
                }
                for h in range(len(train.hulls)) {
                    assert level.collision.offsets[train.hulls[h]].sub(
                        train.origins[h]
                    ).sub(
                        train.motion
                    ).length()
                        < 0.0001;
                }
            }
            assert moved > 0;
            data = snapshot(world, level, Player(), CombatState());
            world spawn TrainTick(bsp=level.bsp, collision=level.collision, dt=0.25);
            restore(world, level, Player(), CombatState(), data);
            for i in range(len(trains)) {
                assert trains[i].motion.sub(positions[i]).length() < 0.0001;
            }
            print("TRAINS PASS", game, name, len(trains), "loaded", moved, "moved");
        }
    }
}
