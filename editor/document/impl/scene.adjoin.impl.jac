"""The document's faces that meet, its sides that make no face, and where a
kept set stands. Declarations live in scene.jac."""

impl Scene.set_mark(name: str, axis: int, how: str = "low") -> float | None {
    lows: list[float] = [];
    highs: list[float] = [];
    members = self.set_solids(name);
    for item in self.set_items(name) {
        at = item.origin();
        if at is not None {
            lows.append([at.x, at.y, at.z][axis % 3]);
            highs.append([at.x, at.y, at.z][axis % 3]);
        }
        for solid in self.solids_of(item) {
            if solid not in members {
                members.append(solid);
            }
        }
    }
    for solid in members {
        box = solid.bounds();
        if box is not None {
            lows.append([box[0].x, box[0].y, box[0].z][axis % 3]);
            highs.append([box[1].x, box[1].y, box[1].z][axis % 3]);
        }
    }
    if len(lows) == 0 {
        return None;
    }
    return min(lows) if how == "low" else (max(highs) if how == "high" else (min(lows) + max(highs)) * 0.5);
}

impl Scene.adjoin_faces -> int {
    # The faces picked now, each with its plane and its outline; those found are added to the end
    # and looked from in their turn.
    reached: list[tuple[Plane3, list[Vec3]]] = [];
    for face in self.faces() {
        outlines = face.solid.outlines();
        if face.side < len(outlines) and len(outlines[face.side]) >= 3 {
            reached.append((face.solid.sides[face.side].plane, outlines[face.side]));
        }
    }
    if len(reached) == 0 {
        return 0;
    }
    # Every other face that lies in one of those planes: only these can adjoin.
    waiting: list[tuple[Solid, int, Plane3, list[Vec3]]] = [];
    for solid in self.solids() {
        if solid.hidden {
            continue;
        }
        outlines = solid.outlines();
        for index in range(len(solid.sides)) {
            if len(outlines[index]) < 3 or self.is_face_selected(solid, index) {
                continue;
            }
            mine = solid.sides[index].plane;
            for (plane, outline) in reached {
                if mine.normal.dot(plane.normal) > 0.9999 and abs(mine.dist - plane.dist) < 0.05 {
                    waiting.append((solid, index, mine, outlines[index]));
                    break;
                }
            }
        }
    }
    count = 0;
    looked = 0;
    while looked < len(reached) {
        (plane, outline) = reached[looked];
        looked += 1;
        left: list[tuple[Solid, int, Plane3, list[Vec3]]] = [];
        for (solid, index, mine, shape) in waiting {
            if mine.normal.dot(plane.normal) > 0.9999 and abs(mine.dist - plane.dist) < 0.05 and outlines_adjoin(outline, shape) {
                self +>:Faced(side=index):+> solid;
                reached.append((mine, shape));
                count += 1;
            } else {
                left.append((solid, index, mine, shape));
            }
        }
        waiting = left;
    }
    self.picks += 1;
    return count;
}

impl Scene.beside_faces -> int {
    count = 0;
    found: list[tuple[Solid, int]] = [];
    for face in self.faces() {
        for other in faces_beside(face.solid.outlines(), face.side) {
            if not self.is_face_selected(face.solid, other) and (face.solid, other) not in found {
                found.append((face.solid, other));
            }
        }
    }
    for (solid, index) in found {
        self +>:Faced(side=index):+> solid;
        count += 1;
    }
    self.picks += 1;
    return count;
}

impl Scene.prune_sides(everywhere: bool = False) -> list[int] {
    brushes = self.solids() if everywhere else self.selected_solids();
    if not everywhere {
        for item in self.selection() {
            for solid in self.solids_of(item) {
                if solid not in brushes {
                    brushes.append(solid);
                }
            }
        }
    }
    step = Step(label="Prune sides");
    dropped = 0;
    gone = 0;
    spared = 0;
    for solid in brushes {
        used = sides_used(solid.outlines());
        if len(used) == len(solid.sides) {
            continue;
        }
        tied = False;
        for index in range(len(solid.sides)) {
            if len(self.linked_sides(solid, index)) > 0 {
                tied = True;
            }
        }
        if tied {
            # Its links go by the places of its sides, which this would shift.
            spared += 1;
            continue;
        }
        for index in self.face_sides(solid) {
            self del->:Faced:side == index:-> solid;
        }
        if len(used) < 4 {
            change = SolidHold(solid=solid, held=False);
            change.redo();
            step.changes.append(change);
            gone += 1;
            continue;
        }
        dropped += len(solid.sides) - len(used);
        kept = SidesChange(solid=solid, before=solid.sides, after=[solid.sides[index] for index in used]);
        kept.redo();
        step.changes.append(kept);
    }
    if len(step.changes) > 0 {
        self.commit(step);
    }
    return [dropped, gone, spared];
}

impl Scene.wrap_round(solid: Solid, side: int) -> int {
    if side < 0 or side >= len(solid.sides) {
        return 0;
    }
    outlines = solid.outlines();
    wanted = [index for index in self.face_sides(solid) if index != side];
    source = solid.sides[side];
    # How the material lies on each face reached so far, the given one first.
    lies: dict[int, Mapping] = {side: source.mapping};
    waiting = [side];
    while len(waiting) > 0 {
        current = waiting.pop(0);
        for other in faces_beside(outlines, current) {
            if other not in wanted or other in lies {
                continue;
            }
            carried = mapping_wrapped(lies[current], solid.sides[current].plane, solid.sides[other].plane);
            if carried is None {
                continue;
            }
            lies[other] = carried;
            waiting.append(other);
        }
    }
    after: list[Side] = [];
    count = 0;
    for (index, each) in enumerate(solid.sides) {
        if index != side and index in lies
            and (each.material != source.material or not mapping_same(each.mapping, lies[index])) {
            after.append(side_like(each, source.material, lies[index]));
            count += 1;
        } else {
            after.append(each);
        }
    }
    if count == 0 {
        return 0;
    }
    step = Step(label="Wrap material round");
    change = SidesChange(solid=solid, before=solid.sides, after=after);
    change.redo();
    step.changes.append(change);
    self.commit(step);
    return count;
}
