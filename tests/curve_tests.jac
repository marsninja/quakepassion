"""Q3 patch meshes for drawing: subdivision by error and stitching."""
import math;
import from engine.formats.bsp { Face }
import from engine.formats.q3.bsp { tessellate }
import from engine.formats.q3.curve {
    Vertex,
    CurveGrid,
    subdivide_patch,
    stitch_patches,
    stitch_all_patches,
    curve_error,
    lerp_vertex,
    CURVE_SUBDIVISIONS
}
import from engine.math.vec3 { Vec3 }

"""A 3 x 3 patch bent a quarter turn about z, `radius` out, 64 tall."""
def quarter_pipe(radius: float) -> list[Vertex] {
    controls: list[Vertex] = [];
    for row in range(3) {
        for corner in [Vec3(x=radius), Vec3(x=radius, y=radius), Vec3(y=radius)] {
            controls.append(
                Vertex(pos=corner.add(Vec3(z=float(row) * 32.0)), s=float(len(controls) % 3) / 2.0, t=float(row) / 2.0, colors=[200.0, 100.0, 50.0, 255.0])
            );
        }
    }
    return controls;
}

test "a flat patch is two triangles and a curved one is split until it is within r_subdivisions" {
    assert CURVE_SUBDIVISIONS == 4.0;
    flat = [Vertex(pos=Vec3(x=float(i % 3) * 32.0, y=float(i // 3) * 32.0), colors=[0.0, 0.0, 0.0, 0.0]) for i in range(9)];
    grid = subdivide_patch(3, 3, flat);
    # Every inner row and column runs straight: only the corners are left.
    assert grid.width == 2 and grid.height == 2;
    face = Face();
    tessellate(face, flat, 3, 3);
    assert len(face.vertices) == 4 and len(face.indices) == 6;
    assert face.patch_width == 3 and len(face.patch_points) == 9;
    # The quarter pipe's midpoint is 22.6 units off its chord, and each half
    # 5 off its own: two rounds of splitting, nine columns. Its straight rows
    # collapse to the two ends.
    assert abs(curve_error(Vec3(x=64.0), Vec3(x=64.0, y=64.0), Vec3(y=64.0)) - 32.0 / math.sqrt(2.0)) < 0.001;
    pipe = subdivide_patch(3, 3, quarter_pipe(64.0));
    assert pipe.width == 9 and pipe.height == 2;
    assert pipe.rows[0][0].pos.sub(Vec3(x=64.0)).length() < 0.001;
    assert pipe.rows[1][8].pos.sub(Vec3(y=64.0, z=64.0)).length() < 0.001;
    # Texture coordinates run with the vertices.
    assert pipe.rows[0][0].s == 0.0 and pipe.rows[0][8].s == 1.0 and abs(pipe.rows[0][4].s - 0.5) < 0.0001;
    assert pipe.rows[0][3].colors == [200.0, 100.0, 50.0, 255.0];
    # Every piece now lies within r_subdivisions of the curve, and the
    # vertices turn steadily round the bend.
    for i in range(8) {
        a = pipe.rows[0][i].pos;
        b = pipe.rows[0][i + 1].pos;
        assert math.atan2(b.y, b.x) > math.atan2(a.y, a.x);
        assert a.sub(b).length() < 20.0;
    }
    # A gentler bend, or a looser r_subdivisions, needs fewer columns.
    assert subdivide_patch(3, 3, quarter_pipe(8.0)).width == 3;
    assert subdivide_patch(3, 3, quarter_pipe(64.0), 8.0).width == 5;
    assert subdivide_patch(3, 3, quarter_pipe(64.0), 40.0).width == 3;
    drawn = Face();
    tessellate(drawn, quarter_pipe(64.0), 3, 3);
    assert len(drawn.vertices) == 18 and len(drawn.indices) == 8 * 6;
    # Wound as before: the first triangle's side faces out of the bend.
    a = drawn.vertices[drawn.indices[0]];
    b = drawn.vertices[drawn.indices[1]];
    c = drawn.vertices[drawn.indices[2]];
    assert b.sub(a).cross(c.sub(a)).dot(Vec3(x=1.0, y=1.0)) > 0.0;
}

"""A grid of plain vertices at `points`, `width` across."""
def plain_grid(points: list[Vec3], width: int) -> CurveGrid {
    rows: list[list[Vertex]] = [];
    for start in range(0, len(points), width) {
        rows.append([Vertex(pos=p, colors=[0.0, 0.0, 0.0, 0.0]) for p in points[start:start + width]]);
    }
    return CurveGrid(width=width, height=len(rows), rows=rows);
}

test "a patch gets its finer neighbour's vertex on the edge they share" {
    # `fine` has a vertex in the middle of its first row, bowed 3 units out;
    # `coarse` runs straight between the same two ends along its last row.
    fine = plain_grid([Vec3(), Vec3(x=32.0, z=3.0), Vec3(x=64.0), Vec3(y=64.0), Vec3(x=32.0, y=64.0), Vec3(x=64.0, y=64.0)], 3);
    coarse = plain_grid([Vec3(y=-64.0), Vec3(x=64.0, y=-64.0), Vec3(), Vec3(x=64.0)], 2);
    assert stitch_patches(fine, coarse);
    # R_GridInsertColumn: a column between the two, the shared row's vertex
    # where the neighbour's is and the other row's half way.
    assert coarse.width == 3 and coarse.height == 2;
    assert coarse.rows[1][1].pos.sub(Vec3(x=32.0, z=3.0)).length() < 0.0001;
    assert coarse.rows[0][1].pos.sub(Vec3(x=32.0, y=-64.0)).length() < 0.0001;
    # Now the edges match: nothing more to stitch, either way.
    assert not stitch_patches(fine, coarse) and not stitch_patches(coarse, fine);
    # A neighbour along a column gets a row instead.
    tall = plain_grid([Vec3(z=64.0), Vec3(z=32.0, y=2.0), Vec3()], 1);
    pillar = plain_grid([Vec3(z=64.0), Vec3(x=9.0, z=64.0), Vec3(), Vec3(x=9.0)], 2);
    assert stitch_patches(tall, pillar);
    assert pillar.height == 3 and pillar.width == 2;
    assert pillar.rows[1][0].pos.sub(Vec3(z=32.0, y=2.0)).length() < 0.0001;
    assert pillar.rows[1][1].pos.sub(Vec3(x=9.0, z=32.0)).length() < 0.0001;
}

"""A finer and a coarser grid sharing an edge."""
def neighbours() -> list[CurveGrid] {
    fine = plain_grid([Vec3(), Vec3(x=32.0, z=3.0), Vec3(x=64.0), Vec3(y=64.0), Vec3(x=32.0, y=64.0), Vec3(x=64.0, y=64.0)], 3);
    coarse = plain_grid([Vec3(y=-64.0), Vec3(x=64.0, y=-64.0), Vec3(), Vec3(x=64.0)], 2);
    return [fine, coarse];
}

test "only patches of one LOD group are stitched together" {
    together = neighbours();
    assert stitch_all_patches(together) == 1 and together[1].width == 3;
    assert together[0].stitched and together[1].stitched;
    apart = neighbours();
    apart[1].lod_radius = 96.0;
    assert stitch_all_patches(apart) == 0 and apart[1].width == 2;
}
