import from engine.math.vec3 { Vec3 }
import from editor.model.bones {
    point_swung,
    points_swung,
    points_carried,
    grip_with,
    grip_without,
    grip_share,
    shares_beside,
    bone_distance,
    nearest_bones,
    frames_spread,
    tint_mixed,
    BONE_TINTS
}

def about(a: float, b: float, slack: float = 0.001) -> bool {
    return abs(a - b) < slack;
}

def near(a: Vec3, b: Vec3, slack: float = 0.001) -> bool {
    return a.sub(b).length() < slack;
}

test "a bone's points go round with it, each by its share" {
    up = Vec3(z=1.0);
    assert near(point_swung(Vec3(x=4.0), Vec3(), up, 90.0), Vec3(y=4.0));
    assert near(point_swung(Vec3(x=4.0, z=7.0), Vec3(x=2.0), up, 180.0), Vec3(x=0.0, z=7.0));
    # An axis of any length is the same axis; of none, no turn.
    assert near(point_swung(Vec3(x=4.0), Vec3(), Vec3(z=5.0), 90.0), Vec3(y=4.0));
    assert near(point_swung(Vec3(x=4.0), Vec3(), Vec3(), 90.0), Vec3(x=4.0));
    points = [Vec3(x=4.0), Vec3(x=8.0), Vec3(x=12.0)];
    # The first is not carried, the second wholly, the third by half.
    made = points_swung(points, [1, 2, 9], [1.0, 0.5, 1.0], Vec3(), up, 90.0);
    assert near(made[0], Vec3(x=4.0)) and near(made[1], Vec3(y=8.0)) and near(made[2], Vec3(x=6.0, y=6.0));
    assert near(points[1], Vec3(x=8.0));
    # A point carried by two bones, half each, goes all the way when both turn alike.
    twice = points_swung(points_swung(points, [2], [0.5], Vec3(), up, 90.0), [2], [0.5], Vec3(), up, 0.0);
    assert near(twice[2], Vec3(x=6.0, y=6.0));
    moved = points_carried(points, [0, 2], [1.0, 0.25], Vec3(z=8.0));
    assert near(moved[0], Vec3(x=4.0, z=8.0)) and near(moved[1], Vec3(x=8.0)) and near(moved[2], Vec3(x=12.0, z=2.0));
    # With no weight said, a point is carried wholly.
    assert near(points_carried(points, [1], [], Vec3(z=8.0))[1], Vec3(x=8.0, z=8.0));
}

test "a bone takes points at a weight, lets them go, and shares them" {
    grip = grip_with([], [], [5, 2, 2, -1], 1.0);
    assert grip[0] == [2, 5] and grip[1] == [1.0, 1.0];
    # One of them again at half, and a new one: the points stay in order.
    grip = grip_with(grip[0], grip[1], [5, 3], 0.5);
    assert grip[0] == [2, 3, 5] and grip[1] == [1.0, 0.5, 0.5];
    assert about(grip_share(grip[0], grip[1], 3), 0.5) and about(grip_share(grip[0], grip[1], 7), 0.0);
    # At no weight a point is let go; a weight past one is one.
    assert grip_with(grip[0], grip[1], [2], 0.0)[0] == [3, 5] and grip_with([], [], [1], 4.0)[1] == [1.0];
    less = grip_without(grip[0], grip[1], [3, 9]);
    assert less[0] == [2, 5] and less[1] == [1.0, 0.5];
    # Beside a bone that takes six tenths, two others at a half each are cut to two tenths each;
    # ones that already fit are left.
    beside = shares_beside(0.6, [0.5, 0.5]);
    assert about(beside[0], 0.2) and about(beside[1], 0.2);
    assert shares_beside(0.25, [0.5, 0.25]) == [0.5, 0.25] and shares_beside(1.0, [0.5]) == [0.0];
}

test "a point is nearest the bone whose length it lies closest to" {
    assert about(bone_distance(Vec3(), Vec3(z=10.0), Vec3(x=3.0, z=5.0)), 3.0);
    # Past an end, it is how far the end is; a bone of no length is a point.
    assert about(bone_distance(Vec3(), Vec3(z=10.0), Vec3(x=3.0, z=14.0)), 5.0);
    assert about(bone_distance(Vec3(), Vec3(), Vec3(x=3.0, y=4.0)), 5.0);
    heads = [Vec3(), Vec3(z=10.0)];
    tails = [Vec3(z=10.0), Vec3(x=10.0, z=10.0)];
    near_to = nearest_bones(heads, tails, [Vec3(x=1.0, z=2.0), Vec3(x=8.0, z=11.0), Vec3(x=0.0, z=10.0)]);
    # The joint between the two belongs to the first that reaches it.
    assert near_to == [0, 1, 0] and nearest_bones([], [], [Vec3()]) == [-1];
}

test "the frames between two are spread evenly, for all the points or for some" {
    poses = [
        [Vec3(), Vec3(x=1.0)],
        [Vec3(z=99.0), Vec3(x=1.0, z=99.0)],
        [Vec3(z=99.0), Vec3(x=1.0, z=99.0)],
        [Vec3(z=99.0), Vec3(x=1.0, z=99.0)],
        [Vec3(z=8.0), Vec3(x=9.0)]
    ];
    spread = frames_spread(poses, 0, 4);
    assert near(spread[1][0], Vec3(z=2.0)) and near(spread[2][0], Vec3(z=4.0)) and near(spread[3][1], Vec3(x=7.0));
    assert near(spread[0][0], Vec3()) and near(spread[4][1], Vec3(x=9.0)) and near(poses[1][0], Vec3(z=99.0));
    # Only the second point: the first stays where each frame had it.
    some = frames_spread(poses, 0, 4, [1]);
    assert near(some[2][0], Vec3(z=99.0)) and near(some[2][1], Vec3(x=5.0));
    # Between part of them.
    part = frames_spread(poses, 2, 4);
    assert near(part[3][0], Vec3(z=53.5)) and near(part[1][0], Vec3(z=99.0));
    # Frames side by side have none between; a frame out of range changes nothing.
    assert frames_spread(poses, 3, 4) == poses and frames_spread(poses, 0, 9) == poses and frames_spread(poses, -1, 3) == poses;
}

test "a point shows its bones' colours mixed by its weights" {
    assert tint_mixed([0xff0000], [1.0], 0x808080) == 0xff0000;
    assert tint_mixed([0xff0000, 0x0000ff], [0.5, 0.5], 0x808080) == 0x800080;
    # Half carried: half the bone's colour, half the plain one.
    assert tint_mixed([0xff0000], [0.5], 0x000000) == 0x800000;
    assert tint_mixed([], [], 0x123456) == 0x123456;
    # More than one whole between them is one whole.
    assert tint_mixed([0xff0000, 0x00ff00], [1.0, 1.0], 0xffffff) == 0x808000;
    assert len(BONE_TINTS) >= 6 and len(set(BONE_TINTS)) == len(BONE_TINTS);
}
