"""How the model being edited is shown and handled in its view: its faces
drawn solid or with its skin, how the view turns, the three handles of what
is picked and the axes it may not move along, how its marks are drawn, and
its points' own colours. Declarations live in studio.jac."""

impl Studio.turn_model_float {
    pane = self.model_float_pane;
    if pane is None {
        return;
    }
    for event in pane.take() {
        if event.kind == "drag" {
            self.model_float_yaw -= float(event.dx) * 0.01;
            self.model_float_pitch = max(-1.5, min(1.5, self.model_float_pitch - float(event.dy) * 0.01));
        } elif event.kind == "wheel" {
            self.model_float_reach = max(8.0, self.model_float_reach * (0.85 ** event.wheel));
        }
    }
    lens = self.model_float_lens;
    lens.span = 0.0;
    lens.yaw = self.model_float_yaw;
    lens.pitch = self.model_float_pitch;
    lens.eye = self.model_middle.sub(lens.forward().scale(self.model_float_reach));
}

impl Studio.modelview_words -> str {
    doc = self.model_doc;
    part = doc.part() if doc is not None else None;
    coloured = len([tint for tint in part.tints if tint >= 0]) if part is not None else 0;
    return "studio: modelmarks marks=" + self.model_marks + " shade=" + self.model_shade + " about=" + self.model_about
        + " lock=" + (self.model_lock if self.model_lock else "-") + " coloured=" + str(coloured) + " colours="
        + ("1" if self.points_tinted else "0") + " pattern=" + self.skin_pattern + ":" + str(self.skin_grain) + " layout="
        + ("4" if _model_split.four else "1") + " float=" + (
            str(self.model_float_pane.area.w) + "x" + str(self.model_float_pane.area.h)
            if self.model_float_pane is not None
            else "0"
        ) + " views=" + str(len(self.views()));
}

impl Studio.draw_mark(at: Vec3, reach: float, color: Ink) {
    for pair in mark_lines(at, reach, self.model_marks) {
        wire_line(pair[0], pair[1], color);
    }
}

impl Studio.draw_model_faces {
    doc = self.model_doc;
    if doc is None or self.model_shade == "wire" {
        return;
    }
    # The picture being painted, when the model is drawn with it.
    picture = self.canvas.pictures.get("modelskin", 0) if self.model_shade == "textured" and self.model_skin is not None else 0;
    for part in doc.parts() {
        mesh = doc.mesh(part);
        skinned = picture != 0 and len(mesh.uvs) == len(mesh.points) * 2;
        tinted = self.points_tinted and len(part.tints) == len(mesh.points);
        rlSetTexture(u32(picture if skinned else 0));
        rlBegin(i32(4));
        for index in range(mesh.triangles()) {
            lit = face_light(mesh.normal(index));
            if skinned {
                # A skin is seen for what is painted on it: lit, but less starkly.
                lit = 0.55 + 0.45 * lit;
            }
            for corner in range(3) {
                at = mesh.corners[index * 3 + corner];
                # A point with a colour of its own is drawn in it; the rest
                # in the skin's colours, or in grey.
                tone = part.tints[at] if tinted and part.tints[at] >= 0 else (0xffffff if skinned else 0xb8b0a4);
                rlColor4ub(
                    u8(int(float((tone >> 16) & 255) * lit)), u8(int(float((tone >> 8) & 255) * lit)), u8(int(float(tone & 255) * lit)), u8(255)
                );
                if skinned {
                    rlTexCoord2f(f32(mesh.uvs[at * 2]), f32(mesh.uvs[at * 2 + 1]));
                }
                spot = mesh.points[at];
                rlVertex3f(f32(spot.x), f32(spot.y), f32(spot.z));
            }
        }
        rlEnd();
    }
    rlSetTexture(u32(0));
}

impl Studio.handle_reach -> float {
    return max(4.0, self.model_reach * 0.16);
}

impl Studio.handle_under(x: int, y: int) -> int {
    doc = self.model_doc;
    ui = self.ui;
    part = doc.part() if doc is not None else None;
    if doc is None or ui is None or part is None or len(part.picked_points) == 0 {
        return -1;
    }
    area = ui_model_area(ui);
    found = -1;
    nearest = 12 * 12;
    for (axis, tip) in enumerate(handle_tips(picks_middle(doc.mesh(part).points, part.picked_points), self.handle_reach())) {
        if "xyz"[axis] in self.model_lock {
            continue;
        }
        at = self.model_camera.project(area, tip);
        if at is None {
            continue;
        }
        away = (at[0] - x) * (at[0] - x) + (at[1] - y) * (at[1] - y);
        if away < nearest {
            nearest = away;
            found = axis;
        }
    }
    return found;
}

