import struct;
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame }
import from engine.math.vec3 { Vec3 }
import from engine.render.models {
    pack_model_keyframes,
    pack_model_corners,
    model_normal_code,
    model_normal_decode,
    MODEL_FRAME_ROW
}
import from engine.render.cubes { unit_cube_corners }

def texel_at(texels: bytes, index: int) -> list[float] {
    values = struct.unpack_from("<ffff", texels, index * 16);
    return [float(values[0]), float(values[1]), float(values[2]), float(values[3])];
}

def corner_at(records: bytes, index: int) -> list[float] {
    values = struct.unpack_from("<ffff", records, index * 16);
    return [float(values[0]), float(values[1]), float(values[2]), float(values[3])];
}

"""Two surfaces: a lit triangle over two frames and an unlit one over two."""
def two_surfaces() -> AnimatedModel {
    lit = AnimatedSurface(name="lit", indices=[0, 1, 2], uv=[0.0, 0.0, 1.0, 0.0, 0.0, 1.0]);
    for step in range(2) {
        lit.frames.append(
            AnimationFrame(
                vertices=[Vec3(x=float(step)), Vec3(y=1.0), Vec3(z=2.0)],
                normals=[Vec3(z=1.0), Vec3(x=1.0), Vec3(z=-1.0)]
            )
        );
    }
    plain = AnimatedSurface(name="plain", indices=[0, 1, 2, 1, 3, 2], uv=[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.25, 0.75]);
    for step in range(2) {
        plain.frames.append(
            AnimationFrame(vertices=[Vec3(x=10.0 + float(step)), Vec3(x=11.0), Vec3(x=12.0), Vec3(x=13.0)])
        );
    }
    return AnimatedModel(surfaces=[lit, plain]);
}

test "keyframes lay surfaces' frames out one after another" {
    keyframes = pack_model_keyframes(two_surfaces());
    assert keyframes.bases == [0, 6];
    assert keyframes.vertices == [3, 4];
    assert keyframes.frames == 2;
    assert keyframes.width == 14 and keyframes.height == 1;
    # Surface 0 frame 1 vertex 0, surface 1 frame 1 vertex 0.
    assert texel_at(keyframes.texels, 3)[0] == 1.0;
    assert texel_at(keyframes.texels, 6 + 4)[0] == 11.0;
    # Formats without normals are marked for the flat Q1/Q2 shade.
    assert texel_at(keyframes.texels, 6)[3] == -1.0;
    assert texel_at(keyframes.texels, 0)[3] >= 0.0;
}

test "keyframes wrap into rows of the texture width" {
    surface = AnimatedSurface(indices=[0, 1, 2], uv=[0.0] * 6);
    for step in range(3) {
        surface.frames.append(
            AnimationFrame(vertices=[Vec3(x=float(step * 2000 + i)) for i in range(2000)])
        );
    }
    keyframes = pack_model_keyframes(AnimatedModel(surfaces=[surface]));
    assert keyframes.width == MODEL_FRAME_ROW;
    assert keyframes.height == 2;
    assert len(keyframes.texels) == MODEL_FRAME_ROW * 2 * 16;
    assert texel_at(keyframes.texels, 5999)[0] == 5999.0;
}

test "corners keep the reversed winding and point at frame 0" {
    model = two_surfaces();
    keyframes = pack_model_keyframes(model);
    corners = pack_model_corners(model, keyframes);
    assert corners.firsts == [0, 3];
    assert corners.counts == [3, 6];
    assert [corner_at(corners.records, i)[0] for i in range(3)] == [0.0, 2.0, 1.0];
    second = corner_at(corners.records, 4);
    assert second[0] == 6.0 + 2.0 and second[1] == 4.0;
    assert abs(second[2] - 0.5) < 0.00001 and abs(second[3] - 0.6) < 0.00001;
    # Surface 1's second triangle: file corners 1, 3, 2 drawn as 1, 2, 3.
    assert [corner_at(corners.records, 6 + i)[0] for i in range(3)] == [7.0, 8.0, 9.0];
}

test "shader-only surfaces take no GPU keyframes" {
    keyframes = pack_model_keyframes(AnimatedModel(surfaces=[AnimatedSurface(name="shell")]));
    assert keyframes.texels == b"" and keyframes.frames == 0;
}

test "normals survive the octahedral packing" {
    for n in [Vec3(z=1.0), Vec3(z=-1.0), Vec3(x=1.0), Vec3(x=-0.6, y=0.0, z=-0.8), Vec3(x=0.48, y=-0.6, z=0.64)] {
        code = model_normal_code(n);
        assert code >= 0.0 and code < 16777216.0 and float(int(code)) == code;
        back = model_normal_decode(code);
        assert back.sub(n).length() < 0.002;
    }
}

test "instanced cube corners wind counter-clockwise seen from outside" {
    corners = unit_cube_corners();
    assert len(corners) == 36 * 3;
    for triangle in range(12) {
        p = [Vec3(x=corners[(triangle * 3 + k) * 3], y=corners[(triangle * 3 + k) * 3 + 1], z=corners[(triangle * 3 + k) * 3 + 2]) for k in range(3)];
        normal = p[1].sub(p[0]).cross(p[2].sub(p[0]));
        middle = p[0].add(p[1]).add(p[2]).scale(1.0 / 3.0);
        assert normal.dot(middle) > 0.0;
        for point in p {
            assert abs(point.x) == 0.5 and abs(point.y) == 0.5 and abs(point.z) == 0.5;
        }
    }
}
