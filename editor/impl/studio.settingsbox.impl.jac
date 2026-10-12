"""The studio's settings by subject in a box, each also a console variable,
and colours of the studio's own set by hand. Declarations live in
studio.jac."""

"""A number without a needless fraction."""
def:priv plain_number(value: float) -> str {
    return str(int(value)) if value == float(int(value)) else str(round(value, 2));
}

impl Studio.setting_lines_all -> list[str] {
    # What is not kept in the settings file first, so that a kept line has
    # the last word.
    lines: list[str] = [
        "ed_colour accent default",
        "ed_colour select default",
        "ed_colour text default",
        "ed_colour panel default",
        "ed_model backs " + ("on" if self.model_backs else "off"),
        "ed_model ticks " + plain_number(self.model_ticks),
        "ed_model marks " + self.model_marks,
        "ed_model shade " + self.model_shade,
        "ed_model about " + self.model_about,
        "ed_model layout " + ("4" if _model_split.four else "1")
    ];
    for line in self.settings_lines() {
        lines.append(line);
    }
    return lines;
}

impl Studio.apply_inks {
    theme = light_theme() if self.theme_name == "light" else Theme();
    for (which, words) in self.user_inks.items() {
        parts = colour_parts(words);
        if len(parts) != 3 {
            continue;
        }
        made = Ink(r=parts[0], g=parts[1], b=parts[2], a=255);
        if which == "accent" {
            theme.accent = made;
        } elif which == "select" {
            theme.select = made;
        } elif which == "text" {
            theme.text = made;
        } elif which == "panel" {
            theme.panel = made;
        }
    }
    self.canvas.theme = theme;
}

impl Studio.watch_settings {
    app = self.app;
    if app is None or not self.settings_read {
        return;
    }
    if len(self.setting_table) == 0 {
        self.setting_table = settings_table();
    }
    # What was set from the console is seen to first: setting the studio
    # below would put every variable back to what was so before it.
    for setting in self.setting_table {
        if setting.name not in self.setting_cvars {
            continue;
        }
        held = self.setting_cvars[setting.name];
        if not held.modified {
            continue;
        }
        # Set from the console or a config: the studio is set to match, by
        # the command that sets it, or the variable is put back.
        held.modified = False;
        was = self.setting_values.get(setting.name, "");
        if held.text == was {
            continue;
        }
        order = setting_order(setting, held.text);
        if not order {
            self.say(
                setting.name + " takes " + (
                    "one of: " + ", ".join(setting.choices) if len(setting.choices) > 0
                    else ("a number" if setting.numeric else "words without quotation marks")
                )
            );
            held.assign(was);
            held.modified = False;
            continue;
        }
        print("studio: var " + setting.name + " " + held.text + " -> " + order);
        self.command(order.split());
        # Whatever the command made of it is what the variable says next.
        self.settings_mark = "";
    }
    mark = str(self.settings_rev) + "|" + ("1" if self.model_backs else "0") + "|" + plain_number(self.model_ticks) + "|"
        + self.model_marks + "|" + self.model_shade + "|" + self.model_about + "|" + str(self.line_width) + "|"
        + ("4" if _model_split.four else "1");
    if mark != self.settings_mark {
        # Something was set: every console variable says what is so now.
        self.settings_mark = mark;
        lines = self.setting_lines_all();
        for setting in self.setting_table {
            value = setting_value(lines, setting);
            self.setting_values[setting.name] = value;
            said = app.shell.set_cvar(setting.name, value);
            if said is not None {
                said.description = setting.help;
                said.modified = False;
                self.setting_cvars[setting.name] = said;
            }
        }
    }
}

