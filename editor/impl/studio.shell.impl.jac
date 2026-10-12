"""The studio's grid, remembered views, hiding, history and autosave.
Declarations live in studio.jac."""

"""Where a line of sight comes down on a level height, ahead of the eye and
no further than a level is wide. None when it never does."""
def:priv level_point(line: list[Vec3], height: float) -> Vec3 | None {
    if abs(line[1].z) < 0.0001 {
        return None;
    }
    along = (height - line[0].z) / line[1].z;
    if along <= 0.0 or along > 65536.0 {
        return None;
    }
    return line[0].add(line[1].scale(along));
}

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
    if name == "ed_clip_line" or name == "ed_box_draw" {
        numbers: list[int] = [];
        for word in args[1:6] {
            if word.lstrip("-").isdigit() {
                numbers.append(int(word));
            }
        }
        if len(numbers) < 5 or numbers[0] < 0 or numbers[0] >= len(self.ports) {
            self.say(name + " <view> <x0> <y0> <x1> <y1>");
            return True;
        }
        middle = scene.selection_middle();
        anchor = middle if middle is not None else Vec3();
        first = self.view_point(numbers[0], numbers[1], numbers[2], anchor);
        second = self.view_point(numbers[0], numbers[3], numbers[4], anchor);
        if first is None or second is None or second.sub(first).length() < 1.0 {
            self.say("That is too short to go by");
            return True;
        }
        into = self.ports[numbers[0]].camera.forward();
        if name == "ed_clip_line" {
            # The plane that holds the line and the view's own line of sight.
            normal = second.sub(first).cross(into);
            if normal.length() < 0.0001 {
                self.say("That line runs straight into the view");
                return True;
            }
            normal = normal.normalized();
            keep = args[6] if len(args) > 6 and args[6] in ["back", "front", "both"] else "both";
            if not scene.selected_solids() {
                self.say("Select the brushes to cut");
            } elif not scene.clip_selection(Plane3(normal=normal, dist=normal.dot(first)), keep, self.material) {
                self.say("That line cuts nothing selected");
            }
            return True;
        }
        if not self.is_built_scene() {
            self.say("Boxes are drawn in a scene of brushes");
            return True;
        }
        if self.ports[numbers[0]].camera.span <= 0.0 {
            # In the 3D view the rectangle is drawn on the level it would stand on: the height of
            # the selection's middle, or of the origin, on the grid.
            notch = max(1.0, self.grid);
            floor_at = float(round(anchor.z / notch)) * notch;
            watched = self.port_now;
            self.watch(numbers[0]);
            corner = level_point(self.camera.sight(self.view_area(), numbers[1], numbers[2]), floor_at);
            other = level_point(self.camera.sight(self.view_area(), numbers[3], numbers[4]), floor_at);
            self.watch(watched);
            if corner is None or other is None {
                self.say("That drag leaves the level the box would stand on: draw it on the floor");
                return True;
            }
            west = float(round(min(corner.x, other.x) / notch)) * notch;
            east = float(round(max(corner.x, other.x) / notch)) * notch;
            south = float(round(min(corner.y, other.y) / notch)) * notch;
            north = float(round(max(corner.y, other.y) / notch)) * notch;
            if east - west < notch or north - south < notch
                or scene.create_solid(
                    box_sides(Vec3(x=west, y=south, z=floor_at), Vec3(x=east, y=north, z=floor_at + 64.0), self.material)
                ) is None {
                self.say("That rectangle encloses nothing");
            }
            return True;
        }
        # The rectangle, and sixty-four units along the line of sight: up
        # from the anchor's height in the top view, about it in the others.
        low = Vec3(x=min(first.x, second.x), y=min(first.y, second.y), z=min(first.z, second.z));
        high = Vec3(x=max(first.x, second.x), y=max(first.y, second.y), z=max(first.z, second.z));
        deep = 64.0;
        if abs(into.z) > 0.5 {
            base = float(round(anchor.z / self.grid)) * self.grid;
            low = Vec3(x=low.x, y=low.y, z=base);
            high = Vec3(x=high.x, y=high.y, z=base + deep);
        } elif abs(into.y) > 0.5 {
            low = Vec3(x=low.x, y=anchor.y - deep * 0.5, z=low.z);
            high = Vec3(x=high.x, y=anchor.y + deep * 0.5, z=high.z);
        } else {
            low = Vec3(x=anchor.x - deep * 0.5, y=low.y, z=low.z);
            high = Vec3(x=anchor.x + deep * 0.5, y=high.y, z=high.z);
        }
        if scene.create_solid(box_sides(low, high, self.material)) is None {
            self.say("That rectangle encloses nothing");
        }
        return True;
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
        if word == "show" or word == "hide" or word == "toggle" {
            self.grid_shown = (not self.grid_shown) if word == "toggle" else word == "show";
            self.say("The grid is shown" if self.grid_shown else "The grid is hidden");
            self.keep_settings();
            return True;
        }
        if word == "up" {
            size = size * 2.0;
        } elif word == "down" {
            size = size / 2.0;
        } else {
            try {
                size = float(word);
            } except ValueError {
                self.say("ed_grid <size|up|down|show|hide>");
                return True;
            }
        }
        self.grid = max(1.0, min(256.0, float(round(size))));
        self.say("Grid " + str(int(self.grid)));
        self.keep_settings();
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
        if wanted == "next" or wanted == "prev" {
            self.marks_at = (self.marks_at + (1 if wanted == "next" else -1)) % len(marks);
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
        # Every layer that was off is on again too.
        for each in list(scene.layers_off) {
            scene.show_layer(each, True);
        }
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
        ahead = scene.journal.undone;
        if len(args) > 1 and args[1] == "list" {
            # Every edit made, oldest first, and then those undone, the next to be done again first.
            print("studio: history done=" + str(len(done)) + " undone=" + str(len(ahead)));
            for (place, made) in enumerate(done[-40:]) {
                print("studio: edit " + str(len(done) - min(40, len(done)) + place + 1) + " " + made.label);
            }
            for back in range(min(40, len(ahead))) {
                print("studio: undone " + str(back + 1) + " " + ahead[len(ahead) - 1 - back].label);
            }
            self.say(str(len(done)) + " edits made, " + str(len(ahead)) + " undone and waiting to be done again");
            return True;
        }
        if len(args) > 2 and args[1] == "redo" and args[2].isdigit() {
            again = min(int(args[2]), len(ahead));
            for i in range(again) {
                scene.redo();
            }
            self.say("Did " + str(again) + " edits again");
            return True;
        }
        if len(args) > 1 and args[1].isdigit() {
            count = min(int(args[1]), len(done));
            for i in range(count) {
                scene.undo();
            }
            self.say("Undid " + str(count) + " edits");
            return True;
        }
        if (len(done) == 0 and len(ahead) == 0) or stage is None {
            self.say("Nothing has been edited yet");
            return True;
        }
        # The newest edit first: choosing one undoes it and all after it.
        items: list[MenuItem] = [];
        for back in range(min(20, len(done))) {
            step = done[len(done) - 1 - back];
            items.append(MenuItem(text="Undo back to before: " + step.label, command="ed_history " + str(back + 1)));
        }
        # And forward again: choosing one does it and all before it again.
        for back in range(min(20, len(ahead))) {
            step = ahead[len(ahead) - 1 - back];
            items.append(MenuItem(text="Do again up to: " + step.label, command="ed_history redo " + str(back + 1)));
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

impl Studio.view_point(port: int, x: int, y: int, anchor: Vec3) -> Vec3 | None {
    if port < 0 or port >= len(self.ports) {
        return None;
    }
    watched = self.port_now;
    self.watch(port);
    found = self.on_view_plane(x, y, anchor);
    self.watch(watched);
    step = max(1.0, self.grid);
    return Vec3(
        x=float(round(found.x / step)) * step,
        y=float(round(found.y / step)) * step,
        z=float(round(found.z / step)) * step
    );
}

impl Studio.settings_path -> str {
    return override_folder() + "/studio.cfg";
}

impl Studio.keep_settings {
    if not self.settings_read {
        # Not before what was kept has been read: it would be written over.
        return;
    }
    lines = [
        "// The studio's settings, written when one changes.",
        "ed_grid " + str(int(self.grid)),
        # How finely, before whether at all: the second has the last word.
        "ed_build " + ("quick" if self.luxel > 16.0 else "full"),
        "ed_light " + ("on" if self.lit else "off"),
        "ed_display " + ("wire" if self.wire_axis else "textured") + " axis",
        "ed_display " + ("wire" if self.wire_main else "textured") + " 3d",
        "ed_brush " + str(int(self.brush_radius)) + " " + str(int(self.brush_amount)),
        "ed_layout " + ("4b" if self.layout == 5 else str(self.layout)),
        "ed_grid " + ("show" if self.grid_shown else "hide"),
        "ed_dev " + ("on" if self.dev_shown else "off"),
        "ed_autocaulk " + ("on" if self.autocaulk else "off"),
        "ed_mapopts comments " + ("on" if self.map_comments else "off"),
        "ed_mapopts whole " + ("on" if self.map_whole else "off"),
        "ed_ruler " + ("on" if self.ruler else "off"),
        "ed_names " + ("on" if self.names else "off"),
        "ed_anglesnap " + str(int(self.angle_snap)),
        "ed_texlock " + ("on" if self.tex_lock else "off")
    ];
    for kept_class in self.favourites {
        lines.append("ed_fav " + kept_class);
    }
    for chord in sorted(self.user_keys.keys()) {
        lines.append("ed_bind " + chord + " " + quote_command_word(self.user_keys[chord]));
    }
    lines.append("ed_outside " + self.outside);
    lines.append("ed_log panel " + ("on" if self.log_panel else "off") + " " + str(self.log_rows));
    lines.append("ed_flyover " + ("on" if self.flyovers else "off"));
    for tool in self.tools {
        for tool_line in tool.settings_lines(self.host()) {
            lines.append(tool_line);
        }
    }
    lines.append("ed_split x " + str(self.split_x));
    lines.append("ed_split y " + str(self.split_y));
    lines.append("ed_sides " + ("right" if self.sides_swapped else "left"));
    for kept_name in sorted(self.kept_layouts.keys()) {
        lines.append("ed_layout keep " + kept_name + " " + self.kept_layouts[kept_name]);
    }
    lines.append("ed_models " + ("on" if self.models_shown else "off"));
    lines.append("ed_mouse look " + str(round(self.look_rate, 2)));
    lines.append("ed_mouse invert " + ("on" if self.look_flipped else "off"));
    lines.append("ed_mouse wheel " + str(round(self.wheel_rate, 2)));
    lines.append("ed_mouse reverse " + ("on" if self.wheel_flipped else "off"));
    for ending in sorted(self.assoc.keys()) {
        lines.append("ed_assoc " + ending + " " + quote_command_word(self.assoc[ending]));
    }
    for setting in sorted(self.game_setup.keys()) {
        halves = setting.split(".", 1);
        lines.append("ed_game " + halves[0] + " " + halves[1] + " " + quote_command_word(self.game_setup[setting]));
    }
    for addon in self.user_addons {
        lines.append("ed_addon " + quote_command_word(addon));
    }
    for kept_recipe in sorted(self.recipes.keys()) {
        lines.append("ed_recipe " + kept_recipe + " " + quote_command_word(self.recipes[kept_recipe]));
    }
    path = self.settings_path();
    try {
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w") as file {
            file.write("\n".join(lines) + "\n");
        }
    } except OSError {
        return;
    }
}

impl Studio.read_settings {
    app = self.app;
    if self.settings_read or app is None {
        return;
    }
    self.settings_read = True;
    path = self.settings_path();
    if not os.path.isfile(path) {
        return;
    }
    try {
        with open(path, "r") as file {
            app.shell.insert_text(file.read());
        }
    } except OSError {
        return;
    }
}
