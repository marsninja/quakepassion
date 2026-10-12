"""A model's bones: made, jointed, given points to carry, posed, spread
between frames and kept as text. Declarations live in document.jac."""

def:priv rig_number(value: float) -> str {
    return str(int(value)) if value == float(int(value)) else str(round(value, 4));
}

def:priv rig_spot(point: Vec3) -> str {
    return rig_number(point.x) + " " + rig_number(point.y) + " " + rig_number(point.z);
}

impl ModelDoc.bone(name: str) -> Bone | None {
    for held in self.bones() {
        if held.name == name {
            return held;
        }
    }
    return None;
}

impl ModelDoc.bone_parent(bone: Bone) -> Bone | None {
    above = [bone<-:Jointed:<-][?:Bone];
    return above[0] if len(above) > 0 else None;
}

impl ModelDoc.bone_children(bone: Bone) -> list[Bone] {
    return [bone->:Jointed:->][?:Bone];
}

impl ModelDoc.add_bone(name: str, head: Vec3, tail: Vec3, parent: str = "") -> Bone | None {
    if not name or " " in name or self.bone(name) is not None {
        return None;
    }
    above = self.bone(parent) if parent else None;
    if parent and above is None {
        return None;
    }
    made = Bone(name=name, tint=BONE_TINTS[len(self.bones()) % len(BONE_TINTS)]);
    for index in range(max(1, self.frames())) {
        made.heads.append(head);
        made.tails.append(tail);
    }
    self +>:HasBone:+> made;
    if above is not None {
        above +>:Jointed:+> made;
    }
    self.dirty = True;
    self.revision += 1;
    return made;
}

impl ModelDoc.continue_bone(parent: str, name: str, tail: Vec3) -> Bone | None {
    above = self.bone(parent);
    if above is None or len(above.tails) == 0 {
        return None;
    }
    made = self.add_bone(name, above.tails[0], tail, parent);
    if made is None {
        return None;
    }
    # It starts, at every frame, where the bone it carries on from ends there.
    first_end = above.tails[0];
    for index in range(len(made.heads)) {
        if index < len(above.tails) {
            made.heads[index] = above.tails[index];
            made.tails[index] = tail.add(above.tails[index].sub(first_end));
        }
    }
    return made;
}

impl ModelDoc.drop_bone(name: str) -> bool {
    gone = self.bone(name);
    if gone is None {
        return False;
    }
    above = self.bone_parent(gone);
    for child in self.bone_children(gone) {
        gone del->:Jointed:-> child;
        if above is not None {
            above +>:Jointed:+> child;
        }
    }
    if above is not None {
        above del->:Jointed:-> gone;
    }
    for held in [gone->:Holds:->][?:Grip] {
        for part in [held->:GripOf:->][?:Part] {
            held del->:GripOf:-> part;
        }
        gone del->:Holds:-> held;
    }
    self del->:HasBone:-> gone;
    self.dirty = True;
    self.revision += 1;
    return True;
}

impl ModelDoc.set_bone_end(name: str, tail: bool, at: Vec3, every: bool = False) -> bool {
    held = self.bone(name);
    if held is None {
        return False;
    }
    for index in range(len(held.heads)) {
        if every or index == self.frame {
            if tail {
                held.tails[index] = at;
            } else {
                held.heads[index] = at;
            }
        }
    }
    self.dirty = True;
    self.revision += 1;
    return True;
}

impl ModelDoc.tint_bone(name: str, tint: int) -> bool {
    held = self.bone(name);
    if held is None {
        return False;
    }
    held.tint = tint & 0xffffff;
    self.revision += 1;
    return True;
}

impl ModelDoc.grip(bone: Bone, part: Part, make: bool = False) -> Grip | None {
    for held in [bone->:Holds:->][?:Grip] {
        for of_part in [held->:GripOf:->][?:Part] {
            if of_part is part {
                return held;
            }
        }
    }
    if not make {
        return None;
    }
    made = Grip();
    bone +>:Holds:+> made;
    made +>:GripOf:+> part;
    return made;
}

