"""The studio's look at the level as a skill or mode would spawn it, the
skill options in an entity's form, and values replaced across entities.
Declarations live in studio.jac."""

impl Studio.fill_skill(scene: Scene, ui: StudioUi, chosen: list[Item]) {
    for item in chosen {
        if item.classname() == "worldspawn" or item.classname() == "func_group" {
            return;
        }
    }
    if scene.game == "q3" {
        # Quake III says this in fields of its own (notsingle, notfree, notteam).
        return;
    }
    form = ui.form;
    value = chosen[0].fields.get("spawnflags", "");
    form.adopt(Spacer(size=6));
    form.adopt(Label(text="Left out", tone="dim"));
    first = Box(across=True, gap=4);
    second = Box(across=True, gap=4);
    form.adopt(first);
    form.adopt(second);
    for (bit, words, row) in [
        (8, "on easy", first), (9, "on normal", first), (10, "on hard", second), (11, "in deathmatch", second)
    ] {
        row.adopt(
            Check(
                text=words,
                on_now=flag_set(value, bit),
                command="ed_flag " + str(bit),
                grow=1,
                hint="Does not spawn " + words + " (spawnflags " + str(1 << bit) + ")"
            )
        );
    }
}

"""The class each game has for a piece of logic, and the fields that make
it that piece: (kind, game, classname, fields as "key=value" words)."""
glob LOGIC_PIECES: list[tuple[str, str, str, str]] = [
    ("relay", "q1", "trigger_relay", ""),
    ("relay", "q2", "trigger_relay", ""),
    ("relay", "q3", "target_relay", ""),
    ("delay", "q1", "trigger_relay", "delay=1"),
    ("delay", "q2", "trigger_relay", "delay=1"),
    ("delay", "q3", "target_delay", "wait=1"),
    ("counter", "q1", "trigger_counter", "count=2"),
    ("counter", "q2", "trigger_counter", "count=2"),
    ("once", "q1", "trigger_once", ""),
    ("once", "q2", "trigger_once", ""),
    ("once", "q3", "trigger_multiple", "wait=-1"),
    ("multiple", "q1", "trigger_multiple", "wait=1"),
    ("multiple", "q2", "trigger_multiple", "wait=1"),
    ("multiple", "q3", "trigger_multiple", "wait=1"),
    ("message", "q1", "trigger_relay", "message=A message"),
    ("message", "q2", "target_help", "message=A message"),
    ("message", "q3", "target_print", "message=A message"),
    ("timer", "q2", "func_timer", "wait=2"),
    ("timer", "q3", "func_timer", "wait=2"),
    ("changelevel", "q1", "trigger_changelevel", "map=start"),
    ("changelevel", "q2", "target_changelevel", "map=base1"),
    ("speaker", "q2", "target_speaker", "noise=world/drip1.wav"),
    ("speaker", "q3", "target_speaker", "noise=sound/world/drip1.wav")
];

"""The game whose rules a scene's logic runs under: its own, or Quake's for
a scene that names none."""
def:priv logic_game(scene: Scene) -> str {
    return scene.game if scene.game in ["q1", "q2", "q3"] else "q1";
}

impl Studio.mark_handles(scene: Scene) -> list[tuple[int, Vec3]] {
    found: list[tuple[int, Vec3]] = [];
    chosen = scene.selection();
    if len(chosen) != 1 or scene.selected_solids() or chosen[0].origin() is None {
        return found;
    }
    boxed = self.shape_of(chosen[0]);
    if boxed is None {
        return found;
    }
    middle = boxed.center();
    facing = chosen[0].fields.get("angle", "");
    if facing.replace(".", "", 1).isdigit() and abs(self.camera.forward().z) > 0.2 {
        # Seen from the side the arrow cannot be swung, so no handle there.
        turn = math.radians(float(facing));
        found.append((940, middle.add(Vec3(x=math.cos(turn), y=math.sin(turn)).scale(48.0))));
    }
    if chosen[0].classname().startswith("light") {
        reach = 300.0;
        words = chosen[0].fields.get("light", "300").split();
        if len(words) > 0 and words[0].replace(".", "", 1).isdigit() {
            reach = float(words[0]);
        }
        found.append((941, middle.add(self.camera.right().scale(max(64.0, reach * 2.0)))));
    }
    return found;
}

