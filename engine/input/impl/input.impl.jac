"""Implementations for the input module: mouse-capture lifecycle, the buttons
and the per-frame usercmd. Declarations (and the raylib import) live in
input.jac."""

impl mouse_captured() -> bool {
    return _mouse.captured;
}

impl _capture() {
    DisableCursor();
    _mouse.captured = True;
    _mouse.warmup = 10;
}

impl _release() {
    EnableCursor();
    _mouse.captured = False;
}

impl mouse_motion() -> tuple[float, float] {
    if not _mouse.captured {
        return (0.0, 0.0);
    }
    mx = float(GetMouseX());
    my = float(GetMouseY());
    dx = 0.0;
    dy = 0.0;
    if _mouse.warmup > 0 {
        _mouse.warmup -= 1;
    } else {
        dx = mx - _mouse.prev_x;
        dy = my - _mouse.prev_y;
        if dx <= -SPIKE_LIMIT or dx >= SPIKE_LIMIT or dy <= -SPIKE_LIMIT or dy >= SPIKE_LIMIT {
            dx = 0.0;
            dy = 0.0;
        }
    }
    _mouse.prev_x = mx;
    _mouse.prev_y = my;
    return (dx, dy);
}

impl Button.press(holder: str) {
    if holder in self.holders {
        return;  # a repeating key
    }
    if len(self.holders) >= 2 {
        return;  # "Three keys down for a button!"
    }
    self.holders.append(holder);
    if self.state & 1 {
        return;  # still down
    }
    self.state = self.state | 3;
}

impl Button.release(holder: str) {
    if not holder {
        # Typed at the console: let go whatever holds it.
        self.holders = [];
        if self.state & 1 {
            self.state = 4;
        }
        return;
    }
    if holder not in self.holders {
        return;  # up without a matching down (a key held through a menu)
    }
    self.holders.remove(holder);
    if self.holders or not self.state & 1 {
        return;
    }
    self.state = (self.state & ~1) | 4;
}

impl Button.fraction -> float {
    went_down = bool(self.state & 2);
    went_up = bool(self.state & 4);
    down = bool(self.state & 1);
    if went_down and went_up {
        return 0.75 if down else 0.25;
    }
    if went_down {
        return 0.5 if down else 0.0;
    }
    if went_up {
        return 0.0;
    }
    return 1.0 if down else 0.0;
}

impl Button.held -> bool {
    return bool(self.state & 1);
}

impl Button.active -> bool {
    return bool(self.state & 3);
}

impl Button.went_down -> bool {
    return bool(self.state & 2);
}

impl FindButton.start with Controls entry {
    visit [here->:Holds:->];
}

impl FindButton.check with Button entry {
    if here.name == self.name {
        self.found = here;
        disengage;
    }
}

impl ReadButtons.start with Controls entry {
    visit [here->:Holds:->];
}

impl ReadButtons.read with Button entry {
    self.fraction[here.name] = here.fraction();
    self.held[here.name] = here.held();
    self.active[here.name] = here.active();
    self.went_down[here.name] = here.went_down();
    here.state = here.state & 1;
}

impl ReleaseButtons.start with Controls entry {
    visit [here->:Holds:->];
}

impl ReleaseButtons.release with Button entry {
    here.release("");
}

impl Controls.declare(shell: Shell) {
    if not self.booted {
        self.booted = True;
        for name in BUTTON_NAMES {
            self +>:Holds:+> Button(name=name);
        }
    }
    cvars = self.cvars;
    cvars.sensitivity = shell.register(cvars.sensitivity);
    cvars.m_pitch = shell.register(cvars.m_pitch);
    cvars.m_yaw = shell.register(cvars.m_yaw);
    cvars.m_forward = shell.register(cvars.m_forward);
    cvars.m_side = shell.register(cvars.m_side);
    cvars.freelook = shell.register(cvars.freelook);
    cvars.lookstrafe = shell.register(cvars.lookstrafe);
    cvars.forward_speed = shell.register(cvars.forward_speed);
    cvars.back_speed = shell.register(cvars.back_speed);
    cvars.side_speed = shell.register(cvars.side_speed);
    cvars.up_speed = shell.register(cvars.up_speed);
    cvars.speed_key = shell.register(cvars.speed_key);
    cvars.yaw_speed = shell.register(cvars.yaw_speed);
    cvars.pitch_speed = shell.register(cvars.pitch_speed);
    cvars.angle_speed_key = shell.register(cvars.angle_speed_key);
    cvars.run = shell.register(cvars.run);
    for name in BUTTON_NAMES {
        shell.command("+" + name, "input", "+" + name + " [key]", "hold the " + name + " button");
        shell.command("-" + name, "input", "-" + name + " [key]", "let go of the " + name + " button");
    }
    for (name, usage, description) in [
        ("impulse", "impulse <number>", "a Quake impulse: 1-8 weapons, 10 next, 12 previous"),
        ("weapon", "weapon <number>", "select a weapon slot"),
        ("weapnext", "weapnext", "next weapon"),
        ("weapprev", "weapprev", "previous weapon"),
        ("invuse", "invuse", "use the selected item"),
        ("invnext", "invnext", "select the next item"),
        ("invprev", "invprev", "select the previous item"),
        ("inven", "inven", "show or hide the inventory"),
        ("help", "help", "show or hide the help computer"),
        ("centerview", "centerview", "look straight ahead")
    ] {
        shell.command(name, "input", usage, description);
    }
}

