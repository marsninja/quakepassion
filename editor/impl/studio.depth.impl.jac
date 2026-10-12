"""Axis views held to a band of depth, with what lies outside it greyed or
left out and the band drawn in the other views; and axis views turned off
their axes, with a compass that says how. Declarations live in studio.jac."""

"""The numbers among a command's words, as far as they all are numbers."""
def:priv band_numbers(words: list[str]) -> list[float] {
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

impl Studio.lens_of(view: SceneView) -> EditCamera | None {
    for port in self.ports {
        area = port.view.area;
        if area.x == view.x and area.y == view.y and area.w == view.width and area.h == view.height {
            return port.camera;
        }
    }
    return None;
}

impl Studio.port_named(word: str) -> int {
    for (index, port) in enumerate(self.ports) {
        if index > 0 and word and port.title.lower().startswith(word.lower()) {
            return index;
        }
    }
    return -1;
}

impl Studio.veiled(low: Vec3, high: Vec3) -> int {
    lens = self.lens_now;
    if lens is None or self.outside == "whole" or not lens.out_of_depth(low, high) {
        return 0;
    }
    return 2 if self.outside == "hide" else 1;
}

impl Studio.unpickable(low: Vec3, high: Vec3) -> bool {
    # What a view leaves out is not there to be clicked in it.
    return self.outside == "hide" and self.camera.out_of_depth(low, high);
}

impl Studio.draw_depth_lines(view: SceneView) {
    if view.span <= 0.0 {
        return;
    }
    ahead = forward_from(view.yaw, view.pitch);
    for (number, port) in enumerate(self.ports[1:self.showing()]) {
        held = port.camera;
        if not held.bounded or held.span <= 0.0 {
            continue;
        }
        axis = held.depth_axis();
        if abs(axis.dot(ahead)) > 0.99 {
            # The view the band is of, or one that looks the same way.
            continue;
        }
        # Where each edge of the band cuts this view: a line across it.
        along = ahead.cross(axis).normalized();
        base = view.eye.sub(axis.scale(view.eye.dot(axis)));
        reach = view.span * 4.0;
        for (side, edge) in enumerate([held.depth_low, held.depth_high]) {
            pulled = self.resizing and self.resize_side == 970 + (number + 1) * 2 + side;
            spot = base.add(axis.scale(self.resize_by if pulled else edge));
            wire_line(spot.sub(along.scale(reach)), spot.add(along.scale(reach)), ink(0xff7a18) if pulled else ink(0xe5484d));
        }
    }
}

impl Studio.depth_knobs -> list[tuple[int, Vec3]] {
    found: list[tuple[int, Vec3]] = [];
    lens = self.camera;
    if lens.span <= 0.0 {
        return found;
    }
    ahead = lens.forward();
    for number in range(1, min(4, self.showing())) {
        held = self.ports[number].camera;
        if number == self.port_now or not held.bounded or held.span <= 0.0 {
            continue;
        }
        axis = held.depth_axis();
        if abs(axis.dot(ahead)) > 0.99 {
            continue;
        }
        # A knob on each red line, a third of the way from the view's middle.
        along = ahead.cross(axis).normalized();
        base = lens.eye.sub(axis.scale(lens.eye.dot(axis))).add(along.scale(lens.span * 0.3));
        for (side, edge) in enumerate([held.depth_low, held.depth_high]) {
            index = 970 + number * 2 + side;
            pulled = self.resizing and self.resize_side == index;
            found.append((index, base.add(axis.scale(self.resize_by if pulled else edge))));
        }
    }
    return found;
}

impl Studio.drag_depth(x: int, y: int, free: bool) {
    number = (self.resize_side - 970) // 2;
    if number < 1 or number >= len(self.ports) {
        return;
    }
    held = self.ports[number].camera;
    axis = held.depth_axis();
    side = (self.resize_side - 970) % 2;
    at = axis.scale(held.depth_low if side == 0 else held.depth_high);
    # Where the pointer is, in the plane of this view through the line.
    pointed = self.on_view_plane(x, y, self.camera.eye.sub(axis.scale(self.camera.eye.dot(axis))).add(at));
    notch = 1.0 if free else max(1.0, self.grid);
    self.resize_by = float(round(pointed.dot(axis) / notch)) * notch;
}

impl Studio.depth_order -> str {
    number = (self.resize_side - 970) // 2;
    if number < 1 or number >= len(self.ports) {
        return "";
    }
    held = self.ports[number].camera;
    side = (self.resize_side - 970) % 2;
    low = self.resize_by if side == 0 else held.depth_low;
    high = self.resize_by if side == 1 else held.depth_high;
    if abs((held.depth_low if side == 0 else held.depth_high) - self.resize_by) < 0.001 or high - low < 1.0 {
        # Not moved, or moved past the other edge.
        return "";
    }
    return "ed_depth " + self.ports[number].title.split()[0].lower() + " " + str(int(round(low))) + " " + str(int(round(high)));
}

impl Studio.draw_depth_knobs(area: Rect) {
    canvas = self.canvas;
    for (index, spot) in self.depth_knobs() {
        at = self.camera.project(area, spot);
        if at is None {
            continue;
        }
        knob = Rect(x=at[0] - 5, y=at[1] - 5, w=11, h=11);
        canvas.fill(knob, canvas.theme.accent if self.resizing and self.resize_side == index else ink(0xe5484d));
        canvas.outline(knob, canvas.theme.header);
    }
}

impl Studio.compass_at(area: Rect) -> list[int] {
    return [area.x + area.w - 36, area.y + 44, 22];
}

impl Studio.draw_compass(area: Rect) {
    canvas = self.canvas;
    lens = self.camera;
    place = self.compass_at(area);
    reach = float(place[2]);
    tone = canvas.theme.dim;
    for i in range(16) {
        first = 2.0 * math.pi * float(i) / 16.0;
        second = 2.0 * math.pi * float(i + 1) / 16.0;
        canvas.line(
            place[0] + int(reach * math.cos(first)),
            place[1] + int(reach * math.sin(first)),
            place[0] + int(reach * math.cos(second)),
            place[1] + int(reach * math.sin(second)),
            tone
        );
    }
    # The world's three axes as the view sees them.
    needles = [(Vec3(x=1.0), "x", 0xe5484d), (Vec3(y=1.0), "y", 0x3ddc97), (Vec3(z=1.0), "z", 0x4f8ef7)];
    for (axis, letter, shade) in needles {
        tip_x = place[0] + int(axis.dot(lens.right()) * reach);
        tip_y = place[1] - int(axis.dot(lens.up()) * reach);
        canvas.line(place[0], place[1], tip_x, tip_y, ink(shade));
        canvas.text(letter, tip_x + 2, tip_y - 6, ink(shade), canvas.theme.small);
    }
}

impl Studio.depth_words -> list[str] {
    lines: list[str] = [];
    bands: list[str] = [];
    turned: list[str] = [];
    for port in self.ports[1:] {
        lens = port.camera;
        word = port.title.split()[0].lower();
        if lens.bounded {
            out = 0;
            for seen in self.looks {
                if lens.out_of_depth(seen.low, seen.high) {
                    out += 1;
                }
            }
            bands.append(word + "=" + str(int(round(lens.depth_low))) + ".." + str(int(round(lens.depth_high))) + "/" + str(out));
        }
        if lens.oblique() {
            turned.append(
                word + "=" + str(int(round(math.degrees(lens.yaw)))) + "," + str(int(round(math.degrees(lens.pitch))))
            );
        }
    }
    if bands {
        lines.append("studio: depth " + " ".join(bands) + " outside=" + self.outside);
    }
    if turned {
        lines.append("studio: oblique " + " ".join(turned));
    }
    return lines;
}

impl Studio.depth_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_outside" {
        ways = ["whole", "grey", "hide"];
        if len(args) > 1 and args[1] in ways {
            self.outside = args[1];
        } elif len(args) > 1 {
            self.say("ed_outside [whole|grey|hide]: how a view held to a band of depth shows what lies outside it");
            return True;
        } else {
            self.outside = ways[(ways.index(self.outside) + 1) % 3];
        }
        self.keep_settings();
        self.say(
            "Outside a view's band of depth, things are "
                + ("drawn as ever" if self.outside == "whole" else ("greyed" if self.outside == "grey" else "left out"))
        );
        return True;
    }
    if name != "ed_depth" and name != "ed_oblique" {
        return False;
    }
    words = args[1:];
    which = self.port_named(words[0]) if len(words) > 0 else -1;
    if which > 0 {
        words = words[1:];
    } elif self.port_now > 0 and self.port_now < len(self.ports) {
        # The view last pointed at.
        which = self.port_now;
    } else {
        which = 1;
    }
    if which >= len(self.ports) {
        return True;
    }
    lens = self.ports[which].camera;
    title = self.ports[which].title.split()[0];
    if name == "ed_oblique" {
        given = band_numbers(words[:2]);
        if len(words) > 0 and words[0] == "off" {
            straight = axis_camera(title.lower());
            lens.yaw = straight.yaw;
            lens.pitch = straight.pitch;
            self.say("The " + title.lower() + " view looks along its axis again");
        } elif len(given) == 2 {
            lens.yaw = math.radians(given[0]);
            lens.pitch = math.radians(max(-89.0, min(89.0, given[1])));
            self.say("The " + title.lower() + " view looks " + str(int(given[0])) + " round and " + str(int(given[1])) + " up");
        } else {
            self.say("ed_oblique [top|front|side] <yaw> <pitch> | off (Alt and a right drag turns an axis view)");
        }
        return True;
    }
    if len(words) > 0 and words[0] == "off" {
        lens.bounded = False;
        self.say("The " + title.lower() + " view shows every depth");
        return True;
    }
    axis = lens.depth_axis();
    if len(words) > 0 and words[0] == "selection" {
        box = self.selection_box(scene);
        if box is None {
            self.say("ed_depth selection: nothing is selected");
            return True;
        }
        first = box[0].dot(axis);
        second = box[1].dot(axis);
        lens.depth_low = min(first, second) - 8.0;
        lens.depth_high = max(first, second) + 8.0;
        lens.bounded = True;
    } else {
        given = band_numbers(words[:2]);
        if len(given) != 2 or given[0] >= given[1] {
            self.say("ed_depth [top|front|side] <low> <high> | selection | off: the band of depth an axis view shows");
            return True;
        }
        lens.depth_low = given[0];
        lens.depth_high = given[1];
        lens.bounded = True;
    }
    self.say(
        "The " + title.lower() + " view shows " + str(int(round(lens.depth_low))) + " to " + str(int(round(lens.depth_high)))
            + " along " + ("x" if axis.x > 0.9 else ("y" if axis.y > 0.9 else ("z" if axis.z > 0.9 else "its line of sight")))
    );
    return True;
}
