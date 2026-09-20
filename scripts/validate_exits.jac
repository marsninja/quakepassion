"""Resolve real campaign exits and their destination spawnpoints."""
import os;
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.exits { LevelExit, HasExit, exit_map, exit_spawn }

with entry {
    game = os.getenv("QP_GAME", "q1");
    directory = os.getenv("HOME", "")
        + "/quake-assets/"
        + ("id1" if game == "q1" else "baseq2");
    maps = ["start", "e1m1", "e1m2", "e1m3"]
        if game == "q1"
        else ["base1", "base2", "base3", "jail1"];
    total = 0;
    for name in maps {
        world = World();
        load_level(world, directory, name, game);
        for portal in [world->:HasExit:->][?:LevelExit] {
            destination = load_level(
                World(), directory, exit_map(portal.destination), game
            );
            player = spawn_player(destination, exit_spawn(portal.destination));
            assert player.pos.length() < 1.0e6;
            print("EXIT PASS", game, name, "to", portal.destination);
            total += 1;
        }
    }
    assert total > 0;
    print("EXITS PASS", game, total);
}