impl Studio.draw_model_handles {
    doc = self.model_doc;
    part = doc.part() if doc is not None else None;
    if doc is None or part is None or len(part.picked_points) == 0 {
        return;
    }
    # From the middle of what is picked, going with it while it is dragged.
    middle = picks_middle(doc.mesh(part).points, part.picked_points).add(self.model_drag);
    reach = self.handle_reach();
    for (axis, tip) in enumerate(handle_tips(middle, reach)) {
        locked = "xyz"[axis] in self.model_lock;
        tone = ink([0xe5484d, 0x3ddc97, 0x4f8ef7][axis], 70 if locked else 255);
        if axis == self.model_handle {
            tone = ink(0xff7a18);
        }
        wire_line(middle, tip, tone);
        if not locked {
            for pair in mark_lines(tip, reach * 0.07, "box") {
                wire_line(pair[0], pair[1], tone);
            }
        }
    }
}

impl Studio.handle_event(event: UiEvent) -> bool {
    doc = self.model_doc;
    ui = self.ui;
    part = doc.part() if doc is not None else None;
    if doc is None or ui is None or part is None {
        return False;
    }
    if event.kind == "press" and event.button == 0 and not event.ctrl and not event.alt {
        self.model_handle = self.handle_under(event.x, event.y);
        if self.model_handle >= 0 {
            self.model_travel = 0;
            self.model_drag = Vec3();
            return True;
        }
        return False;
    }
    if self.model_handle < 0 {
        return False;
    }
    if event.kind == "drag" {
        through = self.model_camera;
        unit = 2.0 * self.model_reach * through.slope() / float(max(1, ui_model_area(ui).h));
        went = through.right().scale(float(event.dx) * unit).sub(through.up().scale(float(event.dy) * unit));
        # Only what of the drag runs along the handle.
        self.model_drag = self.model_drag.add(drag_along(went, self.model_handle));
        return True;
    }
    if event.kind == "release" and event.button == 0 {
        if self.model_drag.length() > 0.01 {
            doc.reshape(Reshape(kind="move", picks=list(part.picked_points), vector=self.model_drag, only=doc.frame), "Pull a handle");
            print(
                "studio: handle pulled axis=" + "xyz"[self.model_handle] + " by=" + str(round(self.model_drag.x, 1)) + ","
                    + str(round(self.model_drag.y, 1)) + "," + str(round(self.model_drag.z, 1))
            );
            # The click that follows was for the handle: it picks nothing.
            self.model_travel = 99;
        }
        # Pressed and let go where it was: a click, which picks what is under the handle.
        self.model_drag = Vec3();
        self.model_handle = -1;
        return True;
    }
    return False;
}

impl Studio.frame_model_about {
    doc = self.model_doc;
    figure = self.model_now;
    if self.model_about == "origin" {
        # Where the model was begun: its own origin.
        self.model_middle = Vec3();
    } elif self.model_about == "model" {
        box = doc.bounds(doc.frame) if doc is not None else (figure.bounds(self.model_frame) if figure is not None else [Vec3(), Vec3()]);
        self.model_middle = box[0].add(box[1]).scale(0.5);
    }
}

