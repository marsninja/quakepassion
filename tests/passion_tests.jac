import from games.passion.random { Stream, stream_for, mix32 }
import from games.passion.mission {
    Expedition,
    Beat,
    Link,
    build_mission,
    beats_of,
    links_of,
    validate_mission
}
import from games.passion.layout {
    embed,
    rooms_of,
    passages_of,
    target_heights,
    solve_heights
}
import from games.passion.generate {
    generate,
    survey,
    survey_of,
    seed_from,
    niche_for,
    Survey
}
import from games.passion.playtest { progress }
import from games.passion.lighting { ColumnOccluder }
import from games.passion.blueprint { Blueprint }
import from engine.world.lighting { TraceOccluder }
import from engine.world.world { World, Player }
import from engine.math.vec3 { Vec3 }
import from engine.physics.movement { MovePlayer }
import from engine.world.doors { Door, HasDoor }

test "random streams are deterministic, bounded and independent" {
    a = stream_for(42, "layout");
    b = stream_for(42, "layout");
    c = stream_for(42, "mission");
    first = [a.word() for _ in range(16)];
    assert first == [b.word() for _ in range(16)];
    assert first != [c.word() for _ in range(16)];
    counts = [0 for _ in range(6)];
    s = stream_for(7, "dice");
    for _ in range(6000) {
        counts[s.below(6)] += 1;
    }
    for count in counts {
        assert 850 < count < 1150;
    }
    order = stream_for(3, "order").order(10);
    assert sorted(order) == list(range(10));
    # Drawing from one child never shifts a sibling's sequence.
    parent = stream_for(9, "parent");
    left = parent.child("room", 1);
    for _ in range(50) {
        left.word();
    }
    assert parent.child("room", 2).word()
        == stream_for(9, "parent").child("room", 2).word();
}

test "cyclic missions are completable and softlock free across archetypes" {
    archetypes = ["keys", "relays", "guardian", "mixed"];
    patterns: list[str] = [];
    modes: list[str] = [];
    for seed in range(1, 121) {
        plan = build_mission(
            seed,
            stream_for(seed, "mission"),
            archetypes[seed % 4],
            1 + seed % 3,
            1 + seed % 4,
            14 + seed % 20,
            float(seed % 10) / 10.0
        );
        validate_mission(plan);
        goal = [
            beat
            for beat in beats_of(plan)
            if beat.kind == "goal"
        ];
        assert len(goal) == 1 and goal[0].id in plan.route;
        for beat in beats_of(plan) {
            if beat.pattern and beat.pattern not in patterns {
                patterns.append(beat.pattern);
            }
        }
        for link in links_of(plan) {
            if link.mode not in modes {
                modes.append(link.mode);
            }
        }
    }
    for name in [
        "alternatives",
        "lock_key",
        "far_key",
        "shortcut",
        "hidden",
        "switch",
        "gambit"
    ] {
        assert name in patterns , "pattern never used: " + name;
    }
    for mode in ["open", "valve", "locked", "shortcut", "secret", "gate", "window"] {
        assert mode in modes , "link mode never used: " + mode;
    }
}

test "a mission whose goal needs an ungranted token is rejected" {
    plan = build_mission(5, stream_for(5, "mission"), "keys", 1, 1, 14, 0.5);
    gate = [
        link
        for link in links_of(plan)
        if link.mode == "gate"
    ][0];
    gate.needs = gate.needs + ["key_missing"];
    rejected = False;
    try {
        validate_mission(plan);
    } except AssertionError {
        rejected = True;
    }
    assert rejected;
}

test "spatial embedding and height solving succeed for most missions" {
    successes = 0;
    for seed in range(1, 61) {
        plan = build_mission(seed, stream_for(seed, "mission"), "keys", 2, 2, 22, 0.5);
        site = embed(plan, stream_for(seed, "layout"));
        if site.failures {
            continue;
        }
        target_heights(site, stream_for(seed, "heights"), 0.6);
        if not solve_heights(site) {
            continue;
        }
        successes += 1;
        rooms = rooms_of(site);
        # Rooms never overlap on the macro grid.
        for a in rooms {
            for b in rooms {
                if a.beat < b.beat {
                    overlap_x = a.x < b.x + b.w and b.x < a.x + a.w;
                    overlap_y = a.y < b.y + b.h and b.y < a.y + a.h;
                    assert not (overlap_x and overlap_y);
                }
            }
        }
    }
    assert successes >= 54 , "embedding success " + str(successes) + "/60";
}

