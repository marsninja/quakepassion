"""Faces linked to stay in one plane, two brushes cut to meet in a mitred
seam, and corners merged. Declarations live in scene.jac."""

"""Where a brush stands in a list of them (-1 when it is not there)."""
def:priv brush_place(order: list[Solid], one: Solid) -> int {
    for index in range(len(order)) {
        if order[index] is one {
            return index;
        }
    }
    return -1;
}

def:priv entity_place(order: list[Item], one: Item) -> int {
    for index in range(len(order)) {
        if order[index] is one {
            return index;
        }
    }
    return -1;
}

"""The middle of a brush's corners."""
def:priv corners_middle(sides: list[Side]) -> Vec3 | None {
    corners = brush_corners(sides);
    if len(corners) == 0 {
        return None;
    }
    total = Vec3();
    for corner in corners {
        total = total.add(corner);
    }
    return total.scale(1.0 / float(len(corners)));
}

impl Scene.side_in(solid: Solid, plane: Plane3) -> int {
    for index in range(len(solid.sides)) {
        if planes_meet(solid.sides[index].plane, plane) {
            return index;
        }
    }
    return -1;
}

impl Scene.linked_sides(solid: Solid, index: int) -> list[FacePick] {
    found: list[FacePick] = [];
    if index < 0 or index >= len(solid.sides) {
        return found;
    }
    # Outward from the side, a link at a time, each side met once.
    waiting: list[FacePick] = [FacePick(solid=solid, side=index)];
    turn = 0;
    while turn < len(waiting) and turn < 512 {
        base = waiting[turn].solid;
        which = waiting[turn].side;
        turn += 1;
        plane = base.sides[which].plane;
        nearby: list[FacePick] = [];
        for other in [base->:Linked:side == which:->] {
            there = self.side_in(other, plane);
            if other.held and there >= 0 {
                nearby.append(FacePick(solid=other, side=there));
            }
        }
        for source in [base<-:Linked:<-] {
            if not source.held {
                continue;
            }
            for back in range(len(source.sides)) {
                if planes_meet(source.sides[back].plane, plane) and base in [source->:Linked:side == back:->] {
                    nearby.append(FacePick(solid=source, side=back));
                }
            }
        }
        for near in nearby {
            known = False;
            for seen in waiting {
                if seen.solid is near.solid and seen.side == near.side {
                    known = True;
                }
            }
            if not known {
                waiting.append(near);
                found.append(near);
            }
        }
    }
    return found;
}

impl Scene.link_sides(first: Solid, index: int, second: Solid, other: int) -> bool {
    if first is second or index < 0 or other < 0 or index >= len(first.sides) or other >= len(second.sides) {
        return False;
    }
    if not planes_meet(first.sides[index].plane, second.sides[other].plane) {
        return False;
    }
    for tied in self.linked_sides(first, index) {
        if tied.solid is second and tied.side == other {
            return False;
        }
    }
    first +>:Linked(side=index):+> second;
    self.dirty = True;
    self.revision += 1;
    return True;
}

impl Scene.unlink_side(solid: Solid, index: int) -> int {
    if index < 0 or index >= len(solid.sides) {
        return 0;
    }
    count = 0;
    plane = solid.sides[index].plane;
    for other in [solid->:Linked:side == index:->] {
        solid del->:Linked:side == index:-> other;
        count += 1;
    }
    for source in [solid<-:Linked:<-] {
        for back in range(len(source.sides)) {
            if planes_meet(source.sides[back].plane, plane) and solid in [source->:Linked:side == back:->] {
                source del->:Linked:side == back:-> solid;
                count += 1;
            }
        }
    }
    if count > 0 {
        self.dirty = True;
        self.revision += 1;
    }
    return count;
}

impl Scene.link_faces -> int {
    chosen_faces = self.faces();
    if len(chosen_faces) < 2 {
        return 0;
    }
    count = 0;
    for pick in chosen_faces[1:] {
        if self.link_sides(chosen_faces[0].solid, chosen_faces[0].side, pick.solid, pick.side) {
            count += 1;
        }
    }
    return count;
}

impl Scene.link_coplanar(solids: list[Solid]) -> int {
    count = 0;
    for (place, first) in enumerate(solids) {
        for index in range(len(first.sides)) {
            plane = first.sides[index].plane;
            for second in solids[place + 1:] {
                for other in range(len(second.sides)) {
                    # One plane, and facing the same way: one face in pieces.
                    if planes_meet(plane, second.sides[other].plane) and plane.normal.dot(second.sides[other].plane.normal) > 0.0
                        and self.link_sides(first, index, second, other) {
                        count += 1;
                    }
                }
            }
        }
    }
    return count;
}

impl Scene.link_count -> int {
    count = 0;
    for solid in self.solids() {
        # A side at a time: two brushes may be linked on more than one side.
        for index in range(len(solid.sides)) {
            for other in [solid->:Linked:side == index:->] {
                if other.held {
                    count += 1;
                }
            }
        }
    }
    return count;
}

