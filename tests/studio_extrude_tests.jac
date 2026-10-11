import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, box_sides, brush_volume, brush_holds, brush_windings, windings_bounds, cylinder_sides }
import from editor.geometry.extrude { profile_pieces, profile_of, sweep_brushes, sweep_frame, PROFILE_KINDS }

def about(a: float, b: float, slack: float = 0.5) -> bool {
    return abs(a - b) < slack;
}

"""How much the brushes hold between them."""
def total(brushes: list[list[Side]]) -> float {
    sum = 0.0;
    for sides in brushes {
        sum += brush_volume(sides);
    }
    return sum;
}

"""How many of the brushes a point is inside."""
def holders(brushes: list[list[Side]], point: Vec3) -> int {
    count = 0;
    for sides in brushes {
        if brush_holds(sides, point) {
            count += 1;
        }
    }
    return count;
}

test "every outline has convex pieces within its square" {
    for kind in PROFILE_KINDS {
        pieces = profile_pieces(kind);
        assert len(pieces) >= 1 , kind;
        for piece in pieces {
            assert len(piece) >= 3 , kind;
            for (across, up) in piece {
                assert abs(across) <= 0.5001 and abs(up) <= 0.5001 , kind;
            }
        }
    }
    assert len(profile_pieces("round", 12)[0]) == 12 and len(profile_pieces("round", 2)[0]) == 3;
    assert len(profile_pieces("rail")) == 3 and len(profile_pieces("ell")) == 2 and profile_pieces("nothing") == [];
}

test "a square swept along a line is a beam of the line's length" {
    made = sweep_brushes(profile_pieces("square"), [Vec3(), Vec3(x=256.0)], 32.0, 16.0, "beam");
    assert len(made) == 1 and len(made[0]) == 6 and made[0][0].material == "beam";
    assert about(brush_volume(made[0]), 256.0 * 32.0 * 16.0);
    box = windings_bounds(brush_windings(made[0]));
    assert box is not None and about(box[0].x, 0.0) and about(box[1].x, 256.0);
    assert about(box[0].y, -16.0) and about(box[1].y, 16.0) and about(box[0].z, -8.0) and about(box[1].z, 8.0);
    # A line of no length, or an outline of no size, sweeps nothing.
    assert sweep_brushes(profile_pieces("square"), [Vec3(), Vec3()], 32.0, 16.0) == [];
    assert sweep_brushes(profile_pieces("square"), [Vec3(), Vec3(x=64.0)], 0.0, 16.0) == [];
    # Straight up, across is still across.
    frame = sweep_frame(Vec3(z=1.0));
    assert about(abs(frame[0].y), 1.0, 0.001) and about(frame[1].length(), 1.0, 0.001);
    up = sweep_brushes(profile_pieces("square"), [Vec3(), Vec3(z=128.0)], 32.0, 32.0);
    assert len(up) == 1 and about(brush_volume(up[0]), 128.0 * 32.0 * 32.0);
}

test "at a turn the stretches meet on the plane that halves it, with no gap and no overlap" {
    path = [Vec3(), Vec3(x=256.0), Vec3(x=256.0, y=256.0)];
    made = sweep_brushes(profile_pieces("square"), path, 32.0, 32.0);
    assert len(made) == 2;
    # Cut at forty-five degrees, the two hold what the path's length would.
    assert about(total(made), 512.0 * 32.0 * 32.0, 2.0);
    # Inside the corner, either side of the cut, and on the outside of the bend: in one brush each.
    for point in [Vec3(x=250.0, y=-4.0), Vec3(x=260.0, y=4.0), Vec3(x=268.0, y=-14.0), Vec3(x=246.0, y=14.0)] {
        assert holders(made, point) == 1 , str(point.x) + " " + str(point.y);
    }
    # Beyond the bend's outer corner there is nothing.
    assert holders(made, Vec3(x=280.0, y=-20.0)) == 0;
    # A climb: the same across, and as much in it as its length makes.
    climb = [Vec3(), Vec3(x=128.0), Vec3(x=256.0, z=128.0)];
    ramp = sweep_brushes(profile_pieces("square"), climb, 64.0, 16.0);
    assert len(ramp) == 2 and about(total(ramp), (128.0 + math.sqrt(2.0) * 128.0) * 64.0 * 16.0, 4.0);
    assert holders(ramp, Vec3(x=192.0, z=64.0)) == 1 and holders(ramp, Vec3(x=192.0, z=0.0)) == 0;
}

test "an outline of several pieces sweeps a brush a piece a stretch, and a closed path a ring" {
    path = [Vec3(), Vec3(x=256.0), Vec3(x=256.0, y=256.0)];
    rail = sweep_brushes(profile_pieces("rail"), path, 32.0, 64.0);
    assert len(rail) == 6;
    # A rail is two flanges a quarter of its height and a web a quarter of its width.
    assert about(total(rail), 512.0 * (2.0 * 32.0 * 16.0 + 8.0 * 32.0), 4.0);
    # In the web, and beside it where the flanges leave a hollow.
    assert holders(rail, Vec3(x=128.0)) == 1 and holders(rail, Vec3(x=128.0, y=12.0)) == 0;
    assert holders(rail, Vec3(x=128.0, y=12.0, z=28.0)) == 1;
    square = [Vec3(), Vec3(x=256.0), Vec3(x=256.0, y=256.0), Vec3(y=256.0)];
    ring = sweep_brushes(profile_pieces("square"), square, 32.0, 32.0, "", True);
    assert len(ring) == 4 and about(total(ring), 1024.0 * 32.0 * 32.0, 4.0);
    # The first corner is mitred too.
    assert holders(ring, Vec3(x=-8.0, y=-4.0)) == 1 and holders(ring, Vec3(x=-4.0, y=-8.0)) == 1;
    assert holders(ring, Vec3(x=128.0, y=128.0)) == 0;
    # Open, the same four points leave the last side out.
    assert len(sweep_brushes(profile_pieces("square"), square, 32.0, 32.0)) == 3;
    pipe = sweep_brushes(profile_pieces("round", 8), [Vec3(), Vec3(x=128.0)], 64.0, 64.0);
    assert len(pipe) == 1 and len(pipe[0]) == 10;
}

test "a brush's own outline, seen from the front, is swept as it is" {
    wedge = profile_of(box_sides(Vec3(x=-24.0, y=0.0, z=0.0), Vec3(x=24.0, y=8.0, z=16.0)));
    assert len(wedge[0]) == 4 and about(wedge[1], 48.0, 0.01) and about(wedge[2], 16.0, 0.01);
    made = sweep_brushes([wedge[0]], [Vec3(), Vec3(y=128.0)], wedge[1], wedge[2]);
    assert len(made) == 1 and about(brush_volume(made[0]), 48.0 * 16.0 * 128.0);
    # A drum seen from the front is a slab: its corners in a row along the
    # top and the bottom make no more sides.
    drum = profile_of(cylinder_sides(Vec3(x=-32.0, y=-32.0, z=0.0), Vec3(x=32.0, y=32.0, z=8.0), 8));
    assert len(drum[0]) >= 4 and about(drum[1], 64.0, 0.01) and about(drum[2], 8.0, 0.01);
    slab = sweep_brushes([drum[0]], [Vec3(), Vec3(y=64.0)], drum[1], drum[2]);
    assert len(slab) == 1 and len(slab[0]) == 6 and about(brush_volume(slab[0]), 64.0 * 8.0 * 64.0);
    assert profile_of([])[0] == [];
}
