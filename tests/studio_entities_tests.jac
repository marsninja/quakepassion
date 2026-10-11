import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item }
import from editor.geometry.brush { box_sides }

"""A floor, a button that opens a door, and monsters for some skills only."""
def yard -> Scene {
    scene = Scene(game="q1", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_item({"classname": "info_player_start", "origin": "0 0 24"});
    scene.add_item({"classname": "func_button", "origin": "64 0 32", "target": "door1"});
    scene.add_item({"classname": "func_door", "origin": "96 0 32", "targetname": "door1"});
    scene.add_item({"classname": "monster_ogre", "origin": "0 64 24", "spawnflags": "256"});
    scene.add_item({"classname": "monster_knight", "origin": "0 96 24", "spawnflags": "1792"});
    scene.add_item({"classname": "item_health", "origin": "32 64 24", "spawnflags": "2049"});
    scene.add_item({"classname": "item_armor_body", "origin": "32 96 24", "notfree": "1"});
    return scene;
}

def classes(found: list[Item]) -> list[str] {
    return [item.classname() for item in found];
}

test "a skill or a mode leaves out the entities flagged against it" {
    scene = yard();
    assert classes(scene.spawn_excluded("easy")) == ["monster_ogre", "monster_knight"];
    assert classes(scene.spawn_excluded("normal")) == ["monster_knight"];
    assert classes(scene.spawn_excluded("hard")) == ["monster_knight"];
    assert classes(scene.spawn_excluded("deathmatch")) == ["item_health", "item_armor_body"];
    assert scene.spawn_excluded("all") == [] and scene.spawn_excluded("nightmare") == [];
}

test "the preview hides what a skill leaves out and shows it again for the next" {
    scene = yard();
    ogre = scene.items()[4];
    scene.select(ogre);
    seen = scene.revision;
    hidden = scene.spawn_preview("easy", []);
    assert len(hidden) == 2 and ogre.hidden and scene.hidden_count() == 2 and scene.revision > seen;
    # What is hidden is not left selected, and is out of what is built while editing.
    assert scene.selection() == [] and len(scene.built_map(False)) == len(scene.items()) - 2;
    assert len(scene.built_map(True)) == len(scene.items());
    hidden = scene.spawn_preview("deathmatch", hidden);
    assert len(hidden) == 2 and not ogre.hidden and scene.items()[6].hidden and scene.hidden_count() == 2;
    hidden = scene.spawn_preview("all", hidden);
    assert hidden == [] and scene.hidden_count() == 0;
}

test "part of a field's value is replaced across the selection or every entity" {
    scene = yard();
    button = scene.items()[2];
    door = scene.items()[3];
    scene.select(button);
    assert scene.replace_values("target", "door", "gate") == 1 and button.fields["target"] == "gate1";
    assert door.fields["targetname"] == "door1";
    assert scene.replace_values("target", "door", "gate") == 0;
    assert scene.undo() == "Replace target" and button.fields["target"] == "door1";
    # Everywhere: every origin at height 24 goes to 48.
    assert scene.replace_values("origin", " 24", " 48", True) == 5;
    assert scene.items()[1].fields["origin"] == "0 0 48" and scene.items()[4].fields["origin"] == "0 64 48";
    # A value that would leave an entity nowhere is refused; a class is not renamed this way.
    scene.undo();
    assert scene.replace_values("origin", "0 0 24", "nowhere", True) == 0;
    assert scene.replace_values("classname", "monster", "item", True) == 0;
    assert scene.replace_values("", "a", "b", True) == 0;
}

test "the audit names what waits for a name nothing fires" {
    scene = yard();
    assert scene.audit() == [];
    scene.add_item({"classname": "func_door", "origin": "0 0 0", "targetname": "vault"});
    scene.add_item({"classname": "trigger_relay", "origin": "0 0 0", "targetname": "chain", "target": "chain2"});
    scene.add_item({"classname": "path_corner", "origin": "0 0 0", "targetname": "chain2"});
    found = scene.audit();
    words = [finding.words for finding in found];
    assert len(found) == 2 and "func_door (vault) waits for vault, which nothing fires" in words;
    assert "trigger_relay (chain) waits for chain, which nothing fires" in words;
    assert found[0].item is not None;
}

test "what is pasted keeps its own names apart from the document's" {
    scene = yard();
    button = scene.items()[2];
    door = scene.items()[3];
    scene.select(button);
    scene.select(door, True);
    copied = scene.selection_map();
    assert scene.insert_map(copied, Vec3(x=0.0, y=128.0, z=0.0));
    pasted = scene.selection();
    assert len(pasted) == 2;
    # The copy of the door takes a new name, and the copy of the button fires that.
    assert pasted[1].fields["targetname"] == "door2" and pasted[0].fields["target"] == "door2";
    assert door.fields["targetname"] == "door1" and button.fields["target"] == "door1";
    assert scene.insert_map(copied, Vec3(x=0.0, y=256.0, z=0.0));
    assert scene.selection()[1].fields["targetname"] == "door3" and scene.selection()[0].fields["target"] == "door3";
    # A button pasted alone still fires the door it did: the name is not its own.
    scene.select(button);
    alone = scene.selection_map();
    assert scene.insert_map(alone, Vec3(x=0.0, y=64.0, z=0.0));
    assert scene.selection()[0].fields["target"] == "door1";
    assert scene.undo() == "Paste";
    # And a door pasted alone keeps its name: what opened the first opens both.
    scene.select(door);
    assert scene.insert_map(scene.selection_map(), Vec3(x=0.0, y=-64.0, z=0.0));
    assert scene.selection()[0].fields["targetname"] == "door1";
}
