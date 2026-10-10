"""The studio's grid, remembered views, hiding, history and autosave.
Declarations live in studio.jac."""

impl Studio.autosave_path(name: str) -> str {
    return os.path.dirname(self.scene_path("x")) + "/autosave/" + name.replace("/", "_") + ".map";
}

impl Studio.autosave(dt: float, now: bool) {
    scene = self.scene;
    if scene is None or not self.is_built_scene() {
        return;
    }
    self.autosave_clock += dt;
    if not now and (self.autosave_clock < 30.0 or not scene.dirty or scene.revision == self.autosaved) {
        return;
    }
    self.autosave_clock = 0.0;
    self.autosaved = scene.revision;
    path = self.autosave_path(scene.name[7:]);
    try {
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w") as file {
            file.write(write_map(scene_map(scene)));
        }
    } except OSError {
        return;
    }
    if now {
        self.say("Autosaved " + path);
    }
}

impl Studio.shell_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    app = self.app;
    stage = self.stage;
    if app is None {
        return False;
    }
    if name == "ed_palette" {
        if stage is None {
            return True;
        }
        entries: list[PaletteEntry] = [];
        for (known, usage, about) in STUDIO_COMMANDS {
            if not known.startswith("ui_") {
                entries.append(PaletteEntry(command=known, usage=usage, about=about));
            }
        }
        chooser = Palette(entries=entries);
        chooser.open_in(stage);
        return True;
    }
    if name == "ed_grid" {
        word = args[1] if len(args) > 1 else "";
        size = self.grid;
        if word == "up" {
            size = size * 2.0;
        } elif word == "down" {
            size = size / 2.0;
        } else {
            try {
                size = float(word);
            } except ValueError {
                self.say("ed_grid <size|up|down>");
                return True;
            }
        }
        self.grid = max(1.0, min(256.0, float(round(size))));
        self.say("Grid " + str(int(self.grid)));
        return True;
    }
    if name == "ed_mark" {
        world = scene.world();
        label = args[1].strip() if len(args) > 1 else "";
        if not label {
            number = 1;
            while ("_view_" + str(number)) in world.fields {
                number += 1;
            }
            label = str(number);
        }
        eye = self.main.eye;
        words = str(int(round(eye.x))) + " " + str(int(round(eye.y))) + " " + str(int(round(eye.z))) + " "
            + str(int(round(math.degrees(self.main.yaw)))) + " " + str(int(round(math.degrees(self.main.pitch))));
        change = FieldChange(item=world, key="_view_" + label, before=world.fields.get("_view_" + label), after=words);
        change.redo();
        scene.commit(Step(label="Remember view", changes=[change]));
        self.say("Remembered this view as " + label);
        return True;
    }
    if name == "ed_goto" {
        world = scene.world();
        marks = sorted([key for key in world.fields.keys() if key.startswith("_view_")]);
        if len(marks) == 0 {
            self.say("No view has been remembered (ed_mark)");
            return True;
        }
        wanted = args[1].strip() if len(args) > 1 else "next";
        key = "_view_" + wanted;
        if wanted == "next" {
            self.marks_at = (self.marks_at + 1) % len(marks);
            key = marks[self.marks_at];
        }
        parts = world.fields.get(key, "").split();
        if len(parts) < 5 {
            self.say("No view is remembered as " + wanted);
            return True;
        }
        try {
            self.main.eye = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            self.main.yaw = math.radians(float(parts[3]));
            self.main.pitch = math.radians(float(parts[4]));
        } except ValueError {
            self.say("That remembered view does not read as numbers");
            return True;
        }
        self.say("View " + key[6:]);
        return True;
    }
    if name == "ed_hide" {
        count = scene.hide_others() if len(args) > 1 and args[1] == "others" else scene.hide_selection();
        self.say("Hid " + str(count) if count else "Select what to hide (or what to keep, for the others)");
        return True;
    }
    if name == "ed_show" {
        count = scene.show_all();
        self.say("Showed " + str(count) if count else "Nothing is hidden");
        return True;
    }
    if name == "ed_drop" {
        # The underside of the selection, from the boxes of what is selected.
        far = 1000000.0;
        low = Vec3(x=far, y=far, z=far);
        high = Vec3(x=-far, y=-far, z=-far);
        for seen in self.looks {
            if scene.is_solid_selected(seen.solid) {
                low = Vec3(x=min(low.x, seen.low.x), y=min(low.y, seen.low.y), z=min(low.z, seen.low.z));
                high = Vec3(x=max(high.x, seen.high.x), y=max(high.y, seen.high.y), z=max(high.z, seen.high.z));
            }
        }
        for shape in self.shapes {
            if scene.is_selected(shape.item) {
                low = Vec3(x=min(low.x, shape.low.x), y=min(low.y, shape.low.y), z=min(low.z, shape.low.z));
                high = Vec3(x=max(high.x, shape.high.x), y=max(high.y, shape.high.y), z=max(high.z, shape.high.z));
            }
        }
        if low.x > high.x {
            self.say("Nothing to drop");
            return True;
        }
        # From just under its middle, straight down to what stops it.
        under = Vec3(x=(low.x + high.x) * 0.5, y=(low.y + high.y) * 0.5, z=low.z - 1.0);
        trace = app.level.collision.trace_point(under, under.sub(Vec3(z=4096.0)));
        if trace.start_solid or trace.fraction >= 1.0 {
            self.say("There is nothing beneath it");
            return True;
        }
        fall = float(round(1.0 + 4096.0 * trace.fraction));
        if fall < 1.0 or not scene.shift_selection(Vec3(z=-fall)) {
            self.say("It is already resting");
        }
        return True;
    }
    if name == "ed_history" {
        done = scene.journal.done;
        if len(args) > 1 and args[1].isdigit() {
            count = min(int(args[1]), len(done));
            for i in range(count) {
                scene.undo();
            }
            self.say("Undid " + str(count) + " edits");
            return True;
        }
        if len(done) == 0 or stage is None {
            self.say("Nothing has been edited yet");
            return True;
        }
        # The newest edit first: choosing one undoes it and all after it.
        items: list[MenuItem] = [];
        for back in range(min(20, len(done))) {
            step = done[len(done) - 1 - back];
            items.append(MenuItem(text="Undo back to before: " + step.label, command="ed_history " + str(back + 1)));
        }
        popup = MenuPopup(items=items);
        popup.open_at(stage, 300, 80);
        return True;
    }
    if name == "ed_autosave" {
        self.autosave(0.0, True);
        return True;
    }
    return False;
}

