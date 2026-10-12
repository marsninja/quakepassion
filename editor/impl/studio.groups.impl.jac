"""The studio's groups: their rows in the scene tree and the switches each
keeps for itself (how it shows, whether clicks pass it by, whether builds
leave it out, the colour of its outlines). Declarations live in studio.jac."""

"""A group's switches as the tree and the list say them."""
def:priv group_marks(item: Item) -> str {
    marks: list[str] = [];
    veil = item_veil(item);
    if veil {
        marks.append("outlines" if veil == "grey" else "hidden");
    }
    if item_switched(item, LOCK_KEY) {
        marks.append("locked");
    }
    if item_switched(item, SKIP_KEY) {
        marks.append("not built");
    }
    if digs(item.fields) {
        marks.append("digs");
    }
    if duplicates(item.fields) {
        # A duplicator, and what it makes its images by.
        ways: list[str] = [];
        count = item.fields.get("_copies", "").strip();
        if count.isdigit() and int(count) > 0 {
            ways.append(count + (" copy" if count == "1" else " copies"));
        }
        if item.fields.get("_mirror", "").strip() {
            ways.append("mirrored");
        }
        if item.fields.get("_at", "").strip() {
            ways.append("at " + item.fields["_at"].strip());
        }
        if item.fields.get("_path", "").strip() {
            ways.append("along " + item.fields["_path"].strip());
        }
        marks.append("duplicator: " + " and ".join(ways) if len(ways) > 0 else "duplicator");
    }
    return "  (" + ", ".join(marks) + ")" if marks else "";
}

impl Studio.list_group(scene: Scene, rows: list[TreeRow], item: Item, picked: bool, depth: int = 1) {
    owned = scene.solids_of(item);
    inner = scene.nested(item);
    key = str(item.serial);
    shown = self.opened.get(key, False);
    veil = item_veil(item);
    rows.append(
        TreeRow(
            key=key,
            text=item.fields.get("_group_name", "group") + group_marks(item),
            depth=depth,
            branch=len(owned) > 0 or len(inner) > 0,
            opened=shown,
            picked=picked,
            # Its brushes, and the groups it holds.
            note=str(len(owned)) + (" +" + str(len(inner)) if len(inner) > 0 else ""),
            tone="dim" if veil or item_switched(item, SKIP_KEY) else "text",
            # It opens and shuts, and is carried onto another group to be held by it.
            carried=True
        )
    );
    if not shown {
        return;
    }
    for brush in owned {
        rows.append(
            TreeRow(
                key="solid:" + str(brush.serial),
                text=brush.sides[0].material if brush.sides[0].material else "(no material)",
                depth=depth + 1,
                picked=scene.is_solid_selected(brush),
                note="#" + str(brush.serial)
            )
        );
    }
    # The groups it holds, each under it as it is under its class.
    for held_group in inner {
        self.list_group(scene, rows, held_group, scene.is_selected(held_group), depth + 1);
    }
}

impl Studio.fill_group(scene: Scene, ui: StudioUi, chosen: list[Item]) {
    for item in chosen {
        if item.classname() != "func_group" {
            return;
        }
    }
    form = ui.form;
    form.adopt(Spacer(size=6));
    form.adopt(Label(text="This group", tone="dim"));
    views = Box(across=True, gap=4);
    form.adopt(views);
    views.adopt(PushButton(text="Shown", command="ed_group_view shown", grow=1, hint="Show the group whole"));
    views.adopt(
        PushButton(
            text="Outlines",
            command="ed_group_view grey",
            grow=1,
            hint="Show only the group's outlines: out of the level while editing, and out of a click's way"
        )
    );
    views.adopt(
        PushButton(text="Hidden", command="ed_group_view hidden", grow=1, hint="Do not show the group at all")
    );
    switches = Box(across=True, gap=4);
    form.adopt(switches);
    switches.adopt(
        PushButton(
            text="Unlock" if item_switched(chosen[0], LOCK_KEY) else "Lock",
            command="ed_group_lock",
            grow=1,
            hint="Whether clicks in the views can select the group"
        )
    );
    switches.adopt(
        PushButton(
            text="Build it" if item_switched(chosen[0], SKIP_KEY) else "Skip in builds",
            command="ed_group_skip",
            grow=1,
            hint="Whether the group is part of what is built and played"
        )
    );
    switches.adopt(
        PushButton(text="Its brushes", command="ed_select child", grow=1, hint="Select the group's brushes instead")
    );
}

