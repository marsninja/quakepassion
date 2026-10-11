"""The document's entities by skill and mode, values replaced across them,
names kept apart when a map is pasted in, and the deeper logic audit.
Declarations live in scene.jac."""

"""The spawnflags bit that leaves an entity out of a skill or a mode."""
def:priv spawn_bit(mode: str) -> int {
    if mode == "easy" {
        return 256;
    }
    if mode == "normal" {
        return 512;
    }
    if mode == "hard" {
        return 1024;
    }
    return 2048 if mode == "deathmatch" else 0;
}

impl Scene.spawn_excluded(mode: str) -> list[Item] {
    out: list[Item] = [];
    bit = spawn_bit(mode);
    if bit == 0 {
        return out;
    }
    for item in self.items() {
        flags = item.fields.get("spawnflags", "0").strip();
        number = int(flags) if flags.isdigit() else 0;
        # Quake III says it in fields of its own.
        named = item.fields.get("notfree" if mode == "deathmatch" else "notsingle", "0").strip();
        if number & bit != 0 or named == "1" {
            out.append(item);
        }
    }
    return out;
}

impl Scene.spawn_preview(mode: str, before: list[Item]) -> list[Item] {
    for item in before {
        item.hidden = False;
    }
    left_out = self.spawn_excluded(mode);
    for item in left_out {
        item.hidden = True;
        if self.is_selected(item) {
            self del->:Selected:-> item;
            self.picks += 1;
        }
    }
    if len(before) > 0 or len(left_out) > 0 {
        self.geometry += 1;
        self.revision += 1;
    }
    return left_out;
}

impl Scene.replace_values(key: str, old: str, fresh: str, everywhere: bool = False) -> int {
    if not key or not old or key == "classname" {
        return 0;
    }
    step = Step(label="Replace " + key);
    count = 0;
    for item in (self.items() if everywhere else self.selection()) {
        before = item.fields.get(key);
        if before is None or old not in before {
            continue;
        }
        after = before.replace(old, fresh);
        if after == before or self.refuses(key, after) {
            continue;
        }
        change = FieldChange(item=item, key=key, before=before, after=after);
        change.redo();
        step.changes.append(change);
        count += 1;
    }
    if count > 0 {
        self.commit(step);
    }
    return count;
}

impl Scene.audit -> list[Finding] {
    found: list[Finding] = [];
    aimed: list[str] = [];
    for item in self.items() {
        for key in ["target", "killtarget", "pathtarget", "team"] {
            aim = item.fields.get(key, "");
            if aim and aim not in aimed {
                aimed.append(aim);
            }
        }
    }
    for item in self.items() {
        name = item.fields.get("targetname", "");
        if name and name not in aimed {
            found.append(Finding(words=item.title() + " waits for " + name + ", which nothing fires", item=item));
        }
    }
    return found;
}
