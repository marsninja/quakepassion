"""Groups that hold groups. A group says which group it is in by that
group's id (`_group_in`, `_group_id`); the Within edges are drawn from those
fields with the rest of the document's links, and a walker travels them."""

impl Scene.nested_in(item: Item) -> Item | None {
    self.links();
    for holder in [item->:Within:->] {
        if holder.held {
            return holder;
        }
    }
    return None;
}

impl Scene.nested(item: Item) -> list[Item] {
    self.links();
    return [each for each in [item<-:Within:<-] if each.held];
}

impl Scene.all_nested(item: Item) -> list[Item] {
    self.links();
    gathered = item spawn Nested();
    return gathered.found;
}

impl Scene.fresh_group_id -> str {
    taken = [each.fields.get(GROUP_ID_KEY, "") for each in self.items()];
    number = 1;
    while "g" + str(number) in taken {
        number += 1;
    }
    return "g" + str(number);
}

impl Scene.nest(children: list[Item], holder: Item | None) -> bool {
    self.links();
    step = Step(label="Nest groups" if holder is not None else "Take groups out");
    wanted: str | None = None;
    if holder is not None {
        if holder.classname() != "func_group" {
            return False;
        }
        # A group cannot be in itself, nor in one it holds.
        for child in children {
            if child is holder or holder in self.all_nested(child) {
                return False;
            }
        }
        known = holder.fields.get(GROUP_ID_KEY, "");
        if not known {
            known = self.fresh_group_id();
            named = FieldChange(item=holder, key=GROUP_ID_KEY, before=None, after=known);
            named.redo();
            step.changes.append(named);
        }
        wanted = known;
    }
    for child in children {
        if child.classname() != "func_group" {
            continue;
        }
        before = child.fields.get(GROUP_IN_KEY);
        if before == wanted {
            continue;
        }
        moved = FieldChange(item=child, key=GROUP_IN_KEY, before=before, after=wanted);
        moved.redo();
        step.changes.append(moved);
    }
    return self.commit(step);
}

impl Scene.set_field_of(item: Item, key: str, value: str | None, label: str = "Set field") -> bool {
    before = item.fields.get(key);
    if before == value {
        return False;
    }
    step = Step(label=label);
    change = FieldChange(item=item, key=key, before=before, after=value);
    change.redo();
    step.changes.append(change);
    return self.commit(step);
}

impl Scene.tops(items: list[Item]) -> list[Item] {
    found: list[Item] = [];
    for each in items {
        holder = self.nested_in(each);
        if holder is None or holder not in items {
            found.append(each);
        }
    }
    return found;
}

impl Scene.pick_nested -> int {
    added = 0;
    for item in self.selection() {
        if item.classname() != "func_group" {
            continue;
        }
        for each in self.all_nested(item) {
            if not self.is_selected(each) {
                self +>:Selected:+> each;
                added += 1;
            }
        }
    }
    if added > 0 {
        self.picks += 1;
    }
    return added;
}

impl Scene.regroup(made: list[Item]) {
    taken = [each.fields.get(GROUP_ID_KEY, "") for each in self.items() if each not in made];
    fresh: dict[str, str] = {};
    for copy in made {
        had = copy.fields.get(GROUP_ID_KEY, "");
        if not had or had not in taken {
            continue;
        }
        if had not in fresh {
            number = 1;
            while "g" + str(number) in taken {
                number += 1;
            }
            fresh[had] = "g" + str(number);
            taken.append("g" + str(number));
        }
        copy.fields[GROUP_ID_KEY] = fresh[had];
    }
    for copy in made {
        held_in = copy.fields.get(GROUP_IN_KEY, "");
        if held_in in fresh {
            copy.fields[GROUP_IN_KEY] = fresh[held_in];
        }
    }
}
