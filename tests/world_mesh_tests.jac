import struct;
import math;
import from engine.render.world_mesh {
    IndexLists,
    IndexSpan,
    assign_chunks,
    face_triangles,
    face_index_bytes,
    gather_indices,
    pack_world_face,
    sprite_quad,
    file_winding,
    pack_light_blocks,
    fit_light_atlas,
    WORLD_FOG_LIMIT,
    WORLD_FOG_GLSL,
    LIGHT_ATLAS_SIZES,
    SPRITE_STAMP_CORNERS,
    batch_key,
    WORLD_VERTEX_STRIDE,
    PASS_LIT,
    PASS_LIQUID,
    PASS_BASE,
    PASS_FOG
}
import from engine.render.quake { tcmod_steps, apply_tcmods, stage_affine, placed_matrix, same_placement, moved_face }
import from engine.formats.bsp { Face, TexInfo }
import from engine.formats.animated { ModelStage, TexMod, ShaderWave }
import from engine.math.vec3 { Vec3 }
import from engine.math.orientation { quake_basis }

"""Whether `spans` are exactly the (chunk, first, count) runs `expected`."""
def spans_are(spans: list[IndexSpan], expected: list[list[int]]) -> bool {
    if len(spans) != len(expected) {
        return False;
    }
    for i in range(len(spans)) {
        if spans[i].chunk != expected[i][0] or spans[i].first != expected[i][1] or spans[i].count != expected[i][2] {
            return False;
        }
    }
    return True;
}

def square(x: float) -> Face {
    return Face(vertices=[Vec3(x=x), Vec3(x=x, y=16.0), Vec3(x=x, y=16.0, z=16.0), Vec3(x=x, z=16.0)], uv=[0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]);
}

