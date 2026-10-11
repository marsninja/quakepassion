"""The studio's floating 3D windows: further views of the level, each in a
window of its own over the others, with a camera and a way of drawing of
its own. Declarations live in studio.jac."""

def:priv window_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            return found;
        }
    }
    return found;
}

impl Studio.float_ports -> list[Port] {
    return [port for port in self.ports[4:] if port.window is not None];
}

impl Studio.over_layers(stage: Stage) -> int {
    # A floating window is a layer too, but not one that is open over the views.
    return len([layer for layer in stage.layers() if not isinstance(layer, Floater)]) - 1;
}

impl Studio.open_float(wire: bool) -> Port | None {
    stage = self.stage;
    if stage is None or len(self.ports) < 4 {
        return None;
    }
    self.floats_made += 1;
    number = self.floats_made + 1;
    # It looks where the first 3D view looks, until it is taken elsewhere.
    seeing = EditCamera(eye=self.main.eye, yaw=self.main.yaw, pitch=self.main.pitch, fov=self.main.fov);
    pane = ViewArea(hint="Right drag + WASD/QE: fly | wheel: dolly | middle drag: pan | click: select", plain=True);
    casing = Floater(title="3D " + str(number), command="ed_window close " + str(number));
    casing.adopt(pane);
    base = self.ports[0].view.area;
    step = 26 * len(self.float_ports());
    casing.area = Rect(x=base.x + 24 + step, y=base.y + 24 + step, w=340, h=240);
    ui = self.ui;
    if ui is not None {
        casing.bounds = ui.center.area;
        casing.settle(stage);
    }
    stage.open(casing);
    made = Port(view=pane, camera=seeing, title="3D " + str(number), wire=wire, number=number, window=casing);
    self.ports.append(made);
    return made;
}

impl Studio.close_float(number: int) -> bool {
    stage = self.stage;
    for port in self.float_ports() {
        if port.number != number {
            continue;
        }
        casing = port.window;
        if stage is not None and casing is not None {
            stage.close(casing);
        }
        self.ports = [other for other in self.ports if other is not port];
        if self.port_now >= len(self.ports) or self.camera is port.camera {
            self.watch(0);
        }
        return True;
    }
    return False;
}

impl Studio.float_views(built: bool) -> list[SceneView] {
    seen: list[SceneView] = [];
    ui = self.ui;
    stage = self.stage;
    floating = self.float_ports();
    for (place, port) in enumerate(floating) {
        area = port.view.area;
        casing = port.window;
        if casing is not None {
            # The windows opened after it float above it.
            casing.covered = [above.window.area for above in floating[place + 1:] if above.window is not None];
        }
        if casing is not None and ui is not None and stage is not None and not casing.bounds.same(ui.center.area) {
            # They float over the views, not over the panels beside them.
            casing.bounds = ui.center.area;
            casing.settle(stage);
        }
        if casing is not None {
            casing.note = str(int(port.camera.eye.x)) + " " + str(int(port.camera.eye.y)) + " " + str(int(port.camera.eye.z))
                + ("   outlines" if port.wire else "");
        }
        if area.w <= 0 or area.h <= 0 {
            continue;
        }
        seen.append(
            SceneView(
                x=area.x,
                y=area.y,
                width=area.w,
                height=area.h,
                eye=port.camera.eye,
                yaw=port.camera.yaw,
                pitch=port.camera.pitch,
                span=port.camera.span,
                everything=True,
                wire=port.wire and not built,
                bare=port.wire and built,
                over=True
            )
        );
    }
    return seen;
}

impl Studio.window_lines -> list[str] {
    lines: list[str] = [];
    for port in self.float_ports() {
        casing = port.window;
        if casing is None {
            continue;
        }
        lines.append(
            "studio: window " + str(port.number) + " at=" + str(casing.area.x) + "," + str(casing.area.y) + " size="
                + str(casing.area.w) + "x" + str(casing.area.h) + " eye=" + str(int(round(port.camera.eye.x))) + ","
                + str(int(round(port.camera.eye.y))) + "," + str(int(round(port.camera.eye.z))) + " yaw="
                + str(int(round(math.degrees(port.camera.yaw)))) + " pitch=" + str(int(round(math.degrees(port.camera.pitch))))
                + " outlines=" + ("1" if port.wire else "0")
        );
    }
    return lines;
}

impl Studio.window_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_window" {
        return False;
    }
    how = args[1] if len(args) > 1 else "";
    stage = self.stage;
    if not how or how == "list" {
        for line in self.window_lines() {
            print(line);
        }
        print("studio: windows " + str(len(self.float_ports())));
        self.say(
            str(len(self.float_ports())) + " floating 3D windows" if len(self.float_ports()) > 0
            else "No floating 3D windows (ed_window new)"
        );
        return True;
    }
    if how == "new" {
        if len(self.float_ports()) >= 4 {
            self.say("Four floating windows are open already");
            return True;
        }
        made = self.open_float(len(args) > 2 and args[2] in ["wire", "outlines"]);
        if made is None {
            self.say("A floating window needs the studio's views");
        } else {
            self.say(made.title + ": a view of its own. Drag its bar to move it, its corner to size it");
        }
        return True;
    }
    if how == "close" {
        which = args[2] if len(args) > 2 else "";
        if which == "all" {
            for port in self.float_ports() {
                self.close_float(port.number);
            }
            return True;
        }
        if not which.isdigit() or not self.close_float(int(which)) {
            self.say("ed_window close <number|all>: no such window");
        }
        return True;
    }
    chosen: Port | None = None;
    for port in self.float_ports() {
        if how.isdigit() and port.number == int(how) {
            chosen = port;
        }
    }
    what = args[2] if len(args) > 2 else "";
    numbers = window_numbers(args[3:]);
    if chosen is None or chosen.window is None {
        self.say("ed_window [list] | new [outlines] | close <n|all> | <n> outlines|solid | <n> at <x> <y> [w h] | <n> cam <x y z> [yaw pitch] | <n> here");
        return True;
    }
    casing = chosen.window;
    if what in ["outlines", "wire", "solid"] {
        chosen.wire = what != "solid";
    } elif what == "at" and len(numbers) >= 2 and casing is not None and stage is not None {
        casing.area = Rect(
            x=int(numbers[0]),
            y=int(numbers[1]),
            w=int(numbers[2]) if len(numbers) >= 4 else casing.area.w,
            h=int(numbers[3]) if len(numbers) >= 4 else casing.area.h
        );
        casing.settle(stage);
    } elif what == "cam" and len(numbers) >= 3 {
        chosen.camera.eye = Vec3(x=numbers[0], y=numbers[1], z=numbers[2]);
        if len(numbers) >= 5 {
            chosen.camera.yaw = math.radians(numbers[3]);
            chosen.camera.pitch = math.radians(numbers[4]);
        }
    } elif what == "here" {
        chosen.camera.eye = self.main.eye;
        chosen.camera.yaw = self.main.yaw;
        chosen.camera.pitch = self.main.pitch;
    } else {
        self.say("ed_window <n> outlines|solid | at <x> <y> [w h] | cam <x y z> [yaw pitch] | here");
    }
    return True;
}
