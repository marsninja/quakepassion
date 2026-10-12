"""The studio's colours, its bars shown, hidden and moved, the floating
windows kept between sessions, and the shape dialog. Declarations live in
studio.jac."""

impl Studio.place_bars {
    ui = self.ui;
    stage = self.stage;
    if ui is None {
        return;
    }
    if stage is not None {
        stage.focus_on(None);
    }
    ui.top.clear();
    ui.top.adopt(ui.bar_row);
    if self.tools_shown and not self.tools_below {
        ui.top.adopt(ui.tools_row);
    }
    ui.top.adopt(ui.body);
    if self.tools_shown and self.tools_below {
        ui.top.adopt(ui.tools_row);
    }
    if self.status_shown {
        ui.top.adopt(ui.status_row);
    }
}

impl Studio.float_settings -> list[str] {
    lines: list[str] = [];
    number = 2;
    for port in self.float_ports() {
        casing = port.window;
        if casing is None {
            continue;
        }
        # Opened again in this order they take these numbers.
        lines.append("ed_window new" + (" outlines" if port.wire else ""));
        lines.append(
            "ed_window " + str(number) + " at " + str(casing.area.x) + " " + str(casing.area.y) + " " + str(casing.area.w) + " "
                + str(casing.area.h)
        );
        lines.append(
            "ed_window " + str(number) + " cam " + str(int(round(port.camera.eye.x))) + " " + str(int(round(port.camera.eye.y))) + " "
                + str(int(round(port.camera.eye.z))) + " " + str(int(round(math.degrees(port.camera.yaw)))) + " "
                + str(int(round(math.degrees(port.camera.pitch))))
        );
        number += 1;
    }
    return lines;
}

impl Studio.keep_floats {
    stage = self.stage;
    if stage is None or stage.held is not None or not self.settings_read {
        return;
    }
    casing = self.shape_box;
    if casing is not None {
        self.shape_at = [casing.area.x, casing.area.y];
    }
    words = "|".join(self.float_settings()) + "|" + str(self.shape_at[0]) + "," + str(self.shape_at[1]);
    if words != self.floats_kept {
        had = self.floats_kept;
        self.floats_kept = words;
        if had {
            # Moved, sized or flown since the settings were kept.
            self.keep_settings();
        }
    }
}

impl Studio.show_shape_box {
    stage = self.stage;
    ui = self.ui;
    if stage is None or ui is None {
        return;
    }
    casing = self.shape_box;
    if casing is None {
        casing = Floater(title="Shape", command="ed_shapebox close", least_wide=250, least_tall=228);
        casing.area = Rect(x=self.shape_at[0], y=self.shape_at[1], w=250, h=228);
        casing.settle(stage);
        stage.open(casing);
        self.shape_box = casing;
    }
    casing.clear();
    form = Box(pad=8, gap=4, fill="panel");
    casing.adopt(form);
    form.adopt(
        Dropdown(
            text=self.shape_kind,
            labels=SHAPE_KINDS,
            commands=["ed_shapebox kind " + kind for kind in SHAPE_KINDS],
            hint="The kind of shape to build"
        )
    );
    for (held_key, label, ghost) in [
        ("w", "wide", "128"), ("d", "deep", "128"), ("h", "tall", "96"), ("count", "count", "as it comes"),
        ("thick", "thickness", "16")
    ] {
        row = Box(across=True, gap=4);
        form.adopt(row);
        row.adopt(Label(text=label, tone="dim", size=76));
        row.adopt(
            TextField(
                value=self.shape_sizes.get(held_key, ""),
                ghost=ghost,
                command="ed_shapebox set " + held_key,
                grow=1,
                hint="Enter keeps it; Tab goes to the next"
            )
        );
    }
    form.adopt(Spacer(size=4));
    form.adopt(
        PushButton(text="Build it where the camera looks", command="ed_shapebox build", bold=True, hint="Build the shape (ed_shape)")
    );
}

