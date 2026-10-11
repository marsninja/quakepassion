"""The studio's open documents, the files opened lately, the selection's
menu, the console's last lines and how maps are written. Declarations live
in studio.jac."""

impl Studio.doc_keys -> list[str] {
    return sorted(self.scenes.keys());
}

impl Studio.map_text(scene: Scene) -> str {
    return write_map(scene_map(scene), "valve", False, self.map_comments, self.map_whole);
}

impl Studio.recent_path -> str {
    return override_folder() + "/studio_recent.txt";
}

impl Studio.recent_files -> list[str] {
    path = self.recent_path();
    if not os.path.isfile(path) {
        return [];
    }
    try {
        with open(path, "r") as file {
            return [line.strip() for line in file.read().splitlines() if line.strip()];
        }
    } except OSError {
        return [];
    }
}

impl Studio.note_recent(path: str) {
    whole = os.path.abspath(path);
    kept = [whole] + [other for other in self.recent_files() if other != whole];
    try {
        os.makedirs(os.path.dirname(self.recent_path()), exist_ok=True);
        with open(self.recent_path(), "w") as file {
            file.write("\n".join(kept[:12]) + "\n");
        }
    } except OSError {
        return;
    }
    ui = self.ui;
    if ui is not None {
        # The Library tab lists them: it is filled again when next looked at.
        ui.library.rows = [];
    }
}

impl Studio.show_doc(key: str) -> bool {
    target = self.scenes.get(key);
    current = self.scene;
    if target is None {
        return False;
    }
    if target is current {
        return True;
    }
    if current is not None {
        eye = self.main.eye;
        self.doc_views[current.game + "/" + current.name] = [eye.x, eye.y, eye.z, self.main.yaw, self.main.pitch];
    }
    if target.name.startswith("studio:") {
        self.show_scene(target);
    } else {
        if not self.load(target.game, target.name) {
            return False;
        }
        self.enter(reset_camera=False);
    }
    stood = self.doc_views.get(key);
    if stood is not None and len(stood) == 5 {
        self.main.eye = Vec3(x=stood[0], y=stood[1], z=stood[2]);
        self.main.yaw = stood[3];
        self.main.pitch = stood[4];
    }
    ui = self.ui;
    if ui is not None {
        ui.library.rows = [];
    }
    return self.scene is target;
}

impl Studio.save_all -> int {
    current = self.scene;
    count = 0;
    for key in self.doc_keys() {
        held = self.scenes[key];
        if not held.dirty or (held.game == "passion" and not held.name.startswith("studio:")) {
            continue;
        }
        # Each is saved as the one being edited is.
        self.scene = held;
        self.save();
        if not held.dirty {
            count += 1;
        }
    }
    self.scene = current;
    return count;
}

impl Studio.selection_menu(scene: Scene, x: int, y: int) {
    stage = self.stage;
    if stage is None {
        return;
    }
    brushes = len(scene.selected_solids());
    items = [
        MenuItem(text="Look at", command="ed_focus", keys="F"),
        MenuItem(text="Duplicate", command="ed_duplicate", keys="Ctrl+D"),
        MenuItem(text="Delete", command="ed_delete", keys="Del"),
        MenuItem(rule=True),
        MenuItem(text="Copy", command="ed_copy", keys="Ctrl+C"),
        MenuItem(text="Cut", command="ed_cut", keys="Ctrl+X"),
        MenuItem(rule=True),
        MenuItem(text="Hide", command="ed_hide", keys="H"),
        MenuItem(text="Hide everything else", command="ed_hide others"),
        MenuItem(text="Drop to the floor", command="ed_drop", keys="End")
    ];
    if brushes > 0 {
        items.append(MenuItem(rule=True));
        items.append(MenuItem(text="Group", command="ed_group", keys="Ctrl+G"));
        items.append(MenuItem(text="Hollow", command="ed_hollow"));
        items.append(MenuItem(text="Carve out of the others", command="ed_carve"));
        items.append(MenuItem(text="Its owner", command="ed_select parent"));
    } else {
        items.append(MenuItem(rule=True));
        items.append(MenuItem(text="Its brushes", command="ed_select child"));
    }
    popup = MenuPopup(items=items);
    popup.open_at(stage, x, y);
}

