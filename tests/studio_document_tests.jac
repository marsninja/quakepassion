import from engine.formats.bsp { MapEntity, parse_entities, entity_text }
import from engine.math.vec3 { Vec3 }
import from editor.document.scene {
    Scene,
    Item,
    Solid,
    scene_of,
    scene_map,
    scene_from_map,
    read_vector,
    write_vector,
    field_number,
    side_moved,
    FaceEdit,
    Finding,
    LogicNode
}
import from editor.geometry.brush { box_sides, brush_volume, Plane3, Side }
import from editor.formats.map { read_map, write_map }

glob LUMP: str = "{\n\"classname\" \"worldspawn\"\n\"message\" \"the Slipgate Complex\"\n}\n"
         + "{\n\"classname\" \"info_player_start\"\n\"origin\" \"480 -352 88\"\n\"angle\" \"90\"\n}\n"
         + "{\n\"classname\" \"func_door\"\n\"model\" \"*1\"\n\"targetname\" \"t3\"\n}\n"
         + "{\n\"classname\" \"monster_army\"\n\"origin\" \"0 0 24\"\n}\n"
         + "{\n\"classname\" \"monster_army\"\n\"origin\" \"64 0 24\"\n}\n";

def sample -> Scene {
    return scene_of("q1", "e1m1", parse_entities(LUMP));
}

test "an entity lump round-trips through the document" {
    entities = parse_entities(LUMP);
    assert entity_text(entities) == LUMP;
    scene = sample();
    assert scene.text() == LUMP;
    assert [item.serial for item in scene.items()] == [0, 1, 2, 3, 4];
    assert not scene.dirty and scene.revision == 0;
}

test "items read their class, origin, model and title" {
    scene = sample();
    items = scene.items();
    assert items[1].classname() == "info_player_start";
    at = items[1].origin();
    assert at is not None and at.x == 480.0 and at.y == -352.0 and at.z == 88.0;
    assert items[0].origin() is None and items[0].model() == -1;
    assert items[2].model() == 1 and items[2].title() == "func_door (t3)";
    assert read_vector("1 2") is None and read_vector("a b c") is None;
    assert write_vector(Vec3(x=1.0, y=-2.5, z=0.125)) == "1 -2.5 0.125";
    assert field_number(64.0) == "64" and field_number(63.99999) == "64";
}

test "selection is edges: alone, added, toggled off and cleared" {
    scene = sample();
    items = scene.items();
    scene.select(items[3]);
    assert scene.selection() == [items[3]] and scene.picks == 2;
    scene.select(items[4], add=True);
    assert len(scene.selection()) == 2;
    scene.select(items[3], add=True);
    assert scene.selection() == [items[4]];
    scene.select(items[1]);
    assert scene.selection() == [items[1]];
    scene.select(None);
    assert scene.selection() == [];
    found = scene.find(2);
    assert found is items[2] and scene.find(99) is None;
}

test "setting a field edits every selected item and undoes as one step" {
    scene = sample();
    items = scene.items();
    scene.select(items[3]);
    scene.select(items[4], add=True);
    assert scene.set_field("angle", "180");
    assert items[3].fields["angle"] == "180" and items[4].fields["angle"] == "180";
    assert scene.dirty and scene.revision == 1 and len(scene.journal.done) == 1;
    # Setting the same value again changes nothing and journals nothing.
    assert not scene.set_field("angle", "180");
    assert len(scene.journal.done) == 1;
    assert scene.undo() == "Set angle";
    assert "angle" not in items[3].fields and "angle" not in items[4].fields;
    assert scene.redo() == "Set angle";
    assert items[4].fields["angle"] == "180";
    assert scene.unset_field("angle") and "angle" not in items[3].fields;
    assert scene.undo() == "Remove angle" and items[3].fields["angle"] == "180";
    assert scene.undo() == "Set angle" and scene.undo() == "" and scene.redo() == "Set angle";
}

test "a new edit forgets what was undone" {
    scene = sample();
    scene.select(scene.items()[1]);
    scene.set_field("angle", "0");
    scene.set_field("angle", "45");
    scene.undo();
    assert scene.items()[1].fields["angle"] == "0";
    scene.set_field("angle", "270");
    assert scene.redo() == "" and scene.items()[1].fields["angle"] == "270";
    assert scene.undo() == "Set angle" and scene.undo() == "Set angle";
    assert scene.items()[1].fields["angle"] == "90";
}

