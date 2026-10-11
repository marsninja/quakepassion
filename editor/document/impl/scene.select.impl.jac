"""The document's kept selections (sets), steps from the selection to its
kin, brushes by number and the swap. Declarations live in scene.jac."""

"""Where one of a list is, or -1."""
def:priv item_place(order: list[Item], one: Item) -> int {
    for index in range(len(order)) {
        if order[index] is one {
            return index;
        }
    }
    return -1;
}

def:priv solid_place(order: list[Solid], one: Solid) -> int {
    for index in range(len(order)) {
        if order[index] is one {
            return index;
        }
    }
    return -1;
}

impl Scene.set_items(name: str) -> list[Item] {
    return [item for item in [self->:Member:name == name:->][?:Item] if item.held];
}

impl Scene.set_solids(name: str) -> list[Solid] {
    return [solid for solid in [self->:Member:name == name:->][?:Solid] if solid.held];
}

impl Scene.layer_shown(name: str) -> bool {
    return name not in self.layers_off;
}

impl Scene.show_layer(name: str, shown: bool) -> int {
    if name not in self.set_names or shown == self.layer_shown(name) {
        return 0;
    }
    if shown {
        self.layers_off = [other for other in self.layers_off if other != name];
    } else {
        self.layers_off.append(name);
    }
    # What the layers still off hold stays out of sight.
    kept_items: list[Item] = [];
    kept_solids: list[Solid] = [];
    for other in self.layers_off {
        kept_items.extend(self.set_items(other));
        kept_solids.extend(self.set_solids(other));
    }
    count = 0;
    for item in self.set_items(name) {
        veiled = False;
        for held in kept_items {
            if held is item {
                veiled = True;
            }
        }
        if item.hidden != veiled {
            item.hidden = veiled;
            count += 1;
        }
    }
    for solid in self.set_solids(name) {
        covered = False;
        for held_solid in kept_solids {
            if held_solid is solid {
                covered = True;
            }
        }
        if solid.hidden != covered {
            solid.hidden = covered;
            count += 1;
        }
    }
    if not shown {
        # What is out of sight is not selected.
        for item in self.set_items(name) {
            if self.is_selected(item) {
                self.select(item, True);
            }
        }
        for solid in self.set_solids(name) {
            if self.is_solid_selected(solid) {
                self.select_solid(solid, True);
            }
        }
    }
    self.dirty = True;
    self.geometry += 1;
    self.revision += 1;
    return count;
}

impl Scene.only_layer(name: str) -> int {
    if name not in self.set_names {
        return 0;
    }
    count = 0;
    for other in self.set_names {
        if other != name {
            count += self.show_layer(other, False);
        }
    }
    return count + self.show_layer(name, True);
}

impl Scene.drop_set(name: str) -> bool {
    if name not in self.set_names {
        return False;
    }
    # A layer that was off shows its members again as it goes.
    self.show_layer(name, True);
    for member in [self->:Member:name == name:->] {
        self del->:Member:name == name:-> member;
    }
    self.set_names = [other for other in self.set_names if other != name];
    self.dirty = True;
    return True;
}

impl Scene.keep_set(name: str) -> int {
    entities = self.selection();
    brushes = self.selected_solids();
    if not name or len(entities) + len(brushes) == 0 {
        return 0;
    }
    self.drop_set(name);
    for item in entities {
        self +>:Member(name=name):+> item;
    }
    for solid in brushes {
        self +>:Member(name=name):+> solid;
    }
    self.set_names.append(name);
    self.dirty = True;
    return len(entities) + len(brushes);
}

impl Scene.pick_set(name: str, add: bool = False) -> int {
    entities = self.set_items(name);
    brushes = self.set_solids(name);
    if len(entities) + len(brushes) == 0 {
        return 0;
    }
    if not add {
        self.clear_selection();
    }
    for item in entities {
        if not self.is_selected(item) {
            self.select(item, True);
        }
    }
    for solid in brushes {
        if not self.is_solid_selected(solid) {
            self.select_solid(solid, True);
        }
    }
    return len(entities) + len(brushes);
}

impl Scene.set_words(name: str) -> str {
    order = self.items();
    words: list[str] = [];
    for item in self.set_items(name) {
        spot = item_place(order, item);
        if spot >= 0 {
            words.append(str(spot));
        }
    }
    for solid in self.set_solids(name) {
        holder = self.owner_of(solid);
        if holder is None {
            continue;
        }
        entity_spot = item_place(order, holder);
        brush_spot = solid_place(self.solids_of(holder), solid);
        if entity_spot >= 0 and brush_spot >= 0 {
            words.append(str(entity_spot) + ":" + str(brush_spot));
        }
    }
    return " ".join(words);
}

