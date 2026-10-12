"""The studio's clipboard, prefabs, library and logic graph. Declarations
live in studio.jac."""

"""The box round a map's brushes and origins: [low, high], or none when it
holds nothing that is anywhere."""
def:priv fragment_box(found: list[MapItem]) -> list[Vec3] | None {
    far = 1000000.0;
    low = Vec3(x=far, y=far, z=far);
    high = Vec3(x=-far, y=-far, z=-far);
    seen = False;
    for read in found {
        spots: list[Vec3] = [];
        for sides in read.brushes {
            box = windings_bounds(brush_windings(sides));
            if box is not None {
                spots.append(box[0]);
                spots.append(box[1]);
            }
        }
        at = read_vector(read.fields.get("origin", ""));
        if at is not None {
            spots.append(at);
        }
        for spot in spots {
            low = Vec3(x=min(low.x, spot.x), y=min(low.y, spot.y), z=min(low.z, spot.z));
            high = Vec3(x=max(high.x, spot.x), y=max(high.y, spot.y), z=max(high.z, spot.z));
            seen = True;
        }
    }
    if not seen {
        return None;
    }
    return [low, high];
}

def:priv instance_number(value: float) -> str {
    near = round(value, 4);
    return str(int(near)) if near == float(int(near)) else str(near);
}

impl Studio.prefab_path(name: str) -> str {
    folder = os.getenv("QP_PREFABS", "");
    if self.project_folder {
        folder = self.project_folder + "/prefabs";
    } elif not folder {
        folder = os.getcwd() + "/prefabs";
    }
    if name.startswith("addon:") {
        # An add-on's own prefab: under the folder its add-on named.
        halves = name[6:].split("/", 1);
        if len(halves) == 2 and halves[0] in self.addon_prefabs {
            return self.addon_prefabs[halves[0]] + "/" + shelf_name(halves[1]) + ".map";
        }
    }
    # A name may say folders of the shelf: no further up than the shelf itself.
    return folder + "/" + shelf_name(name) + ".map";
}

impl Studio.read_fragment(path: str) -> list[MapItem] | None {
    if not os.path.isfile(path) {
        self.say("No such file: " + path);
        return None;
    }
    text = "";
    with open(path, "r") as file {
        text = file.read();
    }
    try {
        return read_map(text).items;
    } except ValueError as error {
        self.say(str(error));
        return None;
    }
}

impl Studio.place_fragment(scene: Scene, found: list[MapItem], label: str, group: str = "") -> bool {
    app = self.app;
    box = fragment_box(found);
    if app is None or box is None {
        return False;
    }
    eye = self.main.eye;
    ahead = self.main.forward();
    trace = app.level.collision.trace_point(eye, eye.add(ahead.scale(1024.0)));
    spot = eye.add(ahead.scale(256.0));
    if trace.fraction < 1.0 and not trace.start_solid {
        spot = eye.add(ahead.scale(1024.0 * trace.fraction));
    }
    # Its middle over the point, its underside on it.
    middle = box[0].add(box[1]).scale(0.5);
    snap = 16.0;
    offset = Vec3(
        x=float(round((spot.x - middle.x) / snap)) * snap,
        y=float(round((spot.y - middle.y) / snap)) * snap,
        z=float(round((spot.z - box[0].z) / snap)) * snap
    );
    return scene.insert_map(found, offset, label, group);
}

impl Studio.expanded(scene: Scene) -> Scene {
    linked = False;
    for item in scene.items() {
        if item.classname() == "misc_prefab" or duplicates(item.fields) or digs(item.fields) or makes(item.fields) {
            linked = True;
        }
    }
    if not linked {
        return scene;
    }
    plain: list[MapItem] = [];
    # Makers' brushes are made before the diggers cut: a hole goes through a made wall too.
    # Each duplicator's images, made again only where what they copy has changed.
    for read in with_holes(with_makers(with_regenerated(scene, scene_map(scene)) if self.images_shown else scene_map(scene))) {
        if read.fields.get("classname", "") != "misc_prefab" {
            plain.append(read);
        }
    }
    whole = scene_from_map(scene.game, scene.name, MapFile(items=plain));
    for item in scene.items() {
        if item.classname() != "misc_prefab" {
            continue;
        }
        # With the prefabs it holds put in, and changed as this instance says.
        found = self.prefab_items(item.fields.get("prefab", ""), []);
        if found is None {
            continue;
        }
        # A linked prefab stands with the middle of its underside on its origin, sized and turned as it says.
        stood = prefab_placed(found, item.fields);
        if len(stood) > 0 {
            whole.insert_map(stood, Vec3());
        }
    }
    return whole;
}

