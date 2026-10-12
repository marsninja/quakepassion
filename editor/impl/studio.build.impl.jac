"""The studio's level converter, leak finder and duplicators. Declarations
live in studio.jac."""

"""The numbers among a duplicator command's words."""
def:priv dup_numbers(words: list[str]) -> list[float] {
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

impl Studio.build_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    app = self.app;
    if app is None {
        return False;
    }
    if name == "ed_convert" {
        if self.is_built_scene() {
            self.say("This is already a scene of brushes");
            return True;
        }
        fields: list[dict[str, str]] = [];
        for item in scene.items() {
            fields.append(dict(item.fields));
        }
        # The size each of the level's textures is drawn at as a material.
        drawn: dict[str, list[int]] = {};
        # A generated level's Quake textures go by their names alone: as
        # materials they are found by their maps too.
        renames: dict[str, str] = editor_material_names() if app.level.bsp.game == "passion" else {};
        for image in app.level.bsp.textures {
            named = level_material(app.level.bsp.game, image.name);
            if named and named not in drawn {
                seen_as = self.materials.texture(renames[named] if named in renames else named);
                drawn[named] = [max(1, seen_as.width), max(1, seen_as.height)];
            }
        }
        found = bsp_items(app.level.bsp, fields, self.material, drawn);
        if len(renames) > 0 {
            found = map_renamed(found, renames);
        }
        if len(found) == 0 {
            self.say(
                "This level keeps no brushes to turn back into a scene (Quake's own format does not; "
                    + "Quake II, Quake III and generated levels do)"
            );
            return True;
        }
        made = scene_from_map("passion", "studio:" + scene.name.replace("/", "_"), MapFile(items=found));
        made.path = self.scene_path(scene.name.replace("/", "_"));
        made.dirty = True;
        self.scenes["passion/" + made.name] = made;
        eye = self.main.eye;
        yaw = self.main.yaw;
        pitch = self.main.pitch;
        self.show_scene(made);
        # Looking at it from where the level was being looked at.
        self.main.eye = eye;
        self.main.yaw = yaw;
        self.main.pitch = pitch;
        self.say(
            "Turned " + scene.name + " into " + str(len(made.solids())) + " brushes and "
                + str(len(made.items())) + " entities"
        );
        return True;
    }
    if name == "ed_leak" {
        if len(args) > 1 and args[1] == "clear" {
            self.leak = [];
            return True;
        }
        if not self.is_built_scene() {
            self.say("The leak finder works on a scene of brushes (ed_convert makes one of a level)");
            return True;
        }
        walls: list[list[Side]] = [];
        starts: list[Vec3] = [];
        for item in scene.items() {
            kind = item.classname();
            if kind in ["worldspawn", "func_group"] {
                for solid in scene.solids_of(item) {
                    walls.append(solid.sides);
                }
            }
            at = item.origin();
            if at is not None and not kind.startswith("light") {
                starts.append(at);
            }
        }
        if len(starts) == 0 {
            self.say("There is no entity to flood from");
            return True;
        }
        outcome = find_leak(walls, starts);
        self.leak = outcome.path;
        if outcome.gave_up {
            self.say("The level is too large to flood at this cell size (" + str(outcome.cells) + " cells)");
            print("studio: leak gave up after " + str(outcome.cells));
        } elif outcome.sealed {
            self.say("The level is sealed: nothing inside it reaches the void");
            print("studio: leak sealed after " + str(outcome.cells));
        } else {
            self.say(
                "The level leaks: the red line runs " + str(len(outcome.path)) + " cells from an entity to the void"
            );
            if len(outcome.path) > 0 {
                last = outcome.path[-1];
                print(
                    "studio: leak ends " + str(int(round(last.x))) + " " + str(int(round(last.y))) + " "
                        + str(int(round(last.z)))
                );
            }
        }
        return True;
    }
    if name == "ed_dup" {
        how = args[1] if len(args) > 1 else "";
        if how == "hide" or how == "show" {
            # Whether what is built has the images in it at all.
            self.images_shown = how == "show";
            self.built_geometry = -1;
            self.say("Images are built" if self.images_shown else "Only what is in the document is built");
            return True;
        }
        if how == "images" {
            # The walker's work: which duplicators' images it made again and which it kept.
            walked = regenerate(scene, scene_map(scene));
            count = 0;
            for serial in sorted(walked.sets.keys()) {
                shown = scene.find(serial);
                pieces = sum([len(image_set) for image_set in walked.sets[serial]]);
                print(
                    "studio: dup #" + str(serial) + " " + (shown.title() if shown is not None else "?") + " images="
                        + str(len(walked.sets[serial])) + " brushes=" + str(pieces)
                );
                count += 1;
            }
            print("studio: dups " + str(count) + " made=" + str(walked.made) + " kept=" + str(walked.kept));
            self.say(str(count) + " duplicators: " + str(walked.made) + " made again, " + str(walked.kept) + " as they were");
            return True;
        }
        # A group, or any entity made of brushes.
        groups = [item for item in scene.selection() if len(scene.solids_of(item)) > 0 and item.classname() != "worldspawn"];
        if len(groups) == 0 and scene.selected_solids() and how not in ["off", "apply", ""] {
            # Loose brushes are grouped first.
            made_group = scene.group_selection("");
            if made_group is not None {
                groups = [made_group];
            }
        }
        if len(groups) == 0 {
            self.say("Select a group, or the brushes to copy");
            return True;
        }
        scene.clear_selection();
        for group in groups {
            scene.select(group, True);
        }
        nothing: dict[str, str | None] = {};
        for key in DUPLICATOR_KEYS {
            nothing[key] = None;
        }
        if how == "off" {
            if not scene.set_fields(nothing, "Stop copying") {
                self.say("It makes no copies");
            }
            return True;
        }
        if how == "apply" {
            count = 0;
            for group in groups {
                images: list[list[Side]] = [];
                for image_set in image_sets(
                    group.fields, [solid.sides for solid in scene.solids_of(group)], scene_map(scene)
                ) {
                    for sides in image_set {
                        images.append(sides);
                    }
                }
                if len(images) > 0 and scene.add_brushes(group, images, "Make copies real") {
                    count += len(images);
                }
            }
            scene.set_fields(nothing, "Stop copying");
            self.say("Made " + str(count) + " copies real" if count else "It makes no copies");
            return True;
        }
        if how == "mirror" {
            if len(args) < 3 or not args[2] or args[2].strip("xyz") != "" {
                self.say("ed_dup mirror <x|y|z, or several: xy, xyz>");
                return True;
            }
            scene.set_fields({"_mirror": args[2]}, "Mirror image");
            return True;
        }
        if how == "axis" {
            if len(args) < 3 or args[2] not in ["x", "y", "z"] {
                self.say("ed_dup axis <x|y|z>: what each copy turns about");
                return True;
            }
            scene.set_fields({"_axis": args[2]}, "Turn axis");
            return True;
        }
        if how == "grow" {
            factors = dup_numbers(args[2:]);
            if len(factors) not in [1, 3] or min(factors) <= 0.0 {
                self.say("ed_dup grow <factor> or <fx fy fz>: each copy's size against the last");
                return True;
            }
            scene.set_fields({"_grow": " ".join([str(round(factor, 4)) for factor in factors])}, "Grow copies");
            return True;
        }
        if how == "tile" {
            lengths = dup_numbers(args[2:]);
            if len(args) > 2 and args[2] in ["off", "none"] {
                scene.set_fields({"_tile": None}, "No tiles");
            } elif len(lengths) != 1 or lengths[0] <= 0.0 {
                self.say("ed_dup tile <length|off>: lay the copies along the path so far apart, with one turned at each bend");
            } else {
                scene.set_fields({"_tile": str(round(lengths[0], 3) + 0.0).rstrip("0").rstrip(".")}, "Tile along path");
            }
            return True;
        }
        if how == "at" or how == "path" {
            if len(args) < 3 {
                self.say("ed_dup " + how + " <targetname|none>");
                return True;
            }
            placing: dict[str, str | None] = {"_" + how: None};
            if args[2] != "none" {
                placing = {"_" + how: args[2]};
            }
            scene.set_fields(placing, "Images at " + args[2]);
            return True;
        }
        if how == "materials" {
            cycle: dict[str, str | None] = {"_materials": None};
            if len(args) > 2 and args[2] != "none" {
                cycle = {"_materials": " ".join(args[2:])};
            }
            scene.set_fields(cycle, "Material cycle");
            return True;
        }
        if how == "each" {
            apart: dict[str, str | None] = {"_each": "1"};
            if len(args) > 2 and args[2] in ["off", "0"] {
                apart = {"_each": None};
            }
            scene.set_fields(apart, "Images as entities");
            return True;
        }
        numbers = dup_numbers(args[1:]);
        if len(numbers) < 1 or numbers[0] < 1.0 {
            self.say(
                "ed_dup <copies> <dx> <dy> <dz> [turn] | mirror <axes> | axis <x|y|z> | grow <f> | at <name> | "
                    + "path <name> | materials <names> | each [on|off] | hide | show | off | apply"
            );
            return True;
        }
        pairs: dict[str, str | None] = {"_copies": str(int(numbers[0])), "_offset": None, "_turn": None};
        if len(numbers) >= 4 and (numbers[1] != 0.0 or numbers[2] != 0.0 or numbers[3] != 0.0) {
            pairs["_offset"] = str(int(numbers[1])) + " " + str(int(numbers[2])) + " " + str(int(numbers[3]));
        }
        if len(numbers) >= 5 and numbers[4] != 0.0 {
            pairs["_turn"] = str(int(numbers[4]));
        }
        if not scene.set_fields(pairs, "Copy as images") {
            self.say("It already does");
        }
        return True;
    }
    return False;
}
