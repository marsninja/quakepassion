"""The document's edits by face: faces dropped and turned, brushes stood on
faces, and the flags sides carry. Declarations live in scene.jac."""

"""A side with other contents, surface flags or value."""
def:priv side_flagged(side: Side, key: str, number: int) -> Side {
    return Side(
        plane=side.plane,
        points=side.points,
        material=side.material,
        mapping=side.mapping,
        contents=number if key == "contents" else side.contents,
        flags=number if key == "flags" else side.flags,
        value=number if key == "value" else side.value
    );
}

impl Scene.drop_faces -> int {
    step = Step(label="Delete face");
    done: list[Solid] = [];
    count = 0;
    for solid in [self->:Faced:->] {
        if not solid.held or solid in done {
            continue;
        }
        done.append(solid);
        gone = self.face_sides(solid);
        after = sides_dropped(solid.sides, gone);
        if len(after) == 0 {
            # The others do not close without it: this brush keeps its faces.
            continue;
        }
        change = SidesChange(solid=solid, before=solid.sides, after=after);
        change.redo();
        step.changes.append(change);
        count += len(gone);
    }
    if count > 0 {
        self.clear_faces();
        self.commit(step);
    }
    return count;
}

impl Scene.flip_faces -> int {
    step = Step(label="Flip face");
    done: list[Solid] = [];
    count = 0;
    for solid in [self->:Faced:->] {
        if not solid.held or solid in done {
            continue;
        }
        done.append(solid);
        picked = self.face_sides(solid);
        if len(picked) != 1 {
            # One face a brush: two turned at once seldom close anything.
            continue;
        }
        after = side_flipped(solid.sides, picked[0]);
        if len(after) == 0 {
            continue;
        }
        change = SidesChange(solid=solid, before=solid.sides, after=after);
        change.redo();
        step.changes.append(change);
        count += 1;
    }
    if count > 0 {
        self.clear_faces();
        self.commit(step);
    }
    return count;
}

impl Scene.build_on_faces(shape: str, size: float, thickness: float = 16.0) -> int {
    label = "Cone on face" if shape == "cone" else ("Extrude" if shape == "prism" else "Walls");
    step = Step(label=label);
    made: list[Solid] = [];
    for pick in self.faces() {
        outlines = pick.solid.outlines();
        if pick.side >= len(outlines) {
            continue;
        }
        face = pick.solid.sides[pick.side];
        built: list[list[Side]] = [];
        if shape == "cone" {
            built = [cone_on(outlines[pick.side], face, size)];
        } elif shape == "prism" {
            built = [prism_on(outlines[pick.side], face, size)];
        } elif shape == "walls" {
            built = walls_on(outlines[pick.side], face, size, thickness);
        }
        holder = self.owner_of(pick.solid);
        keeper = holder if holder is not None else self.world();
        for sides in built {
            if not sides_enclose(sides) {
                continue;
            }
            fresh = self.add_solid(keeper, sides);
            step.changes.append(SolidHold(solid=fresh, held=True));
            made.append(fresh);
        }
    }
    if len(made) == 0 {
        return 0;
    }
    self.commit(step);
    self.clear_faces();
    self.clear_selection();
    for fresh in made {
        self +>:Selected:+> fresh;
    }
    self.picks += 1;
    return len(made);
}

impl Scene.flag_sides(key: str, bits: int, how: str = "set") -> int {
    if key not in ["contents", "flags", "value"] or how not in ["set", "clear", "put"] {
        return 0;
    }
    faced = [solid for solid in [self->:Faced:->] if solid.held];
    targets: list[Solid] = [];
    for solid in faced {
        if solid not in targets {
            targets.append(solid);
        }
    }
    by_face = len(targets) > 0;
    if not by_face {
        targets = self.selected_solids();
        for item in self.selection() {
            for solid in self.solids_of(item) {
                if solid not in targets {
                    targets.append(solid);
                }
            }
        }
    }
    step = Step(label="Side flags");
    count = 0;
    for solid in targets {
        picked = self.face_sides(solid) if by_face else [];
        after: list[Side] = [];
        touched = 0;
        for index in range(len(solid.sides)) {
            side = solid.sides[index];
            if by_face and index not in picked {
                after.append(side);
                continue;
            }
            old = side.contents if key == "contents" else (side.flags if key == "flags" else side.value);
            number = bits;
            if how == "set" {
                number = old | bits;
            } elif how == "clear" {
                number = old - (old & bits);
            }
            if number == old {
                after.append(side);
                continue;
            }
            after.append(side_flagged(side, key, number));
            touched += 1;
        }
        if touched > 0 {
            change = SidesChange(solid=solid, before=solid.sides, after=after);
            change.redo();
            step.changes.append(change);
            count += touched;
        }
    }
    if count > 0 {
        self.commit(step);
    }
    return count;
}

impl Scene.step_face(pace: int = 1) -> bool {
    picks = self.faces();
    if len(picks) != 1 {
        return False;
    }
    solid = picks[0].solid;
    # Past sides that make no face.
    outlines = solid.outlines();
    index = picks[0].side;
    for attempt in range(len(solid.sides)) {
        index = (index + pace) % len(solid.sides);
        if index < len(outlines) and len(outlines[index]) >= 3 {
            break;
        }
    }
    self.select_face(solid, index);
    return True;
}
