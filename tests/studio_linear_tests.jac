import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, Mapping, box_sides, brush_volume, brush_windings, windings_bounds, brush_holds }
import from editor.geometry.mapping { mapping_place, side_stretched, side_spun }
import from editor.document.scene { Scene, Item }
import from editor.geometry.patch { patch_points }
import from editor.geometry.linear {
    Linear,
    linear_turn,
    linear_size,
    linear_shear,
    linear_text,
    linear_from,
    point_remapped,
    side_remapped,
    sides_remapped,
    box_part,
    box_drag
}

def about(a: float, b: float, slack: float = 0.001) -> bool {
    return abs(a - b) < slack;
}

def near(a: Vec3, b: Vec3, slack: float = 0.001) -> bool {
    return a.sub(b).length() < slack;
}

test "a change is what it makes of the axes: turns, sizes and shears, one after another, and undone" {
    quarter = linear_turn(0, 1, 90.0);
    assert near(quarter.carry(Vec3(x=1.0)), Vec3(y=1.0)) and near(quarter.carry(Vec3(y=1.0)), Vec3(x=-1.0));
    assert near(quarter.carry(Vec3(z=5.0)), Vec3(z=5.0)) and about(quarter.volume(), 1.0);
    # In the plane of x and z, x toward z.
    assert near(linear_turn(0, 2, 90.0).carry(Vec3(x=2.0, y=3.0)), Vec3(y=3.0, z=2.0));
    sized = linear_size(Vec3(x=2.0, y=-1.0, z=0.5));
    assert near(sized.carry(Vec3(x=1.0, y=1.0, z=4.0)), Vec3(x=2.0, y=-1.0, z=2.0)) and about(sized.volume(), -1.0);
    # A shear along x across z: a point slides along x by half its height.
    lean = linear_shear(0, 2, 0.5);
    assert near(lean.carry(Vec3(x=1.0, y=2.0, z=8.0)), Vec3(x=5.0, y=2.0, z=8.0)) and about(lean.volume(), 1.0);
    assert linear_shear(1, 1, 3.0).idle() and Linear().idle() and not lean.idle();
    # One after another, as one; and back again.
    both = sized.followed(quarter);
    assert near(both.carry(Vec3(x=1.0)), Vec3(y=2.0)) and near(both.carry(Vec3(y=1.0)), Vec3(x=1.0));
    undo = both.back();
    assert undo is not None and both.followed(undo).idle() and undo.followed(both).idle();
    back = lean.back();
    assert back is not None and near(back.carry(Vec3(x=5.0, y=2.0, z=8.0)), Vec3(x=1.0, y=2.0, z=8.0));
    # A change that flattens the world cannot be undone, and has no slopes.
    flat = Linear(z=Vec3(x=1.0));
    assert flat.back() is None and flat.slopes() is None and about(flat.volume(), 0.0);
    # As nine numbers.
    assert linear_text(lean) == "1 0 0 0 1 0 0.5 0 1" and linear_text(quarter) == "0 1 0 -1 0 0 0 0 1";
    read = linear_from(linear_text(lean).split());
    assert read is not None and near(read.z, Vec3(x=0.5, z=1.0));
    assert linear_from(["1", "0"]) is None and linear_from("1 0 0 0 one 0 0 0 1".split()) is None;
}

