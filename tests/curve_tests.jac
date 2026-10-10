"""Q3 patch meshes for drawing: subdivision by error, stitching, the errors
rows and columns are dropped by, and vertex normals."""
import math;
import from engine.formats.bsp { Face }
import from engine.formats.q3.bsp { tessellate }
import from engine.formats.q3.curve {
    Vertex,
    CurveGrid,
    subdivide_patch,
    stitch_patches,
    stitch_all_patches,
    fix_all_shared_lod_errors,
    make_mesh_normals,
    curve_error,
    lerp_vertex,
    CURVE_SUBDIVISIONS
}
import from engine.render.world_mesh {
    lod_error_for_volume,
    grid_lines,
    grid_steps,
    grid_level,
    grid_index_bytes,
    CURVE_LOD_ERROR
}
import struct;
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
    return CurveGrid(
        width=width, height=len(rows), rows=rows, width_errors=[0.0] * width, height_errors=[0.0] * len(rows)
    );
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

test "a grid keeps the error each column was added for and thins by it" {
    pipe = subdivide_patch(3, 3, quarter_pipe(64.0));
    errors = pipe.width_errors;
    assert len(errors) == 9 and pipe.height_errors == [0.0, 0.0];
    # R_SubdividePatchToGrid's table: the ends and the middle of the bend
    # always draw; the quarter points were added for the 5.06 units a half
    # bend's control points lay off their chord, the eighth points for the
    # 1.13 (outer) and 1.37 (inner) a quarter's did. An error is kept as one
    # over its length.
    assert errors[0] == 0.0 and errors[4] == 0.0 and errors[8] == 0.0;
    assert abs(1.0 / errors[2] - 5.06) < 0.01 and abs(1.0 / errors[6] - 5.06) < 0.01;
    assert abs(1.0 / errors[1] - 1.131) < 0.01 and abs(1.0 / errors[7] - 1.131) < 0.01;
    assert abs(1.0 / errors[3] - 1.372) < 0.01 and abs(1.0 / errors[5] - 1.372) < 0.01;
    # RB_SurfaceGrid: a column is drawn while its error is within what the
    # view allows.
    assert grid_lines(errors, 0.0) == [0, 4, 8];
    assert grid_lines(errors, 1.0 / 5.0) == [0, 2, 4, 6, 8];
    assert grid_lines(errors, 1.0 / 1.3) == [0, 2, 3, 4, 5, 6, 8];
    assert grid_lines(errors, 1.0 / 1.1) == [0, 1, 2, 3, 4, 5, 6, 7, 8];
    assert grid_lines(pipe.height_errors, 100.0) == [0, 1];
    # The errors at which what is drawn changes, rising (the two sides of
    # the bend may differ in their last bits), and the level a view is at.
    steps = grid_steps(pipe.width_errors, pipe.height_errors);
    assert 3 <= len(steps) and len(steps) <= 6 and steps == sorted(steps);
    assert abs(1.0 / steps[0] - 5.06) < 0.01 and abs(1.0 / steps[-1] - 1.131) < 0.01;
    assert grid_level(steps, 0.0) == 0 and grid_level(steps, 1000.0) == len(steps);
    assert grid_level(steps, steps[0]) == 1 and grid_level(steps, steps[0] * 0.999) == 0;
    assert grid_level(steps, 1.0 / 5.0) < grid_level(steps, 1.0 / 1.3) and grid_level(steps, 1.0 / 1.3) < grid_level(steps, 1.0 / 1.1);
    # A flat patch has nothing to drop.
    flat = subdivide_patch(3, 3, [Vertex(pos=Vec3(x=float(i % 3) * 32.0, y=float(i // 3) * 32.0), colors=[0.0, 0.0, 0.0, 0.0]) for i in range(9)]);
    assert grid_steps(flat.width_errors, flat.height_errors) == [];
    # The coarsest pipe is two cells, wound as the whole grid is.
    coarse = struct.unpack("<12H", grid_index_bytes(9, [0, 4, 8], [0, 1], 10));
    assert coarse == (10, 14, 19, 14, 23, 19, 14, 18, 23, 18, 27, 23);
    drawn = Face();
    tessellate(drawn, quarter_pipe(64.0), 3, 3);
    whole = grid_index_bytes(9, list(range(9)), [0, 1], 0);
    assert struct.unpack("<48H", whole) == tuple(drawn.indices);
    assert drawn.grid_width == 9 and drawn.grid_height == 2 and len(drawn.width_errors) == 9;
    assert abs(drawn.width_errors[2] - errors[2]) < 0.000001;
}

test "LodErrorForVolume allows less error the deeper a group lies in the view" {
    assert CURVE_LOD_ERROR == 250.0;
    eye = Vec3(x=10.0);
    ahead = Vec3(x=1.0);
    # 1000 units ahead, 100 across: its nearest point is 900 deep.
    assert abs(lod_error_for_volume(Vec3(x=1010.0), 100.0, eye, ahead) - 250.0 / 900.0) < 0.000001;
    # Depth is along the view's axis, either way; off to the side counts for nothing.
    assert abs(lod_error_for_volume(Vec3(x=-990.0, y=5000.0), 100.0, eye, ahead) - 250.0 / 900.0) < 0.000001;
    # Inside the group, or within a unit of it, the whole allowance.
    assert lod_error_for_volume(Vec3(x=40.0), 100.0, eye, ahead) == 250.0;
    # r_lodCurveError scales it, and below zero allows nothing.
    assert abs(lod_error_for_volume(Vec3(x=1010.0), 100.0, eye, ahead, 90.0) - 0.1) < 0.000001;
    assert lod_error_for_volume(Vec3(x=1010.0), 100.0, eye, ahead, -1.0) == 0.0;
    # A column is drawn out to 250 times the error it was added for: the
    # quarter pipe's eighth points (1.13 and 1.37 units) to 283 and 343 units,
    # its quarter points (5.06) to 1265.
    pipe = subdivide_patch(3, 3, quarter_pipe(64.0));
    near = lod_error_for_volume(Vec3(x=260.0), 0.0, eye, ahead);
    nearish = lod_error_for_volume(Vec3(x=320.0), 0.0, eye, ahead);
    middle = lod_error_for_volume(Vec3(x=810.0), 0.0, eye, ahead);
    far = lod_error_for_volume(Vec3(x=1510.0), 0.0, eye, ahead);
    assert len(grid_lines(pipe.width_errors, near)) == 9;
    assert len(grid_lines(pipe.width_errors, nearish)) == 7;
    assert len(grid_lines(pipe.width_errors, middle)) == 5;
    assert len(grid_lines(pipe.width_errors, far)) == 3;
}

test "MakeMeshNormals gives each vertex the normal of the grid round it" {
    flat = subdivide_patch(3, 3, [Vertex(pos=Vec3(x=float(i % 3) * 32.0, y=float(i // 3) * 32.0), colors=[0.0, 0.0, 0.0, 0.0]) for i in range(9)]);
    for row in flat.rows {
        for v in row {
            assert v.normal.sub(Vec3(z=1.0)).length() < 0.0001;
        }
    }
    # Round the quarter pipe the normals turn with the bend, level throughout.
    pipe = subdivide_patch(3, 3, quarter_pipe(64.0));
    for row in pipe.rows {
        for v in row {
            radial = Vec3(x=v.pos.x, y=v.pos.y).normalized();
            assert abs(v.normal.z) < 0.0001 and abs(abs(v.normal.dot(radial)) - 1.0) < 0.06;
        }
    }
    assert abs(pipe.rows[0][0].normal.dot(pipe.rows[0][8].normal)) < 0.2;
    drawn = Face();
    tessellate(drawn, quarter_pipe(64.0), 3, 3);
    assert len(drawn.normals) == len(drawn.vertices) and drawn.normals[4].sub(pipe.rows[0][4].normal).length() < 0.0001;
    # A tube whose first and last columns coincide: the seam's normal takes
    # the faces on both sides of it, as every other corner's does.
    square = [Vec3(x=16.0, y=16.0), Vec3(x=-16.0, y=16.0), Vec3(x=-16.0, y=-16.0), Vec3(x=16.0, y=-16.0), Vec3(x=16.0, y=16.0)];
    tube = plain_grid(square + [p.add(Vec3(z=32.0)) for p in square], 5);
    make_mesh_normals(tube);
    seam = tube.rows[0][0].normal;
    assert seam.sub(tube.rows[0][4].normal).length() < 0.0001;
    assert abs(abs(seam.x) - abs(seam.y)) < 0.0001 and abs(seam.z) < 0.0001 and abs(seam.x) > 0.5;
    corner = tube.rows[0][2].normal;
    assert abs(seam.dot(corner) + 1.0) < 0.0001;
    # The same strip open at the seam: its end vertex sees one face only.
    strip = plain_grid(square[:4] + [p.add(Vec3(z=32.0)) for p in square[:4]], 4);
    make_mesh_normals(strip);
    assert abs(strip.rows[0][0].normal.x) < 0.0001 or abs(strip.rows[0][0].normal.y) < 0.0001;
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

test "a stitched vertex drops with its neighbour's, and shared vertices share an error" {
    pair = neighbours();
    pair[0].width_errors = [0.0, 0.25, 0.0];
    assert stitch_all_patches(pair) == 1;
    # R_GridInsertColumn: the new column carries the error of the vertex it
    # was added to meet, and the grid's normals are made again.
    assert pair[1].width_errors == [0.0, 0.25, 0.0] and pair[1].height_errors == [0.0, 0.0];
    assert not pair[1].reshaped and pair[1].rows[1][1].normal.length() > 0.99;
    # R_FixSharedVertexLodError: a later grid of the group takes the first
    # one's error for an inner border vertex they share.
    first = plain_grid([Vec3(), Vec3(x=32.0), Vec3(x=64.0), Vec3(y=64.0), Vec3(x=32.0, y=64.0), Vec3(x=64.0, y=64.0)], 3);
    second = plain_grid([Vec3(y=-64.0), Vec3(x=32.0, y=-64.0), Vec3(x=64.0, y=-64.0), Vec3(), Vec3(x=32.0), Vec3(x=64.0)], 3);
    first.width_errors = [0.0, 0.5, 0.0];
    second.width_errors = [0.0, 0.125, 0.0];
    fix_all_shared_lod_errors([first, second]);
    assert second.width_errors == [0.0, 0.5, 0.0] and first.lod_fixed == 2 and second.lod_fixed == 2;
    # Another LOD group keeps its own.
    other = plain_grid([Vec3(y=-64.0), Vec3(x=32.0, y=-64.0), Vec3(x=64.0, y=-64.0), Vec3(), Vec3(x=32.0), Vec3(x=64.0)], 3);
    other.width_errors = [0.0, 0.125, 0.0];
    other.lod_radius = 7.0;
    lone = plain_grid([Vec3(), Vec3(x=32.0), Vec3(x=64.0), Vec3(y=64.0), Vec3(x=32.0, y=64.0), Vec3(x=64.0, y=64.0)], 3);
    lone.width_errors = [0.0, 0.5, 0.0];
    fix_all_shared_lod_errors([lone, other]);
    assert other.width_errors == [0.0, 0.125, 0.0];
}
