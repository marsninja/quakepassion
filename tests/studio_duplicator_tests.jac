import math;
import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, box_sides, brush_volume, brush_windings, windings_bounds }
import from editor.formats.map { MapItem }
import from editor.document.generate { duplicates, image_brushes, image_sets, with_images, counted_name }

def near(a: float, b: float, slack: float = 0.05) -> bool {
    return abs(a - b) < slack;
}

"""A post 16 square and 64 high, standing with its middle at (64, 0)."""
def post -> list[list[Side]] {
    return [box_sides(Vec3(x=56.0, y=-8.0, z=0.0), Vec3(x=72.0, y=8.0, z=64.0), "wood")];
}

def middle_of(sides: list[Side]) -> Vec3 {
    box = windings_bounds(brush_windings(sides));
    return box[0].add(box[1]).scale(0.5) if box is not None else Vec3();
}

test "each copy can be bigger than the last, and turn about any axis" {
    grown = image_sets({"_copies": "2", "_offset": "32 0 0", "_grow": "2"}, post(), []);
    assert len(grown) == 2 and len(grown[0]) == 1;
    # Twice the size, then four times, about the post's own middle; and a step on each time.
    assert near(brush_volume(grown[0][0]), 16.0 * 16.0 * 64.0 * 8.0, 1.0);
    assert near(brush_volume(grown[1][0]), 16.0 * 16.0 * 64.0 * 64.0, 1.0);
    assert near(middle_of(grown[0][0]).x, 96.0) and near(middle_of(grown[1][0]).x, 128.0);
    # Wider only: a factor an axis.
    wide = image_sets({"_copies": "1", "_grow": "3 1 1"}, post(), []);
    box = windings_bounds(brush_windings(wide[0][0]));
    assert box is not None and near(box[1].x - box[0].x, 48.0) and near(box[1].y - box[0].y, 16.0);
    # A quarter turn about x through the origin lays the post over: up becomes -y... or +y.
    tipped = image_sets({"_copies": "1", "_turn": "90", "_axis": "x", "_pivot": "0 0 0"}, post(), []);
    box = windings_bounds(brush_windings(tipped[0][0]));
    assert box is not None and near(box[1].z - box[0].z, 16.0) and near(abs(box[1].y - box[0].y), 64.0);
    assert near(box[0].x, 56.0);
    # About y the post swings in the x/z plane and stays at y = 0.
    swung = image_sets({"_copies": "3", "_turn": "90", "_axis": "y", "_pivot": "0 0 0"}, post(), []);
    assert len(swung) == 3 and near(middle_of(swung[1][0]).x, -64.0) and near(middle_of(swung[1][0]).y, 0.0);
    # A factor that makes no sense is left out of it.
    assert near(brush_volume(image_sets({"_copies": "1", "_grow": "-2"}, post(), [])[0][0]), 16.0 * 16.0 * 64.0, 1.0);
}

test "symmetry on two or three axes makes every combination of them" {
    assert duplicates({"_mirror": "xy"}) and not duplicates({"_mirror": "sideways"}) and not duplicates({});
    four = image_sets({"_mirror": "xy", "_pivot": "0 0 0"}, [box_sides(Vec3(x=32.0, y=16.0), Vec3(x=48.0, y=32.0, z=8.0), "wood")], []);
    assert len(four) == 3;
    spots = sorted([(round(middle_of(one[0]).x), round(middle_of(one[0]).y)) for one in four]);
    assert spots == [(-40, -24), (-40, 24), (40, -24)];
    eight = image_sets({"_mirror": "xyz", "_pivot": "0 0 0"}, [box_sides(Vec3(x=32.0, y=16.0, z=8.0), Vec3(x=48.0, y=32.0, z=16.0), "wood")], []);
    assert len(eight) == 7;
    # Copies in a row are mirrored with the group.
    row = image_sets({"_copies": "2", "_offset": "0 0 80", "_mirror": "x", "_pivot": "0 0 0"}, post(), []);
    assert len(row) == 5 and near(middle_of(row[4][0]).x, -64.0) and near(middle_of(row[4][0]).z, 192.0);
}