impl Studio.list_library(ui: StudioUi) {
    rows: list[TreeRow] = [];
    shelves = [
        ("Scenes", "scene:", os.path.dirname(self.scene_path("x"))),
        ("Prefabs", "prefab:", os.path.dirname(self.prefab_path("x"))),
        ("Autosaved", "auto:", os.path.dirname(self.autosave_path("x")))
    ];
    for (named, lead, folder) in shelves {
        names: list[str] = [];
        if named == "Prefabs" {
            # Prefabs are kept in folders: every map under the shelf, by its path from it.
            names = [found_file[:-4] for found_file in own_files(folder) if found_file.lower().endswith(".map")];
        } elif os.path.isdir(folder) {
            for entry_name in sorted(os.listdir(folder)) {
                if entry_name.lower().endswith(".map") {
                    names.append(entry_name[:-4]);
                }
            }
        }
        sought = self.library_filter.strip().lower();
        if sought {
            # Found by name: listed flat under their shelf, whatever folder they are in.
            names = [known for known in names if sought in known.lower()];
        }
        rows.append(TreeRow(key="shelf:" + named, text=named, tone="accent", note=str(len(names))));
        if named == "Prefabs" and not sought {
            for shelved in shelf_rows(names, lead, "prefabdir:", self.opened) {
                rows.append(
                    TreeRow(
                        key=shelved.key,
                        text=shelved.text,
                        depth=shelved.depth,
                        branch=shelved.folder,
                        opened=shelved.opened,
                        note=str(shelved.count) if shelved.folder else ""
                    )
                );
            }
            continue;
        }
        for known in names {
            rows.append(TreeRow(key=lead + known, text=known, depth=1));
        }
    }
    # What add-ons bring: each one's prefabs under its name.
    for label in sorted(self.addon_prefabs.keys()) {
        brought = [
            each[:-4]
            for each in own_files(self.addon_prefabs[label])
            if each.lower().endswith(".map") and self.library_filter.strip().lower() in each.lower()
        ];
        rows.append(TreeRow(key="shelf:addon:" + label, text="Add-on " + label, tone="accent", note=str(len(brought))));
        for each in brought {
            rows.append(TreeRow(key="prefab:addon:" + label + "/" + each, text=each, depth=1));
        }
    }
    # After the shelves of files: what is open now, and what was lately.
    current = self.scene;
    docs = self.doc_keys();
    rows.append(TreeRow(key="shelf:Open now", text="Open now", tone="accent", note=str(len(docs))));
    for key in docs {
        held = self.scenes[key];
        rows.append(
            TreeRow(
                key="doc:" + key,
                text=held.name + ("  (edited)" if held.dirty else ""),
                depth=1,
                picked=held is current
            )
        );
    }
    lately = self.recent_files();
    rows.append(TreeRow(key="shelf:Recent", text="Recent", tone="accent", note=str(len(lately))));
    for path in lately {
        rows.append(TreeRow(key="recent:" + path, text=os.path.basename(path), depth=1));
    }
    rows.append(TreeRow(key="shelf:Favourites", text="Favourites", tone="accent", note=str(len(self.favourites))));
    for kept_class in self.favourites {
        rows.append(TreeRow(key="fav:" + kept_class, text=kept_class, depth=1));
    }
    if len(self.favourites) > 0 {
        rows.append(TreeRow(key="trash:fav", text="Trash: drag a favourite here to forget it", depth=1, tone="faint", fixed=True));
    }
    # Pieces of logic as the scene's game has them.
    sought_now = self.library_filter.strip().lower();
    scene_now = self.scene;
    logic_game = scene_now.game if scene_now is not None and scene_now.game in ["q1", "q2", "q3"] else "q1";
    gadgets = [piece[0] for piece in LOGIC_PIECES if piece[1] == logic_game and (not sought_now or sought_now in piece[0])];
    rows.append(TreeRow(key="shelf:Logic", text="Logic", tone="accent", note=str(len(gadgets))));
    for gadget in gadgets {
        rows.append(TreeRow(key="gadget:" + gadget, text=gadget, depth=1));
    }
    # Materials, models and sounds: so many that they are listed only for
    # what the find field asks for, forty of each at most.
    if sought_now {
        # Those the Materials tab shows, its shelf's, those lately in hand
        # and those the scene's brushes are made of.
        offered: list[str] = [tile.key for tile in ui.gallery.tiles] + list(self.recent_materials);
        shelf_now = self.archive;
        if shelf_now is not None and self.shelf and ":" in self.shelf {
            offered.extend(shelf_now.names(self.shelf));
        }
        if scene_now is not None {
            for brush in scene_now.solids()[:2000] {
                for side in brush.sides {
                    offered.append(side.material);
                }
            }
        }
        materials: list[str] = [];
        for material in offered {
            if material and sought_now in material.lower() and material not in materials {
                materials.append(material);
            }
        }
        materials = materials[:40];
        rows.append(TreeRow(key="shelf:Materials", text="Materials", tone="accent", note=str(len(materials))));
        for material in materials {
            rows.append(TreeRow(key="mat:" + material, text=material.split("/")[-1].split(":")[-1], depth=1, note=material));
        }
        listing = self.asset_index;
        stock = self.archive;
        if listing is None and stock is not None {
            listing = AssetIndex(shelf=stock);
            self.asset_index = listing;
        }
        for (called, lead, endings) in [
            ("Models", "model:", [".mdl", ".md2", ".md3"]), ("Sounds", "sound:", [".wav"])
        ] {
            found: list[str] = [];
            if listing is not None {
                for game in listing.games() {
                    for file_name in listing.names(game) {
                        low = file_name.lower();
                        if sought_now in low and len([ending for ending in endings if low.endswith(ending)]) > 0 {
                            found.append(game + ":" + file_name);
                        }
                        if len(found) >= 40 {
                            break;
                        }
                    }
                }
            }
            rows.append(TreeRow(key="shelf:" + called, text=called, tone="accent", note=str(len(found))));
            for whole_name in found {
                halves = whole_name.split(":", 1);
                rows.append(
                    TreeRow(key=lead + whole_name, text=halves[1].split("/")[-1] + "  (" + halves[0] + ")", depth=1, note=halves[1])
                );
            }
        }
    }
    ui.library.rows = rows;
}