impl Studio.group_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_nest" {
        chosen_groups = [each for each in scene.selection() if each.classname() == "func_group"];
        # Those picked whose own group is not picked with them: the rest go where they go.
        tops = scene.tops(chosen_groups);
        word = " ".join(args[1:]).strip();
        if not word {
            for each in scene.groups() {
                holder = scene.nested_in(each);
                if holder is not None {
                    print(
                        "studio: nest " + each.fields.get("_group_name", "group") + "#" + str(each.serial) + " in "
                            + holder.fields.get("_group_name", "group") + "#" + str(holder.serial)
                    );
                }
            }
            self.say("ed_nest <group's name|#number>: put the selected groups in that group | ed_nest out: take them out");
            return True;
        }
        if len(tops) == 0 {
            self.say("Select the groups to put in another (or take out) first");
            return True;
        }
        if word == "out" {
            if not scene.nest(tops, None) {
                self.say("They are in no group");
            } else {
                self.say(str(len(tops)) + (" group" if len(tops) == 1 else " groups") + " taken out");
            }
            return True;
        }
        taker: Item | None = None;
        for each in scene.groups() {
            if each in chosen_groups {
                continue;
            }
            if (word.startswith("#") and word[1:] == str(each.serial)) or each.fields.get("_group_name", "") == word {
                taker = each;
                break;
            }
        }
        if taker is None {
            self.say("There is no other group called " + word + " (ed_groups lists them)");
            return True;
        }
        if not scene.nest(tops, taker) {
            self.say("They are in " + taker.fields.get("_group_name", "it") + " already, or it is in one of them");
            return True;
        }
        self.opened[str(taker.serial)] = True;
        print("studio: nested " + str(len(tops)) + " in #" + str(taker.serial) + " " + taker.fields.get("_group_name", ""));
        self.say(str(len(tops)) + (" group" if len(tops) == 1 else " groups") + " put in " + taker.fields.get("_group_name", "group"));
        return True;
    }
    if name == "ed_groups" {
        told = [each.fields.get("_group_name", "group") + " #" + str(each.serial) + group_marks(each)
            for each in scene.groups()];
        self.say("Groups: " + ", ".join(told) if told else "There are no groups (Ctrl+G groups the selected brushes)");
        return True;
    }
    if name not in ["ed_group_view", "ed_group_lock", "ed_group_skip", "ed_group_tint"] {
        return False;
    }
    members = [item for item in scene.selection() if item.classname() == "func_group"];
    if len(members) == 0 or len(members) != len(scene.selection()) {
        self.say("Select the groups to change (from the scene list when they are hidden or locked)");
        return True;
    }
    if name == "ed_group_view" {
        how = args[1] if len(args) > 1 else "";
        if how not in ["shown", "grey", "hidden"] {
            self.say("ed_group_view <shown|grey|hidden>");
            return True;
        }
        veiled: dict[str, str | None] = {VIEW_KEY: None};
        if how != "shown" {
            veiled = {VIEW_KEY: how};
        }
        scene.set_fields(veiled, "Group view");
        self.say("Shown whole" if how == "shown" else ("Shown as outlines only" if how == "grey" else "Hidden"));
        return True;
    }
    if name == "ed_group_lock" or name == "ed_group_skip" {
        key = LOCK_KEY if name == "ed_group_lock" else SKIP_KEY;
        on = not item_switched(members[0], key);
        if len(args) > 1 and args[1] in ["on", "off", "1", "0"] {
            on = args[1] in ["on", "1"];
        }
        switched: dict[str, str | None] = {key: None};
        if on {
            switched = {key: "1"};
        }
        scene.set_fields(switched, "Group lock" if name == "ed_group_lock" else "Group build");
        if name == "ed_group_lock" {
            self.say("Clicks pass the group by" if on else "Clicks select the group again");
        } else {
            self.say("Builds leave the group out" if on else "The group is built again");
        }
        return True;
    }
    shade = [part for part in " ".join(args[1:]).split() if part.isdigit()];
    if len(args) > 1 and args[1] == "none" {
        scene.set_fields({TINT_KEY: None}, "Group colour");
        self.say("The group's outlines are as any brush's");
        return True;
    }
    if len(shade) != 3 {
        self.say("ed_group_tint <r g b|none>: 0 to 255 each");
        return True;
    }
    scene.set_fields(
        {TINT_KEY: str(min(255, int(shade[0]))) + " " + str(min(255, int(shade[1]))) + " " + str(min(255, int(shade[2])))},
        "Group colour"
    );
    self.say("The group's outlines take that colour");
    return True;
}
