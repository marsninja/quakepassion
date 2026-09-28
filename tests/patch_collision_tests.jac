"""Quake III patch collision: cm_patch.c facets from the control grid."""
import from engine.physics.collision { CollisionMap }
import from engine.physics.patch_collide { generate_patch_collide, PatchCollide }
import from engine.physics.movement { MovePlayer }
import from engine.formats.bsp { Bsp, Face, Texture, Model, MapEntity }
import from engine.formats.q3.bsp { Vertex, tessellate }
import from engine.formats.brush_collision { build_brush_collision }
import from engine.math.vec3 { Vec3 }
import from engine.world.world { Player }

glob PATCH_TEST_MINS: Vec3 = Vec3(x=-15.0, y=-15.0, z=-24.0),
     PATCH_TEST_MAXS: Vec3 = Vec3(x=15.0, y=15.0, z=32.0);

"""Control points for a patch: column x, row y, height zs[row][column]."""
def grid_points(xs: list[float], ys: list[float], zs: list[list[float]]) -> list[Vec3] {
    points: list[Vec3] = [];
    for row in range(len(ys)) {
        for column in range(len(xs)) {
            points.append(Vec3(x=xs[column], y=ys[row], z=zs[row][column]));
        }
    }
    return points;
}

"""A Q3-sized collision map holding `patches` and axial boxes [lo, hi]."""
def patch_collision(patches: list[PatchCollide], boxes: list[list[Vec3]] = []) -> CollisionMap {
    collision = CollisionMap(
        eye_height=26.0, hull_mins=PATCH_TEST_MINS, hull_maxs=PATCH_TEST_MAXS
    );
    for box in boxes {
        collision.add_box(box[0], box[1], Vec3(), PATCH_TEST_MINS, PATCH_TEST_MAXS);
    }
    for patch in patches {
        collision.add_patch(patch, PATCH_TEST_MINS, PATCH_TEST_MAXS, Vec3());
    }
    collision.reindex();
    return collision;
}

