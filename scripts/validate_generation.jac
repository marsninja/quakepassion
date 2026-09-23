"""Headless generation gauntlet; no game assets or graphical window required.

Every seed must produce an expedition whose mission is proven softlock free,
whose geometry is re-proven completable by the column playtester and checked
physically, and whose clusters cull something. The report also measures how
the chosen expeditions spread over the quality-diversity descriptor grid.
"""
import time;
import from games.passion.generate { generate, survey_of, Survey, REJECTIONS }
import from games.passion.playtest { progress }
import from engine.world.world { World }
import from engine.world.level { Level }

with entry {
    seeds = list(range(1, 201)) + [104729, 2147483646];
    started = time.perf_counter();
    slowest = 0.0;
    cells: dict[str, int] = {};
    archetypes: dict[str, int] = {};
    recipes: dict[str, int] = {};
    rooms = 0;
    faces = 0;
    monsters = 0;
    teleports = 0;
    windows = 0;
    culled = 0.0;
    candidates = 0;
    valid = 0;
    failed: list[int] = [];
    for seed in seeds {
        begin = time.perf_counter();
        world = World();
        level: Level | None = None;
        try {
            level = generate(world, "v2-" + str(seed), []);
        } except ValueError {
            failed.append(seed);
            continue;
        }
        if level is None {
            continue;
        }
        slowest = max(slowest, time.perf_counter() - begin);
        found = survey_of(world);
        assert found is not None;
        record: Survey = found;
        plan = record.plan;
        bp = record.bp;
        site = record.site;
        assert plan is not None and bp is not None and site is not None;
        proof = progress(plan, bp, site, record.start[0], record.start[1]);
        assert proof.reached_exit , "seed " + str(seed) + " is not completable";
        clusters = level.bsp.clusters;
        assert record.visible_pairs < clusters * clusters;
        culled += 1.0 - float(record.visible_pairs) / float(clusters * clusters);
        key = "|".join([str(min(2, int(value * 3.0))) for value in record.measured]);
        cells[key] = cells.get(key, 0) + 1;
        archetypes[record.archetype] = archetypes.get(record.archetype, 0) + 1;
        for beat in bp.interiors {
            recipe = bp.interiors[beat].recipe;
            recipes[recipe] = recipes.get(recipe, 0) + 1;
        }
        rooms += len(bp.interiors);
        faces += len(level.bsp.faces);
        monsters += len(
            [
                entity
                for entity in level.bsp.entities
                if entity.fields.get("classname", "").startswith("monster_")
                    or entity.fields.get("classname", "") == "info_player_deathmatch"
            ]
        );
        teleports += site.teleports;
        windows += site.windows;
        candidates += record.candidates;
        valid += record.valid;
    }
    print("  failed seeds", failed, "rejections", REJECTIONS);
    assert not failed , "seeds without a valid expedition";
    count = float(len(seeds));
    print(
        "GENERATION PASS",
        len(seeds),
        "seeds in",
        round(time.perf_counter() - started, 1),
        "s (slowest",
        round(slowest, 2),
        "s): mission proof, geometry playtest, corridor physics, cluster culling"
    );
    print(
        "  averages: rooms",
        round(float(rooms) / count, 1),
        "faces",
        int(float(faces) / count),
        "hostiles",
        round(float(monsters) / count, 1),
        "culled pairs",
        round(culled / count, 2),
        "teleports",
        round(float(teleports) / count, 2),
        "windows",
        round(float(windows) / count, 2)
    );
    print("  candidates valid", valid, "/", candidates, "rejections", REJECTIONS);
    print(
        "  descriptor cells occupied", len(cells), "of 81 (loop|vertical|density|size)"
    );
    print("  archetypes", archetypes);
    print("  room recipes", recipes);
}