impl Scene.restore_set(name: str, words: str, placed: list[Item]) {
    if not name {
        return;
    }
    self.drop_set(name);
    count = 0;
    for word in words.split() {
        parts = word.split(":");
        if not parts[0].isdigit() or int(parts[0]) >= len(placed) {
            continue;
        }
        holder = placed[int(parts[0])];
        if len(parts) == 1 {
            self +>:Member(name=name):+> holder;
            count += 1;
            continue;
        }
        owned = self.solids_of(holder);
        if parts[1].isdigit() and int(parts[1]) < len(owned) {
            self +>:Member(name=name):+> owned[int(parts[1])];
            count += 1;
        }
    }
    if count > 0 {
        self.set_names.append(name);
    }
}

impl Scene.select_kin(how: str) -> int {
    entities = self.selection();
    brushes = self.selected_solids();
    if how == "parent" {
        owners: list[Item] = [];
        for solid in brushes {
            holder = self.owner_of(solid);
            if holder is not None and holder not in owners {
                owners.append(holder);
            }
        }
        if len(owners) == 0 {
            return 0;
        }
        self.clear_selection();
        for owner in owners {
            self.select(owner, True);
        }
        return len(owners);
    }
    if how == "child" {
        inside: list[Solid] = [];
        for item in entities {
            for solid in self.solids_of(item) {
                inside.append(solid);
            }
        }
        if len(inside) == 0 {
            return 0;
        }
        self.clear_selection();
        for solid in inside {
            self.select_solid(solid, True);
        }
        return len(inside);
    }
    if how not in ["next", "prev"] or len(entities) + len(brushes) != 1 {
        return 0;
    }
    pace = 1 if how == "next" else -1;
    if len(brushes) == 1 {
        keeper = self.owner_of(brushes[0]);
        if keeper is None {
            return 0;
        }
        beside = self.solids_of(keeper);
        if len(beside) < 2 {
            return 0;
        }
        self.select_solid(beside[(solid_place(beside, brushes[0]) + pace) % len(beside)]);
        return 1;
    }
    order = self.items();
    if len(order) < 2 {
        return 0;
    }
    self.select(order[(item_place(order, entities[0]) + pace) % len(order)]);
    return 1;
}

impl Scene.select_numbered(entity: int, brush: int = -1) -> bool {
    order = self.items();
    if entity < 0 or entity >= len(order) {
        return False;
    }
    if brush < 0 {
        self.select(order[entity]);
        return True;
    }
    owned = self.solids_of(order[entity]);
    if brush >= len(owned) {
        return False;
    }
    self.select_solid(owned[brush]);
    return True;
}

impl Scene.swap_selection -> bool {
    entities = self.selection();
    brushes = self.selected_solids();
    if len(entities) + len(brushes) != 2 {
        return False;
    }
    # Where each is: an entity at its origin or the middle of its brushes, a
    # brush at the middle of its box.
    spots: list[Vec3] = [];
    for item in entities {
        self.select(item);
        middle = self.selection_middle();
        if middle is not None {
            spots.append(middle);
        }
    }
    for solid in brushes {
        self.select_solid(solid);
        centre = self.selection_middle();
        if centre is not None {
            spots.append(centre);
        }
    }
    if len(spots) != 2 or spots[0].sub(spots[1]).length() == 0.0 {
        self.clear_selection();
        for item in entities {
            self.select(item, True);
        }
        for solid in brushes {
            self.select_solid(solid, True);
        }
        return False;
    }
    step = Step(label="Swap");
    turn = 0;
    for item in entities {
        self.select(item);
        self spawn Shift(delta=spots[1 - turn].sub(spots[turn]), step=step);
        turn += 1;
    }
    for solid in brushes {
        self.select_solid(solid);
        self spawn Shift(delta=spots[1 - turn].sub(spots[turn]), step=step);
        turn += 1;
    }
    self.clear_selection();
    for item in entities {
        self.select(item, True);
    }
    for solid in brushes {
        self.select_solid(solid, True);
    }
    return self.commit(step);
}

impl Scene.groups -> list[Item] {
    return [item for item in self.items() if item.classname() == "func_group"];
}

impl Scene.filtered(play: bool) -> bool {
    for item in self.items() {
        if item_switched(item, SKIP_KEY) {
            return True;
        }
        if not play and (item.hidden or item_veil(item) != "") {
            return True;
        }
    }
    if play {
        return False;
    }
    for solid in self.solids() {
        if solid.hidden {
            return True;
        }
    }
    return False;
}

impl Scene.built_map(play: bool) -> list[MapItem] {
    result: list[MapItem] = [];
    for item in self.items() {
        if item_switched(item, SKIP_KEY) {
            continue;
        }
        if not play and (item.hidden or item_veil(item) != "") {
            continue;
        }
        result.append(
            MapItem(
                fields=dict(item.fields),
                brushes=[solid.sides for solid in self.solids_of(item) if play or not solid.hidden]
            )
        );
    }
    return result;
}
