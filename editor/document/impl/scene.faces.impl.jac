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

impl Scene.rebuild_item(item: Item, brushes: list[list[Side]], fields: dict[str, str | None], label: str) -> bool {
    sound = [sides for sides in brushes if sides_enclose(sides)];
    if len(sound) == 0 {
        return False;
    }
    step = Step(label=label);
    for solid in self.solids_of(item) {
        gone = SolidHold(solid=solid, held=False);
        gone.redo();
        step.changes.append(gone);
    }
    for sides in sound {
        made = self.add_solid(item, sides);
        step.changes.append(SolidHold(solid=made, held=True));
    }
    for (key, value) in fields.items() {
        before = item.fields.get(key);
        if before == value {
            continue;
        }
        kept = FieldChange(item=item, key=key, before=before, after=value);
        kept.redo();
        step.changes.append(kept);
    }
    return self.commit(step);
}

impl Scene.caulk_selection(material: str = "caulk") -> int {
    chosen = self.selected_solids();
    for item in self.selection() {
        for solid in self.solids_of(item) {
            if solid not in chosen {
                chosen.append(solid);
            }
        }
    }
    if len(chosen) < 2 {
        return 0;
    }
    covered = caulked([solid.sides for solid in chosen], material);
    step = Step(label="Caulk");
    count = 0;
    for index in range(len(chosen)) {
        swapped = 0;
        for which in range(len(chosen[index].sides)) {
            if covered[index][which].material != chosen[index].sides[which].material {
                swapped += 1;
            }
        }
        if swapped == 0 {
            continue;
        }
        change = SidesChange(solid=chosen[index], before=chosen[index].sides, after=covered[index]);
        change.redo();
        step.changes.append(change);
        count += swapped;
    }
    if count > 0 {
        self.commit(step);
    }
    return count;
}

impl Scene.terrain_origin(item: Item) -> Vec3 {
    far = 1000000.0;
    low = Vec3(x=far, y=far, z=far);
    for solid in self.solids_of(item) {
        box = solid.bounds();
        if box is not None {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
        }
    }
    return low;
}

impl Scene.lift_terrain(item: Item, low: Vec3, high: Vec3, amount: float, falloff: float = 0.0) -> bool {
    grid = self.terrain_grid(item);
    if grid is None or amount == 0.0 {
        return False;
    }
    cols = int(grid[0]);
    rows = int(grid[1]);
    old = heights_from(item.fields.get("_heights", ""), cols, rows);
    if old is None {
        return False;
    }
    return self.set_heights(
        item,
        lifted(old, self.terrain_origin(item), cols, rows, grid[2], low, high, amount, falloff),
        "Lift terrain" if amount > 0.0 else "Lower terrain"
    );
}

impl Scene.set_pattern(item: Item, pattern: str) -> bool {
    grid = self.terrain_grid(item);
    if grid is None or pattern not in ["", "alt", "other"] or item.fields.get("_pattern", "") == pattern {
        return False;
    }
    cols = int(grid[0]);
    rows = int(grid[1]);
    heights = heights_from(item.fields.get("_heights", ""), cols, rows);
    owned = self.solids_of(item);
    if heights is None or len(owned) != cols * rows * 2 {
        return False;
    }
    brushes = terrain_brushes(
        self.terrain_origin(item), cols, rows, grid[2], heights, grid[3], "", [solid.sides for solid in owned], pattern
    );
    return self.rebuild_item(item, brushes, {"_pattern": pattern if pattern else None}, "Terrain pattern");
}

impl Scene.paint_terrain(item: Item, x: float, y: float, radius: float, material: str) -> int {
    if self.terrain_grid(item) is None or not material or radius <= 0.0 {
        return 0;
    }
    step = Step(label="Paint terrain");
    count = 0;
    for solid in self.solids_of(item) {
        box = solid.bounds();
        if box is None {
            continue;
        }
        middle = box[0].add(box[1]).scale(0.5);
        if math.sqrt((middle.x - x) ** 2 + (middle.y - y) ** 2) > radius {
            continue;
        }
        after: list[Side] = [];
        touched = False;
        for side in solid.sides {
            # The prism's top: the one side that faces up.
            if side.plane.normal.z > 0.1 and side.material != material {
                after.append(side_like(side, material));
                touched = True;
            } else {
                after.append(side);
            }
        }
        if touched {
            change = SidesChange(solid=solid, before=solid.sides, after=after);
            change.redo();
            step.changes.append(change);
            count += 1;
        }
    }
    if count > 0 {
        self.commit(step);
    }
    return count;
}