impl Studio.modelview_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    word = args[2].lower() if len(args) > 2 else "";
    doc = self.model_doc;
    if name == "ed_model" and how == "marks" {
        if word not in MARK_STYLES {
            self.say("ed_model marks <" + "|".join(MARK_STYLES) + ">: how the marks on points and tags are drawn (now " + self.model_marks + ")");
            return True;
        }
        self.model_marks = word;
        self.keep_settings();
        print(self.modelview_words());
        self.say("Marks are drawn as a " + word);
        return True;
    }
    if name == "ed_model" and how == "shade" {
        if word not in ["wire", "solid", "textured"] {
            self.say("ed_model shade <wire|solid|textured>: the model being edited as its edges, with its faces filled, or with its skin (now " + self.model_shade + ")");
            return True;
        }
        self.model_shade = word;
        self.keep_settings();
        print(self.modelview_words());
        self.say(
            "The model is drawn " + ("as its edges" if word == "wire" else ("with its faces filled" if word == "solid" else "with its skin"))
                + (": make or open a skin to see it (ed_skin new, ed_skin open)" if word == "textured" and self.model_skin is None else "")
        );
        return True;
    }
    if name == "ed_model" and how == "layout" {
        if word not in ["1", "4"] {
            self.say("ed_model layout <1|4>: the model in one view, or in four: turning, from above, the front and the side");
            return True;
        }
        _model_split.four = word == "4";
        self.keep_settings();
        print(self.modelview_words());
        self.say("The model is shown in " + ("four views" if _model_split.four else "one view"));
        return True;
    }
    if name == "ed_model" and how == "float" {
        stage = self.stage;
        casing = self.model_float_box;
        if word == "close" or (casing is not None and word != "open") {
            if casing is not None and stage is not None {
                stage.close(casing);
            }
            self.model_float_box = None;
            self.model_float_pane = None;
            print(self.modelview_words());
            return True;
        }
        if casing is None and stage is not None {
            pane = ViewArea(hint="Drag: turn | wheel: nearer or farther", plain=True);
            casing = Floater(title="Model", command="ed_model float close", least_wide=160, least_tall=120);
            casing.adopt(pane);
            # It floats over the model's views, where nothing of the interface is drawn over it.
            whole = self.ui.model_view.area if self.ui is not None else Rect();
            casing.area = Rect(x=whole.x + whole.w // 3, y=whole.y + 8, w=max(160, whole.w * 2 // 3 - 8), h=max(120, whole.h // 2));
            if whole.w > 0 {
                casing.bounds = whole;
            }
            casing.settle(stage);
            stage.open(casing);
            self.model_float_box = casing;
            self.model_float_pane = pane;
            self.model_float_reach = self.model_reach;
        }
        print(self.modelview_words());
        self.say("A floating window looks at the model: drag in it to turn it there");
        return True;
    }
    if name == "ed_model" and how == "about" {
        if word not in ["model", "origin", "view", "free"] {
            self.say("ed_model about <model|origin|view|free>: what the view turns about: the model's middle, its origin, where the view looks (Shift and a drag moves it), or the eye itself (now " + self.model_about + ")");
            return True;
        }
        self.model_about = word;
        self.frame_model_about();
        self.keep_settings();
        print(self.modelview_words());
        about_words = "the eye";
        if word == "model" {
            about_words = "the model's middle";
        } elif word == "origin" {
            about_words = "the model's origin";
        } elif word == "view" {
            about_words = "where it looks (Shift and a drag moves that)";
        }
        self.say("The view turns about " + about_words);
        return True;
    }
    if name == "ed_mesh" and how == "lock" {
        if not word or (word not in ["off", "none"] and not locked_axes(word)) {
            self.say("ed_mesh lock <x|y|z|xy|...|off>: the axes the picked points may not be dragged along (now " + (self.model_lock if self.model_lock else "none") + ")");
            return True;
        }
        self.model_lock = locked_axes(word);
        print(self.modelview_words());
        self.say("Points are not dragged along " + ", ".join(list(self.model_lock)) if self.model_lock else "Points are dragged along every axis");
        return True;
    }
    if name == "ed_mesh" and how in ["colour", "color", "colours", "colors"] {
        part = doc.part() if doc is not None else None;
        if doc is None or part is None {
            self.say("No model is being edited (ed_model new <kind>, ed_model edit)");
            return True;
        }
        if how in ["colours", "colors"] {
            self.points_tinted = (not self.points_tinted) if word not in ["on", "off"] else word == "on";
            for (index, tint) in enumerate(part.tints) {
                if tint >= 0 {
                    print("studio: point " + str(index) + " colour=" + tint_word(tint));
                }
            }
            print(self.modelview_words());
            self.say("Points are shown in their own colours" if self.points_tinted else "Points' own colours are not shown");
            return True;
        }
        tint = word_tint(word);
        if (tint < 0 and word != "none") or len(part.picked_points) == 0 {
            self.say("ed_mesh colour <rrggbb|none>: give the picked points a colour of their own, or take it away (pick points first)");
            return True;
        }
        changed = doc.tint_points(list(part.picked_points), tint, "Colour points");
        # Shown, now that there is something to show.
        self.points_tinted = self.points_tinted or changed;
        print(self.modelview_words());
        self.say(
            (str(len(part.picked_points)) + " points " + ("are " + tint_word(tint) if tint >= 0 else "have no colour of their own"))
            if changed
            else "Nothing changed"
        );
        return True;
    }
    if name == "ed_skin" and how == "pattern" {
        if word not in SKIN_PATTERNS {
            self.say("ed_skin pattern <" + "|".join(SKIN_PATTERNS) + "> [grain]: what the brush lays its colour in (now " + self.skin_pattern + ")");
            return True;
        }
        self.skin_pattern = word;
        if len(args) > 3 and args[3].isdigit() {
            self.skin_grain = max(1, min(64, int(args[3])));
        }
        print(self.modelview_words());
        self.say("The brush paints " + ("solid" if word == "solid" else word + " " + str(self.skin_grain) + " texels wide"));
        return True;
    }
    if name == "ed_skin" and how == "pick" {
        image = self.model_skin;
        place: list[float] = [];
        try {
            place = [float(number) for number in args[2:4]];
        } except ValueError {
            place = [];
        }
        if image is None or len(place) != 2 {
            self.say("ed_skin pick <u> <v>: take up the colour at a place on the skin (Alt and a click on the model, when painting)");
            return True;
        }
        self.skin_color = skin_colour(image, place[0], place[1]);
        print("studio: skin colour " + " ".join([str(level) for level in self.skin_color]));
        self.say("The brush's colour is " + " ".join([str(level) for level in self.skin_color]));
        return True;
    }
    return False;
}
