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
    bicone_brushes,
    torus_brushes,
    xtree_brushes,
    cap_brushes,
    corner_brushes,
    column_brushes,
    landing_brushes,
    caulked,
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

def total(brushes: list[list[Side]]) -> float {
    volume = 0.0;
    for brush in brushes {
        volume += brush_volume(brush);
    }
    return volume;
}

test "two cones, a ring, crossed walls, a cap, a corner and a column fill their boxes" {
    box = room();
    # Two cones base to base: a third of the cylinder they stand in.
    bicone = bicone_brushes(box[0], box[1], 16, "wall");
    # (Its base has sixteen sides, so it is a little less than the round one.)
    assert len(bicone) == 1 and near(total(bicone), math.pi * 64.0 * 64.0 * 64.0 / 3.0, 8000.0);
    span = reach(bicone);
    assert near(span[0].z, 0.0) and near(span[1].z, 64.0) and near(span[1].x, 128.0);
    # A ring: twelve blocks, open in the middle, within the box.
    ring = torus_brushes(box[0], box[1], 12, 32.0, "wall");
    assert len(ring) == 12;
    for block in ring {
        assert not brush_holds(block, Vec3(x=64.0, y=64.0, z=32.0));
    }
    span = reach(ring);
    assert span[0].x > -0.5 and span[1].x < 128.5 and span[1].z < 64.5 and span[0].z > -0.5;
    assert near(span[1].z - span[0].z, 32.0, 1.0);
    # Three thin walls crossed at the middle, each as tall as the box.
    tree = xtree_brushes(box[0], box[1], 3, "leaf");
    assert len(tree) == 3;
    for wall in tree {
        assert brush_holds(wall, Vec3(x=64.0, y=64.0, z=32.0)) and near(brush_volume(wall), 128.0 * 2.0 * 64.0, 300.0);
    }
    # A cap: half a disc, filled, as deep as the box.
    cap = cap_brushes(box[0], box[1], 16, "wall");
    assert len(cap) == 16 and near(total(cap), math.pi * 64.0 * 64.0 * 0.5 * 128.0, 12000.0);
    assert brush_holds(cap[8], Vec3(x=60.0, y=64.0, z=30.0)) or brush_holds(cap[7], Vec3(x=60.0, y=64.0, z=30.0));
    # A rounded corner: a quarter disc from the box's low corner; one wedge of it is a bevel.
    corner = corner_brushes(box[0], box[1], 6, "wall");
    assert len(corner) == 6 and near(total(corner), math.pi * 128.0 * 64.0 * 0.25 * 128.0, 12000.0);
    bevel = shape_brushes("bevel", box[0], box[1], 0, 16.0, "wall");
    assert len(bevel) == 1 and near(total(bevel), 128.0 * 64.0 * 0.5 * 128.0, 10.0);
    # A column: a foot, a head and a shaft between them.
    column = column_brushes(box[0], box[1], 8, "stone");
    assert len(column) == 3 and near(brush_volume(column[0]), 128.0 * 128.0 * 8.0, 1.0);
    shaft = reach([column[2]]);
    assert near(shaft[0].z, 8.0) and near(shaft[1].z, 56.0) and shaft[1].x < 113.0;
}

test "stairs with a landing go up one side and come back up the other" {
    box = [Vec3(), Vec3(x=128.0, y=192.0, z=128.0)];
    flight = landing_brushes(box[0], box[1], 8, "wood");
    # Four steps, the landing, four more.
    assert len(flight) == 9;
    landing = reach([flight[4]]);
    assert near(landing[0].y, 144.0) and near(landing[1].y, 192.0) and near(landing[1].z, 64.0);
    assert near(landing[0].x, 0.0) and near(landing[1].x, 128.0);
    first = reach([flight[0]]);
    last = reach([flight[8]]);
    # The first step is at the near end on the left; the last, at the near end on the right, reaches the top.
    assert near(first[0].y, 0.0) and near(first[1].x, 64.0) and near(first[1].z, 16.0);
    assert near(last[0].y, 0.0) and near(last[0].x, 64.0) and near(last[1].z, 128.0);
    assert near(reach(flight)[1].z, 128.0);
}

test "the faces a shape's own brushes cover are caulked, and no others" {
    box = room();
    steps = stair_brushes(box[0], box[1], 4, "wood");
    hidden = caulked(steps);
    assert len(hidden) == 4;
    count = 0;
    for brush in hidden {
        for side in brush {
            if side.material == "caulk" {
                count += 1;
            }
        }
    }
    # Each step's back is against the next, taller, step: three faces; no step covers another's front or top.
    assert count == 3 , str(count);
    for index in range(4) {
        for which in range(len(hidden[index])) {
            side = hidden[index][which];
            if side.plane.normal.z > 0.9 or side.plane.normal.y < -0.9 {
                assert side.material == "wood";
            }
        }
    }
    # Brushes apart cover nothing of each other.
    apart = caulked([steps[0], steps[3]]);
    assert [side.material for side in apart[0]] == ["wood"] * 6;
    # A box wholly against a bigger one: the small one's touching face goes, the big one's does not.
    pair = caulked(
        [
            shape_brushes("pyramid", Vec3(), Vec3(x=64.0, y=64.0, z=32.0), 0, 16.0, "wall")[0],
            stair_brushes(Vec3(x=-64.0, y=-64.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), 1, "floor")[0]
        ],
        "nodraw"
    );
    assert len([side for side in pair[0] if side.material == "nodraw"]) == 1;
    assert len([side for side in pair[1] if side.material == "nodraw"]) == 0;
}