test "deleting takes items out of the document and the selection, and undoes" {
    scene = sample();
    items = scene.items();
    scene.select(items[0]);
    scene.select(items[3], add=True);
    assert scene.remove_selection();
    # The world stays; the grunt goes.
    assert [item.serial for item in scene.items()] == [0, 1, 2, 4];
    assert scene.selection() == [items[0]] and scene.find(3) is None;
    assert scene.text().count("monster_army") == 1;
    assert scene.undo() == "Delete";
    assert [item.serial for item in scene.items()] == [0, 1, 2, 3, 4];
    assert scene.text() == LUMP;
}

test "moving shifts origins and leaves entities without one alone" {
    scene = sample();
    items = scene.items();
    scene.select(items[2]);
    assert not scene.shift_selection(Vec3(x=16.0));
    scene.select(items[3], add=True);
    assert scene.shift_selection(Vec3(x=16.0, z=-8.0));
    assert items[3].fields["origin"] == "16 0 16" and "origin" not in items[2].fields;
    scene.undo();
    assert items[3].fields["origin"] == "0 0 24";
}

test "duplicating copies point entities and selects the copies" {
    scene = sample();
    items = scene.items();
    scene.select(items[2]);
    scene.select(items[3], add=True);
    assert scene.clone_selection(Vec3(x=32.0));
    made = scene.selection();
    assert len(made) == 1 and made[0].serial == 5;
    assert made[0].fields == {"classname": "monster_army", "origin": "32 0 24"};
    assert len(scene.items()) == 6;
    assert scene.undo() == "Duplicate" and len(scene.items()) == 5 and scene.selection() == [];
    assert scene.redo() == "Duplicate" and len(scene.items()) == 6;
    # A brush entity alone has nothing to copy.
    scene.select(items[2]);
    assert not scene.clone_selection(Vec3(x=32.0));
}

test "creating adds an entity at a point, selected, and undoes" {
    scene = sample();
    item = scene.create("light", Vec3(x=8.0, y=16.0, z=96.0));
    assert item.fields == {"classname": "light", "origin": "8 16 96"};
    assert scene.selection() == [item] and scene.items()[-1] is item;
    assert scene.text().endswith("{\n\"classname\" \"light\"\n\"origin\" \"8 16 96\"\n}\n");
    assert scene.undo() == "New light" and len(scene.items()) == 5;
}

test "any run of edits undone in full restores the document" {
    scene = sample();
    items = scene.items();
    scene.select(items[3]);
    scene.set_field("health", "200");
    scene.shift_selection(Vec3(y=64.0));
    scene.clone_selection(Vec3(x=16.0));
    scene.set_field("targetname", "squad");
    scene.create("item_health", Vec3());
    scene.select(items[4]);
    scene.remove_selection();
    assert scene.text() != LUMP;
    steps = 0;
    while scene.undo() {
        steps += 1;
    }
    assert steps == 6 and scene.text() == LUMP;
    while scene.redo() {
        steps -= 1;
    }
    assert steps == 0 and scene.text().count("squad") == 1 and scene.text().count("item_health") == 1;
}

test "a field that would leave an entity nowhere or classless is refused" {
    scene = sample();
    items = scene.items();
    scene.select(items[1]);
    assert scene.refuses("origin", "180") == "origin takes three numbers";
    assert not scene.set_field("origin", "180") and not scene.set_field("origin", "a b c");
    assert not scene.set_field("classname", " ") and not scene.set_field("", "x");
    assert not scene.unset_field("classname");
    assert items[1].fields["origin"] == "480 -352 88" and not scene.dirty and len(scene.journal.done) == 0;
    assert scene.refuses("origin", "1 2 3") == "" and scene.set_field("origin", "1 2 3");
}

def close_to(a: float, b: float) -> bool {
    return abs(a - b) < 0.001;
}

"""A document with a floor and a pillar in the world, and a door made of one
brush."""
def built -> Scene {
    scene = Scene(game="passion", name="room");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=-16.0, y=-16.0, z=0.0), Vec3(x=16.0, y=16.0, z=96.0), "pillar"));
    door = scene.add_item({"classname": "func_door", "angle": "90"});
    scene.add_solid(door, box_sides(Vec3(x=64.0, y=-8.0, z=0.0), Vec3(x=128.0, y=8.0, z=96.0), "door"));
    scene.add_item({"classname": "info_player_start", "origin": "0 -96 24"});
    return scene;
}