impl ModelDoc.hold_points(name: str, points: list[int], weight: float = 1.0) -> int {
    taker = self.bone(name);
    part = self.part();
    if taker is None or part is None {
        return 0;
    }
    count = len(self.mesh(part).points);
    wanted = [index for index in points if index >= 0 and index < count];
    if len(wanted) == 0 {
        return 0;
    }
    share = max(0.0, min(1.0, weight));
    taken = self.grip(taker, part, True);
    if taken is None {
        return 0;
    }
    fresh = grip_with(taken.points, taken.weights, wanted, share);
    taken.points = fresh[0];
    taken.weights = fresh[1];
    # What the other bones carry of these points fits in what is left of one whole.
    others: list[Grip] = [];
    for other in self.bones() {
        if other is taker {
            continue;
        }
        beside = self.grip(other, part);
        if beside is not None {
            others.append(beside);
        }
    }
    for index in wanted {
        before = [grip_share(beside.points, beside.weights, index) for beside in others];
        after = shares_beside(share, before);
        for (place, beside) in enumerate(others) {
            if before[place] > 0.0 and abs(after[place] - before[place]) > 0.0000001 {
                cut = grip_with(beside.points, beside.weights, [index], after[place]);
                beside.points = cut[0];
                beside.weights = cut[1];
            }
        }
    }
    self.dirty = True;
    self.revision += 1;
    return len(wanted);
}

impl ModelDoc.release_points(points: list[int], name: str = "") -> int {
    part = self.part();
    if part is None {
        return 0;
    }
    freed = 0;
    for held in self.bones() {
        if name and held.name != name {
            continue;
        }
        had = self.grip(held, part);
        if had is None {
            continue;
        }
        fewer = grip_without(had.points, had.weights, points);
        freed += len(had.points) - len(fewer[0]);
        had.points = fewer[0];
        had.weights = fewer[1];
    }
    if freed > 0 {
        self.dirty = True;
        self.revision += 1;
    }
    return freed;
}

impl ModelDoc.hold_nearest -> int {
    rig = self.bones();
    if len(rig) == 0 {
        return 0;
    }
    at = self.frame;
    heads = [held.heads[min(at, len(held.heads) - 1)] for held in rig if len(held.heads) > 0];
    tails = [held.tails[min(at, len(held.tails) - 1)] for held in rig if len(held.tails) > 0];
    if len(heads) != len(rig) or len(tails) != len(rig) {
        return 0;
    }
    given = 0;
    for part in self.parts() {
        nearest = nearest_bones(heads, tails, self.mesh(part).points);
        for (place, held) in enumerate(rig) {
            taken = self.grip(held, part, True);
            if taken is None {
                continue;
            }
            taken.points = [index for index in range(len(nearest)) if nearest[index] == place];
            taken.weights = [1.0 for index in taken.points];
            given += len(taken.points);
        }
    }
    self.dirty = True;
    self.revision += 1;
    return given;
}

impl ModelDoc.point_shares(point: int) -> list[tuple[str, float]] {
    found: list[tuple[str, float]] = [];
    part = self.part();
    if part is None {
        return found;
    }
    for held in self.bones() {
        had = self.grip(held, part);
        if had is None {
            continue;
        }
        share = grip_share(had.points, had.weights, point);
        if share > 0.0 {
            found.append((held.name, share));
        }
    }
    return found;
}

impl ModelDoc.point_tints(part: Part, plain: int = 0x9a9a9a) -> list[int] {
    count = len(self.mesh(part).points);
    tints: list[list[int]] = [[] for index in range(count)];
    shares: list[list[float]] = [[] for index in range(count)];
    for held in self.bones() {
        had = self.grip(held, part);
        if had is None {
            continue;
        }
        for (place, index) in enumerate(had.points) {
            if index >= 0 and index < count {
                tints[index].append(held.tint);
                shares[index].append(had.weights[place] if place < len(had.weights) else 1.0);
            }
        }
    }
    return [tint_mixed(tints[index], shares[index], plain) for index in range(count)];
}

