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
    for item in self.loops() {
        found.append(Finding(words=item.title() + " sets itself off through what it fires", item=item));
    }
    return found;
}

impl Scene.relink {
    names: dict[str, list[Item]] = {};
    members = self.items();
    for item in members {
        for other in [item->:Fires:->] {
            item del->:Fires:-> other;
        }
        name = item.fields.get("targetname", "");
        if name {
            if name not in names {
                names[name] = [];
            }
            names[name].append(item);
        }
    }
    for item in members {
        for field in ["target", "killtarget"] {
            aim = item.fields.get(field, "");
            if not aim or aim not in names {
                continue;
            }
            for other in names[aim] {
                if other is not item and other not in [item->:Fires:key == field:->] {
                    item +>:Fires(key=field):+> other;
                }
            }
        }
    }
    self.linked = self.revision;
}

impl Scene.links {
    if self.linked != self.revision {
        self.relink();
    }
}

impl Scene.fires(item: Item) -> list[Item] {
    self.links();
    return [other for other in [item->:Fires:->] if other.held];
}

impl Scene.fired_by(item: Item) -> list[Item] {
    self.links();
    return [other for other in [item<-:Fires:<-] if other.held];
}

impl Scene.reach(item: Item) -> list[Item] {
    self.links();
    found: list[Item] = [];
    for other in [item->:Fires:->] {
        traveller = other spawn Reach(seen=found);
        found = traveller.seen;
    }
    return found;
}

impl Scene.fresh_name(stem: str = "t") -> str {
    taken: list[str] = [];
    for item in self.items() {
        name = item.fields.get("targetname", "");
        if name {
            taken.append(name);
        }
    }
    number = 1;
    while stem + str(number) in taken {
        number += 1;
    }
    return stem + str(number);
}

impl Scene.link(source: Item, dest: Item) -> bool {
    if source is dest or not source.held or not dest.held {
        return False;
    }
    step = Step(label="Link");
    name = dest.fields.get("targetname", "");
    if not name {
        name = self.fresh_name();
        named = FieldChange(item=dest, key="targetname", before=None, after=name);
        named.redo();
        step.changes.append(named);
    }
    if source.fields.get("target", "") != name {
        aimed = FieldChange(item=source, key="target", before=source.fields.get("target"), after=name);
        aimed.redo();
        step.changes.append(aimed);
    }
    return self.commit(step);
}

impl Scene.unlink(source: Item, dest: Item | None = None) -> bool {
    step = Step(label="Unlink");
    name = dest.fields.get("targetname", "") if dest is not None else "";
    for key in ["target", "killtarget"] {
        aim = source.fields.get(key);
        if aim is None or (dest is not None and aim != name) {
            continue;
        }
        cut = FieldChange(item=source, key=key, before=aim, after=None);
        cut.redo();
        step.changes.append(cut);
    }
    return self.commit(step);
}

impl Scene.logic_nodes -> list[LogicNode] {
    self.links();
    linked: list[Item] = [];
    for item in self.items() {
        if len([item->:Fires:->]) > 0 or len([item<-:Fires:<-]) > 0 {
            linked.append(item);
        }
    }
    # A column further for each firing, as far as the longest chain; a loop
    # stops being followed once it is as long as the graph.
    ranks: dict[int, int] = {};
    for item in linked {
        ranks[item.serial] = 0;
    }
    limit = min(len(linked), 24);
    moved = True;
    rounds = 0;
    while moved and rounds < limit {
        moved = False;
        rounds += 1;
        for item in linked {
            for other in [item->:Fires:->] {
                if not other.held or other.serial not in ranks {
                    continue;
                }
                wanted = ranks[item.serial] + 1;
                if wanted > ranks[other.serial] and wanted < limit {
                    ranks[other.serial] = wanted;
                    moved = True;
                }
            }
        }
    }
    filled: dict[int, int] = {};
    placed: list[LogicNode] = [];
    for item in linked {
        column = ranks[item.serial];
        row = filled.get(column, 0);
        filled[column] = row + 1;
        placed.append(LogicNode(item=item, column=column, row=row));
    }
    return placed;
}

impl Scene.loops -> list[Item] {
    self.links();
    found: list[Item] = [];
    for item in self.items() {
        if len([item->:Fires:->]) > 0 and item in self.reach(item) {
            found.append(item);
        }
    }
    return found;
}

