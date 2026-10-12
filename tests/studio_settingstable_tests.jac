import from editor.document.settingstable {
    Setting, SUBJECTS, settings_table, read_setting, setting_takes, setting_value, setting_order, colour_parts, colour_words
}

test "every line of the table is a setting under a known subject, each name once" {
    table = settings_table();
    assert len(table) >= 30;
    names: list[str] = [];
    subjects = [key for (key, title) in SUBJECTS];
    for setting in table {
        assert setting.name.startswith("studio_") and setting.name not in names and setting.subject in subjects;
        assert setting.order.count("%") == 1 and setting.order.startswith("ed_") and setting.label and setting.help;
        names.append(setting.name);
    }
    # Every subject has something under it.
    for key in subjects {
        assert len([setting for setting in table if setting.subject == key]) > 0;
    }
}

test "a setting is read out of the settings file's own lines" {
    lines = [
        "// The studio's settings, written when one changes.",
        "ed_grid 16",
        "ed_display wire axis",
        "ed_display textured 3d",
        "ed_grid hide",
        "ed_bar tools show",
        "ed_bar tools below",
        "ed_layout 4b",
        "ed_layout keep wide 4 600 300",
        "ed_mouse look 1.5",
        "ed_colour accent 3fa9f5"
    ];
    values: dict[str, str] = {};
    for setting in settings_table() {
        values[setting.name] = setting_value(lines, setting);
    }
    # Two settings kept by one command are told apart by what they take.
    assert values["studio_grid"] == "16" and values["studio_grid_shown"] == "hide";
    assert values["studio_tools"] == "show" and values["studio_tools_place"] == "below";
    # A value in the middle of its command.
    assert values["studio_view_axis"] == "wire" and values["studio_view_3d"] == "textured";
    # A kept layout is not the layout shown.
    assert values["studio_layout"] == "4b";
    assert values["studio_look"] == "1.5" and values["studio_colour_accent"] == "3fa9f5";
    # What no line sets is not known.
    assert values["studio_theme"] == "" and values["studio_ruler"] == "";
}

test "a setting is set by its command, and refuses what it does not take" {
    by_name: dict[str, Setting] = {};
    for setting in settings_table() {
        by_name[setting.name] = setting;
    }
    assert setting_order(by_name["studio_grid"], " 32 ") == "ed_grid 32";
    assert setting_order(by_name["studio_view_axis"], "textured") == "ed_display textured axis";
    assert setting_order(by_name["studio_theme"], "light") == "ed_theme light";
    assert setting_order(by_name["studio_grid"], "show") == "" and setting_order(by_name["studio_theme"], "pink") == "";
    assert setting_order(by_name["studio_colour_accent"], "ff0000") == "ed_colour accent ff0000";
    # Nothing that would run on as another command.
    assert not setting_takes(by_name["studio_colour_accent"], "ff0000; quit") and not setting_takes(by_name["studio_grid"], "");
}

test "a line that is not a setting reads as none" {
    assert read_setting("studio_x|general|X") is None and read_setting("|general|X|ed_x %") is None;
    assert read_setting("studio_x|general|X|ed_x") is None;
    read = read_setting("studio_x|general|X|ed_x %|#|how many");
    assert read is not None and read.numeric and read.choices == [] and read.help == "how many";
}

test "a colour is six digits, read to its parts and written back" {
    assert colour_parts("ff7a18") == [255, 122, 24] and colour_parts("#FF7A18") == [255, 122, 24];
    assert colour_parts("ff7a1") == [] and colour_parts("gg0000") == [] and colour_parts("default") == [];
    assert colour_words(255, 122, 24) == "ff7a18" and colour_words(300, -4, 0) == "ff0000";
}