test "brushes belong to entities and are found by serial" {
    scene = built();
    world = scene.world();
    assert len(scene.solids()) == 3 and len(scene.solids_of(world)) == 2;
    pillar = scene.solids_of(world)[1];
    assert pillar.serial == 2 and scene.find_solid(2) is pillar and scene.find_solid(99) is None;
    assert scene.owner_of(pillar) is world;
    bounds = pillar.bounds();
    assert bounds is not None and close_to(bounds[0].x, -16.0) and close_to(bounds[1].z, 96.0);
    # Entities and brushes share one run of serials.
    assert [item.serial for item in scene.items()] == [0, 3, 5];
    assert scene.world() is world;
}

test "a new brush is journalled, selected and refused when it encloses nothing" {
    scene = built();
    made = scene.create_solid(box_sides(Vec3(), Vec3(x=32.0, y=32.0, z=32.0), "crate"));
    assert made is not None and scene.selected_solids() == [made] and scene.selection() == [];
    assert len(scene.solids()) == 4 and scene.owner_of(made) is scene.world();
    assert scene.undo() == "New brush" and len(scene.solids()) == 3 and scene.selected_solids() == [];
    assert scene.redo() == "New brush" and len(scene.solids()) == 4;
    # Three planes do not enclose a brush, nor does a box turned inside out.
    assert scene.create_solid(box_sides(Vec3(), Vec3(x=32.0, y=32.0, z=32.0))[:3]) is None;
    assert scene.create_solid(box_sides(Vec3(x=32.0), Vec3(x=0.0, y=32.0, z=32.0))) is None;
}

test "moving a brush moves its planes and keeps its material where it lies" {
    scene = built();
    pillar = scene.solids()[1];
    before = pillar.sides[4].mapping.texel(Vec3(x=0.0, y=0.0, z=96.0));
    scene.select_solid(pillar);
    assert scene.shift_selection(Vec3(x=64.0, z=16.0));
    bounds = pillar.bounds();
    assert bounds is not None and close_to(bounds[0].x, 48.0) and close_to(bounds[1].x, 80.0) and close_to(bounds[1].z, 112.0);
    after = pillar.sides[4].mapping.texel(Vec3(x=64.0, y=0.0, z=112.0));
    assert close_to(before[0], after[0]) and close_to(before[1], after[1]);
    assert close_to(brush_volume(pillar.sides), 32.0 * 32.0 * 96.0);
    assert scene.undo() == "Move";
    back = pillar.bounds();
    assert back is not None and close_to(back[0].x, -16.0) and close_to(back[1].z, 96.0);
}

test "an entity made of brushes moves by moving them, once" {
    scene = built();
    door = scene.items()[1];
    slab = scene.solids_of(door)[0];
    scene.select(door);
    scene.select_solid(slab, add=True);
    assert scene.shift_selection(Vec3(y=32.0));
    bounds = slab.bounds();
    assert bounds is not None and close_to(bounds[0].y, 24.0) and close_to(bounds[1].y, 40.0);
    assert "origin" not in door.fields;
}

test "deleting, duplicating and painting brushes undo" {
    scene = built();
    floor = scene.solids()[0];
    pillar = scene.solids()[1];
    scene.select_solid(pillar);
    assert scene.clone_selection(Vec3(x=64.0));
    copies = scene.selected_solids();
    assert len(copies) == 1 and copies[0] is not pillar and len(scene.solids()) == 4;
    copied = copies[0].bounds();
    assert copied is not None and close_to(copied[0].x, 48.0) and scene.owner_of(copies[0]) is scene.world();
    assert scene.paint_selection("q1:e1m1/tech04_1");
    assert [side.material for side in copies[0].sides] == ["q1:e1m1/tech04_1"] * 6;
    assert scene.paint_selection("q1:e1m1/sfloor4_2", side=4);
    assert copies[0].sides[4].material == "q1:e1m1/sfloor4_2" and copies[0].sides[0].material == "q1:e1m1/tech04_1";
    assert not scene.paint_selection("q1:e1m1/sfloor4_2", side=4);
    assert scene.remove_selection() and len(scene.solids()) == 3 and scene.selected_solids() == [];
    scene.select_solid(floor);
    scene.select_solid(pillar, add=True);
    assert scene.remove_selection() and len(scene.solids()) == 1;
    steps = 0;
    while scene.undo() {
        steps += 1;
    }
    assert steps == 5 and len(scene.solids()) == 3 and pillar.sides[0].material == "pillar";
}

