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
