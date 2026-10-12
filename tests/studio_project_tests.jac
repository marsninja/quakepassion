import from editor.project {
    Project,
    read_project,
    write_project,
    manifest_words,
    manifest_word,
    file_name,
    addon_classes,
    addon_folders,
    addon_label
}

test "a manifest's words keep what is quoted together" {
    assert manifest_words("name \"The keep\"") == ["name", "The keep"];
    assert manifest_words("  recipe fine \"ed_build full; ed_bake 128\"  ") == ["recipe", "fine", "ed_build full; ed_bake 128"];
    assert manifest_words("material \"\"") == ["material", ""];
    assert manifest_words("") == [];
    assert manifest_word("blockout") == "blockout" and manifest_word("The keep") == "\"The keep\"";
    assert manifest_word("") == "\"\"" and manifest_word("a; b") == "\"a; b\"";
    assert file_name("The keep!") == "The_keep" and file_name("../x") == "x" and file_name(" ") == "";
}

test "a project is read from its manifest and written back the same" {
    text = "// A QuakePassion project.\nname \"The keep\"\ngame q1\nstart yard\nmaterial q1:metal1_1\nbuild quick\nbake 128\n"
        + "scene hall\nscene yard\naddon classes/traps.txt\nrecipe fine \"ed_build full; ed_bake 128\"\n";
    project = read_project(text);
    assert project.name == "The keep" and project.game == "q1" and project.start == "yard";
    assert project.material == "q1:metal1_1" and project.build == "quick" and project.bake == 128;
    assert project.scenes == ["hall", "yard"] and project.addons == ["classes/traps.txt"];
    assert project.recipes["fine"] == "ed_build full; ed_bake 128";
    assert write_project(project) == text;
    # Scenes are written in order whatever order they were added in, so two
    # versions of a manifest compare line by line.
    project.scenes.append("cellar");
    assert "scene cellar\nscene hall\nscene yard\n" in write_project(project);
    assert read_project(write_project(project)).scenes == ["cellar", "hall", "yard"];
}

test "a manifest keeps what it does not understand and refuses what would mislead" {
    project = read_project("name Keep\ngame q9\nbuild fancy\nscene hall\nscene hall\naddon ../secret.txt\ncolour red\n");
    # An unknown game, a build it has no word for and an add-on outside the
    # project are not taken; a scene named twice is there once.
    assert project.game == "passion" and project.build == "" and project.scenes == ["hall"] and project.addons == [];
    assert "colour red" in project.other and "game q9" in project.other;
    written = write_project(project);
    assert "colour red\n" in written and written.startswith("// A QuakePassion project.\nname Keep\ngame passion\n");
    empty = read_project("");
    assert empty.name == "" and empty.scenes == [] and write_project(empty) == "// A QuakePassion project.\nname \"\"\ngame passion\n";
}

test "an add-on's classes are its lines after the word class" {
    text = "// Traps for the keep.\nclass trap_spikes | point | passion | Spikes that rise | dmg:n:20:What they do, wait:n:2 | start up\n"
        + "class trap_pit | brush | passion | A floor that falls away\nclass broken | point\nprefab pit\n";
    found = addon_classes(text);
    assert len(found) == 2 and found[0].startswith("trap_spikes | point") and found[1].startswith("trap_pit | brush");
}

test "an add-on names the folders of textures and prefabs beside its file" {
    text = "// The castle\ntextures castle/tex\nprefabs \"castle/pre/\"\nclass trap_spikes|point|q1|Spikes that fall||\n";
    assert addon_folders(text) == {"textures": "castle/tex", "prefabs": "castle/pre"};
    assert addon_classes(text) == ["trap_spikes|point|q1|Spikes that fall||"];
    # Nothing above the add-on's own file, and nothing from the root.
    assert addon_folders("textures ../other\nprefabs /usr/share") == {};
    assert addon_folders("textures\nsounds noise") == {};
}

test "an add-on's materials and prefabs go by its file's name" {
    assert addon_label("/home/me/addons/Castle Keep.addon") == "castle_keep";
    assert addon_label("traps.txt") == "traps" and addon_label("plain") == "plain" and addon_label("") == "addon";
}
