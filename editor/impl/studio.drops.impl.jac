"""Things dragged from the side panels and dropped in a view: a material on
the face under the pointer, an entity of a class where the pointer is, a
prefab resting there. The press that began the drag has already done what a
click does (taken the material in hand, added the entity or the prefab where
the camera looks); the drop puts it where it was dropped. Declarations live
in studio.jac."""

impl Studio.drop_point(scene: Scene, x: int, y: int, back: float) -> Vec3 {
    app = self.app;
    line = self.camera.sight(self.view_area(), x, y);
    start = line[0];
    along = line[1];
    far = 8192.0 if self.camera.span <= 0.0 else 40000.0;
    reach = -1.0;
    # Where the line of sight first meets a brush: not one of those being
    # dropped, which stand where the camera looks until they are put here.
    for seen in self.looks {
        holder = scene.owner_of(seen.solid);
        if scene.is_solid_selected(seen.solid) or (holder is not None and scene.is_selected(holder)) {
            continue;
        }
        if ray_enters_box(start, along, seen.low, seen.high) < 0.0 {
            continue;
        }
        entered = ray_enters_brush(seen.solid.sides, start, along);
        if entered[1] >= 0 and entered[0] > 0.0 and (reach < 0.0 or entered[0] < reach) {
            reach = entered[0];
        }
    }
    if reach < 0.0 and len(self.looks) == 0 and app is not None {
        # A shipped map has no brushes to ask: the level itself is.
        trace = app.level.collision.trace_point(start, start.add(along.scale(far)));
        if trace.fraction < 1.0 {
            reach = far * trace.fraction;
        }
    }
    if reach < 0.0 {
        # Nothing there: a little way off, or on an axis view's own middle plane.
        reach = self.camera.eye.sub(start).dot(along) if self.camera.span > 0.0 else 256.0 + back;
    }
    at = start.add(along.scale(max(0.0, reach - back)));
    step = max(1.0, self.grid);
    return Vec3(x=float(round(at.x / step)) * step, y=float(round(at.y / step)) * step, z=float(round(at.z / step)) * step);
}

impl Studio.dropped(scene: Scene, x: int, y: int, what: str) {
    parts = what.split(" ", 1);
    if len(parts) < 2 {
        return;
    }
    kind = parts[0];
    key = parts[1];
    if kind == "library" and key.startswith("fav:") {
        # A favourite is a class: the press added one, and it is put here.
        kind = "class";
        key = key[4:];
    }
    if kind == "tree" {
        # A row of the scene list, picked by the press: put where it was let go.
        chosen = scene.selection();
        if key.isdigit() and len(chosen) == 1 and str(chosen[0].serial) == key and chosen[0].origin() is not None {
            at = self.drop_point(scene, x, y, 24.0);
            words = str(int(at.x)) + " " + str(int(at.y)) + " " + str(int(at.z));
            if scene.set_fields({"origin": words}, "Place") {
                print("studio: dropped entity #" + key + " at " + words.replace(" ", ","));
                self.say(chosen[0].title() + " at " + words);
            }
            return;
        }
        if not key.startswith("solid:") and not key.isdigit() {
            return;
        }
    }
    if kind == "material" {
        under = self.aim(x, y);
        held = under.solid;
        if held is None or under.side < 0 {
            self.say("A material is dropped on a brush's face");
            return;
        }
        if scene.paint_face(held, under.side, key) {
            print("studio: dropped material " + key + " on #" + str(held.serial) + "/" + str(under.side));
            self.say(key + " on that face");
        }
        return;
    }
    if kind == "class" {
        chosen = scene.selection();
        if len(chosen) != 1 or chosen[0].classname() != key {
            return;
        }
        if chosen[0].origin() is not None {
            # A little off what it was dropped on, toward the eye.
            at = self.drop_point(scene, x, y, 24.0);
            words = str(int(at.x)) + " " + str(int(at.y)) + " " + str(int(at.z));
            if scene.set_fields({"origin": words}, "Place") {
                print("studio: dropped class " + key + " at " + words.replace(" ", ","));
                self.say(key + " at " + words);
            }
            return;
        }
    }
    if kind == "class" or kind == "tree" or (kind == "library" and key.startswith("prefab:")) {
        # Brushes: standing on the place they were dropped at.
        box = self.selection_box(scene);
        if box is None {
            return;
        }
        spot = self.drop_point(scene, x, y, 0.0);
        delta = Vec3(x=spot.x - (box[0].x + box[1].x) * 0.5, y=spot.y - (box[0].y + box[1].y) * 0.5, z=spot.z - box[0].z);
        step = max(1.0, self.grid);
        delta = Vec3(x=float(round(delta.x / step)) * step, y=float(round(delta.y / step)) * step, z=float(round(delta.z / step)) * step);
        if scene.shift_selection(delta, self.tex_lock) {
            print(
                "studio: dropped " + ("class " + key if kind == "class" else ("row " + key if kind == "tree" else "prefab " + key[7:]))
                    + " at " + str(int(spot.x)) + ","
                    + str(int(spot.y)) + "," + str(int(spot.z))
            );
            self.say("Put where it was dropped");
        }
    }
}
