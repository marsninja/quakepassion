"""The studio's handles on a face for its material: a dot that slides it,
and an arm along each way it runs that stretches and swings that way, or
turns both. Declarations live in studio.jac."""

def:priv lay_number(value: float) -> str {
    return str(int(value)) if value == float(int(value)) else str(round(value, 9));
}

def:priv lay_short(value: float) -> str {
    return str(int(value)) if value == float(int(value)) else str(round(value, 3));
}

def:priv lay_spot(point: Vec3) -> str {
    return lay_short(point.x) + "," + lay_short(point.y) + "," + lay_short(point.z);
}

"""Where a line of sight meets a plane. None when it runs along it."""
def:priv sight_on(line: list[Vec3], plane: Plane3) -> Vec3 | None {
    closing = line[1].dot(plane.normal);
    if abs(closing) < 0.0001 {
        return None;
    }
    return line[0].add(line[1].scale((plane.dist - line[0].dot(plane.normal)) / closing));
}

impl Studio.lay_face(scene: Scene) -> FacePick | None {
    if self.mode != "face" or not self.lay_shown {
        return None;
    }
    picked_faces = scene.faces();
    return picked_faces[0] if len(picked_faces) == 1 else None;
}

impl Studio.lay_stand(face: FacePick) -> Vec3 | None {
    outlines = brush_windings(face.solid.sides);
    if face.side >= len(outlines) or len(outlines[face.side]) < 3 {
        return None;
    }
    total = Vec3();
    for corner in outlines[face.side] {
        total = total.add(corner);
    }
    return total.scale(1.0 / float(len(outlines[face.side])));
}

impl Studio.lay_sizes(side: Side) -> list[float] {
    image = self.materials.texture(side.material);
    return [
        float(image.width) if image.width > 0 else 64.0,
        float(image.height) if image.height > 0 else 64.0
    ];
}

impl Studio.lay_handles(scene: Scene) -> list[tuple[int, Vec3]] {
    found: list[tuple[int, Vec3]] = [];
    face = self.lay_face(scene);
    if face is None {
        return found;
    }
    side = face.solid.sides[face.side];
    stand = self.lay_stand(face);
    if stand is None {
        return found;
    }
    held = self.resize_side if self.resizing else -1;
    lie = side.mapping;
    pulled = self.lay_pull;
    if held >= 961 and held <= 962 and pulled is not None {
        # While an arm is held the arms are where the drag would leave them.
        lie = pulled;
    }
    arms = lay_arms(side.plane.normal, lie, self.lay_sizes(side)[0], self.lay_sizes(side)[1]);
    if arms is None {
        return found;
    }
    if held == 960 {
        stand = stand.add(self.corner_by);
    }
    found.append((960, stand));
    found.append((961, stand.add(arms[0])));
    found.append((962, stand.add(arms[1])));
    return found;
}

impl Studio.drag_lay(scene: Scene, x: int, y: int, free: bool) {
    face = self.lay_face(scene);
    if face is None {
        return;
    }
    side = face.solid.sides[face.side];
    stand = self.lay_stand(face);
    view = self.view_area();
    toward = sight_on(self.camera.sight(view, x, y), side.plane);
    began = sight_on(self.camera.sight(view, self.press_x, self.press_y), side.plane);
    if stand is None or toward is None or began is None {
        return;
    }
    number = self.resize_side - 960;
    notch = 1.0 if free else max(1.0, self.grid);
    if number == 0 {
        gone = toward.sub(began);
        self.corner_by = Vec3(
            x=float(round(gone.x / notch)) * notch,
            y=float(round(gone.y / notch)) * notch,
            z=float(round(gone.z / notch)) * notch
        );
        toward = stand.add(self.corner_by);
    } else {
        toward = Vec3(
            x=float(round(toward.x / notch)) * notch,
            y=float(round(toward.y / notch)) * notch,
            z=float(round(toward.z / notch)) * notch
        );
    }
    self.lay_pull = lay_dragged(
        side.plane,
        side.mapping,
        stand,
        self.lay_sizes(side),
        number,
        toward,
        "turn" if self.held_shift else "",
        0.0 if free else max(1.0, self.angle_snap)
    );
}

impl Studio.lay_words -> str {
    pulled = self.lay_pull;
    if pulled is None {
        return "";
    }
    words = "ed_texlay";
    for value in [
        pulled.s_axis.x, pulled.s_axis.y, pulled.s_axis.z, pulled.t_axis.x, pulled.t_axis.y, pulled.t_axis.z,
        pulled.s_shift, pulled.t_shift, pulled.s_scale, pulled.t_scale
    ] {
        words += " " + lay_number(value);
    }
    return words;
}

