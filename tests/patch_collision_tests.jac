import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { MovePlayer }
import from engine.formats.bsp { Bsp, Face, Texture, Model, MapEntity }
import from engine.formats.q3.bsp { Vertex, tessellate }
import from engine.formats.brush_collision { build_brush_collision }
import from engine.math.vec3 { Vec3 }
import from engine.world.world { Player }

def triangle_map() -> CollisionMap {
    collision = CollisionMap();
    collision.add_triangle(
        Vec3(),
        Vec3(x=100.0),
        Vec3(y=100.0),
        Vec3(x=-15.0, y=-15.0, z=-24.0),
        Vec3(x=15.0, y=15.0, z=32.0),
        Vec3()
    );
    collision.reindex();
    return collision;
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

test "triangle facets stop fast sweeps from both sides and reject empty corners" {
    collision = triangle_map();
    hit = collision.trace(
        Vec3(x=20.0, y=20.0, z=1000.0), Vec3(x=20.0, y=20.0, z=-1000.0)
    );
    assert abs(hit.end.z - 24.03125) < 0.0001 and hit.normal.z == 1.0;
    below = collision.trace(
        Vec3(x=20.0, y=20.0, z=-1000.0), Vec3(x=20.0, y=20.0, z=1000.0)
    );
    assert abs(below.end.z + 32.03125) < 0.0001 and below.normal.z == -1.0;
    assert collision.trace(
        Vec3(x=90.0, y=90.0, z=100.0), Vec3(x=90.0, y=90.0, z=-100.0)
    ).fraction
        == 1.0;
    assert collision.trace(
        Vec3(x=55.0, y=55.0, z=100.0), Vec3(x=55.0, y=55.0, z=-100.0)
    ).fraction
        < 1.0;
    assert collision.trace(Vec3(x=20.0, y=20.0), Vec3(x=20.0, y=20.0)).start_solid;
}

test "degenerate facets are skipped and vertical facets block sideways sweeps" {
    collision = CollisionMap();
    collision.add_triangle(Vec3(), Vec3(), Vec3(), Vec3(), Vec3(), Vec3());
    assert not collision.hulls;
    collision.add_triangle(
        Vec3(y=-100.0, z=-100.0),
        Vec3(y=100.0, z=-100.0),
        Vec3(z=100.0),
        Vec3(x=-15.0, y=-15.0, z=-24.0),
        Vec3(x=15.0, y=15.0, z=32.0),
        Vec3(x=50.0)
    );
    collision.reindex();
    hit = collision.trace(Vec3(x=200.0), Vec3(x=-200.0));
    assert abs(hit.end.x - 65.03125) < 0.0001 and hit.normal.x == 1.0;
}

test "curved Q3 patch collision follows the rendered tessellation" {
    collision = build_brush_collision(patch_map(128.0));
    assert len(collision.hulls) == 128;
    hit = collision.trace(Vec3(z=200.0), Vec3(z=-100.0));
    assert abs(hit.end.z - 56.03125) < 0.1;
    assert hit.normal.z > 0.9;
}

test "walking crosses patch triangle seams without sinking or sticking" {
    collision = build_brush_collision(patch_map());
    player = Player(pos=Vec3(x=-100.0, z=100.0));
    for i in range(240) {
        player spawn MovePlayer(collision=collision);
    }
    assert player.grounded and abs(player.pos.z - 50.03125) < 0.001;
    for i in range(70) {
        player spawn MovePlayer(collision=collision, wish=Vec3(x=1.0));
        assert player.grounded and abs(player.pos.z - 50.03125) < 0.001;
    }
    assert player.pos.x > 50.0;
}

test "only solid patches collide including hidden and translated model surfaces" {
    bsp = patch_map();
    bsp.textures[0].contents = 0;
    assert not build_brush_collision(bsp).hulls;
    bsp.textures[0].contents = 65536;
    bsp.faces[0].hidden = True;
    assert len(build_brush_collision(bsp).hulls) == 128;
    bsp.models[0].face_count = 0;
    bsp.models.append(Model(head=0, first_face=0, face_count=1));
    bsp.entities = [
        MapEntity(
            fields={"classname": "func_static", "model": "*1", "origin": "0 0 100"}
        )
    ];
    hit = build_brush_collision(bsp).trace(Vec3(z=300.0), Vec3());
    assert abs(hit.end.z - 124.03125) < 0.001;
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
