"""The studio's entity classes: the inspector's typed fields, the class
list, options as boxes to tick, and the shapes built of brushes.
Declarations live in studio.jac."""

"""The class every one of the entities has, or "" when they differ."""
def:priv shared_class(chosen: list[Item]) -> str {
    if len(chosen) == 0 {
        return "";
    }
    name = chosen[0].classname();
    for item in chosen {
        if item.classname() != name {
            return "";
        }
    }
    return name;
}

"""The numbers among a shape command's words."""
def:priv shape_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            continue;
        }
    }
    return found;
}

impl Studio.fill_fields(scene: Scene, ui: StudioUi, chosen: list[Item]) {
    form = ui.form;
    shared = shared_class(chosen);
    # The class first, then the fields in the order the map has them.
    keys: list[str] = ["classname"];
    for item in chosen {
        for key in item.fields.keys() {
            if key not in keys {
                keys.append(key);
            }
        }
    }
    for key in keys {
        first = chosen[0].fields.get(key, "");
        same = True;
        for item in chosen {
            if item.fields.get(key, "") != first or key not in item.fields {
                same = False;
            }
        }
        known = field_of(shared, key);
        row = Box(across=True, gap=4);
        form.adopt(row);
        row.adopt(Label(text=key, tone="dim", size=104, hint=known.help));
        placing = "ed_set " + quote_command_word(key);
        told = (known.help + " | " if known.help else "") + "Enter sets " + key + " on the selection; Escape cancels";
        if known.kind == "choice" and same {
            words = first;
            labels: list[str] = [];
            orders: list[str] = [];
            for (value, label) in known.choices {
                labels.append(label);
                orders.append(placing + " " + quote_command_word(value));
                if value == first {
                    words = label;
                }
            }
            row.adopt(Dropdown(text=words, labels=labels, commands=orders, grow=1, hint=known.help));
        } else {
            row.adopt(
                TextField(
                    value=first if same else "", ghost="" if same else "(mixed)", command=placing, grow=1, hint=told
                )
            );
        }
        if known.kind == "angle" {
            row.adopt(
                PushButton(
                    text="<", command="ed_bump " + quote_command_word(key) + " 45", size=22, hint="Turn it 45 degrees left"
                )
            );
            row.adopt(
                PushButton(
                    text=">", command="ed_bump " + quote_command_word(key) + " -45", size=22, hint="Turn it 45 degrees right"
                )
            );
        } elif known.kind == "color" and same {
            tint = read_vector(first);
            if tint is not None {
                if max(tint.x, max(tint.y, tint.z)) > 1.0 {
                    tint = tint.scale(1.0 / 255.0);
                }
                row.adopt(Swatch(red=tint.x, green=tint.y, blue=tint.z, size=22));
            }
        } elif known.kind == "link" and same and first {
            row.adopt(
                PushButton(
                    text=">",
                    command="ed_select " + quote_command_word("name:" + first),
                    size=22,
                    hint="Select what it fires"
                )
            );
        }
        row.adopt(PushButton(text="x", command="ed_unset " + quote_command_word(key), size=22, hint="Remove " + key));
    }
}

impl Studio.fill_class(scene: Scene, ui: StudioUi, chosen: list[Item]) {
    form = ui.form;
    shared = shared_class(chosen);
    known = class_info(shared) if shared else None;
    if known is None {
        return;
    }
    form.adopt(Spacer(size=8));
    form.adopt(Label(text=known.help, tone="faint", small=True));
    if len(known.flags) > 0 {
        value = chosen[0].fields.get("spawnflags", "");
        line: Box | None = None;
        placed = 0;
        for bit in range(len(known.flags)) {
            name = known.flags[bit];
            if not name {
                continue;
            }
            if line is None or placed % 2 == 0 {
                line = Box(across=True, gap=4);
                form.adopt(line);
            }
            line.adopt(
                Check(
                    text=name.lower().replace("_", " "),
                    on_now=flag_set(value, bit),
                    command="ed_flag " + str(bit),
                    grow=1,
                    hint="Option " + name + " (spawnflags " + str(1 << bit) + ")"
                )
            );
            placed += 1;
        }
    }
    missing: list[FieldInfo] = [];
    for known_field in known.fields {
        held = False;
        for item in chosen {
            if known_field.name in item.fields {
                held = True;
            }
        }
        if not held {
            missing.append(known_field);
        }
    }
    if len(missing) == 0 {
        return;
    }
    form.adopt(Spacer(size=4));
    form.adopt(Label(text="More fields", tone="dim", small=True));
    for absent in missing {
        row = Box(across=True, gap=4);
        form.adopt(row);
        row.adopt(Label(text=absent.name, tone="faint", size=104, hint=absent.help));
        placing = "ed_set " + quote_command_word(absent.name);
        if absent.kind == "choice" {
            labels: list[str] = [];
            orders: list[str] = [];
            words = "";
            for (value, label) in absent.choices {
                labels.append(label);
                orders.append(placing + " " + quote_command_word(value));
                if value == absent.preset {
                    words = "(" + label + ")";
                }
            }
            row.adopt(Dropdown(text=words, labels=labels, commands=orders, grow=1, hint=absent.help));
        } else {
            row.adopt(
                TextField(
                    ghost=absent.preset if absent.preset else absent.kind,
                    command=placing,
                    grow=1,
                    hint=(absent.help + " | " if absent.help else "") + "Enter gives the selection this field"
                )
            );
        }
    }
}

