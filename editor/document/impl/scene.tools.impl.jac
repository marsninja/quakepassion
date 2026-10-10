"""The document's face picks, its wider selections and its brush tools.
Declarations live in scene.jac."""

impl Scene.face_sides(solid: Solid) -> list[int] {
    found: list[int] = [];
    if solid not in [self->:Faced:->] {
        return found;
    }
    for index in range(len(solid.sides)) {
        if solid in [self->:Faced:side == index:->] {
            found.append(index);
        }
    }
    return found;
}

impl Scene.faces -> list[FacePick] {
    found: list[FacePick] = [];
    for solid in [self->:Faced:->] {
        if not solid.held {
            continue;
        }
        for index in self.face_sides(solid) {
            found.append(FacePick(solid=solid, side=index));
        }
    }
    return found;
}

impl Scene.is_face_selected(solid: Solid, index: int) -> bool {
    return solid in [self->:Faced:side == index:->];
}

impl Scene.clear_faces {
    for solid in [self->:Faced:->] {
        self del->:Faced:-> solid;
    }
    self.picks += 1;
}

impl Scene.select_face(solid: Solid, index: int, add: bool = False) {
    if index < 0 or index >= len(solid.sides) {
        return;
    }
    if not add {
        self.clear_selection();
    }
    if self.is_face_selected(solid, index) {
        if add {
            self del->:Faced:side == index:-> solid;
        }
    } else {
        self +>:Faced(side=index):+> solid;
    }
    self.picks += 1;
}

impl Scene.reface(change: FaceEdit, label: str) -> bool {
    step = Step(label=label);
    self spawn Reface(change=change, step=step);
    return self.commit(step);
}

impl Scene.select_all(kind: str = "") -> int {
    self.clear_selection();
    count = 0;
    for item in self.items() {
        if item.classname() == "worldspawn" {
            if kind != "entities" {
                for solid in self.solids_of(item) {
                    self +>:Selected:+> solid;
                    count += 1;
                }
            }
        } elif kind != "brushes" {
            self +>:Selected:+> item;
            count += 1;
        } else {
            for solid in self.solids_of(item) {
                self +>:Selected:+> solid;
                count += 1;
            }
        }
    }
    self.picks += 1;
    return count;
}

impl Scene.invert_selection -> int {
    items = self.selection();
    solids = self.selected_solids();
    self.clear_selection();
    count = 0;
    for item in self.items() {
        if item.classname() == "worldspawn" {
            for solid in self.solids_of(item) {
                if solid not in solids {
                    self +>:Selected:+> solid;
                    count += 1;
                }
            }
            continue;
        }
        if item in items {
            continue;
        }
        owned = self.solids_of(item);
        taken = False;
        for solid in owned {
            if solid in solids {
                taken = True;
            }
        }
        if taken {
            # Some of its brushes were selected: the rest are now.
            for solid in owned {
                if solid not in solids {
                    self +>:Selected:+> solid;
                    count += 1;
                }
            }
        } else {
            self +>:Selected:+> item;
            count += 1;
        }
    }
    self.picks += 1;
    return count;
}

impl Scene.select_material(material: str) -> int {
    self.clear_selection();
    count = 0;
    for solid in self.solids() {
        for side in solid.sides {
            if side.material == material {
                self +>:Selected:+> solid;
                count += 1;
                break;
            }
        }
    }
    self.picks += 1;
    return count;
}

impl Scene.stretch_selection(factors: Vec3, grid: float = 8.0, label: str = "Stretch") -> bool {
    middle = self.selection_middle();
    if middle is None or factors.x == 0.0 or factors.y == 0.0 or factors.z == 0.0 {
        return False;
    }
    if factors.x == 1.0 and factors.y == 1.0 and factors.z == 1.0 {
        return False;
    }
    step_size = grid if grid > 0.0 else 1.0;
    pivot = Vec3(
        x=float(round(middle.x / step_size)) * step_size,
        y=float(round(middle.y / step_size)) * step_size,
        z=float(round(middle.z / step_size)) * step_size
    );
    step = Step(label=label);
    self spawn Stretch(pivot=pivot, factors=factors, step=step);
    return self.commit(step);
}

impl Scene.carve_selection(lined: bool = False) -> int {
    cutters = self.selected_solids();
    for item in self.selection() {
        for solid in self.solids_of(item) {
            if solid not in cutters {
                cutters.append(solid);
            }
        }
    }
    if len(cutters) == 0 {
        return 0;
    }
    step = Step(label="Carve");
    self spawn Carve(cutters=cutters, step=step, lined=lined);
    count = len(step.changes);
    if not self.commit(step) {
        return 0;
    }
    return count;
}

impl Scene.intersect_selection -> bool {
    chosen = self.selected_solids();
    if len(chosen) < 2 {
        return False;
    }
    shared = chosen[0].sides;
    for other in chosen[1:] {
        shared = common_sides(shared, other.sides);
        if len(shared) == 0 {
            return False;
        }
    }
    step = Step(label="Intersect");
    change = SidesChange(solid=chosen[0], before=chosen[0].sides, after=shared);
    change.redo();
    step.changes.append(change);
    for other in chosen[1:] {
        gone = SolidHold(solid=other, held=False);
        gone.redo();
        step.changes.append(gone);
    }
    return self.commit(step);
}

impl Scene.hollow_selection(thickness: float) -> bool {
    step = Step(label="Hollow");
    shaper = self spawn Hollow(thickness=thickness, step=step);
    if not self.commit(step) {
        return False;
    }
    for wall in shaper.made {
        self +>:Selected:+> wall;
    }
    self.picks += 1;
    return True;
}

impl Scene.merge_selection -> bool {
    chosen = self.selected_solids();
    if len(chosen) < 2 {
        return False;
    }
    joined = chosen[0].sides;
    for other in chosen[1:] {
        joined = merged_sides(joined, other.sides);
        if len(joined) == 0 {
            return False;
        }
    }
    step = Step(label="Merge");
    change = SidesChange(solid=chosen[0], before=chosen[0].sides, after=joined);
    change.redo();
    step.changes.append(change);
    for other in chosen[1:] {
        gone = SolidHold(solid=other, held=False);
        gone.redo();
        step.changes.append(gone);
    }
    return self.commit(step);
}

impl Scene.move_corners(solid: Solid, spots: list[Vec3], delta: Vec3) -> bool {
    if delta.length() < 0.0001 {
        return False;
    }
    sides = corners_moved(solid.sides, spots, delta);
    if len(sides) == 0 {
        return False;
    }
    return self.reshape(solid, sides, "Move corner");
}

impl Scene.problems -> list[Finding] {
    looker = self spawn Inspect();
    found = looker.findings;
    if looker.worlds == 0 {
        found.append(Finding(words="There is no worldspawn", grave=True));
    } elif looker.worlds > 1 {
        found.append(Finding(words="There are " + str(looker.worlds) + " worldspawn entities"));
    }
    if looker.starts == 0 {
        found.append(Finding(words="There is no player start", grave=True));
    }
    for (item, key, aim) in looker.aims {
        if aim not in looker.names {
            found.append(Finding(words=item.title() + " has a " + key + " nothing is named: " + aim, item=item));
        }
    }
    return found;
}