test "expeditions are deterministic and proven completable in their geometry" {
    world = World();
    level = generate(world, "v2-42", []);
    again = generate(World(), "v2-42", []);
    assert len(level.bsp.faces) == len(again.bsp.faces);
    assert len(level.bsp.entities) == len(again.bsp.entities);
    for index in range(0, len(level.bsp.faces), 97) {
        assert level.bsp.faces[index].vertices[0].x
            == again.bsp.faces[index].vertices[0].x;
        assert level.bsp.faces[index].vertices[2].z
            == again.bsp.faces[index].vertices[2].z;
    }
    other = generate(World(), "v2-43", []);
    assert len(other.bsp.faces) != len(level.bsp.faces)
        or len(other.bsp.entities) != len(level.bsp.entities);
    found = survey_of(world);
    assert found is not None;
    record: Survey = found;
    plan = record.plan;
    bp = record.bp;
    site = record.site;
    assert plan is not None and bp is not None and site is not None;
    proof = progress(plan, bp, site, record.start[0], record.start[1]);
    assert proof.reached_exit;
    for token in plan.objectives {
        assert token in proof.tokens;
    }
    assert level.briefing and "extraction" in level.briefing;
}

test "entity wiring resolves every target and objective" {
    for seed in [3, 11, 42, 77] {
        level = generate(World(), "v2-" + str(seed), []);
        names: list[str] = [];
        for entity in level.bsp.entities {
            name = entity.fields.get("targetname", "");
            if name {
                names.append(name);
            }
        }
        starts = 0;
        for entity in level.bsp.entities {
            fields = entity.fields;
            kind = fields.get("classname", "");
            if kind == "info_player_start" {
                starts += 1;
            }
            target = fields.get("target", "");
            if target and not target.startswith("ambush_") {
                assert target in names , "unresolved target " + target;
            }
            if kind.startswith("monster_") or kind.startswith("item_") {
                assert fields.get("asset_game", "") in ["q1", "q2", "q3"];
            }
            assert kind
                not in [
                    "monster_zombie",
                    "monster_boss",
                    "monster_oldone",
                    "monster_jorg"
                ];
        }
        assert starts == 1;
    }
}

test "spawn is clear and stairs are walkable under real physics" {
    world = World();
    level = generate(world, "v2-8", []);
    found = survey_of(world);
    assert found is not None;
    record: Survey = found;
    start = Vec3(
        x=record.start[0],
        y=record.start[1],
        z=record.start[2] + level.collision.eye_height
    );
    assert not level.collision.trace(start, start).start_solid;
    bp = record.bp;
    assert bp is not None;
    walked = 0;
    for link in bp.routes {
        points = bp.routes[link];
        if len(points) < 6 or abs(points[0][2] - points[-1][2]) < 32.0 {
            continue;
        }
        if [
            door
            for door in bp.doors
            if door.link == link
        ] {
            continue;
        }
        player = Player(
            pos=Vec3(x=points[0][0], y=points[0][1], z=points[0][2] + 46.125)
        );
        for point in points[1:] {
            target = Vec3(x=point[0], y=point[1]);
            for tick in range(240) {
                delta = Vec3(x=target.x - player.pos.x, y=target.y - player.pos.y);
                if delta.length() < 6.0 {
                    break;
                }
                player spawn MovePlayer(
                    collision=level.collision, wish=delta.normalized(), dt=1.0 / 120.0
                );
            }
            assert Vec3(x=target.x - player.pos.x, y=target.y - player.pos.y).length()
                < 8.0;
        }
        assert abs(player.pos.z - (points[-1][2] + 46.125)) < 20.0;
        walked += 1;
        if walked >= 2 {
            break;
        }
    }
    assert walked >= 1;
}