test "resizing pushes one side and refuses to turn a brush inside out" {
    scene = built();
    pillar = scene.solids()[1];
    assert scene.push_side(pillar, 4, 32.0);
    bounds = pillar.bounds();
    assert bounds is not None and close_to(bounds[1].z, 128.0) and close_to(bounds[0].z, 0.0);
    assert not scene.push_side(pillar, 4, -200.0);
    assert not scene.push_side(pillar, 9, 8.0) and not scene.push_side(pillar, 4, 0.0);
    assert scene.undo() == "Resize";
    restored = pillar.bounds();
    assert restored is not None and close_to(restored[1].z, 96.0);
}

test "a document with brushes writes as a map and reads back the same" {
    scene = built();
    text = write_map(scene_map(scene));
    assert text.count("// brush") == 3 and "\"classname\" \"func_door\"" in text;
    again = scene_from_map("passion", "room", read_map(text));
    assert len(again.items()) == 3 and len(again.solids()) == 3;
    assert [len(again.solids_of(item)) for item in again.items()] == [2, 1, 0];
    assert write_map(scene_map(again)) == text;
    slab = again.solids_of(again.items()[1])[0];
    assert slab.sides[0].material == "door" and close_to(brush_volume(slab.sides), 64.0 * 16.0 * 96.0);
    # The entity lump is the entities alone.
    assert again.text().count("{") == 3 and "(" not in again.text();
}

test "the document counts changes to what the level is built from" {
    scene = built();
    start = scene.items()[2];
    scene.select(start);
    scene.set_field("angle", "90");
    scene.shift_selection(Vec3(x=16.0));
    assert scene.geometry == 0;
    pillar = scene.solids()[1];
    scene.select_solid(pillar);
    scene.shift_selection(Vec3(x=16.0));
    assert scene.geometry == 1;
    scene.undo();
    assert scene.geometry == 2;
    # Deleting an entity that owns brushes changes the level; one that owns none does not.
    scene.select(scene.items()[1]);
    scene.remove_selection();
    assert scene.geometry == 3;
    scene.select(start);
    scene.remove_selection();
    assert scene.geometry == 3;
}

test "brushes are tied to a new entity and handed back to the world" {
    scene = built();
    world = scene.world();
    pillar = scene.solids()[1];
    scene.select_solid(pillar);
    taker = scene.tie_selection("func_wall");
    assert taker is not None and taker.classname() == "func_wall" and scene.owner_of(pillar) is taker;
    assert len(scene.solids_of(world)) == 1 and len(scene.items()) == 4 and scene.geometry == 1;
    assert scene.undo() == "Tie to func_wall";
    assert scene.owner_of(pillar) is world and len(scene.items()) == 3 and len(scene.solids_of(world)) == 2;
    assert scene.redo() == "Tie to func_wall" and scene.owner_of(pillar) is taker;
    back = scene.tie_selection("");
    assert back is world and scene.owner_of(pillar) is world;
    # Already the world's: nothing to do.
    assert scene.tie_selection("") is None;
}

test "clipping keeps a side or both, and a brush left with nothing goes" {
    scene = built();
    pillar = scene.solids()[1];
    scene.select_solid(pillar);
    # Across the pillar at half height.
    cut = Plane3(normal=Vec3(z=1.0), dist=48.0);
    assert scene.clip_selection(cut, "both");
    halves = scene.selected_solids();
    assert len(halves) == 2 and len(scene.solids()) == 4;
    assert close_to(brush_volume(halves[0].sides) + brush_volume(halves[1].sides), 32.0 * 32.0 * 96.0);
    lower = pillar.bounds();
    assert lower is not None and close_to(lower[1].z, 48.0);
    assert scene.undo() == "Clip" and len(scene.solids()) == 3;
    whole = pillar.bounds();
    assert whole is not None and close_to(whole[1].z, 96.0);
    scene.select_solid(pillar);
    assert scene.clip_selection(cut, "front") and len(scene.solids()) == 3;
    upper = pillar.bounds();
    assert upper is not None and close_to(upper[0].z, 48.0) and close_to(upper[1].z, 96.0);
    # Keeping what is behind a plane the brush is wholly in front of removes it.
    assert scene.clip_selection(Plane3(normal=Vec3(z=1.0), dist=16.0), "back");
    assert len(scene.solids()) == 2 and scene.selected_solids() == [];
    scene.select_solid(scene.solids()[0]);
    # A plane that misses changes nothing.
    assert not scene.clip_selection(Plane3(normal=Vec3(z=1.0), dist=500.0), "both");
}