impl ModelDoc.rig_states -> list[BoneState] {
    return [BoneState(bone=held, heads=list(held.heads), tails=list(held.tails)) for held in self.bones()];
}

impl ModelDoc.keep_pose(label: str, parts_before: list[PartState], bones_before: list[BoneState]) -> bool {
    held = self.parts();
    steps: list[ModelStep] = [];
    for (index, part) in enumerate(held) {
        if index >= len(parts_before) {
            break;
        }
        now = self.state(part);
        if now.poses != parts_before[index].poses {
            steps.append(ModelStep(label=label, part=part, before=parts_before[index], after=now));
        }
    }
    bones_after = self.rig_states();
    moved = False;
    for (index, kept) in enumerate(bones_before) {
        if index < len(bones_after) and (kept.heads != bones_after[index].heads or kept.tails != bones_after[index].tails) {
            moved = True;
        }
    }
    if len(steps) == 0 and not moved {
        return False;
    }
    if len(steps) == 0 and len(held) > 0 {
        # Only bones moved: the step still names a part, which it leaves as it is.
        same = self.state(held[0]);
        steps.append(ModelStep(label=label, part=held[0], before=same, after=same));
    }
    if len(steps) == 0 {
        return False;
    }
    whole = steps[0];
    whole.rest = steps[1:];
    whole.bones_before = bones_before;
    whole.bones_after = bones_after;
    self.done.append(whole);
    if len(self.done) > self.limit {
        self.done = self.done[1:];
    }
    self.undone = [];
    self.dirty = True;
    self.revision += 1;
    return True;
}

impl ModelDoc.swing_bone(name: str, axis: Vec3, degrees: float) -> bool {
    turned = self.bone(name);
    if turned is None or degrees == 0.0 or axis.length() < 0.000001 or self.frame >= len(turned.heads) {
        return False;
    }
    parts_before = [self.state(part) for part in self.parts()];
    bones_before = self.rig_states();
    tool = Swing(frame=self.frame, pivot=turned.heads[self.frame], axis=axis, degrees=degrees);
    turned spawn tool;
    for (place, part) in enumerate(tool.carried) {
        stood = self.poses(part);
        if self.frame >= len(stood) {
            continue;
        }
        held = [index for index in range(len(tool.shares[place])) if tool.shares[place][index] > 0.0];
        stood[self.frame].points = points_swung(
            stood[self.frame].points, held, [tool.shares[place][index] for index in held], tool.pivot, axis, degrees
        );
    }
    return self.keep_pose("Turn bone", parts_before, bones_before);
}

impl ModelDoc.shift_bone(name: str, delta: Vec3) -> bool {
    carried = self.bone(name);
    if carried is None or delta.length() < 0.000001 or self.frame >= len(carried.heads) {
        return False;
    }
    parts_before = [self.state(part) for part in self.parts()];
    bones_before = self.rig_states();
    tool = Swing(frame=self.frame, delta=delta, turning=False);
    carried spawn tool;
    for (place, part) in enumerate(tool.carried) {
        stood = self.poses(part);
        if self.frame >= len(stood) {
            continue;
        }
        held = [index for index in range(len(tool.shares[place])) if tool.shares[place][index] > 0.0];
        stood[self.frame].points = points_carried(
            stood[self.frame].points, held, [tool.shares[place][index] for index in held], delta
        );
    }
    return self.keep_pose("Move bone", parts_before, bones_before);
}

impl ModelDoc.spread_frames(first: int, last: int) -> bool {
    count = self.frames();
    if first < 0 or last >= count or last - first < 2 {
        return False;
    }
    parts_before = [self.state(part) for part in self.parts()];
    bones_before = self.rig_states();
    for part in self.parts() {
        stood = self.poses(part);
        spread = frames_spread([pose.points for pose in stood], first, last);
        for (index, pose) in enumerate(stood) {
            pose.points = spread[index];
        }
    }
    for held in self.bones() {
        # A bone's two ends go as two points do.
        if len(held.heads) == count and len(held.tails) == count {
            ends = frames_spread([[held.heads[index], held.tails[index]] for index in range(count)], first, last);
            held.heads = [pair[0] for pair in ends];
            held.tails = [pair[1] for pair in ends];
        }
    }
    return self.keep_pose("Spread frames", parts_before, bones_before);
}