impl Studio.fill_graph(scene: Scene, ui: StudioUi) {
    boxes: list[GraphNode] = [];
    arrows: list[GraphLink] = [];
    for node in scene.logic_nodes() {
        item = node.item;
        name = item.fields.get("targetname", "");
        fired = item.fields.get("target", "");
        words = name;
        if fired {
            words = (name + "  ->  " + fired) if name else ("->  " + fired);
        }
        # In the game last played from here: how often it fired, and
        # whether its firing holds the game.
        times = self.fired_names.get(self.signal_label(item.fields), 0);
        if times > 0 {
            words += "   fired x" + str(times);
        }
        if self.signal_label(item.fields) in self.breaks {
            words += "   [holds]";
        }
        boxes.append(
            GraphNode(
                key=str(item.serial),
                text=item.classname(),
                note=words,
                column=node.column,
                row=node.row,
                tone="good" if times > 0 else "text",
                picked=scene.is_selected(item)
            )
        );
        for other in scene.fires(item) {
            arrows.append(GraphLink(source=str(item.serial), dest=str(other.serial)));
        }
    }
    # What is selected stands in the first column too, so two entities that
    # fire nothing yet can be picked in the level and linked here.
    below = 0;
    for box in boxes {
        if box.column == 0 {
            below = max(below, box.row + 1);
        }
    }
    for item in scene.selection() {
        known = False;
        for box in boxes {
            if box.key == str(item.serial) {
                known = True;
            }
        }
        if known or item.classname() == "worldspawn" {
            continue;
        }
        boxes.append(
            GraphNode(
                key=str(item.serial),
                text=item.classname(),
                note=item.fields.get("targetname", ""),
                column=0,
                row=below,
                tone="dim",
                picked=True
            )
        );
        below += 1;
    }
    ui.logic.nodes = boxes;
    ui.logic.links = arrows;
}

