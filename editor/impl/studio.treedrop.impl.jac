"""Rows carried within the side panels' lists: a brush put on the entity
that is to hold it, a favourite put before another or in the trash.
Declarations live in studio.jac."""

impl Studio.drop_taker(scene: Scene, target: str) -> Item | None {
    if target == "class:brushes" or target == "class:worldspawn" {
        return scene.world();
    }
    if target.startswith("solid:") and target[6:].isdigit() {
        # On a brush: beside it, in whatever holds it.
        beside = scene.find_solid(int(target[6:]));
        return scene.owner_of(beside) if beside is not None else None;
    }
    if target.startswith("class:") {
        # A class's heading stands for its one entity, when it has but one.
        of_class = [item for item in scene.items() if item.classname() == target[6:]];
        if len(of_class) != 1 {
            return None;
        }
        target = str(of_class[0].serial);
    }
    if not target.isdigit() {
        return None;
    }
    found = scene.find(int(target));
    if found is None {
        return None;
    }
    known = class_info(found.classname());
    if found.classname() == "worldspawn" or (known is not None and known.solid) or len(scene.solids_of(found)) > 0 {
        return found;
    }
    return None;
}

impl Studio.treedrop_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name != "ed_treedrop" and name != "ed_libdrop" {
        return False;
    }
    target = args[1] if len(args) > 1 else "";
    parts = (args[2] if len(args) > 2 else "").split(" ", 1);
    carried = parts[1] if len(parts) > 1 else "";
    if name == "ed_treedrop" {
        if parts[0] != "tree" or not carried or carried == target {
            return True;
        }
        if carried.isdigit() {
            # A group carried: onto a group to be held by it, onto the
            # groups' heading (or the world's) to be held by none.
            child = scene.find(int(carried));
            if child is not None and child.classname() == "func_group" {
                holder = scene.find(int(target)) if target.isdigit() else None;
                if holder is not None and holder.classname() == "func_group" {
                    if scene.nest([child], holder) {
                        self.opened[str(holder.serial)] = True;
                        print("studio: nested 1 in #" + str(holder.serial) + " " + holder.fields.get("_group_name", ""));
                        self.say(child.title() + " is in " + holder.title() + " now");
                    } else {
                        self.say("It is there already, or the other is in it");
                    }
                    return True;
                }
                if target in ["class:func_group", "class:brushes", "class:worldspawn"] {
                    if scene.nest([child], None) {
                        print("studio: nested 1 out");
                        self.say(child.title() + " is in no group now");
                    }
                    return True;
                }
            }
        }
        if not carried.startswith("solid:") {
            self.say("Only brushes and groups change hands in the list: an entity is not held by another");
            return True;
        }
        taker = self.drop_taker(scene, target);
        if taker is None {
            self.say("Put a brush on the entity that is to hold it (one that holds brushes), on a brush it holds, or on the brushes' heading for the world");
            return True;
        }
        handed = scene.hand_selection(taker);
        print("studio: handed brushes=" + str(handed) + " to #" + str(taker.serial) + " " + taker.classname());
        if handed == 0 {
            self.say(taker.title() + " holds it already");
            self.seen_revision = -1;
        } else {
            self.say(str(handed) + (" brush" if handed == 1 else " brushes") + " handed to " + taker.title());
        }
        return True;
    }
    if parts[0] == "library" and carried.startswith("prefab:") {
        # A prefab let go on a folder of prefabs, or on the shelf's own heading: kept there.
        into = "";
        if target.startswith("prefabdir:") {
            into = target[10:];
        } elif target.startswith("prefab:") and "/" in target[7:] {
            # On a prefab: beside it.
            into = target[7:].rsplit("/", 1)[0];
        } elif target != "shelf:Prefabs" and not target.startswith("prefab:") {
            self.say("Put a prefab on a folder of prefabs, on a prefab in one, or on Prefabs itself");
            return True;
        }
        named = carried[7:];
        # The press that began the drag added a copy, as a click does: carried about the panel, it is taken back.
        placed = scene.journal;
        if len(placed.done) > 0 and placed.done[-1].label == "Add " + named {
            scene.undo();
        }
        going = shelf_moved(named, into);
        if going != shelf_name(named) {
            return self.library_command(scene, ["ed_prefab", "move", named, going]);
        }
        return True;
    }
    if parts[0] != "library" or not carried.startswith("fav:") {
        return True;
    }
    kept_class = carried[4:];
    if target == carried {
        return True;
    }
    # The press that began the drag added one where the camera looks, as a
    # click does: carried about the panel, that was not what was meant.
    journal = scene.journal;
    if len(journal.done) > 0 and journal.done[-1].label == "New " + kept_class {
        scene.undo();
    }
    if target == "trash:fav" {
        self.favourites = [other for other in self.favourites if other != kept_class];
        print("studio: favourite dropped " + kept_class + " left=" + ",".join(self.favourites));
        self.say(kept_class + " is no longer a favourite");
    } elif target.startswith("fav:") or target == "shelf:Favourites" {
        self.favourites = moved_before(self.favourites, kept_class, target[4:] if target.startswith("fav:") else "");
        print("studio: favourites " + ",".join(self.favourites));
        self.say(kept_class + " moved among the favourites");
    } else {
        self.say("Put a favourite on another to stand before it, or in the trash to forget it");
        return True;
    }
    self.keep_settings();
    ui = self.ui;
    if ui is not None {
        ui.library.rows = [];
    }
    return True;
}

