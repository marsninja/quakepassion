"""What a scene uses and what uses a thing: the materials on its brushes and
the sounds and models its entities name, each with whether an archive holds
it; and, for one of them, every brush and entity that uses it. Declarations
live in studio.jac."""

impl Studio.uses_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_uses" {
        return False;
    }
    ui = self.ui;
    stock = self.archive;
    listing = self.asset_index;
    if listing is None and stock is not None {
        listing = AssetIndex(shelf=stock);
        self.asset_index = listing;
    }
    if len(args) > 1 {
        # What uses it: brushes with a side of that material, entities that name that file.
        wanted = args[1];
        scene.clear_selection();
        brushes = 0;
        for brush in scene.solids() {
            if len([side for side in brush.sides if side.material == wanted]) > 0 {
                scene.select_solid(brush, add=True);
                brushes += 1;
            }
        }
        entities = 0;
        for item in scene.items() {
            game = scene.game if scene.game in ["q1", "q2", "q3"] else item.fields.get("asset_game", "");
            if names_file(game, item.fields, wanted) {
                scene.select(item, add=True);
                entities += 1;
            }
        }
        print("studio: used " + wanted + " brushes=" + str(brushes) + " entities=" + str(entities));
        self.say(
            "Nothing here uses " + wanted
            if brushes + entities == 0
            else wanted + " is used by " + str(brushes) + (" brush" if brushes == 1 else " brushes") + " and " + str(entities)
                + (" entity" if entities == 1 else " entities") + ": they are selected"
        );
        return True;
    }
    # Everything it uses, and what of that is not there.
    sides_of: dict[str, int] = {};
    for brush in scene.solids() {
        for side in brush.sides {
            if side.material {
                sides_of[side.material] = sides_of.get(side.material, 0) + 1;
            }
        }
    }
    rows: list[TreeRow] = [];
    lacking = 0;
    rows.append(TreeRow(key="none", text="Materials", tone="accent", note=str(len(sides_of))));
    for name in sorted(sides_of.keys()) {
        gone = stock is not None and ":" in name and name.split(":", 1)[0] in ["q1", "q2", "q3", "file"] and stock.fetch(name) is None;
        lacking += 1 if gone else 0;
        print("studio: uses material " + name + " sides=" + str(sides_of[name]) + (" missing" if gone else ""));
        rows.append(
            TreeRow(key="uses:" + name, text=name + ("  (missing)" if gone else ""), depth=1, note=str(sides_of[name]), tone="text" if not gone else "accent")
        );
    }
    named_by: dict[str, int] = {};
    kinds: dict[str, str] = {};
    held: dict[str, set[str]] = {};
    absent: list[str] = [];
    for item in scene.items() {
        game = scene.game if scene.game in ["q1", "q2", "q3"] else item.fields.get("asset_game", "");
        if game not in ["q1", "q2", "q3"] {
            continue;
        }
        needs = needed_files(game, item.fields);
        if len(needs) == 0 {
            continue;
        }
        if listing is not None and game not in held {
            held[game] = held_names(listing.names(game));
        }
        for (key, file) in needs {
            label = game + ":" + file;
            named_by[label] = named_by.get(label, 0) + 1;
            kinds[label] = "model" if key.startswith("model") else "sound";
            built_in = item.classname() == "misc_model" and key == "model" and not self.is_built_scene();
            if game in held and len(held[game]) > 0 and file.lower() not in held[game] and not built_in and label not in absent {
                absent.append(label);
            }
        }
    }
    rows.append(TreeRow(key="none", text="Sounds and models", tone="accent", note=str(len(named_by))));
    for label in sorted(named_by.keys()) {
        gone = label in absent;
        lacking += 1 if gone else 0;
        file = label.split(":", 1)[1];
        print("studio: uses " + kinds[label] + " " + label + " by=" + str(named_by[label]) + (" missing" if gone else ""));
        rows.append(
            TreeRow(key="uses:" + file, text=file + ("  (missing)" if gone else ""), depth=1, note=str(named_by[label]), tone="text" if not gone else "accent")
        );
    }
    print("studio: uses materials=" + str(len(sides_of)) + " files=" + str(len(named_by)) + " missing=" + str(lacking));
    if ui is not None {
        ui.checks.rows = rows;
    }
    self.say(
        str(len(sides_of)) + " materials and " + str(len(named_by)) + " sounds and models used"
            + ("" if lacking == 0 else ", " + str(lacking) + " of them missing") + ": a click in the Checks tab selects what uses one"
    );
    return True;
}
