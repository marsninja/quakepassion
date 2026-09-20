"""Q2 WAL bounds, Q3 patch geometry, and cluster visibility regression tests."""
import struct;
import from engine.formats.bsp { Bsp, Face, Leaf, Model }
import from engine.formats.q2.bsp { parse_wal, parse_q2 }
import from engine.formats.q3.bsp { Vertex, tessellate, parse_q3 }
import from engine.world.level { Level, Split, BspArea, Front, Back }
import from engine.world.world { World }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

test "WAL reads first mip and rejects a truncated payload" {
    header = bytes(32) + struct.pack("<iii", 2, 2, 100) + bytes(56);
    texture = parse_wal(header + b"\x01\x02\x03\x04", "test");
    assert texture.width == 2 and texture.height == 2;
    assert texture.pixels == b"\x01\x02\x03\x04";
    caught = False;
    try {
        parse_wal(header + b"\x01", "bad");
    } except ValueError {
        caught = True;
    }
    assert caught;
}

test "quadratic patch interpolates center corners UVs and winding" {
    controls: list[Vertex] = [];
    for y in range(3) {
        for x in range(3) {
            controls.append(
                Vertex(
                    pos=Vec3(
                        x=float(x), y=float(y), z=4.0 if x == 1 and y == 1 else 0.0
                    ),
                    s=float(x) / 2.0,
                    t=float(y) / 2.0,
                    ls=float(x) / 2.0,
                    lt=float(y) / 2.0,
                    colors=[100.0, 150.0, 200.0, 255.0]
                )
            );
        }
    }
    face = Face();
    tessellate(face, controls, 3, 3, 2);
    assert len(face.vertices) == 9 and len(face.indices) == 24;
    assert face.vertices[0].x == 0.0 and face.vertices[8].y == 2.0;
    assert abs(face.vertices[4].z - 1.0) < 0.00001;
    assert face.uv[8] == 0.5 and face.uv[9] == 0.5;
    assert face.light_uv[8] == 63.5;
    assert face.colors[16] == 100;
    a = face.vertices[face.indices[0]];
    b = face.vertices[face.indices[1]];
    c = face.vertices[face.indices[2]];
    assert b.sub(a).cross(c.sub(a)).z > 0.0;
    caught = False;
    try {
        tessellate(Face(), controls, 2, 3);
    } except ValueError {
        caught = True;
    }
    assert caught;
}

test "Q2 and Q3 reject the wrong BSP version before tables" {
    caught = False;
    try {
        parse_q2(b"IBSP" + struct.pack("<i", 46) + bytes(152), []);
    } except ValueError {
        caught = True;
    }
    assert caught;
    caught = False;
    try {
        parse_q3(b"IBSP" + struct.pack("<i", 38) + bytes(136));
    } except ValueError {
        caught = True;
    }
    assert caught;
}

test "cluster zero and leaf zero participate in Q3 visibility" {
    world = World();
    areas: list[BspArea] = [];
    leaves: list[Leaf] = [];
    for i in range(3) {
        area = BspArea(
            name=str(i), index=i, faces=[10 + i], bounds=AABB(mins=Vec3(), maxs=Vec3())
        );
        world ++> area;
        areas.append(area);
        leaves.append(
            Leaf(contents=0, vis_offset=-1, cluster=i, mins=Vec3(), maxs=Vec3())
        );
    }
    split = Split(normal=Vec3(x=1.0), distance=0.0);
    split +>:Front:+> areas[0];
    split +>:Back:+> areas[1];
    bsp = Bsp(
        game="q3",
        clusters=3,
        cluster_bytes=1,
        visibility=struct.pack("<ii", 3, 1) + b"\x05\x02\x05",
        leaves=leaves,
        models=[Model(head=0, first_face=0, face_count=3)]
    );
    level = Level(active=True, bsp=bsp, areas=areas, splits=[split]);
    assert level.visible(world, Vec3(x=1.0), True) == [10, 12];
    assert level.visible(world, Vec3(x=-1.0), True) == [11];
    assert level.visible(world, Vec3(x=1.0), False) == [10, 11, 12];
    bsp.game = "q2";
    bsp.visibility = struct.pack("<iiiiiii", 3, 28, 28, 29, 29, 30, 30)
        + b"\x05\x02\x05";
    assert level.visible(world, Vec3(x=1.0), True) == [10, 12];
    assert level.visible(world, Vec3(x=-1.0), True) == [11];
}

test "Q3 alpha testing follows the selected image stage" {
    import from engine.assets.pk3 { Pk3Assets }
    assets = Pk3Assets();
    assets.parse_shaders(
        "opaque { { map $lightmap alphaFunc GE128 } { map textures/solid.tga } }\n"
            + "masked { { alphaFunc GT0 map textures/mask.tga } { map textures/glow.tga alphaFunc LT128 } }\n"
            + "animated { { animMap 4 textures/frame1.tga textures/frame2.tga alphaFunc GE128 } }"
    );
    assert assets.shaders["opaque"] == "textures/solid.tga";
    assert assets.alpha_tests["opaque"] == 0;
    assert assets.shaders["masked"] == "textures/mask.tga";
    assert assets.alpha_tests["masked"] == 1;
    assert assets.shaders["animated"] == "textures/frame1.tga";
    assert assets.alpha_tests["animated"] == 2;
}

test "Q3 additive and two sided material flags follow shader stages" {
    import from engine.assets.pk3 { Pk3Assets }
    assets = Pk3Assets();
    assets.parse_shaders(
        "flame { cull disable { map flame.tga blendFunc GL_ONE GL_ONE } }\n"
            + "wall { { map wall.tga } { map glow.tga blendFunc add } }\n"
            + "fire { { blendFunc add map fire.tga } }"
    );
    assert assets.additive["flame"] and assets.two_sided["flame"];
    assert not assets.additive["wall"] and not assets.two_sided["wall"];
    assert assets.additive["fire"];
}

def q2_leaf_model(head: int) -> bytes {
    lumps: list[bytes] = [];
    for i in range(19) {
        lumps.append(b"");
    }
    lumps[0] = b'{"classname" "worldspawn"}\x00';
    lumps[1] = struct.pack("<ffffi", 1.0, 0.0, 0.0, 0.0, 0);
    lumps[4] = struct.pack("<iii", 0, -1, -1) + bytes(16);
    lumps[8] = struct.pack("<ihh", 1, -1, 0) + bytes(20);
    lumps[13] = bytes(36)
        + struct.pack("<iii", 0, 0, 0)
        + bytes(36)
        + struct.pack("<iii", head, 0, 0);
    directory = b"IBSP" + struct.pack("<i", 38);
    payload = b"";
    offset = 160;
    for lump in lumps {
        directory += struct.pack("<ii", offset, len(lump));
        payload += lump;
        offset += len(lump);
    }
    return directory + payload;
}

test "Q2 empty brush models may have a leaf as their root" {
    bsp = parse_q2(q2_leaf_model(-1), []);
    assert len(bsp.models) == 2;
    assert bsp.models[1].head == -1 and bsp.models[1].face_count == 0;
    caught = False;
    try {
        parse_q2(q2_leaf_model(-2), []);
    } except ValueError {
        caught = True;
    }
    assert caught;
}
