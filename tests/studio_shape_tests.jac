import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, brush_windings, brush_volume, brush_holds, windings_bounds }
import from editor.geometry.csg { common_sides, brush_corners }
import from editor.geometry.shapes {
    cone_brushes,
    ball_brushes,
    stair_brushes,
    spiral_brushes,
    arch_brushes,
    pipe_brushes,
    shape_brushes,
    SHAPE_KINDS
}

def near(a: float, b: float, slack: float = 0.5) -> bool {
    return abs(a - b) < slack;
}

def room -> list[Vec3] {
    return [Vec3(), Vec3(x=128.0, y=128.0, z=64.0)];
}

"""The box round several brushes."""
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

test "a pyramid is a third of its box and a cone comes to a point over the middle" {
    box = room();
    pyramid = cone_brushes(box[0], box[1], 4, "stone");
    assert len(pyramid) == 1 and len(pyramid[0]) == 5;
    assert near(brush_volume(pyramid[0]), 128.0 * 128.0 * 64.0 / 3.0);
    assert pyramid[0][0].material == "stone";
    cone = cone_brushes(box[0], box[1], 12);
    assert len(cone) == 1 and len(cone[0]) == 13;
    assert brush_holds(cone[0], Vec3(x=64.0, y=64.0, z=63.0)) and not brush_holds(cone[0], Vec3(x=8.0, y=8.0, z=32.0));
    assert brush_volume(cone[0]) < brush_volume(pyramid[0]);
}

test "a ball fills its box and a dome stands on its floor" {
    box = [Vec3(), Vec3(x=128.0, y=128.0, z=128.0)];
    ball = ball_brushes(box[0], box[1], 6);
    assert len(ball) == 1;
    span = reach(ball);
    assert near(span[0].z, 0.0) and near(span[1].z, 128.0) and near(span[1].x, 128.0);
    # Less than the ball it approximates, more than half of that.
    whole = 4.0 / 3.0 * math.pi * 64.0 * 64.0 * 64.0;
    assert brush_volume(ball[0]) < whole and brush_volume(ball[0]) > whole * 0.5;
    dome = ball_brushes(box[0], box[1], 6, "", True);
    assert len(dome) == 1 and near(reach(dome)[0].z, 0.0) and near(reach(dome)[1].z, 128.0);
    assert brush_holds(dome[0], Vec3(x=64.0, y=64.0, z=1.0)) and not brush_holds(dome[0], Vec3(x=4.0, y=4.0, z=100.0));
}

test "stairs are steps that stand on the floor and do not overlap" {
    box = room();
    steps = stair_brushes(box[0], box[1], 8, "wood");
    assert len(steps) == 8;
    total = 0.0;
    for (index, step) in enumerate(steps) {
        span = windings_bounds(brush_windings(step));
        assert span is not None and near(span[0].z, 0.0) and near(span[1].z, 8.0 * float(index + 1));
        assert near(span[1].y - span[0].y, 16.0);
        total += brush_volume(step);
    }
    assert near(total, 128.0 * 16.0 * 8.0 * 36.0);
    assert len(common_sides(steps[0], steps[1])) == 0;
}

test "a spiral winds its steps once round the middle, each a step higher" {
    box = [Vec3(), Vec3(x=128.0, y=128.0, z=96.0)];
    steps = spiral_brushes(box[0], box[1], 12);
    assert len(steps) == 12;
    for (index, step) in enumerate(steps) {
        span = windings_bounds(brush_windings(step));
        assert span is not None and near(span[0].z, 8.0 * float(index)) and near(span[1].z, 8.0 * float(index + 1));
        assert brush_volume(step) > 100.0;
    }
    span = reach(steps);
    assert near(span[0].x, 0.0) and near(span[1].x, 128.0) and near(span[1].z, 96.0);
}

test "an arch leaves its middle open and a pipe is open down its length" {
    box = [Vec3(), Vec3(x=128.0, y=32.0, z=64.0)];
    arch = arch_brushes(box[0], box[1], 8, 16.0, "brick");
    assert len(arch) == 8;
    span = reach(arch);
    assert near(span[0].x, 0.0) and near(span[1].x, 128.0) and near(span[1].z, 64.0) and near(span[1].y, 32.0);
    for block in arch {
        assert not brush_holds(block, Vec3(x=64.0, y=16.0, z=16.0));
    }
    held = 0;
    for block in arch {
        if brush_holds(block, Vec3(x=64.0, y=16.0, z=56.0)) {
            held += 1;
        }
    }
    assert held >= 1;
    box = [Vec3(), Vec3(x=128.0, y=128.0, z=64.0)];
    pipe = pipe_brushes(box[0], box[1], 12, 16.0);
    assert len(pipe) == 12;
    for block in pipe {
        assert not brush_holds(block, Vec3(x=64.0, y=64.0, z=32.0));
    }
    span = reach(pipe);
    assert near(span[1].x - span[0].x, 128.0) and near(span[1].z, 64.0);
}

test "every kind of shape makes brushes that enclose something" {
    box = room();
    for kind in SHAPE_KINDS {
        made = shape_brushes(kind, box[0], box[1], 0, 16.0, "wall");
        assert len(made) > 0 , kind;
        for brush in made {
            assert brush_volume(brush) > 1.0 , kind;
            assert len(brush_corners(brush)) >= 4 , kind;
        }
    }
    assert len(shape_brushes("nothing", box[0], box[1])) == 0;
}
