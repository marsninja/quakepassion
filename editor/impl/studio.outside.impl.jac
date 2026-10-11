"""Programs outside the studio (one kept for each kind of file, files opened
with it, image files read again when one changes them) and how the mouse
steers the views. Declarations live in studio.jac."""

impl Studio.file_of(scene: Scene, what: str) -> str {
    stock = self.archive;
    if what.startswith("file:") and stock is not None and ".." not in what {
        return stock.files_folder() + "/" + what[5:];
    }
    if what and os.path.isfile(what) {
        return what;
    }
    return "";
}

impl Studio.reread(name: str) -> bool {
    stock = self.archive;
    if stock is None {
        return False;
    }
    # Fetched afresh; its small picture drawn again; the level built with it.
    stock.found.pop(name, None);
    fresh = stock.texture(name);
    if name not in self.thumbs {
        self.thumbs.append(name);
    }
    self.materials_changed += 1;
    self.built_copies = [];
    self.built_geometry = -1;
    print("studio: reloaded " + name + " " + str(fresh.width) + "x" + str(fresh.height));
    return True;
}

impl Studio.watch_files(dt: float) {
    stock = self.archive;
    if stock is None or not self.watching {
        return;
    }
    # By the clock on the wall: frames come as fast as the display lets them.
    now = time.time();
    due = now - self.watch_clock >= 0.5;
    if due {
        self.watch_clock = now;
    }
    if not due and len(stock.found) == self.watch_count {
        return;
    }
    self.watch_count = len(stock.found);
    changed: list[str] = [];
    for name in stock.found.keys() {
        if not name.startswith("file:") {
            continue;
        }
        path = stock.files_folder() + "/" + name[5:];
        if not os.path.isfile(path) {
            continue;
        }
        if name not in self.watched {
            # As it was when it was first read.
            self.watched[name] = os.path.getmtime(path);
        } elif due and os.path.getmtime(path) != self.watched[name] {
            self.watched[name] = os.path.getmtime(path);
            changed.append(name);
        }
    }
    for name in changed {
        self.reread(name);
        self.say(name + " changed on disk and was read again");
    }
}

impl Studio.mouse_words -> str {
    return "studio: mouse look=" + str(round(self.look_rate, 2)) + " invert=" + ("1" if self.look_flipped else "0")
        + " wheel=" + str(round(self.wheel_rate, 2)) + " reverse=" + ("1" if self.wheel_flipped else "0") + " yaw="
        + str(int(round(math.degrees(self.main.yaw)))) + " pitch=" + str(int(round(math.degrees(self.main.pitch))));
}

impl Studio.outside_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_mouse" {
        what = args[1] if len(args) > 1 else "";
        value = args[2] if len(args) > 2 else "";
        rate = 0.0;
        try {
            rate = float(value);
        } except ValueError {
            rate = 0.0;
        }
        if what == "look" and rate >= 0.1 and rate <= 10.0 {
            self.look_rate = rate;
        } elif what == "wheel" and rate >= 0.1 and rate <= 10.0 {
            self.wheel_rate = rate;
        } elif what == "invert" and value in ["on", "off"] {
            self.look_flipped = value == "on";
        } elif what == "reverse" and value in ["on", "off"] {
            self.wheel_flipped = value == "on";
        } elif what {
            self.say("ed_mouse [look <0.1 to 10>] [invert on|off] [wheel <0.1 to 10>] [reverse on|off]");
            return True;
        }
        if what {
            self.keep_settings();
        }
        print(self.mouse_words());
        self.say(
            "The mouse turns the camera at " + str(round(self.look_rate, 2)) + (" (up is down)" if self.look_flipped else "")
                + "; the wheel moves it at " + str(round(self.wheel_rate, 2)) + (" (the other way)" if self.wheel_flipped else "")
        );
        return True;
    }
    if name == "ed_assoc" {
        if len(args) < 2 {
            for ending in sorted(self.assoc.keys()) {
                print("studio: assoc " + ending + " = " + self.assoc[ending]);
            }
            self.say(
                "Programs kept for: " + ", ".join(sorted(self.assoc.keys()))
                if self.assoc
                else "No program is kept for any file (ed_assoc <ending> \"<command line> %file%\")"
            );
            return True;
        }
        ending = args[1].lower().lstrip(".");
        line = " ".join(args[2:]).strip();
        if not ending {
            self.say("ed_assoc <ending> \"<command line> %file%\": png, map, or * for any other");
            return True;
        }
        if line {
            self.assoc[ending] = line;
            self.say("Files ending ." + ending + " open with " + line);
        } elif ending in self.assoc {
            self.assoc.pop(ending, None);
            self.say("No program is kept for ." + ending + " files now");
        } else {
            self.say("ed_assoc " + ending + " \"<command line> %file%\"");
            return True;
        }
        self.keep_settings();
        return True;
    }
    if name == "ed_reload" {
        stock = self.archive;
        count = 0;
        if stock is not None {
            for known in list(stock.found.keys()) {
                if known.startswith("file:") and self.reread(known) {
                    count += 1;
                }
            }
        }
        self.built_copies = [];
        self.built_geometry = -1;
        print("studio: reloaded all " + str(count));
        self.say("Read " + str(count) + " image files again and built the level afresh");
        return True;
    }
    if name == "ed_watch" {
        self.watching = not self.watching;
        if len(args) > 1 and args[1] in ["on", "off"] {
            self.watching = args[1] == "on";
        }
        self.say(
            "Image files are read again when they change" if self.watching else "Image files are read once (ed_reload reads them again)"
        );
        return True;
    }
    if name != "ed_openwith" {
        return False;
    }
    what = args[1] if len(args) > 1 else (self.material if self.material.startswith("file:") else scene.path);
    path = self.file_of(scene, what);
    if not path {
        self.say("ed_openwith [file]: a path, or a material that is an image file of the project's (file:...)");
        return True;
    }
    dot = path.rfind(".");
    ending = path[dot + 1:].lower() if dot >= 0 else "";
    line = self.assoc.get(ending, self.assoc.get("*", ""));
    if not line {
        self.say("No program is kept for ." + ending + " files (ed_assoc " + ending + " \"<command line> %file%\")");
        return True;
    }
    quoted = "\"" + path + "\"" if " " in path else path;
    order = line.replace("%file%", quoted) if "%file%" in line else line + " " + quoted;
    # Left running beside the studio.
    os.system("( " + order + " ) > /dev/null 2>&1 &");
    print("studio: opened " + path + " with " + line);
    self.say("Opened " + os.path.basename(path) + " with " + line);
    return True;
}
