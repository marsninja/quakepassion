"""The studio's asset explorer and archive packing. Declarations live in
studio.jac."""

"""Every file under a folder on disk, as names with `/` between their
parts, sorted."""
def:priv files_under(folder: str) -> list[str] {
    found: list[str] = [];
    waiting: list[str] = [""];
    while len(waiting) > 0 {
        part = waiting.pop();
        here = folder + "/" + part if part else folder;
        for entry_name in sorted(os.listdir(here)) {
            path = here + "/" + entry_name;
            inner = part + "/" + entry_name if part else entry_name;
            if os.path.isdir(path) {
                waiting.append(inner);
            } elif os.path.isfile(path) {
                found.append(inner);
            }
        }
    }
    return sorted(found);
}

impl Studio.list_assets(ui: StudioUi) {
    rows: list[TreeRow] = [];
    shelf = self.archive;
    if shelf is None {
        rows.append(TreeRow(key="none", text="(no game archives found)", tone="faint"));
        ui.assets.rows = rows;
        return;
    }
    known = self.asset_index;
    if known is None {
        known = AssetIndex(shelf=shelf);
        self.asset_index = known;
    }
    seen = self.asset_now;
    titles = {"q1": "Quake", "q2": "Quake II", "q3": "Quake III Arena"};
    if self.asset_filter {
        # A search: every file whose name holds the text, flat, a few hundred at most.
        hits = 0;
        for game in known.games() {
            for name in known.names(game) {
                if self.asset_filter not in name.lower() {
                    continue;
                }
                if hits >= 400 {
                    break;
                }
                rows.append(
                    TreeRow(
                        key="file:" + game + ":" + name,
                        text=name,
                        note=game,
                        picked=seen is not None and seen.game == game and seen.name == name
                    )
                );
                hits += 1;
            }
        }
        if hits == 0 {
            rows.append(TreeRow(key="none", text="Nothing is named like that.", tone="faint"));
        }
        ui.assets.rows = rows;
        print("studio: found " + str(hits) + " files");
        return;
    }
    for game in known.games() {
        top = "dir:" + game + ":";
        unfolded = self.opened.get(top, False);
        rows.append(
            TreeRow(key=top, text=titles.get(game, game), branch=True, opened=unfolded, tone="accent")
        );
        if not unfolded {
            continue;
        }
        # What is still to list: a folder ("dir") or the files of one
        # ("files"), last in first out, so a folder's own folders come out
        # under it before its files do.
        waiting: list[tuple[str, str, int]] = [("dir", "", 1)];
        while len(waiting) > 0 {
            (what, folder, depth) = waiting.pop();
            inside = known.children(game, folder);
            if what == "files" {
                for name in inside[1] {
                    whole = (folder + "/" + name) if folder else name;
                    rows.append(
                        TreeRow(
                            key="file:" + game + ":" + whole,
                            text=name,
                            depth=depth,
                            picked=seen is not None and seen.game == game and seen.name == whole,
                            tone="dim" if file_kind(name) == "other" else "text"
                        )
                    );
                }
                continue;
            }
            if folder {
                key = "dir:" + game + ":" + folder;
                shown = self.opened.get(key, False);
                rows.append(
                    TreeRow(
                        key=key,
                        text=folder.split("/")[-1],
                        depth=depth - 1,
                        branch=True,
                        opened=shown,
                        note=str(len(inside[0]) + len(inside[1]))
                    )
                );
                if not shown {
                    continue;
                }
            }
            waiting.append(("files", folder, depth));
            for i in range(len(inside[0]) - 1, -1, -1) {
                name = inside[0][i];
                waiting.append(("dir", (folder + "/" + name) if folder else name, depth + 1));
            }
        }
    }
    ui.assets.rows = rows;
}