"""A flat square patch reaching `size` units either side of the origin."""
def flat_patch(size: float = 64.0) -> PatchCollide {
    return generate_patch_collide(
        3,
        3,
        grid_points(
            [-size, 0.0, size],
            [-size, 0.0, size],
            [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
        )
    );
}

def patch_map(height: float = 0.0) -> Bsp {
    controls: list[Vertex] = [];
    for y in range(3) {
        for x in range(3) {
            controls.append(
                Vertex(
                    colors=[255.0, 255.0, 255.0, 255.0],
                    pos=Vec3(
                        x=float(x - 1) * 256.0,
                        y=float(y - 1) * 256.0,
                        z=height if x == 1 and y == 1 else 0.0
                    )
                )
            );
        }
    }
    face = Face(patch=True, planar=False);
    tessellate(face, controls, 3, 3);
    return Bsp(
        game="q3",
        faces=[face],
        textures=[Texture(contents=1)],
        models=[Model(head=0, first_face=0, face_count=1)]
    );
}

test "collision subdivides the control grid, not the rendered tessellation" {
    # A flat patch needs no subdivision: one quad facet, its surface plane,
    # four edge planes, and the flipped surface plane closing its back.
    flat = flat_patch();
    assert len(flat.facets) == 1;
    faces = flat.facets[0].outward(flat.planes);
    assert len(faces) == 6;
    assert faces[0].normal.z == 1.0 and faces[0].dist == 0.0;
    assert faces[5].normal.z == -1.0 and faces[5].dist == 0.0;
    for side in faces[1:5] {
        assert abs(side.normal.z) < 0.000001 and abs(side.dist - 64.0) < 0.000001;
    }
    # The hill bows 32 units, so its grid splits until every approximating
    # point lies within SUBDIVIDE_DISTANCE of the curve: far fewer facets than
    # the 128 rendered triangles.
    hill = generate_patch_collide(3, 3, patch_map(128.0).faces[0].patch_points);
    assert len(hill.facets) == 16;
    assert abs(hill.mins.z + 1.0) < 0.000001 and abs(hill.maxs.z - 33.0) < 0.000001;
    # Identical control rows (a degenerate patch) collapse to nothing.
    line = grid_points(
        [0.0, 64.0, 128.0],
        [0.0, 0.0, 0.0],
        [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
    );
    assert not generate_patch_collide(3, 3, line).facets;
}

test "boxes hit the front of a facet but pass through its back" {
    collision = patch_collision([flat_patch()]);
    # SURFACE_CLIP_EPSILON short of the expanded surface, not pulled back again.
    hit = collision.trace(Vec3(x=20.0, y=10.0, z=1000.0), Vec3(x=20.0, y=10.0, z=-1000.0));
    assert abs(hit.end.z - 24.125) < 0.000001 and hit.normal.z == 1.0;
    assert hit.surface_clip and not hit.start_solid;
    assert collision.trace(
        Vec3(x=20.0, y=10.0, z=-1000.0), Vec3(x=20.0, y=10.0, z=1000.0)
    ).fraction
        == 1.0;
    # Past the edge (plus the box) there is nothing to hit.
    assert collision.trace(Vec3(x=80.0, z=100.0), Vec3(x=80.0, z=-100.0)).fraction == 1.0;
    rim = collision.trace(Vec3(x=78.0, z=100.0), Vec3(x=78.0, z=-100.0));
    assert rim.fraction < 1.0 and rim.normal.z == 1.0;
    # Sideways into the facet's edge: its border plane stops the box.
    side = collision.trace(Vec3(x=200.0, z=10.0), Vec3(x=-200.0, z=10.0));
    assert abs(side.end.x - 79.125) < 0.000001 and side.normal.x == 1.0;
}

test "a box starts solid only when it does not move" {
    collision = patch_collision([flat_patch()]);
    inside = Vec3(x=5.0, y=5.0, z=10.0);
    assert collision.trace(inside, inside).start_solid;
    above = Vec3(x=5.0, y=5.0, z=30.0);
    assert collision.trace(above, above).fraction == 1.0;
    across = collision.trace(inside, Vec3(x=40.0, y=5.0, z=10.0));
    assert not across.start_solid and across.fraction == 1.0;
    down = collision.trace(inside, Vec3(x=5.0, y=5.0, z=-100.0));
    assert not down.start_solid and down.fraction == 1.0;
}

test "point traces hit a facet from in front only, inside its borders" {
    collision = patch_collision([flat_patch(10.0)]);
    hit = collision.trace_point(Vec3(x=2.0, y=3.0, z=10.0), Vec3(x=2.0, y=3.0, z=-10.0));
    assert abs(hit.end.z - 0.125) < 0.000001 and hit.normal.z == 1.0;
    assert collision.trace_point(
        Vec3(x=2.0, y=3.0, z=-10.0), Vec3(x=2.0, y=3.0, z=10.0)
    ).fraction
        == 1.0;
    assert collision.trace_point(
        Vec3(x=12.0, y=3.0, z=10.0), Vec3(x=12.0, y=3.0, z=-10.0)
    ).fraction
        == 1.0;
    assert collision.trace_point(Vec3(x=-20.0, z=1.0), Vec3(x=20.0, z=1.0)).fraction == 1.0;
}

test "curved Q3 patch collision follows the true curve" {
    collision = build_brush_collision(patch_map(128.0));
    assert len(collision.hulls) == 16;
    # The peak (32 units up) is a grid point, and the box rests on it.
    hit = collision.trace(Vec3(z=200.0), Vec3(z=-100.0));
    assert abs(hit.end.z - 56.125) < 0.000001 and hit.normal.z > 0.99;
    point = collision.trace_point(
        Vec3(x=10.0, y=3.0, z=200.0), Vec3(x=10.0, y=3.0, z=-100.0)
    );
    assert point.end.z > 31.0 and point.end.z < 32.0;
}

test "a curved ramp is walked up smoothly" {
    # A 256-unit run curving up 64 units (z = x * x / 1024), between a floor
    # and a landing.
    ramp = generate_patch_collide(
        3,
        3,
        grid_points(
            [0.0, 128.0, 256.0],
            [-128.0, 0.0, 128.0],
            [[0.0, 0.0, 64.0], [0.0, 0.0, 64.0], [0.0, 0.0, 64.0]]
        )
    );
    collision = patch_collision(
        [ramp],
        [
            [Vec3(x=-256.0, y=-128.0, z=-16.0), Vec3(x=0.0, y=128.0, z=0.0)],
            [Vec3(x=256.0, y=-128.0, z=48.0), Vec3(x=1024.0, y=128.0, z=64.0)]
        ]
    );
    player = Player(pos=Vec3(x=-200.0, z=26.0 + 24.5));
    for i in range(60) {
        player spawn MovePlayer(collision=collision, game="q3");
    }
    assert player.grounded;
    # The curve bows 16 units at its middle, so its collision grid is two
    # flat facets (chords never more than 4 units off the curve).
    assert len(ramp.facets) == 2;
    last = player.pos.z;
    while player.pos.x < 224.0 {
        player spawn MovePlayer(collision=collision, game="q3", wish=Vec3(x=1.0));
        origin = player.pos.sub(Vec3(z=26.0));
        foot = origin.z - 24.0;
        x = origin.x;
        curve = 0.0 if x < 0.0 else x * x / 1024.0;
        # Up to speed on the floor, it keeps it up the facets.
        assert player.grounded and (x < 0.0 or player.velocity.x > 280.0);
        assert not collision.trace(origin, origin).start_solid;
        # Never below the curve, and never above it by more than the chord's
        # rise under half the box plus the chord's bow.
        assert foot > curve - 0.01 and foot < curve + 10.0;
        assert player.pos.z >= last - 0.01 and player.pos.z - last < 4.0;
        last = player.pos.z;
    }
    # Over the crest (where Q3 kicks a fast walker off the ground) onto the landing.
    for i in range(120) {
        player spawn MovePlayer(collision=collision, game="q3", wish=Vec3(x=1.0));
    }
    assert player.grounded and player.pos.x > 500.0;
    assert abs(player.pos.z - 26.0 - 24.0 - 64.0) < 0.2;
}

test "a round pillar is slid around rather than stuck on" {
    # A closed cylinder of radius 64 (its first and last columns meet), wound
    # counterclockwise so its facets face out.
    r = 64.0;
    ring = [
        [r, 0.0],
        [r, r],
        [0.0, r],
        [-r, r],
        [-r, 0.0],
        [-r, -r],
        [0.0, -r],
        [r, -r],
        [r, 0.0]
    ];
    points: list[Vec3] = [];
    for z in [0.0, 64.0, 128.0] {
        for corner in ring {
            points.append(Vec3(x=corner[0], y=corner[1], z=z));
        }
    }
    pillar = generate_patch_collide(9, 3, points);
    collision = patch_collision(
        [pillar], [[Vec3(x=-512.0, y=-512.0, z=-16.0), Vec3(x=512.0, y=512.0, z=0.0)]]
    );
    # Every side blocks from outside and none from within.
    for direction in [
        Vec3(x=1.0),
        Vec3(y=1.0),
        Vec3(x=-0.6, y=0.8),
        Vec3(x=-0.8, y=-0.6)
    ] {
        outside = collision.trace(direction.scale(300.0).add(Vec3(z=60.0)), Vec3(z=60.0));
        assert outside.fraction < 1.0 and outside.normal.dot(direction) > 0.9;
        assert outside.end.sub(Vec3(z=60.0)).length() > 64.0 + 14.0;
        inside = collision.trace_point(
            Vec3(z=60.0), direction.scale(300.0).add(Vec3(z=60.0))
        );
        assert inside.fraction == 1.0;
    }
    # Off to the side of the facet corner ahead, so the box meets a facet.
    player = Player(pos=Vec3(x=-250.0, y=30.0, z=24.5 + 26.0));
    for i in range(360) {
        player spawn MovePlayer(collision=collision, game="q3", wish=Vec3(x=1.0));
        origin = player.pos.sub(Vec3(z=26.0));
        assert not collision.trace(origin, origin).start_solid;
        assert Vec3(x=origin.x, y=origin.y).length() > 64.0 + 14.0;
    }
    assert player.pos.x > 150.0 and player.pos.y > 30.0;
}

test "walking crosses patch facet seams without sinking or sticking" {
    collision = build_brush_collision(patch_map());
    player = Player(pos=Vec3(x=-100.0, z=100.0));
    for i in range(240) {
        player spawn MovePlayer(collision=collision);
    }
    assert player.grounded and abs(player.pos.z - 50.125) < 0.001;
    for i in range(70) {
        player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0));
        assert player.grounded and abs(player.pos.z - 50.125) < 0.001;
    }
    assert player.pos.x > 50.0;
}