test "a box sheared keeps its volume and leans, its material going with it" {
    sides = box_sides(Vec3(), Vec3(x=64.0, y=32.0, z=64.0), "tile");
    lean = linear_shear(0, 2, 0.5);
    leant = sides_remapped(sides, Vec3(), lean);
    assert len(leant) == 6 and about(brush_volume(leant), 64.0 * 32.0 * 64.0, 0.5);
    bounds = windings_bounds(brush_windings(leant));
    assert bounds is not None and near(bounds[0], Vec3()) and near(bounds[1], Vec3(x=96.0, y=32.0, z=64.0));
    # Its foot is where it was; its top has slid thirty-two units along x.
    assert brush_holds(leant, Vec3(x=40.0, y=16.0, z=60.0)) and not brush_holds(leant, Vec3(x=4.0, y=16.0, z=60.0));
    assert brush_holds(leant, Vec3(x=4.0, y=16.0, z=4.0)) and not brush_holds(leant, Vec3(x=90.0, y=16.0, z=4.0));
    # Every point of every face has the place on its material it had before.
    for (index, side) in enumerate(sides) {
        for corner in brush_windings(sides)[index] {
            before = mapping_place(side.mapping, corner);
            after = mapping_place(leant[index].mapping, point_remapped(corner, Vec3(), lean));
            assert about(before[0], after[0], 0.01) and about(before[1], after[1], 0.01);
        }
    }
    # About another pivot the same shape stands elsewhere: the pivot's own height stays put.
    high = sides_remapped(sides, Vec3(z=64.0), lean);
    raised = windings_bounds(brush_windings(high));
    assert raised is not None and near(raised[0], Vec3(x=-32.0)) and near(raised[1], Vec3(x=64.0, y=32.0, z=64.0));
    # Flattened, there is no brush.
    assert sides_remapped(sides, Vec3(), Linear(z=Vec3(x=1.0))) == [];
}

test "a turn and a stretch through a change are what the turn and the stretch already made" {
    sides = box_sides(Vec3(x=16.0, y=-8.0, z=0.0), Vec3(x=80.0, y=24.0, z=48.0), "tile");
    pivot = Vec3(x=32.0, y=8.0, z=16.0);
    turned = sides_remapped(sides, pivot, linear_turn(0, 1, 90.0));
    stretched = sides_remapped(sides, pivot, linear_size(Vec3(x=2.0, y=0.5, z=1.0)));
    for (index, side) in enumerate(sides) {
        spun = side_spun(side, pivot, 2, 1.5707963267948966);
        assert near(turned[index].plane.normal, spun.plane.normal) and about(turned[index].plane.dist, spun.plane.dist);
        wide = side_stretched(side, pivot, Vec3(x=2.0, y=0.5, z=1.0));
        assert near(stretched[index].plane.normal, wide.plane.normal) and about(stretched[index].plane.dist, wide.plane.dist);
        for probe in [pivot, Vec3(x=100.0, y=50.0, z=-20.0)] {
            ours = mapping_place(stretched[index].mapping, probe);
            theirs = mapping_place(wide.mapping, probe);
            assert about(ours[0], theirs[0], 0.01) and about(ours[1], theirs[1], 0.01);
            ours = mapping_place(turned[index].mapping, probe);
            theirs = mapping_place(spun.mapping, probe);
            assert about(ours[0], theirs[0], 0.01) and about(ours[1], theirs[1], 0.01);
        }
    }
    # Mirrored, a box is still a box of its own size.
    mirrored = sides_remapped(sides, pivot, linear_size(Vec3(x=-1.0, y=1.0, z=1.0)));
    assert about(brush_volume(mirrored), 64.0 * 32.0 * 48.0, 0.5);
    bounds = windings_bounds(brush_windings(mirrored));
    assert bounds is not None and near(bounds[0], Vec3(x=-16.0, y=-8.0, z=0.0)) and near(bounds[1], Vec3(x=48.0, y=24.0, z=48.0));
}