impl Studio.list_classes(ui: StudioUi) {
    rows: list[TreeRow] = [];
    wanted = self.class_filter.lower();
    families: dict[str, list[str]] = {};
    order: list[str] = [];
    for name in class_names(scene_game(self.scene)) {
        if wanted and wanted not in name.lower() {
            continue;
        }
        family = class_family(name);
        if family not in families {
            families[family] = [];
            order.append(family);
        }
        families[family].append(name);
    }
    for family in sorted(order) {
        members = families[family];
        shown = self.opened.get("fam:" + family, False) or bool(wanted);
        rows.append(
            TreeRow(key="fam:" + family, text=family, branch=True, opened=shown, note=str(len(members)))
        );
        if not shown {
            continue;
        }
        for name in members {
            known = class_info(name);
            rows.append(
                TreeRow(
                    key=name, text=name, depth=1, note="brushes" if known is not None and known.solid else ""
                )
            );
        }
    }
    ui.classes.rows = rows;
}

impl Studio.class_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_classfilter" {
        self.class_filter = args[1] if len(args) > 1 else "";
        return True;
    }
    if name == "ed_class" {
        if len(args) < 2 or not args[1].strip() {
            self.say("ed_class <classname>");
            return True;
        }
        wanted = args[1].strip();
        if wanted.startswith("fam:") {
            self.opened[wanted] = not self.opened.get(wanted, False);
            self.folds += 1;
            return True;
        }
        known = class_info(wanted);
        if known is None or not known.solid {
            self.create(scene, ["ed_new", wanted]);
            return True;
        }
        if not scene.selected_solids() {
            if not self.is_built_scene() {
                self.say(wanted + " is made of brushes: a shipped map cannot take new ones");
                return True;
            }
            self.add_shape(scene, ["ed_box"], "box");
        }
        taker = scene.tie_selection(wanted);
        if taker is None {
            self.say("Select the brushes " + wanted + " is made of");
        } else {
            scene.select(taker);
            self.say("Made " + taker.title());
        }
        return True;
    }
    if name == "ed_flag" {
        if len(args) < 3 or not args[1].isdigit() {
            self.say("ed_flag <bit> <0|1>");
            return True;
        }
        if not scene.flag_selection(int(args[1]), args[2] != "0") {
            self.say("Nothing to change");
        }
        return True;
    }
    if name == "ed_bump" {
        amount = shape_numbers(args[2:]);
        if len(args) < 3 or len(amount) == 0 {
            self.say("ed_bump <key> <amount>");
            return True;
        }
        turning = args[1] == "angle";
        if not scene.bump_selection(args[1], amount[0], 360.0 if turning else 0.0, turning) {
            self.say("Nothing selected has a number for " + args[1]);
        }
        return True;
    }
    if name == "ed_light" {
        if len(args) < 2 or args[1] not in ["on", "off"] {
            self.say("ed_light <on|off>");
            return True;
        }
        self.lit = args[1] == "on";
        # Build the level again, lit or flat.
        self.built_geometry = -1;
        self.say("Scenes are lit from their own lights" if self.lit else "Scenes are lit flat");
        return True;
    }
    if name == "ed_shape" {
        kind = args[1] if len(args) > 1 else "";
        if kind not in SHAPE_KINDS {
            self.say("ed_shape <" + "|".join(SHAPE_KINDS) + "> [w d h] [count] [thickness]");
            return True;
        }
        if not self.is_built_scene() {
            self.say("A shipped map cannot take new brushes: start a scene (ed_scene)");
            return True;
        }
        numbers = shape_numbers(args[2:]);
        size = Vec3(x=128.0, y=32.0 if kind == "arch" else 128.0, z=96.0);
        if len(numbers) >= 3 {
            size = Vec3(x=max(8.0, numbers[0]), y=max(8.0, numbers[1]), z=max(8.0, numbers[2]));
        }
        count = int(numbers[3]) if len(numbers) > 3 else 0;
        thickness = numbers[4] if len(numbers) > 4 else 16.0;
        made = shape_brushes(kind, Vec3(), size, count, thickness, self.material);
        if len(made) == 0 {
            self.say("That " + kind + " encloses nothing");
            return True;
        }
        found = [MapItem(fields={"classname": "worldspawn"}, brushes=made)];
        if self.place_fragment(scene, found, "Add " + kind, kind if len(made) > 1 else "") {
            self.say("Added a " + kind + " of " + str(len(made)) + (" brush" if len(made) == 1 else " brushes"));
        }
        return True;
    }
    return False;
}
