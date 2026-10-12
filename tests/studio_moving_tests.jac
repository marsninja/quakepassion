import from editor.assets.moving { warps_name, frames_rate, frame_now, warped }

test "Quake's liquids are known by the star their names begin with" {
    assert warps_name("q1:e1m1/*water0") and warps_name("*lava1") and warps_name("q1:*slime");
    assert not warps_name("q1:e1m1/+0slip") and not warps_name("q2:e1u1/water1") and not warps_name("star*");
}

test "a row of frames goes round at its game's pace, each frame beginning from itself" {
    assert frames_rate("q1:e1m1/+0slip") == 5.0 and frames_rate("q2:e1u1/comp1_1") == 2.0;
    assert frame_now(4, 0.0, 5.0) == 0 and frame_now(4, 0.21, 5.0) == 1 and frame_now(4, 0.81, 5.0) == 0;
    # The third of the row shows the fourth a fifth of a second on, and then the first.
    assert frame_now(4, 0.0, 5.0, 2) == 2 and frame_now(4, 0.21, 5.0, 2) == 3 and frame_now(4, 0.41, 5.0, 2) == 0;
    assert frame_now(1, 9.0, 5.0) == 0 and frame_now(0, 9.0, 5.0) == 0;
}

"""A picture of 8 by 8 whose every texel's red says where it is."""
def numbered -> bytes {
    made = bytearray(8 * 8 * 4);
    for at in range(64) {
        made[at * 4] = u8(at);
        made[at * 4 + 3] = u8(255);
    }
    return bytes(made);
}

test "a warped picture has every texel pushed along its row and its column by a wave" {
    still = numbered();
    moved = warped(still, 8, 8, 0.0);
    assert len(moved) == len(still) and moved != still;
    # At no time on the clock the first row and column are not pushed: the corner stays.
    assert int(moved[0]) == 0;
    # A quarter of the way down, the row is pushed an eighth of the picture: one texel.
    # A quarter of the way across, so is the column.
    assert int(moved[(2 * 8 + 0) * 4]) == 2 * 8 + 1 and int(moved[(0 * 8 + 2) * 4]) == 1 * 8 + 2;
    # It is the same texels in other places: none is made up.
    assert sorted([int(moved[at * 4]) for at in range(64)])[0] >= 0 and int(moved[3]) == 255;
    # The wave moves on with the clock.
    assert warped(still, 8, 8, 1.5) != moved;
    # What is not a picture is given back as it came.
    assert warped(b"abc", 8, 8, 0.0) == b"abc";
}
