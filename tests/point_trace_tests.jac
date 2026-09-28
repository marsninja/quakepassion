"""Weapon-sized queries preserve geometry independently of player hull expansion."""
import from engine.physics.collision { CollisionMap }
import from engine.physics.patch_collide { generate_patch_collide }
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Bsp, Branch, Leaf, Model, Plane, MapEntity }
import from engine.formats.q1.collision { build_collision }
import from engine.formats.brush_collision { build_brush_collision }
import from tests.brush_collision_tests { brush_map }

test "point traces hit the actual brush surface and preserve moving model identity" {
    for game in ["q2", "q3"] {
        bsp = brush_map(game, 1);
        collision = build_brush_collision(bsp);
        hit = collision.trace_point(Vec3(z=100.0), Vec3(z=-100.0));
        assert abs(hit.end.z) < 0.000001 and hit.normal.z == 1.0;
        assert hit.model == 0 and hit.hull == 0;
        assert collision.trace(Vec3(z=100.0), Vec3(z=-100.0)).end.z > 24.0;
        assert collision.trace_point(Vec3(z=-5.0), Vec3(z=-5.0)).start_solid;
        assert collision.trace_point(Vec3(z=2.0), Vec3(z=2.0)).fraction == 1.0;
        assert collision.trace_point(
            Vec3(z=100.0), Vec3(z=-100.0), exclude=[0]
        ).fraction
            == 1.0;
        collision.offsets[0] = Vec3(z=7.0);
        hit = collision.trace_point(Vec3(z=100.0), Vec3(z=-100.0));
        assert abs(hit.end.z - 7.0) < 0.000001;
    }
}

test "point traces ignore playerclip while retaining solid and Q2 windows" {
    for game in ["q2", "q3"] {
        for contents in [1, 2, 32, 65536] {
            collision = build_brush_collision(brush_map(game, contents));
            hit = collision.trace_point(Vec3(z=100.0), Vec3(z=-100.0));
            assert (hit.fraction < 1.0)
                == (contents == 1 or (game == "q2" and contents == 2));
        }
    }
}

test "nearest translated submodel wins regardless of hull insertion order" {
    bsp = brush_map("q2", 1);
    bsp.models[0].brushes = [];
    bsp.models.append(Model(head=0, first_face=0, face_count=0, brushes=[0]));
    bsp.models.append(Model(head=0, first_face=0, face_count=0, brushes=[0]));
    bsp.entities = [
        MapEntity(
            fields={"classname": "func_door", "model": "*1", "origin": "100 0 0"}
        ),
        MapEntity(fields={"classname": "func_wall", "model": "*2", "origin": "50 0 0"})
    ];
    collision = build_brush_collision(bsp);
    start = Vec3(z=-5.0);
    finish = Vec3(x=200.0, z=-5.0);
    hit = collision.trace_point(start, finish);
    assert hit.model == 2 and hit.hull == 1;
    assert abs(hit.end.x - 40.0) < 0.000001;
    hit = collision.trace_point(start, finish, exclude=[1]);
    assert hit.model == 1 and abs(hit.end.x - 90.0) < 0.000001;
}

test "point traces cross patch facets from behind without facet box false positives" {
    collision = CollisionMap();
    points: list[Vec3] = [];
    for row in range(3) {
        for column in range(3) {
            points.append(Vec3(x=float(column) * 5.0, y=float(row) * 5.0));
        }
    }
    collision.add_patch(
        generate_patch_collide(3, 3, points),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3()
    );
    collision.reindex();
    # CM_TracePointThroughPatchCollide: the front side stops the point
    # SURFACE_CLIP_EPSILON short; the back side does not stop it at all.
    hit = collision.trace_point(Vec3(x=2.0, y=3.0, z=10.0), Vec3(x=2.0, y=3.0, z=-10.0));
    assert abs(hit.end.z - 0.125) < 0.000001 and hit.normal.z == 1.0 and not hit.start_solid;
    assert collision.trace_point(
        Vec3(x=2.0, y=3.0, z=-10.0), Vec3(x=2.0, y=3.0, z=10.0)
    ).fraction
        == 1.0;
    # Within the box-expanded bounds but past the facet's edge.
    assert collision.trace_point(
        Vec3(x=12.0, y=3.0, z=10.0), Vec3(x=12.0, y=3.0, z=-10.0)
    ).fraction
        == 1.0;
    assert collision.trace_point(Vec3(x=-5.0, y=3.0, z=1.0), Vec3(x=15.0, y=3.0, z=1.0)).fraction
        == 1.0;
}

test "Quake one point queries use render BSP leaves and share mover offsets" {
    bsp = Bsp(
        planes=[
            Plane(normal=Vec3(z=1.0), distance=0.0),
            Plane(normal=Vec3(z=1.0), distance=24.0)
        ],
        branches=[Branch(plane=0, front=-2, back=-1)],
        clipnodes=[Branch(plane=1, front=-1, back=-2)],
        leaves=[
            Leaf(contents=-2, vis_offset=-1, mins=Vec3(), maxs=Vec3()),
            Leaf(contents=-1, vis_offset=-1, mins=Vec3(), maxs=Vec3())
        ],
        models=[Model(head=0, player_hull=0, first_face=0, face_count=0)]
    );
    collision = build_collision(bsp);
    assert collision.trace(Vec3(z=100.0), Vec3(z=-100.0)).end.z > 24.0;
    assert abs(collision.trace_point(Vec3(z=100.0), Vec3(z=-100.0)).end.z) < 0.000001;
    collision.offsets[0] = Vec3(z=12.0);
    assert abs(collision.trace_point(Vec3(z=100.0), Vec3(z=-100.0)).end.z - 12.0)
        < 0.000001;
    assert collision.trace_point(Vec3(z=11.0), Vec3(z=20.0)).start_solid;
}