impl Scene.selection_map -> list[MapItem] {
    result: list[MapItem] = [];
    chosen = self.selection();
    loose: list[list[Side]] = [];
    for solid in self.selected_solids() {
        holder = self.owner_of(solid);
        if holder is None or holder not in chosen {
            loose.append(solid.sides);
        }
    }
    if len(loose) > 0 {
        result.append(MapItem(fields={"classname": "worldspawn"}, brushes=loose));
    }
    for item in chosen {
        if item.classname() == "worldspawn" {
            continue;
        }
        fields: dict[str, str] = dict(item.fields);
        owned = [solid.sides for solid in self.solids_of(item)];
        if len(owned) > 0 {
            fields.pop("model", None);
        }
        result.append(MapItem(fields=fields, brushes=owned));
    }
    return result;
}

impl Scene.insert_map(found: list[MapItem], offset: Vec3, label: str = "Paste", group: str = "") -> bool {
    step = Step(label=label);
    items: list[Item] = [];
    solids: list[Solid] = [];
    for read in found {
        fields: dict[str, str] = dict(read.fields);
        if fields.get("classname", "") == "worldspawn" {
            if len(read.brushes) == 0 {
                continue;
            }
            holder = self.world();
            if group {
                holder = self.add_item({"classname": "func_group", "_group_name": group});
                step.changes.append(HoldChange(item=holder, held=True));
                items.append(holder);
            }
            for sides in read.brushes {
                solid = self.add_solid(holder, [side_moved(side, offset) for side in sides]);
                step.changes.append(SolidHold(solid=solid, held=True));
                if not group {
                    solids.append(solid);
                }
            }
            continue;
        }
        at = read_vector(fields.get("origin", ""));
        if at is not None {
            fields["origin"] = write_vector(at.add(offset));
        }
        # A map's first entity says which form it is written in; that is the
        # file's business, not the entity's.
        fields.pop("mapversion", None);
        item = self.add_item(fields);
        step.changes.append(HoldChange(item=item, held=True));
        items.append(item);
        for sides in read.brushes {
            solid = self.add_solid(item, [side_moved(side, offset) for side in sides]);
            step.changes.append(SolidHold(solid=solid, held=True));
        }
    }
    if not self.commit(step) {
        return False;
    }
    self.clear_selection();
    for item in items {
        self +>:Selected:+> item;
    }
    for solid in solids {
        self +>:Selected:+> solid;
    }
    self.picks += 1;
    return True;
}

impl Scene.group_selection(name: str) -> Item | None {
    chosen = self.selected_solids();
    if len(chosen) == 0 {
        return None;
    }
    step = Step(label="Group");
    taker = self.add_item({"classname": "func_group", "_group_name": name if name else self.fresh_name("group")});
    step.changes.append(HoldChange(item=taker, held=True));
    for solid in chosen {
        giver = self.owner_of(solid);
        if giver is None {
            continue;
        }
        change = OwnChange(solid=solid, before=giver, after=taker);
        change.redo();
        step.changes.append(change);
    }
    if not self.commit(step) {
        return None;
    }
    self.clear_selection();
    self +>:Selected:+> taker;
    self.picks += 1;
    return taker;
}

impl Scene.flag_selection(bit: int, on: bool) -> bool {
    step = Step(label="Set option" if on else "Clear option");
    for item in self.selection() {
        before = item.fields.get("spawnflags");
        after = flag_put(before if before is not None else "", bit, on);
        fresh: str | None = after;
        if after == "0" {
            # No options is no field.
            fresh = None;
        }
        if fresh == before {
            continue;
        }
        change = FieldChange(item=item, key="spawnflags", before=before, after=fresh);
        change.redo();
        step.changes.append(change);
    }
    return self.commit(step);
}

impl Scene.bump_selection(key: str, delta: float, wrap: float = 0.0, fill: bool = False) -> bool {
    step = Step(label="Change " + key);
    for item in self.selection() {
        before = item.fields.get(key);
        if before is None and not fill {
            continue;
        }
        number = 0.0;
        try {
            number = float(before) if before is not None else 0.0;
        } except ValueError {
            continue;
        }
        number += delta;
        if wrap > 0.0 {
            number = number % wrap;
        }
        change = FieldChange(item=item, key=key, before=before, after=field_number(number));
        change.redo();
        step.changes.append(change);
    }
    return self.commit(step);
}