impl Studio.drag_mark(scene: Scene, x: int, y: int, free: bool) {
    chosen = scene.selection();
    boxed = self.shape_of(chosen[0]) if len(chosen) == 1 else None;
    if boxed is None {
        return;
    }
    middle = boxed.center();
    if self.resize_side == 941 {
        # As far from the light as the pointer is, in the plane facing the view.
        far = self.on_view_plane(x, y, middle).sub(middle).length();
        notch = 1.0 if free else 10.0;
        self.turn_by = max(10.0, float(round(far * 0.5 / notch)) * notch);
        return;
    }
    # Where the line of sight meets the level plane through its middle.
    line = self.camera.sight(self.view_area(), x, y);
    if abs(line[1].z) < 0.0001 {
        return;
    }
    met = line[0].add(line[1].scale((middle.z - line[0].z) / line[1].z)).sub(middle);
    if met.length() < 1.0 {
        return;
    }
    swung = math.degrees(math.atan2(met.y, met.x)) % 360.0;
    step = 1.0 if free else max(1.0, self.angle_snap);
    self.turn_by = (float(round(swung / step)) * step) % 360.0;
}

impl Studio.draw_mark_handles(scene: Scene, area: Rect) {
    canvas = self.canvas;
    chosen = scene.selection();
    boxed = self.shape_of(chosen[0]) if len(chosen) == 1 else None;
    if boxed is None {
        return;
    }
    middle = boxed.center();
    held = self.resize_side if self.resizing else -1;
    for (index, spot) in self.mark_handles(scene) {
        shown_at = spot;
        words = "";
        if held == index and self.turn_by < 0.0 {
            # Taken hold of, not yet dragged.
            words = "";
        } elif held == index and index == 940 {
            turn = math.radians(self.turn_by);
            shown_at = middle.add(Vec3(x=math.cos(turn), y=math.sin(turn)).scale(48.0));
            words = "angle " + str(int(round(self.turn_by)));
        } elif held == index and index == 941 {
            shown_at = middle.add(self.camera.right().scale(max(64.0, self.turn_by * 2.0)));
            words = "light " + str(int(round(self.turn_by)));
        }
        at = self.camera.project(area, shown_at);
        if at is None {
            continue;
        }
        tone = ink(0x4cc38a) if index == 940 else ink(0xf5d90a);
        knob = Rect(x=at[0] - 4, y=at[1] - 4, w=9, h=9);
        canvas.fill(knob, canvas.theme.accent if held == index else tone);
        canvas.outline(knob, canvas.theme.header);
        if words {
            wide = canvas.text_width(words, canvas.theme.small) + 8;
            tag = Rect(x=at[0] - wide // 2, y=at[1] + 10, w=wide, h=16);
            canvas.fill(tag, canvas.theme.header.faded(210));
            canvas.label(words, tag, canvas.theme.text, 0, 0, canvas.theme.small);
        }
    }
}

impl Studio.draw_paths {
    # Each corner of a path to the corner it sends its train on to.
    tone = ink(0x5b8def, 170);
    for shape in self.shapes {
        aim = shape.item.fields.get("target", "");
        if not aim or not shape.item.classname().startswith("path_") {
            continue;
        }
        for other in self.shapes {
            if other.item is not shape.item and other.item.fields.get("targetname", "") == aim {
                wire_line(shape.center(), other.center(), tone);
            }
        }
    }
}

impl Studio.entity_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_fav" {
        wanted = args[1].strip() if len(args) > 1 else "";
        if not wanted {
            self.say("Favourites: " + ", ".join(self.favourites) if self.favourites else "ed_fav <classname> keeps a class as a favourite");
            return True;
        }
        if wanted in self.favourites {
            self.favourites = [other for other in self.favourites if other != wanted];
            self.say(wanted + " is no longer a favourite");
        } else {
            self.favourites.append(wanted);
            self.say(wanted + " is a favourite: it is in the Library tab");
        }
        self.keep_settings();
        ui = self.ui;
        if ui is not None {
            ui.library.rows = [];
        }
        return True;
    }
    if name == "ed_logic" {
        game = logic_game(scene);
        kinds = [piece[0] for piece in LOGIC_PIECES if piece[1] == game];
        wanted = args[1] if len(args) > 1 else "";
        stage = self.stage;
        if wanted not in kinds {
            # The pieces this game has, each a line to add one.
            for kind in kinds {
                print("studio: logic kind " + kind);
            }
            if stage is not None and not wanted {
                popup = MenuPopup(items=[MenuItem(text="Add a " + kind, command="ed_logic " + kind) for kind in kinds]);
                popup.open_at(stage, 300, 80);
            } else {
                self.say("ed_logic <" + "|".join(kinds) + ">");
            }
            return True;
        }
        for piece in LOGIC_PIECES {
            if piece[0] != wanted or piece[1] != game {
                continue;
            }
            self.create(scene, ["ed_new", piece[2]]);
            fresh: dict[str, str | None] = {"targetname": scene.fresh_name(wanted)};
            for pair in piece[3].split("|") {
                if "=" in pair {
                    fresh[pair.split("=")[0]] = pair.split("=", 1)[1];
                }
            }
            scene.set_fields(fresh, "Logic " + wanted);
            self.say("Added a " + wanted + " (" + piece[2] + "): drag from a box to it in the logic graph to wire it");
            break;
        }
        return True;
    }
    if name == "ed_spawn" {
        mode = args[1] if len(args) > 1 else "";
        if mode not in ["all", "easy", "normal", "hard", "deathmatch"] {
            self.say("ed_spawn <all|easy|normal|hard|deathmatch>");
            return True;
        }
        self.spawn_hidden = scene.spawn_preview(mode, self.spawn_hidden);
        self.spawn_mode = mode;
        self.say(
            "Everything that spawns is shown"
            if mode == "all"
            else str(len(self.spawn_hidden)) + " entities do not spawn " + ("in deathmatch" if mode == "deathmatch" else "on " + mode)
        );
        return True;
    }
    if name == "ed_refield" {
        if len(args) < 4 {
            self.say("ed_refield <key> <old> <new> [all]");
            return True;
        }
        count = scene.replace_values(args[1], args[2], args[3], len(args) > 4 and args[4] == "all");
        self.say(
            "Changed " + args[1] + " on " + str(count) + " entities"
            if count
            else "No " + ("entity" if len(args) > 4 else "selected entity") + " has " + args[2] + " in " + args[1]
        );
        return True;
    }
    return False;
}