test "a box handle's parts lie on the box as it is seen, and a drag of each asks one thing" {
    low = Vec3(x=0.0, y=0.0, z=0.0);
    high = Vec3(x=64.0, y=32.0, z=16.0);
    # Seen from above: x across, y up.
    assert near(box_part(low, high, 0, 1, 4), Vec3(x=32.0, y=16.0, z=8.0));
    assert near(box_part(low, high, 0, 1, 0), Vec3(x=0.0, y=0.0, z=8.0)) and near(box_part(low, high, 0, 1, 8), Vec3(x=64.0, y=32.0, z=8.0));
    assert near(box_part(low, high, 0, 1, 5), Vec3(x=64.0, y=16.0, z=8.0)) and near(box_part(low, high, 0, 1, 7), Vec3(x=32.0, y=32.0, z=8.0));
    # From the front: x across, z up.
    assert near(box_part(low, high, 0, 2, 2), Vec3(x=64.0, y=16.0, z=0.0));
    # The middle moves, in the view's plane only.
    moved = box_drag(low, high, 0, 1, 4, Vec3(x=48.0, y=0.0, z=99.0));
    assert moved.label == "Move" and near(moved.move, Vec3(x=16.0, y=-16.0)) and moved.change.idle() and not moved.idle();
    assert box_drag(low, high, 0, 1, 4, Vec3(x=32.0, y=16.0, z=8.0)).idle();
    # The right edge dragged up its own length slides: the left edge stays, the right goes up sixteen.
    slid = box_drag(low, high, 0, 1, 5, Vec3(x=64.0, y=32.0, z=8.0));
    assert slid.label == "Shear" and near(slid.pivot, Vec3(x=0.0, y=16.0, z=8.0));
    assert near(point_remapped(Vec3(x=64.0, y=0.0), slid.pivot, slid.change), Vec3(x=64.0, y=16.0));
    assert near(point_remapped(Vec3(x=0.0, y=32.0), slid.pivot, slid.change), Vec3(x=0.0, y=32.0));
    # Dragged outward instead it sizes that way alone, from the far edge.
    wider = box_drag(low, high, 0, 1, 5, Vec3(x=96.0, y=18.0, z=8.0));
    assert wider.label == "Stretch" and near(point_remapped(Vec3(x=64.0, y=32.0, z=16.0), wider.pivot, wider.change), Vec3(x=96.0, y=32.0, z=16.0));
    assert near(point_remapped(low, wider.pivot, wider.change), low);
    # Said outright, the same drag shears, or sizes.
    assert box_drag(low, high, 0, 1, 5, Vec3(x=96.0, y=18.0, z=8.0), "shear").label == "Shear";
    assert box_drag(low, high, 0, 1, 5, Vec3(x=64.0, y=32.0, z=8.0), "size").idle();
    # The top edge slides along x and sizes along y.
    top = box_drag(low, high, 0, 1, 7, Vec3(x=48.0, y=32.0, z=8.0));
    assert top.label == "Shear" and near(point_remapped(Vec3(x=0.0, y=32.0), top.pivot, top.change), Vec3(x=16.0, y=32.0));
    # A corner turns and sizes about the middle: taken a quarter of the way round, the box stands on end.
    corner = box_part(low, high, 0, 1, 8);
    round = box_drag(low, high, 0, 1, 8, Vec3(x=16.0, y=48.0, z=8.0));
    assert round.label == "Turn" and near(point_remapped(corner, round.pivot, round.change), Vec3(x=16.0, y=48.0, z=8.0));
    # Twice as far out along its own line, it is twice the size (and as tall again: alike all ways).
    grown = box_drag(low, high, 0, 1, 8, Vec3(x=96.0, y=48.0, z=8.0));
    assert grown.label == "Stretch" and near(point_remapped(corner, grown.pivot, grown.change), Vec3(x=96.0, y=48.0, z=8.0));
    assert near(point_remapped(Vec3(x=32.0, y=16.0, z=16.0), grown.pivot, grown.change), Vec3(x=32.0, y=16.0, z=24.0));
    # Told to turn only, in steps: a little past a quarter is a quarter, and nothing grows.
    stepped = box_drag(low, high, 0, 1, 8, Vec3(x=10.0, y=80.0, z=8.0), "turn", 45.0);
    assert stepped.label == "Turn" and about(stepped.change.volume(), 1.0);
    assert near(point_remapped(corner, stepped.pivot, stepped.change), Vec3(x=16.0, y=48.0, z=8.0));
    # Told to size only, each way goes by itself and the far corner stays.
    sized = box_drag(low, high, 0, 1, 8, Vec3(x=128.0, y=16.0, z=8.0), "size");
    assert sized.label == "Stretch" and near(point_remapped(corner, sized.pivot, sized.change), Vec3(x=128.0, y=16.0, z=8.0));
    assert near(point_remapped(low, sized.pivot, sized.change), low);
    # A box with no size one way gives its corners and edges nothing to hold.
    assert box_drag(low, Vec3(x=64.0, y=0.0, z=16.0), 0, 1, 8, Vec3(x=128.0, y=16.0)).idle();
}

