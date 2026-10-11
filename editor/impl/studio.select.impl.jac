"""The studio's clicks through what is in front, steps to the selection's
kin, kept sets, the tour of a selection and the swap. Declarations live in
studio.jac."""

impl Studio.aim_all(x: int, y: int) -> list[Aim] {
    front = self.aim(x, y);
    found: list[Aim] = [];
    if front.item is not None or front.solid is not None {
        found.append(front);
    }
    line = self.camera.sight(self.view_area(), x, y);
    eye = line[0];
    along = line[1];
    behind: list[Aim] = [];
    for seen in self.looks {
        if self.pick_kind == "entities" or seen.solid is front.solid or seen.dim or seen.locked
            or self.unpickable(seen.low, seen.high) or ray_enters_box(eye, along, seen.low, seen.high) < 0.0 {
            continue;
        }
        entered = ray_enters_brush(seen.solid.sides, eye, along);
        if entered[1] >= 0 and entered[0] > 0.0 {
            behind.append(Aim(solid=seen.solid, side=entered[1], reach=entered[0]));
        }
    }
    for shape in self.shapes {
        # An entity made of brushes is clicked by its brushes.
        if self.pick_kind == "brushes" or shape.item is front.item or shape.item.origin() is None
            or item_veil(shape.item) != "" or item_switched(shape.item, LOCK_KEY) {
            continue;
        }
        enters = ray_enters_box(eye, along, shape.low, shape.high);
        if enters > 0.0 {
            behind.append(Aim(item=shape.item, reach=enters));
        }
    }
    # Nearest first, after what is in front.
    while len(behind) > 0 {
        nearest = 0;
        for index in range(1, len(behind)) {
            if behind[index].reach < behind[nearest].reach {
                nearest = index;
            }
        }
        found.append(behind[nearest]);
        behind.pop(nearest);
    }
    return found;
}

impl Studio.aim_through(scene: Scene, x: int, y: int) -> Aim {
    hits = self.aim_all(x, y);
    again = abs(x - self.click_x) <= 2 and abs(y - self.click_y) <= 2 and self.port_now == self.click_port;
    if again {
        # Only while what the last click took is still what is selected:
        # a selection changed some other way starts from the front again.
        held = False;
        if self.click_solid {
            last_brush = scene.find_solid(self.click_serial);
            held = last_brush is not None and scene.is_solid_selected(last_brush);
        } else {
            last_item = scene.find(self.click_serial);
            held = last_item is not None and scene.is_selected(last_item);
        }
        again = held;
    }
    self.click_x = x;
    self.click_y = y;
    self.click_port = self.port_now;
    if len(hits) == 0 {
        self.click_turn = 0;
        self.click_serial = -1;
        return Aim();
    }
    # A click where the last one was goes one deeper, and round again.
    self.click_turn = (self.click_turn + 1) % len(hits) if again else 0;
    taken = hits[self.click_turn];
    taken_solid = taken.solid;
    taken_item = taken.item;
    self.click_solid = taken_solid is not None;
    self.click_serial = taken_solid.serial
        if taken_solid is not None
        else (taken_item.serial if taken_item is not None else -1);
    return taken;
}

impl Studio.select_more(scene: Scene, args: list[str]) -> bool {
    word = args[1];
    if word in ["parent", "child", "next", "prev"] {
        if scene.select_kin(word) == 0 {
            self.say(
                "No brush is selected to find the owner of"
                if word == "parent"
                else (
                    "No selected entity is made of brushes"
                    if word == "child"
                    else "Select one thing to step from"
                )
            );
        }
        return True;
    }
    if word == "brush" {
        places = [int(part) for part in args[2:] if part.isdigit()];
        if len(places) == 0 or not scene.select_numbered(places[0], places[1] if len(places) > 1 else -1) {
            self.say("ed_select brush <entity> [brush]: counted from 0, as the map has them");
        }
        return True;
    }
    return False;
}

