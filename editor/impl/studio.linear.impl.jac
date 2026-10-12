"""The studio's box handle: one handle round the selection that moves it,
turns it, sizes it and shears it; and the same changes said in numbers.
Declarations live in studio.jac."""

def:priv linear_numbers(words: list[str]) -> list[float] {
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

def:priv short_number(value: float) -> str {
    return str(int(value)) if value == float(int(value)) else str(round(value, 3));
}

"""Where a line of sight meets the plane across an axis at a height along
it. None when the line runs along the plane."""
def:priv on_level(line: list[Vec3], axis: int, height: float) -> Vec3 | None {
    closing = along_axis(line[1], axis);
    if abs(closing) < 0.0001 {
        return None;
    }
    return line[0].add(line[1].scale((height - along_axis(line[0], axis)) / closing));
}

impl Studio.box_axes -> list[int] {
    if self.camera.span > 0.0 and not self.camera.oblique() {
        depth = self.camera.depth_axis();
        if abs(depth.x) > 0.5 {
            return [1, 2];
        }
        if abs(depth.y) > 0.5 {
            return [0, 2];
        }
    }
    # From above, and in the 3D view: the handle lies level, across the box's middle.
    return [0, 1];
}

impl Studio.box_bounds(scene: Scene) -> list[Vec3] | None {
    spots: list[Vec3] = [];
    for solid in scene.selected_solids() {
        reach = solid.bounds();
        if reach is not None {
            spots.append(reach[0]);
            spots.append(reach[1]);
        }
    }
    for item in scene.selection() {
        at = item.origin();
        if at is not None {
            boxed = self.shape_of(item);
            if boxed is not None {
                spots.append(boxed.low);
                spots.append(boxed.high);
            } else {
                spots.append(at);
            }
            continue;
        }
        for solid in scene.solids_of(item) {
            reach = solid.bounds();
            if reach is not None {
                spots.append(reach[0]);
                spots.append(reach[1]);
            }
        }
    }
    if len(spots) == 0 {
        return None;
    }
    low = spots[0];
    high = spots[0];
    for spot in spots {
        low = Vec3(x=min(low.x, spot.x), y=min(low.y, spot.y), z=min(low.z, spot.z));
        high = Vec3(x=max(high.x, spot.x), y=max(high.y, spot.y), z=max(high.z, spot.z));
    }
    return [low, high];
}

impl Studio.box_handles(scene: Scene) -> list[tuple[int, Vec3]] {
    found: list[tuple[int, Vec3]] = [];
    round_it = self.box_bounds(scene);
    if round_it is None {
        return found;
    }
    seen_by = self.box_axes();
    span_of = round_it[1].sub(round_it[0]);
    # A box with no size as it is seen has only its middle to hold.
    thin = along_axis(span_of, seen_by[0]) < 1.0 or along_axis(span_of, seen_by[1]) < 1.0;
    for number in range(9) {
        if thin and number != 4 {
            continue;
        }
        found.append((950 + number, box_part(round_it[0], round_it[1], seen_by[0], seen_by[1], number)));
    }
    return found;
}

impl Studio.drag_box(scene: Scene, x: int, y: int, free: bool) {
    round_it = self.box_bounds(scene);
    if round_it is None {
        return;
    }
    seen_by = self.box_axes();
    heart = round_it[0].add(round_it[1]).scale(0.5);
    number = self.resize_side - 950;
    gone = Vec3();
    if self.camera.span > 0.0 and not self.camera.oblique() {
        gone = self.on_view_plane(x, y, heart).sub(self.on_view_plane(self.press_x, self.press_y, heart));
    } else {
        # In the plane the handle lies in: level, through the box's middle.
        across_it = 3 - seen_by[0] - seen_by[1];
        level = along_axis(heart, across_it);
        began = on_level(self.camera.sight(self.view_area(), self.press_x, self.press_y), across_it, level);
        now_at = on_level(self.camera.sight(self.view_area(), x, y), across_it, level);
        if began is None or now_at is None {
            return;
        }
        gone = now_at.sub(began);
    }
    notch = 1.0 if free else max(1.0, self.grid);
    gone = Vec3(
        x=float(round(gone.x / notch)) * notch,
        y=float(round(gone.y / notch)) * notch,
        z=float(round(gone.z / notch)) * notch
    );
    toward = box_part(round_it[0], round_it[1], seen_by[0], seen_by[1], number).add(gone);
    # A corner turns, and with Shift sizes; an edge shears or sizes by the way it is dragged, and with Shift sizes.
    manner = "size" if self.held_shift else ("turn" if number % 2 == 0 else "");
    self.box_pull = box_drag(
        round_it[0], round_it[1], seen_by[0], seen_by[1], number, toward, manner, 0.0 if free else max(1.0, self.angle_snap)
    );
    self.box_said = self.box_says();
}

impl Studio.box_words -> str {
    pull = self.box_pull;
    if pull.idle() {
        return "";
    }
    if pull.label == "Move" {
        return "ed_move " + short_number(pull.move.x) + " " + short_number(pull.move.y) + " " + short_number(pull.move.z);
    }
    return "ed_linear " + linear_text(pull.change) + " about " + short_number(pull.pivot.x) + " "
        + short_number(pull.pivot.y) + " " + short_number(pull.pivot.z) + " " + pull.label;
}

impl Studio.box_says -> str {
    pull = self.box_pull;
    if pull.idle() {
        return "";
    }
    seen_by = self.box_axes();
    letters = ["x", "y", "z"];
    if pull.label == "Move" {
        return "move " + short_number(pull.move.x) + " " + short_number(pull.move.y) + " " + short_number(pull.move.z);
    }
    first = pull.change.carry(axis_vector(seen_by[0]));
    second = pull.change.carry(axis_vector(seen_by[1]));
    if pull.label == "Turn" {
        swung = math.degrees(math.atan2(along_axis(first, seen_by[1]), along_axis(first, seen_by[0])));
        return "turn " + short_number(float(round(swung * 10.0)) / 10.0) + " degrees";
    }
    if pull.label == "Shear" {
        slope = along_axis(second, seen_by[0]) + along_axis(first, seen_by[1]);
        return "shear " + short_number(slope);
    }
    return "size " + letters[seen_by[0]] + " " + short_number(first.length()) + "  " + letters[seen_by[1]] + " "
        + short_number(second.length());
}

impl Studio.draw_box_handle(scene: Scene, area: Rect) {
    canvas = self.canvas;
    held = self.resize_side if self.resizing else -1;
    pulling = held >= 950 and held <= 958;
    spots: dict[int, list[int]] = {};
    for (index, spot) in self.box_handles(scene) {
        at = self.camera.project(area, self.dragged_point(spot, spot) if pulling else spot);
        if at is not None {
            spots[index - 950] = at;
        }
    }
    # The box as it is seen, and as the drag would leave it: its four corners in turn.
    frame_tone = canvas.theme.accent if pulling else canvas.theme.text;
    ring = [0, 2, 8, 6];
    for place in range(4) {
        if ring[place] in spots and ring[(place + 1) % 4] in spots {
            from_at = spots[ring[place]];
            to_at = spots[ring[(place + 1) % 4]];
            canvas.line(from_at[0], from_at[1], to_at[0], to_at[1], frame_tone);
        }
    }
    lowest = area.y;
    for (number, at) in spots.items() {
        lowest = max(lowest, at[1]);
        grabbed = held == 950 + number;
        # Corners turn (blue), edges shear and size (green), the middle moves (red).
        tone = ink(0xe5484d) if number == 4 else (ink(0x5b8def) if number % 2 == 0 else ink(0x4cc38a));
        reach_of = 6 if number == 4 else 5;
        knob = Rect(x=at[0] - reach_of, y=at[1] - reach_of, w=reach_of * 2 + 1, h=reach_of * 2 + 1);
        canvas.fill(knob, canvas.theme.accent if grabbed else tone);
        canvas.outline(knob, canvas.theme.header);
    }
    words = self.box_said if pulling else "";
    if words and 4 in spots {
        wide = canvas.text_width(words, canvas.theme.small) + 8;
        tag = Rect(x=spots[4][0] - wide // 2, y=min(lowest + 12, area.y + area.h - 18), w=wide, h=16);
        canvas.fill(tag, canvas.theme.header.faded(210));
        canvas.label(words, tag, canvas.theme.text, 0, 0, canvas.theme.small);
    }
}

impl Studio.linear_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_shear" {
        letters = ["x", "y", "z"];
        amounts = linear_numbers(args[3:]);
        if len(args) < 4 or args[1] not in letters or args[2] not in letters or args[1] == args[2] or len(amounts) < 1 {
            self.say("ed_shear <x|y|z> <x|y|z> <amount>: slide along the first by so much for each unit along the second");
            return True;
        }
        lean = linear_shear(letters.index(args[1]), letters.index(args[2]), amounts[0]);
        if not scene.remap_selection(lean, self.pivot_for(scene), "Shear", self.grid, self.tex_turns()) {
            self.say("Nothing to shear");
        } else {
            self.say("Sheared along " + args[1] + " by " + short_number(amounts[0]) + " a unit of " + args[2]);
        }
        return True;
    }
    if name == "ed_linear" {
        wanted_change = linear_from(args[1:10]);
        if wanted_change is None {
            self.say("ed_linear <what x becomes> <what y becomes> <what z becomes> [about <x> <y> <z>] [name]: nine numbers");
            return True;
        }
        hub: Vec3 | None = self.pivot_for(scene);
        rest = args[10:];
        if len(rest) >= 4 and rest[0] == "about" {
            spot_numbers = linear_numbers(rest[1:4]);
            if len(spot_numbers) == 3 {
                hub = Vec3(x=spot_numbers[0], y=spot_numbers[1], z=spot_numbers[2]);
            }
            rest = rest[4:];
        }
        called = rest[0] if len(rest) > 0 and rest[0] in ["Turn", "Stretch", "Shear"] else "Change";
        if wanted_change.slopes() is None {
            self.say("That would flatten the selection");
        } elif not scene.remap_selection(wanted_change, hub, called, self.grid, self.tex_turns()) {
            self.say("Nothing to change");
        }
        return True;
    }
    return False;
}
