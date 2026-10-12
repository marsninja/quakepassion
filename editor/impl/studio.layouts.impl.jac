"""How the level views share the room, which side each side panel is on, and
layouts kept by name. Declarations live in studio.jac."""

impl Studio.apply_split {
    if len(self.ports) < 4 {
        return;
    }
    wide = max(10, min(90, self.split_x));
    tall = max(10, min(90, self.split_y));
    if self.layout == 2 {
        self.ports[0].view.grow = wide;
        self.ports[1].view.grow = 100 - wide;
    } elif self.layout == 3 or self.layout == 5 {
        self.ports[0].view.grow = wide;
        column = self.split_column;
        if column is not None {
            column.grow = 100 - wide;
        }
        for index in range(1, 4) {
            self.ports[index].view.grow = 1;
        }
    } elif self.layout == 4 {
        for index in [0, 2] {
            self.ports[index].view.grow = wide;
            self.ports[index + 1].view.grow = 100 - wide;
        }
        if len(self.split_rows) == 2 {
            self.split_rows[0].grow = tall;
            self.split_rows[1].grow = 100 - tall;
        }
    } else {
        self.ports[0].view.grow = 1;
    }
}

impl Studio.place_sides {
    ui = self.ui;
    stage = self.stage;
    if ui is None {
        return;
    }
    if stage is not None {
        stage.focus_on(None);
    }
    # The same three in another order, each side panel with a bar toward the middle.
    ui.body.clear();
    if self.sides_swapped {
        ui.body.adopt(ui.right);
        ui.body.adopt(Splitter(target=ui.right, low=220, high=640));
        ui.body.adopt(ui.center);
        ui.body.adopt(Splitter(target=ui.left, after=True, low=160, high=600));
        ui.body.adopt(ui.left);
    } else {
        ui.body.adopt(ui.left);
        ui.body.adopt(Splitter(target=ui.left, low=160, high=600));
        ui.body.adopt(ui.center);
        ui.body.adopt(Splitter(target=ui.right, after=True, low=220, high=640));
        ui.body.adopt(ui.right);
    }
}

impl Studio.layout_words -> str {
    return ("4b" if self.layout == 5 else str(self.layout)) + " " + str(self.split_x) + " " + str(self.split_y) + " "
        + ("right" if self.sides_swapped else "left") + " " + ("on" if self.log_panel else "off") + " " + str(self.log_rows);
}

impl Studio.layouts_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_split" {
        which = args[1] if len(args) > 1 else "";
        amount = args[2] if len(args) > 2 else "";
        was = self.split_x * 1000 + self.split_y;
        if which == "even" {
            self.split_x = 50;
            self.split_y = 50;
        } elif which in ["x", "y"] and amount.isdigit() {
            share = max(10, min(90, int(amount)));
            if which == "x" {
                self.split_x = share;
            } else {
                self.split_y = share;
            }
        } else {
            print("studio: split x=" + str(self.split_x) + " y=" + str(self.split_y));
            self.say("ed_split [x|y] <percent> | even: the left views have " + str(self.split_x) + " of the width, the upper " + str(self.split_y) + " of the height");
            return True;
        }
        if self.split_x * 1000 + self.split_y != was {
            self.apply_split();
            self.keep_settings();
        }
        return True;
    }
    if name == "ed_sides" {
        how = args[1] if len(args) > 1 else "swap";
        if how not in ["swap", "left", "right"] {
            self.say("ed_sides [swap|left|right]: the side the scene list is on");
            return True;
        }
        wanted = (not self.sides_swapped) if how == "swap" else how == "right";
        if wanted != self.sides_swapped {
            self.sides_swapped = wanted;
            self.place_sides();
            self.keep_settings();
            self.say("The scene list is on the " + ("right" if wanted else "left") + ", the inspector on the " + ("left" if wanted else "right"));
        }
        return True;
    }
    if name != "ed_layout" or len(args) < 2 or args[1] not in ["save", "load", "drop", "list", "keep"] {
        return False;
    }
    how = args[1];
    called = args[2] if len(args) > 2 else "";
    if how == "list" {
        for kept_name in sorted(self.kept_layouts.keys()) {
            print("studio: layout " + kept_name + " " + self.kept_layouts[kept_name]);
        }
        print("studio: layouts " + str(len(self.kept_layouts)));
        self.say(
            "Layouts kept: " + ", ".join(sorted(self.kept_layouts.keys())) if len(self.kept_layouts) > 0
            else "No layout is kept: ed_layout save <name> keeps this one"
        );
        return True;
    }
    if not called or " " in called {
        self.say("ed_layout " + how + " <name>");
        return True;
    }
    if how == "keep" {
        # As the settings have it: the name and the words that set it.
        if len(args) >= 9 {
            self.kept_layouts[called] = " ".join(args[3:9]);
        }
        return True;
    }
    if how == "save" {
        self.kept_layouts[called] = self.layout_words();
        self.keep_settings();
        print("studio: layout " + called + " " + self.kept_layouts[called]);
        self.say("This layout is kept as " + called);
        return True;
    }
    if called not in self.kept_layouts {
        self.say("No layout is kept as " + called);
        return True;
    }
    if how == "drop" {
        self.kept_layouts.pop(called);
        self.keep_settings();
        self.say(called + " is forgotten");
        return True;
    }
    words = self.kept_layouts[called].split();
    if len(words) < 6 {
        self.say(called + " was not kept whole");
        return True;
    }
    self.logic_shown = False;
    self.assets_shown = False;
    if words[1].isdigit() and words[2].isdigit() {
        self.split_x = max(10, min(90, int(words[1])));
        self.split_y = max(10, min(90, int(words[2])));
    }
    self.arrange_views(5 if words[0] == "4b" else (int(words[0]) if words[0] in ["2", "3", "4"] else 1));
    if (words[3] == "right") != self.sides_swapped {
        self.sides_swapped = words[3] == "right";
        self.place_sides();
    }
    self.log_panel = words[4] == "on";
    if words[5].isdigit() {
        self.log_rows = max(2, min(24, int(words[5])));
    }
    self.log_back = 0;
    self.keep_settings();
    print("studio: layout loaded " + called + " " + self.layout_words());
    self.say("The layout " + called);
    return True;
}