impl Studio.selection_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_layer" {
        label = args[1] if len(args) > 1 else "";
        how = args[2] if len(args) > 2 else "toggle";
        if not label {
            # Every set is a layer: what each holds, and whether it shows.
            listed: list[MenuItem] = [];
            for each in scene.set_names {
                held = len(scene.set_items(each)) + len(scene.set_solids(each));
                state = "shown" if scene.layer_shown(each) else "hidden";
                print("studio: layer " + each + " " + state + " holds=" + str(held));
                listed.append(
                    MenuItem(
                        text=each + " (" + str(held) + "): " + state + ", click to " + ("hide" if state == "shown" else "show"),
                        command="ed_layer " + each
                    )
                );
            }
            board = self.stage;
            if len(listed) == 0 {
                self.say("No layers: ed_keep <name> keeps the selection as one, ed_layer <name> hides and shows it");
            } elif board is not None {
                sheet = MenuPopup(items=listed);
                sheet.open_at(board, 300, 80);
            }
            return True;
        }
        count = 0;
        if label == "all" {
            for each in list(scene.layers_off) {
                count += scene.show_layer(each, True);
            }
            self.say("Every layer shows");
        } elif label not in scene.set_names {
            self.say("ed_layer [name|all] [hide|show|only]: " + (", ".join(scene.set_names) if scene.set_names else "no sets are kept (ed_keep <name>)"));
            return True;
        } elif how == "only" {
            count = scene.only_layer(label);
            self.say("Only the layer " + label + " shows of the layers");
        } elif how in ["hide", "show", "toggle"] {
            shown = how == "show" or (how == "toggle" and not scene.layer_shown(label));
            count = scene.show_layer(label, shown);
            self.say("The layer " + label + (" shows" if shown else " is hidden"));
        } else {
            self.say("ed_layer " + label + " [hide|show|only]");
            return True;
        }
        print("studio: layered changed=" + str(count));
        return True;
    }
    if name == "ed_keep" or name == "ed_recall" or name == "ed_forget" {
        if len(args) < 2 {
            kept = [each + " (" + str(len(scene.set_items(each)) + len(scene.set_solids(each))) + ")"
                for each in scene.set_names];
            self.say(
                "Sets: " + ", ".join(kept)
                if kept
                else "No sets are kept: ed_keep <name> keeps the selection, ed_recall <name> picks it again"
            );
            return True;
        }
        label = "".join([letter for letter in args[1] if letter.isalnum() or letter in "_-"]);
        if not label {
            self.say("A set's name is letters, digits, - and _");
            return True;
        }
        if name == "ed_keep" {
            count = scene.keep_set(label);
            self.say("Kept " + str(count) + " as " + label if count else "Nothing is selected to keep");
        } elif name == "ed_forget" {
            self.say("Forgot " + label if scene.drop_set(label) else "There is no set " + label);
        } else {
            picked = scene.pick_set(label, len(args) > 2 and args[2] == "add");
            self.say("Picked " + str(picked) + " of " + label if picked else "There is nothing in a set " + label);
        }
        return True;
    }
    if name == "ed_swap" {
        if not scene.swap_selection() {
            self.say("Select two things to swap");
        }
        return True;
    }
    if name == "ed_browse" {
        entities = scene.selection();
        brushes = scene.selected_solids();
        total = len(entities) + len(brushes);
        if total == 0 {
            self.say("Nothing is selected to go through");
            return True;
        }
        pace = -1 if len(args) > 1 and args[1] == "prev" else 1;
        if self.browse_picks != scene.picks {
            # Another selection: the tour starts over.
            self.browse_picks = scene.picks;
            self.browse_turn = -1 if pace > 0 else 0;
        }
        self.browse_turn = (self.browse_turn + pace) % total;
        low = Vec3();
        high = Vec3();
        named_as = "";
        if self.browse_turn < len(entities) {
            visited = entities[self.browse_turn];
            boxed = self.shape_of(visited);
            if boxed is None {
                self.say("That one has no place to look at");
                return True;
            }
            low = boxed.low;
            high = boxed.high;
            named_as = visited.title();
        } else {
            brush = brushes[self.browse_turn - len(entities)];
            look = self.look_of(brush);
            if look is None {
                self.say("That brush is not shown");
                return True;
            }
            low = look.low;
            high = look.high;
            named_as = "brush #" + str(brush.serial);
        }
        for port in self.ports {
            port.camera.frame(low.add(high).scale(0.5), high.sub(low).length() * 0.5);
        }
        self.say(str(self.browse_turn + 1) + " of " + str(total) + ": " + named_as);
        return True;
    }
    return False;
}
