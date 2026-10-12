import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item, scene_map }
import from editor.geometry.brush { box_sides }

"""A group of one box, by its name."""
def group(scene: Scene, name: str, at: float) -> Item {
    made = scene.add_item({"classname": "func_group", "_group_name": name});
    scene.add_solid(made, box_sides(Vec3(x=at, y=0.0, z=0.0), Vec3(x=at + 32.0, y=32.0, z=32.0), "wall"));
    return made;
}

"""A scene of a house that holds a wall and a roof, a door in the wall, and a shed apart."""
def village -> tuple[Scene, dict[str, Item]] {
    scene = Scene(game="passion", name="studio:village");
    scene.world();
    made: dict[str, Item] = {};
    for (number, name) in enumerate(["house", "wall", "roof", "door", "shed"]) {
        made[name] = group(scene, name, float(number) * 64.0);
    }
    assert scene.nest([made["wall"], made["roof"]], made["house"]) and scene.nest([made["door"]], made["wall"]);
    return (scene, made);
}

test "a group holds groups, and those hold theirs" {
    built = village();
    scene = built[0];
    made = built[1];
    assert scene.nested_in(made["wall"]) is made["house"] and scene.nested_in(made["door"]) is made["wall"];
    assert scene.nested_in(made["house"]) is None and scene.nested_in(made["shed"]) is None;
    held = scene.nested(made["house"]);
    assert len(held) == 2 and made["wall"] in held and made["roof"] in held;
    below = scene.all_nested(made["house"]);
    assert len(below) == 3 and made["door"] in below and made["shed"] not in below;
    assert scene.all_nested(made["door"]) == [] and scene.all_nested(made["shed"]) == [];
    # It is said in the fields, so the map keeps it.
    assert made["house"].fields["_group_id"] == "g1" and made["wall"].fields["_group_in"] == "g1";
    assert made["wall"].fields["_group_id"] == "g2" and made["door"].fields["_group_in"] == "g2";
}

test "a group is picked and let go with what it holds" {
    built = village();
    scene = built[0];
    made = built[1];
    scene.select(made["house"]);
    assert len(scene.selection()) == 4 and not scene.is_selected(made["shed"]);
    # Of a house picked with what it holds, the house is the one thing picked.
    assert scene.tops(scene.selection()) == [made["house"]];
    scene.select(made["wall"]);
    assert len(scene.selection()) == 2 and scene.is_selected(made["door"]) and not scene.is_selected(made["house"]);
    scene.select(made["shed"], True);
    scene.select(made["wall"], True);
    assert len(scene.selection()) == 1 and scene.is_selected(made["shed"]);
}

test "no group is put in itself or in one it holds, and taking out undoes" {
    built = village();
    scene = built[0];
    made = built[1];
    assert not scene.nest([made["house"]], made["house"]) and not scene.nest([made["house"]], made["door"]);
    assert scene.nested_in(made["house"]) is None;
    # Out to the top, and back by undo.
    assert scene.nest([made["door"]], None) and scene.nested_in(made["door"]) is None;
    assert len(scene.all_nested(made["house"])) == 2;
    assert scene.undo() == "Take groups out" and scene.nested_in(made["door"]) is made["wall"];
    # Moved from one to another in one step.
    assert scene.nest([made["door"]], made["shed"]) and scene.nested_in(made["door"]) is made["shed"];
    assert not scene.nest([made["door"]], made["shed"]);
}

test "a copy of a group and what it holds is a group of its own" {
    built = village();
    scene = built[0];
    made = built[1];
    scene.select(made["house"]);
    assert scene.insert_map(scene.selection_map(), Vec3(x=0.0, y=256.0, z=0.0), "Duplicate");
    copies = scene.selection();
    assert len(copies) == 4;
    names: dict[str, Item] = {};
    for each in copies {
        names[each.fields["_group_name"]] = each;
    }
    assert scene.nested_in(names["wall"]) is names["house"] and scene.nested_in(names["door"]) is names["wall"];
    assert names["house"] is not made["house"] and names["house"].fields["_group_id"] != made["house"].fields["_group_id"];
    # The first house holds what it held, and no more.
    assert len(scene.all_nested(made["house"])) == 3 and len(scene.all_nested(names["house"])) == 3;
}

test "what a map says of groups in groups is read back as it was written" {
    built = village();
    scene = built[0];
    written = scene_map(scene);
    again = Scene(game="passion", name="studio:again");
    again.world();
    assert again.insert_map(written[1:], Vec3(), "Open");
    found: dict[str, Item] = {};
    for each in again.items() {
        if each.classname() == "func_group" {
            found[each.fields["_group_name"]] = each;
        }
    }
    assert again.nested_in(found["door"]) is found["wall"] and len(again.all_nested(found["house"])) == 3;
}

test "however a group came to be picked, what it holds is picked with it, and a clone is its own" {
    built = village();
    scene = built[0];
    made = built[1];
    # Picked by a search, which does not go by a click.
    assert scene.select_field("_group_name", "house") == 1 and len(scene.selection()) == 1;
    assert scene.pick_nested() == 3 and len(scene.selection()) == 4 and scene.pick_nested() == 0;
    assert scene.clone_selection(Vec3(x=0.0, y=256.0, z=0.0));
    copies = scene.selection();
    assert len(copies) == 4;
    names: dict[str, Item] = {};
    for each in copies {
        names[each.fields["_group_name"]] = each;
    }
    assert scene.nested_in(names["wall"]) is names["house"] and scene.nested_in(names["door"]) is names["wall"];
    assert len(scene.all_nested(made["house"])) == 3 and len(scene.all_nested(names["house"])) == 3;
    # A group cloned without the group it is in stays in it, beside the first.
    scene.select(made["door"]);
    assert scene.clone_selection(Vec3(x=0.0, y=0.0, z=64.0));
    twin = scene.selection()[0];
    assert scene.nested_in(twin) is made["wall"] and len(scene.nested(made["wall"])) == 2;
}
