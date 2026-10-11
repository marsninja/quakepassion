"""The studio's views: zoom, the ruler along the selection, names on every
entity, a picture laid behind an axis view, the list of remembered views and
the camera swung round what is selected. Declarations live in studio.jac."""

def:priv view_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in " ".join(words).split() {
        try {
            found.append(float(word));
        } except ValueError {
            continue;
        }
    }
    return found;
}

"""A length as a ruler shows it: whole when it is whole."""
def:priv ruler_words(length: float) -> str {
    nearest = float(round(length));
    return str(int(nearest)) if abs(length - nearest) < 0.05 else str(round(length, 1));
}

impl Studio.selection_box(scene: Scene) -> list[Vec3] | None {
    low = Vec3(x=1000000.0, y=1000000.0, z=1000000.0);
    high = Vec3(x=-1000000.0, y=-1000000.0, z=-1000000.0);
    count = 0;
    for shape in self.shapes {
        if scene.is_selected(shape.item) {
            low = Vec3(x=min(low.x, shape.low.x), y=min(low.y, shape.low.y), z=min(low.z, shape.low.z));
            high = Vec3(x=max(high.x, shape.high.x), y=max(high.y, shape.high.y), z=max(high.z, shape.high.z));
            count += 1;
        }
    }
    for look in self.looks {
        if scene.is_solid_selected(look.solid) {
            low = Vec3(x=min(low.x, look.low.x), y=min(low.y, look.low.y), z=min(low.z, look.low.z));
            high = Vec3(x=max(high.x, look.high.x), y=max(high.y, look.high.y), z=max(high.z, look.high.z));
            count += 1;
        }
    }
    return [low, high] if count > 0 else None;
}

impl Studio.swing(scene: Scene, yaw: float, pitch: float) {
    middle = scene.selection_middle();
    centre = middle if middle is not None else self.main.eye.add(self.main.forward().scale(256.0));
    self.main.orbit(centre, yaw, pitch);
}

