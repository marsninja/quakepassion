"""Quake III shader scripts opened, changed a line or a stage at a time,
checked and saved. Declarations live in studio.jac."""

impl Studio.shader_path(name: str) -> str {
    if name.startswith("/") {
        return name;
    }
    folder = os.getenv("QP_SHADERS", "");
    if self.project_folder {
        folder = self.project_folder + "/scripts";
    } elif not folder {
        folder = os.getcwd() + "/scripts";
    }
    return folder + "/" + (name if name.lower().endswith(".shader") else name + ".shader");
}

impl Studio.shader_in_hand -> ShaderText | None {
    if self.shader_now < 0 or self.shader_now >= len(self.shader_list) {
        return None;
    }
    return self.shader_list[self.shader_now];
}

impl Studio.shader_words -> str {
    shader = self.shader_in_hand();
    return "studio: shaders file=" + os.path.basename(self.shader_file) + " count=" + str(len(self.shader_list)) + " now="
        + (shader.name if shader is not None else "-") + " lines=" + str(len(shader.lines) if shader is not None else 0)
        + " stages=" + str(len(shader.stages) if shader is not None else 0) + " edited=" + ("1" if self.shader_dirty else "0");
}

impl Studio.shader_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_shader" {
        return False;
    }
    how = args[1] if len(args) > 1 else "";
    if how == "open" and len(args) > 2 {
        path = self.shader_path(args[2]);
        text = "";
        if os.path.isfile(path) {
            try {
                with open(path, "r") as file {
                    text = file.read();
                }
            } except OSError {
                text = "";
            }
        }
        read = read_shaders(text);
        # The script in hand stays open beside it (or, when it is this one, is taken again).
        if path != self.shader_file {
            self.park_shader();
            self.shaders_parked = [held for held in self.shaders_parked if held.file != path];
        }
        self.shader_file = path;
        self.shader_list = read[0];
        self.shader_broken = read[1];
        self.shader_now = 0 if len(read[0]) > 0 else -1;
        self.shader_dirty = False;
        self.say(
            os.path.basename(path) + ": " + str(len(read[0])) + " shaders" + (", " + str(len(read[1])) + " faults in how it is put together" if read[1] else "")
            if text
            else os.path.basename(path) + " is new: ed_shader new <name> adds a shader to it"
        );
        print(self.shader_words());
        return True;
    }
    if how == "take" {
        # The script the asset explorer shows, to change a copy of.
        seen = self.asset_now;
        known = self.asset_index;
        whole = known.read(seen.game, seen.name) if seen is not None and known is not None else None;
        if seen is None or whole is None or not seen.name.lower().endswith(".shader") {
            self.say("ed_shader take: show a .shader file in the asset explorer first");
            return True;
        }
        read = read_shaders(whole.decode("utf-8", "replace"));
        self.park_shader();
        self.shader_file = self.shader_path(seen.name.split("/")[-1]);
        self.shader_list = read[0];
        self.shader_broken = read[1];
        self.shader_now = 0 if len(read[0]) > 0 else -1;
        self.shader_dirty = True;
        self.say("Took " + str(len(read[0])) + " shaders from " + seen.name + ", to be saved as " + self.shader_file);
        print(self.shader_words());
        return True;
    }
    if not self.shader_file {
        self.say("No shader script is open (ed_shader open <file>, or ed_shader take for the one the explorer shows)");
        return True;
    }
    if not how {
        for (number, each) in enumerate(self.shader_list) {
            print(
                "studio: shader " + str(number) + " " + each.name + " lines=" + str(len(each.lines)) + " stages="
                    + str(len(each.stages)) + (" in hand" if number == self.shader_now else "")
            );
        }
        print(self.shader_words());
        self.say(os.path.basename(self.shader_file) + ": " + str(len(self.shader_list)) + " shaders");
        return True;
    }
    if how == "pick" and len(args) > 2 {
        for (number, each) in enumerate(self.shader_list) {
            if args[2] == str(number) or args[2].lower() == each.name.lower() {
                self.shader_now = number;
            }
        }
        print(self.shader_words());
        return True;
    }
    if how == "new" and len(args) > 2 {
        if shader_named(self.shader_list, args[2]) is not None {
            self.say("The script has a shader called " + args[2] + " already");
            return True;
        }
        # A picture lit by the level's light: what most walls are.
        self.shader_list.append(
            ShaderText(
                name=args[2],
                stages=[
                    ShaderStage(lines=["map $lightmap", "rgbGen identity"]),
                    ShaderStage(lines=["map " + args[2] + ".tga", "blendFunc filter", "rgbGen identity"])
                ]
            )
        );
        self.shader_now = len(self.shader_list) - 1;
        self.shader_dirty = True;
        print(self.shader_words());
        return True;
    }
    if how == "check" {
        found = list(self.shader_broken);
        for each in self.shader_list {
            for fault in shader_faults(each) {
                found.append(fault);
            }
        }
        rows: list[TreeRow] = [];
        self.findings = [];
        for fault in found {
            said = (("line " + str(fault.line) + ": ") if fault.line > 0 else "") + fault.words;
            print("studio: shader fault " + said);
            rows.append(TreeRow(key=str(len(rows)), text=said, tone="text", note="!"));
            self.findings.append(Finding(words=said, grave=True));
        }
        print("studio: shader faults " + str(len(found)));
        panel = self.ui;
        if panel is not None {
            if not rows {
                rows.append(TreeRow(key="none", text="Nothing is wrong with the script.", tone="faint"));
            }
            panel.checks.rows = rows;
        }
        self.say(str(len(found)) + " things the game would trip on (the Checks tab lists them)" if found else "Nothing is wrong with the script");
        return True;
    }
    if how == "save" {
        path = self.shader_path(args[2]) if len(args) > 2 else self.shader_file;
        try {
            os.makedirs(os.path.dirname(path), exist_ok=True);
            with open(path, "w") as file {
                file.write(write_shaders(self.shader_list));
            }
        } except OSError {
            self.say("ed_shader save: could not write " + path);
            return True;
        }
        self.shader_file = path;
        self.shader_dirty = False;
        # As written, it is put together soundly.
        self.shader_broken = [];
        print("studio: saved shaders " + path + " count=" + str(len(self.shader_list)));
        self.say("Saved " + path);
        return True;
    }
    shader = self.shader_in_hand();
    if shader is None {
        self.say("The script has no shader in hand (ed_shader new <name>, ed_shader pick <name>)");
        return True;
    }
    if how == "preview" {
        refused = self.preview_shader();
        previewed = self.shader_in_hand();
        shader_name_now = previewed.name if previewed is not None else "-";
        if refused {
            self.say("ed_shader preview: " + refused);
        } else {
            print("studio: shader preview " + shader_name_now + " stages=" + str(len(self.shader_drawer.stages) if self.shader_drawer is not None else 0));
            self.say("The shader is drawn on a square in the explorer, as the game draws a model with it");
        }
        return True;
    }
    if how == "show" {
        for line in write_shaders([shader]).split("\n") {
            if line {
                print("studio: | " + line.replace("\t", "    "));
            }
        }
        return True;
    }
    if how == "drop" {
        self.shader_list.pop(self.shader_now);
        self.shader_now = min(self.shader_now, len(self.shader_list) - 1);
        self.shader_dirty = True;
        print(self.shader_words());
        return True;
    }
    # A directive that a shader or a stage may have several of is told
    # apart by its next word.
    several = ["surfaceparm", "tcmod", "deformvertexes"];
    if (how == "set" or how == "unset") and len(args) > 2 {
        key = args[2];
        value = " ".join(args[3:]) if how == "set" else "";
        also = args[3] if len(args) > 3 and key.lower() in several else "";
        shader.lines = with_directive(shader.lines, key, value, also);
        self.shader_dirty = True;
        print(self.shader_words());
        return True;
    }
    if how == "stage" and len(args) > 2 {
        what = args[2];
        if what == "add" {
            shader.stages.append(ShaderStage(lines=["map " + (args[3] if len(args) > 3 else "$whiteimage")]));
        } elif what.isdigit() and int(what) < len(shader.stages) and len(args) > 3 {
            layer = shader.stages[int(what)];
            act = args[3];
            if (act == "set" or act == "unset") and len(args) > 4 {
                key = args[4];
                value = " ".join(args[5:]) if act == "set" else "";
                also = args[5] if len(args) > 5 and key.lower() in several else "";
                layer.lines = with_directive(layer.lines, key, value, also);
            } elif act == "drop" {
                shader.stages.pop(int(what));
            } elif act == "move" and len(args) > 4 and args[4].isdigit() and int(args[4]) < len(shader.stages) {
                moved_stage = shader.stages.pop(int(what));
                shader.stages.insert(int(args[4]), moved_stage);
            } else {
                self.say("ed_shader stage <n> set <key> <value> | unset <key> | drop | move <to>");
                return True;
            }
        } else {
            self.say("ed_shader stage add [picture] | stage <n> set|unset|drop|move ...");
            return True;
        }
        self.shader_dirty = True;
        print(self.shader_words());
        return True;
    }
    self.say("ed_shader [open <file>|take|new <name>|pick <name>|show|set <key> <value>|unset <key>|stage ...|drop|check|save]");
    return True;
}
