"""The host's side of the console: configuration (Host_Init and quake.rc), the
command buffer's dispatch (Cbuf_Execute), the frame's key events (Key_Event)
and the commands the host runs. Declarations live in app.jac."""

impl App.configure() {
    if self.configured {
        return;
    }
    self.configured = True;
    self.shell.boot();
    self.keyboard.declare(self.shell);
    self.controls.declare(self.shell);
    self.console.declare(self.shell);
    self.renderer.declare(self.shell);
    self.audio.declare(self.shell);
    self.hud.declare(self.shell);
    host = self.host;
    host.skill = self.shell.register(host.skill);
    host.god = self.shell.register(host.god);
    host.flyspeed = self.shell.register(host.flyspeed);
    host.overlay = self.shell.register(host.overlay);
    for (name, usage, description) in HOST_COMMANDS {
        self.shell.command(name, "host", usage, description);
    }
    if not self.smoke {
        # The settings file holds every archived cvar, so a game's default.cfg
        # never overrides them; a missing or older one is completed now.
        preferences = Preferences();
        try {
            if not preferences.current() {
                self.shell.insert_text(preferences.settings_text());
                self.execute_commands();
                self.save_preferences();
            }
        } except Exception as error {
            self.shell.print("Settings: " + str(error));
            self.show_notice("Settings: " + str(error));
        }
    }
    self.configure_game(self.level.bsp.game);
    if self.stuffed {
        self.shell.add_text(self.stuffed);
    }
}

impl App.configure_game(game: str) {
    if not self.configured {
        # Everything is declared first; that ends by configuring the level's game.
        self.configure();
        return;
    }
    self.configured_game = game;
    defaults = self.read_config("default.cfg");
    script = defaults + "\n" + binding_layer(game, bool(defaults.strip())) + "\n";
    if not self.smoke {
        preferences = Preferences();
        try {
            script += preferences.settings_text() + "\n" + preferences.bindings_text(game) + "\n";
        } except Exception as error {
            self.shell.print("Settings: " + str(error));
        }
    }
    self.shell.insert_text(script);
    self.execute_commands();
    self.keyboard.dirty = False;
}

impl App.execute_commands() -> bool {
    while True {
        args = self.shell.next_command();
        if not args {
            break;
        }
        forwarded = self.shell.run(args);
        if forwarded is None {
            continue;
        }
        if forwarded.owner == "keys" {
            self.keyboard.command(self.shell, args);
        } elif forwarded.owner == "input" {
            self.controls.command(self.shell, args);
        } else {
            self.host_command(args);
        }
        if self.quitting {
            return False;
        }
    }
    return True;
}

impl App.handle_keys() -> bool {
    polled = self.keyboard.poll();
    events = polled[0];
    typed = polled[1];
    escape = False;
    shift = self.keyboard.is_down("SHIFT");
    ctrl = self.keyboard.is_down("CTRL") or self.keyboard.is_down("COMMAND");
    alt = self.keyboard.is_down("ALT");
    for event in events {
        name = event.key.name;
        if not event.down {
            # Key up events run the "-" half of button bindings in every mode,
            # so nothing stays held through a console or a menu.
            for command in key_event_commands(event.key.binding, name, False) {
                self.shell.add_text(command);
            }
            continue;
        }
        if self.menu.opened and self.menu.grabbing {
            if not event.repeat {
                self.grab_key(name);
            }
            continue;
        }
        if (name == "ENTER" or name == "KP_ENTER") and alt {
            # CL_KeyEvent: alt+enter flips fullscreen and restarts the video.
            if not event.repeat {
                self.shell.add_text("toggle vid_fullscreen\nvid_restart");
            }
            continue;
        }
        # The console key is hard-wired so it cannot be unbound (Q3), and
        # shift+Escape opens it too (ioquake3).
        if (name == "`" or (name == "ESCAPE" and shift)) and not self.menu.opened {
            if not event.repeat {
                self.toggle_console();
            }
            continue;
        }
        if name == "ESCAPE" {
            # M_ToggleMenu_f: Escape puts the console away, else the menu.
            if not event.repeat {
                if self.console.active {
                    self.toggle_console();
                } else {
                    escape = True;
                }
            }
            continue;
        }
        if self.console.active and self.console.key(self.shell, name, ctrl, shift) {
            continue;
        }
        if event.repeat or self.menu.opened {
            continue;
        }
        if name == "MOUSE1" and not mouse_captured() and not self.console.active {
            # A click on a free cursor captures the mouse rather than firing.
            _capture();
            continue;
        }
        for command in key_event_commands(event.key.binding, name, True) {
            self.shell.add_text(command);
        }
    }
    if self.console.active and typed {
        self.console.type_text("".join(typed));
    }
    return escape;
}

