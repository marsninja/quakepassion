"""Boxes that tools show floating over the studio: words to edit with
their lines numbered, what the tool says of them, and buttons. Declarations
live in studio.jac."""

impl Studio.tool_panel_set(key: str, spec: PanelSpec) {
    self.tool_specs[key] = spec;
    if key not in self.tool_stale {
        self.tool_stale.append(key);
    }
}

impl Studio.tool_panel_text(key: str) -> str {
    if key not in self.tool_areas or key not in self.tool_boxes {
        return "";
    }
    return passage_of(self.tool_areas[key].value);
}

impl Studio.tool_panel_close(key: str) {
    stage = self.stage;
    if key in self.tool_boxes and stage is not None {
        stage.close(self.tool_boxes[key]);
    }
    self.tool_boxes.pop(key, None);
    self.tool_areas.pop(key, None);
    self.tool_specs.pop(key, None);
    if key in self.tool_stale {
        self.tool_stale.remove(key);
    }
}

impl Studio.keep_tool_panels {
    stage = self.stage;
    if stage is None or len(self.tool_stale) == 0 or stage.input.down[0] {
        # A button of a box may be held: it is filled once the button is up.
        return;
    }
    stale = list(self.tool_stale);
    self.tool_stale = [];
    for key in stale {
        if key not in self.tool_specs {
            continue;
        }
        spec = self.tool_specs[key];
        if key not in self.tool_boxes {
            casing = Floater(title=spec.title, command="ed_toolpanel close " + quote_command_word(key), least_wide=460, least_tall=200);
            casing.area = Rect(x=max(8, (stage.width - 800) // 2), y=110, w=min(800, max(460, stage.width - 16)), h=430);
            casing.settle(stage);
            stage.open(casing);
            self.tool_boxes[key] = casing;
        }
        box = self.tool_boxes[key];
        box.title = spec.title;
        box.clear();
        form = Box(across=True, pad=8, gap=8, fill="panel");
        box.adopt(form);
        area = TextArea(
            value=passage_line(spec.text),
            command=spec.order,
            numbered=True,
            indents=True,
            rows=12,
            grow=1,
            hint="Enter begins a line; Ctrl+Enter or a click elsewhere hands the words over; Escape cancels"
        );
        self.tool_areas[key] = area;
        form.adopt(area);
        side = Box(gap=2, size=300);
        form.adopt(side);
        for said in spec.notes[:14] {
            side.adopt(Label(text=said, tone="text", small=True, hint=said));
        }
        side.adopt(Spacer(grow=1));
        row: Box | None = None;
        for (number, button) in enumerate(spec.buttons[:6]) {
            if row is None or number % 2 == 0 {
                row = Box(across=True, gap=4);
                side.adopt(row);
            }
            row.adopt(PushButton(text=button[0], command=button[1], grow=1, hint=button[1]));
        }
    }
}

impl Studio.toolpanel_command(args: list[str]) -> bool {
    if args[0] != "ed_toolpanel" {
        return False;
    }
    if len(args) > 2 and args[1] == "close" {
        self.tool_panel_close(args[2]);
    } else {
        self.say("ed_toolpanel close <name>");
    }
    return True;
}
