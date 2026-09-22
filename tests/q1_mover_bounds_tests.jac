import from engine.formats.bsp { Bsp, Model, Plane, Branch, MapEntity }
import from engine.formats.q1.collision { build_collision }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "Q1 contracted model bounds cannot cull real hull contacts" {
    bsp = Bsp(game="q1");
    normals = [
        Vec3(x=1.0),
        Vec3(x=-1.0),
        Vec3(y=1.0),
        Vec3(y=-1.0),
        Vec3(z=1.0),
        Vec3(z=-1.0)
    ];
    # Physical brush [-8,8] x [-8,8] x [0,16], expanded by standing hull.
    distances = [24.0, 24.0, 24.0, 24.0, 40.0, 32.0];
    for i in range(6) {
        bsp.planes.append(Plane(normal=normals[i], distance=distances[i]));
        bsp.clipnodes.append(Branch(plane=i, front=-1, back=i + 1 if i < 5 else -2));
    }
    bsp.models = [
        Model(head=-1, first_face=0, face_count=0),
        Model(
            head=-1,
            first_face=0,
            face_count=0,
            player_hull=0,
            mins=Vec3(x=-7.0, y=-7.0, z=1.0),
            maxs=Vec3(x=7.0, y=7.0, z=15.0)
        )
    ];
    bsp.entities = [
        MapEntity(fields={"classname": "func_plat", "model": "*1", "origin": "0 0 10"})
    ];
    indexed = build_collision(bsp);
    exhaustive = CollisionMap(
        hulls=indexed.hulls, offsets=indexed.offsets, models=indexed.models
    );
    for offset in [
        Vec3(x=23.5, z=18.0),
        Vec3(x=-23.5, z=18.0),
        Vec3(y=23.5, z=18.0),
        Vec3(y=-23.5, z=18.0),
        Vec3(z=49.5),
        Vec3(z=-21.5)
    ] {
        assert exhaustive.trace(offset, offset).start_solid;
        assert indexed.trace(offset, offset).start_solid;
    }
    hit = indexed.trace(Vec3(z=50.1), Vec3(z=49.9));
    assert not hit.start_solid and hit.fraction < 1.0;
    assert abs(hit.end.z - 50.03125) < 0.000001;
}
