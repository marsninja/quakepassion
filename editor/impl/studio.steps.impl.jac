"""Seeing what a bake made, recipes of build commands, steps run by other
programs over the scene's map, and what they say gone to. Declarations live
in studio.jac."""

impl Studio.eye_cell(scene: Scene) -> int {
    made = self.live;
    if made is None or made.bsp.clusters < 2 or len(made.bsp.models) == 0 {
        return -1;
    }
    # From a lone selected entity, else from where the 3D camera is.
    eye = self.main.eye;
    chosen = scene.selection();
    if len(chosen) == 1 and len(scene.selected_solids()) == 0 {
        stands = chosen[0].origin();
        if stands is not None {
            eye = stands;
        }
    }
    return made.bsp.leaves[leaf_at(made.bsp, made.bsp.models[0].head, eye)].cluster;
}

impl Studio.cells_seen(scene: Scene) -> int {
    made = self.live;
    from_cell = self.eye_cell(scene);
    if made is None or from_cell < 0 {
        return 0;
    }
    count = 0;
    for other in range(made.bsp.clusters) {
        if cell_sees(made.bsp, from_cell, other) {
            count += 1;
        }
    }
    return count;
}

impl Studio.draw_cells(scene: Scene) {
    made = self.live;
    from_cell = self.eye_cell(scene);
    if not self.cells_shown or made is None or from_cell < 0 {
        return;
    }
    for (index, leaf) in enumerate(made.bsp.leaves) {
        if leaf.cluster < 0 {
            continue;
        }
        if index < len(made.shapes) {
            # A leaf of a bake by planes: its own outline, drawn a little
            # toward its middle so that neighbours' lines lie apart.
            middle = leaf.mins.add(leaf.maxs).scale(0.5);
            outline_tone = ink(0xffd166) if leaf.cluster == from_cell else (
                ink(0x3ddc97) if cell_sees(made.bsp, from_cell, leaf.cluster) else ink(0xe5484d).faded(150)
            );
            for outline in made.shapes[index] {
                drawn = [corner.add(middle.sub(corner).scale(0.03)) for corner in outline];
                for at in range(len(drawn)) {
                    wire_line(drawn[at], drawn[(at + 1) % len(drawn)], outline_tone);
                }
            }
            continue;
        }
        # Drawn a little inside itself, so that neighbours' lines lie apart.
        low = leaf.mins.add(Vec3(x=4.0, y=4.0, z=1.0));
        high = leaf.maxs.sub(Vec3(x=4.0, y=4.0, z=1.0));
        if leaf.cluster == from_cell {
            wire_box(low, high, ink(0xffd166));
            continue;
        }
        tone = ink(0x3ddc97) if cell_sees(made.bsp, from_cell, leaf.cluster) else ink(0xe5484d).faded(150);
        for level in [low.z, high.z] {
            wire_line(Vec3(x=low.x, y=low.y, z=level), Vec3(x=high.x, y=low.y, z=level), tone);
            wire_line(Vec3(x=high.x, y=low.y, z=level), Vec3(x=high.x, y=high.y, z=level), tone);
            wire_line(Vec3(x=high.x, y=high.y, z=level), Vec3(x=low.x, y=high.y, z=level), tone);
            wire_line(Vec3(x=low.x, y=high.y, z=level), Vec3(x=low.x, y=low.y, z=level), tone);
        }
    }
}

impl Studio.draw_portals(scene: Scene) {
    if not self.portals_shown {
        return;
    }
    # A portal file's, as they were read.
    for points in self.portal_lines {
        for at in range(len(points)) {
            wire_line(points[at], points[(at + 1) % len(points)], ink(0xb18cff));
        }
    }
    made = self.live;
    if made is None {
        return;
    }
    from_cell = self.eye_cell(scene);
    bsp = made.bsp;
    for (number, points) in enumerate(made.portals) {
        if number * 2 + 1 >= len(made.portal_ends) {
            break;
        }
        first = bsp.leaves[made.portal_ends[number * 2]];
        second = bsp.leaves[made.portal_ends[number * 2 + 1]];
        if first.cluster < 0 or second.cluster < 0 {
            continue;
        }
        # The looked-from cluster's own in yellow; between two areas (an
        # area portal's) in orange; the rest green where in sight, else red.
        tone = ink(0xe5484d).faded(150);
        if from_cell >= 0 and (first.cluster == from_cell or second.cluster == from_cell) {
            tone = ink(0xffd166);
        } elif first.area != second.area {
            tone = ink(0xff7a18);
        } elif from_cell < 0 or (cell_sees(bsp, from_cell, first.cluster) and cell_sees(bsp, from_cell, second.cluster)) {
            tone = ink(0x3ddc97);
        }
        for at in range(len(points)) {
            wire_line(points[at], points[(at + 1) % len(points)], tone);
        }
    }
}