impl Studio.show_asset(ui: StudioUi) {
    form = ui.asset_form;
    for row in form.kids() {
        row.clear();
    }
    form.clear();
    if self.show_model_form(ui) {
        # The model being edited has the panel.
        return;
    }
    seen = self.asset_now;
    if seen is None {
        form.adopt(Label(text="Nothing is shown.", tone="dim"));
        form.adopt(Label(text="Open a game's folders and click a file.", tone="faint", small=True));
        return;
    }
    form.adopt(Label(text=seen.name.split("/")[-1], tone="accent"));
    form.adopt(Label(text=seen.game + ":" + seen.name, tone="dim", small=True));
    words = seen.kind + ", " + str(seen.size) + " bytes" + (", " + seen.note if seen.note else "");
    form.adopt(Label(text=words, tone="dim", small=True));
    figure = self.model_now;
    if figure is not None and figure.game == seen.game and figure.name == seen.name {
        form.adopt(
            Label(
                text=str(len(figure.model.surfaces)) + " surfaces, " + str(figure.triangles) + " triangles, "
                    + str(figure.vertices) + " vertices, " + str(figure.frames) + " frames",
                tone="dim",
                small=True
            )
        );
        form.adopt(ui.model_view);
        frames = Box(across=True, gap=4);
        form.adopt(frames);
        frames.adopt(PushButton(text="<", command="ed_frame prev", size=28, hint="The frame before"));
        frames.adopt(PushButton(text=">", command="ed_frame next", size=28, hint="The frame after"));
        frames.adopt(
            PushButton(
                text="Stop" if self.model_playing else "Play",
                command="ed_frame stop" if self.model_playing else "ed_frame play",
                size=56,
                hint="Run through the frames, ten a second"
            )
        );
        frames.adopt(
            Label(
                text="frame " + str(self.model_frame) + " of " + str(figure.frames) + "   "
                    + figure.frame_name(self.model_frame),
                tone="dim",
                grow=1
            )
        );
        form.adopt(
            PushButton(text="Extract", command="ed_extract", hint="Write this file under the extract folder")
        );
        return;
    }
    image = seen.image;
    if image is not None {
        key = "asset:" + seen.game + ":" + seen.name;
        kept = self.canvas.has_picture(key);
        if not kept {
            if len(image.rgba) >= image.width * image.height * 4 and image.width > 0 {
                self.canvas.keep_picture(key, image.width, image.height, image.rgba);
                kept = True;
            } elif len(image.encoded) > 0 {
                kept = self.canvas.keep_encoded(key, image.extension, image.encoded);
            }
        }
        if kept {
            size = self.canvas.picture_size(key);
            form.adopt(Label(text=str(size[0]) + " x " + str(size[1]) + " texels", tone="dim", small=True));
            form.adopt(Picture(key=key, grow=1));
        } else {
            form.adopt(Label(text="(this image could not be shown)", tone="faint", small=True));
            form.adopt(Spacer(grow=1));
        }
    } elif len(seen.lines) > 0 {
        page = Scroll(grow=1);
        form.adopt(page);
        text_box = Box(pad=2);
        page.adopt(text_box);
        for line in seen.lines {
            text_box.adopt(Label(text=line if line else " ", tone="text", small=True));
        }
    } else {
        form.adopt(Spacer(grow=1));
    }
    actions = Box(across=True, gap=4);
    form.adopt(actions);
    actions.adopt(
        PushButton(text="Extract", command="ed_extract", grow=1, hint="Write this file under the extract folder")
    );
    if seen.kind == "sound" {
        actions.adopt(PushButton(text="Play", command="ed_listen", grow=1, hint="Play this sound"));
    }
    if seen.material {
        actions.adopt(
            PushButton(
                text="Use as material",
                command="ed_material " + quote_command_word(seen.material),
                grow=1,
                hint="Give this texture to the selected faces or brushes, and to new brushes"
            )
        );
    }
}

