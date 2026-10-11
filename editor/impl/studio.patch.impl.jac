"""The studio's curved patches. Declarations live in studio.jac."""

impl Studio.patch_now(scene: Scene) -> Item | None {
    chosen = scene.selection();
    if len(chosen) != 1 or scene.selected_solids() {
        return None;
    }
    return chosen[0] if scene.patch_grid(chosen[0]) is not None else None;
}

impl Studio.patch_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    app = self.app;
    if app is None {
        return False;
    }
    if name == "ed_patch" {
        kind = args[1] if len(args) > 1 else "";
        if kind in ["grow", "shrink", "thick", "fine"] {
            curved = self.patch_now(scene);
            if curved is None {
                self.say("Select the patch to change");
                return True;
            }
            if kind == "grow" or kind == "shrink" {
                way = args[2] if len(args) > 2 else "";
                if way not in ["u", "v"] {
                    self.say("ed_patch " + kind + " <u|v>: across the patch or up it");
                } elif not scene.grow_patch(curved, way, kind == "grow") {
                    self.say("That patch cannot " + kind + " that way");
                }
                return True;
            }
            number = 0.0;
            try {
                number = float(args[2]) if len(args) > 2 else 0.0;
            } except ValueError {
                number = 0.0;
            }
            control = scene.patch_control(curved);
            lay = scene.patch_grid(curved);
            if number <= 0.0 or control is None or lay is None {
                self.say("ed_patch thick <units> | fine <prisms a curve>");
                return True;
            }
            if not scene.remake_patch(
                curved,
                control,
                int(lay[0]),
                int(lay[1]),
                int(number) if kind == "fine" else 0,
                number if kind == "thick" else 0.0,
                "Patch " + ("thickness" if kind == "thick" else "fineness")
            ) {
                self.say("That patch has no surface that way");
            }
            return True;
        }
        if kind not in PATCH_KINDS {
            self.say("ed_patch <" + "|".join(PATCH_KINDS) + "> [w d h] | grow <u|v> | shrink <u|v> | thick <units> | fine <n>");
            return True;
        }
        if not self.is_built_scene() {
            self.say("A shipped map cannot take new brushes: start a scene (ed_scene)");
            return True;
        }
        sizes: list[float] = [];
        for word in args[2:] {
            try {
                sizes.append(max(8.0, float(word)));
            } except ValueError {
                continue;
            }
        }
        size = Vec3(x=128.0, y=64.0 if kind == "arch" else 128.0, z=96.0);
        if len(sizes) >= 3 {
            size = Vec3(x=sizes[0], y=sizes[1], z=sizes[2]);
        }
        # Where the camera looks, its middle over the point and its foot on it.
        eye = self.main.eye;
        ahead = self.main.forward();
        trace = app.level.collision.trace_point(eye, eye.add(ahead.scale(1024.0)));
        spot = eye.add(ahead.scale(256.0));
        if trace.fraction < 1.0 and not trace.start_solid {
            spot = eye.add(ahead.scale(1024.0 * trace.fraction));
        }
        snap = 16.0;
        low = Vec3(
            x=float(round((spot.x - size.x * 0.5) / snap)) * snap,
            y=float(round((spot.y - size.y * 0.5) / snap)) * snap,
            z=float(round(spot.z / snap)) * snap
        );
        made = patch_points(kind, low, low.add(size));
        added = scene.make_patch(made[2], made[0], made[1], self.material);
        if added is None {
            self.say("That patch has no surface");
        } else {
            self.say("Added a curved " + kind + " of " + str(len(scene.solids_of(added))) + " prisms");
        }
        return True;
    }
    if name == "ed_patch_point" {
        numbers: list[float] = [];
        for word in args[1:] {
            try {
                numbers.append(float(word));
            } except ValueError {
                continue;
            }
        }
        if len(numbers) < 5 {
            self.say("ed_patch_point <patch> <point> <dx> <dy> <dz>");
            return True;
        }
        bent = scene.find(int(numbers[0]));
        if bent is None or scene.patch_grid(bent) is None {
            self.say("ed_patch_point: no patch " + str(int(numbers[0])));
            return True;
        }
        if not scene.move_patch_point(bent, int(numbers[1]), Vec3(x=numbers[2], y=numbers[3], z=numbers[4])) {
            self.say("That point cannot go there");
        }
        return True;
    }
    return False;
}
