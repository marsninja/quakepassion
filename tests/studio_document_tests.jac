import from engine.formats.bsp { MapEntity, parse_entities, entity_text }
import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item, scene_of, read_vector, write_vector, field_number }

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
