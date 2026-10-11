"""The studio's bones for a model being edited: made and jointed, given
points to carry by weight, turned by command or by dragging an end, spread
between frames, and shown with the points they carry in their colours.
Declarations live in studio.jac."""

def:priv bone_numbers(words: list[str]) -> list[float] {
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

def:priv bone_number(value: float) -> str {
    return str(int(round(value))) if abs(value - float(round(value))) < 0.005 else str(round(value, 2));
}

def:priv bone_spot(point: Vec3) -> str {
    return bone_number(point.x) + "," + bone_number(point.y) + "," + bone_number(point.z);
}

def:priv tint_word(tint: int) -> str {
    digits = "0123456789abcdef";
    word = "";
    for place in range(6) {
        word = digits[(tint >> (place * 4)) & 15] + word;
    }
    return word;
}

def:priv tint_from(word: str) -> int {
    digits = "0123456789abcdef";
    text = word.lower().lstrip("#");
    if len(text) != 6 {
        return -1;
    }
    value = 0;
    for letter in text {
        if letter not in digits {
            return -1;
        }
        value = value * 16 + digits.index(letter);
    }
    return value;
}

impl Studio.bone_in_hand -> Bone | None {
    doc = self.model_doc;
    if doc is None {
        return None;
    }
    held = doc.bone(self.bone_now) if self.bone_now else None;
    if held is None and len(doc.bones()) > 0 {
        # With none chosen (or the chosen one gone), the last made.
        held = doc.bones()[-1];
        self.bone_now = held.name;
    }
    return held;
}

impl Studio.bone_rig_path -> str {
    doc = self.model_doc;
    return self.model_path((doc.name if doc is not None else "model") + ".rig");
}

impl Studio.bone_lines -> list[str] {
    lines: list[str] = [];
    doc = self.model_doc;
    if doc is None or len(doc.bones()) == 0 {
        return lines;
    }
    part = doc.part();
    in_hand = self.bone_in_hand();
    lines.append(
        "studio: bones " + str(len(doc.bones())) + " hand=" + (in_hand.name if in_hand is not None else "-") + " colours="
            + ("1" if self.bones_tinted else "0")
    );
    for held in doc.bones() {
        above = doc.bone_parent(held);
        at = min(doc.frame, len(held.heads) - 1);
        had = doc.grip(held, part) if part is not None else None;
        lines.append(
            "studio: bone " + held.name + " parent=" + (above.name if above is not None else "-") + " head="
                + (bone_spot(held.heads[at]) if at >= 0 else "-") + " tail=" + (bone_spot(held.tails[at]) if at >= 0 else "-")
                + " tint=" + tint_word(held.tint) + " carries=" + str(len(had.points) if had is not None else 0)
        );
    }
    return lines;
}

impl Studio.bone_event(event: UiEvent) -> bool {
    doc = self.model_doc;
    ui = self.ui;
    if doc is None or ui is None or len(doc.bones()) == 0 {
        return False;
    }
    area = ui_model_area(ui);
    through = self.model_camera;
    if event.kind == "press" and event.button == 0 {
        self.bone_held = "";
        self.bone_swept = 0.0;
        for held in doc.bones() {
            if doc.frame >= len(held.tails) {
                continue;
            }
            at = through.project(area, held.tails[doc.frame]);
            if at is not None and abs(at[0] - event.x) <= 7 and abs(at[1] - event.y) <= 7 {
                self.bone_held = held.name;
                self.bone_press_x = event.x;
                self.bone_press_y = event.y;
                # The click that ends this press is the bone's, not a pick of what lies under it.
                self.model_travel = 1000;
            }
        }
        return self.bone_held != "";
    }
    if not self.bone_held {
        return False;
    }
    taken = doc.bone(self.bone_held);
    if taken is None or doc.frame >= len(taken.heads) {
        self.bone_held = "";
        return False;
    }
    if event.kind == "drag" {
        # How far round the bone's joint the pointer has gone, as seen.
        joint = through.project(area, taken.heads[doc.frame]);
        if joint is not None {
            began = math.atan2(float(self.bone_press_y - joint[1]), float(self.bone_press_x - joint[0]));
            now = math.atan2(float(event.y - joint[1]), float(event.x - joint[0]));
            gone_round = math.degrees(now - began);
            while gone_round > 180.0 {
                gone_round -= 360.0;
            }
            while gone_round <= -180.0 {
                gone_round += 360.0;
            }
            notch = 1.0 if event.ctrl else max(1.0, self.angle_snap);
            self.bone_swept = float(round(gone_round / notch)) * notch;
        }
        return True;
    }
    if event.kind == "release" and event.button == 0 {
        name = self.bone_held;
        self.bone_held = "";
        self.bone_now = name;
        if self.bone_swept != 0.0 {
            # The view looks along the line the bone was turned about.
            doc.swing_bone(name, through.forward(), self.bone_swept);
            print("studio: bone dragged " + name + " " + bone_number(self.bone_swept));
        } else {
            print("studio: bone picked " + name);
            self.folds += 1;
        }
        self.bone_swept = 0.0;
        return True;
    }
    if event.kind == "click" and event.button == 0 {
        return True;
    }
    return False;
}

impl Studio.draw_bones {
    doc = self.model_doc;
    if doc is None or len(doc.bones()) == 0 {
        return;
    }
    tick = max(0.5, self.model_reach * 0.012);
    for held in doc.bones() {
        if doc.frame >= len(held.heads) or doc.frame >= len(held.tails) {
            continue;
        }
        head = held.heads[doc.frame];
        tail = held.tails[doc.frame];
        tone = ink(held.tint);
        wire_line(head, tail, tone);
        # A cross at the joint, a box at the end it is turned by.
        for way in [Vec3(x=tick), Vec3(y=tick), Vec3(z=tick)] {
            wire_line(head.sub(way), head.add(way), tone);
        }
        reach = tick * (1.6 if held.name == self.bone_now else 1.0);
        wire_box(
            tail.sub(Vec3(x=reach, y=reach, z=reach)), tail.add(Vec3(x=reach, y=reach, z=reach)),
            ink(0xffffff) if held.name == self.bone_now else tone
        );
        if held.name == self.bone_held and self.bone_swept != 0.0 {
            # Where the drag would leave it.
            wire_line(head, point_swung(tail, head, self.model_camera.forward(), self.bone_swept), ink(0xff7a18));
        }
    }
    part = doc.part();
    if not self.bones_tinted or part is None {
        return;
    }
    # Each point in the colours of the bones that carry it.
    spots = doc.mesh(part).points;
    for (index, tint) in enumerate(doc.point_tints(part)) {
        if index < len(spots) {
            tone = ink(tint);
            wire_line(spots[index].sub(Vec3(x=tick * 0.6)), spots[index].add(Vec3(x=tick * 0.6)), tone);
            wire_line(spots[index].sub(Vec3(y=tick * 0.6)), spots[index].add(Vec3(y=tick * 0.6)), tone);
            wire_line(spots[index].sub(Vec3(z=tick * 0.6)), spots[index].add(Vec3(z=tick * 0.6)), tone);
        }
    }
}

impl Studio.bone_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_bone" {
        return False;
    }
    doc = self.model_doc;
    if doc is None {
        self.say("No model is being edited (ed_model new <kind>, ed_model edit, ed_model open <file>)");
        return True;
    }
    how = args[1] if len(args) > 1 else "";
    part = doc.part();
    numbers = bone_numbers(args[3:]);
    if not how or how == "list" {
        for line in self.bone_lines() {
            print(line);
        }
        self.say(str(len(doc.bones())) + " bones" if len(doc.bones()) > 0 else "The model has no bones (ed_bone add <name> <head> <tail>)");
        return True;
    }
    if how == "add" and len(args) > 2 and len(numbers) >= 6 {
        above = args[9] if len(args) > 9 else "";
        made = doc.add_bone(args[2], Vec3(x=numbers[0], y=numbers[1], z=numbers[2]), Vec3(x=numbers[3], y=numbers[4], z=numbers[5]), above);
        if made is None {
            self.say("ed_bone add: a bone needs a name of its own, of one word, and a bone that is there to hang from");
        } else {
            self.bone_now = made.name;
            self.say("Bone " + made.name + (" hangs from " + above if above else ""));
        }
        return True;
    }
    if how == "chain" and len(args) > 2 and len(numbers) >= 3 {
        in_hand = self.bone_in_hand();
        made = doc.continue_bone(in_hand.name, args[2], Vec3(x=numbers[0], y=numbers[1], z=numbers[2])) if in_hand is not None else None;
        if made is None or in_hand is None {
            self.say("ed_bone chain <name> <x> <y> <z>: carries on from the bone in hand, under a name of its own");
        } else {
            self.bone_now = made.name;
            self.say("Bone " + made.name + " carries on from " + in_hand.name);
        }
        return True;
    }
    if how == "pick" and len(args) > 2 {
        if doc.bone(args[2]) is None {
            self.say("No bone " + args[2]);
        } else {
            self.bone_now = args[2];
            self.folds += 1;
            self.say("Bone " + args[2] + " in hand");
        }
        return True;
    }
    if how == "auto" {
        given = doc.hold_nearest();
        print("studio: bones took " + str(given));
        self.say("Every point given to the bone nearest it: " + str(given) if given > 0 else "The model has no bones to give points to");
        return True;
    }
    if how == "colours" or how == "colors" {
        word = args[2] if len(args) > 2 else "";
        self.bones_tinted = (not self.bones_tinted) if word not in ["on", "off"] else word == "on";
        self.say("Points are shown in their bones' colours" if self.bones_tinted else "Points are not coloured by bone");
        return True;
    }
    if how == "spread" {
        ends = bone_numbers(args[2:]);
        if len(ends) < 2 or not doc.spread_frames(int(ends[0]), int(ends[1])) {
            self.say("ed_bone spread <first frame> <last frame>: two frames with frames between them");
        } else {
            self.say("Frames " + str(int(ends[0]) + 1) + " to " + str(int(ends[1]) - 1) + " set evenly between the two");
        }
        return True;
    }
    if how == "save" or how == "load" {
        path = self.model_path(args[2]) if len(args) > 2 else self.bone_rig_path();
        try {
            if how == "save" {
                os.makedirs(os.path.dirname(path), exist_ok=True);
                with open(path, "w") as file {
                    file.write(doc.rig_text());
                }
                print("studio: saved bones " + path + " bones=" + str(len(doc.bones())));
                self.say("Saved the bones as " + path);
            } else {
                text = "";
                with open(path, "r") as file {
                    text = file.read();
                }
                print("studio: read bones " + path + " bones=" + str(doc.read_rig(text)));
                self.bone_now = "";
                self.say("Read the bones of " + path);
            }
        } except OSError {
            self.say("ed_bone " + how + ": could not " + ("write " if how == "save" else "read ") + path);
        }
        return True;
    }
    if how == "weights" {
        picked_now = part.picked_points if part is not None else [];
        for index in picked_now {
            shares = doc.point_shares(index);
            print(
                "studio: weight " + str(index) + " "
                    + (" ".join([name + ":" + bone_number(share) for (name, share) in shares]) if len(shares) > 0 else "none")
            );
        }
        self.say(str(len(picked_now)) + " picked points' weights listed" if len(picked_now) > 0 else "Pick points first (ed_pick)");
        return True;
    }
    if how == "release" {
        picked_now = part.picked_points if part is not None else [];
        whose = "" if len(args) > 2 and args[2] == "all" else self.bone_now;
        freed = doc.release_points(list(picked_now), whose);
        print("studio: bones freed " + str(freed));
        self.say(str(freed) + " points let go" if freed > 0 else "None of the picked points was carried" + (" by " + whose if whose else ""));
        return True;
    }
    in_hand = self.bone_in_hand();
    if in_hand is None {
        self.say("The model has no bones (ed_bone add <name> <head> <tail>)");
        return True;
    }
    if how == "hold" {
        picked_now = part.picked_points if part is not None else [];
        weight = bone_numbers(args[2:]);
        taken = doc.hold_points(in_hand.name, list(picked_now), weight[0] if len(weight) > 0 else 1.0);
        print("studio: bones took " + str(taken));
        self.say(in_hand.name + " carries " + str(taken) + " more points" if taken > 0 else "Pick points for the bone to carry first (ed_pick)");
    } elif how == "tint" and len(args) > 2 and tint_from(args[2]) >= 0 {
        doc.tint_bone(in_hand.name, tint_from(args[2]));
    } elif how == "turn" and len(args) > 3 and args[2] in ["x", "y", "z"] and len(numbers) > 0 {
        about = Vec3(x=1.0) if args[2] == "x" else (Vec3(y=1.0) if args[2] == "y" else Vec3(z=1.0));
        if not doc.swing_bone(in_hand.name, about, numbers[0]) {
            self.say("Nothing to turn");
        }
    } elif how == "move" and len(bone_numbers(args[2:])) >= 3 {
        gone_by = bone_numbers(args[2:]);
        if not doc.shift_bone(in_hand.name, Vec3(x=gone_by[0], y=gone_by[1], z=gone_by[2])) {
            self.say("Nothing to move");
        }
    } elif how == "end" and len(args) > 2 and args[2] in ["head", "tail"] and len(numbers) >= 3 {
        doc.set_bone_end(in_hand.name, args[2] == "tail", Vec3(x=numbers[0], y=numbers[1], z=numbers[2]), len(args) > 6 and args[6] == "all");
    } elif how == "drop" {
        gone = args[2] if len(args) > 2 else in_hand.name;
        if not doc.drop_bone(gone) {
            self.say("No bone " + gone);
        } else {
            self.bone_now = "";
            self.say("Bone " + gone + " taken away");
        }
    } else {
        self.say(
            "ed_bone [list] | add <name> <head xyz> <tail xyz> [parent] | chain <name> <tail xyz> | pick <name> | hold [weight] | release [all] | auto | weights | tint <rrggbb> | turn <x|y|z> <degrees> | move <dx dy dz> | end <head|tail> <xyz> [all] | drop [name] | spread <first> <last> | colours [on|off] | save|load [file]"
        );
    }
    return True;
}