impl App.toggle_console() {
    self.console.toggle();
    if self.console.active {
        self.console_restore_mouse = mouse_captured();
        _release();
    } elif self.console_restore_mouse and not self.menu.opened {
        _capture();
    }
}

impl App.prompt_key(code: int) -> bool {
    return not self.console.active and IsKeyPressed(i32(code));
}

impl App.culling() -> bool {
    return not self.renderer.cvars.novis.on();
}

impl App.read_config(name: str) -> str {
    game = self.configured_game if self.configured_game else self.level.bsp.game;
    if not name or ".." in name {
        return "";
    }
    directory = game_directory(game);
    path = directory + "/" + name;
    try {
        if os.path.isfile(path) {
            return read_save(path);
        }
        if game not in ["q1", "q2", "q3"] {
            return "";
        }
        library = AssetLibrary(game=game);
        library.open(directory);
        text = "";
        if library.exists(name) {
            text = library.read(name).decode("latin-1");
        }
        library.close();
        return text;
    } except Exception as error {
        self.shell.print("couldn't read " + name + ": " + str(error));
    }
    return "";
}

impl App.host_command(args: list[str]) {
    name = args[0].lower();
    rest = " ".join(args[1:]);
    if name == "quit" {
        self.quitting = True;
    } elif name == "toggleconsole" {
        self.toggle_console();
    } elif name == "togglemenu" {
        self.menu_requested = True;
    } elif name == "map" {
        if len(args) < 2 {
            self.shell.print("map <levelname> : start a level of " + self.level.bsp.game);
            return;
        }
        if self.console.active {
            self.toggle_console();
        }
        self.load_destination(self.level.bsp.game, args[1]);
        if self.menu.opened and self.menu.message {
            self.shell.print(self.menu.message);
        }
    } elif name == "god" {
        # Host_God_f / Cmd_God_f.
        self.host.god.assign("0" if self.host.god.on() else "1");
        self.player.god_mode = self.host.god.on();
        self.shell.print("godmode ON" if self.host.god.on() else "godmode OFF");
    } elif name == "noclip" {
        # Host_Noclip_f: the engine's fly mode passes through walls.
        was_walking = self.walking;
        self.toggle_movement();
        if self.walking == was_walking {
            self.shell.print(self.movement_status);
        } else {
            self.shell.print("noclip OFF" if self.walking else "noclip ON");
        }
    } elif name == "give" {
        self.give(args);
    } elif name == "kill" {
        # Q2/Q3 Cmd_Kill_f: suicide, even in god mode.
        if self.player.health <= 0 {
            self.shell.print("Can't suicide -- already dead!");
            return;
        }
        self.player spawn Damage(amount=100000, bypass_armor=True, bypass_protection=True, means="suicide");
        self.player.health = min(self.player.health, 0);
    } elif name == "use" {
        if not rest {
            self.shell.print("use <item>");
            return;
        }
        self.use_named(rest);
    } elif name == "cmd" {
        if rest {
            self.shell.insert_text(rest);
        }
    } elif name == "exec" {
        if len(args) != 2 {
            self.shell.print("exec <filename> : execute a script file");
            return;
        }
        text = self.read_config(args[1]);
        if not text {
            self.shell.print("couldn't exec " + args[1]);
            return;
        }
        self.shell.print("execing " + args[1]);
        self.shell.insert_text(text);
    } elif name == "writeconfig" {
        if len(args) != 2 {
            self.shell.print("writeconfig <filename> : write the settings and bindings");
            return;
        }
        target = args[1] if args[1].endswith(".cfg") else args[1] + ".cfg";
        if "/" in target or ".." in target {
            self.shell.print("writeconfig: a file name, not a path");
            return;
        }
        path = game_directory(self.level.bsp.game) + "/" + target;
        try {
            write_save(
                path,
                "// generated by QuakePassion\n"
                    + "\n".join(self.keyboard.binding_lines() + self.shell.archive_lines())
                    + "\n"
            );
            self.shell.print("Writing " + path);
        } except Exception as error {
            self.shell.print("Couldn't write " + target + ": " + str(error));
        }
    } elif name == "save" {
        if not self.level.active {
            return;
        }
        self.quicksave(args[1] if len(args) > 1 else "");
        self.shell.print(self.notice);
    } elif name == "load" {
        self.quickload(args[1] if len(args) > 1 else "");
        self.shell.print(self.notice);
    } elif name == "screenshot" {
        # SCR_ScreenShot_f: the next free numbered name, in the working folder.
        shot = args[1] if len(args) > 1 else "";
        if not shot {
            for number in range(10000) {
                digits = str(number);
                candidate = "quakepassion" + "0" * (4 - len(digits)) + digits + ".png";
                if not os.path.exists(candidate) {
                    shot = candidate;
                    break;
                }
            }
        } elif not shot.endswith(".png") {
            shot += ".png";
        }
        self.renderer.screenshot(shot);
        self.shell.print("Wrote " + shot);
    } elif name == "vid_restart" {
        self.renderer.apply_video();
        self.shell.print(
            "Video: " + str(self.renderer.width) + " x " + str(self.renderer.height)
                + (" fullscreen" if self.renderer.cvars.fullscreen.on() else " windowed")
        );
    }
}

