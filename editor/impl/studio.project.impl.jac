"""Projects (a folder with a manifest, scenes, prefabs and textures of its
own), add-ons of entity classes read from text files, and what each game
is set up with. Declarations live in studio.jac."""

impl Studio.projects_folder -> str {
    folder = os.getenv("QP_PROJECTS", "");
    return folder if folder else os.getcwd() + "/projects";
}

impl Studio.class_game -> str {
    project = self.project;
    if project is not None and self.is_built_scene() {
        return project.game;
    }
    return scene_game(self.scene);
}

impl Studio.save_project {
    project = self.project;
    if project is None or not self.project_folder {
        return;
    }
    try {
        os.makedirs(self.project_folder, exist_ok=True);
        with open(self.project_folder + "/" + MANIFEST_NAME, "w") as file {
            file.write(write_project(project));
        }
    } except OSError {
        self.say("The project's manifest could not be written in " + self.project_folder);
    }
}

impl Studio.project_took(path: str) {
    project = self.project;
    held = self.project_folder + "/scenes/";
    if project is None or not path.startswith(held) or not path.endswith(".map") {
        return;
    }
    # A scene saved among the project's is one of them.
    named = path[len(held):-4];
    if named and "/" not in named and named not in project.scenes {
        project.scenes.append(named);
        if not project.start {
            project.start = named;
        }
        self.save_project();
    }
}

impl Studio.all_recipes -> dict[str, str] {
    both: dict[str, str] = {};
    for kept in self.recipes.keys() {
        both[kept] = self.recipes[kept];
    }
    project = self.project;
    if project is not None {
        # The project's own have the last word on a name.
        for kept in project.recipes.keys() {
            both[kept] = project.recipes[kept];
        }
    }
    return both;
}

impl Studio.load_addon(path: str) -> int {
    text = "";
    try {
        with open(path, "r") as file {
            text = file.read();
        }
    } except OSError {
        return -1;
    }
    # What it added before is taken out first, so that a class it no
    # longer has is gone.
    drop_classes(self.addons.get(path, []));
    taken = add_classes(addon_classes(text));
    self.addons[path] = taken;
    self.classes_seen = "";
    # The folders it names beside its file: image files to use as
    # materials, and prefabs. Each is known by the add-on's name.
    label = addon_label(path);
    self.addon_labels[path] = label;
    self.addon_textures.pop(label, None);
    self.addon_prefabs.pop(label, None);
    beside = os.path.dirname(os.path.abspath(path));
    named = addon_folders(text);
    if "textures" in named and os.path.isdir(beside + "/" + named["textures"]) {
        self.addon_textures[label] = beside + "/" + named["textures"];
    }
    if "prefabs" in named and os.path.isdir(beside + "/" + named["prefabs"]) {
        self.addon_prefabs[label] = beside + "/" + named["prefabs"];
    }
    self.sync_addons();
    return len(taken);
}

impl Studio.drop_addon(path: str) {
    drop_classes(self.addons.get(path, []));
    self.addons.pop(path, None);
    self.classes_seen = "";
    label = self.addon_labels.get(path, "");
    self.addon_labels.pop(path, None);
    self.addon_textures.pop(label, None);
    self.addon_prefabs.pop(label, None);
    self.sync_addons();
}

impl Studio.sync_addons {
    stock = self.archive;
    if stock is not None {
        stock.extras = dict(self.addon_textures);
        # What was read of an add-on's files is read again.
        stock.found = {};
        stock.listed = {};
    }
    self.materials_changed += 1;
    self.folds += 1;
    # The library lists itself only when asked: what add-ons bring is asked for here.
    panel = self.ui;
    if panel is not None {
        self.list_library(panel);
    }
}