impl Studio.library_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    ui = self.ui;
    if name == "ed_copy" or name == "ed_cut" {
        copied = scene.selection_map();
        if len(copied) == 0 {
            self.say("Nothing to copy");
            return True;
        }
        self.clip = write_map(copied);
        if not self.source.scripted {
            self.canvas.copy(self.clip);
        }
        if name == "ed_cut" {
            scene.remove_selection();
        }
        self.say(("Cut " if name == "ed_cut" else "Copied ") + str(len(copied)) + " things");
        return True;
    }
    if name == "ed_paste" {
        text = self.clip;
        if not self.source.scripted {
            # Map text copied in another editor pastes too.
            outside = self.canvas.copied();
            if "{" in outside and "classname" in outside {
                text = outside;
            }
        }
        pasting: list[MapItem] = [];
        try {
            pasting = read_map(text).items;
        } except ValueError {
            pasting = [];
        }
        if len(pasting) == 0 {
            self.say("Nothing has been copied");
            return True;
        }
        pasted = False;
        if len(args) > 1 and args[1] == "here" {
            pasted = self.place_fragment(scene, pasting, "Paste");
        } else {
            pasted = scene.insert_map(pasting, Vec3(x=16.0, y=16.0), "Paste");
        }
        if not pasted {
            self.say("Nothing to paste");
        }
        return True;
    }
    if name == "ed_group" {
        group = scene.group_selection(args[1].strip() if len(args) > 1 else "");
        if group is None {
            self.say("Select the brushes to group");
        } else {
            self.say("Grouped as " + group.fields.get("_group_name", ""));
        }
        return True;
    }
    if name == "ed_import" {
        if len(args) < 2 {
            self.say("ed_import <file.map> [group]");
            return True;
        }
        brought = self.read_fragment(args[1]);
        if brought is not None
            and not self.place_fragment(scene, brought, "Import", args[2] if len(args) > 2 else "") {
            self.say("That map holds nothing to add");
        }
        return True;
    }
    if name == "ed_prefab" {
        how = args[1] if len(args) > 1 else "";
        named = args[2].strip() if len(args) > 2 else "";
        if how == "save" and not named and ui is not None {
            named = ui.prefab_name.text_now().strip();
        }
        if how == "unlink" {
            done = 0;
            for item in scene.selection() {
                at = item.origin();
                if item.classname() != "misc_prefab" or at is None {
                    continue;
                }
                inside = self.prefab_items(item.fields.get("prefab", ""), []);
                if inside is None {
                    continue;
                }
                # What it stood for, where it stood, sized and turned as it was.
                changed_copy = prefab_placed(inside, item.fields);
                if len(changed_copy) == 0 {
                    continue;
                }
                scene.select(item);
                scene.remove_selection();
                scene.insert_map(changed_copy, Vec3(), "Unlink prefab");
                done += 1;
            }
            self.say("Turned " + str(done) + " linked prefabs into copies" if done else "Select linked prefabs first");
            return True;
        }
        if how == "move" {
            # Another name, or another folder of the shelf: the file goes there.
            going = shelf_name(args[3]) if len(args) > 3 else "";
            came = self.prefab_path(named);
            if not named or not going or not os.path.isfile(came) {
                self.say("ed_prefab move <name> <new name>: a prefab that is there, and where it is to go (folders/name)");
                return True;
            }
            went = self.prefab_path(going);
            if os.path.exists(went) {
                self.say("There is a prefab called " + going + " already");
                return True;
            }
            os.makedirs(os.path.dirname(went), exist_ok=True);
            os.rename(came, went);
            print("studio: prefab moved " + shelf_name(named) + " > " + going);
            self.say(shelf_name(named) + " is " + going + " now (entities that link it by its old name do not follow)");
            if ui is not None {
                self.list_library(ui);
            }
            return True;
        }
        if how not in ["save", "add", "link"] or not named {
            self.say("ed_prefab <save|add|link|unlink|move> [name]: a name may say folders (props/crate)");
            return True;
        }
        path = self.prefab_path(named);
        if how == "save" {
            copied = scene.selection_map();
            if len(copied) == 0 {
                self.say("Select what the prefab is made of");
                return True;
            }
            os.makedirs(os.path.dirname(path), exist_ok=True);
            with open(path, "w") as file {
                file.write(write_map(copied));
            }
            self.say("Saved prefab " + named);
            if ui is not None {
                self.list_library(ui);
            }
            return True;
        }
        kept = self.read_fragment(path);
        if kept is None {
            return True;
        }
        if how == "add" {
            if not self.place_fragment(scene, kept, "Add " + named, named) {
                self.say("That prefab holds nothing");
            }
            return True;
        }
        # A linked prefab: one entity that stands for the file's contents.
        marker = [MapItem(fields={"classname": "misc_prefab", "prefab": named, "origin": "0 0 0"})];
        if not self.place_fragment(scene, marker, "Link " + named) {
            self.say("Could not place " + named);
        }
        return True;
    }
    if name == "ed_libfind" {
        self.library_filter = " ".join(args[1:]).strip();
        if ui is not None {
            self.list_library(ui);
        }
        print("studio: library find=" + (self.library_filter if self.library_filter else "-") + " rows=" + str(len(ui.library.rows) if ui is not None else 0));
        return True;
    }
    if name == "ed_library" {
        if ui is None {
            return True;
        }
        word = args[1] if len(args) > 1 else "";
        if word.startswith("scene:") {
            self.open_map(self.scene_path(word[6:]));
        } elif word.startswith("auto:") {
            self.open_map(self.autosave_path(word[5:]));
        } elif word.startswith("prefabdir:") {
            # A folder of prefabs: opened, or shut.
            self.opened[word] = not self.opened.get(word, False);
            self.list_library(ui);
        } elif word.startswith("prefab:") {
            self.library_command(scene, ["ed_prefab", "add", word[7:]]);
        } elif word.startswith("fav:") {
            self.class_command(scene, ["ed_class", word[4:]]);
        } elif word.startswith("gadget:") {
            self.command(["ed_logic", word[7:]]);
        } elif word.startswith("mat:") {
            self.command(["ed_material", word[4:]]);
        } elif word.startswith("model:") or word.startswith("sound:") {
            # Shown in the explorer, as any file of a game is.
            self.command(["ed_asset", "file:" + word[6:]]);
        } elif word.startswith("doc:") {
            self.show_doc(word[4:]);
        } elif word.startswith("recent:") {
            self.open_map(word[7:]);
        } else {
            self.list_library(ui);
        }
        return True;
    }
    if name == "ed_link" or name == "ed_unlink" {
        first = scene.find(int(args[1])) if len(args) > 1 and args[1].isdigit() else None;
        second = scene.find(int(args[2])) if len(args) > 2 and args[2].isdigit() else None;
        if first is None or (name == "ed_link" and second is None) {
            self.say(name + " <from> " + ("<to>" if name == "ed_link" else "[to]") + " takes entities' numbers");
            return True;
        }
        if name == "ed_link" and second is not None {
            if scene.link(first, second) {
                self.say(first.title() + " now fires " + second.title());
            } else {
                self.say("It already does");
            }
        } elif name == "ed_unlink" {
            if not scene.unlink(first, second) {
                self.say("It fires nothing to stop");
            }
        }
        return True;
    }
    return False;
}

