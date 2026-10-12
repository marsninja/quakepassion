import from editor.document.shelves { ShelfRow, shelf_name, shelf_moved, shelf_rows, folders_and_files }
import from editor.assets.needs { file_field, field_choices, sound_file }

test "a name with folders is kept inside its shelf" {
    assert shelf_name("props/crate") == "props/crate" and shelf_name("  crate ") == "crate";
    assert shelf_name("../../etc/passwd") == "etc/passwd" and shelf_name("/props//lamps/./tall") == "props/lamps/tall";
    assert shelf_name("props\\crate") == "props/crate" and shelf_name("..") == "" and shelf_name("") == "";
    assert shelf_moved("props/crate", "doors") == "doors/crate" and shelf_moved("crate", "props/wood") == "props/wood/crate";
    assert shelf_moved("props/crate", "") == "crate" and shelf_moved("", "props") == "";
}

test "a shelf lists its folders as headings, shut until opened, and then its files" {
    names = ["gate", "props/crate", "props/lamps/tall", "props/lamps/wall", "doors/iron", "arch"];
    assert folders_and_files(names, "") == (["doors", "props"], ["arch", "gate"]);
    shut = shelf_rows(names, "prefab:", "prefabdir:", {});
    said = [(row.key, row.depth, row.folder, row.count) for row in shut];
    assert said == [
        ("prefabdir:doors", 1, True, 1), ("prefabdir:props", 1, True, 3), ("prefab:arch", 1, False, 0), ("prefab:gate", 1, False, 0)
    ] , str(said);
    # One folder open: what is in it under it, its own folder still shut.
    part = shelf_rows(names, "prefab:", "prefabdir:", {"prefabdir:props": True});
    assert [row.key for row in part] == [
        "prefabdir:doors", "prefabdir:props", "prefabdir:props/lamps", "prefab:props/crate", "prefab:arch", "prefab:gate"
    ];
    assert [row.depth for row in part] == [1, 1, 2, 2, 1, 1] and part[1].opened and not part[2].opened and part[2].count == 2;
    assert part[2].text == "lamps" and part[3].text == "crate";
    # All open.
    whole = shelf_rows(names, "prefab:", "prefabdir:", {"prefabdir:props": True, "prefabdir:props/lamps": True, "prefabdir:doors": True});
    assert [row.key for row in whole] == [
        "prefabdir:doors", "prefab:doors/iron", "prefabdir:props", "prefabdir:props/lamps", "prefab:props/lamps/tall",
        "prefab:props/lamps/wall", "prefab:props/crate", "prefab:arch", "prefab:gate"
    ];
    assert [row.depth for row in whole][3:6] == [2, 3, 3];
    assert shelf_rows([], "prefab:", "prefabdir:", {}) == [];
}

test "a field that names a file can be given any of its game's files of that kind" {
    assert file_field("noise") == "sound" and file_field("music") == "sound" and file_field("model2") == "model";
    assert file_field("target") == "" and file_field("") == "";
    names = ["sound/misc/talk.wav", "sound/doors/drclos4.wav", "progs/player.mdl", "maps/e1m1.bsp", "gfx/conback.lmp", "music/track.wav"];
    # Quake names a sound from sound/ on; what is not under sound/ is not one of its sounds.
    quake = field_choices("q1", "sound", names);
    assert quake == ["doors/drclos4.wav", "misc/talk.wav"] and all([sound_file("q1", value) in names for value in quake]);
    assert field_choices("q3", "sound", names) == ["music/track.wav", "sound/doors/drclos4.wav", "sound/misc/talk.wav"];
    assert field_choices("q1", "model", names + ["models/lamp.MD3", "sprites/s_light.spr"]) == [
        "models/lamp.MD3", "progs/player.mdl", "sprites/s_light.spr"
    ];
    assert field_choices("q1", "other", names) == [] and field_choices("q1", "sound", []) == [];
}
