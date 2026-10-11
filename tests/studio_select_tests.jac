import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, scene_map, scene_from_map }
import from editor.geometry.brush { box_sides }
import from editor.formats.map { read_map, write_map }

"""A floor, a cube from the origin to (64, 64, 64), a player start and a
light."""
def room -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=64.0, y=64.0, z=64.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "-64 -64 24", "angle": "90"});
    scene.add_item({"classname": "light", "origin": "0 0 96", "light": "300"});
    return scene;
}

test "a selection is kept as a set and picked again" {
    scene = room();
    wall = scene.solids()[1];
    start = scene.items()[1];
    lamp = scene.items()[2];
    assert scene.keep_set("door") == 0 and scene.set_names == [];
    scene.select_solid(wall);
    scene.select(start, True);
    assert scene.keep_set("door") == 2 and scene.set_names == ["door"] and scene.dirty;
    scene.clear_selection();
    assert scene.pick_set("door") == 2;
    assert scene.selection() == [start] and scene.selected_solids() == [wall];
    # Added to what is selected, or alone.
    scene.select(lamp);
    assert scene.pick_set("door", True) == 2 and len(scene.selection()) == 2;
    assert scene.pick_set("door") == 2 and scene.selection() == [start];
    assert scene.pick_set("nothing") == 0 and scene.selection() == [start];
    # Kept again under the same name, a set holds the new selection only.
    scene.select(lamp);
    assert scene.keep_set("door") == 1 and scene.set_names == ["door"];
    assert scene.set_items("door") == [lamp] and scene.set_solids("door") == [];
    assert scene.keep_set("") == 0;
    assert scene.drop_set("door") and not scene.drop_set("door") and scene.set_names == [];
    assert scene.pick_set("door") == 0;
}

test "what is deleted leaves a set, and is back in it when the delete is undone" {
    scene = room();
    start = scene.items()[1];
    lamp = scene.items()[2];
    scene.select(start);
    scene.select(lamp, True);
    assert scene.keep_set("pair") == 2;
    scene.select(lamp);
    assert scene.remove_selection();
    assert scene.set_items("pair") == [start] and scene.pick_set("pair") == 1;
    assert scene.undo() == "Delete";
    assert len(scene.set_items("pair")) == 2;
}

test "sets are written with the map and come back from it" {
    scene = room();
    wall = scene.solids()[1];
    lamp = scene.items()[2];
    scene.select_solid(wall);
    scene.select(lamp, True);
    assert scene.keep_set("lit") == 2;
    scene.select(scene.items()[1]);
    assert scene.keep_set("spawn") == 1;
    assert scene.set_words("lit") == "2 0:1" and scene.set_words("spawn") == "1";
    text = write_map(scene_map(scene));
    assert "\"_set_lit\" \"2 0:1\"" in text and "\"_set_spawn\" \"1\"" in text;
    # The document itself does not carry them as fields.
    assert "_set_lit" not in scene.world().fields;
    again = scene_from_map("passion", "studio:test", read_map(text));
    assert again.set_names == ["lit", "spawn"] and "_set_lit" not in again.world().fields and not again.dirty;
    assert again.pick_set("lit") == 2;
    assert again.selection() == [again.items()[2]] and again.selected_solids() == [again.solids()[1]];
    assert again.pick_set("spawn") == 1 and again.selection()[0].classname() == "info_player_start";
    assert write_map(scene_map(again)) == text;
}

test "the selection steps to its owner, its brushes and its neighbours" {
    scene = room();
    world = scene.world();
    floor = scene.solids()[0];
    wall = scene.solids()[1];
    start = scene.items()[1];
    lamp = scene.items()[2];
    scene.select_solid(wall);
    assert scene.select_kin("next") == 1 and scene.selected_solids() == [floor];
    assert scene.select_kin("prev") == 1 and scene.selected_solids() == [wall];
    assert scene.select_kin("parent") == 1 and scene.selection() == [world] and scene.selected_solids() == [];
    assert scene.select_kin("child") == 2 and len(scene.selected_solids()) == 2 and scene.selection() == [];
    # Two brushes have no one neighbour; an entity without brushes has no child.
    assert scene.select_kin("next") == 0;
    scene.select(start);
    assert scene.select_kin("child") == 0 and scene.select_kin("parent") == 0;
    assert scene.select_kin("next") == 1 and scene.selection() == [lamp];
    assert scene.select_kin("next") == 1 and scene.selection() == [world];
    assert scene.select_kin("prev") == 1 and scene.selection() == [lamp];
    assert scene.select_kin("sideways") == 0;
}

test "a brush is selected by its entity's number and its own" {
    scene = room();
    assert scene.select_numbered(0, 1) and scene.selected_solids() == [scene.solids()[1]];
    assert scene.select_numbered(2) and scene.selection()[0].classname() == "light";
    assert scene.selected_solids() == [];
    assert not scene.select_numbered(0, 2) and not scene.select_numbered(3) and not scene.select_numbered(-1);
}

test "two selected things change places, and change back" {
    scene = room();
    wall = scene.solids()[1];
    start = scene.items()[1];
    scene.select_solid(wall);
    assert not scene.swap_selection();
    scene.select(start, True);
    assert scene.swap_selection();
    box = wall.bounds();
    # The cube's middle was (32, 32, 32); the start stood at (-64, -64, 24).
    assert start.fields["origin"] == "32 32 32";
    assert box is not None and box[0].x == -96.0 and box[1].x == -32.0 and box[0].z == -8.0;
    assert scene.selection() == [start] and scene.selected_solids() == [wall];
    assert scene.undo() == "Swap";
    box = wall.bounds();
    assert box is not None and box[0].x == 0.0 and start.fields["origin"] == "-64 -64 24";
    # Two entities.
    lamp = scene.items()[2];
    scene.select(start);
    scene.select(lamp, True);
    assert scene.swap_selection();
    assert start.fields["origin"] == "0 0 96" and lamp.fields["origin"] == "-64 -64 24";
}
