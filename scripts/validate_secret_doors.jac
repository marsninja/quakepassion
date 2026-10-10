"""Original Q1 and Q2 secret door routes, transform synchronization, and
restoration."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.trains { Train, HasTrain, TrainTick }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }

with entry {
    for (game, folder, name) in [
        ("q1", "id1", "e1m1"),
        ("q1", "id1", "e1m2"),
        ("q1", "id1", "e2m1"),
        ("q1", "id1", "e4m1"),
        ("q2", "baseq2", "city3")
    ] {
        world = World();
        level = load_level(
            world, os.getenv("HOME", "") + "/quake-assets/" + folder, name, game
        );
        doors = [
            door
            for door in [world->:HasTrain:->][?:Train]
            if door.kind == "secret"
        ];
        assert len(doors) > 0;
        for door in doors {
            door.activation.pending = 1;
        }
        for frame in range(120) {
            world spawn TrainTick(
                bsp=level.bsp, collision=level.collision, dt=1.0 / 120.0
            );
        }
        for door in doors {
            assert door.motion.length() > 0.0;
            for face in door.faces {
                assert level.bsp.faces[face].motion.sub(door.motion).length() < 0.0001;
            }
            for h in range(len(door.hulls)) {
                assert level.collision.offsets[door.hulls[h]].sub(door.origins[h]).sub(
                    door.motion
                ).length()
                    < 0.0001;
            }
        }
        player = Player();
        state = CombatState();
        before = snapshot(world, level, player, state);
        for frame in range(120) {
            world spawn TrainTick(
                bsp=level.bsp, collision=level.collision, dt=1.0 / 120.0
            );
        }
        restore(world, level, player, state, before);
        assert snapshot(world, level, player, state) == before;
        print("SECRET DOORS PASS", game, name, len(doors), "routes and snapshots");
    }
}
