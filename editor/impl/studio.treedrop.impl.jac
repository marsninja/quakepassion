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
        if not carried.startswith("solid:") {
            self.say("Only brushes change hands in the list: an entity is not held by another");
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