test "only solid patches collide including hidden and translated model surfaces" {
    bsp = patch_map();
    bsp.textures[0].contents = 0;
    assert not build_brush_collision(bsp).hulls;
    bsp.textures[0].contents = 65536;
    bsp.faces[0].hidden = True;
    playerclip = build_brush_collision(bsp);
    assert len(playerclip.hulls) == 1;
    # Shots (MASK_SHOT) pass player clip; bodies do not.
    assert playerclip.trace_point(Vec3(x=3.0, z=10.0), Vec3(x=3.0, z=-10.0)).fraction == 1.0;
    assert playerclip.trace(Vec3(x=3.0, z=100.0), Vec3(x=3.0, z=-10.0)).fraction < 1.0;
    bsp.models[0].face_count = 0;
    bsp.models.append(Model(head=0, first_face=0, face_count=1));
    bsp.entities = [
        MapEntity(
            fields={"classname": "func_static", "model": "*1", "origin": "0 0 100"}
        )
    ];
    hit = build_brush_collision(bsp).trace(Vec3(x=3.0, z=300.0), Vec3(x=3.0));
    assert abs(hit.end.z - 124.125) < 0.001 and hit.model == 1;
}

test "patch surface flags keep shots from leaving impacts or marks" {
    bsp = patch_map();
    bsp.textures[0].flags = 16;
    silent = build_brush_collision(bsp);
    hit = silent.trace_point(Vec3(x=3.0, z=10.0), Vec3(x=3.0, z=-10.0));
    assert hit.fraction < 1.0 and silent.surface_class(hit) == 2;
    bsp.textures[0].flags = 32;
    unmarked = build_brush_collision(bsp);
    assert unmarked.surface_class(
        unmarked.trace_point(Vec3(x=3.0, z=10.0), Vec3(x=3.0, z=-10.0))
    )
        == 1;
}

test "a broad brush bound cannot collapse the patch spatial tree" {
    import from engine.physics.collision { group_hulls, FindHulls }
    import from engine.math.aabb { AABB }
    bounds = [
        AABB(
            mins=Vec3(x=-1.0e30, y=-1.0e30, z=-1.0e30),
            maxs=Vec3(x=1.0e30, y=1.0e30, z=1.0e30)
        )
    ];
    for i in range(1, 33) {
        bounds.append(
            AABB(
                mins=Vec3(x=float(i) * 100.0 - 10.0, y=-10.0, z=-10.0),
                maxs=Vec3(x=float(i) * 100.0 + 10.0, y=10.0, z=10.0)
            )
        );
    }
    tree = group_hulls(bounds, list(range(len(bounds))));
    query = tree spawn FindHulls(mins=Vec3(x=100.0), maxs=Vec3(x=100.0));
    assert 0 in query.indices and 1 in query.indices;
    assert len(query.indices) <= 8;
}