impl Studio.addon_words(path: str) -> str {
    label = self.addon_labels.get(path, "");
    stock = self.archive;
    pictures = len(stock.extra_names(label)) if stock is not None else 0;
    prefabs = 0;
    if label in self.addon_prefabs {
        prefabs = len([each for each in own_files(self.addon_prefabs[label]) if each.lower().endswith(".map")]);
    }
    return "studio: addon " + path + " classes=" + ",".join(self.addons.get(path, [])) + " name=" + label + " materials="
        + str(pictures) + " prefabs=" + str(prefabs);
}

impl Studio.apply_game(game: str) {
    if self.project is not None or game == self.game_applied {
        return;
    }
    self.game_applied = game;
    wanted = self.game_setup.get(game + ".material", "");
    if wanted {
        self.material = wanted;
        self.materials_changed += 1;
    }
    how = self.game_setup.get(game + ".build", "");
    if how == "flat" {
        self.lit = False;
    } elif how {
        self.lit = True;
        self.luxel = 16.0 if how == "full" else 32.0;
    }
    cell = self.game_setup.get(game + ".bake", "");
    if cell.isdigit() {
        self.vis_cell = float(int(cell));
    }
    if how or cell {
        self.built_geometry = -1;
    }
}

impl Studio.close_project {
    project = self.project;
    if project is None {
        return;
    }
    for addon in project.addons {
        self.drop_addon(self.project_folder + "/" + addon);
    }
    self.project = None;
    self.project_folder = "";
    self.folds += 1;
    stock = self.archive;
    if stock is not None {
        stock.folder = "";
    }
    self.materials_changed += 1;
    ui = self.ui;
    if ui is not None {
        ui.library.rows = [];
    }
}

impl Studio.open_project(folder: str) -> bool {
    text = "";
    try {
        with open(folder + "/" + MANIFEST_NAME, "r") as file {
            text = file.read();
        }
    } except OSError {
        return False;
    }
    self.close_project();
    project = read_project(text);
    self.project = project;
    self.project_folder = folder;
    self.folds += 1;
    stock = self.archive;
    if stock is not None {
        # Its image files are the ones offered as materials.
        stock.folder = folder + "/textures";
    }
    if project.material {
        self.material = project.material;
    }
    self.materials_changed += 1;
    if project.build == "flat" {
        self.lit = False;
    } elif project.build {
        self.lit = True;
        self.luxel = 16.0 if project.build == "full" else 32.0;
    }
    if project.bake >= 32 {
        self.vis_cell = float(project.bake);
    }
    self.built_geometry = -1;
    for addon in project.addons {
        if self.load_addon(folder + "/" + addon) < 0 {
            self.say("The project's add-on " + addon + " could not be read");
        }
    }
    ui = self.ui;
    if ui is not None {
        ui.library.rows = [];
    }
    return True;
}

impl Studio.project_words -> str {
    project = self.project;
    if project is None {
        return "studio: project none";
    }
    return "studio: project " + os.path.basename(self.project_folder) + " game=" + project.game + " start="
        + (project.start if project.start else "-") + " scenes=" + (",".join(sorted(project.scenes)) if project.scenes else "-")
        + " material=" + (project.material if project.material else "-") + " build="
        + (project.build if project.build else "-") + " bake=" + str(project.bake) + " addons=" + str(len(project.addons))
        + " recipes=" + str(len(project.recipes)) + " name=" + project.name;
}