impl Studio.portals_command(scene: Scene, args: list[str]) {
    how = args[1] if len(args) > 1 else "";
    made = self.live;
    if how in ["load", "write"] {
        # Beside the scene's map unless told where.
        path = args[2] if len(args) > 2 else self.scene_path(scene.name[7:] if scene.name.startswith("studio:") else scene.name)[:-4] + ".prt";
        if how == "write" {
            text = portal_file_text(made) if made is not None else "";
            if not text {
                self.say("ed_portals write: bake the level by its planes first (ed_bake planes)");
                return;
            }
            try {
                os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True);
                with open(path, "w") as file {
                    file.write(text);
                }
            } except OSError {
                self.say("ed_portals write: could not write " + path);
                return;
            }
            print("studio: portals written " + path + " portals=" + text.split("\n")[2]);
            self.say("The bake's portals are written as a portal file: " + path);
            return;
        }
        text = "";
        try {
            with open(path, "r") as file {
                text = file.read();
            }
        } except OSError {
            self.say("ed_portals load: could not read " + path);
            return;
        }
        read = portal_file_windings(text);
        if read is None {
            self.say("ed_portals load: " + path + " is not a portal file");
            return;
        }
        self.portal_lines = read;
        self.portal_file = path;
        self.portals_shown = True;
        print("studio: portals loaded " + path + " portals=" + str(len(read)));
        self.say(str(len(read)) + " portals read from " + path + ", drawn in violet");
        return;
    }
    if how == "forget" {
        self.portal_lines = [];
        self.portal_file = "";
        self.say("The portal file read is put away");
        return;
    }
    self.portals_shown = not self.portals_shown;
    if how in ["on", "off", "1", "0"] {
        self.portals_shown = how in ["on", "1"];
    }
    count = len(made.portals) if made is not None else 0;
    print("studio: portals shown=" + ("1" if self.portals_shown else "0") + " baked=" + str(count) + " read=" + str(len(self.portal_lines)));
    if not self.portals_shown {
        self.say("The portals are not drawn");
    } elif count == 0 and not self.portal_lines {
        self.say("No portals to draw: ed_bake planes cuts the level into leaves joined by portals");
    } else {
        self.say(
            "Portals: the looked-from cluster's in yellow, an area portal's in orange, the rest green where seen and red where not ("
                + str(count) + ")"
        );
    }
}

impl Studio.build_mark(whole: Scene) -> str {
    return text_mark(write_map(scene_map(whole))) + "|" + ("lit" + str(int(self.luxel)) if self.lit else "flat") + "|"
        + str(int(self.vis_cell)) + "|" + ("tones" if self.solid_tones else "textures") + "|" + str(self.materials_changed);
}

impl Studio.show_said(scene: Scene, places: list[Place], plain: bool) {
    ui = self.ui;
    order = scene.items();
    self.findings = [];
    rows: list[TreeRow] = [];
    for place in places {
        about = Finding(words=place.words, grave=True);
        if plain and place.entity < len(order) {
            # The map was the document as it stands: its numbers are ours.
            about.item = order[place.entity];
            owned = scene.solids_of(order[place.entity]);
            if place.brush >= 0 and place.brush < len(owned) {
                about.solid = owned[place.brush];
            }
        }
        rows.append(TreeRow(key=str(len(self.findings)), text=place.words, tone="text", note="!"));
        self.findings.append(about);
    }
    if ui is not None {
        if not rows {
            rows.append(TreeRow(key="none", text="Nothing was said of an entity or a brush.", tone="faint"));
        }
        ui.checks.rows = rows;
    }
}

