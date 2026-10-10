import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush {
    Plane3,
    Side,
    Mapping,
    box_sides,
    brush_windings,
    brush_volume,
    brush_holds,
    windings_bounds,
    classic_mapping,
    cylinder_sides,
    wedge_sides
}
import from editor.geometry.csg {
    pruned_sides,
    common_sides,
    carve_sides,
    hollow_sides,
    merged_sides,
    brush_corners,
    brush_edges,
    hull_sides,
    corners_moved,
    joined_pieces
}
import from editor.geometry.mapping {
    side_like,
    mapping_slid,
    mapping_sized,
    mapping_spun,
    mapping_flat,
    mapping_fitted,
    mapping_plain,
    side_stretched,
    side_spun,
    spun_about
}

def near(a: float, b: float) -> bool {
    return abs(a - b) < 0.01;
}

def cube(low: float, high: float) -> list[Side] {
    return box_sides(Vec3(x=low, y=low, z=low), Vec3(x=high, y=high, z=high), "wall");
}

test "what two brushes share is a brush, or nothing when they only touch" {
    shared = common_sides(cube(0.0, 64.0), cube(32.0, 96.0));
    assert near(brush_volume(shared), 32.0 * 32.0 * 32.0);
    assert len(shared) == 6;
    assert len(common_sides(cube(0.0, 64.0), cube(64.0, 128.0))) == 0;
    assert len(common_sides(cube(0.0, 64.0), cube(100.0, 128.0))) == 0;
    # A brush inside another: what they share is the inner one.
    assert near(brush_volume(common_sides(cube(0.0, 64.0), cube(16.0, 32.0))), 16.0 * 16.0 * 16.0);
}

test "carving leaves convex pieces that fill what the cutter does not" {
    target = cube(0.0, 64.0);
    cutter = box_sides(Vec3(x=16.0, y=16.0, z=-8.0), Vec3(x=48.0, y=48.0, z=72.0), "trim");
    pieces = carve_sides(target, cutter);
    assert pieces is not None;
    # A square hole through a block leaves four walls.
    assert len(pieces) == 4;
    total = 0.0;
    for piece in pieces {
        total += brush_volume(piece);
        # No piece reaches into the hole.
        assert len(common_sides(piece, cutter)) == 0;
    }
    assert near(total, 64.0 * 64.0 * 64.0 - 32.0 * 32.0 * 64.0);
    # Apart, the target is left alone; swallowed, nothing is left of it.
    assert carve_sides(target, cube(100.0, 120.0)) is None;
    gone = carve_sides(cube(16.0, 32.0), target);
    assert gone is not None and len(gone) == 0;
}

test "carved faces take the target's material, or the cutter's when lined" {
    target = cube(0.0, 64.0);
    cutter = box_sides(Vec3(x=32.0, y=-8.0, z=-8.0), Vec3(x=96.0, y=72.0, z=72.0), "trim");
    plain = carve_sides(target, cutter);
    assert plain is not None and len(plain) == 1;
    assert [side.material for side in plain[0]] == ["wall"] * 6;
    lined = carve_sides(target, cutter, True);
    assert lined is not None and "trim" in [side.material for side in lined[0]];
}

test "hollowing makes walls round an empty middle" {
    walls = hollow_sides(cube(0.0, 128.0), 8.0);
    assert len(walls) == 6;
    total = 0.0;
    for wall in walls {
        total += brush_volume(wall);
        assert not brush_holds(wall, Vec3(x=64.0, y=64.0, z=64.0));
    }
    assert near(total, 128.0 * 128.0 * 128.0 - 112.0 * 112.0 * 112.0);
    # Walls that would meet in the middle are refused.
    assert len(hollow_sides(cube(0.0, 16.0), 8.0)) == 0;
    assert len(hollow_sides(cube(0.0, 16.0), 0.0)) == 0;
}

test "two halves of a wall merge and an L does not" {
    left = box_sides(Vec3(), Vec3(x=32.0, y=16.0, z=64.0), "wall");
    right = box_sides(Vec3(x=32.0), Vec3(x=96.0, y=16.0, z=64.0), "wall");
    joined = merged_sides(left, right);
    assert len(joined) == 6 and near(brush_volume(joined), 96.0 * 16.0 * 64.0);
    turned = box_sides(Vec3(x=32.0), Vec3(x=48.0, y=64.0, z=64.0), "wall");
    assert len(merged_sides(left, turned)) == 0;
    assert len(merged_sides(left, cube(200.0, 232.0))) == 0;
}

test "a brush's corners and edges are counted once" {
    assert len(brush_corners(cube(0.0, 64.0))) == 8;
    assert len(brush_edges(cube(0.0, 64.0))) == 12;
    wedge = wedge_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall");
    assert len(brush_corners(wedge)) == 6 and len(brush_edges(wedge)) == 9;
    assert len(brush_corners(cylinder_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), 8, "wall"))) == 16;
}

