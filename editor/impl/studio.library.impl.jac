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

impl Studio.prefab_path(name: str) -> str {
    folder = os.getenv("QP_PREFABS", "");
    if not folder {
        folder = os.getcwd() + "/prefabs";
    }
    return folder + "/" + name.replace("/", "_") + ".map";
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
        if item.classname() == "misc_prefab" {
            linked = True;
        }
    }
    if not linked {
        return scene;
    }
    plain: list[MapItem] = [];
    for read in scene_map(scene) {
        if read.fields.get("classname", "") != "misc_prefab" {
            plain.append(read);
        }
    }
    whole = scene_from_map(scene.game, scene.name, MapFile(items=plain));
    for item in scene.items() {
        if item.classname() != "misc_prefab" {
            continue;
        }
        found = self.read_fragment(self.prefab_path(item.fields.get("prefab", "")));
        at = item.origin();
        if found is None or at is None {
            continue;
        }
        box = fragment_box(found);
        if box is None {
            continue;
        }
        # A linked prefab stands with the middle of its underside on its origin.
        middle = box[0].add(box[1]).scale(0.5);
        whole.insert_map(found, Vec3(x=at.x - middle.x, y=at.y - middle.y, z=at.z - box[0].z));
    }
    return whole;
}

impl Studio.list_library(ui: StudioUi) {
    rows: list[TreeRow] = [];
    shelves = [
        ("Scenes", "scene:", os.path.dirname(self.scene_path("x"))),
        ("Prefabs", "prefab:", os.path.dirname(self.prefab_path("x")))
    ];
    for (named, lead, folder) in shelves {
        names: list[str] = [];
        if os.path.isdir(folder) {
            for entry_name in sorted(os.listdir(folder)) {
                if entry_name.lower().endswith(".map") {
                    names.append(entry_name[:-4]);
                }
            }
        }
        rows.append(TreeRow(key="shelf:" + named, text=named, tone="accent", note=str(len(names))));
        for known in names {
            rows.append(TreeRow(key=lead + known, text=known, depth=1));
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
        boxes.append(
            GraphNode(
                key=str(item.serial),
                text=item.classname(),
                note=words,
                column=node.column,
                row=node.row,
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
                inside = self.read_fragment(self.prefab_path(item.fields.get("prefab", "")));
                if inside is None {
                    continue;
                }
                box = fragment_box(inside);
                if box is None {
                    continue;
                }
                middle = box[0].add(box[1]).scale(0.5);
                scene.select(item);
                scene.remove_selection();
                scene.insert_map(inside, Vec3(x=at.x - middle.x, y=at.y - middle.y, z=at.z - box[0].z), "Unlink prefab");
                done += 1;
            }
            self.say("Turned " + str(done) + " linked prefabs into copies" if done else "Select linked prefabs first");
            return True;
        }
        if how not in ["save", "add", "link"] or not named {
            self.say("ed_prefab <save|add|link|unlink> [name]");
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
    if name == "ed_library" {
        if ui is None {
            return True;
        }
        word = args[1] if len(args) > 1 else "";
        if word.startswith("scene:") {
            self.open_map(self.scene_path(word[6:]));
        } elif word.startswith("prefab:") {
            self.library_command(scene, ["ed_prefab", "add", word[7:]]);
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
