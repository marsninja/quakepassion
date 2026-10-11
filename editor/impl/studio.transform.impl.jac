"""The studio's turn and size handles, the pivot, inflating and the texture
lock. Declarations live in studio.jac."""

def:priv turn_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            return [];
        }
    }
    return found;
}

"""A factor a dragged size handle may leave: in quarters, or freely."""
def:priv size_factor(raw: float, free: bool) -> float {
    if free {
        return max(0.05, float(round(raw * 100.0)) / 100.0);
    }
    return max(0.25, float(round(raw * 4.0)) / 4.0);
}

"""Where around a ring a line of sight meets the ring's plane, as an angle
from `across` toward `over`. None when the line runs along the plane."""
def:priv ring_angle(line: list[Vec3], middle: Vec3, axis: Vec3, across: Vec3, over: Vec3) -> float | None {
    closing = line[1].dot(axis);
    if abs(closing) < 0.0001 {
        return None;
    }
    reach = middle.sub(line[0]).dot(axis) / closing;
    met = line[0].add(line[1].scale(reach)).sub(middle);
    return math.atan2(met.dot(over), met.dot(across));
}

def:priv factor_words(value: float) -> str {
    return str(round(value, 3));
}

impl Studio.pivot_for(scene: Scene) -> Vec3 | None {
    if self.pivot_set and scene.picks != self.pivot_picks {
        # A pivot set by hand lasts as long as the selection it was set for.
        self.pivot_set = False;
    }
    if self.pivot_set {
        return self.pivot_at;
    }
    return scene.selection_pivot();
}

impl Studio.turn_hub(scene: Scene) -> Vec3 | None {
    chosen_pivot = self.pivot_for(scene);
    if chosen_pivot is not None {
        return chosen_pivot;
    }
    return scene.selection_hub(self.grid);
}

impl Studio.arm_of(middle: Vec3) -> float {
    if self.camera.span > 0.0 {
        return self.camera.span * 0.1;
    }
    return max(24.0, self.camera.eye.sub(middle).length() * 0.15);
}

impl Studio.transform_handles(scene: Scene) -> list[tuple[int, Vec3]] {
    found: list[tuple[int, Vec3]] = [];
    if self.gizmo == "box" {
        return self.box_handles(scene);
    }
    middle = self.turn_hub(scene);
    if middle is None {
        return found;
    }
    arm = self.arm_of(middle);
    if self.gizmo == "turn" {
        # A ring seen edge on cannot be turned by: only those that face the view.
        sightline = self.camera.forward();
        if self.camera.span <= 0.0 and self.camera.eye.sub(middle).length() > 0.001 {
            sightline = middle.sub(self.camera.eye).normalized();
        }
        for about in range(3) {
            if abs(sightline.dot(axis_vector(about))) > 0.2 {
                found.append((910 + about, middle.add(axis_vector((about + 1) % 3).scale(arm))));
            }
        }
    } else {
        for along in range(3) {
            found.append((920 + along, middle.add(axis_vector(along).scale(arm))));
        }
        found.append((923, middle.add(Vec3(x=arm * 0.55, y=arm * 0.55, z=arm * 0.55))));
    }
    found.append((930, middle));
    return found;
}

impl Studio.dragged_point(point: Vec3, middle: Vec3) -> Vec3 {
    held = self.resize_side;
    if held >= 950 and held <= 958 {
        return point_remapped(point, self.box_pull.pivot, self.box_pull.change).add(self.box_pull.move);
    }
    if held >= 920 and held <= 923 {
        away = point.sub(middle);
        return middle.add(
            Vec3(x=away.x * self.size_by.x, y=away.y * self.size_by.y, z=away.z * self.size_by.z)
        );
    }
    if held >= 910 and held <= 912 {
        return middle.add(spun_about(point.sub(middle), axis_vector(held - 910), math.radians(self.turn_by)));
    }
    return point;
}