test "turning swings the selection round its middle and turns what faces" {
    scene = built();
    door = scene.items()[1];
    slab = scene.solids_of(door)[0];
    start = scene.items()[2];
    scene.select_solid(slab);
    assert scene.turn_selection(90.0);
    box = slab.bounds();
    # 64 by 16 about (96, 0) becomes 16 by 64 about it.
    assert box is not None and close_to(box[0].x, 88.0) and close_to(box[1].x, 104.0);
    assert close_to(box[0].y, -32.0) and close_to(box[1].y, 32.0) and close_to(box[1].z, 96.0);
    assert scene.undo() == "Turn";
    scene.select(start);
    scene.select_solid(slab, add=True);
    middle = scene.selection_middle();
    assert middle is not None and close_to(middle.x, 64.0) and close_to(middle.y, -44.0);
    assert scene.turn_selection(180.0);
    # The pivot snaps to the grid at (64, -48): the start swings to the far side and faces back.
    assert start.fields["origin"] == "128 0 24";
    scene.set_field("angle", "90");
    scene.select(start);
    assert scene.turn_selection(-90.0) and start.fields["angle"] == "0";
    scene.clear_selection();
    assert scene.selection_middle() is None and not scene.turn_selection(90.0);
}

def blockout -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=64.0, y=64.0, z=64.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "-64 -64 24", "angle": "90"});
    return scene;
}

test "faces are picked by edges that carry their side" {
    scene = blockout();
    wall = scene.solids()[1];
    floor = scene.solids()[0];
    scene.select_face(wall, 4);
    assert scene.is_face_selected(wall, 4) and not scene.is_face_selected(wall, 3);
    scene.select_face(wall, 2, True);
    scene.select_face(floor, 4, True);
    assert scene.face_sides(wall) == [2, 4] and scene.face_sides(floor) == [4];
    assert len(scene.faces()) == 3;
    # Picked again while adding, a face is dropped.
    scene.select_face(wall, 2, True);
    assert scene.face_sides(wall) == [4];
    # A face picked alone replaces everything selected; selecting a brush drops the faces.
    scene.select_solid(floor, True);
    scene.select_face(floor, 0);
    assert len(scene.faces()) == 1 and not scene.selected_solids();
    scene.select_solid(wall);
    assert len(scene.faces()) == 0;
    scene.select_face(wall, 9);
    assert len(scene.faces()) == 0;
}

test "a face edit touches the picked faces, or every side of a picked brush" {
    scene = blockout();
    wall = scene.solids()[1];
    scene.select_face(wall, 4);
    assert scene.reface(FaceEdit(how="material", material="trim"), "Set material");
    assert [side.material for side in wall.sides] == ["wall", "wall", "wall", "wall", "trim", "wall"];
    assert not scene.reface(FaceEdit(how="material", material="trim"), "Set material");
    assert scene.reface(FaceEdit(how="shift", s=16.0, t=8.0), "Slide");
    assert wall.sides[4].mapping.s_shift == 16.0 and wall.sides[3].mapping.s_shift == 0.0;
    assert scene.reface(FaceEdit(how="fit", sizes={"trim": [32, 32]}), "Fit");
    assert abs(wall.sides[4].mapping.s_scale - 2.0) < 0.001;
    scene.select_solid(wall);
    assert scene.reface(FaceEdit(how="scale", s=0.5, t=0.5), "Scale");
    assert [side.mapping.s_scale for side in wall.sides] == [0.5] * 6;
    assert scene.reface(FaceEdit(how="turn", s=45.0), "Turn");
    assert abs(wall.sides[0].mapping.rotation - 45.0) < 0.001;
    assert scene.reface(FaceEdit(how="reset"), "Reset");
    assert wall.sides[0].mapping.s_scale == 1.0 and wall.sides[0].mapping.rotation == 0.0;
    for i in range(6) {
        scene.undo();
    }
    assert [side.material for side in wall.sides] == ["wall"] * 6 and wall.sides[4].mapping.s_shift == 0.0;
}

test "a picked face is forgotten when its brush loses that side" {
    scene = blockout();
    wall = scene.solids()[1];
    scene.select_face(wall, 5);
    assert scene.reshape(wall, wall.sides[:5] + [wall.sides[5]], "Same");
    assert scene.face_sides(wall) == [5];
    wedge = [wall.sides[1], wall.sides[2], wall.sides[3], wall.sides[5], Side(
        plane=Plane3(normal=Vec3(x=1.0, z=1.0).normalized(), dist=Vec3(x=1.0, z=1.0).normalized().dot(Vec3(x=64.0))),
        material="wall"
    )];
    assert scene.reshape(wall, wedge, "Wedge");
    assert len(scene.faces()) == 0;
}

