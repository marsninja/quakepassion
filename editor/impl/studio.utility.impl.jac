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
        whole = len(args) > 1 and args[1] == "all";
        words = args[2:] if whole else args[1:];
        if len(words) > 0 {
            try {
                size = max(1.0, float(words[0]));
            } except ValueError {
                self.say("ed_snap [all] [size]");
                return True;
            }
        }
        if whole {
            # The whole map forced onto the grid: what would fall flat is left, and counted.
            astray = scene.off_grid(size);
            mended = scene.snap_selection(size, True);
            left = scene.off_grid(size);
            print("studio: snapped all grid=" + str(int(size)) + " off=" + str(astray) + " moved=" + str(mended) + " left=" + str(left));
            self.say(
                "Everything is on the grid" if astray == 0
                else "Put " + str(mended) + " things on the grid" + (", and left " + str(left) + " that would fall flat" if left > 0 else "")
            );
            return True;
        }
        count = scene.snap_selection(size);
        self.say("Snapped " + str(count) if count else "The selection is on the grid");
        return True;
    }
    if name == "ed_align" {
        if len(args) < 3 or args[1] not in ["x", "y", "z"] or args[2] not in ["low", "high", "middle"] {
            self.say("ed_align <x|y|z> <low|high|middle> [to <set>]");
            return True;
        }
        axis = 0 if args[1] == "x" else (1 if args[1] == "y" else 2);
        if len(args) > 4 and args[3] == "to" {
            # Against a kept set: its low side, high side or middle, where it stands.
            mark = scene.set_mark(args[4], axis, args[2]);
            if mark is None {
                self.say("No set called " + args[4] + " holds anything (ed_keep <name> keeps the selection as one)");
            } elif not scene.align_selection(axis, args[2], mark) {
                self.say("Select the brushes to line up with " + args[4] + " (they may be there already)");
            } else {
                self.say("Lined up with " + args[4] + " along " + args[1]);
            }
            return True;
        }
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
        } elif how == "adjoining" {
            count = scene.adjoin_faces();
        } elif how == "beside" {
            count = scene.beside_faces();
        }
        if count < 0 {
            self.say("ed_faces <all|invert|extend|adjoining|beside|next|prev>");
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
        self.tag_planes = [];
        self.tag_names = [];
        self.tagged_solid = None;
        self.tagged_index = -1;
        self.say("No face is tagged");
        return True;
    }
    if name == "ed_tag" and len(args) > 1 and args[1] == "list" {
        for (place, called) in enumerate(self.tag_names) {
            print("studio: tag " + str(place + 1) + " " + called);
        }
        self.say(str(len(self.tag_names)) + " faces tagged: " + ", ".join(self.tag_names) if len(self.tag_names) > 0 else "No face is tagged");
        return True;
    }
    if name == "ed_tag" and len(args) > 1 and args[1] == "add" and self.tagged is not None {
        # More faces beside the first: brushes are glued against the nearest of them.
        added = 0;
        for face in scene.faces() {
            called = "face " + str(face.side) + " of brush #" + str(face.solid.serial);
            if called not in self.tag_names {
                self.tag_planes.append(face.solid.sides[face.side].plane);
                self.tag_names.append(called);
                added += 1;
            }
        }
        self.say(str(len(self.tag_names)) + " faces tagged" if added else "Pick faces that are not tagged yet");
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
        self.tagged_solid = picks[0].solid;
        self.tagged_index = picks[0].side;
        self.tag_planes = [picks[0].solid.sides[picks[0].side].plane];
        self.tag_names = [self.tagged_words];
        self.say("Tagged " + self.tagged_words);
        return True;
    }
    if name == "ed_glue" {
        first_tag = self.tagged;
        if first_tag is None {
            self.say("Tag a face first (ed_tag)");
            return True;
        }
        against: Plane3 = first_tag;
        if len(self.tag_planes) > 1 {
            # Of several tagged faces, the one whose plane what is to be glued stands nearest.
            near = scene.selection_middle();
            if near is None and len(scene.faces()) > 0 {
                reach = scene.faces()[0].solid.bounds();
                near = reach[0].add(reach[1]).scale(0.5) if reach is not None else None;
            }
            if near is not None {
                least = 1000000000.0;
                for (place, marked) in enumerate(self.tag_planes) {
                    gap = abs(near.dot(marked.normal) - marked.dist);
                    if gap < least {
                        least = gap;
                        against = marked;
                        self.tagged_words = self.tag_names[place];
                    }
                }
                print("studio: glued to " + self.tagged_words);
            }
        }
        if len(args) > 1 and args[1] == "face" {
            if not scene.glue_face(against) {
                self.say("Pick one face to put in the plane of " + self.tagged_words + " (or it is there, or nothing would be left)");
            }
            return True;
        }
        if not scene.glue_selection(against) {
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
    if name == "ed_matfind" {
        # Materials by name across every game's groups, shown as a shelf of their own.
        wanted_words = " ".join(args[1:]).strip().lower();
        stock_now = self.archive;
        if not wanted_words or stock_now is None {
            self.say("ed_matfind <text>: every material, of any game, whose name holds the text" if stock_now is not None else "No game archives were found");
            return True;
        }
        matched: list[str] = [];
        for group in stock_now.groups() {
            for each in stock_now.names(group) {
                if wanted_words in each.lower() and each not in matched {
                    matched.append(each);
                }
            }
        }
        for each in stock_now.file_names() {
            if wanted_words in each.lower() and each not in matched {
                matched.append(each);
            }
        }
        self.found_materials = sorted(matched)[:400];
        self.found_words = wanted_words;
        print("studio: matfind " + wanted_words.replace(" ", "_") + " found=" + str(len(matched)) + " " + " ".join(self.found_materials[:6]));
        if len(matched) > 0 {
            self.shelf = "found";
        }
        self.materials_changed += 1;
        self.say(str(len(matched)) + " materials hold \"" + wanted_words + "\"" + (": shown in the Materials tab" if len(matched) > 0 else ""));
        return True;
    }
    if name == "ed_assetfind" {
        self.asset_filter = " ".join(args[1:]).strip().lower();
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
