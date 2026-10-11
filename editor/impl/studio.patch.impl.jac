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
        if kind == "uv" {
            # Where the patch's control points lie on its material, in texels.
            bent_patch = self.patch_now(scene);
            lay_of = scene.patch_grid(bent_patch) if bent_patch is not None else None;
            control_points = scene.patch_control(bent_patch) if bent_patch is not None else None;
            if bent_patch is None or lay_of is None or control_points is None {
                self.say("Select the patch to lay a material on");
                return True;
            }
            across = int(lay_of[0]);
            up = int(lay_of[1]);
            now_places = scene.patch_places(bent_patch);
            how = args[2] if len(args) > 2 else "";
            amounts: list[float] = [];
            for word in args[3:] {
                try {
                    amounts.append(float(word));
                } except ValueError {
                    break;
                }
            }
            # The material's own size in texels, to spread it by repeats.
            owned_now = scene.solids_of(bent_patch);
            image = self.materials.texture(owned_now[0].sides[0].material) if len(owned_now) > 0 else None;
            wide = float(image.width) if image is not None and image.width > 0 else 64.0;
            tall = float(image.height) if image is not None and image.height > 0 else 64.0;
            fresh_places: list[float] = [];
            label = "Lay material";
            if how == "fit" {
                fresh_places = places_even(
                    across, up, wide * (amounts[0] if len(amounts) > 0 else 1.0), tall * (amounts[1] if len(amounts) > 1 else (amounts[0] if len(amounts) > 0 else 1.0))
                );
            } elif how == "project" {
                tagged_face = self.tagged_side;
                if tagged_face is None {
                    self.say("Tag a face first (ed_tag): its material is laid on the patch as it lies on the face");
                    return True;
                }
                fresh_places = places_projected_from(control_points, tagged_face.mapping);
                label = "Project material";
            } elif how == "clear" {
                if len(now_places) == 0 or not scene.set_patch_places(bent_patch, [], "Forget places") {
                    self.say("That patch has not been told where its points lie on its material");
                } else {
                    print("studio: patch places " + str(across) + "x" + str(up) + " none");
                    print("studio: patch lies " + (places_text(scene.patch_lies(bent_patch)) or "nowhere"));
                    self.say("The patch takes its material plainly again");
                }
                return True;
            } elif how in ["row", "col"] and len(amounts) >= 3 and len(now_places) > 0 {
                fresh_places = places_slid(now_places, across, up, how, int(amounts[0]), amounts[1], amounts[2]);
            } elif how == "all" and len(amounts) >= 2 and len(now_places) > 0 {
                fresh_places = places_slid(now_places, across, up, "all", -1, amounts[0], amounts[1]);
            } elif how == "point" and len(amounts) >= 4 and len(now_places) > 0 {
                at = int(amounts[1]) * across + int(amounts[0]);
                if at < 0 or at * 2 + 1 >= len(now_places) {
                    self.say("ed_patch uv point <column> <row> <s> <t>: that patch has no such control point");
                    return True;
                }
                fresh_places = list(now_places);
                fresh_places[at * 2] = amounts[2];
                fresh_places[at * 2 + 1] = amounts[3];
            } elif not how {
                print(
                    "studio: patch places " + str(across) + "x" + str(up) + " "
                        + (places_text(now_places) if len(now_places) > 0 else "none")
                );
                print("studio: patch lies " + (places_text(scene.patch_lies(bent_patch)) or "nowhere"));
                return True;
            } else {
                self.say(
                    "ed_patch uv fit [repeats] [repeats up] | project | point <column> <row> <s> <t> | row|col <n> <ds> <dt> | all <ds> <dt> | clear  (fit or project first)"
                );
                return True;
            }
            if not scene.set_patch_places(bent_patch, fresh_places, label) {
                self.say("It lies so already");
            } else {
                print("studio: patch places " + str(across) + "x" + str(up) + " " + places_text(fresh_places));
                print("studio: patch lies " + (places_text(scene.patch_lies(bent_patch)) or "nowhere"));
                self.say("The patch takes its material where its control points say");
            }
            return True;
        }
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