test "the brush around a box's corners is the box, materials kept" {
    box = box_sides(Vec3(), Vec3(x=64.0, y=32.0, z=16.0), "wall");
    box[4] = side_like(box[4], "floor");
    again = hull_sides(brush_corners(box), box);
    assert len(again) == 6 and near(brush_volume(again), 64.0 * 32.0 * 16.0);
    for side in again {
        assert side.material == ("floor" if side.plane.normal.z > 0.5 else "wall");
    }
    # Corners that lie flat enclose nothing.
    flat = [Vec3(), Vec3(x=64.0), Vec3(x=64.0, y=64.0), Vec3(y=64.0)];
    assert len(hull_sides(flat, box)) == 0;
}

test "moving a corner reshapes the brush around it" {
    box = cube(0.0, 64.0);
    pulled = corners_moved(box, [Vec3(x=64.0, y=64.0, z=64.0)], Vec3(z=32.0));
    assert len(pulled) > 6;
    assert brush_holds(pulled, Vec3(x=62.0, y=62.0, z=80.0));
    assert not brush_holds(pulled, Vec3(x=2.0, y=2.0, z=80.0));
    assert brush_volume(pulled) > 64.0 * 64.0 * 64.0;
    # A whole edge moved keeps the count of sides: the top tilts.
    tilted = corners_moved(box, [Vec3(x=64.0, y=0.0, z=64.0), Vec3(x=64.0, y=64.0, z=64.0)], Vec3(z=32.0));
    assert len(tilted) == 6 and near(brush_volume(tilted), 64.0 * 64.0 * 80.0);
    # A corner nobody has is not moved.
    assert len(corners_moved(box, [Vec3(x=7.0)], Vec3(z=8.0))) == 0;
    # Pushed into the brush, a corner is no longer one.
    sunk = corners_moved(box, [Vec3(x=64.0, y=64.0, z=64.0)], Vec3(x=-32.0, y=-32.0, z=-32.0));
    assert len(brush_corners(sunk)) == 7;
}

test "a material slides, scales and turns on its face" {
    plain = mapping_plain(Vec3(z=1.0));
    point = Vec3(x=32.0, y=16.0, z=0.0);
    slid = mapping_slid(plain, 8.0, -4.0);
    assert near(slid.texel(point)[0], plain.texel(point)[0] + 8.0);
    assert near(slid.texel(point)[1], plain.texel(point)[1] - 4.0);
    sized = mapping_sized(plain, 2.0, 0.0);
    assert near(sized.texel(point)[0], 16.0) and near(sized.s_scale, 2.0) and near(sized.t_scale, 1.0);
    turned = mapping_spun(plain, 90.0);
    assert near(turned.rotation, 90.0);
    assert near(abs(turned.s_axis.y), 1.0) and near(abs(turned.t_axis.x), 1.0);
    # A full turn is where it began.
    round_trip = mapping_spun(mapping_spun(turned, 180.0), 90.0);
    assert near(round_trip.s_axis.x, plain.s_axis.x) and near(round_trip.t_axis.y, plain.t_axis.y);
}

test "fitting covers a face with the whole texture" {
    box = box_sides(Vec3(x=16.0, y=32.0, z=0.0), Vec3(x=144.0, y=96.0, z=8.0), "wall");
    top = brush_windings(box)[4];
    fitted = mapping_fitted(box[4].mapping, top, 64, 64);
    s_values = [fitted.texel(point)[0] for point in top];
    t_values = [fitted.texel(point)[1] for point in top];
    assert near(min(s_values), 0.0) and near(max(s_values), 64.0);
    assert near(min(t_values), 0.0) and near(max(t_values), 64.0);
    twice = mapping_fitted(box[4].mapping, top, 64, 64, 2.0, 1.0);
    assert near(max([twice.texel(point)[0] for point in top]), 128.0);
}

test "a flat mapping lies in its face's own plane" {
    slope = Vec3(x=1.0, z=1.0).normalized();
    flat = mapping_flat(slope);
    assert near(flat.s_axis.dot(slope), 0.0) and near(flat.t_axis.dot(slope), 0.0);
    assert near(flat.s_axis.dot(flat.t_axis), 0.0);
    assert flat.t_axis.z < 0.0;
    for normal in [Vec3(z=1.0), Vec3(z=-1.0), Vec3(x=1.0), Vec3(y=-1.0)] {
        level = mapping_flat(normal);
        assert near(level.s_axis.length(), 1.0) and near(level.t_axis.length(), 1.0);
        assert near(level.s_axis.dot(normal), 0.0) and near(level.t_axis.dot(normal), 0.0);
    }
}