impl Studio.fill_controls(scene: Scene, ui: StudioUi, chosen: list[Item]) {
    if len(chosen) == 0 {
        return;
    }
    first = chosen[0];
    form = ui.form;
    at = first.origin();
    if at is not None {
        form.adopt(Spacer(size=6));
        form.adopt(Label(text="Drag to change", tone="dim"));
        form.adopt(
            VectorField(
                x=at.x,
                y=at.y,
                z=at.z,
                step=self.grid,
                command="ed_set origin",
                hint="Where it is: drag across a number to move it by grid steps (Shift: ten at a time)"
            )
        );
    }
    facing = first.fields.get("angle", "");
    if facing.lstrip("-").replace(".", "", 1).isdigit() and float(facing) >= 0.0 {
        form.adopt(
            Spinner(
                text="angle",
                value=float(facing),
                step=self.angle_snap,
                low=0.0,
                high=345.0,
                command="ed_set angle",
                hint="The way it faces: drag across to turn it by the angle step"
            )
        );
    }
    if not first.classname().startswith("light") {
        return;
    }
    strength = first.fields.get("light", "300");
    form.adopt(
        Slider(
            low=0.0,
            high=1000.0,
            value=float(strength) if strength.replace(".", "", 1).isdigit() else 300.0,
            step=10.0,
            command="ed_set light",
            hint="How far the light reaches"
        )
    );
    shares = [1.0, 1.0, 1.0];
    parts = first.fields.get("_color", "").split();
    if len(parts) == 3 {
        try {
            shares = [float(parts[0]), float(parts[1]), float(parts[2])];
        } except ValueError {
            shares = [1.0, 1.0, 1.0];
        }
    }
    form.adopt(
        ColourBars(
            red=max(0.0, min(1.0, shares[0])),
            green=max(0.0, min(1.0, shares[1])),
            blue=max(0.0, min(1.0, shares[2])),
            command="ed_set _color",
            hint="The light's colour: drag along the red, green and blue bars"
        )
    );
}