impl ModelDoc.rig_text -> str {
    lines = ["// The bones of a model: each bone, where its ends are at each frame, and what it carries of each part."];
    held_parts = self.parts();
    for (number, part) in enumerate(held_parts) {
        if len(part.tints) > 0 {
            # The colours its points were given, in the points' order.
            lines.append("colours " + str(number) + " " + " ".join([tint_word(tint) for tint in part.tints]));
        }
    }
    for held in self.bones() {
        above = self.bone_parent(held);
        lines.append("bone " + held.name + " " + (above.name if above is not None else "-") + " " + str(held.tint));
        for index in range(min(len(held.heads), len(held.tails))) {
            lines.append("at " + str(index) + " " + rig_spot(held.heads[index]) + " " + rig_spot(held.tails[index]));
        }
        for (number, part) in enumerate(held_parts) {
            had = self.grip(held, part);
            if had is None or len(had.points) == 0 {
                continue;
            }
            words = "grip " + str(number);
            for (place, index) in enumerate(had.points) {
                words += " " + str(index) + ":" + rig_number(had.weights[place] if place < len(had.weights) else 1.0);
            }
            lines.append(words);
        }
    }
    return "\n".join(lines) + "\n";
}

impl ModelDoc.read_rig(text: str) -> int {
    for gone in self.bones() {
        self.drop_bone(gone.name);
    }
    held_parts = self.parts();
    count = max(1, self.frames());
    reading: Bone | None = None;
    made = 0;
    for raw in text.split("\n") {
        words = raw.strip().split();
        if len(words) == 0 or words[0].startswith("//") {
            continue;
        }
        if words[0] == "bone" and len(words) >= 3 {
            reading = self.add_bone(words[1], Vec3(), Vec3(), "" if words[2] == "-" else words[2]);
            if reading is not None {
                made += 1;
                if len(words) > 3 and words[3].isdigit() {
                    reading.tint = int(words[3]) & 0xffffff;
                }
            }
            continue;
        }
        if words[0] == "colours" and len(words) >= 3 and words[1].isdigit() and int(words[1]) < len(held_parts) {
            tinted = held_parts[int(words[1])];
            stood = self.poses(tinted);
            # Only when they are the colours of the points it has.
            if len(stood) > 0 and len(words) - 2 == len(stood[0].points) {
                tinted.tints = [word_tint(word) for word in words[2:]];
            }
            continue;
        }
        if reading is None {
            continue;
        }
        if words[0] == "at" and len(words) >= 8 and words[1].isdigit() {
            try {
                numbers = [float(word) for word in words[2:8]];
            } except ValueError {
                continue;
            }
            index = int(words[1]);
            if index < count and index < len(reading.heads) {
                reading.heads[index] = Vec3(x=numbers[0], y=numbers[1], z=numbers[2]);
                reading.tails[index] = Vec3(x=numbers[3], y=numbers[4], z=numbers[5]);
            }
        } elif words[0] == "grip" and len(words) >= 2 and words[1].isdigit() and int(words[1]) < len(held_parts) {
            taken = self.grip(reading, held_parts[int(words[1])], True);
            if taken is None {
                continue;
            }
            order: list[int] = [];
            shares: list[float] = [];
            for word in words[2:] {
                halves = word.split(":");
                if len(halves) != 2 or not halves[0].isdigit() {
                    continue;
                }
                try {
                    shares.append(max(0.0, min(1.0, float(halves[1]))));
                    order.append(int(halves[0]));
                } except ValueError {
                    continue;
                }
            }
            taken.points = order;
            taken.weights = shares;
        }
    }
    if made > 0 {
        self.dirty = True;
        self.revision += 1;
    }
    return made;
}
