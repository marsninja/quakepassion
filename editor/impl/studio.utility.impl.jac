"""The studio's small tools: a material replaced, snapping, lining up, face
picks spread, glue and counts. Declarations live in studio.jac."""

impl Studio.utility_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    ui = self.ui;
    if name == "ed_replace" {
        if len(args) < 3 {
            self.say("ed_replace <old> <new> [all]");
            return True;
        }
        count = scene.replace_material(args[1], args[2], len(args) > 3 and args[3] == "all");
        self.materials_changed += 1;
        self.say("Replaced " + args[1] + " on " + str(count) + " sides" if count else "Nothing there has " + args[1]);
        return True;
    }
    if name == "ed_snap" {
        size = self.grid;
        if len(args) > 1 {
            try {
                size = max(1.0, float(args[1]));
            } except ValueError {
                self.say("ed_snap [size]");
                return True;
            }
        }
        count = scene.snap_selection(size);
        self.say("Snapped " + str(count) if count else "The selection is on the grid");
        return True;
    }
    if name == "ed_align" {
        if len(args) < 3 or args[1] not in ["x", "y", "z"] or args[2] not in ["low", "high", "middle"] {
            self.say("ed_align <x|y|z> <low|high|middle>");
            return True;
        }
        axis = 0 if args[1] == "x" else (1 if args[1] == "y" else 2);
        if not scene.align_selection(axis, args[2]) {
            self.say("Select two or more brushes that are not lined up");
        }
        return True;
    }
    if name == "ed_faces" {
        how = args[1] if len(args) > 1 else "";
        count = -1;
        if how == "next" or how == "prev" {
            if not scene.step_face(1 if how == "next" else -1) {
                self.say("Pick one face to step from (2)");
            }
            return True;
        }
        if how == "all" {
            count = scene.pick_all_faces();
        } elif how == "invert" {
            count = scene.invert_faces();
        } elif how == "extend" {
            count = scene.extend_faces();
        }
        if count < 0 {
            self.say("ed_faces <all|invert|extend|next|prev>");
        } else {
            self.mode = "face";
            self.say("Picked " + str(count) + " more faces" if count else "No more faces to pick");
        }
        return True;
    }
    if name == "ed_paintface" {
        brush = scene.find_solid(int(args[1])) if len(args) > 2 and args[1].isdigit() else None;
        if brush is None or not args[2].isdigit() {
            self.say("ed_paintface <brush> <side>");
        } else {
            scene.paint_face(brush, int(args[2]), self.material);
        }
        return True;
    }
    if name == "ed_tag" and len(args) > 1 and args[1] == "clear" {
        self.tagged = None;
        self.tagged_side = None;
        self.tagged_words = "";
        self.say("No face is tagged");
        return True;
    }
    if name == "ed_tag" {
        picks = scene.faces();
        if len(picks) != 1 {
            self.say("Pick one face to tag");
            return True;
        }
        self.tagged = picks[0].solid.sides[picks[0].side].plane;
        self.tagged_side = picks[0].solid.sides[picks[0].side];
        self.tagged_words = "face " + str(picks[0].side) + " of brush #" + str(picks[0].solid.serial);
        self.say("Tagged " + self.tagged_words);
        return True;
    }
    if name == "ed_glue" {
        plane = self.tagged;
        if plane is None {
            self.say("Tag a face first (ed_tag)");
            return True;
        }
        if len(args) > 1 and args[1] == "face" {
            if not scene.glue_face(plane) {
                self.say("Pick one face to put in the plane of " + self.tagged_words + " (or it is there, or nothing would be left)");
            }
            return True;
        }
        if not scene.glue_selection(plane) {
            self.say("Select the brushes to glue against " + self.tagged_words + " (or they are there already)");
        }
        return True;
    }
    if name == "ed_step" {
        way = args[1] if len(args) > 1 else "next";
        members = [item for item in scene.items() if item.classname() != "worldspawn" and not item.hidden];
        if len(members) == 0 {
            self.say("There are no entities to step through");
            return True;
        }
        chosen = scene.selection();
        at = -1;
        for (index, item) in enumerate(members) {
            if len(chosen) > 0 and item is chosen[-1] {
                at = index;
            }
        }
        if way == "prev" {
            at = (at - 1 + len(members)) % len(members) if at >= 0 else len(members) - 1;
        } else {
            at = (at + 1) % len(members);
        }
        scene.select(members[at]);
        self.say(members[at].title() + "  #" + str(members[at].serial));
        return True;
    }
    if name == "ed_freeze" {
        word = args[1] if len(args) > 1 else "";
        self.frozen = (not self.frozen) if word not in ["on", "off"] else word == "on";
        self.say(
            "The selection is frozen: clicks in the level leave it alone" if self.frozen else "Clicks select again"
        );
        return True;
    }
    if name == "ed_assetfind" {
        self.asset_filter = args[1].strip().lower() if len(args) > 1 else "";
        self.folds += 1;
        return True;
    }
    if name == "ed_stats" and len(args) > 1 {
        # The materials it uses, a name a line, for another tool to read.
        used: list[str] = [];
        for brush in scene.solids() {
            for side in brush.sides {
                if side.material and side.material not in used {
                    used.append(side.material);
                }
            }
        }
        folder = os.path.dirname(args[1]);
        if folder {
            os.makedirs(folder, exist_ok=True);
        }
        with open(args[1], "w") as file {
            file.write("\n".join(sorted(used)) + "\n");
        }
        self.say("Wrote " + str(len(used)) + " material names to " + args[1]);
        return True;
    }
    if name == "ed_stats" {
        rows: list[TreeRow] = [];
        for line in scene.statistics() {
            print("studio: stat " + line.strip());
            rows.append(TreeRow(key="none", text=line.strip(), depth=1 if line.startswith("  ") else 0, tone="dim"));
        }
        if ui is not None {
            ui.checks.rows = rows;
        }
        self.say(rows[0].text if len(rows) > 0 else "The document is empty");
        return True;
    }
    return False;
}
