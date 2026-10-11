import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, brush_volume, brush_windings, windings_bounds, brush_holds }
import from editor.geometry.patch {
    points_text,
    points_from,
    patch_surface,
    patch_brushes,
    patch_points,
    grid_grown,
    grid_shrunk,
    PATCH_KINDS
}

def near(a: float, b: float, slack: float = 0.5) -> bool {
    return abs(a - b) < slack;
}

def reach(brushes: list[list[Side]]) -> list[Vec3] {
    low = Vec3(x=100000.0, y=100000.0, z=100000.0);
    high = Vec3(x=-100000.0, y=-100000.0, z=-100000.0);
    for brush in brushes {
        box = windings_bounds(brush_windings(brush));
        if box is not None {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
            high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
        }
    }
    return [low, high];
}

test "control points are kept as a field and read back" {
    points = [Vec3(x=0.0, y=1.5, z=-2.0), Vec3(x=64.0, y=0.0, z=128.0)];
    assert points_text(points) == "0 1.5 -2 64 0 128";
    back = points_from("0 1.5 -2 64 0 128", 2);
    assert back is not None and back[0].y == 1.5 and back[1].z == 128.0;
    assert points_from("0 1.5 -2", 2) is None and points_from("0 x -2", 1) is None;
}

test "the surface passes through the corner control points and bends toward the others" {
    made = patch_points("arch", Vec3(), Vec3(x=128.0, y=64.0, z=96.0));
    assert made[0] == 5 and made[1] == 3 and len(made[2]) == 15;
    surface = patch_surface(made[2], 5, 3, 4);
    assert surface[0] == 9 and surface[1] == 5 and len(surface[2]) == 45;
    points = surface[2];
    # Its feet are on the floor at the box's sides, its crown at the top in the middle.
    assert near(points[0].x, 0.0) and near(points[0].z, 0.0) and near(points[8].x, 128.0) and near(points[8].z, 0.0);
    assert near(points[4].x, 64.0) and near(points[4].z, 96.0);
    # Between a foot and the crown it rounds the corner without reaching it.
    assert points[2].x < 20.0 and points[2].z > 60.0 and points[2].z < 96.0 and points[2].x > 0.0;
    assert len(patch_surface(made[2], 4, 3)[2]) == 0 and len(patch_surface(made[2][:9], 5, 3)[2]) == 0;
}

test "a sheet is thin prisms under its surface, two to a square" {
    made = patch_points("sheet", Vec3(), Vec3(x=128.0, y=128.0, z=64.0));
    brushes = patch_brushes(made[2], made[0], made[1], 4, 8.0, "glass");
    assert len(brushes) == 32;
    total = 0.0;
    for brush in brushes {
        assert len(brush) == 5 and brush[0].material == "glass";
        total += brush_volume(brush);
    }
    assert near(total, 128.0 * 128.0 * 8.0, 2.0);
    span = reach(brushes);
    assert near(span[1].z, 64.0) and near(span[0].z, 56.0) and near(span[1].x - span[0].x, 128.0);
}

test "a lifted control point bends the sheet toward it" {
    made = patch_points("sheet", Vec3(), Vec3(x=128.0, y=128.0, z=64.0));
    points = made[2];
    points[4] = points[4].add(Vec3(z=64.0));
    surface = patch_surface(points, 3, 3, 4);
    middle = surface[2][2 * 5 + 2];
    # Pulled a quarter of the way: the middle of a curve is half its middle control point.
    assert near(middle.z, 64.0 + 16.0) and near(surface[2][0].z, 64.0);
    assert near(reach(patch_brushes(points, 3, 3))[1].z, 80.0);
}

test "every kind of patch builds, and a cone's tip makes no prisms of nothing" {
    box = [Vec3(), Vec3(x=128.0, y=128.0, z=96.0)];
    for kind in PATCH_KINDS {
        made = patch_points(kind, box[0], box[1]);
        assert made[0] >= 3 and len(made[2]) == made[0] * made[1] , kind;
        brushes = patch_brushes(made[2], made[0], made[1], 3, 8.0, "wall");
        assert len(brushes) > 8 , kind;
        for brush in brushes {
            assert brush_volume(brush) > 0.5 , kind;
        }
    }
    assert patch_points("nothing", box[0], box[1])[0] == 0;
    tube = patch_points("cylinder", box[0], box[1]);
    walls = patch_brushes(tube[2], 9, 3, 3, 8.0);
    assert len(walls) == 4 * 3 * 3 * 2;
    for wall in walls {
        assert not brush_holds(wall, Vec3(x=64.0, y=64.0, z=48.0));
    }
    cone = patch_points("cone", box[0], box[1]);
    assert len(patch_brushes(cone[2], 9, 3, 3, 8.0)) < len(walls);
}

test "a grid of control points grows by a curve across or up, and shrinks again" {
    made = patch_points("sheet", Vec3(), Vec3(x=128.0, y=128.0, z=32.0));
    wider = grid_grown(made[2], 3, 3, "u");
    assert wider[0] == 5 and wider[1] == 3 and len(wider[2]) == 15;
    # The new columns carry on as the last two were going: 64 apart, to 192 and 256.
    assert wider[2][3].x == 192.0 and wider[2][4].x == 256.0 and wider[2][4].y == wider[2][2].y;
    assert wider[2][8].x == 192.0 and wider[2][0].x == 0.0;
    taller = grid_grown(wider[2], 5, 3, "v");
    assert taller[0] == 5 and taller[1] == 5 and taller[2][20].y == 256.0 and taller[2][15].y == 192.0;
    # Twice as many curves across make about twice the prisms.
    assert len(patch_brushes(wider[2], 5, 3, 3, 8.0, "wall")) == 2 * len(patch_brushes(made[2], 3, 3, 3, 8.0, "wall"));
    back = grid_shrunk(taller[2], 5, 5, "v");
    assert back[1] == 3 and back[2] == wider[2];
    back = grid_shrunk(back[2], 5, 3, "u");
    assert back[0] == 3 and len(back[2]) == 9 and back[2][2].x == 128.0;
    # One curve cannot shrink.
    assert grid_shrunk(made[2], 3, 3, "u")[0] == 3 and grid_shrunk(made[2], 3, 3, "v")[1] == 3;
}

test "an endcap is half a pipe, open to the near side" {
    made = patch_points("endcap", Vec3(), Vec3(x=128.0, y=64.0, z=96.0));
    assert made[0] == 5 and made[1] == 3;
    surface = patch_surface(made[2], 5, 3, 4)[2];
    reach_y = max([point.y for point in surface]);
    # It bulges to the far side and both ends are at the near one.
    assert reach_y > 40.0 and surface[0].y == 0.0 and surface[patch_surface(made[2], 5, 3, 4)[0] - 1].y == 0.0;
}