impl Studio.keep_settings_box {
    casing = self.settings_box;
    stage = self.stage;
    if casing is None or stage is None {
        return;
    }
    words = self.settings_subject + "|" + self.settings_mark + "|" + self.theme_name;
    if words == self.settings_for or not self.settings_mark or stage.input.down[0] {
        return;
    }
    self.settings_for = words;
    casing.clear();
    form = Box(across=True, pad=8, gap=10, fill="panel");
    casing.adopt(form);
    subjects = Box(gap=3, size=104);
    form.adopt(subjects);
    title = "";
    for (key, called) in SUBJECTS {
        subjects.adopt(
            PushButton(
                text=called, command="ed_settings box " + key, lit=key == self.settings_subject, hint="The settings to do with " + called.lower()
            )
        );
        if key == self.settings_subject {
            title = called;
        }
    }
    sheet = Box(gap=4, grow=1);
    form.adopt(sheet);
    sheet.adopt(Label(text=title, tone="accent"));
    theme = self.canvas.theme;
    for setting in self.setting_table {
        if setting.subject != self.settings_subject {
            continue;
        }
        value = self.setting_values.get(setting.name, "");
        row = Box(across=True, gap=6);
        sheet.adopt(row);
        told = setting.help + " | In the console: " + setting.name;
        row.adopt(Label(text=setting.label, tone="dim", size=210, hint=told));
        if len(setting.choices) > 0 {
            row.adopt(
                Dropdown(
                    text=value,
                    labels=setting.choices,
                    commands=[setting_order(setting, choice) for choice in setting.choices],
                    grow=1,
                    hint=told
                )
            );
        } else {
            row.adopt(
                TextField(value=value, command=setting.order.split("%")[0].strip(), grow=1, hint=told + " | Enter sets it")
            );
        }
        if setting.name.startswith("studio_colour_") {
            shown = theme.accent;
            if setting.name.endswith("_select") {
                shown = theme.select;
            } elif setting.name.endswith("_text") {
                shown = theme.text;
            } elif setting.name.endswith("_panel") {
                shown = theme.panel;
            }
            row.adopt(Swatch(red=float(shown.r) / 255.0, green=float(shown.g) / 255.0, blue=float(shown.b) / 255.0, size=22));
        }
        row.adopt(Label(text=setting.name, tone="faint", small=True, size=138));
    }
    if self.settings_subject == "files" {
        sheet.adopt(Spacer(size=4));
        for (what, folder) in [
            ("Settings", self.settings_path()),
            ("Scenes", os.path.dirname(self.scene_path("x"))),
            ("Autosaves", os.path.dirname(self.autosave_path("x"))),
            ("Project", self.project_folder if self.project_folder else "(none is open)")
        ] {
            row = Box(across=True, gap=6);
            sheet.adopt(row);
            row.adopt(Label(text=what, tone="dim", size=210));
            # A long path is shown by its end, which is what tells them apart.
            row.adopt(
                Label(text=folder if len(folder) <= 60 else "..." + folder[len(folder) - 57:], tone="faint", small=True, hint=folder)
            );
        }
        # Where each game's files are looked for: set here, they are kept
        # beside the settings and the engine starts with them.
        sheet.adopt(Spacer(size=4));
        sheet.adopt(Label(text="Game files (a folder and Enter; nothing gives it up)", tone="dim", small=True));
        for (called, game) in [("Every game is under", "passion"), ("Quake", "q1"), ("Quake II", "q2"), ("Quake III Arena", "q3")] {
            pack = shelf().find(game);
            row = Box(across=True, gap=6);
            sheet.adopt(row);
            row.adopt(Label(text=called, tone="dim", size=210));
            row.adopt(
                TextField(
                    value=game_directory("passion") if pack is None else pack_folder(pack),
                    command="ed_game " + game + " dir",
                    grow=1,
                    hint="ed_game " + game + " dir <folder>"
                )
            );
            there = os.path.isdir(game_directory("passion") if pack is None else pack_folder(pack));
            row.adopt(Label(text="found" if there else "not there", tone="faint" if there else "warn", small=True, size=64));
        }
        sheet.adopt(PushButton(text="Programs kept for files...", command="ed_assoc", hint="Which program opens each kind of file outside the studio"));
    } elif self.settings_subject == "colours" {
        sheet.adopt(Spacer(size=4));
        sheet.adopt(PushButton(text="The theme's own colours", command="ed_colour all default", hint="Give up every colour set by hand"));
    }
    sheet.adopt(Spacer(grow=1));
    sheet.adopt(
        Label(text="Each is a console variable too: its name and a value in the console set it.", tone="faint", small=True)
    );
}

impl Studio.settings_box_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    if name == "ed_colour" {
        which = how;
        words = args[2].lower() if len(args) > 2 else "";
        known = ["accent", "select", "text", "panel"];
        if which == "all" and words == "default" {
            self.user_inks = {};
        } elif which in known and words == "default" {
            self.user_inks.pop(which, None);
        } elif which in known and len(colour_parts(words)) == 3 {
            self.user_inks[which] = words.lstrip("#");
        } else {
            self.say("ed_colour <accent|select|text|panel|all> <rrggbb|default>: one of the studio's colours, as six digits");
            return True;
        }
        self.apply_inks();
        self.keep_settings();
        said = [each + " " + self.user_inks[each] for each in known if each in self.user_inks];
        print("studio: colours " + (" ".join(said) if said else "the theme's own"));
        self.say("Colours set by hand: " + ", ".join(said) if said else "The studio is in its theme's own colours");
        return True;
    }
    if name != "ed_settings" or how not in ["box", "vars"] {
        return False;
    }
    self.watch_settings();
    if how == "vars" {
        wanted = args[2] if len(args) > 2 else "";
        for setting in self.setting_table {
            if not wanted or wanted in setting.name or wanted == setting.subject {
                print("studio: var " + setting.name + " = " + self.setting_values.get(setting.name, "") + " (" + setting.subject + ")");
            }
        }
        return True;
    }
    stage = self.stage;
    casing = self.settings_box;
    word = args[2] if len(args) > 2 else "";
    if word == "close" or (not word and casing is not None) {
        if casing is not None and stage is not None {
            stage.close(casing);
        }
        self.settings_box = None;
        return True;
    }
    if word and word != "open" {
        if word not in [key for (key, called) in SUBJECTS] {
            self.say("ed_settings box [" + "|".join([key for (key, called) in SUBJECTS]) + "|close]");
            return True;
        }
        self.settings_subject = word;
    }
    if casing is None and stage is not None {
        casing = Floater(title="Settings", command="ed_settings box close", least_wide=520, least_tall=240);
        casing.area = Rect(x=max(8, (stage.width - 660) // 2), y=100, w=min(660, max(520, stage.width - 16)), h=400);
        casing.settle(stage);
        stage.open(casing);
        self.settings_box = casing;
    }
    self.settings_for = "";
    self.keep_settings_box();
    print(
        "studio: settings box subject=" + self.settings_subject + " rows="
            + str(len([setting for setting in self.setting_table if setting.subject == self.settings_subject]))
    );
    return True;
}