test "everything, the rest, and every brush of a material can be selected" {
    scene = blockout();
    assert scene.select_all() == 3;
    assert len(scene.selected_solids()) == 2 and len(scene.selection()) == 1;
    assert scene.select_all("brushes") == 2 and not scene.selection();
    assert scene.select_all("entities") == 1 and not scene.selected_solids();
    scene.select_solid(scene.solids()[0]);
    assert scene.invert_selection() == 2;
    assert scene.selected_solids() == [scene.solids()[1]] and len(scene.selection()) == 1;
    assert scene.select_material("floor") == 1 and scene.selected_solids() == [scene.solids()[0]];
    assert scene.select_material("nothing") == 0;
}

test "mirroring and stretching the selection undo" {
    scene = blockout();
    wall = scene.solids()[1];
    start = scene.items()[1];
    scene.select_solid(wall);
    scene.select(start, True);
    # The two span x -64..64, so the mirror is about x = 0.
    assert scene.stretch_selection(Vec3(x=-1.0, y=1.0, z=1.0), 8.0, "Mirror");
    box = wall.bounds();
    assert box is not None and box[0].x == -64.0 and box[1].x == 0.0;
    assert start.fields["origin"] == "64 -64 24" and start.fields["angle"] == "90";
    assert scene.stretch_selection(Vec3(x=1.0, y=-1.0, z=1.0), 8.0, "Mirror");
    assert start.fields["angle"] == "270";
    scene.undo();
    scene.undo();
    box = wall.bounds();
    assert box is not None and box[0].x == 0.0 and start.fields["origin"] == "-64 -64 24";
    scene.select_solid(wall);
    assert scene.stretch_selection(Vec3(x=2.0, y=1.0, z=0.5));
    box = wall.bounds();
    assert box is not None and box[1].x - box[0].x == 128.0 and box[1].z - box[0].z == 32.0;
    assert not scene.stretch_selection(Vec3(x=1.0, y=1.0, z=1.0));
    assert not scene.stretch_selection(Vec3(x=0.0, y=1.0, z=1.0));
}

test "the selection turns about the x and y axes too" {
    scene = blockout();
    wall = scene.solids()[1];
    scene.select_solid(wall);
    assert scene.push_side(wall, 4, 64.0);
    assert scene.turn_selection(90.0, 8.0, 0);
    box = wall.bounds();
    # A 64 x 64 x 128 pillar laid on its side along y.
    assert box is not None and abs((box[1].y - box[0].y) - 128.0) < 0.01 and abs((box[1].z - box[0].z) - 64.0) < 0.01;
    scene.undo();
    box = wall.bounds();
    assert box is not None and abs((box[1].z - box[0].z) - 128.0) < 0.01;
}

test "carving cuts the selection out of every other brush and undoes as one step" {
    scene = blockout();
    floor = scene.solids()[0];
    cutter = scene.create_solid(box_sides(Vec3(x=-32.0, y=-32.0, z=-32.0), Vec3(x=32.0, y=32.0, z=32.0), "trim"));
    assert cutter is not None;
    before = len(scene.solids());
    assert scene.carve_selection() > 0;
    # The floor is four pieces round the hole and the wall has lost a corner.
    assert len(scene.solids()) > before;
    total = 0.0;
    for solid in scene.solids() {
        if solid is not cutter {
            total += brush_volume(solid.sides);
        }
    }
    whole = 256.0 * 256.0 * 16.0 + 64.0 * 64.0 * 64.0;
    assert abs(total - (whole - 64.0 * 64.0 * 16.0 - 32.0 * 32.0 * 32.0)) < 1.0;
    assert scene.undo() == "Carve";
    assert len(scene.solids()) == before and abs(brush_volume(floor.sides) - 256.0 * 256.0 * 16.0) < 0.01;
    # With nothing selected, or nothing reached, nothing is carved.
    scene.select_solid(None);
    assert scene.carve_selection() == 0;
}