test "an image stands at every entity of a name, facing as it does" {
    spots = [
        MapItem(fields={"classname": "info_notnull", "targetname": "torch", "origin": "0 128 0"}, brushes=[]),
        MapItem(fields={"classname": "info_notnull", "targetname": "torch", "origin": "0 -128 32", "angle": "90"}, brushes=[]),
        MapItem(fields={"classname": "info_notnull", "targetname": "other", "origin": "500 500 0"}, brushes=[])
    ];
    arm = [box_sides(Vec3(x=0.0, y=-4.0, z=0.0), Vec3(x=32.0, y=4.0, z=8.0), "iron")];
    made = image_sets({"_at": "torch", "_pivot": "0 0 0"}, arm, spots);
    assert len(made) == 2;
    first = windings_bounds(brush_windings(made[0][0]));
    second = windings_bounds(brush_windings(made[1][0]));
    assert first is not None and near(first[0].x, 0.0) and near(first[1].x, 32.0) and near(first[0].y, 124.0);
    # The second is turned a quarter: its arm runs along y, from where that entity stands.
    assert second is not None and near(second[1].y - second[0].y, 32.0) and near(second[0].y, -128.0);
    assert near(second[0].z, 32.0);
    assert len(image_sets({"_at": "nothing"}, arm, spots)) == 0 and len(image_brushes({"_at": "torch"}, arm)) == 0;
}

test "images follow the corners of a path, facing along it" {
    path = [
        MapItem(fields={"classname": "path_corner", "targetname": "p1", "target": "p2", "origin": "0 0 0"}, brushes=[]),
        MapItem(fields={"classname": "path_corner", "targetname": "p2", "target": "p3", "origin": "128 0 0"}, brushes=[]),
        MapItem(fields={"classname": "path_corner", "targetname": "p3", "target": "p1", "origin": "128 128 0"}, brushes=[])
    ];
    plank = [box_sides(Vec3(x=-16.0, y=-4.0, z=0.0), Vec3(x=16.0, y=4.0, z=4.0), "wood")];
    made = image_sets({"_path": "p1"}, plank, path);
    # Three corners, and the loop back to the first ends it.
    assert len(made) == 3;
    boxes = [windings_bounds(brush_windings(one[0])) for one in made];
    first = boxes[0];
    second = boxes[1];
    assert first is not None and near(first[1].x - first[0].x, 32.0) and near(middle_of(made[0][0]).x, 0.0);
    # At the second corner the path turns to +y, and so does the plank.
    assert second is not None and near(second[1].y - second[0].y, 32.0) and near(middle_of(made[1][0]).x, 128.0);
    assert near(middle_of(made[2][0]).y, 128.0);
    assert len(image_sets({"_path": "nowhere"}, plank, path)) == 0;
}

test "images take materials in turn" {
    made = image_sets({"_copies": "3", "_offset": "32 0 0", "_materials": "brick stone"}, post(), []);
    assert [one[0][0].material for one in made] == ["brick", "stone", "brick"];
    assert made[0][0][5].material == "brick";
    # The mirror image of each takes that one's.
    both = image_sets({"_copies": "1", "_offset": "32 0 0", "_materials": "brick", "_mirror": "x", "_pivot": "0 0 0"}, post(), []);
    assert [one[0][0].material for one in both] == ["brick", "wood", "brick"];
}

test "a brush entity's images are entities of their own, their names counted up" {
    assert counted_name("door1", 1) == "door2" and counted_name("door", 1) == "door2" and counted_name("a9", 2) == "a11";
    door = MapItem(
        fields={"classname": "func_door", "targetname": "door1", "target": "light1", "_copies": "2", "_offset": "0 96 0", "_each": "1"},
        brushes=post()
    );
    world = MapItem(fields={"classname": "worldspawn"}, brushes=post());
    built = with_images([world, door]);
    assert len(built) == 4 and built[1].fields["targetname"] == "door1";
    assert built[2].fields["targetname"] == "door2" and built[2].fields["target"] == "light2";
    assert built[3].fields["targetname"] == "door3" and "_copies" not in built[3].fields and "_each" not in built[3].fields;
    assert len(built[2].brushes) == 1 and near(middle_of(built[3].brushes[0]).y, 192.0);
    assert built[2].fields["classname"] == "func_door";
    # Without it they are one door of three brushes; a group never becomes entities.
    door.fields.pop("_each", None);
    assert len(with_images([world, door])) == 2 and len(with_images([world, door])[1].brushes) == 3;
    group = MapItem(fields={"classname": "func_group", "_copies": "1", "_offset": "0 96 0", "_each": "1"}, brushes=post());
    assert len(with_images([world, group])) == 2;
}