impl App.give(args: list[str]) {
    if len(args) < 2 {
        self.shell.print("give <item> [count]");
        return;
    }
    p = self.player;
    if p.health <= 0 {
        return;
    }
    item = " ".join(args[1:]).lower();
    count = -1;
    if len(args) > 2 and args[-1].isdigit() {
        count = int(args[-1]);
        item = " ".join(args[1:-1]).lower();
    }
    game = self.level.bsp.game;
    everything = item == "all";
    given = False;
    if everything or item == "health" or (game == "q1" and item == "h") {
        # Q1 sets health to the count; Q2/Q3 fill it to the maximum.
        p.health = count if count > 0 else max(p.health, p.max_health);
        given = True;
    }
    if everything or item == "weapons" {
        for rule in self.combat.rules {
            if not rule.hand_thrown {
                p.inventory spawn AdjustInventory(kind="weapon_" + rule.key, amount=1, capacity=1);
            }
        }
        given = True;
    }
    if everything or item == "ammo" {
        for rule in self.combat.rules {
            if rule.ammo {
                p.inventory spawn AdjustInventory(kind=rule.ammo, amount=rule.capacity, capacity=rule.capacity);
            }
        }
        given = True;
    }
    if everything or item == "armor" {
        # Red armor (Q1), body armor (Q2), a full 200 (Q3).
        p.armor = max(p.armor, 200);
        p.armor_capacity = max(p.armor_capacity, 200);
        p.armor_ratio = 0.66 if game == "q3" else 0.8;
        given = True;
    }
    if not given and game == "q1" and len(item) == 1 {
        # Host_Give_f: a weapon number, or s, n, r, c for ammo.
        ammo = {"s": "shells", "n": "nails", "r": "rockets", "c": "cells"};
        if item in ammo {
            p.inventory spawn AdjustInventory(kind=ammo[item], amount=count if count > 0 else 100, capacity=200);
            given = True;
        } elif item.isdigit() {
            for rule in self.combat.rules {
                if rule.slot == int(item) {
                    p.inventory spawn AdjustInventory(kind="weapon_" + rule.key, amount=1, capacity=1);
                    given = True;
                }
            }
        }
    }
    if not given {
        # A weapon by name, an ammo kind or a stored item by name or kind.
        for rule in self.combat.rules {
            if rule.name.lower() == item or rule.key == item {
                p.inventory spawn AdjustInventory(kind="weapon_" + rule.key, amount=1, capacity=1);
                if rule.ammo and rule.hand_thrown {
                    p.inventory spawn AdjustInventory(kind=rule.ammo, amount=max(1, count), capacity=rule.capacity);
                }
                given = True;
            } elif rule.ammo == item {
                p.inventory spawn AdjustInventory(kind=rule.ammo, amount=count if count > 0 else rule.capacity, capacity=rule.capacity);
                given = True;
            }
        }
        if not given {
            for kind in stored_kinds(game) {
                if kind == item or item_label(kind).lower() == item {
                    p.inventory spawn AdjustInventory(kind=kind, amount=max(1, count), capacity=max(1, count));
                    given = True;
                }
            }
        }
    }
    if not given {
        self.shell.print("unknown item");
    }
}

