"""Help for the control under the pointer, hints that fly beside it, and a
name typed over a row of the scene list. Declarations live in studio.jac."""

impl Studio.help_lines(asked: str) -> list[str] {
    lines: list[str] = [];
    word = asked.split()[0] if asked.split() else "";
    for (name, usage, description) in STUDIO_COMMANDS {
        if name == word {
            lines.append(usage);
            lines.append(description);
        }
    }
    for tool in self.tools {
        for (name, usage, description) in tool.commands() {
            if name == word {
                lines.append(usage);
                lines.append(description);
            }
        }
    }
    return lines;
}

impl Studio.help_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    stage = self.stage;
    ui = self.ui;
    if name == "ed_flyover" {
        word = args[1] if len(args) > 1 else "";
        wanted = (not self.flyovers) if word not in ["on", "off"] else word == "on";
        if wanted != self.flyovers {
            self.flyovers = wanted;
            if stage is not None {
                stage.flyovers = wanted;
            }
            self.keep_settings();
            self.say("A control's hint is shown beside the pointer when it rests there" if wanted else "Hints are shown in the bar at the foot only");
        }
        return True;
    }
    if name == "ed_help" {
        asked = " ".join(args[1:]);
        if asked == "doc" {
            # The studio's own book, in whatever program is kept for such files.
            book = "docs/studio-status.md";
            if not os.path.isfile(book) {
                self.say("The studio's book is docs/studio-status.md in QuakePassion's folder; it is not beside where this was started");
                return True;
            }
            return self.outside_command(scene, ["ed_openwith", book]);
        }
        said: list[str] = [];
        under = stage.hover if stage is not None else None;
        if not asked and under is not None and stage is not None {
            # What the pointer is on: its hint, and the command it asks for.
            if stage.hint() {
                said.append(stage.hint());
            }
            target: Widget | None = under;
            while target is not None and not asked {
                asked = target.asks();
                target = target.parent();
            }
        }
        about = self.help_lines(asked);
        word = asked.split()[0] if asked.split() else "";
        if len(about) == 0 and word and not word.startswith("ed_") {
            about = self.help_lines("ed_" + word);
            word = "ed_" + word;
        }
        for line in about {
            said.append(line);
        }
        if len(said) == 0 {
            self.say(
                "No command is called " + word + " (Ctrl+P lists them all)" if word
                else "Point at a control and press F1, or ed_help <command>; ed_help doc opens the studio's book"
            );
            return True;
        }
        print("studio: help " + (word if word and len(about) > 0 else "hint") + " lines=" + str(len(said)));
        for line in said {
            print("studio: help: " + line);
        }
        if stage is not None {
            shown: list[MenuItem] = [MenuItem(text=line[:120]) for line in said];
            shown.append(MenuItem(rule=True));
            shown.append(MenuItem(text="Open the studio's book", command="ed_help doc"));
            sheet = MenuPopup(items=shown);
            sheet.open_at(stage, stage.input.x + 12, stage.input.y + 12);
        }
        self.say(said[0]);
        return True;
    }
    if name != "ed_rename" {
        return False;
    }
    chosen = scene.selection();
    if len(chosen) != 1 {
        self.say("Select the one entity to name");
        return True;
    }
    item = chosen[0];
    key = "_group_name" if item.classname() == "func_group" else "targetname";
    if len(args) > 1 {
        # The name itself: typed over the row, or said outright.
        wanted_name = " ".join(args[1:]).strip();
        typed = self.rename_field;
        if typed is not None and stage is not None {
            stage.close(typed);
            self.rename_field = None;
        }
        if wanted_name == item.fields.get(key, "") {
            return True;
        }
        if not wanted_name {
            scene.unset_field(key);
        } else {
            reason = scene.refuses(key, wanted_name);
            if reason {
                self.say(reason);
                return True;
            }
            scene.set_field(key, wanted_name);
        }
        print("studio: renamed #" + str(item.serial) + " " + key + "=" + wanted_name);
        self.say(item.title() + " is named");
        return True;
    }
    if stage is None or ui is None {
        return True;
    }
    # A field over the entity's row of the scene list, with its name to type over.
    tree = ui.tree;
    place = -1;
    for (index, row) in enumerate(tree.rows) {
        if row.key == str(item.serial) {
            place = index;
        }
    }
    if place < 0 {
        self.say("Its row is not in the list: open its class's heading (or ed_rename <name>)");
        return True;
    }
    tree.reveal(place);
    typed_now = TextField(value=item.fields.get(key, ""), command="ed_rename", ghost="name");
    typed_now.transient = True;
    typed_now.area = Rect(
        x=tree.area.x + 24, y=tree.area.y + place * tree.row_height - tree.offset, w=max(60, tree.area.w - 60), h=tree.row_height
    );
    stage.dismiss();
    stage.open(typed_now);
    stage.focus_on(typed_now);
    self.rename_field = typed_now;
    print("studio: renaming #" + str(item.serial) + " row=" + str(place));
    self.say("Type its name and press Enter (Esc leaves it as it is)");
    return True;
}