test "intersecting, hollowing and merging replace the selection and undo" {
    scene = blockout();
    wall = scene.solids()[1];
    other = scene.create_solid(box_sides(Vec3(x=32.0, y=32.0, z=32.0), Vec3(x=96.0, y=96.0, z=96.0), "trim"));
    assert other is not None;
    scene.select_solid(wall, True);
    assert scene.intersect_selection();
    assert len(scene.solids()) == 2;
    kept = scene.selected_solids();
    assert len(kept) == 1 and abs(brush_volume(kept[0].sides) - 32.0 * 32.0 * 32.0) < 0.01;
    scene.undo();
    assert len(scene.solids()) == 3;
    scene.select_solid(wall);
    assert scene.hollow_selection(8.0);
    assert len(scene.solids()) == 8 and len(scene.selected_solids()) == 6;
    assert not scene.hollow_selection(64.0);
    scene.undo();
    assert len(scene.solids()) == 3 and abs(brush_volume(wall.sides) - 64.0 * 64.0 * 64.0) < 0.01;
    # Cut in two, a wall merges back; with the floor it does not.
    scene.select_solid(wall);
    assert scene.clip_selection(Plane3(normal=Vec3(x=1.0), dist=32.0), "both");
    assert len(scene.selected_solids()) == 2;
    assert scene.merge_selection();
    assert len(scene.selected_solids()) == 1 and abs(brush_volume(scene.selected_solids()[0].sides) - 64.0 * 64.0 * 64.0) < 0.01;
    scene.select_solid(scene.solids()[0], True);
    assert not scene.merge_selection();
}

test "moving a corner reshapes a brush and refuses a corner it has not got" {
    scene = blockout();
    wall = scene.solids()[1];
    assert scene.move_corners(wall, [Vec3(x=64.0, y=64.0, z=64.0)], Vec3(z=32.0));
    box = wall.bounds();
    assert box is not None and box[1].z == 96.0;
    assert not scene.move_corners(wall, [Vec3(x=1.0, y=2.0, z=3.0)], Vec3(z=32.0));
    assert not scene.move_corners(wall, [Vec3(x=64.0, y=64.0, z=96.0)], Vec3());
    assert scene.undo() == "Move corner";
    box = wall.bounds();
    assert box is not None and box[1].z == 64.0;
}

test "the document reports what would stop it playing" {
    scene = blockout();
    assert len(scene.problems()) == 0;
    scene.add_item({"classname": "func_button", "target": "door9", "origin": "x y"});
    scene.add_item({"classname": "trigger_once"});
    scene.add_solid(scene.world(), box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=0.5), "wall"));
    words = [finding.words for finding in scene.problems()];
    assert "func_button has a target nothing is named: door9" in words;
    assert "func_button has an origin that is not three numbers" in words;
    assert "trigger_once has no brushes" in words;
    assert len([word for word in words if "thinner than a unit" in word]) == 1;
    assert len([word for word in words if "off the unit grid" in word]) == 1;
    assert len([finding for finding in scene.problems() if finding.grave]) == 1;
    empty = Scene(game="passion", name="studio:empty");
    grave = [finding.words for finding in empty.problems() if finding.grave];
    assert grave == ["There is no worldspawn", "There is no player start"];
}

def wired -> Scene {
    scene = Scene(game="q1", name="wired");
    scene.add_item({"classname": "worldspawn"});
    scene.add_item({"classname": "info_player_start", "origin": "0 0 24"});
    scene.add_item({"classname": "func_button", "target": "relay", "origin": "0 64 24"});
    scene.add_item({"classname": "trigger_relay", "targetname": "relay", "target": "door", "origin": "0 128 24"});
    scene.add_item({"classname": "func_door", "targetname": "door", "origin": "0 192 24"});
    scene.add_item({"classname": "func_door", "targetname": "door", "origin": "64 192 24"});
    scene.add_item({"classname": "light", "origin": "0 0 96"});
    return scene;
}

test "targets are edges between entities, redrawn when the fields change" {
    scene = wired();
    items = scene.items();
    button = items[2];
    relay = items[3];
    assert scene.fires(button) == [relay] and scene.fired_by(relay) == [button];
    assert len(scene.fires(relay)) == 2 and len(scene.fired_by(items[4])) == 1;
    assert len(scene.fires(items[6])) == 0 and len(scene.fires(items[4])) == 0;
    # Everything the button sets off, through the relay.
    assert len(scene.reach(button)) == 3 and button not in scene.reach(button);
    scene.select(relay);
    assert scene.set_field("target", "nothing");
    assert len(scene.fires(relay)) == 0 and len(scene.reach(button)) == 1;
    scene.undo();
    assert len(scene.fires(relay)) == 2;
    scene.select(items[5]);
    assert scene.remove_selection();
    assert len(scene.fires(relay)) == 1;
}