impl Studio.asset_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    ui = self.ui;
    if name == "ed_asset" {
        word = args[1] if len(args) > 1 else "";
        parts = word.split(":", 2);
        if len(parts) < 3 or parts[0] not in ["dir", "file"] {
            self.say("ed_asset <dir:game:folder|file:game:name>");
            return True;
        }
        if parts[0] == "dir" {
            self.opened[word] = not self.opened.get(word, False);
            self.folds += 1;
            return True;
        }
        known = self.asset_index;
        if known is None {
            stock = self.archive;
            if stock is None {
                self.say("No game archives were found");
                return True;
            }
            known = AssetIndex(shelf=stock);
            self.asset_index = known;
        }
        self.asset_now = known.look(parts[1], parts[2]);
        self.model_now = None;
        self.model_playing = False;
        self.model_edges = [];
        stock_now = self.archive;
        if is_model(parts[2]) and stock_now is not None {
            figure = load_model(stock_now, parts[1], parts[2]);
            if figure is not None {
                self.model_now = figure;
                self.model_yaw = 0.6;
                self.model_pitch = -0.25;
                box = figure.bounds(0);
                self.model_middle = box[0].add(box[1]).scale(0.5);
                self.model_reach = max(32.0, box[1].sub(box[0]).length() * 1.2);
                self.set_frame(0);
            }
        }
        self.folds += 1;
        if ui is not None {
            self.show_asset(ui);
        }
        return True;
    }
    if name == "ed_frame" or name == "ed_orbit" {
        self.fresh_model();
        figure = self.model_now;
        if figure is None {
            self.say("Show a model in the explorer first");
            return True;
        }
        word = args[1] if len(args) > 1 else "";
        if name == "ed_orbit" {
            try {
                self.model_yaw = math.radians(float(word));
                self.model_pitch = math.radians(float(args[2])) if len(args) > 2 else self.model_pitch;
                if len(args) > 3 {
                    self.model_reach = max(8.0, float(args[3]));
                }
            } except ValueError {
                self.say("ed_orbit <yaw> <pitch> [distance]");
            }
            return True;
        }
        if word == "play" or word == "stop" {
            self.model_playing = word == "play";
        } elif word == "next" {
            self.set_frame((self.model_frame + 1) % figure.frames);
        } elif word == "prev" {
            self.set_frame((self.model_frame + figure.frames - 1) % figure.frames);
        } elif word.isdigit() {
            self.set_frame(min(int(word), figure.frames - 1));
        } else {
            self.say("ed_frame <number|next|prev|play|stop>");
            return True;
        }
        if ui is not None {
            self.show_asset(ui);
        }
        return True;
    }
    if name == "ed_listen" {
        heard = self.asset_now;
        app = self.app;
        if heard is None or heard.kind != "sound" or app is None {
            self.say("Show a sound in the explorer first");
            return True;
        }
        # The game's own sound player reads from the game that is loaded.
        library = app.audio.library;
        if library is None or library.game != heard.game or not library.exists(heard.name) {
            self.say("A " + heard.game + " sound plays while one of that game's levels is open");
            return True;
        }
        app.audio.play_path(heard.name);
        self.say("Playing " + heard.name);
        print("studio: played " + heard.name);
        return True;
    }
    if name == "ed_extract" {
        seen = self.asset_now;
        known = self.asset_index;
        if seen is None or known is None {
            self.say("Show a file in the explorer first (ed_layout assets)");
            return True;
        }
        folder = args[1] if len(args) > 1 else os.getenv("QP_EXTRACT", "");
        if not folder {
            folder = os.getcwd() + "/extracted";
        }
        data = known.read(seen.game, seen.name);
        if data is None {
            self.say("That file could not be read");
            return True;
        }
        path = folder + "/" + seen.game + "/" + seen.name;
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "wb") as file {
            file.write(data);
        }
        self.say("Wrote " + path);
        print("studio: extracted " + str(len(data)) + " bytes");
        return True;
    }
    if name == "ed_pack" {
        if len(args) < 3 or not (args[2].lower().endswith(".pak") or args[2].lower().endswith(".pk3")) {
            self.say("ed_pack <folder|scene> <out.pak|out.pk3>");
            return True;
        }
        files: list[tuple[str, bytes]] = [];
        if args[1] == "scene" {
            if not self.is_built_scene() {
                self.say("ed_pack scene packs a scene of brushes");
                return True;
            }
            short = scene.name[7:].replace("/", "_");
            files.append(("maps/" + short + ".map", write_map(scene_map(scene)).encode("utf-8")));
            known = self.asset_index;
            stock = self.archive;
            if known is None and stock is not None {
                known = AssetIndex(shelf=stock);
                self.asset_index = known;
            }
            used: list[str] = [];
            for brush in scene.solids() {
                for side in brush.sides {
                    if side.material not in used {
                        used.append(side.material);
                    }
                }
            }
            # The files its materials are in, where the games keep one each.
            if known is not None {
                for material in sorted(used) {
                    spots: list[tuple[str, str]] = [];
                    if material.startswith("q2:") {
                        spots.append(("q2", "textures/" + material[3:] + ".wal"));
                    } elif material.startswith("q3:") {
                        spots.append(("q3", material[3:] + ".tga"));
                        spots.append(("q3", material[3:] + ".jpg"));
                    }
                    for (game, inner) in spots {
                        data = known.read(game, inner);
                        if data is not None {
                            files.append((inner, data));
                            break;
                        }
                    }
                }
            }
        } else {
            if not os.path.isdir(args[1]) {
                self.say("ed_pack: no such folder " + args[1]);
                return True;
            }
            for inner in files_under(args[1]) {
                with open(args[1] + "/" + inner, "rb") as file {
                    files.append((inner, file.read()));
                }
            }
        }
        if len(files) == 0 {
            self.say("There is nothing to pack");
            return True;
        }
        packed = b"";
        try {
            packed = write_pak(files) if args[2].lower().endswith(".pak") else write_zip(files);
        } except ValueError as error {
            self.say(str(error));
            return True;
        }
        folder = os.path.dirname(args[2]);
        if folder {
            os.makedirs(folder, exist_ok=True);
        }
        with open(args[2], "wb") as file {
            file.write(packed);
        }
        self.say("Packed " + str(len(files)) + " files into " + args[2]);
        print("studio: packed " + str(len(files)) + " files, " + str(len(packed)) + " bytes");
        return True;
    }
    return False;
}