impl Controls.button(name: str) -> Button | None {
    search = self spawn FindButton(name=name);
    return search.found;
}

impl Controls.command(shell: Shell, args: list[str]) {
    name = args[0].lower();
    if name.startswith("+") or name.startswith("-") {
        held = self.button(name[1:]);
        if held is None {
            return;
        }
        holder = args[1] if len(args) > 1 else "";
        if name.startswith("+") {
            held.press(holder);
        } else {
            held.release(holder);
        }
        return;
    }
    wanted = self.pending;
    if name == "impulse" {
        # Q1 weapons.qc ImpulseCommands: 1-8 choose a weapon, 10 and 12
        # cycle; the others go to the game (9 and 255 are its cheats).
        number = int(args[1]) if len(args) > 1 and args[1].isdigit() else 0;
        if number >= 1 and number <= 8 {
            wanted.weapon = number;
        } elif number == 10 {
            wanted.weapon_step = 1;
        } elif number == 12 {
            wanted.weapon_step = -1;
        } elif number > 0 {
            wanted.impulse = number;
        }
    } elif name == "weapon" {
        number = int(args[1]) if len(args) > 1 and args[1].isdigit() else 0;
        if number > 0 {
            wanted.weapon = number;
        }
    } elif name == "weapnext" {
        wanted.weapon_step = 1;
    } elif name == "weapprev" {
        wanted.weapon_step = -1;
    } elif name == "invuse" {
        wanted.use_item = True;
    } elif name == "invnext" {
        wanted.next_item = True;
    } elif name == "invprev" {
        wanted.prev_item = True;
    } elif name == "inven" {
        wanted.inventory = True;
    } elif name == "help" {
        wanted.help = True;
    } elif name == "centerview" {
        wanted.center_view = True;
    }
}

impl Controls.full_move_speed -> float {
    return max(1.0, self.cvars.forward_speed.number * self.cvars.speed_key.number);
}

impl Controls.release_all {
    self spawn ReleaseButtons();
}

impl Controls.sample(dt: float) -> Intent {
    cvars = self.cvars;
    b = self spawn ReadButtons();
    intent = self.pending;
    self.pending = Intent();
    # CL_AdjustAngles (Quake's pitch grows looking down; ours looking up).
    turn = dt * (cvars.angle_speed_key.number if b.held["speed"] else 1.0);
    yaw = 0.0;
    pitch = 0.0;
    if not b.held["strafe"] {
        yaw += turn * cvars.yaw_speed.number * (b.fraction["left"] - b.fraction["right"]);
    }
    if b.held["klook"] {
        pitch += turn * cvars.pitch_speed.number * (b.fraction["forward"] - b.fraction["back"]);
    }
    pitch += turn * cvars.pitch_speed.number * (b.fraction["lookup"] - b.fraction["lookdown"]);
    # CL_BaseMove, with Q2/Q3's cl_run: the speed key walks while it is set.
    side = cvars.side_speed.number * (b.fraction["moveright"] - b.fraction["moveleft"]);
    if b.held["strafe"] {
        side += cvars.side_speed.number * (b.fraction["right"] - b.fraction["left"]);
    }
    up = cvars.up_speed.number * (
        max(b.fraction["moveup"], b.fraction["jump"]) - b.fraction["movedown"]
    );
    ahead = 0.0;
    if not b.held["klook"] {
        ahead = cvars.forward_speed.number * b.fraction["forward"]
            - cvars.back_speed.number * b.fraction["back"];
    }
    if b.held["speed"] != cvars.run.on() {
        side *= cvars.speed_key.number;
        up *= cvars.speed_key.number;
        ahead *= cvars.speed_key.number;
    }
    # IN_MouseMove: sensitivity scales the motion; the mouse turns, looks and
    # (with +strafe, or without mouse look) moves.
    motion = mouse_motion();
    mouse_x = motion[0] * cvars.sensitivity.number;
    mouse_y = motion[1] * cvars.sensitivity.number;
    looking = cvars.freelook.on() or b.held["mlook"];
    if b.held["strafe"] or (cvars.lookstrafe.on() and looking) {
        side += cvars.m_side.number * mouse_x;
    } else {
        yaw -= cvars.m_yaw.number * mouse_x;
    }
    if looking and not b.held["strafe"] {
        pitch -= cvars.m_pitch.number * mouse_y;
    } else {
        ahead -= cvars.m_forward.number * mouse_y;
    }
    full = self.full_move_speed();
    intent.move = Vec3(
        x=max(-1.0, min(1.0, side / full)),
        y=max(-1.0, min(1.0, ahead / full)),
        z=max(-1.0, min(1.0, up / full))
    );
    intent.look_yaw = yaw * 0.017453292519943295;
    intent.look_pitch = pitch * 0.017453292519943295;
    # Q2 and Q3 jump with +moveup; +jump works in every game.
    intent.jump = b.went_down["jump"] or b.went_down["moveup"];
    intent.jump_held = b.active["jump"] or b.active["moveup"];
    intent.crouch = b.active["movedown"];
    intent.fire = b.active["attack"];
    intent.scores = b.active["showscores"] or b.active["scores"];
    if b.went_down["button2"] {
        intent.use_item = True;
    }
    return intent;
}