impl Scene.select_named(name: str) -> int {
    self.clear_selection();
    count = 0;
    for item in self.items() {
        if name and item.fields.get("targetname", "") == name {
            self +>:Selected:+> item;
            count += 1;
        }
    }
    self.picks += 1;
    return count;
}

impl Scene.set_fields(pairs: dict[str, str | None], label: str = "Set fields") -> bool {
    step = Step(label=label);
    for item in self.selection() {
        for (key, value) in pairs.items() {
            before = item.fields.get(key);
            if before == value {
                continue;
            }
            change = FieldChange(item=item, key=key, before=before, after=value);
            change.redo();
            step.changes.append(change);
        }
    }
    return self.commit(step);
}

impl Scene.add_brushes(owner: Item, brushes: list[list[Side]], label: str = "Add brushes") -> bool {
    step = Step(label=label);
    for sides in brushes {
        if not sides_enclose(sides) {
            continue;
        }
        solid = self.add_solid(owner, sides);
        step.changes.append(SolidHold(solid=solid, held=True));
    }
    return self.commit(step);
}

impl Scene.hide_selection -> int {
    count = 0;
    for item in self.selection() {
        item.hidden = True;
        count += 1;
    }
    for solid in self.selected_solids() {
        solid.hidden = True;
        count += 1;
    }
    if count > 0 {
        self.clear_selection();
        self.geometry += 1;
        self.revision += 1;
    }
    return count;
}

impl Scene.hide_others -> int {
    chosen = self.selection();
    solids = self.selected_solids();
    if len(chosen) == 0 and len(solids) == 0 {
        return 0;
    }
    count = 0;
    for item in self.items() {
        if item.classname() == "worldspawn" or item in chosen {
            for solid in self.solids_of(item) {
                if item.classname() == "worldspawn" and solid not in solids and not solid.hidden {
                    solid.hidden = True;
                    count += 1;
                }
            }
            continue;
        }
        owned = self.solids_of(item);
        kept = False;
        for solid in owned {
            if solid in solids {
                kept = True;
            }
        }
        if kept {
            for solid in owned {
                if solid not in solids and not solid.hidden {
                    solid.hidden = True;
                    count += 1;
                }
            }
        } elif not item.hidden {
            item.hidden = True;
            count += 1;
        }
    }
    if count > 0 {
        self.geometry += 1;
        self.revision += 1;
    }
    return count;
}

impl Scene.show_all -> int {
    count = 0;
    for item in self.items() {
        if item.hidden {
            item.hidden = False;
            count += 1;
        }
        for solid in self.solids_of(item) {
            if solid.hidden {
                solid.hidden = False;
                count += 1;
            }
        }
    }
    if count > 0 {
        self.geometry += 1;
        self.revision += 1;
    }
    return count;
}

impl Scene.hidden_count -> int {
    count = 0;
    for item in self.items() {
        if item.hidden {
            count += 1;
        }
        for solid in self.solids_of(item) {
            if solid.hidden {
                count += 1;
            }
        }
    }
    return count;
}

impl Scene.shown_map -> list[MapItem] {
    result: list[MapItem] = [];
    for item in self.items() {
        if item.hidden {
            continue;
        }
        result.append(
            MapItem(
                fields=dict(item.fields),
                brushes=[solid.sides for solid in self.solids_of(item) if not solid.hidden]
            )
        );
    }
    return result;
}

impl Scene.select_field(key: str, value: str) -> int {
    self.clear_selection();
    count = 0;
    for item in self.items() {
        if key in item.fields and (not value or item.fields[key] == value) and item.classname() != "worldspawn" {
            self +>:Selected:+> item;
            count += 1;
        }
    }
    self.picks += 1;
    return count;
}

impl Scene.terrain_grid(item: Item) -> list[float] | None {
    parts = item.fields.get("_terrain", "").split();
    if len(parts) != 4 {
        return None;
    }
    try {
        grid = [float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])];
    } except ValueError {
        return None;
    }
    if grid[0] < 1.0 or grid[1] < 1.0 or grid[2] <= 0.0 {
        return None;
    }
    return grid;
}