test "a mirrored brush keeps its size and its material in place" {
    box = box_sides(Vec3(x=16.0, y=0.0, z=0.0), Vec3(x=80.0, y=32.0, z=48.0), "wall");
    pivot = Vec3(x=0.0, y=0.0, z=0.0);
    flipped = [side_stretched(side, pivot, Vec3(x=-1.0, y=1.0, z=1.0)) for side in box];
    bounds = windings_bounds(brush_windings(flipped));
    assert bounds is not None and near(bounds[0].x, -80.0) and near(bounds[1].x, -16.0);
    assert near(brush_volume(flipped), 64.0 * 32.0 * 48.0);
    # A point of the top face and its mirror image see the same texel.
    before = box[4].mapping.texel(Vec3(x=40.0, y=8.0, z=48.0));
    top = [side for side in flipped if side.plane.normal.z > 0.5][0];
    after = top.mapping.texel(Vec3(x=-40.0, y=8.0, z=48.0));
    assert near(before[0], after[0]) and near(before[1], after[1]);
}

test "a stretched brush grows about its pivot and its material with it" {
    box = cube(0.0, 64.0);
    pivot = Vec3(x=32.0, y=32.0, z=0.0);
    grown = [side_stretched(side, pivot, Vec3(x=2.0, y=1.0, z=0.5)) for side in box];
    bounds = windings_bounds(brush_windings(grown));
    assert bounds is not None;
    assert near(bounds[0].x, -32.0) and near(bounds[1].x, 96.0) and near(bounds[1].z, 32.0);
    before = box[4].mapping.texel(Vec3(x=48.0, y=20.0, z=64.0));
    top = [side for side in grown if side.plane.normal.z > 0.5][0];
    after = top.mapping.texel(Vec3(x=64.0, y=20.0, z=32.0));
    assert near(before[0], after[0]) and near(before[1], after[1]);
}

test "a brush turns about any axis with its material" {
    box = box_sides(Vec3(), Vec3(x=64.0, y=32.0, z=16.0), "wall");
    pivot = Vec3();
    tipped = [side_spun(side, pivot, 0, math.pi * 0.5) for side in box];
    bounds = windings_bounds(brush_windings(tipped));
    # About x by a quarter: y goes to z, z to -y.
    assert bounds is not None;
    assert near(bounds[1].x, 64.0) and near(bounds[0].y, -16.0) and near(bounds[1].z, 32.0);
    before = box[4].mapping.texel(Vec3(x=10.0, y=20.0, z=16.0));
    carried = spun_about(Vec3(x=10.0, y=20.0, z=16.0), Vec3(x=1.0), math.pi * 0.5);
    face = [side for side in tipped if side.plane.normal.y < -0.5][0];
    after = face.mapping.texel(carried);
    assert near(before[0], after[0]) and near(before[1], after[1]);
    # Four quarter turns about z are the brush again.
    spun = box;
    for i in range(4) {
        spun = [side_spun(side, Vec3(x=8.0, y=8.0), 2, math.pi * 0.5) for side in spun];
    }
    for i in range(6) {
        assert near(spun[i].plane.dist, box[i].plane.dist) and near(spun[i].plane.normal.dot(box[i].plane.normal), 1.0);
    }
}

test "a slanted cutter does not split its target far from the hole" {
    floor = box_sides(Vec3(x=-256.0, y=-256.0, z=-16.0), Vec3(x=256.0, y=256.0, z=0.0), "floor");
    block = box_sides(Vec3(x=176.0, y=128.0, z=-8.0), Vec3(x=240.0, y=192.0, z=56.0), "wall");
    # One top corner pulled up: the top is two slanted triangles.
    slanted = corners_moved(block, [Vec3(x=240.0, y=192.0, z=56.0)], Vec3(z=16.0));
    assert len(slanted) == 7;
    pieces = carve_sides(floor, slanted);
    # Four round the hole and one under it.
    assert pieces is not None and len(pieces) == 5;
    total = 0.0;
    for piece in pieces {
        total += brush_volume(piece);
    }
    assert near(total, 512.0 * 512.0 * 16.0 - 64.0 * 64.0 * 8.0);
}

test "pieces that together are convex are joined" {
    wall = box_sides(Vec3(), Vec3(x=96.0, y=16.0, z=64.0), "wall");
    thirds = [
        box_sides(Vec3(), Vec3(x=32.0, y=16.0, z=64.0), "wall"),
        box_sides(Vec3(x=64.0), Vec3(x=96.0, y=16.0, z=64.0), "wall"),
        box_sides(Vec3(x=32.0), Vec3(x=64.0, y=16.0, z=64.0), "wall"),
        box_sides(Vec3(x=32.0, y=16.0), Vec3(x=48.0, y=64.0, z=64.0), "wall")
    ];
    joined = joined_pieces(thirds);
    # The three in a row become the wall; the one that makes a T stays.
    assert len(joined) == 2;
    volumes = sorted([brush_volume(piece) for piece in joined]);
    assert near(volumes[1], brush_volume(wall)) and near(volumes[0], 16.0 * 48.0 * 64.0);
}