impl Scene.links_words -> str {
    order = self.items();
    words: list[str] = [];
    for solid in self.solids() {
        holder = self.owner_of(solid);
        if holder is None {
            continue;
        }
        for index in range(len(solid.sides)) {
            for other in [solid->:Linked:side == index:->] {
                other_holder = self.owner_of(other) if other.held else None;
                if other_holder is None {
                    continue;
                }
                words.append(
                    str(entity_place(order, holder)) + ":" + str(brush_place(self.solids_of(holder), solid)) + ":" + str(index)
                        + ">" + str(entity_place(order, other_holder)) + ":"
                        + str(brush_place(self.solids_of(other_holder), other))
                );
            }
        }
    }
    return " ".join(words);
}

impl Scene.restore_links(words: str, placed: list[Item]) {
    for word in words.split() {
        halves = word.split(">");
        if len(halves) != 2 {
            continue;
        }
        left = halves[0].split(":");
        right = halves[1].split(":");
        if len(left) != 3 or len(right) != 2 {
            continue;
        }
        numbers: list[int] = [];
        for part in left + right {
            if not part.isdigit() {
                break;
            }
            numbers.append(int(part));
        }
        if len(numbers) != 5 or numbers[0] >= len(placed) or numbers[3] >= len(placed) {
            continue;
        }
        from_owned = self.solids_of(placed[numbers[0]]);
        to_owned = self.solids_of(placed[numbers[3]]);
        if numbers[1] >= len(from_owned) or numbers[4] >= len(to_owned) or numbers[2] >= len(from_owned[numbers[1]].sides) {
            continue;
        }
        source = from_owned[numbers[1]];
        target = to_owned[numbers[4]];
        there = self.side_in(target, source.sides[numbers[2]].plane);
        if there >= 0 {
            self.link_sides(source, numbers[2], target, there);
        }
    }
}

impl Scene.miter_selection -> bool {
    chosen = self.selected_solids();
    if len(chosen) != 2 {
        return False;
    }
    # Where the two overlap, and where each one's which middle is from there.
    shared = common_sides(chosen[0].sides, chosen[1].sides);
    meeting = corners_middle(shared) if len(shared) >= 4 else None;
    first_middle = corners_middle(chosen[0].sides);
    second_middle = corners_middle(chosen[1].sides);
    if meeting is None or first_middle is None or second_middle is None {
        return False;
    }
    first_way = first_middle.sub(meeting);
    second_way = second_middle.sub(meeting);
    if first_way.length() < 0.01 or second_way.length() < 0.01 {
        return False;
    }
    across = first_way.normalized().sub(second_way.normalized());
    if across.length() < 0.01 {
        # Both run the same way from where they meet: no seam between them.
        return False;
    }
    normal = across.normalized();
    seam = Plane3(normal=normal, dist=normal.dot(meeting));
    # Each keeps the side of the seam its which middle is on.
    first_halves = clip_sides(chosen[0].sides, seam);
    second_halves = clip_sides(chosen[1].sides, seam);
    first_kept = first_halves[1];
    second_kept = second_halves[0];
    if not sides_enclose(first_kept) or not sides_enclose(second_kept) {
        return False;
    }
    step = Step(label="Miter");
    for (solid, kept) in [(chosen[0], first_kept), (chosen[1], second_kept)] {
        change = SidesChange(solid=solid, before=solid.sides, after=kept);
        change.redo();
        step.changes.append(change);
    }
    return self.commit(step);
}

impl Scene.merge_corners(solid: Solid, first: Vec3, second: Vec3) -> bool {
    delta = second.sub(first);
    if delta.length() < 0.0001 {
        return False;
    }
    sides = corners_moved(solid.sides, [first], delta);
    if len(sides) == 0 or not sides_enclose(sides) {
        return False;
    }
    return self.reshape(solid, sides, "Merge corners");
}

impl Scene.share_linked(step: Step, change: FaceEdit | None, material: str = "") {
    # What the step left each brush with, and which of their sides it touched.
    swaps: dict[int, SidesChange] = {};
    done: list[str] = [];
    touched: list[FacePick] = [];
    for made in step.changes {
        if not isinstance(made, SidesChange) {
            continue;
        }
        swaps[made.solid.serial] = made;
        for index in range(min(len(made.before), len(made.after))) {
            if made.before[index] is not made.after[index] {
                touched.append(FacePick(solid=made.solid, side=index));
                done.append(str(made.solid.serial) + ":" + str(index));
            }
        }
    }
    for pick in touched {
        for tied in self.linked_sides(pick.solid, pick.side) {
            key = str(tied.solid.serial) + ":" + str(tied.side);
            if key in done or not tied.solid.held {
                continue;
            }
            done.append(key);
            old = tied.solid.sides[tied.side];
            fresh = old;
            if change is not None {
                fresh = change.apply(old, tied.solid.outlines()[tied.side]);
            } elif material and old.material != material {
                fresh = side_like(old, material);
            }
            if fresh is old {
                continue;
            }
            held = swaps.get(tied.solid.serial);
            if held is None {
                after = list(tied.solid.sides);
                after[tied.side] = fresh;
                held = SidesChange(solid=tied.solid, before=tied.solid.sides, after=after);
                swaps[tied.solid.serial] = held;
                held.redo();
                step.changes.append(held);
            } else {
                after = list(held.after);
                after[tied.side] = fresh;
                held.after = after;
                held.redo();
            }
        }
    }
}