impl Scene.make_terrain(
    origin: Vec3, cols: int, rows: int, cell: float, material: str = "", base: float = 16.0
) -> Item | None {
    if cols < 1 or rows < 1 or cols > 64 or rows > 64 or cell < 1.0 {
        return None;
    }
    heights = flat_heights(cols, rows);
    step = Step(label="New terrain");
    item = self.add_item(
        {
            "classname": "func_group",
            "_group_name": "terrain",
            "_terrain": str(cols) + " " + str(rows) + " " + field_number(cell) + " " + field_number(base),
            "_heights": heights_text(heights)
        }
    );
    step.changes.append(HoldChange(item=item, held=True));
    for sides in terrain_brushes(origin, cols, rows, cell, heights, base, material) {
        solid = self.add_solid(item, sides);
        step.changes.append(SolidHold(solid=solid, held=True));
    }
    self.commit(step);
    self.select(item);
    return item;
}

impl Scene.set_heights(item: Item, heights: list[float], label: str = "Sculpt") -> bool {
    grid = self.terrain_grid(item);
    if grid is None {
        return False;
    }
    cols = int(grid[0]);
    rows = int(grid[1]);
    owned = self.solids_of(item);
    old = heights_from(item.fields.get("_heights", ""), cols, rows);
    if old is None or len(heights) != len(old) or len(owned) != cols * rows * 2 {
        # Its brushes were added to or taken from by hand: no longer a grid.
        return False;
    }
    # Where it stands now: the low corner of its brushes, wherever it was moved.
    far = 1000000.0;
    low = Vec3(x=far, y=far, z=far);
    for solid in owned {
        box = solid.bounds();
        if box is not None {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
        }
    }
    fresh = terrain_brushes(low, cols, rows, grid[2], heights, grid[3], "", [solid.sides for solid in owned]);
    step = Step(label=label);
    for row in range(rows) {
        for col in range(cols) {
            touched = False;
            for (dc, dr) in [(0, 0), (1, 0), (1, 1), (0, 1)] {
                index = (row + dr) * (cols + 1) + col + dc;
                if abs(old[index] - heights[index]) > 0.001 {
                    touched = True;
                }
            }
            if not touched {
                continue;
            }
            for half in range(2) {
                which = (row * cols + col) * 2 + half;
                if not sides_enclose(fresh[which]) {
                    continue;
                }
                change = SidesChange(solid=owned[which], before=owned[which].sides, after=fresh[which]);
                change.redo();
                step.changes.append(change);
            }
        }
    }
    if len(step.changes) == 0 {
        return False;
    }
    kept = FieldChange(item=item, key="_heights", before=item.fields.get("_heights"), after=heights_text(heights));
    kept.redo();
    step.changes.append(kept);
    return self.commit(step);
}

impl Scene.sculpt_terrain(
    item: Item, x: float, y: float, radius: float, amount: float, how: str = "raise"
) -> bool {
    grid = self.terrain_grid(item);
    if grid is None {
        return False;
    }
    cols = int(grid[0]);
    rows = int(grid[1]);
    old = heights_from(item.fields.get("_heights", ""), cols, rows);
    if old is None {
        return False;
    }
    far = 1000000.0;
    low = Vec3(x=far, y=far, z=far);
    for solid in self.solids_of(item) {
        box = solid.bounds();
        if box is not None {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
        }
    }
    return self.set_heights(item, sculpted(old, low, cols, rows, grid[2], x, y, radius, amount, how), "Sculpt " + how);
}

impl Scene.patch_grid(item: Item) -> list[float] | None {
    parts = item.fields.get("_patch", "").split();
    if len(parts) != 4 {
        return None;
    }
    try {
        lay = [float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])];
    } except ValueError {
        return None;
    }
    if lay[0] < 3.0 or lay[1] < 3.0 or lay[2] < 1.0 or lay[3] <= 0.0 {
        return None;
    }
    return lay;
}

impl Scene.patch_control(item: Item) -> list[Vec3] | None {
    lay = self.patch_grid(item);
    if lay is None {
        return None;
    }
    return points_from(item.fields.get("_points", ""), int(lay[0]) * int(lay[1]));
}

impl Scene.make_patch(
    points: list[Vec3], width: int, height: int, material: str = "", steps: int = 4, thickness: float = 8.0
) -> Item | None {
    brushes = patch_brushes(points, width, height, steps, thickness, material);
    if len(brushes) == 0 {
        return None;
    }
    step = Step(label="New patch");
    item = self.add_item(
        {
            "classname": "func_group",
            "_group_name": "patch",
            "_patch": str(width) + " " + str(height) + " " + str(steps) + " " + field_number(thickness),
            "_points": points_text(points)
        }
    );
    step.changes.append(HoldChange(item=item, held=True));
    for sides in brushes {
        solid = self.add_solid(item, sides);
        step.changes.append(SolidHold(solid=solid, held=True));
    }
    self.commit(step);
    self.select(item);
    return item;
}

