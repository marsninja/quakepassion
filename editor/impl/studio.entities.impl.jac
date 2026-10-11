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

impl Studio.entity_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
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
