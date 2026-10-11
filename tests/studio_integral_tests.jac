import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, Plane3, box_sides, brush_volume, brush_windings, windings_bounds }
import from editor.geometry.integral { faces_astray, sides_integral, normal_snapped, sides_angled }

def about(a: float, b: float, slack: float = 0.001) -> bool {
    return abs(a - b) < slack;
}

def near(a: Vec3, b: Vec3, slack: float = 0.001) -> bool {
    return a.sub(b).length() < slack;
}

"""A box whose top has drifted: a little off the level and a little high."""
def drifted -> list[Side] {
    sides = box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall");
    made: list[Side] = [];
    for side in sides {
        if side.plane.normal.z > 0.9 {
            leaning = Vec3(x=0.004, y=-0.003, z=1.0).normalized();
            made.append(Side(plane=Plane3(normal=leaning, dist=64.21), material=side.material, mapping=side.mapping));
        } else {
            made.append(side);
        }
    }
    return made;
}

def top_of(sides: list[Side]) -> int {
    for (index, side) in enumerate(sides) {
        if side.plane.normal.z > 0.9 {
            return index;
        }
    }
    return -1;
}

test "a face that has drifted off whole numbers is laid through whole points again" {
    sides = drifted();
    top = top_of(sides);
    assert top >= 0 and faces_astray(sides, [top]) > 0.1 and faces_astray(box_sides(Vec3(), Vec3(x=8.0, y=8.0, z=8.0)), [0, 1, 2]) == 0.0;
    mended = sides_integral(sides, [top]);
    assert near(mended[top].plane.normal, Vec3(z=1.0), 0.0000001) and mended[top].plane.dist == 64.0;
    assert faces_astray(mended, [top]) == 0.0 and about(brush_volume(mended), 64.0 * 64.0 * 64.0, 0.01);
    # Asked again, nothing is changed: every face is the one it was.
    again = sides_integral(mended, [0, 1, 2, 3, 4, 5]);
    assert [again[index] is mended[index] for index in range(6)] == [True] * 6;
    # Its material is what it was, and the other faces are the very ones.
    assert mended[top].material == "wall" and [mended[index] is sides[index] for index in range(len(sides)) if index != top] == [True] * 5;
    # On a coarser grid a face goes to that grid's points.
    tall = box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=70.0), "wall");
    lowered = sides_integral(tall, [top_of(tall)], 16.0);
    assert lowered[top_of(tall)].plane.dist == 64.0;
    # A face too small for the grid would have its corners fall together: it is left.
    sliver = box_sides(Vec3(), Vec3(x=2.0, y=3.0, z=5.0), "wall");
    assert sides_integral(sliver, [top_of(sliver)], 16.0)[top_of(sliver)] is sliver[top_of(sliver)];
    # A face that is not there is not looked at.
    assert sides_integral(sides, [99, -1]) == sides and faces_astray(sides, [99]) == 0.0;
}

test "a direction is put on whole angles of heading and tilt" {
    assert near(normal_snapped(Vec3(z=1.0)), Vec3(z=1.0)) and near(normal_snapped(Vec3(x=-3.0)), Vec3(x=-1.0));
    # Forty-three degrees up from level along x, on steps of fifteen: forty-five.
    leaning = Vec3(x=math.cos(math.radians(43.0)), z=math.sin(math.radians(43.0)));
    snapped = normal_snapped(leaning, 15.0);
    assert about(snapped.x, math.cos(math.radians(45.0))) and about(snapped.z, math.sin(math.radians(45.0))) and about(snapped.y, 0.0);
    # A heading of twenty-eight degrees on steps of thirty.
    turned = normal_snapped(Vec3(x=math.cos(math.radians(28.0)), y=math.sin(math.radians(28.0))), 30.0);
    assert about(turned.x, math.cos(math.radians(30.0))) and about(turned.y, 0.5) and about(turned.z, 0.0);
    assert near(normal_snapped(Vec3(), 15.0), Vec3()) and near(normal_snapped(leaning, 0.0), leaning);
}

test "a face is tilted to a whole angle about its own middle" {
    sides = drifted();
    top = top_of(sides);
    outline = brush_windings(sides)[top];
    middle = Vec3();
    for corner in outline {
        middle = middle.add(corner);
    }
    middle = middle.scale(1.0 / float(len(outline)));
    level = sides_angled(sides, [top], 15.0);
    assert near(level[top].plane.normal, Vec3(z=1.0), 0.000001);
    # It turned about its middle: that point is still on it.
    assert about(level[top].plane.side(middle), 0.0, 0.0001) and about(level[top].plane.dist, middle.z, 0.0001);
    # A face already on whole angles is the very one it was.
    square = box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall");
    assert sides_angled(square, [0, 1, 2, 3, 4, 5], 15.0) == square;
    # A slope ten degrees off forty-five becomes one of forty-five, and still encloses a brush.
    ramp: list[Side] = [];
    for side in square {
        if side.plane.normal.z > 0.9 {
            slope = Vec3(x=math.sin(math.radians(40.0)), z=math.cos(math.radians(40.0)));
            ramp.append(Side(plane=Plane3(normal=slope, dist=slope.dot(Vec3(x=32.0, y=32.0, z=64.0))), material="wall", mapping=side.mapping));
        } else {
            ramp.append(side);
        }
    }
    sloped = top_of(square);
    eased = sides_angled(ramp, [sloped], 15.0);
    # Its normal stood fifty degrees up from the level: forty-five now.
    tilt = math.degrees(math.asin(eased[sloped].plane.normal.z));
    assert about(tilt, 45.0, 0.001) and about(eased[sloped].plane.normal.y, 0.0) and brush_volume(eased) > 1000.0;
}