impl Studio.prefab_items(name: str, trail: list[str]) -> list[MapItem] | None {
    found = self.read_fragment(self.prefab_path(name));
    if found is None {
        return None;
    }
    # The prefabs it holds, each read the same way: not one that holds
    # itself, however far down, and no deeper than eight.
    inner: dict[str, list[MapItem]] = {};
    for item in found {
        wanted = item.fields.get("prefab", "");
        if item.fields.get("classname", "") != "misc_prefab" or not wanted or wanted in inner {
            continue;
        }
        if wanted == name or wanted in trail or len(trail) >= 8 {
            continue;
        }
        held = self.prefab_items(wanted, trail + [name]);
        if held is not None {
            inner[wanted] = held;
        }
    }
    return with_prefabs(found, inner);
}

impl Studio.prefab_change(scene: Scene, args: list[str]) -> bool {
    how = args[1] if len(args) > 1 else "";
    if args[0] != "ed_prefab" or how not in ["swap", "put", "names", "plain", "turn", "scale"] {
        return False;
    }
    chosen = [item for item in scene.selection() if item.classname() == "misc_prefab"];
    if len(chosen) == 0 {
        self.say("Select the linked prefabs to change (ed_prefab link <name> adds one)");
        return True;
    }
    first = chosen[0];
    told: dict[str, str | None] = {};
    if how == "plain" {
        told = {"_swap": None, "_put": None, "_names": None, "_scale": None, "angle": None, "angles": None};
    } elif how == "turn" and len(args) > 2 {
        # Round the upright through where it stands, by so much more.
        try {
            more = float(args[2]);
        } except ValueError {
            self.say("ed_prefab turn <degrees>");
            return True;
        }
        about = args[3] if len(args) > 3 else "yaw";
        if about not in ["pitch", "yaw", "roll"] {
            self.say("ed_prefab turn <degrees> [pitch|roll]: round the upright, or tipped nose down, or rolled about its length");
            return True;
        }
        tipped = prefab_turns(first.fields);
        place = ["pitch", "yaw", "roll"].index(about);
        tipped[place] = (tipped[place] + more) % 360.0;
        if tipped[0] == 0.0 and tipped[2] == 0.0 {
            # Only round the upright: the one number every entity has.
            told = {"angle": instance_number(tipped[1]) if tipped[1] != 0.0 else None, "angles": None};
        } else {
            told = {"angles": " ".join([instance_number(turn) for turn in tipped]), "angle": None};
        }
    } elif how == "scale" and len(args) > 2 {
        sizes: list[float] = [];
        for word in args[2:5] {
            try {
                sizes.append(float(word));
            } except ValueError {
                sizes = [];
                break;
            }
        }
        flat = len([size for size in sizes if abs(size) < 0.001]) > 0;
        if (len(sizes) != 1 and len(sizes) != 3) or flat {
            self.say("ed_prefab scale <times> | <x> <y> <z>: how many times as large (not nothing)");
            return True;
        }
        whole_size = len(sizes) == 1 or (sizes[0] == sizes[1] and sizes[1] == sizes[2]);
        if whole_size and sizes[0] == 1.0 {
            told = {"_scale": None};
        } else {
            told = {"_scale": instance_number(sizes[0]) if whole_size else " ".join([instance_number(size) for size in sizes])};
        }
    } elif how == "swap" and len(args) > 3 {
        # One more pair, after those it has.
        told = {"_swap": (first.fields.get("_swap", "") + " " + args[2] + " " + args[3]).strip()};
    } elif how == "put" and len(args) > 4 {
        before = first.fields.get("_put", "");
        told = {"_put": (before + "; " if before else "") + args[2] + " " + args[3] + " " + " ".join(args[4:])};
    } elif how == "names" and len(args) > 2 {
        told = {"_names": args[2]};
    } else {
        self.say("ed_prefab swap <old> <new> | put <classname|name> <key> <value> | names <word> | turn <degrees> [pitch|roll] | scale <times>|<x y z> | plain");
        return True;
    }
    if not scene.set_fields(told, "Prefab instance") {
        self.say("It is so already");
    } else {
        self.say("This instance differs from its prefab: " + how);
    }
    return True;
}