impl Studio.project_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    project = self.project;
    if name == "ed_game" {
        games = ["passion", "q1", "q2", "q3"];
        if len(args) < 3 or args[1] not in games or args[2] not in ["material", "build", "bake"] {
            for game in games {
                print(
                    "studio: game " + game + " material=" + self.game_setup.get(game + ".material", "-") + " build="
                        + self.game_setup.get(game + ".build", "-") + " bake=" + self.game_setup.get(game + ".bake", "-")
                        + " dir=" + game_directory(game)
                );
            }
            self.say("ed_game <passion|q1|q2|q3> <material|build|bake> [value]: what a scene of that game begins with");
            return True;
        }
        key = args[1] + "." + args[2];
        value = args[3].strip() if len(args) > 3 else "";
        if args[2] == "build" and value and value not in ["full", "quick", "flat"] {
            self.say("ed_game " + args[1] + " build <full|quick|flat>");
            return True;
        }
        if args[2] == "bake" and value and (not value.isdigit() or int(value) < 32) {
            self.say("ed_game " + args[1] + " bake <cell>: 32 units wide or more");
            return True;
        }
        if value {
            self.game_setup[key] = value;
        } else {
            self.game_setup.pop(key, None);
        }
        self.keep_settings();
        # Taken up now when the scene in hand is of that game.
        self.game_applied = "";
        self.apply_game(scene.game);
        self.say(
            "A " + args[1] + " scene begins with " + args[2] + " " + value
            if value
            else "A " + args[1] + " scene begins with the " + args[2] + " in hand"
        );
        return True;
    }
    if name == "ed_addon" {
        how = args[1] if len(args) > 1 else "";
        if not how {
            for path in sorted(self.addons.keys()) {
                print(self.addon_words(path));
            }
            print(
                "studio: tools commands=" + str(len(STUDIO_COMMANDS)) + " classes=" + str(len(class_names()))
                    + " addons=" + str(len(self.addons)) + " recipes=" + str(len(self.all_recipes())) + " keys="
                    + str(len(self.user_keys))
            );
            self.say(
                str(len(self.addons)) + " add-ons: " + ", ".join([os.path.basename(path) for path in sorted(self.addons.keys())])
                if self.addons
                else "No add-ons are loaded (ed_addon <file>: a text file of class lines, and of the folders of textures and prefabs beside it)"
            );
            return True;
        }
        if how == "reload" {
            sought = args[2] if len(args) > 2 else "";
            count = 0;
            for path in sorted(self.addons.keys()) {
                if not sought or path == sought or os.path.basename(path) == sought {
                    taken = self.load_addon(path);
                    print("studio: reloaded " + path + " classes=" + str(taken));
                    count += 1;
                }
            }
            self.say("Read " + str(count) + " add-ons again" if count else "ed_addon reload: no such add-on is loaded");
            return True;
        }
        if how == "drop" {
            sought = args[2] if len(args) > 2 else "";
            for path in sorted(self.addons.keys()) {
                if path == sought or os.path.basename(path) == sought {
                    self.drop_addon(path);
                    if path in self.user_addons {
                        self.user_addons.remove(path);
                        self.keep_settings();
                    }
                    inside = self.project_folder + "/";
                    if project is not None and path.startswith(inside) and path[len(inside):] in project.addons {
                        project.addons.remove(path[len(inside):]);
                        self.save_project();
                    }
                    self.say("The add-on " + os.path.basename(path) + " is dropped, and its classes with it");
                    return True;
                }
            }
            self.say("ed_addon drop <file>: no such add-on is loaded");
            return True;
        }
        path = how;
        if not os.path.isfile(path) and project is not None and os.path.isfile(self.project_folder + "/" + how) {
            path = self.project_folder + "/" + how;
        }
        taken = self.load_addon(path);
        if taken < 0 {
            self.say("ed_addon: could not read " + how);
            return True;
        }
        inside = self.project_folder + "/";
        if project is not None and path.startswith(inside) {
            # The project's own: named in its manifest, to load with it.
            if path[len(inside):] not in project.addons {
                project.addons.append(path[len(inside):]);
                self.save_project();
            }
        } elif path not in self.user_addons {
            self.user_addons.append(path);
            self.keep_settings();
        }
        print("studio: addon " + path + " classes=" + ",".join(self.addons[path]));
        self.say(os.path.basename(path) + " adds " + str(taken) + " classes");
        return True;
    }
    if name != "ed_project" {
        return False;
    }
    how = args[1] if len(args) > 1 else "";
    if not how {
        print(self.project_words());
        self.say(
            "Project " + project.name + " in " + self.project_folder + ": " + str(len(project.scenes)) + " scenes"
            if project is not None
            else "No project is open (ed_project new <folder> [name], ed_project open <folder>)"
        );
        return True;
    }
    if how == "close" {
        self.close_project();
        self.say("The project is closed" if project is not None else "No project is open");
        return True;
    }
    if how == "new" or how == "open" {
        if len(args) < 3 or not args[2].strip() {
            self.say("ed_project " + how + " <folder>: a path, or a name under " + self.projects_folder());
            return True;
        }
        folder = args[2] if args[2].startswith("/") else self.projects_folder() + "/" + args[2];
        if how == "new" {
            if os.path.isfile(folder + "/" + MANIFEST_NAME) {
                self.say("There is a project in " + folder + " already (ed_project open)");
                return True;
            }
            self.close_project();
            words = " ".join(args[3:]).strip();
            self.project = Project(name=words if words else os.path.basename(folder), game="passion", material=self.material);
            self.project_folder = folder;
            self.folds += 1;
            self.save_project();
            for part in ["scenes", "prefabs", "textures"] {
                os.makedirs(folder + "/" + part, exist_ok=True);
            }
        }
        if not self.open_project(folder) {
            self.say("ed_project: no project in " + folder);
            return True;
        }
        at_hand = self.project;
        if at_hand is not None {
            first = folder + "/scenes/" + at_hand.start + ".map";
            if at_hand.start and os.path.isfile(first) {
                self.open_map(first);
            }
            self.say("Project " + at_hand.name + ": " + str(len(at_hand.scenes)) + " scenes, in " + folder);
        }
        return True;
    }
    if project is None {
        self.say("No project is open (ed_project new <folder> [name], ed_project open <folder>)");
        return True;
    }
    if how == "add" {
        if not self.is_built_scene() {
            self.say("A project's scenes are scenes of brushes (ed_convert makes one of a level)");
            return True;
        }
        self.save_scene(self.project_folder + "/scenes/" + file_name(scene.name[7:]) + ".map");
        return True;
    }
    sought = file_name(args[2]) if len(args) > 2 else "";
    if how == "drop" {
        if sought in project.scenes {
            # The file stays where it is; the project no longer counts it.
            project.scenes.remove(sought);
            if project.start == sought {
                project.start = sorted(project.scenes)[0] if project.scenes else "";
            }
            self.save_project();
            self.say(sought + " is no longer one of the project's scenes (its file is left)");
        } else {
            self.say("ed_project drop <scene>: " + ", ".join(sorted(project.scenes)));
        }
        return True;
    }
    if how == "start" {
        if sought in project.scenes {
            project.start = sought;
            self.save_project();
            self.say("The project opens with " + sought);
        } else {
            self.say("ed_project start <scene>: " + ", ".join(sorted(project.scenes)));
        }
        return True;
    }
    if how == "set" and len(args) > 2 and args[2] in ["name", "game", "material", "build", "bake"] {
        value = " ".join(args[3:]).strip();
        if args[2] == "name" and value {
            project.name = value;
        } elif args[2] == "game" and value in ["passion", "q1", "q2", "q3"] {
            project.game = value;
        } elif args[2] == "material" {
            # The one in hand when none is named.
            project.material = value if value else self.material;
            self.material = project.material;
            self.materials_changed += 1;
        } elif args[2] == "build" and value in ["full", "quick", "flat"] {
            project.build = value;
            self.lit = value != "flat";
            if self.lit {
                self.luxel = 16.0 if value == "full" else 32.0;
            }
            self.built_geometry = -1;
        } elif args[2] == "bake" and (value == "off" or (value.isdigit() and int(value) >= 32)) {
            project.bake = 0 if value == "off" else int(value);
            self.vis_cell = float(project.bake);
            self.built_geometry = -1;
        } else {
            self.say("ed_project set " + args[2] + ": not a value it takes");
            return True;
        }
        self.save_project();
        self.say("The project's " + args[2] + " is " + (value if value else project.material));
        return True;
    }
    self.say("ed_project [new|open <folder>] [close] [add] [drop|start <scene>] [set name|game|material|build|bake <value>]");
    return True;
}