impl Studio.step_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    app = self.app;
    stage = self.stage;
    if name == "ed_portals" {
        self.portals_command(scene, args);
        return True;
    }
    if name == "ed_cells" {
        self.cells_shown = not self.cells_shown;
        if len(args) > 1 and args[1] in ["on", "off", "1", "0"] {
            self.cells_shown = args[1] in ["on", "1"];
        }
        if not self.cells_shown {
            self.say("The cells of the bake are not drawn");
        } elif self.vis_cell <= 0.0 {
            self.say("The level is built as one: ed_bake cuts it into cells to show");
        } else {
            self.say(
                "Cells: the one looked from in yellow, what it sees in green, the rest in red ("
                    + str(self.cells_seen(scene)) + " of " + str(self.vis_done.cells) + " seen)"
            );
        }
        return True;
    }
    if name == "ed_recipe" {
        if len(args) < 2 {
            listed: list[MenuItem] = [];
            known = self.all_recipes();
            for kept in sorted(known.keys()) {
                listed.append(MenuItem(text=kept + ": " + known[kept], command="ed_make " + kept));
                print("studio: recipe " + kept + " = " + known[kept]);
            }
            if len(listed) == 0 {
                self.say("No recipes are kept: ed_recipe <name> \"<command>; <command>\" keeps one, ed_make <name> runs it");
            } elif stage is not None {
                sheet = MenuPopup(items=listed);
                sheet.open_at(stage, 300, 80);
            }
            return True;
        }
        label = "".join([letter for letter in args[1] if letter.isalnum() or letter in "_-"]);
        if not label {
            self.say("A recipe's name is letters, digits, - and _");
            return True;
        }
        steps = recipe_steps(" ".join(args[2:]));
        # A project's recipes are kept in its manifest, to go where it goes.
        held = self.project;
        book = held.recipes if held is not None else self.recipes;
        if len(steps) == 0 {
            if label in book {
                book.pop(label, None);
                self.say("The recipe " + label + " is forgotten");
            } else {
                self.say("ed_recipe " + label + " \"<command>; <command>\": the commands it runs");
                return True;
            }
        } else {
            book[label] = "; ".join(steps);
            self.say("ed_make " + label + " runs " + book[label]);
        }
        if held is not None {
            self.save_project();
        } else {
            self.keep_settings();
        }
        return True;
    }
    if name == "ed_make" {
        sought = args[1] if len(args) > 1 else "";
        known = self.all_recipes();
        if sought not in known {
            self.say("ed_make <name>: " + (", ".join(sorted(known.keys())) if known else "no recipes are kept (ed_recipe)"));
            return True;
        }
        steps = recipe_steps(known[sought]);
        if app is not None {
            # Ahead of whatever waits, each in its turn.
            app.shell.insert_text("\n".join(steps));
        }
        print("studio: making " + sought + " steps=" + str(len(steps)));
        return True;
    }
    if name != "ed_run" {
        return False;
    }
    if len(args) < 2 {
        self.say("ed_run <command line>: %map% is the scene written as a map, %dir% its folder, %name% its name");
        return True;
    }
    if not self.is_built_scene() {
        self.say("ed_run works on a scene of brushes (ed_convert makes one of a level)");
        return True;
    }
    # What is built, with copies and prefabs made real; the document as it
    # stands when it has none, and then the map's numbers are its own.
    whole = self.expanded(scene);
    plain = whole is scene;
    text = write_map(scene_map(whole), "valve", False, True, self.map_whole);
    path = self.scene_path(scene.name[7:]).replace(".map", ".build.map");
    heard = path + ".log";
    try {
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w") as file {
            file.write(text);
        }
    } except OSError {
        self.say("ed_run: could not write " + path);
        return True;
    }
    line = step_line(" ".join(args[1:]), path);
    status = os.system("( " + line + " ) > \"" + heard + "\" 2>&1");
    code = (status >> 8) & 255 if status > 255 else status;
    said = "";
    try {
        with open(heard, "r") as file {
            said = file.read();
        }
    } except OSError {
        said = "";
    }
    spoken = [each for each in said.split("\n") if each.strip()];
    for each in spoken[-12:] {
        if app is not None {
            app.shell.print(each);
        }
    }
    places = places_named(said, text);
    self.show_said(scene, places, plain);
    print(
        "studio: ran code=" + str(code) + " lines=" + str(len(spoken)) + " places=" + str(len(places))
            + " plain=" + ("1" if plain else "0")
    );
    for place in places {
        print("studio: said entity=" + str(place.entity) + " brush=" + str(place.brush) + " " + place.words);
    }
    self.say(
        ("It ran" if code == 0 else "It stopped with " + str(code)) + ", saying " + str(len(spoken)) + " lines"
            + (
                "; " + str(len(places)) + " name an entity or a brush (the Checks tab goes to them)"
                if places
                else ""
            )
    );
    return True;
}