test "world faces fill 16-bit chunks in batch order without splitting a face" {
    counts = [4, 3, 5, 4, 6];
    placed = assign_chunks(counts, [4, 0, 2, 3], limit=10);
    chunks = placed[0];
    bases = placed[1];
    # Face 1 is not drawn; the others fill chunks of at most 10 vertices.
    assert chunks == [0, -1, 1, 1, 0];
    assert bases[4] == 0 and bases[0] == 6 and bases[2] == 0 and bases[3] == 5;
    failed = False;
    try {
        assign_chunks([11], [0], limit=10);
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "faces triangulate as fans unless they carry their own indices" {
    fan = square(0.0);
    assert face_triangles(fan) == [0, 2, 1, 0, 3, 2];
    mesh = Face(vertices=fan.vertices, indices=[0, 1, 2]);
    assert face_triangles(mesh) == [0, 1, 2];
    run = face_index_bytes(fan, 100);
    values = struct.unpack("<HHHHHH", run);
    assert values[0] == 100 and values[1] == 102 and values[2] == 101;
    assert values[3] == 100 and values[4] == 103 and values[5] == 102;
}

test "visible faces become one index run per chunk and batch" {
    runs = [face_index_bytes(square(0.0), 0), face_index_bytes(square(1.0), 4), face_index_bytes(square(2.0), 0), face_index_bytes(square(3.0), 8)];
    chunks = [0, 0, 1, 0];
    # Face 3 draws in batch 0 and is fogged by batch 2; faces 0 and 1 share batch 1.
    batches = [[1], [1], [0], [0, 2]];
    lists = IndexLists(chunks=[bytearray(), bytearray()], spans={});
    added = gather_indices(lists, [1, 3, 0, 2], chunks, batches, runs);
    assert lists.faces == 4;
    # Chunk 0 holds batch 0 (face 3), batch 1 (faces 1 then 0), batch 2 (face 3).
    assert spans_are(lists.spans[0], [[0, 0, 6], [1, 0, 6]]);
    assert spans_are(lists.spans[1], [[0, 6, 12]]);
    assert spans_are(lists.spans[2], [[0, 18, 6]]);
    assert len(lists.chunks[0]) == 24 * 2 and len(lists.chunks[1]) == 6 * 2;
    first = struct.unpack_from("<H", bytes(lists.chunks[0]), 6 * 2)[0];
    assert first == 4;
    assert sorted(added.keys()) == [0, 1, 2];
    # A second gather (brush groups) appends after the first.
    more = gather_indices(lists, [0], chunks, batches, runs);
    assert spans_are(more[1], [[0, 24, 6]]);
    # Batch keys sort by pass, then texture, then liquid kind.
    assert batch_key(PASS_LIT, 9, 0) < batch_key(PASS_LIQUID, 0, 0);
    assert batch_key(PASS_LIQUID, 0, 0) < batch_key(PASS_LIQUID, 0, 1);
    assert batch_key(PASS_BASE, 70000 % 65536, 0) < batch_key(PASS_FOG, 0, 0);
}

test "world vertices pack position, coordinates, light, styles and sprite data" {
    face = square(8.0);
    face.light_offset = 0;
    face.light_uv = [0.0, 0.0, 2.0, 0.0, 2.0, 2.0, 0.0, 2.0];
    face.styles = [0, 5];
    face.normal = Vec3(x=1.0);
    face.fog = 3;
    out = bytearray(4 * WORLD_VERTEX_STRIDE);
    pack_world_face(out, 0, face, 10, 20, 64, 0.25, 1, face.fog, False, alpha=84);
    v = struct.unpack_from("<fffffffBBBBfffBBBBBBBBffffffff", bytes(out), 2 * WORLD_VERTEX_STRIDE);
    assert v[0] == 8.0 and v[1] == 16.0 and v[2] == 16.0;
    assert v[3] == 1.0 and v[4] == 1.0;
    assert abs(v[5] - 12.5 / 64.0) < 0.00001 and abs(v[6] - 22.5 / 64.0) < 0.00001;
    # Uncoloured faces are white at the given opacity.
    assert v[7] == 255 and v[10] == 84;
    assert v[11] == 1.0 and v[14] == 1 and v[16] == 4;
    assert v[18] == 0 and v[19] == 5 and v[20] == 255 and v[21] == 255;
    assert v[22] == 0.25;
    # A face without texture axes (Q3) leaves them out.
    assert v[23] == 0.0 and v[26] == 0.0 and v[29] == 0.0 and v[15] == 0 and v[17] == 0;
    # A Q1/Q2 face also carries its texture axes in lightmap samples, where
    # its block starts in the atlas and its last sample column and row, for
    # R_AddDynamicLights per sample.
    face.texinfo = TexInfo(s=Vec3(y=1.0), t=Vec3(z=-2.0), soff=0.0, toff=0.0, texture=0, flags=0);
    face.light_width = 3;
    face.light_height = 2;
    pack_world_face(out, 0, face, 10, 20, 64, 0.25, 1, face.fog, False, alpha=84);
    q = struct.unpack_from("<fffffffBBBBfffBBBBBBBBffffffff", bytes(out), 2 * WORLD_VERTEX_STRIDE);
    assert q[22] == 0.25 and q[23] == 0.0 and q[24] == 1.0 / 16.0 and q[25] == 0.0;
    assert q[26] == 0.0 and q[27] == 0.0 and q[28] == -2.0 / 16.0;
    assert q[29] == float(10 * 4096 + 20);
    assert q[15] == 2 and q[17] == 1 and q[14] == 1 and q[16] == 4;
    # Q3 quads also carry their centre, radius and short-edge midpoints. The
    # indices are q3map's strip (3 0 2, 2 0 1), stored reversed.
    wide = Face(vertices=[Vec3(), Vec3(y=64.0), Vec3(y=64.0, z=8.0), Vec3(z=8.0)], uv=[0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0], colors=[10, 20, 30, 40, 10, 20, 30, 40, 10, 20, 30, 40, 10, 20, 30, 40], indices=[3, 2, 0, 2, 1, 0]);
    sprite = bytearray(4 * WORLD_VERTEX_STRIDE);
    pack_world_face(sprite, 0, wide, 0, 0, 64, 0.0, 0, -1, True, sprites=True);
    w = struct.unpack_from("<fffffffBBBBfffBBBBBBBBffffffff", bytes(sprite), WORLD_VERTEX_STRIDE);
    # Overbright-shifted colour, raw alpha.
    assert w[7] == 40 and w[8] == 80 and w[9] == 120 and w[10] == 40;
    assert w[14] == 32 and w[15] == 1 and w[16] == 0;
    assert w[22] == 0.0 and w[23] == 32.0 and w[24] == 4.0;
    # Vertex 1 ends the short edge 1-2, midpoint (0, 64, 4), half length 4.
    assert w[26] == 0.0 and w[27] == 64.0 and w[28] == 4.0 and w[29] == 4.0;
    # Its edge is the second shortest and it goes forward along the minor axis.
    assert w[17] == 4 + 1 * 2 + 0;
}

"""Autosprite2Deform's re-projection of a quad for a view along `forward`,
as world_mesh.jac SHADER_DEFORM_GLSL does it from sprite_quad's codes."""
def pivoted(points: list[Vec3], order: list[int], forward: Vec3) -> list[Vec3] {
    shape = sprite_quad(points, order);
    middle = points[0].add(points[1]).add(points[2]).add(points[3]).scale(0.25);
    moved: list[Vec3] = [];
    for i in range(4) {
        partner = points[shape.partners[i]];
        end = points[i].add(partner).scale(0.5);
        other = middle.scale(2.0).sub(end);
        major = other.sub(end) if shape.codes[i] < 2 else end.sub(other);
        minor = major.cross(forward).normalized();
        half = points[i].sub(partner).length() * 0.5;
        moved.append(end.add(minor.scale(half if shape.codes[i] % 2 == 0 else -half)));
    }
    return moved;
}

test "autosprite2 pivots a quad about its long axis to face the viewer" {
    # A flame 64 tall and 8 wide in the x = 0 plane, q3map's indices.
    points = [Vec3(), Vec3(z=64.0), Vec3(y=8.0, z=64.0), Vec3(y=8.0)];
    order = [3, 0, 2, 2, 0, 1];
    shape = sprite_quad(points, order);
    # The short edges are 0-3 and 1-2; the long ones keep their vertices.
    assert shape.partners == [3, 2, 1, 0];
    assert sorted(shape.codes) == [0, 1, 2, 3] and shape.codes[0] // 2 == shape.codes[3] // 2;
    for forward in [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(x=0.6, y=-0.8)] {
        moved = pivoted(points, order, forward);
        # The long axis stays where it was and the ends stay 8 wide.
        assert moved[0].add(moved[3]).scale(0.5).sub(Vec3(y=4.0)).length() < 0.0001;
        assert moved[1].add(moved[2]).scale(0.5).sub(Vec3(y=4.0, z=64.0)).length() < 0.0001;
        assert abs(moved[0].sub(moved[3]).length() - 8.0) < 0.0001;
        # The quad lies square to the view and is not twisted: both ends
        # run the same way across it.
        assert abs(moved[0].sub(moved[3]).dot(forward)) < 0.0001;
        assert moved[0].sub(moved[3]).dot(moved[1].sub(moved[2])) > 63.0;
        # Its first triangle (file winding 3 0 2) turns clockwise for the
        # viewer, the side Q3 draws.
        normal = moved[0].sub(moved[3]).cross(moved[2].sub(moved[3]));
        assert normal.dot(forward) > 0.0;
    }
    # A fan's triangles (0 1 2, 0 2 3) list edge 1-2 in order: that end turns
    # the other way, as the original's index test has it.
    fanned = sprite_quad(points, [0, 1, 2, 0, 2, 3]);
    assert fanned.codes[1] % 2 == 1 and fanned.codes[0] % 2 == 0;
    assert file_winding([3, 2, 0, 2, 1, 0]) == order;
    assert face_index_bytes(Face(vertices=points), 10, SPRITE_STAMP_CORNERS) == struct.pack("<HHHHHH", 10, 13, 11, 13, 12, 11);
}

test "tcMod steps reproduce the CPU tcMods, turb included" {
    stage = ModelStage(mods=[
        TexMod(kind="scale", a=2.0, b=0.5),
        TexMod(kind="turb", wave=ShaderWave(amplitude=0.1, phase=0.2, frequency=0.5)),
        TexMod(kind="scroll", a=0.3, b=-0.1),
        TexMod(kind="rotate", a=30.0)
    ]);
    seconds = 3.7;
    point = Vec3(x=40.0, y=-12.0, z=96.0);
    steps = tcmod_steps(stage, seconds);
    assert len(steps) == 2 and steps[0][6] == 1.0 and steps[1][6] == 0.0;
    s = 0.3;
    t = 0.8;
    for step in steps {
        before = s;
        s = step[0] * before + step[1] * t + step[2];
        t = step[3] * before + step[4] * t + step[5];
        if step[6] > 0.5 {
            s += math.sin(((point.x + point.z) / 128.0 * 0.125 + step[8]) * 2.0 * math.pi) * step[7];
            t += math.sin((point.y / 128.0 * 0.125 + step[8]) * 2.0 * math.pi) * step[7];
        }
    }
    expected = apply_tcmods(stage, 0.3, 0.8, point, seconds);
    assert abs(s - expected[0]) < 0.00001 and abs(t - expected[1]) < 0.00001;
    # Without turb there is one step, the folded affine map.
    plain = ModelStage(mods=[TexMod(kind="scroll", a=1.0, b=2.0)]);
    assert tcmod_steps(plain, 2.0)[0][:6] == stage_affine(plain, 2.0);
}

test "brush placements become model matrices about the pivot" {
    face = square(0.0);
    assert not moved_face(face);
    face.turn = quake_basis(Vec3(y=90.0));
    face.pivot = Vec3(x=10.0, y=5.0);
    face.motion = Vec3(z=32.0);
    assert moved_face(face);
    m = placed_matrix(face.pivot, face.motion, face.turn);
    v = Vec3(x=20.0, y=5.0, z=3.0);
    placed = face.pivot.add(face.turn.apply(v.sub(face.pivot))).add(face.motion);
    x = float(m.m0) * v.x + float(m.m4) * v.y + float(m.m8) * v.z + float(m.m12);
    y = float(m.m1) * v.x + float(m.m5) * v.y + float(m.m9) * v.z + float(m.m13);
    z = float(m.m2) * v.x + float(m.m6) * v.y + float(m.m10) * v.z + float(m.m14);
    assert abs(x - placed.x) < 0.001 and abs(y - placed.y) < 0.001 and abs(z - placed.z) < 0.001;
    other = square(1.0);
    other.turn = face.turn;
    other.pivot = face.pivot;
    other.motion = Vec3(z=32.0);
    assert same_placement(other, face);
    other.frame = 1;
    assert not same_placement(other, face);
}

test "the lightmap atlas is the smallest size that holds the map's lightmaps" {
    # Three 128-texel Q3 pages (130 with their borders) need 512.
    pages = fit_light_atlas([128, 128, 128], [128, 128, 128], [1, 1, 1]);
    assert pages.fits and pages.size == 512 and pages.unit == 1;
    assert pages.xs == [1, 131, 261] and pages.ys == [1, 1, 1];
    # A fourth starts the next shelf, two texels under the first.
    four = pack_light_blocks([128] * 4, [128] * 4, [1] * 4, 512);
    assert four.xs[3] == 1 and four.ys[3] == 131;
    # One page fits the smallest atlas; 226 of them (15 x 15 fit 2048) need 4096.
    assert fit_light_atlas([128], [128], [1]).size == 256;
    assert fit_light_atlas([128] * 225, [128] * 225, [1] * 225).size == 2048;
    assert fit_light_atlas([128] * 226, [128] * 226, [1] * 226).size == 4096;
    # Q1/Q2 faces lay their light style layers side by side.
    styled = pack_light_blocks([16, 16], [8, 8], [4, 1], 256);
    assert styled.xs == [1, 73] and styled.ys == [1, 1];
    # Past 4096 a block's corner is aligned so 4096 steps span the atlas.
    big = pack_light_blocks([128] * 3, [128] * 3, [1] * 3, 8192);
    assert big.unit == 2 and big.xs == [2, 132, 262] and big.ys == [2, 2, 2];
    assert not pack_light_blocks([300], [8], [1], 256).fits;
    assert not pack_light_blocks([8], [300], [1], 256).fits;
    assert not fit_light_atlas([20000], [8], [1]).fits and LIGHT_ATLAS_SIZES[-1] == 16384;
}

test "a face's lightmap block corner is packed in the atlas's units" {
    face = square(8.0);
    face.light_offset = 0;
    face.light_uv = [0.0, 0.0, 2.0, 0.0, 2.0, 2.0, 0.0, 2.0];
    face.styles = [0];
    face.texinfo = TexInfo(s=Vec3(y=1.0), t=Vec3(z=-2.0), soff=0.0, toff=0.0, texture=0, flags=0);
    face.light_width = 3;
    face.light_height = 2;
    out = bytearray(4 * WORLD_VERTEX_STRIDE);
    pack_world_face(out, 0, face, 5000, 6002, 8192, 0.25, 1, -1, False, unit=2);
    q = struct.unpack_from("<fffffffBBBBfffBBBBBBBBffffffff", bytes(out), 0);
    assert q[29] == float(2500 * 4096 + 3001);
}

test "the world shaders hold as many fog volumes as the original numbers" {
    assert WORLD_FOG_LIMIT == 31;
    assert "fogPlane[31]" in WORLD_FOG_GLSL and "fogColor[31]" in WORLD_FOG_GLSL;
}