test "linking names what is fired and aims what fires; unlinking clears the aim" {
    scene = wired();
    items = scene.items();
    light = items[6];
    button = items[2];
    assert scene.link(light, items[1]);
    assert items[1].fields["targetname"] == "t1" and light.fields["target"] == "t1";
    assert scene.fires(light) == [items[1]];
    assert scene.undo() == "Link";
    assert "targetname" not in items[1].fields and "target" not in light.fields;
    # Aiming at something already named only changes the aim.
    assert scene.link(button, items[4]);
    assert button.fields["target"] == "door" and len(scene.fires(button)) == 2;
    assert not scene.link(button, items[4]) and not scene.link(button, button);
    assert scene.unlink(button, items[4]);
    assert "target" not in button.fields and len(scene.fires(button)) == 0;
    assert not scene.unlink(button);
    assert scene.fresh_name() == "t1" and scene.fresh_name("door") == "door1";
}

test "the logic graph puts each entity a column past what fires it" {
    scene = wired();
    placed = scene.logic_nodes();
    assert len(placed) == 4;
    columns: dict[str, int] = {};
    for node in placed {
        columns[node.item.classname() + str(node.row)] = node.column;
    }
    assert columns["func_button0"] == 0 and columns["trigger_relay0"] == 1;
    assert columns["func_door0"] == 2 and columns["func_door1"] == 2;
    assert len(scene.loops()) == 0;
    # A door that fires the button closes a loop: every entity on it is found, and the check says so.
    scene.select(scene.items()[4]);
    assert scene.set_field("target", "press");
    scene.select(scene.items()[2]);
    assert scene.set_field("targetname", "press");
    assert len(scene.loops()) == 3;
    assert len(scene.logic_nodes()) == 4;
    words = [finding.words for finding in scene.problems()];
    assert "func_button (press) sets itself off through what it fires" in words;
}

test "the selection is copied as a map and pasted back moved" {
    scene = blockout();
    wall = scene.solids()[1];
    start = scene.items()[1];
    scene.select_solid(wall);
    scene.select(start, True);
    copied = scene.selection_map();
    assert len(copied) == 2 and copied[0].fields["classname"] == "worldspawn" and len(copied[0].brushes) == 1;
    assert copied[1].fields["classname"] == "info_player_start";
    # Through the map format, as the clipboard carries it.
    text = write_map(copied);
    assert scene.insert_map(read_map(text).items, Vec3(x=128.0, y=0.0, z=0.0));
    assert len(scene.solids()) == 3 and len(scene.items()) == 3;
    pasted = scene.selected_solids();
    assert len(pasted) == 1 and pasted[0] is not wall;
    box = pasted[0].bounds();
    assert box is not None and box[0].x == 128.0 and box[1].x == 192.0;
    assert scene.selection()[0].fields["origin"] == "64 -64 24";
    # An entity that came first in the text does not keep the file's version line.
    assert scene.insert_map(read_map(write_map(copied[1:])).items, Vec3());
    assert "mapversion" not in scene.selection()[0].fields;
    scene.undo();
    assert scene.undo() == "Paste";
    assert len(scene.solids()) == 2 and len(scene.items()) == 2;
    # As a group: the world's brushes come in under a func_group of their own.
    assert scene.insert_map(copied, Vec3(z=64.0), "Insert", "crate");
    groups = [item for item in scene.items() if item.classname() == "func_group"];
    assert len(groups) == 1 and groups[0].fields["_group_name"] == "crate" and len(scene.solids_of(groups[0])) == 1;
    assert scene.is_selected(groups[0]) and not scene.selected_solids();
    assert not scene.insert_map([], Vec3());
}

test "brushes are grouped, and a group or a brush entity duplicates with its brushes" {
    scene = blockout();
    scene.select_all("brushes");
    group = scene.group_selection("yard");
    assert group is not None and group.classname() == "func_group" and len(scene.solids_of(group)) == 2;
    assert len(scene.solids_of(scene.world())) == 0 and scene.selection() == [group];
    assert scene.clone_selection(Vec3(x=512.0));
    assert len(scene.solids()) == 4;
    twin = scene.selection()[0];
    assert twin is not group and twin.fields["_group_name"] == "yard" and len(scene.solids_of(twin)) == 2;
    box = scene.solids_of(twin)[1].bounds();
    assert box is not None and box[0].x == 512.0;
    scene.undo();
    assert len(scene.solids()) == 2;
    scene.undo();
    assert len(scene.solids_of(scene.world())) == 2;
    scene.select(None);
    assert scene.group_selection("none") is None;
}