impl Studio.drag_transform(scene: Scene, x: int, y: int, free: bool) {
    held = self.resize_side;
    if held == 940 or held == 941 {
        self.drag_mark(scene, x, y, free);
        return;
    }
    if held >= 950 and held <= 958 {
        self.drag_box(scene, x, y, free);
        return;
    }
    if held >= 960 and held <= 962 {
        self.drag_lay(scene, x, y, free);
        return;
    }
    middle = self.turn_hub(scene);
    if middle is None {
        return;
    }
    view = self.view_area();
    if held == 930 {
        # The pivot itself goes where it is dragged, in the plane facing the view.
        gone = self.on_view_plane(x, y, middle).sub(self.on_view_plane(self.press_x, self.press_y, middle));
        notch = 1.0 if free else self.grid;
        self.corner_by = Vec3(
            x=float(round(gone.x / notch)) * notch,
            y=float(round(gone.y / notch)) * notch,
            z=float(round(gone.z / notch)) * notch
        );
        return;
    }
    if held == 923 {
        # All three at once: to the right and up grows, to the left and down shrinks.
        every = size_factor(1.0 + float((x - self.press_x) - (y - self.press_y)) / 120.0, free);
        self.size_by = Vec3(x=every, y=every, z=every);
        return;
    }
    if held >= 920 {
        axis = axis_vector(held - 920);
        arm = self.arm_of(middle);
        from_at = self.camera.project(view, middle);
        to_at = self.camera.project(view, middle.add(axis.scale(arm)));
        if from_at is None or to_at is None {
            return;
        }
        run = float(to_at[0] - from_at[0]);
        rise = float(to_at[1] - from_at[1]);
        length = run * run + rise * rise;
        if length < 1.0 {
            return;
        }
        # As far as the pointer has gone along the arm as seen, in arms.
        pulled = (float(x - self.press_x) * run + float(y - self.press_y) * rise) / length;
        one = size_factor(1.0 + pulled, free);
        self.size_by = Vec3(
            x=one if held == 920 else 1.0, y=one if held == 921 else 1.0, z=one if held == 922 else 1.0
        );
        return;
    }
    about = axis_vector(held - 910);
    across = axis_vector((held - 910 + 1) % 3);
    over = about.cross(across);
    began = ring_angle(self.camera.sight(view, self.press_x, self.press_y), middle, about, across, over);
    now = ring_angle(self.camera.sight(view, x, y), middle, about, across, over);
    if began is None or now is None {
        return;
    }
    swept = math.degrees(now - began);
    while swept > 180.0 {
        swept -= 360.0;
    }
    while swept <= -180.0 {
        swept += 360.0;
    }
    notch = 1.0 if free else max(1.0, self.angle_snap);
    self.turn_by = float(round(swept / notch)) * notch;
}

impl Studio.transform_words(scene: Scene) -> str {
    held = self.resize_side;
    if held == 940 or held == 941 {
        # The way it faces, or how far it lights, as the drag left it.
        if self.turn_by < 0.0 {
            return "";
        }
        return ("ed_set angle " if held == 940 else "ed_set light ") + str(int(round(self.turn_by)));
    }
    if held >= 950 and held <= 958 {
        return self.box_words();
    }
    if held >= 960 and held <= 962 {
        return self.lay_words();
    }
    if held >= 910 and held <= 912 {
        if self.turn_by == 0.0 {
            return "";
        }
        return "ed_rotate " + factor_words(self.turn_by) + " " + ["x", "y", "z"][held - 910];
    }
    if held >= 920 and held <= 923 {
        factors = self.size_by;
        if factors.x == 1.0 and factors.y == 1.0 and factors.z == 1.0 {
            return "";
        }
        return "ed_resize " + factor_words(factors.x) + " " + factor_words(factors.y) + " " + factor_words(factors.z);
    }
    middle = self.turn_hub(scene);
    if held != 930 or middle is None or self.corner_by.length() == 0.0 {
        return "";
    }
    placed = middle.add(self.corner_by);
    return "ed_pivot " + factor_words(placed.x) + " " + factor_words(placed.y) + " " + factor_words(placed.z);
}

impl Studio.draw_transform_preview(scene: Scene) {
    middle = self.turn_hub(scene);
    if middle is None or self.resize_side == 930 {
        return;
    }
    tone = ink(0xff7a18);
    carried = scene.selected_solids();
    for item in scene.selection() {
        for solid in scene.solids_of(item) {
            if solid not in carried {
                carried.append(solid);
            }
        }
    }
    drawn = 0;
    for solid in carried {
        if drawn >= 400 {
            break;
        }
        look = self.look_of(solid);
        if look is None {
            continue;
        }
        drawn += 1;
        for outline in look.outlines {
            corners = len(outline);
            for index in range(corners) {
                wire_line(
                    self.dragged_point(outline[index], middle),
                    self.dragged_point(outline[(index + 1) % corners], middle),
                    tone
                );
            }
        }
    }
    for item in scene.selection() {
        if item.origin() is None {
            continue;
        }
        boxed = self.shape_of(item);
        if boxed is not None {
            half = boxed.high.sub(boxed.low).scale(0.5);
            landed = self.dragged_point(boxed.center(), middle);
            wire_box(landed.sub(half), landed.add(half), tone);
        }
    }
}