impl Scene.set_patch(item: Item, points: list[Vec3], label: str = "Bend") -> bool {
    lay = self.patch_grid(item);
    if lay is None or len(points) != int(lay[0]) * int(lay[1]) {
        return False;
    }
    before = item.fields.get("_points", "");
    after = points_text(points);
    if before == after {
        return False;
    }
    owned = self.solids_of(item);
    like: list[Side] = owned[0].sides if len(owned) > 0 else [];
    brushes = patch_brushes(points, int(lay[0]), int(lay[1]), int(lay[2]), lay[3], "", like);
    if len(brushes) == 0 {
        return False;
    }
    step = Step(label=label);
    for solid in owned {
        gone = SolidHold(solid=solid, held=False);
        gone.redo();
        step.changes.append(gone);
    }
    for sides in brushes {
        made = self.add_solid(item, sides);
        step.changes.append(SolidHold(solid=made, held=True));
    }
    kept = FieldChange(item=item, key="_points", before=before, after=after);
    kept.redo();
    step.changes.append(kept);
    return self.commit(step);
}

impl Scene.move_patch_point(item: Item, index: int, delta: Vec3) -> bool {
    points = self.patch_control(item);
    if points is None or index < 0 or index >= len(points) or delta.length() < 0.0001 {
        return False;
    }
    moved = list(points);
    moved[index] = points[index].add(delta);
    return self.set_patch(item, moved, "Move control point");
}

impl Scene.replace_material(old: str, fresh: str, everywhere: bool = False) -> int {
    if not fresh or old == fresh {
        return 0;
    }
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
    step = Step(label="Replace " + old);
    count = 0;
    for solid in brushes {
        after: list[Side] = [];
        touched = False;
        for side in solid.sides {
            if side.material == old {
                after.append(side_like(side, fresh));
                touched = True;
                count += 1;
            } else {
                after.append(side);
            }
        }
        if touched {
            change = SidesChange(solid=solid, before=solid.sides, after=after);
            change.redo();
            step.changes.append(change);
        }
    }
    self.commit(step);
    return count;
}

impl Scene.snap_selection(size: float = 8.0) -> int {
    grid = size if size > 0.0 else 1.0;
    step = Step(label="Snap to grid");
    count = 0;
    brushes = self.selected_solids();
    for item in self.selection() {
        at = item.origin();
        if at is None {
            for solid in self.solids_of(item) {
                if solid not in brushes {
                    brushes.append(solid);
                }
            }
            continue;
        }
        snapped = Vec3(
            x=float(round(at.x / grid)) * grid, y=float(round(at.y / grid)) * grid, z=float(round(at.z / grid)) * grid
        );
        if snapped.sub(at).length() > 0.0001 {
            change = FieldChange(item=item, key="origin", before=item.fields.get("origin"), after=write_vector(snapped));
            change.redo();
            step.changes.append(change);
            count += 1;
        }
    }
    for solid in brushes {
        corners = brush_corners(solid.sides);
        moved: list[Vec3] = [];
        off = False;
        for corner in corners {
            snapped = Vec3(
                x=float(round(corner.x / grid)) * grid,
                y=float(round(corner.y / grid)) * grid,
                z=float(round(corner.z / grid)) * grid
            );
            if snapped.sub(corner).length() > 0.0001 {
                off = True;
            }
            moved.append(snapped);
        }
        if not off {
            continue;
        }
        fresh = hull_sides(moved, solid.sides);
        # Corners that fall together would leave it flat: it is left as it is.
        if not sides_enclose(fresh) {
            continue;
        }
        reshaped = SidesChange(solid=solid, before=solid.sides, after=fresh);
        reshaped.redo();
        step.changes.append(reshaped);
        count += 1;
    }
    self.commit(step);
    return count;
}

