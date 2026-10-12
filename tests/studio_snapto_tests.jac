import from engine.math.vec3 { Vec3 }
import from editor.geometry.snapto { loop_inside, loop_thinned, snapped_move }

def near(a: Vec3, b: Vec3) -> bool {
    return a.sub(b).length() < 0.001;
}

test "a point is inside a loop drawn round it, whatever the loop's shape" {
    square = [10, 10, 50, 10, 50, 50, 10, 50];
    assert loop_inside(square, 30, 30) and not loop_inside(square, 60, 30) and not loop_inside(square, 30, 5);
    # An L: the notch is outside.
    ell = [0, 0, 60, 0, 60, 20, 20, 20, 20, 60, 0, 60];
    assert loop_inside(ell, 10, 50) and loop_inside(ell, 50, 10) and not loop_inside(ell, 40, 40);
    # Drawn the other way round it is the same loop.
    back = [10, 50, 50, 50, 50, 10, 10, 10];
    assert loop_inside(back, 30, 30) and not loop_inside(back, 0, 0);
    assert not loop_inside([10, 10, 50, 50], 30, 30) and not loop_inside([], 0, 0);
}

test "a long loop is thinned to so many points, its ends kept" {
    long: list[int] = [];
    for at in range(200) {
        long.append(at);
        long.append(at * 2);
    }
    thin = loop_thinned(long, 48);
    assert len(thin) == 96 and thin[:2] == [0, 0] and thin[-2:] == [199, 398];
    assert loop_thinned([1, 2, 3, 4, 5, 6], 48) == [1, 2, 3, 4, 5, 6] and loop_thinned([1, 2, 3], 48) == [1, 2];
}

test "a move ends on a corner, an edge or a face that it comes within reach of" {
    # A box 64 on a side stands with a corner on the origin; a point is moved toward it.
    corners = [Vec3(), Vec3(y=64.0), Vec3(z=64.0), Vec3(y=64.0, z=64.0)];
    edges = [[Vec3(), Vec3(y=64.0)], [Vec3(), Vec3(z=64.0)]];
    faces = [[Vec3(), Vec3(y=64.0), Vec3(y=64.0, z=64.0), Vec3(z=64.0)]];
    moving = [Vec3(x=128.0, y=0.0, z=0.0), Vec3(x=192.0, y=0.0, z=0.0)];
    asked = Vec3(x=-121.0, y=3.0, z=0.0);
    # Seven and three short of the corner: within reach, and so on to it.
    assert near(snapped_move(moving, asked, corners, edges, faces, "corners", 16.0), Vec3(x=-128.0));
    # Out of reach it is the move as asked; and with no snapping at all.
    assert near(snapped_move(moving, asked, corners, edges, faces, "corners", 4.0), asked);
    assert near(snapped_move(moving, asked, corners, edges, faces, "grid", 16.0), asked);
    # Part way along an edge: to corners it is out of reach, to edges it lands on the edge beside it.
    along = Vec3(x=-121.0, y=30.0, z=0.0);
    assert near(snapped_move(moving, along, corners, edges, faces, "corners", 16.0), along);
    assert near(snapped_move(moving, along, corners, edges, faces, "edges", 16.0), Vec3(x=-128.0, y=30.0));
    # Over the middle of the face: only faces takes it, straight on to the face.
    over = Vec3(x=-121.0, y=30.0, z=20.0);
    assert near(snapped_move(moving, over, corners, edges, faces, "edges", 16.0), over);
    assert near(snapped_move(moving, over, corners, edges, faces, "faces", 16.0), Vec3(x=-128.0, y=30.0, z=20.0));
    # Past the face's edge the face is not there to land on, but its edge still is.
    past = Vec3(x=-121.0, y=-5.0, z=20.0);
    assert near(snapped_move(moving, past, corners, edges, faces, "faces", 16.0), Vec3(x=-128.0, y=0.0, z=20.0));
    # Nothing to land on, nothing moving: the move as asked.
    assert near(snapped_move(moving, asked, [], [], [], "faces", 16.0), asked) and near(snapped_move([], asked, corners, edges, faces, "faces", 16.0), asked);
}