impl Studio.draw_view_extras(scene: Scene, area: Rect) {
    canvas = self.canvas;
    lens = self.camera;
    world = scene.world();
    if lens.span > 0.0 {
        # A picture laid behind this view: where the document says, as
        # faint as it says.
        laid = world.fields.get("_backdrop", "");
        placed = world.fields.get("_backdrop_at", "").split();
        view_name = self.ports[self.port_now].title.lower() if self.port_now < len(self.ports) else "";
        if laid and len(placed) >= 5 and view_name.startswith(placed[0]) and canvas.has_picture("backdrop:" + laid) {
            spot = view_numbers(placed[1:5]);
            size = canvas.picture_size("backdrop:" + laid);
            if len(spot) == 4 and size[0] > 0 and spot[2] > 0.0 {
                wide = float(size[0]) * spot[2] * 0.5;
                tall = float(size[1]) * spot[2] * 0.5;
                heart = lens.right().scale(spot[0]).add(lens.up().scale(spot[1]));
                first = lens.project(area, heart.sub(lens.right().scale(wide)).add(lens.up().scale(tall)));
                second = lens.project(area, heart.add(lens.right().scale(wide)).sub(lens.up().scale(tall)));
                if first is not None and second is not None {
                    canvas.picture(
                        "backdrop:" + laid,
                        Rect(
                            x=min(first[0], second[0]),
                            y=min(first[1], second[1]),
                            w=abs(second[0] - first[0]),
                            h=abs(second[1] - first[1])
                        ),
                        int(spot[3])
                    );
                }
            }
        }
    }
    if lens.span > 0.0 and self.grid_shown {
        self.draw_grid_numbers(area);
    }
    if self.names {
        shown = 0;
        for shape in self.shapes {
            if shown >= 200 or scene.is_selected(shape.item) or shape.item is self.hover {
                # The selection and what is pointed at are named anyway.
                continue;
            }
            at = lens.project(area, Vec3(x=shape.center().x, y=shape.center().y, z=shape.high.z));
            if at is None or at[0] < area.x or at[0] > area.x + area.w or at[1] < area.y or at[1] > area.y + area.h {
                continue;
            }
            words = shape.item.title();
            canvas.text(
                words,
                at[0] - canvas.text_width(words, canvas.theme.small) // 2,
                at[1] - 16,
                canvas.theme.faint,
                canvas.theme.small
            );
            shown += 1;
        }
    }
    if not self.ruler or lens.span <= 0.0 or self.resizing {
        return;
    }
    box = self.selection_box(scene);
    if box is None {
        return;
    }
    low_at = lens.project(area, box[0]);
    high_at = lens.project(area, box[1]);
    if low_at is None or high_at is None {
        return;
    }
    left = min(low_at[0], high_at[0]);
    right = max(low_at[0], high_at[0]);
    top = min(low_at[1], high_at[1]);
    bottom = max(low_at[1], high_at[1]);
    extent = box[1].sub(box[0]);
    across = abs(extent.dot(lens.right()));
    upward = abs(extent.dot(lens.up()));
    tone = canvas.theme.dim;
    if right - left >= 8 {
        # Under the selection: how far it runs across the view.
        line_y = bottom + 12;
        canvas.line(left, line_y, right, line_y, tone);
        canvas.line(left, line_y - 4, left, line_y + 4, tone);
        canvas.line(right, line_y - 4, right, line_y + 4, tone);
        words = ruler_words(across);
        canvas.text(
            words,
            (left + right) // 2 - canvas.text_width(words, canvas.theme.small) // 2,
            line_y + 3,
            tone,
            canvas.theme.small
        );
    }
    if bottom - top >= 8 {
        # Beside it: how far it runs up the view.
        line_x = left - 12;
        canvas.line(line_x, top, line_x, bottom, tone);
        canvas.line(line_x - 4, top, line_x + 4, top, tone);
        canvas.line(line_x - 4, bottom, line_x + 4, bottom, tone);
        tall_words = ruler_words(upward);
        canvas.text(
            tall_words,
            line_x - 6 - canvas.text_width(tall_words, canvas.theme.small),
            (top + bottom) // 2 - 7,
            tone,
            canvas.theme.small
        );
    }
}