test "cluster visibility never hides a column a player can see" {
    world = World();
    level = generate(world, "v2-21", []);
    found = survey_of(world);
    assert found is not None;
    record: Survey = found;
    bp = record.bp;
    assert bp is not None;
    occluder = ColumnOccluder(bp=bp);
    s = stream_for(21, "pvs-test");
    open_cells = [
        i
        for i in range(bp.width * bp.height)
        if bp.region[i] >= 0
    ];
    checked = 0;
    for attempt in range(4000) {
        a = open_cells[s.below(len(open_cells))];
        b = open_cells[s.below(len(open_cells))];
        ra = bp.region[a];
        rb = bp.region[b];
        if ra == rb {
            continue;
        }
        ax = float(a % bp.width) * 32.0 + 16.0;
        ay = float(a // bp.width) * 32.0 + 16.0;
        bx = float(b % bp.width) * 32.0 + 16.0;
        b_y = float(b // bp.width) * 32.0 + 16.0;
        az = float(bp.floor[a] + 40);
        bz = float(bp.floor[b] + 40);
        if az > float(bp.ceiling[a]) or bz > float(bp.ceiling[b]) {
            continue;
        }
        if not occluder.clear(ax, ay, az, bx, b_y, bz) {
            continue;
        }
        checked += 1;
        row = 8 + ra * level.bsp.cluster_bytes;
        assert int(level.bsp.visibility[row + rb // 8]) & (1 << (rb % 8)) , "PVS hides a visible region";
    }
    assert checked > 20;
    # Culling must actually cull something.
    assert record.visible_pairs < level.bsp.clusters * level.bsp.clusters;
}

test "column shadow rays agree with collision traces" {
    world = World();
    level = generate(world, "v2-5", []);
    found = survey_of(world);
    assert found is not None;
    record: Survey = found;
    bp = record.bp;
    assert bp is not None;
    movers = [
        i
        for i in range(len(level.collision.models))
        if level.collision.models[i] != 0
    ];
    column = ColumnOccluder(bp=bp);
    trace = TraceOccluder(collision=level.collision, excluded=movers);
    total = 0;
    agree = 0;
    for index in range(0, level.bsp.models[1].first_face, 23) {
        face = level.bsp.faces[index];
        if face.emission {
            continue;
        }
        u = face.vertices[1].sub(face.vertices[0]);
        v = face.vertices[-1].sub(face.vertices[0]);
        point = face.vertices[0].add(u.scale(0.37)).add(v.scale(0.61)).add(
            face.normal.scale(0.25)
        );
        for lamp in bp.lamps {
            target = Vec3(x=lamp.x, y=lamp.y, z=lamp.z);
            if target.sub(point).length() > lamp.radius {
                continue;
            }
            total += 1;
            if abs(column.visibility(point, target) - trace.visibility(point, target))
                < 0.01 {
                agree += 1;
            }
        }
    }
    assert total > 200 and float(agree) >= 0.98 * float(total);
}

test "keyed doors start locked" {
    world = World();
    generate(world, "v2-4", []);
    doors = [world->:HasDoor:->][?:Door];
    assert doors;
    for door in doors {
        if door.keys {
            assert not door.unlocked;
            for key in door.keys {
                assert key.startswith("key_");
            }
        }
    }
}

test "seeds select diverse niches and generation versions are strict" {
    niches: list[str] = [];
    for seed in range(1, 200) {
        code = str(niche_for(seed));
        if code not in niches {
            niches.append(code);
        }
    }
    assert len(niches) >= 70;
    for value in ["v1-1", "v2-0", "v2-2147483647", "v2-01", "v2--2", "v3-5"] {
        rejected = False;
        try {
            seed_from(value);
        } except ValueError {
            rejected = True;
        }
        assert rejected;
    }
    assert seed_from("v2-42") == 42;
}

test "candidate search spreads expeditions across descriptor space" {
    measured: list[list[float]] = [];
    archetypes: list[str] = [];
    recipes: list[str] = [];
    for seed in range(1, 13) {
        record = survey(seed);
        measured.append(record.measured);
        if record.archetype not in archetypes {
            archetypes.append(record.archetype);
        }
        bp = record.bp;
        if bp is not None {
            for beat in bp.interiors {
                recipe = bp.interiors[beat].recipe;
                if recipe not in recipes {
                    recipes.append(recipe);
                }
            }
        }
    }
    for axis in range(4) {
        values = [m[axis] for m in measured];
        assert max(values) - min(values) > 0.25 , "descriptor axis collapsed: "
            + str(axis);
    }
    assert len(archetypes) >= 3;
    assert len(recipes) >= 8;
}

import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.world.combat { CombatState }
test "saved asset manifests must match the generated level" {
    world = World();
    level = Level(asset_manifest="q1:stone|q2:metal|q3:blocks");
    player = Player();
    data = snapshot(world, level, player, CombatState());
    restore(world, level, player, CombatState(), data);
    level.asset_manifest = "changed";
    rejected = False;
    try {
        restore(world, level, player, CombatState(), data);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
}

import from engine.physics.collision { CollisionMap }
test "point traces hit a floor along an adjoining brush seam" {
    collision = CollisionMap();
    for x in [-10.0, 0.0] {
        collision.add_box(
            Vec3(x=x, y=-10.0, z=-2.0),
            Vec3(x=x + 10.0, y=10.0, z=0.0),
            Vec3(),
            Vec3(),
            Vec3()
        );
    }
    hit = collision.trace_point(Vec3(z=10.0), Vec3(z=-10.0));
    assert not hit.start_solid and abs(hit.fraction - 0.5) < 0.00001;
    assert hit.normal.z == 1.0;
}