impl Studio.set_frame(frame: int) {
    figure = self.model_now;
    if figure is None {
        return;
    }
    self.model_frame = max(0, min(frame, figure.frames - 1));
    self.model_edges = figure.edges(self.model_frame);
    edited = self.model_doc;
    if edited is not None {
        # The model being edited goes to the frame the view shows.
        edited.frame = self.model_frame;
    }
}

impl Studio.turn_model(dt: float) {
    ui = self.ui;
    self.fresh_model();
    figure = self.model_now;
    if ui is None {
        return;
    }
    for event in ui.model_view.take() {
        if event.kind == "drag" {
            self.model_yaw -= float(event.dx) * 0.01;
            self.model_pitch = max(-1.5, min(1.5, self.model_pitch - float(event.dy) * 0.01));
        } elif event.kind == "wheel" {
            self.model_reach = max(8.0, self.model_reach * (0.85 ** event.wheel));
        }
    }
    if figure is None {
        return;
    }
    if self.model_playing {
        # Ten frames a second, as the games play most of them.
        self.model_clock += dt;
        if self.model_clock >= 0.1 {
            self.model_clock = 0.0;
            self.set_frame((self.model_frame + 1) % figure.frames);
        }
    }
    camera = self.model_camera;
    camera.span = 0.0;
    camera.yaw = self.model_yaw;
    camera.pitch = self.model_pitch;
    camera.eye = self.model_middle.sub(camera.forward().scale(self.model_reach));
}