impl App.use_named(name: str) {
    wanted = name.lower();
    if wanted == "grenades" {
        wanted = "hand grenades";
    }
    for rule in self.combat.rules {
        if rule.name.lower() == wanted {
            self.controls.pending.weapon = rule.slot;
            return;
        }
    }
    for kind in stored_kinds(self.level.bsp.game) {
        if item_label(kind).lower() == wanted or kind == wanted {
            self.controls.pending.use_item = True;
            self.controls.pending.use_kind = kind;
            return;
        }
    }
    self.shell.print("unknown item: " + name);
}

impl App.impulse(number: int) {
    if self.level.bsp.game != "q1" {
        return;
    }
    if number == 9 {
        # CheatCommand: every weapon and full ammunition.
        self.give(["give", "weapons"]);
        self.give(["give", "ammo"]);
    } elif number == 255 {
        # QuadCheat.
        self.give(["give", "powerup_quad"]);
    }
}

impl App.refresh_controls() {
    labels: list[str] = [];
    keys: list[str] = [];
    for (command, label) in control_actions(self.level.bsp.game) {
        labels.append(label);
        keys.append(" or ".join(self.keyboard.keys_for(command)));
    }
    self.menu.controls_labels = labels;
    self.menu.controls_keys = keys;
}

impl App.grab_key(name: str) {
    self.menu.grabbing = False;
    if name == "ESCAPE" or name == "`" {
        return;
    }
    actions = control_actions(self.level.bsp.game);
    row = self.menu.controls_selected;
    if row < 0 or row >= len(actions) {
        return;
    }
    command = actions[row][0];
    # M_Keys_Key: an action holds two keys; a third replaces them.
    if len(self.keyboard.keys_for(command)) >= 2 {
        for bound in self.keyboard.keys_for(command) {
            self.keyboard.set_binding(bound, "");
        }
    }
    self.keyboard.set_binding(name, command);
    self.save_bindings();
}

impl App.control_action(action: str) {
    actions = control_actions(self.level.bsp.game);
    if action == "unbind" {
        row = self.menu.controls_selected;
        if row >= 0 and row < len(actions) {
            for bound in self.keyboard.keys_for(actions[row][0]) {
                self.keyboard.set_binding(bound, "");
            }
            self.save_bindings();
        }
    } elif action == "controls_reset" {
        try {
            Preferences().forget_bindings(self.level.bsp.game);
        } except Exception as error {
            self.menu.message = "Bindings: " + str(error);
        }
        self.configure_game(self.level.bsp.game);
        self.menu.message = "Default controls restored";
    }
}

impl App.save_bindings() {
    try {
        Preferences().save_bindings(self.configured_game, self.keyboard.binding_lines());
        self.keyboard.dirty = False;
        self.menu.message = "Controls saved";
    } except Exception as error {
        self.menu.message = "Controls save failed: " + str(error);
    }
}

impl App.save_file(slot: str) -> str {
    if not slot or slot == "quick" {
        return self.save_path or os.getenv("HOME", ".") + "/.quakepassion-save.txt";
    }
    return os.getenv("HOME", ".") + "/.quakepassion-save-" + slot.replace("/", "_") + ".txt";
}
