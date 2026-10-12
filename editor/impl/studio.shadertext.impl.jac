"""The shader script as text in a box, with what is wrong with it by line
and the shader in hand in brief beside it. Declarations live in studio.jac."""

impl Studio.keep_script_box {
    casing = self.script_box;
    if casing is None {
        return;
    }
    words = self.shader_file + "|" + str(self.shader_rev) + "|" + str(self.shader_now);
    if words == self.script_for {
        return;
    }
    stage = self.stage;
    if stage is not None and stage.input.down[0] {
        # A button of the box may be held (a press on Save is what read the
        # words): it is filled again once the button is up.
        return;
    }
    self.script_for = words;
    casing.clear();
    form = Box(across=True, pad=8, gap=8, fill="panel");
    casing.adopt(form);
    # Words that do not hold together are kept as typed until they do.
    text = self.script_kept if self.script_kept else script_shown(self.shader_list);
    area = TextArea(
        value=passage_line(text),
        command="ed_shader write",
        ghost="A shader's name, then its lines between braces",
        numbered=True,
        indents=True,
        rows=12,
        grow=1,
        hint="The script as text: Enter begins a line; Ctrl+Enter or a click elsewhere reads it again; Escape cancels"
    );
    self.script_area = area;
    form.adopt(area);
    side = Box(gap=2, size=300);
    form.adopt(side);
    faults = script_faults(text);
    side.adopt(
        Label(
            text=str(len(faults)) + (" thing" if len(faults) == 1 else " things") + " the game would trip on"
                if len(faults) > 0
                else "Nothing the game would trip on",
            tone="dim"
        )
    );
    for fault in faults[:9] {
        said = (("line " + str(fault.line) + ": ") if fault.line > 0 else "") + fault.words;
        side.adopt(Label(text=said, tone="text", small=True, hint=said));
    }
    if len(faults) > 9 {
        side.adopt(Label(text="and " + str(len(faults) - 9) + " more (ed_shader check lists them all)", tone="faint", small=True));
    }
    side.adopt(Spacer(size=6));
    shader = self.shader_in_hand();
    if self.script_kept {
        side.adopt(Label(text="The script stands as it was until", tone="faint", small=True));
        side.adopt(Label(text="its braces and names are mended.", tone="faint", small=True));
    } elif shader is not None {
        side.adopt(Label(text="In hand", tone="dim"));
        for line in shader_brief(shader)[:8] {
            side.adopt(Label(text=line, tone="faint", small=True, hint=line));
        }
    }
    side.adopt(Spacer(grow=1));
    row = Box(across=True, gap=4);
    side.adopt(row);
    row.adopt(PushButton(text="Check", command="ed_shader check", grow=1, hint="List every fault in the Checks tab"));
    row.adopt(PushButton(text="Save", command="ed_shader save", grow=1, hint="Write the script to its file"));
}

impl Studio.script_words -> str {
    area = self.script_area;
    text = self.script_kept if self.script_kept else script_shown(self.shader_list);
    return "studio: script text lines=" + str(len(text.split("\n")) if text else 0) + " faults=" + str(len(script_faults(text)))
        + " sound=" + ("0" if self.script_kept else "1") + " box=" + ("1" if area is not None and self.script_box is not None else "0");
}

impl Studio.script_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_shader" {
        return False;
    }
    # Whatever is asked of the script, the box shows it afterwards.
    self.shader_rev += 1;
    how = args[1] if len(args) > 1 else "";
    if how == "open" or how == "take" {
        self.script_kept = "";
        return False;
    }
    stage = self.stage;
    casing = self.script_box;
    if how == "text" {
        word = args[2] if len(args) > 2 else "";
        if word == "close" or (not word and casing is not None) {
            if casing is not None and stage is not None {
                stage.close(casing);
            }
            self.script_box = None;
            self.script_area = None;
            return True;
        }
        if word not in ["", "open"] {
            self.say("ed_shader text [open|close]");
            return True;
        }
        if not self.shader_file {
            self.say("Open a script first (ed_shader open <file>, or ed_shader take for the one the explorer shows)");
            return True;
        }
        if casing is None and stage is not None {
            casing = Floater(
                title="Shader script: " + os.path.basename(self.shader_file),
                command="ed_shader text close",
                least_wide=460,
                least_tall=200
            );
            casing.area = Rect(x=max(8, (stage.width - 780) // 2), y=96, w=min(780, max(460, stage.width - 16)), h=430);
            casing.settle(stage);
            stage.open(casing);
            self.script_box = casing;
        }
        self.script_for = "";
        self.keep_script_box();
        print(self.script_words());
        return True;
    }
    if how == "write" {
        area = self.script_area;
        # The box's own words when it is open (a command's words lose their
        # quotation marks on the way); else the words given, breaks as \n.
        text = passage_of(area.value) if area is not None and casing is not None else passage_of(" ".join(args[2:]));
        read = read_shaders(text);
        if len(read[1]) > 0 {
            self.script_kept = text;
            for fault in read[1] {
                print("studio: script fault line " + str(fault.line) + ": " + fault.words);
            }
            print(self.script_words());
            self.say(
                str(len(read[1])) + (" fault" if len(read[1]) == 1 else " faults")
                + " in how the script is put together: it stands as it was until they are mended"
            );
            return True;
        }
        held = self.shader_in_hand();
        name = held.name.lower() if held is not None else "";
        self.script_kept = "";
        self.shader_list = read[0];
        self.shader_broken = [];
        self.shader_now = 0 if len(read[0]) > 0 else -1;
        for (number, each) in enumerate(read[0]) {
            if each.name.lower() == name {
                self.shader_now = number;
            }
        }
        self.shader_dirty = True;
        print(self.script_words());
        print(self.shader_words());
        found = len(script_faults(text));
        self.say(
            "The script is read again: " + str(len(read[0])) + (" shader" if len(read[0]) == 1 else " shaders")
            + (", " + str(found) + " things the game would trip on" if found > 0 else "")
        );
        return True;
    }
    return False;
}