impl Studio.doc_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    stage = self.stage;
    app = self.app;
    if name == "ed_docs" {
        told: list[str] = [];
        for key in self.doc_keys() {
            held = self.scenes[key];
            print(
                "studio: doc " + key + " dirty=" + ("1" if held.dirty else "0") + " current="
                    + ("1" if held is scene else "0")
            );
            told.append(held.name + ("*" if held.dirty else ""));
        }
        self.say("Open: " + ", ".join(told));
        return True;
    }
    if name == "ed_doc" {
        keys = self.doc_keys();
        wanted = args[1] if len(args) > 1 else "next";
        this_key = scene.game + "/" + scene.name;
        target = "";
        if wanted == "next" or wanted == "prev" {
            place = 0;
            for index in range(len(keys)) {
                if keys[index] == this_key {
                    place = index;
                }
            }
            target = keys[(place + (1 if wanted == "next" else -1)) % len(keys)];
        } else {
            for key in keys {
                # By its whole key, or by the name the title shows.
                if key == wanted or key.split("/")[-1] == wanted or key.endswith(":" + wanted) {
                    target = key;
                }
            }
        }
        if not target {
            self.say("No open document is called " + wanted + " (ed_docs lists them)");
        } elif target == this_key {
            self.say("That is the document being edited");
        } elif not self.show_doc(target) {
            self.say("That document does not load");
        }
        return True;
    }
    if name == "ed_close" {
        if scene.dirty and not (len(args) > 1 and args[1] == "force") {
            self.say("This document has edits that are not saved: save it, or ed_close force");
            return True;
        }
        this_key = scene.game + "/" + scene.name;
        others = [key for key in self.doc_keys() if key != this_key];
        if len(others) == 0 {
            self.say("It is the only document open");
            return True;
        }
        if not self.show_doc(others[0]) {
            self.say("The next document does not load, so this one stays");
            return True;
        }
        self.scenes.pop(this_key, None);
        self.doc_views.pop(this_key, None);
        ui = self.ui;
        if ui is not None {
            ui.library.rows = [];
        }
        self.say("Closed " + this_key.split("/")[-1]);
        return True;
    }
    if name == "ed_recent" {
        lately = self.recent_files();
        if len(args) > 1 and args[1].isdigit() {
            if int(args[1]) < 1 or int(args[1]) > len(lately) {
                self.say("ed_recent: there are " + str(len(lately)) + " recent files");
            } else {
                self.open_map(lately[int(args[1]) - 1]);
            }
            return True;
        }
        for path in lately {
            print("studio: recent " + path);
        }
        if len(lately) == 0 or stage is None {
            self.say("No file has been opened or saved yet");
            return True;
        }
        listed: list[MenuItem] = [];
        for (index, path) in enumerate(lately) {
            listed.append(MenuItem(text=os.path.basename(path), command="ed_recent " + str(index + 1)));
        }
        chooser = MenuPopup(items=listed);
        chooser.open_at(stage, 300, 80);
        return True;
    }
    if name == "ed_log" {
        if app is None or stage is None {
            return True;
        }
        count = 20;
        if len(args) > 1 and args[1].isdigit() {
            count = max(1, min(40, int(args[1])));
        }
        said = app.shell.log.lines;
        shown: list[MenuItem] = [];
        for line in said[max(0, len(said) - count):] {
            shown.append(MenuItem(text=line[:110] if line else " "));
        }
        if len(shown) == 0 {
            self.say("The console has said nothing yet");
            return True;
        }
        print("studio: log lines=" + str(len(shown)));
        sheet = MenuPopup(items=shown);
        sheet.open_at(stage, 300, 80);
        return True;
    }
    if name == "ed_mapopts" {
        which = args[1] if len(args) > 1 else "";
        if which in ["comments", "whole"] {
            on = (not self.map_comments) if which == "comments" else (not self.map_whole);
            if len(args) > 2 and args[2] in ["on", "off", "1", "0"] {
                on = args[2] in ["on", "1"];
            }
            if which == "comments" {
                self.map_comments = on;
            } else {
                self.map_whole = on;
            }
            self.keep_settings();
        } elif which {
            self.say("ed_mapopts [comments|whole] [on|off]");
            return True;
        }
        self.say(
            "Maps are written " + ("with" if self.map_comments else "without") + " numbered comments, "
                + ("with whole coordinates only" if self.map_whole else "with coordinates as they are")
        );
        return True;
    }
    return False;
}