impl Studio.marked_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_marked" {
        return False;
    }
    how = args[1] if len(args) > 1 else "";
    kept = scene.find(self.marked_item) if self.marked_item >= 0 else None;
    if kept is not None and not kept.held {
        # Deleted since it was marked.
        kept = None;
    }
    if how == "set" {
        chosen = scene.selection();
        picked_brushes = scene.selected_solids();
        wanted: Item | None = chosen[0] if len(chosen) == 1 and len(picked_brushes) == 0 else None;
        if wanted is None and len(chosen) == 0 and len(picked_brushes) > 0 {
            # A brush stands for what holds it, when the selection has one holder.
            holders = [scene.owner_of(brush) for brush in picked_brushes];
            first = holders[0];
            if first is not None and len([holder for holder in holders if holder is not first]) == 0 {
                wanted = first;
            }
        }
        if wanted is None {
            self.say("Select the one entity to mark (or brushes of one entity)");
            return True;
        }
        self.marked_item = wanted.serial;
        print("studio: marked #" + str(wanted.serial) + " " + wanted.classname());
        self.say(wanted.title() + " is marked: ed_marked take hands it the selected brushes, pick selects it, swap changes places with it");
        return True;
    }
    if how == "clear" {
        self.marked_item = -1;
        self.say("Nothing is marked");
        return True;
    }
    if kept is None {
        self.marked_item = -1;
        if how in ["take", "pick", "swap"] {
            self.say("Nothing is marked: select an entity and ed_marked set");
        } elif not how {
            print("studio: marked none");
            self.say("Nothing is marked");
        } else {
            self.say("ed_marked [set|clear|take|pick|swap]");
        }
        return True;
    }
    if not how {
        print("studio: marked #" + str(kept.serial) + " " + kept.classname());
        self.say(kept.title() + " is marked");
    } elif how == "pick" {
        scene.select(kept);
        self.focus(scene, ["ed_focus"]);
    } elif how == "take" {
        if self.drop_taker(scene, str(kept.serial)) is None {
            self.say(kept.title() + " holds no brushes: it cannot take any");
            return True;
        }
        handed = scene.hand_selection(kept);
        print("studio: handed brushes=" + str(handed) + " to #" + str(kept.serial) + " " + kept.classname());
        self.say(
            str(handed) + (" brush" if handed == 1 else " brushes") + " handed to " + kept.title()
            if handed > 0
            else "Select brushes " + kept.title() + " does not hold already"
        );
    } elif how == "swap" {
        if scene.is_selected(kept) or len(scene.selection()) + len(scene.selected_solids()) != 1 {
            self.say("Select one other thing to change places with " + kept.title());
            return True;
        }
        scene.select(kept, add=True);
        if not scene.swap_selection() {
            self.say("Those two cannot change places");
        }
    } else {
        self.say("ed_marked [set|clear|take|pick|swap]");
    }
    return True;
}