impl Studio.view_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_zoom" {
        how = args[1] if len(args) > 1 else "";
        sizes = view_numbers(args[1:2]);
        if how not in ["in", "out"] and (len(sizes) == 0 or sizes[0] < 16.0) {
            self.say("ed_zoom <in|out|units>: so many units fit an axis view's height");
            return True;
        }
        if how in ["in", "out"] and self.camera.span <= 0.0 {
            # The 3D view goes nearer or farther.
            self.camera.fly(64.0 if how == "in" else -64.0, 0.0, 0.0);
            return True;
        }
        for port in self.ports {
            if port.camera.span <= 0.0 {
                continue;
            }
            if how == "in" or how == "out" {
                if port.camera is self.camera {
                    port.camera.zoom(0.5 if how == "in" else 2.0);
                }
            } else {
                port.camera.span = min(65536.0, sizes[0]);
            }
        }
        if self.camera.span > 0.0 {
            self.say(str(int(self.camera.span)) + " units up this view");
        }
        return True;
    }
    if name == "ed_ruler" or name == "ed_names" {
        on = (not self.ruler) if name == "ed_ruler" else (not self.names);
        if len(args) > 1 and args[1] in ["on", "off", "1", "0"] {
            on = args[1] in ["on", "1"];
        }
        if name == "ed_ruler" {
            self.ruler = on;
            self.say("The axis views measure the selection" if on else "No ruler");
        } else {
            self.names = on;
            self.say("Every entity is named" if on else "Only the selection is named");
        }
        self.keep_settings();
        return True;
    }
    if name == "ed_backdrop" {
        world = scene.world();
        if len(args) < 2 {
            laid = world.fields.get("_backdrop", "");
            self.say(
                "Behind a view: " + laid + " (" + world.fields.get("_backdrop_at", "") + ")"
                if laid
                else "ed_backdrop <file|off> [top|front|side] [across up] [units per pixel] [alpha]"
            );
            return True;
        }
        step = Step(label="Backdrop");
        fresh: dict[str, str | None] = {"_backdrop": None, "_backdrop_at": None};
        if args[1] != "off" {
            path = args[1];
            try {
                with open(path, "rb") as file {
                    data = file.read();
                }
            } except OSError {
                self.say("Cannot read " + path);
                return True;
            }
            if not self.canvas.keep_encoded("backdrop:" + path, os.path.splitext(path)[1].lower(), data) {
                self.say(path + " is not a picture this can show (PNG, JPEG or TGA)");
                return True;
            }
            which = args[2] if len(args) > 2 and args[2] in ["top", "front", "side"] else "top";
            spot = view_numbers(args[3:] if len(args) > 2 and args[2] in ["top", "front", "side"] else args[2:]);
            across = spot[0] if len(spot) > 1 else 0.0;
            upward = spot[1] if len(spot) > 1 else 0.0;
            scale = spot[2] if len(spot) > 2 and spot[2] > 0.0 else 1.0;
            alpha = int(max(16.0, min(255.0, spot[3]))) if len(spot) > 3 else 110;
            fresh = {
                "_backdrop": path,
                "_backdrop_at": which + " " + ruler_words(across) + " " + ruler_words(upward) + " "
                    + str(round(scale, 4)) + " " + str(alpha)
            };
            self.backdrop_seen = path;
        }
        for (key, value) in fresh.items() {
            before = world.fields.get(key);
            if before == value {
                continue;
            }
            change = FieldChange(item=world, key=key, before=before, after=value);
            change.redo();
            step.changes.append(change);
        }
        scene.commit(step);
        self.say("No picture behind the views" if args[1] == "off" else "Laid " + args[1] + " behind a view");
        return True;
    }
    if name == "ed_marks" or name == "ed_unmark" {
        world = scene.world();
        marks = sorted([key[6:] for key in world.fields.keys() if key.startswith("_view_")]);
        if name == "ed_marks" {
            self.say(
                "Remembered views: " + ", ".join(marks)
                if marks
                else "No view has been remembered (ed_mark [name])"
            );
            return True;
        }
        label = args[1].strip() if len(args) > 1 else "";
        if label not in marks {
            self.say("No view is remembered as " + label if label else "ed_unmark <name>");
            return True;
        }
        gone = FieldChange(item=world, key="_view_" + label, before=world.fields.get("_view_" + label), after=None);
        gone.redo();
        scene.commit(Step(label="Forget view", changes=[gone]));
        self.say("Forgot the view " + label);
        return True;
    }
    if name == "ed_behind" {
        picks = scene.faces();
        if len(picks) != 1 {
            self.say("Pick one face to go behind (2)");
            return True;
        }
        outlines = picks[0].solid.outlines();
        outline = outlines[picks[0].side] if picks[0].side < len(outlines) else [];
        if len(outline) < 3 {
            self.say("That face has no outline");
            return True;
        }
        middle = Vec3();
        reach = 0.0;
        for point in outline {
            middle = middle.add(point);
        }
        middle = middle.scale(1.0 / float(len(outline)));
        for point in outline {
            reach = max(reach, point.sub(middle).length());
        }
        normal = picks[0].solid.sides[picks[0].side].plane.normal;
        self.main.look_from(middle.sub(normal.scale(max(96.0, reach * 2.0))), middle);
        self.say("Behind face " + str(picks[0].side) + " of brush #" + str(picks[0].solid.serial));
        return True;
    }
    if name == "ed_swing" {
        angles = view_numbers(args[1:]);
        if len(angles) < 2 {
            self.say("ed_swing <yaw> <pitch>: degrees round the selection");
            return True;
        }
        self.swing(scene, math.radians(angles[0]), math.radians(angles[1]));
        return True;
    }
    return False;
}
