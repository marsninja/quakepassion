import from editor.classes.registry {
    ClassInfo,
    FieldInfo,
    classes,
    class_info,
    class_names,
    class_family,
    field_of,
    common_field,
    read_field,
    flag_set,
    flag_put,
    read_class,
    add_classes,
    drop_classes,
    CLASS_TABLE
}

test "every line of the table reads as a class" {
    known = classes();
    assert len(known) == len(CLASS_TABLE) and len(known) > 100;
    for (name, found) in known.items() {
        assert name == found.name and found.help , name;
        for entry_field in found.fields {
            # A comma in a field's help would have cut it in two.
            assert " " not in entry_field.name , name + " " + entry_field.name;
            assert entry_field.name and entry_field.kind in [
                "number", "text", "angle", "vector", "color", "link", "name", "choice"
            ] , name + " " + entry_field.name;
            if entry_field.kind == "choice" {
                assert len(entry_field.choices) >= 2 , name + " " + entry_field.name;
            }
        }
    }
}

test "a door is brushes with typed fields, choices and named options" {
    door = class_info("func_door");
    assert door is not None and door.solid and "q2" in door.games;
    speed = door.field("speed");
    assert speed is not None and speed.kind == "number" and speed.preset == "100";
    assert speed.help == "How fast it moves";
    sounds = door.field("sounds");
    assert sounds is not None and sounds.kind == "choice" and len(sounds.choices) == 5;
    assert sounds.choices[1][0] == "1" and sounds.choices[1][1] == "stone";
    assert door.flags[0] == "START_OPEN" and door.flags[1] == "" and door.flags[3] == "GOLD_KEY";
    pause = door.field("wait");
    assert pause is not None and pause.help == "Seconds open (-1 stays open)";
    assert door.field("nothing") is None and class_info("nothing_at_all") is None;
    start = class_info("info_player_start");
    assert start is not None and not start.solid;
}

test "a field is edited by what its class says, else by what it means everywhere" {
    assert field_of("func_door", "angle").kind == "angle";
    assert field_of("func_button", "target").kind == "link";
    assert field_of("light", "_color").kind == "color" and field_of("light", "_color").preset == "1 1 1";
    assert field_of("func_door", "spawnflags").kind == "flags";
    # A class with no named bits edits spawnflags as a number.
    assert field_of("info_player_start", "spawnflags").kind == "number";
    assert field_of("some_mod_thing", "targetname").kind == "name";
    assert field_of("some_mod_thing", "origin").kind == "vector";
    unknown = field_of("some_mod_thing", "wobble");
    assert unknown.kind == "text" and unknown.name == "wobble";
    assert common_field("message").help == "Words shown to the player";
    read = read_field("style:o:0:0=steady;1=flicker");
    assert read.kind == "choice" and len(read.choices) == 2 and read.preset == "0";
}

test "classes list by game and by family" {
    quake = class_names("q1");
    arena = class_names("q3");
    assert "monster_shambler" in quake and "monster_shambler" not in arena;
    assert "weapon_plasmagun" in arena and "weapon_plasmagun" not in quake;
    assert "func_door" in quake and "func_door" in arena;
    # A scene may hold any game's entities.
    assert len(class_names("passion")) == len(class_names()) and len(class_names()) == len(CLASS_TABLE);
    assert quake == sorted(quake);
    assert class_family("monster_army") == "monster" and class_family("light") == "light";
    assert class_family("item_artifact_envirosuit") == "item";
}

test "spawnflags bits are read and written one at a time" {
    assert flag_set("5", 0) and not flag_set("5", 1) and flag_set("5", 2);
    assert not flag_set("", 0) and not flag_set("words", 3);
    assert flag_put("", 3, True) == "8" and flag_put("8", 0, True) == "9";
    assert flag_put("9", 3, False) == "1" and flag_put("1", 0, False) == "0";
    assert flag_put("words", 1, True) == "2";
}

test "an add-on's classes join the table, are replaced when read again, and leave it" {
    before = len(classes());
    taken = add_classes(
        [
            "trap_spikes | point | passion | Spikes that rise | dmg:n:20:What they do, wait:n:2 | start up",
            "trap_pit | brush | passion | A floor that falls away",
            "func_door | brush | q1 | Not the studio's own door",
            "no class at all"
        ]
    );
    # The studio's own door is left as it is; a line that is not a class is passed over.
    assert taken == ["trap_spikes", "trap_pit"] and len(classes()) == before + 2;
    spikes = class_info("trap_spikes");
    assert spikes is not None and not spikes.solid and spikes.flags == ["start up"];
    assert field_of("trap_spikes", "dmg").preset == "20" and field_of("trap_spikes", "dmg").help == "What they do";
    # A field it does not explain means what it does everywhere.
    assert field_of("trap_spikes", "wait").help == common_field("wait").help;
    pit = class_info("trap_pit");
    assert pit is not None and pit.solid and pit.fields == [] and "trap_pit" in class_names("passion");
    door = class_info("func_door");
    assert door is not None and door.help != "Not the studio's own door";
    assert read_class("one | two") is None and read_class("has space | point | q1 | x") is None;
    # Read again with other words, it is replaced, not added twice.
    assert add_classes(["trap_spikes | point | passion | Spikes that fall"]) == ["trap_spikes"];
    again = class_info("trap_spikes");
    assert again is not None and again.help == "Spikes that fall" and len(classes()) == before + 2;
    drop_classes(["trap_spikes", "trap_pit", "func_door"]);
    assert len(classes()) == before and class_info("trap_pit") is None and class_info("func_door") is not None;
}