impl Studio.preview_library(ui: StudioUi) {
    view = self.library_view;
    if view is None {
        return;
    }
    rows = ui.library.rows;
    at = ui.library.hover_row;
    key = rows[at].key if at >= 0 and at < len(rows) else "";
    shown_kinds = ["prefab:", "model:", "sound:", "mat:"];
    if len([lead for lead in shown_kinds if key.startswith(lead)]) == 0 or key == self.library_previewed {
        # What was last looked at stays until another thing with a picture is.
        return;
    }
    self.library_previewed = key;
    tint = self.canvas.theme.accent;
    if key.startswith("model:") {
        # A model as its first frame's edges.
        edges = [(pair[0], pair[1]) for pair in self.preview_edges(key[6:])];
        view.shown = len(edges) > 0;
        if len(edges) > 0 {
            self.canvas.keep_picture("library:preview", 240, 180, sketch(edges, 240, 180, tint.r, tint.g, tint.b));
        }
        return;
    }
    if key.startswith("sound:") {
        # A sound as its shape.
        halves = key[6:].split(":", 1);
        listing = self.asset_index;
        data = listing.read(halves[0], halves[1]) if listing is not None and len(halves) == 2 else None;
        view.shown = False;
        if data is not None {
            try {
                layout = parse_wav_pcm(data);
                heard = data[layout.offset:layout.offset + layout.length];
                self.canvas.keep_picture(
                    "library:preview", 240, 90, waveform(heard, layout.width, layout.channels, 240, 90, tint.r, tint.g, tint.b)
                );
                view.shown = True;
            } except Exception {
                view.shown = False;
            }
        }
        return;
    }
    if key.startswith("mat:") {
        picture = self.materials.texture(key[4:]);
        colours = texture_rgba(picture) if picture is not None else b"";
        view.shown = len(colours) > 0;
        if len(colours) > 0 {
            self.canvas.keep_picture("library:preview", picture.width, picture.height, colours);
        }
        return;
    }
    brushes: list[list[Side]] = [];
    try {
        with open(self.prefab_path(key[7:]), "r") as file {
            for item in read_map(file.read()).items {
                for sides in item.brushes {
                    brushes.append(sides);
                }
            }
        }
    } except Exception {
        brushes = [];
    }
    view.shown = len(brushes) > 0;
    if len(brushes) > 0 {
        self.canvas.keep_picture("library:preview", 240, 180, sketch(sketch_edges(brushes), 240, 180, tint.r, tint.g, tint.b));
    }
}
