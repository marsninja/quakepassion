"""The studio's loop selection and its moves that end on something there.
Declarations live in studio.jac."""

impl Studio.select_in_loop(scene: Scene, port: int, loop: list[int], add: bool) {
    if port < 0 or port >= len(self.ports) or len(loop) < 6 {
        return;
    }
    camera = self.ports[port].camera;
    view = self.ports[port].view.area;
    if not add {
        scene.clear_selection();
    }
    count = 0;
    for shape in self.shapes {
        if item_veil(shape.item) != "" or item_switched(shape.item, LOCK_KEY) {
            continue;
        }
        at = camera.project(view, shape.center());
        if at is not None and loop_inside(loop, at[0], at[1]) and not scene.is_selected(shape.item) {
            scene.select(shape.item, True);
            count += 1;
        }
    }
    for seen in self.looks {
        holder = scene.owner_of(seen.solid);
        # A brush entity's brushes come with the entity.
        if holder is None or holder.classname() != "worldspawn" or seen.dim or seen.locked {
            continue;
        }
        at = camera.project(view, seen.center());
        if at is not None and loop_inside(loop, at[0], at[1]) and not scene.is_solid_selected(seen.solid) {
            scene.select_solid(seen.solid, True);
            count += 1;
        }
    }
    scene.picks += 1;
    print("studio: lasso points=" + str(len(loop) // 2) + " selected=" + str(count));
    self.say("Selected " + str(count));
}

impl Studio.snap_delta(scene: Scene, delta: Vec3) -> Vec3 {
    if self.snap_to == "grid" {
        return delta;
    }
    # What is moving: the corners of the selected brushes and of the selected entities' brushes.
    carried = scene.selected_solids();
    for item in scene.selection() {
        for owned in scene.solids_of(item) {
            if owned not in carried {
                carried.append(owned);
            }
        }
    }
    travelling: list[Vec3] = [];
    for brush in carried {
        for outline in brush.outlines() {
            for corner in outline {
                travelling.append(corner);
            }
        }
    }
    # What stands still: every other brush that is shown.
    corners: list[Vec3] = [];
    stretches: list[list[Vec3]] = [];
    faces: list[list[Vec3]] = [];
    for brush in scene.solids() {
        if brush in carried or brush.hidden {
            continue;
        }
        for outline in brush.outlines() {
            if len(outline) < 3 {
                continue;
            }
            faces.append(outline);
            for (place, corner) in enumerate(outline) {
                corners.append(corner);
                stretches.append([corner, outline[(place + 1) % len(outline)]]);
            }
        }
    }
    landed = snapped_move(travelling, delta, corners, stretches, faces, self.snap_to, self.snap_reach);
    if landed.sub(delta).length() > 0.0001 {
        gone = landed.sub(delta);
        print(
            "studio: snapped " + self.snap_to + " by=" + str(round(gone.x, 2) + 0.0) + "," + str(round(gone.y, 2) + 0.0) + ","
                + str(round(gone.z, 2) + 0.0)
        );
    }
    return landed;
}

impl Studio.snapto_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_lasso" {
        loop: list[int] = [];
        for word in args[2:] {
            if word.lstrip("-").isdigit() {
                loop.append(int(word));
            }
        }
        if len(args) < 3 or not args[1].isdigit() or len(loop) < 6 or len(loop) % 2 != 0 {
            self.say("ed_lasso <view> <x> <y> <x> <y> <x> <y> ... [add]: a loop of three points or more");
            return True;
        }
        self.select_in_loop(scene, int(args[1]), loop, args[-1] == "add");
        return True;
    }
    if name != "ed_snapto" {
        return False;
    }
    how = args[1] if len(args) > 1 else "";
    if how not in ["grid", "corners", "edges", "faces"] {
        self.say("ed_snapto <grid|corners|edges|faces> [reach]: now " + self.snap_to + ", within " + str(int(round(self.snap_reach))));
        return True;
    }
    self.snap_to = how;
    if len(args) > 2 {
        try {
            self.snap_reach = max(1.0, min(256.0, float(args[2])));
        } except ValueError {
            self.say("ed_snapto " + how + " <reach>: how near, in units");
            return True;
        }
    }
    self.say(
        "A move ends where it is asked"
        if how == "grid"
        else "A move ends on " + ("a corner" if how == "corners" else ("a corner or an edge" if how == "edges" else "a corner, an edge or a face"))
            + " of another brush it comes within " + str(int(round(self.snap_reach))) + " of"
    );
    return True;
}