impl Scene.align_selection(axis: int, how: str = "low") -> bool {
    brushes = self.selected_solids();
    if len(brushes) < 2 or how not in ["low", "high", "middle"] {
        return False;
    }
    marks: list[float] = [];
    for solid in brushes {
        box = solid.bounds();
        if box is None {
            return False;
        }
        low = [box[0].x, box[0].y, box[0].z][axis % 3];
        high = [box[1].x, box[1].y, box[1].z][axis % 3];
        marks.append(low if how == "low" else (high if how == "high" else (low + high) * 0.5));
    }
    goal = min(marks) if how == "low" else (max(marks) if how == "high" else (min(marks) + max(marks)) * 0.5);
    step = Step(label="Align");
    for (index, solid) in enumerate(brushes) {
        gap = goal - marks[index];
        if abs(gap) < 0.0001 {
            continue;
        }
        delta = Vec3(x=gap if axis % 3 == 0 else 0.0, y=gap if axis % 3 == 1 else 0.0, z=gap if axis % 3 == 2 else 0.0);
        change = SidesChange(solid=solid, before=solid.sides, after=[side_moved(side, delta) for side in solid.sides]);
        change.redo();
        step.changes.append(change);
    }
    return self.commit(step);
}

impl Scene.pick_all_faces -> int {
    count = 0;
    brushes = [face.solid for face in self.faces()] + self.selected_solids();
    for solid in brushes {
        for index in range(len(solid.sides)) {
            if not self.is_face_selected(solid, index) {
                self +>:Faced(side=index):+> solid;
                count += 1;
            }
        }
    }
    for solid in self.selected_solids() {
        self del->:Selected:-> solid;
    }
    self.picks += 1;
    return count;
}

impl Scene.invert_faces -> int {
    count = 0;
    brushes: list[Solid] = [];
    for face in self.faces() {
        if face.solid not in brushes {
            brushes.append(face.solid);
        }
    }
    for solid in brushes {
        picked = self.face_sides(solid);
        self del->:Faced:-> solid;
        for index in range(len(solid.sides)) {
            if index not in picked {
                self +>:Faced(side=index):+> solid;
                count += 1;
            }
        }
    }
    self.picks += 1;
    return count;
}

impl Scene.extend_faces -> int {
    count = 0;
    planes = [face.solid.sides[face.side].plane for face in self.faces()];
    if len(planes) == 0 {
        return 0;
    }
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
            for plane in planes {
                if mine.normal.dot(plane.normal) > 0.9999 and abs(mine.dist - plane.dist) < 0.05 {
                    self +>:Faced(side=index):+> solid;
                    count += 1;
                    break;
                }
            }
        }
    }
    self.picks += 1;
    return count;
}

impl Scene.glue_selection(plane: Plane3) -> bool {
    brushes = self.selected_solids();
    for item in self.selection() {
        for solid in self.solids_of(item) {
            if solid not in brushes {
                brushes.append(solid);
            }
        }
    }
    step = Step(label="Glue");
    for solid in brushes {
        # The side that looks back at the plane: glued, the two faces touch.
        best = -1;
        facing = -0.5;
        for (index, side) in enumerate(solid.sides) {
            against = -side.plane.normal.dot(plane.normal);
            if against > facing {
                facing = against;
                best = index;
            }
        }
        if best < 0 {
            continue;
        }
        # How far its own face is in front of the plane, at its middle.
        outline = solid.outlines()[best];
        if len(outline) < 3 {
            continue;
        }
        middle = Vec3();
        for point in outline {
            middle = middle.add(point);
        }
        gap = plane.side(middle.scale(1.0 / float(len(outline))));
        if abs(gap) < 0.0001 {
            continue;
        }
        delta = plane.normal.scale(-gap);
        change = SidesChange(solid=solid, before=solid.sides, after=[side_moved(side, delta) for side in solid.sides]);
        change.redo();
        step.changes.append(change);
    }
    return self.commit(step);
}

impl Scene.statistics -> list[str] {
    lines: list[str] = [];
    classes: dict[str, int] = {};
    materials: dict[str, int] = {};
    brushes = 0;
    sides = 0;
    for item in self.items() {
        classes[item.classname()] = classes.get(item.classname(), 0) + 1;
        for solid in self.solids_of(item) {
            brushes += 1;
            for side in solid.sides {
                sides += 1;
                materials[side.material] = materials.get(side.material, 0) + 1;
            }
        }
    }
    lines.append(str(len(self.items())) + " entities, " + str(brushes) + " brushes, " + str(sides) + " sides");
    for name in sorted(classes.keys()) {
        lines.append("  " + str(classes[name]) + " " + name);
    }
    lines.append(str(len(materials)) + " materials");
    for name in sorted(materials.keys()) {
        lines.append("  " + str(materials[name]) + " sides of " + (name if name else "(none)"));
    }
    return lines;
}
