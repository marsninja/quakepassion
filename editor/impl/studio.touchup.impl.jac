"""Fine work on a terrain: a corner shifted with the corners that go with it,
a plot of adjoining cells picked, outlined and worked on, and a terrain's
top or bottom shifted on its own. Declarations live in studio.jac."""

"""The numbers at the front of a command's words, as far as they are numbers."""
def:priv plot_numbers(words: list[str]) -> list[float] {
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

impl Studio.draw_plot(scene: Scene) {
    land = self.plot_land;
    if land is None or len(self.plot) == 0 or not land.held {
        return;
    }
    lay = scene.terrain_grid(land);
    if lay is None {
        return;
    }
    cols = int(lay[0]);
    rows = int(lay[1]);
    heights = heights_from(land.fields.get("_heights", ""), cols, rows);
    if heights is None {
        return;
    }
    # The colour guide: the edge of what the next thing will be done to.
    for line in cells_outline(heights, cols, rows, self.plot, scene.terrain_origin(land), lay[2], lay[3]) {
        wire_line(line[0], line[1], ink(0xffd166));
    }
}

impl Studio.touchup_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    if name != "ed_touch" and name != "ed_plot" and not (name == "ed_terrain" and how in ["top", "bottom", "both"]) {
        return False;
    }
    ground = self.terrain_now(scene);
    lay = scene.terrain_grid(ground) if ground is not None else None;
    if ground is None or lay is None {
        self.say("Select the terrain to work on (there is none, or more than one)");
        return True;
    }
    cols = int(lay[0]);
    rows = int(lay[1]);
    if name == "ed_terrain" {
        amounts = plot_numbers(args[2:]);
        if len(amounts) < 1 or amounts[0] == 0.0 {
            self.say("ed_terrain top|bottom|both <amount>: move its top, the underside of its base, or the whole of it");
            return True;
        }
        if how == "both" {
            scene.select(ground);
            scene.shift_selection(Vec3(z=amounts[0]), self.tex_lock);
        } elif not scene.move_terrain(ground, how, amounts[0]) {
            self.say("That would leave the terrain's base with nothing in it");
        }
        return True;
    }
    if name == "ed_touch" {
        spots = plot_numbers(args[1:]);
        if len(spots) < 3 {
            self.say("ed_touch <x> <y> <amount> [variance]: move the corner nearest a place, and the corners that go with it");
            return True;
        }
        shifted = scene.touch_terrain(ground, spots[0], spots[1], spots[2], spots[3] if len(spots) > 3 else self.plot_variance);
        print("studio: touched " + str(shifted));
        self.say("Moved " + str(shifted) + " corners that stand together" if shifted else "Nothing shifted");
        return True;
    }
    # ed_plot: a group of adjoining cells.
    heights = heights_from(ground.fields.get("_heights", ""), cols, rows);
    if heights is None {
        return True;
    }
    if how == "clear" {
        self.plot = [];
        self.plot_land = None;
    } elif how == "variance" and len(plot_numbers(args[2:])) > 0 {
        self.plot_variance = max(0.0, plot_numbers(args[2:])[0]);
        self.say("Cells and corners go together within " + str(int(self.plot_variance)) + " units of height");
        return True;
    } elif how == "lift" and len(plot_numbers(args[2:])) > 0 {
        if len(self.plot) == 0 or not scene.lift_cells(ground, self.plot, plot_numbers(args[2:])[0]) {
            self.say("Pick a plot first (ed_plot <x> <y>, or Alt and a click in sculpt mode)");
            return True;
        }
    } elif how == "paint" {
        # The material in hand on the top of every cell of the plot.
        origin = scene.terrain_origin(ground);
        painted = 0;
        for at in self.plot {
            painted += scene.paint_terrain(
                ground,
                origin.x + (float(at % cols) + 0.5) * lay[2],
                origin.y + (float(at // cols) + 0.5) * lay[2],
                lay[2] * 0.45,
                self.material
            );
        }
        print("studio: plot painted " + str(painted));
        self.say("Painted " + str(painted) + " tops with " + self.material if painted else "Pick a plot first, or it is that material already");
        return True;
    } else {
        spots = plot_numbers(args[1:]);
        if len(spots) < 2 {
            self.say("ed_plot <x> <y> [variance] [add] | clear | variance <units> | lift <amount> | paint");
            return True;
        }
        place = cell_at(scene.terrain_origin(ground), cols, rows, lay[2], spots[0], spots[1]);
        group = kin_cells(heights, cols, rows, place[0], place[1], spots[2] if len(spots) > 2 else self.plot_variance);
        if len(args) > 1 and args[-1] == "add" and self.plot_land is ground {
            for at in group {
                if at not in self.plot {
                    self.plot.append(at);
                }
            }
        } else {
            self.plot = group;
        }
        self.plot_land = ground;
    }
    print("studio: plot cells=" + str(len(self.plot)));
    self.say(str(len(self.plot)) + " cells in the plot" if self.plot else "No plot is picked");
    return True;
}