"""A floor, a cube from the origin to (64, 64, 64), and a player start facing +y."""
def room -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=64.0, y=64.0, z=64.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "32 -64 24", "angle": "90"});
    return scene;
}

test "a selection sheared leans as one: its brushes, its entities and the way they face" {
    scene = room();
    wall = scene.solids()[1];
    start = scene.items()[1];
    scene.select_solid(wall);
    scene.select(start, True);
    # Along x across y, half a unit a unit, about the origin.
    assert scene.remap_selection(linear_shear(0, 1, 0.5), Vec3());
    box = wall.bounds();
    assert box is not None and near(box[0], Vec3()) and near(box[1], Vec3(x=96.0, y=64.0, z=64.0));
    assert about(brush_volume(wall.sides), 64.0 * 64.0 * 64.0, 0.5);
    at = start.origin();
    assert at is not None and near(at, Vec3(x=0.0, y=-64.0, z=24.0));
    # Facing +y, it now faces along the lean: a little toward +x.
    assert about(float(start.fields["angle"]), 63.435, 0.01);
    assert scene.undo() == "Shear";
    back = wall.bounds();
    assert back is not None and near(back[1], Vec3(x=64.0, y=64.0, z=64.0)) and start.fields["angle"] == "90";
    assert start.fields["origin"] == "32 -64 24";
    # A change that changes nothing, or flattens the world, is not made.
    assert not scene.remap_selection(Linear(), Vec3()) and not scene.remap_selection(Linear(z=Vec3(x=1.0)), Vec3());
    # A quarter turn, said as a change: the same as the turn the scene already has.
    assert scene.remap_selection(linear_turn(0, 1, 90.0), Vec3(), "Turn");
    turned = wall.bounds();
    assert turned is not None and near(turned[0], Vec3(x=-64.0)) and near(turned[1], Vec3(y=64.0, z=64.0));
    assert start.fields["angle"] == "180" and scene.undo() == "Turn";
    # With nothing selected there is nothing to change.
    scene.clear_selection();
    assert not scene.remap_selection(linear_shear(0, 1, 0.5), Vec3());
}

test "a patch sheared keeps its control points with its brushes, and its material with the lock" {
    scene = room();
    made = patch_points("sheet", Vec3(z=64.0), Vec3(x=128.0, y=128.0, z=64.0));
    patch = scene.make_patch(made[2], made[0], made[1], "tile");
    assert patch is not None;
    scene.clear_selection();
    scene.select(patch);
    prisms = len(scene.solids_of(patch));
    assert scene.remap_selection(linear_shear(2, 0, 0.25), Vec3(z=64.0), "Shear", 8.0);
    control = scene.patch_control(patch);
    assert control is not None and near(control[0], Vec3(z=64.0)) and near(control[2], Vec3(x=128.0, z=96.0));
    assert near(control[8], Vec3(x=128.0, y=128.0, z=96.0)) and len(scene.solids_of(patch)) == prisms;
    # Built again from its points, it is the same sloping sheet.
    assert scene.set_patch(patch, control) is False or len(scene.solids_of(patch)) == prisms;
    # With the lock off the material stays where it lay in the world.
    wall = scene.solids()[1];
    scene.clear_selection();
    scene.select_solid(wall);
    before = [mapping_place(side.mapping, Vec3(x=8.0, y=8.0, z=8.0)) for side in wall.sides];
    assert scene.remap_selection(linear_shear(0, 2, 0.5), Vec3(), "Shear", 8.0, False);
    after = [mapping_place(side.mapping, Vec3(x=8.0, y=8.0, z=8.0)) for side in wall.sides];
    assert before == after;
}
