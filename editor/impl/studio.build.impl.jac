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
        for image in app.level.bsp.textures {
            named = level_material(app.level.bsp.game, image.name);
            if named and named not in drawn {
                seen_as = self.materials.texture(named);
                drawn[named] = [max(1, seen_as.width), max(1, seen_as.height)];
            }
        }
        found = bsp_items(app.level.bsp, fields, self.material, drawn);
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
        groups = [item for item in scene.selection() if item.classname() == "func_group"];
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
        if how == "off" {
            if not scene.set_fields({"_copies": None, "_offset": None, "_turn": None, "_pivot": None, "_mirror": None}, "Stop copying") {
                self.say("It makes no copies");
            }
            return True;
        }
        if how == "apply" {
            count = 0;
            for group in groups {
                images = image_brushes(group.fields, [solid.sides for solid in scene.solids_of(group)]);
                if len(images) > 0 and scene.add_brushes(group, images, "Make copies real") {
                    count += len(images);
                }
            }
            scene.set_fields({"_copies": None, "_offset": None, "_turn": None, "_pivot": None, "_mirror": None}, "Stop copying");
            self.say("Made " + str(count) + " copies real" if count else "It makes no copies");
            return True;
        }
        if how == "mirror" {
            if len(args) < 3 or args[2] not in ["x", "y", "z"] {
                self.say("ed_dup mirror <x|y|z>");
                return True;
            }
            scene.set_fields({"_mirror": args[2]}, "Mirror image");
            return True;
        }
        numbers = dup_numbers(args[1:]);
        if len(numbers) < 1 or numbers[0] < 1.0 {
            self.say("ed_dup <copies> <dx> <dy> <dz> [turn] | mirror <x|y|z> | off | apply");
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