impl Studio.looks_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    stage = self.stage;
    how = args[1] if len(args) > 1 else "";
    if name == "ed_theme" {
        wanted = how if how in ["dark", "light"] else ("light" if self.theme_name == "dark" else "dark");
        if how and how not in ["dark", "light"] {
            self.say("ed_theme [dark|light]");
            return True;
        }
        if wanted != self.theme_name {
            self.theme_name = wanted;
            self.canvas.theme = light_theme() if wanted == "light" else Theme();
            self.keep_settings();
            self.say("The studio is in its " + wanted + " colours");
        }
        return True;
    }
    if name == "ed_bar" {
        word = args[2] if len(args) > 2 else "";
        was = [self.tools_shown, self.status_shown, self.tools_below];
        if how == "tools" and word in ["above", "below", "flip"] {
            self.tools_below = (not self.tools_below) if word == "flip" else word == "below";
        } elif how == "tools" and word in ["", "show", "hide"] {
            self.tools_shown = (not self.tools_shown) if not word else word == "show";
        } elif how == "status" and word in ["", "show", "hide"] {
            self.status_shown = (not self.status_shown) if not word else word == "show";
        } else {
            self.say("ed_bar <tools|status> [show|hide] | tools <above|below>");
            return True;
        }
        if was != [self.tools_shown, self.status_shown, self.tools_below] {
            self.place_bars();
            self.keep_settings();
            self.say(
                "The tools are " + ("hidden" if not self.tools_shown else ("under the views" if self.tools_below else "over the views"))
                    + "; the status bar is " + ("shown" if self.status_shown else "hidden")
            );
        }
        return True;
    }
    if name != "ed_shapebox" {
        return False;
    }
    if how == "close" {
        casing = self.shape_box;
        if casing is not None and stage is not None {
            self.shape_at = [casing.area.x, casing.area.y];
            stage.close(casing);
        }
        self.shape_box = None;
        self.keep_settings();
        return True;
    }
    if how == "at" and len(args) > 3 and args[2].lstrip("-").isdigit() and args[3].lstrip("-").isdigit() {
        self.shape_at = [int(args[2]), int(args[3])];
        casing = self.shape_box;
        if casing is not None and stage is not None {
            casing.area = Rect(x=self.shape_at[0], y=self.shape_at[1], w=casing.area.w, h=casing.area.h);
            casing.settle(stage);
        }
        return True;
    }
    if how == "kind" and len(args) > 2 {
        if args[2] not in SHAPE_KINDS {
            self.say("The kinds of shape: " + ", ".join(SHAPE_KINDS));
            return True;
        }
        changed = args[2] != self.shape_kind;
        self.shape_kind = args[2];
        if self.shape_box is not None {
            self.show_shape_box();
        }
        if changed {
            self.keep_settings();
        }
        return True;
    }
    if how == "set" and len(args) > 2 and args[2] in ["w", "d", "h", "count", "thick"] {
        value = args[3].strip() if len(args) > 3 else "";
        try {
            if value {
                float(value);
            }
        } except ValueError {
            self.say("A size is a number");
            return True;
        }
        if self.shape_sizes.get(args[2], "") != value {
            self.shape_sizes[args[2]] = value;
            self.keep_settings();
        }
        return True;
    }
    if how == "build" {
        if stage is not None {
            # A field still being typed in is kept first.
            stage.focus_on(None);
        }
        words = ["ed_shape", self.shape_kind];
        for held_key in ["w", "d", "h"] {
            words.append(self.shape_sizes.get(held_key, "") or {"w": "128", "d": "128", "h": "96"}[held_key]);
        }
        if self.shape_sizes.get("count", "") or self.shape_sizes.get("thick", "") {
            words.append(self.shape_sizes.get("count", "") or "0");
        }
        if self.shape_sizes.get("thick", "") {
            words.append(self.shape_sizes["thick"]);
        }
        print("studio: shapebox builds " + " ".join(words[1:]));
        self.command(words);
        return True;
    }
    if how in ["", "open"] {
        if self.shape_box is None or how == "open" {
            self.show_shape_box();
            self.keep_settings();
        } else {
            return self.looks_command(scene, ["ed_shapebox", "close"]);
        }
        return True;
    }
    self.say("ed_shapebox [open|close|kind <kind>|set <w|d|h|count|thick> <value>|build|at <x> <y>]");
    return True;
}