impl Studio.draw_transform_handles(scene: Scene, area: Rect) {
    if self.gizmo == "box" {
        self.draw_box_handle(scene, area);
        return;
    }
    canvas = self.canvas;
    middle = self.turn_hub(scene);
    if middle is None {
        return;
    }
    centre = self.camera.project(area, middle);
    if centre is None {
        return;
    }
    tones = [ink(0xe5484d), ink(0x4cc38a), ink(0x5b8def)];
    arm = self.arm_of(middle);
    held = self.resize_side if self.resizing else -1;
    # How far down the view the handles reach, so what a drag says goes under them.
    lowest = centre[1];
    for (index, spot) in self.transform_handles(scene) {
        if index == 930 {
            continue;
        }
        shown_at = self.dragged_point(spot, middle) if held >= 910 and held != 930 else spot;
        at = self.camera.project(area, shown_at);
        rest = self.camera.project(area, spot);
        if rest is not None {
            # A ring reaches as far below the middle as its knob is from it.
            lowest = max(
                lowest,
                max(rest[1], centre[1] + abs(rest[0] - centre[0]) + abs(rest[1] - centre[1]))
                if index <= 912
                else rest[1]
            );
        }
        if at is not None {
            lowest = max(lowest, at[1]);
        }
        if index >= 910 and index <= 912 {
            # The ring the knob runs round.
            about = axis_vector(index - 910);
            across = axis_vector((index - 910 + 1) % 3);
            over = about.cross(across);
            before: list[int] | None = None;
            for part in range(49) {
                angle = float(part) * math.pi / 24.0;
                on_ring = self.camera.project(
                    area,
                    middle.add(across.scale(arm * math.cos(angle))).add(over.scale(arm * math.sin(angle)))
                );
                if on_ring is not None and before is not None {
                    canvas.line(before[0], before[1], on_ring[0], on_ring[1], tones[index - 910]);
                }
                before = on_ring;
            }
            if at is not None {
                canvas.line(centre[0], centre[1], at[0], at[1], tones[index - 910]);
            }
        } elif at is not None {
            if index != 923 and abs(at[0] - centre[0]) + abs(at[1] - centre[1]) < 6 {
                # An arm seen end on has no handle to take hold of.
                continue;
            }
            canvas.line(centre[0], centre[1], at[0], at[1], tones[index - 920] if index < 923 else canvas.theme.text);
        }
        if at is None {
            continue;
        }
        grabbed = held == index;
        tone = canvas.theme.text if index == 923 else tones[(index - 910) % 10];
        if index >= 920 {
            # A size handle is a box; a turn handle a smaller one on its ring.
            box = Rect(x=at[0] - 5, y=at[1] - 5, w=11, h=11);
            canvas.fill(box, canvas.theme.accent if grabbed else tone);
            canvas.outline(box, canvas.theme.header);
        } else {
            knob = Rect(x=at[0] - 4, y=at[1] - 4, w=9, h=9);
            canvas.fill(knob, canvas.theme.accent if grabbed else tone);
            canvas.outline(knob, canvas.theme.header);
        }
    }
    # The pivot: a small cross, where everything turns and stretches about.
    hub_at = self.camera.project(area, middle.add(self.corner_by) if held == 930 else middle);
    if hub_at is not None {
        mark = canvas.theme.accent if held == 930 or self.pivot_set else canvas.theme.text;
        canvas.line(hub_at[0] - 7, hub_at[1], hub_at[0] + 7, hub_at[1], mark);
        canvas.line(hub_at[0], hub_at[1] - 7, hub_at[0], hub_at[1] + 7, mark);
        canvas.outline(Rect(x=hub_at[0] - 3, y=hub_at[1] - 3, w=7, h=7), mark);
    }
    words = "";
    if held >= 910 and held <= 912 {
        words = str(int(round(self.turn_by))) + " degrees";
    } elif held >= 920 and held <= 923 {
        words = "x " + factor_words(self.size_by.x) + "  y " + factor_words(self.size_by.y) + "  z "
            + factor_words(self.size_by.z);
    } elif held == 930 {
        moved_to = middle.add(self.corner_by);
        words = "pivot " + str(int(moved_to.x)) + " " + str(int(moved_to.y)) + " " + str(int(moved_to.z));
    }
    if words {
        wide = canvas.text_width(words, canvas.theme.small) + 8;
        tag = Rect(x=centre[0] - wide // 2, y=min(lowest + 10, area.y + area.h - 18), w=wide, h=16);
        canvas.fill(tag, canvas.theme.header.faded(210));
        canvas.label(words, tag, canvas.theme.text, 0, 0, canvas.theme.small);
    }
}

impl Studio.transform_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_gizmo" {
        kinds = ["move", "turn", "size", "box"];
        if len(args) > 1 and args[1] in kinds {
            self.gizmo = args[1];
        } elif len(args) > 1 and args[1] == "next" {
            self.gizmo = kinds[(kinds.index(self.gizmo) + 1) % len(kinds)] if self.gizmo in kinds else "move";
        } else {
            self.say("ed_gizmo <move|turn|size|box|next>");
            return True;
        }
        self.say(
            (
                "One handle: its middle moves, its corners turn (Shift sizes), its edges shear and size"
                if self.gizmo == "box"
                else "Handles that " + self.gizmo
            )
                + (" (in brush mode, 1)" if self.mode != "brush" else "")
        );
        # The inspector's own choice of handles follows.
        self.seen_revision = -1;
        return True;
    }
    if name == "ed_pivot" {
        if len(args) == 1 {
            current = self.pivot_for(scene);
            self.say(
                "The pivot is at " + str(int(current.x)) + " " + str(int(current.y)) + " " + str(int(current.z))
                if current is not None
                else "ed_pivot [x y z | middle | clear]: the selection turns about its middle"
            );
            return True;
        }
        if args[1] == "clear" {
            self.pivot_set = False;
            scene.set_pivot(None);
            self.say("The selection turns about its middle");
            return True;
        }
        target: Vec3 | None = None;
        if args[1] == "middle" {
            target = scene.selection_hub(self.grid);
        } else {
            typed = turn_numbers(args[1:]);
            if len(typed) >= 3 {
                target = Vec3(x=typed[0], y=typed[1], z=typed[2]);
            }
        }
        if target is None {
            self.say("ed_pivot [x y z | middle | clear]");
            return True;
        }
        spot_words = str(int(target.x)) + " " + str(int(target.y)) + " " + str(int(target.z));
        if scene.set_pivot(target) {
            # One group alone: it keeps the pivot for itself, in the document.
            self.pivot_set = False;
            self.say("The group keeps its pivot at " + spot_words);
        } else {
            self.pivot_at = target;
            self.pivot_set = True;
            self.pivot_picks = scene.picks;
            self.say("The selection turns about " + spot_words);
        }
        return True;
    }
    if name == "ed_anglesnap" {
        if len(args) > 1 {
            asked = turn_numbers(args[1:2]);
            if len(asked) == 0 {
                self.say("ed_anglesnap [degrees]");
                return True;
            }
            self.angle_snap = min(180.0, max(1.0, asked[0]));
            self.keep_settings();
        }
        self.say("A dragged turn snaps to " + str(int(self.angle_snap)) + " degrees");
        return True;
    }
    if name == "ed_inflate" {
        amount = 0.0;
        if len(args) > 1 and args[1] == "up" {
            amount = self.grid;
        } elif len(args) > 1 and args[1] == "down" {
            amount = -self.grid;
        } else {
            given = turn_numbers(args[1:2]);
            if len(given) == 0 or given[0] == 0.0 {
                self.say("ed_inflate <units|up|down>");
                return True;
            }
            amount = given[0];
        }
        count = scene.inflate_selection(amount);
        self.say(
            ("Grew " if amount > 0.0 else "Shrank ") + str(count)
            if count
            else "No selected brush can take that"
        );
        return True;
    }
    if name == "ed_texlock" {
        if len(args) > 1 and args[1] in ["on", "off", "1", "0"] {
            self.tex_lock = args[1] in ["on", "1"];
        } else {
            self.tex_lock = not self.tex_lock;
        }
        self.keep_settings();
        self.say(
            "Materials go with their faces" if self.tex_lock else "Materials stay where they lie as faces move"
        );
        return True;
    }
    return False;
}