impl Scene.remake_patch(
    item: Item, points: list[Vec3], width: int, height: int, steps: int = 0, thickness: float = 0.0,
    label: str = "Patch"
) -> bool {
    lay = self.patch_grid(item);
    if lay is None or width < 3 or height < 3 or len(points) != width * height {
        return False;
    }
    fine = steps if steps > 0 else int(lay[2]);
    thick = thickness if thickness > 0.0 else lay[3];
    owned = self.solids_of(item);
    like: list[Side] = owned[0].sides if len(owned) > 0 else [];
    brushes = patch_brushes(points, width, height, min(16, fine), thick, "", like);
    return self.rebuild_item(
        item,
        brushes,
        {
            "_patch": str(width) + " " + str(height) + " " + str(min(16, fine)) + " " + field_number(thick),
            "_points": points_text(points)
        },
        label
    );
}

impl Scene.grow_patch(item: Item, way: str, more: bool = True) -> bool {
    lay = self.patch_grid(item);
    control = self.patch_control(item);
    if lay is None or control is None or way not in ["u", "v"] {
        return False;
    }
    width = int(lay[0]);
    height = int(lay[1]);
    made = grid_grown(control, width, height, way) if more else grid_shrunk(control, width, height, way);
    if made[0] == width and made[1] == height {
        return False;
    }
    if made[0] > 31 or made[1] > 31 {
        return False;
    }
    return self.remake_patch(item, made[2], made[0], made[1], 0, 0.0, "Grow patch" if more else "Shrink patch");
}

impl Scene.paint_face(solid: Solid, index: int, material: str) -> bool {
    if not solid.held or index < 0 or index >= len(solid.sides) or not material
        or solid.sides[index].material == material {
        return False;
    }
    after = list(solid.sides);
    after[index] = side_like(solid.sides[index], material);
    step = Step(label="Paint face");
    change = SidesChange(solid=solid, before=solid.sides, after=after);
    change.redo();
    step.changes.append(change);
    return self.commit(step);
}

impl Scene.glue_face(plane: Plane3) -> bool {
    picks = self.faces();
    if len(picks) != 1 {
        return False;
    }
    solid = picks[0].solid;
    side = solid.sides[picks[0].side];
    # The plane, facing the way the face does.
    onto = plane if side.plane.normal.dot(plane.normal) >= 0.0 else plane.flipped();
    if side.plane.normal.dot(onto.normal) > 0.99999 and abs(side.plane.dist - onto.dist) < 0.01 {
        return False;
    }
    after = list(solid.sides);
    after[picks[0].side] = side_on(side, onto);
    return self.reshape(solid, after, "Glue face");
}

impl Scene.touch_terrain(item: Item, x: float, y: float, amount: float, variance: float = 0.0) -> int {
    grid = self.terrain_grid(item);
    if grid is None or amount == 0.0 {
        return 0;
    }
    cols = int(grid[0]);
    rows = int(grid[1]);
    old = heights_from(item.fields.get("_heights", ""), cols, rows);
    if old is None {
        return 0;
    }
    near = corner_near(self.terrain_origin(item), cols, rows, grid[2], x, y);
    kin = kin_corners(old, cols, rows, near[0], near[1], variance);
    if len(kin) == 0 or not self.set_heights(item, corners_lifted(old, kin, amount), "Touch up") {
        return 0;
    }
    return len(kin);
}

impl Scene.lift_cells(item: Item, cells: list[int], amount: float) -> bool {
    grid = self.terrain_grid(item);
    if grid is None or amount == 0.0 or len(cells) == 0 {
        return False;
    }
    cols = int(grid[0]);
    rows = int(grid[1]);
    old = heights_from(item.fields.get("_heights", ""), cols, rows);
    if old is None {
        return False;
    }
    return self.set_heights(
        item, corners_lifted(old, cells_corners(cols, rows, cells), amount), "Lift cells" if amount > 0.0 else "Lower cells"
    );
}

impl Scene.move_terrain(item: Item, part: str, amount: float) -> bool {
    grid = self.terrain_grid(item);
    if grid is None or amount == 0.0 or part not in ["top", "bottom"] {
        return False;
    }
    cols = int(grid[0]);
    rows = int(grid[1]);
    old = heights_from(item.fields.get("_heights", ""), cols, rows);
    owned = self.solids_of(item);
    if old is None or len(owned) != cols * rows * 2 {
        return False;
    }
    if part == "top" {
        return self.set_heights(item, [max(0.0, height + amount) for height in old], "Move top");
    }
    # The underside goes down (or up) and the base grows (or thins) by as
    # much, so the top stays where it is.
    thick = grid[3] - amount;
    if thick < 1.0 {
        return False;
    }
    stands = self.terrain_origin(item);
    rebuilt = terrain_brushes(
        Vec3(x=stands.x, y=stands.y, z=stands.z + amount),
        cols,
        rows,
        grid[2],
        old,
        thick,
        "",
        [solid.sides for solid in owned],
        item.fields.get("_pattern", "")
    );
    told = str(cols) + " " + str(rows) + " " + item.fields.get("_terrain", "").split()[2] + " "
        + (str(int(thick)) if thick == float(int(thick)) else str(round(thick, 3)));
    return len(rebuilt) == len(owned) and self.rebuild_item(item, rebuilt, {"_terrain": told}, "Move bottom");
}
