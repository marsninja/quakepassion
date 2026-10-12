"""The studio's keys bound by hand, its list of settings, the numbers along
the grid and the developer's readout. Declarations live in studio.jac."""

impl Studio.dev_words(scene: Scene) -> str {
    if not self.dev_shown {
        return "";
    }
    built_now = self.live;
    return "frame " + str(round(self.frame_ms, 1)) + " ms   build " + str(self.build_ms) + " ms   "
        + str(len(scene.solids())) + " brushes (" + str(built_now.brushes if built_now is not None else 0) + " built)   "
        + str(len(scene.items())) + " entities   " + str(self.lit_samples if self.lit else 0) + " lit   ";
}

impl Studio.draw_grid_numbers(area: Rect) {
    canvas = self.canvas;
    lens = self.camera;
    step = max(1.0, self.grid);
    while lens.span / step > 40.0 {
        step *= 4.0;
    }
    # A number at every fourth line, as the stronger lines are drawn.
    step *= 4.0;
    tall = lens.span * 0.5;
    wide = tall * float(max(1, area.w)) / float(max(1, area.h));
    across = lens.right();
    upward = lens.up();
    middle_x = lens.eye.dot(across);
    middle_y = lens.eye.dot(upward);
    for i in range(int(math.floor((middle_x - wide) / step)), int(math.ceil((middle_x + wide) / step)) + 1) {
        at = float(i) * step;
        x = area.x + int((at - middle_x + wide) / (2.0 * wide) * float(area.w));
        if x > area.x + 40 and x < area.x + area.w - 20 {
            # The world's number there, whichever way the view's right runs.
            words = str(int(round(at * (across.x + across.y + across.z))));
            canvas.text(words, x + 2, area.y + area.h - 14, canvas.theme.faint, canvas.theme.small);
        }
    }
    for i in range(int(math.floor((middle_y - tall) / step)), int(math.ceil((middle_y + tall) / step)) + 1) {
        at = float(i) * step;
        y = area.y + int((middle_y + tall - at) / (2.0 * tall) * float(area.h));
        if y > area.y + 20 and y < area.y + area.h - 20 {
            words = str(int(round(at * (upward.x + upward.y + upward.z))));
            canvas.text(words, area.x + 3, y - 12, canvas.theme.faint, canvas.theme.small);
        }
    }
}

impl Studio.settings_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    stage = self.stage;
    if name == "ed_bind" {
        if len(args) < 3 {
            self.say("ed_bind <key> <command>: a letter, or ctrl+ and shift+ before one");
            return True;
        }
        chord = args[1].lower();
        self.user_keys[chord] = " ".join(args[2:]);
        self.keep_settings();
        self.say(chord + " runs " + self.user_keys[chord]);
        return True;
    }
    if name == "ed_unbind" {
        chord = args[1].lower() if len(args) > 1 else "";
        if chord in self.user_keys {
            self.user_keys.pop(chord, None);
            self.keep_settings();
            self.say(chord + " does what the studio gives it");
        } else {
            self.say("ed_unbind: " + (chord if chord else "a key") + " is not bound by hand");
        }
        return True;
    }
    if name == "ed_binds" {
        for chord in sorted(self.user_keys.keys()) {
            print("studio: key " + chord + " " + self.user_keys[chord]);
        }
        self.say(
            "Bound by hand: " + ", ".join(sorted(self.user_keys.keys()))
            if self.user_keys
            else "No key is bound by hand (ed_bind <key> <command>)"
        );
        return True;
    }
    if name == "ed_dev" {
        self.dev_shown = not self.dev_shown;
        if len(args) > 1 and args[1] in ["on", "off", "1", "0"] {
            self.dev_shown = args[1] in ["on", "1"];
        }
        self.keep_settings();
        self.seen_revision = -1;
        return True;
    }
    if self.settings_box_command(scene, args) {
        return True;
    }
    if name == "ed_settings" {
        if stage is None {
            return True;
        }
        # Each line says what is so and does the other thing when clicked.
        rows = [
            ("Grid " + str(int(self.grid)) + " (coarser)", "ed_grid up"),
            ("Grid " + ("shown" if self.grid_shown else "hidden"), "ed_grid toggle"),
            ("Turns snap to " + str(int(self.angle_snap)) + " degrees", "ed_anglesnap " + ("45" if self.angle_snap < 45.0 else "15")),
            ("Materials " + ("go with their faces" if self.tex_lock else "stay in the world"), "ed_texlock"),
            ("Ruler " + ("on" if self.ruler else "off"), "ed_ruler"),
            ("Names " + ("on every entity" if self.names else "on the selection"), "ed_names"),
            ("Light " + ("coarse" if self.luxel > 16.0 else "fine"), "ed_build " + ("full" if self.luxel > 16.0 else "quick")),
            ("Shapes " + ("come caulked" if self.autocaulk else "in one material"), "ed_autocaulk"),
            ("Maps " + ("with" if self.map_comments else "without") + " numbered comments", "ed_mapopts comments"),
            ("Maps in " + ("whole numbers" if self.map_whole else "exact numbers"), "ed_mapopts whole"),
            ("Materials as " + ("flat tones" if self.solid_tones else "textures"), "ed_display " + ("textured" if self.solid_tones else "solid")),
            ("Developer's readout " + ("on" if self.dev_shown else "off"), "ed_dev")
        ];
        listed: list[MenuItem] = [];
        for (words, order) in rows {
            listed.append(MenuItem(text=words, command=order));
            print("studio: setting " + words);
        }
        sheet = MenuPopup(items=listed);
        sheet.open_at(stage, 300, 80);
        return True;
    }
    return False;
}