impl Studio.lay_says(scene: Scene) -> str {
    face = self.lay_face(scene);
    pulled = self.lay_pull;
    if face is None or pulled is None {
        return "";
    }
    side = face.solid.sides[face.side];
    if self.resize_side == 960 {
        return "slid " + lay_short(self.corner_by.x) + " " + lay_short(self.corner_by.y) + " " + lay_short(self.corner_by.z);
    }
    before = lay_arms(side.plane.normal, side.mapping, 64.0, 64.0);
    after = lay_arms(side.plane.normal, pulled, 64.0, 64.0);
    if before is None or after is None {
        return "";
    }
    said = "s " + lay_short(after[0].length() / 64.0) + "  t " + lay_short(after[1].length() / 64.0);
    swung = swept_between(before[self.resize_side - 961], after[self.resize_side - 961], side.plane.normal);
    if abs(swung) > 0.05 {
        said += "  swung " + lay_short(float(round(swung * 10.0)) / 10.0);
    }
    return said;
}

impl Studio.draw_lay_handles(scene: Scene, area: Rect) {
    canvas = self.canvas;
    spots: dict[int, list[int]] = {};
    for (index, spot) in self.lay_handles(scene) {
        at = self.camera.project(area, spot);
        if at is not None {
            spots[index] = at;
        }
    }
    if 960 not in spots {
        return;
    }
    held = self.resize_side if self.resizing else -1;
    middle = spots[960];
    tones = {961: ink(0x5b8def), 962: ink(0x4cc38a)};
    lowest = middle[1];
    for end in [961, 962] {
        if end not in spots {
            continue;
        }
        at = spots[end];
        lowest = max(lowest, at[1]);
        canvas.line(middle[0], middle[1], at[0], at[1], tones[end]);
        knob = Rect(x=at[0] - 5, y=at[1] - 5, w=11, h=11);
        canvas.fill(knob, canvas.theme.accent if held == end else tones[end]);
        canvas.outline(knob, canvas.theme.header);
        canvas.label(
            "s" if end == 961 else "t", Rect(x=at[0] + 8, y=at[1] - 8, w=12, h=16), canvas.theme.text, 0, 0, canvas.theme.small
        );
    }
    dot = Rect(x=middle[0] - 4, y=middle[1] - 4, w=9, h=9);
    canvas.fill(dot, canvas.theme.accent if held == 960 else canvas.theme.text);
    canvas.outline(dot, canvas.theme.header);
    words = self.lay_says(scene) if held >= 960 and held <= 962 else "";
    if words {
        wide = canvas.text_width(words, canvas.theme.small) + 8;
        tag = Rect(x=middle[0] - wide // 2, y=min(lowest + 12, area.y + area.h - 18), w=wide, h=16);
        canvas.fill(tag, canvas.theme.header.faded(210));
        canvas.label(words, tag, canvas.theme.text, 0, 0, canvas.theme.small);
    }
}

impl Studio.lay_line(scene: Scene) -> str {
    face = self.lay_face(scene);
    if face is None {
        return "";
    }
    side = face.solid.sides[face.side];
    stand = self.lay_stand(face);
    arms = lay_arms(side.plane.normal, side.mapping, self.lay_sizes(side)[0], self.lay_sizes(side)[1]);
    if stand is None or arms is None {
        return "";
    }
    return "studio: lay #" + str(face.solid.serial) + "/" + str(face.side) + " at=" + lay_spot(stand) + " s=" + lay_spot(arms[0])
        + " t=" + lay_spot(arms[1]);
}

impl Studio.lay_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_texhandles" {
        word = args[1] if len(args) > 1 else "";
        if word in ["on", "off"] {
            self.lay_shown = word == "on";
        } elif not word {
            self.lay_shown = not self.lay_shown;
        } else {
            self.say("ed_texhandles [on|off]");
            return True;
        }
        self.say(
            "A picked face shows handles for its material: the dot slides it, an arm stretches and swings one way of it (Shift turns both)"
            if self.lay_shown
            else "No handles on faces"
        );
        return True;
    }
    if name == "ed_texlay" {
        numbers: list[float] = [];
        for word in args[1:] {
            try {
                numbers.append(float(word));
            } except ValueError {
                break;
            }
        }
        picked_faces = scene.faces();
        if len(numbers) < 10 or numbers[8] == 0.0 or numbers[9] == 0.0 {
            self.say("ed_texlay <s axis: x y z> <t axis: x y z> <s shift> <t shift> <s scale> <t scale>");
            return True;
        }
        if len(picked_faces) == 0 {
            self.say("Pick the faces to lay the material on first");
            return True;
        }
        first_side = picked_faces[0].solid.sides[picked_faces[0].side];
        if len([face for face in picked_faces if face.solid.sides[face.side].material != first_side.material]) > 0 {
            self.say("Pick faces of one material: this lays it, and does not change it");
            return True;
        }
        wanted_lie = Mapping(
            s_axis=Vec3(x=numbers[0], y=numbers[1], z=numbers[2]),
            t_axis=Vec3(x=numbers[3], y=numbers[4], z=numbers[5]),
            s_shift=numbers[6],
            t_shift=numbers[7],
            s_scale=numbers[8],
            t_scale=numbers[9]
        );
        if mapping_bad(wanted_lie) {
            self.say("A material cannot lie that way: its two ways run together");
            return True;
        }
        given = Side(plane=first_side.plane, material=first_side.material, mapping=wanted_lie);
        if not scene.reface(FaceEdit(how="project", source=given), "Lay material") {
            self.say("It lies so already");
            self.seen_revision = -1;
        }
        return True;
    }
    return False;
}