impl Studio.draw_marks(shape: Shape) {
    item = shape.item;
    middle = shape.center();
    facing = item.fields.get("angle");
    if facing is not None {
        try {
            turn = float(facing);
            ahead = Vec3(z=1.0);
            if turn == -2.0 {
                ahead = Vec3(z=-1.0);
            } elif turn != -1.0 {
                ahead = Vec3(x=math.cos(math.radians(turn)), y=math.sin(math.radians(turn)));
            }
            # An arrow the way it faces.
            tip = middle.add(ahead.scale(48.0));
            wire_line(middle, tip, ink(0x4cc38a));
            side = Vec3(x=-ahead.y, y=ahead.x) if abs(ahead.z) < 0.5 else Vec3(x=1.0);
            wire_line(tip, tip.sub(ahead.scale(12.0)).add(side.scale(6.0)), ink(0x4cc38a));
            wire_line(tip, tip.sub(ahead.scale(12.0)).sub(side.scale(6.0)), ink(0x4cc38a));
        } except ValueError {
            return;
        }
    }
    if item.classname().startswith("light") {
        reach = 300.0;
        try {
            reach = float(item.fields.get("light", "300").split()[0]);
        } except (ValueError, IndexError) {
            reach = 300.0;
        }
        # How far it lights, as a ring in each of the three planes.
        far = max(64.0, reach * 2.0);
        for i in range(32) {
            first = 2.0 * math.pi * float(i) / 32.0;
            second = 2.0 * math.pi * float(i + 1) / 32.0;
            a = far * math.cos(first);
            b = far * math.sin(first);
            c = far * math.cos(second);
            d = far * math.sin(second);
            wire_line(middle.add(Vec3(x=a, y=b)), middle.add(Vec3(x=c, y=d)), ink(0xf5d90a, 150));
            wire_line(middle.add(Vec3(x=a, z=b)), middle.add(Vec3(x=c, z=d)), ink(0xf5d90a, 90));
            wire_line(middle.add(Vec3(y=a, z=b)), middle.add(Vec3(y=c, z=d)), ink(0xf5d90a, 90));
        }
    }
}
