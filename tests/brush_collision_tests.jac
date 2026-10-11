import from engine.physics.collision { CollisionMap }
import from engine.formats.bsp { Bsp, Brush, Plane, Model, MapEntity }
import from engine.formats.brush_collision { build_brush_collision }
import from engine.math.vec3 { Vec3 }

def brush_map(game: str, contents: int) -> Bsp {
    return Bsp(
        game=game,
        planes=[
            Plane(normal=Vec3(x=1.0), distance=10.0),
            Plane(normal=Vec3(x=-1.0), distance=10.0),
            Plane(normal=Vec3(y=1.0), distance=10.0),
            Plane(normal=Vec3(y=-1.0), distance=10.0),
            Plane(normal=Vec3(z=1.0), distance=0.0),
            Plane(normal=Vec3(z=-1.0), distance=10.0)
        ],
        brushes=[Brush(planes=[0, 1, 2, 3, 4, 5], contents=contents)],
        models=[Model(head=0, first_face=0, face_count=0, brushes=[0])]
    );
}

test "brush hulls expand by each game's standing player dimensions" {
    for game in ["q2", "q3"] {
        collision = build_brush_collision(brush_map(game, 1));
        hit = collision.trace(Vec3(z=100.0), Vec3(z=-100.0));
        assert abs(hit.end.z - 24.03125) < 0.0001;
        assert hit.normal.z == 1.0 and not hit.start_solid;
        side = collision.trace(Vec3(x=100.0), Vec3());
        width = 16.0 if game == "q2" else 15.0;
        assert abs(side.end.x - (10.03125 + width)) < 0.0001;
        assert collision.trace(Vec3(), Vec3()).start_solid;
        assert collision.eye_height == (22.0 if game == "q2" else 26.0);
    }
}

test "player clipping respects solid window and playerclip contents" {
    for game in ["q2", "q3"] {
        for contents in [1, 2, 32, 65536] {
            collision = build_brush_collision(brush_map(game, contents));
            hit = collision.trace(Vec3(z=100.0), Vec3(z=-100.0));
            blocks = contents == 1
                or contents == 65536
                or (game == "q2" and contents == 2);
            assert (hit.fraction < 1.0) == blocks;
        }
    }
}

test "translated brush entities collide while triggers do not" {
    bsp = brush_map("q2", 1);
    bsp.models[0].brushes = [];
    bsp.models.append(Model(head=0, first_face=0, face_count=0, brushes=[0]));
    bsp.entities = [
        MapEntity(fields={"classname": "func_wall", "model": "*1", "origin": "100 0 0"})
    ];
    collision = build_brush_collision(bsp);
    assert not collision.trace(Vec3(), Vec3()).start_solid;
    assert collision.trace(Vec3(x=100.0), Vec3(x=100.0)).start_solid;
    bsp.entities[0].fields["classname"] = "trigger_multiple";
    collision = build_brush_collision(bsp);
    assert not collision.hulls;
}

test "spatial hull queries agree with exhaustive sweeps" {
    bsp = brush_map("q3", 1);
    collision = CollisionMap();
    normals = [p.normal for p in bsp.planes];
    distances = [p.distance for p in bsp.planes];
    for i in range(24) {
        collision.add_brush(
            normals,
            distances,
            Vec3(x=-15.0, y=-15.0, z=-24.0),
            Vec3(x=15.0, y=15.0, z=32.0),
            Vec3(x=float(i) * 100.0)
        );
    }
    exhaustive = CollisionMap(hulls=collision.hulls, offsets=collision.offsets);
    collision.reindex();
    assert len(collision.groups) == 1;
    for i in range(48) {
        start = Vec3(x=float(i) * 50.0 - 30.0, z=100.0);
        finish = start.add(Vec3(x=90.0, z=-200.0));
        actual = collision.trace(start, finish);
        expected = exhaustive.trace(start, finish);
        assert abs(actual.fraction - expected.fraction) < 0.000001;
        assert actual.start_solid == expected.start_solid;
        assert actual.normal.sub(expected.normal).length() < 0.000001;
    }
}

test "clip brushes stop only the masks that name them" {
    # CONTENTS_SOLID 1, CONTENTS_WINDOW 2, CONTENTS_PLAYERCLIP 65536,
    # CONTENTS_MONSTERCLIP 131072. Each row: the contents, then whether Q2's
    # MASK_PLAYERSOLID, MASK_MONSTERSOLID and MASK_SOLID stop at them.
    item_mins = Vec3(x=-15.0, y=-15.0, z=-15.0);
    item_maxs = Vec3(x=15.0, y=15.0, z=15.0);
    for row in [
        (1, True, True, True), (2, True, True, True), (65536, True, False, False),
        (131072, False, True, False), (196608, True, True, False), (65537, True, True, True)
    ] {
        collision = build_brush_collision(brush_map("q2", row[0]));
        monster = collision.for_body(22.0, 0.0, None, None, "monster");
        item = collision.for_body(0.0, 0.0, item_mins, item_maxs, "solid");
        assert collision.mask == "player" and monster.mask == "monster" and item.mask == "solid";
        assert (collision.trace(Vec3(z=100.0), Vec3(z=-100.0)).fraction < 1.0) == row[1] , str(row[0]);
        assert (monster.trace(Vec3(z=100.0), Vec3(z=-100.0)).fraction < 1.0) == row[2] , str(row[0]);
        assert (item.trace(Vec3(z=100.0), Vec3(z=-100.0)).fraction < 1.0) == row[3] , str(row[0]);
        assert collision.trace(Vec3(), Vec3()).start_solid == row[1];
        assert monster.trace(Vec3(), Vec3()).start_solid == row[2];
        assert item.trace(Vec3(), Vec3()).start_solid == row[3];
        assert [collision.passes(0), monster.passes(0), item.passes(0)]
            == [not row[1], not row[2], not row[3]];
        # A monster's own box keeps the mask, and a shot (MASK_SHOT) stops
        # only at what is solid.
        wide = collision.for_body(22.0, 0.0, Vec3(x=-32.0, y=-32.0, z=-24.0), Vec3(x=32.0, y=32.0, z=64.0), "monster");
        assert wide.trace(Vec3(), Vec3()).start_solid == row[2];
        for view in [collision, monster, item] {
            assert (view.trace_point(Vec3(z=100.0), Vec3(z=-100.0)).fraction < 1.0) == row[3];
        }
    }
    # Q3 has no monster mask: its player clip stops every body, and nothing
    # that traces with MASK_SOLID (an item put down by FinishSpawningItem).
    arena = build_brush_collision(brush_map("q3", 65536));
    assert arena.trace(Vec3(), Vec3()).start_solid and not arena.player_clips;
    assert arena.for_body(26.0, 0.0, None, None, "monster").trace(Vec3(), Vec3()).start_solid;
    placed = arena.for_body(0.0, 0.0, item_mins, item_maxs, "solid");
    assert not placed.trace(Vec3(), Vec3()).start_solid;
    assert placed.trace(Vec3(z=100.0), Vec3(z=-100.0)).fraction == 1.0;
    walled = build_brush_collision(brush_map("q3", 1));
    assert walled.for_body(0.0, 0.0, item_mins, item_maxs, "solid").trace(Vec3(), Vec3()).start_solid;
    assert not walled.clips and arena.clips == {0};
}
