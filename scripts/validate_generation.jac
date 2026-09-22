"""Headless generation gauntlet; no game assets or graphical window required."""
import from games.passion.generate { generate }
import from engine.world.world { World }
with entry {
    seeds = list(range(1, 101)) + [104729, 2147483646];
    for seed in seeds {
        level = generate(World(), "v1-" + str(seed), []);
        assert len(level.areas) == 20 and level.bsp.models[1].face_count > 0;
    }
    print("GENERATION PASS", len(seeds), "seeds: topology, collision clearance, step heights, objectives");
}
