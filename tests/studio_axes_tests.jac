import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, box_sides, side_turned }
import from editor.geometry.axes { world_axes, ordered_axes, brush_axes, facing_axes, kept_to_axis }

def near(one: Vec3, other: Vec3) -> bool {
    return one.sub(other).length() < 0.001;
}

test "a box that has not been turned has the world's own axes" {
    found = brush_axes(box_sides(Vec3(), Vec3(x=64.0, y=32.0, z=16.0), "wall"));
    assert near(found[0], Vec3(x=1.0)) and near(found[1], Vec3(y=1.0)) and near(found[2], Vec3(z=1.0));
    none = brush_axes([]);
    assert near(none[0], world_axes()[0]) and near(none[1], world_axes()[1]) and near(none[2], world_axes()[2]);
}

test "axes are put where the world's they lie nearest are, pointing its way" {
    found = ordered_axes([Vec3(z=-1.0), Vec3(y=1.0), Vec3(x=-1.0)]);
    assert near(found[0], Vec3(x=1.0)) and near(found[1], Vec3(y=1.0)) and near(found[2], Vec3(z=1.0));
}

test "an entity's axes follow the way it faces" {
    found = facing_axes(30.0);
    assert near(found[0], Vec3(x=math.cos(math.radians(30.0)), y=math.sin(math.radians(30.0))));
    assert near(found[1], Vec3(x=-math.sin(math.radians(30.0)), y=math.cos(math.radians(30.0)))) and near(found[2], Vec3(z=1.0));
    # Facing along the world's y, its ahead is the axis nearest y, and its left the one nearest x, turned to point along it.
    turned = facing_axes(90.0);
    assert near(turned[1], Vec3(y=1.0)) and near(turned[0], Vec3(x=1.0));
}

test "a move is kept to one axis in whole steps along it" {
    slant = Vec3(x=1.0, y=1.0).normalized();
    kept = kept_to_axis(Vec3(x=20.0, y=4.0, z=9.0), slant, 8.0);
    # 24 over root two along the slant is about 17: two steps of 8.
    assert near(kept, slant.scale(16.0));
    assert near(kept_to_axis(Vec3(x=3.0), Vec3(x=1.0), 0.0), Vec3(x=3.0));
}

test "a box turned about the upright has its own axes, turned with it" {
    sides = [side_turned(side, Vec3(), math.radians(30.0)) for side in box_sides(Vec3(), Vec3(x=64.0, y=32.0, z=16.0), "wall")];
    found = brush_axes(sides);
    assert near(found[0], Vec3(x=math.cos(math.radians(30.0)), y=math.sin(math.radians(30.0))));
    assert near(found[1], Vec3(x=-math.sin(math.radians(30.0)), y=math.cos(math.radians(30.0))));
    assert near(found[2], Vec3(z=1.0));
}
