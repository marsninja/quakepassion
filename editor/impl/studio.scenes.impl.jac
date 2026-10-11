"""The studio's scenes of brushes: building them into levels, opening and
saving them as maps, and drawing, picking and reshaping their brushes.
Declarations live in studio.jac."""

impl Studio.is_built_scene -> bool {
    scene = self.scene;
    return scene is not None and scene.name.startswith("studio:");
}

impl Studio.build_level(game: str, name: str) -> Bsp | None {
    if not name.startswith("studio:") {
        return None;
    }
    scene = self.scenes.get(game + "/" + name);
    if scene is None {
        return None;
    }
    began = time.time();
    source = scene;
    if self.play_only {
        # Only what is selected, in a world of its own.
        alone = scene.selection_map();
        if len(alone) == 0 or alone[0].fields.get("classname", "") != "worldspawn" {
            alone = [MapItem(fields={"classname": "worldspawn"}, brushes=[])] + alone;
        }
        source = scene_from_map(scene.game, scene.name, MapFile(items=alone));
    } elif scene.filtered(self.play_build) {
        # What builds are told to skip is left out; while editing, so is
        # what is hidden or shown as outlines only.
        source = scene_from_map(scene.game, scene.name, MapFile(items=scene.built_map(self.play_build)));
    }
    whole = self.expanded(source);
    made = compile_scene(whole, self.materials);
    self.lit_samples = bake_light(whole, made, self.luxel) if self.lit else 0;
    self.live = made;
    self.build_ms = int((time.time() - began) * 1000.0);
    self.built_geometry = scene.geometry;
    started = False;
    for entity in made.bsp.entities {
        if entity.fields.get("classname", "") == "info_player_start" {
            started = True;
        }
    }
    if not started {
        # A scene still being laid out is looked at from somewhere.
        made.bsp.entities.append(
            MapEntity(fields={"classname": "info_player_start", "origin": "0 0 64"})
        );
    }
    return made.bsp;
}

impl Studio.scene_path(name: str) -> str {
    folder = os.getenv("QP_SCENES", "");
    if not folder {
        folder = os.getcwd() + "/scenes";
    }
    return folder + "/" + name.replace("/", "_") + ".map";
}

impl Studio.new_scene(name: str) {
    scene = Scene(game="passion", name="studio:" + name);
    world = scene.world();
    world.fields["message"] = name;
    scene.add_solid(
        world, box_sides(Vec3(x=-256.0, y=-256.0, z=-16.0), Vec3(x=256.0, y=256.0, z=0.0), self.material)
    );
    scene.add_item({"classname": "info_player_start", "origin": "0 0 24", "angle": "90"});
    scene.path = self.scene_path(name);
    self.scenes["passion/" + scene.name] = scene;
    self.show_scene(scene);
    self.say("New scene " + name);
}

impl Studio.open_map(path: str) {
    if not os.path.isfile(path) {
        self.say("ed_open: no such file " + path);
        return;
    }
    text = "";
    with open(path, "r") as file {
        text = file.read();
    }
    try {
        found = read_map(text);
    } except ValueError as error {
        self.say(str(error));
        return;
    }
    name = os.path.basename(path);
    if name.lower().endswith(".map") {
        name = name[:-4];
    }
    scene = scene_from_map("passion", "studio:" + name, found);
    scene.path = path;
    self.scenes["passion/" + scene.name] = scene;
    self.note_recent(path);
    self.show_scene(scene);
    self.say(
        "Opened " + path + ": " + str(len(scene.items())) + " entities, " + str(len(scene.solids())) + " brushes"
            + (", " + str(found.skipped) + " blocks not read" if found.skipped else "")
    );
}

impl Studio.show_scene(scene: Scene) {
    app = self.app;
    if app is None {
        return;
    }
    left = self.scene;
    if left is not None and left is not scene {
        # Where the camera stands in the document being left, to come back to.
        eye = self.main.eye;
        self.doc_views[left.game + "/" + left.name] = [eye.x, eye.y, eye.z, self.main.yaw, self.main.pitch];
    }
    if not self.load(scene.game, scene.name) {
        return;
    }
    self.leak = [];
    self.enter(reset_camera=False);
    # Above and behind the start, looking down at it.
    self.main.eye = Vec3(x=0.0, y=-420.0, z=260.0);
    self.main.yaw = math.pi * 0.5;
    self.main.pitch = -0.5;
    for port in self.ports[1:] {
        port.camera.eye = Vec3(z=64.0);
        port.camera.span = 1024.0;
    }
    made = self.live;
    if made is not None {
        for warning in made.warnings {
            self.say(warning);
        }
    }
}

impl Studio.save_scene(path: str = "") {
    scene = self.scene;
    if scene is None {
        return;
    }
    target = path if path else scene.path;
    if not target {
        target = self.scene_path(scene.name[7:]);
    }
    folder = os.path.dirname(target);
    if folder {
        os.makedirs(folder, exist_ok=True);
    }
    with open(target, "w") as file {
        file.write(self.map_text(scene));
    }
    scene.path = target;
    scene.dirty = False;
    self.note_recent(target);
    self.say("Saved " + target);
}

impl Studio.keep_built {
    app = self.app;
    scene = self.scene;
    if app is None or scene is None or not self.is_built_scene() {
        return;
    }
    if scene.geometry == self.built_geometry or self.moving or self.resizing {
        return;
    }
    # A way out found before the brushes changed may not be one now.
    self.leak = [];
    loaded = self.load(scene.game, scene.name, quiet=True);
    # Loading a level takes the mouse for the game; the studio keeps it free.
    _release();
    if not loaded {
        self.built_geometry = scene.geometry;
        return;
    }
    self.seen_revision = -1;
}

impl Studio.outline_solids(scene: Scene) {
    self.looks = [];
    for brush in scene.solids() {
        holder = scene.owner_of(brush);
        if brush.hidden or (holder is not None and (holder.hidden or item_veil(holder) == "hidden")) {
            continue;
        }
        outlines = brush.outlines();
        low = Vec3(x=1000000.0, y=1000000.0, z=1000000.0);
        high = Vec3(x=-1000000.0, y=-1000000.0, z=-1000000.0);
        for outline in outlines {
            for point in outline {
                low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
                high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
            }
        }
        if low.x <= high.x {
            look = SolidLook(solid=brush, outlines=outlines, low=low, high=high);
            if holder is not None {
                look.dim = item_veil(holder) == "grey";
                look.locked = item_switched(holder, LOCK_KEY);
                shade = [part for part in holder.fields.get(TINT_KEY, "").split() if part.isdigit()];
                if len(shade) == 3 {
                    look.tint = (min(255, int(shade[0])) << 16) | (min(255, int(shade[1])) << 8) | min(255, int(shade[2]));
                }
            }
            self.looks.append(look);
        }
    }
}

impl Studio.owned_shape(item: Item, solids: list[Solid]) -> Shape | None {
    if item.classname() == "worldspawn" {
        return None;
    }
    low = Vec3(x=1000000.0, y=1000000.0, z=1000000.0);
    high = Vec3(x=-1000000.0, y=-1000000.0, z=-1000000.0);
    for brush in solids {
        box = brush.bounds();
        if box is not None {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
            high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
        }
    }
    if low.x > high.x {
        return None;
    }
    return Shape(item=item, low=low, high=high, tone=class_tone(item.classname()));
}

impl Studio.look_of(solid: Solid) -> SolidLook | None {
    for seen in self.looks {
        if seen.solid is solid {
            return seen;
        }
    }
    return None;
}

impl Studio.aim(x: int, y: int) -> Aim {
    target = Aim();
    line = self.camera.sight(self.view_area(), x, y);
    eye = line[0];
    along = line[1];
    nearest = 1000000.0;
    for seen in self.looks {
        if seen.dim or seen.locked or ray_enters_box(eye, along, seen.low, seen.high) < 0.0 {
            # A click passes what is shown as outlines only, and what is locked.
            continue;
        }
        entered = ray_enters_brush(seen.solid.sides, eye, along);
        if entered[1] >= 0 and entered[0] > 0.0 and entered[0] < nearest {
            nearest = entered[0];
            target.solid = seen.solid;
            target.side = entered[1];
            target.reach = entered[0];
        }
    }
    under = self.pick(x, y);
    if under is not None {
        boxed = self.shape_of(under);
        reach = ray_enters_box(eye, along, boxed.low, boxed.high) if boxed is not None else -1.0;
        # An entity in front of every brush is what the pointer is on; a
        # brush entity's own brushes come before its box.
        if target.solid is None or (reach >= 0.0 and reach < target.reach - 1.0) {
            target.item = under;
            target.solid = None;
            target.side = -1;
            target.reach = reach;
        }
    }
    return target;
}

impl Studio.draw_solids(scene: Scene) {
    # Every brush's edges, faintly, so a blockout reads its own shape; when
    # the level itself is not drawn they are all there is of it.
    faint = ink(0xb8b0a4, 255) if self.bare_now else ink(0x000000, 110);
    for seen in self.looks {
        if scene.is_solid_selected(seen.solid) {
            continue;
        }
        # A group's own colour; outlines only are all there is of a grey group.
        tone = ink(seen.tint, 230) if seen.tint >= 0 else (ink(0x8a8378, 200) if seen.dim else faint);
        for outline in seen.outlines {
            for i in range(len(outline)) {
                wire_line(outline[i], outline[(i + 1) % len(outline)], tone);
            }
        }
    }
    rlDrawRenderBatchActive();
    rlDisableDepthTest();
    for seen in self.looks {
        chosen = scene.is_solid_selected(seen.solid);
        if not chosen and seen.solid is not self.hover_solid {
            continue;
        }
        tone = ink(0xffffff) if chosen else ink(0xff7a18, 170);
        for outline in seen.outlines {
            for i in range(len(outline)) {
                wire_line(outline[i], outline[(i + 1) % len(outline)], tone);
            }
        }
        if chosen and self.moving {
            for outline in seen.outlines {
                for i in range(len(outline)) {
                    wire_line(
                        outline[i].add(self.move_by),
                        outline[(i + 1) % len(outline)].add(self.move_by),
                        ink(0xff7a18)
                    );
                }
            }
        }
        if chosen and self.resizing and self.resize_side >= 0 and self.resize_side < len(seen.outlines) {
            pushed = seen.outlines[self.resize_side];
            push = seen.solid.sides[self.resize_side].plane.normal.scale(self.resize_by);
            for i in range(len(pushed)) {
                wire_line(pushed[i].add(push), pushed[(i + 1) % len(pushed)].add(push), ink(0xff7a18));
            }
        }
    }
    self.draw_faces(scene);
    rlDrawRenderBatchActive();
    rlEnableDepthTest();
}

impl Studio.handles(scene: Scene) -> list[tuple[int, Vec3]] {
    found: list[tuple[int, Vec3]] = [];
    bent = self.patch_now(scene);
    if self.mode == "corner" and bent is not None {
        # A patch shows the points that bend it.
        control = scene.patch_control(bent);
        if control is not None {
            for (number, point) in enumerate(control) {
                found.append((number, point));
            }
        }
        return found;
    }
    if self.mode == "brush" and self.gizmo != "move" {
        return self.transform_handles(scene);
    }
    chosen = scene.selected_solids();
    if len(chosen) != 1 or scene.selection() {
        # Anything but one lone brush: three arrows from the selection's
        # middle, one along each axis, to move it by.
        heart = scene.selection_middle();
        if self.mode == "brush" and heart is not None {
            arm = self.camera.span * 0.08
                if self.camera.span > 0.0
                else max(24.0, self.camera.eye.sub(heart).length() * 0.12);
            found.append((900, heart.add(Vec3(x=arm))));
            found.append((901, heart.add(Vec3(y=arm))));
            found.append((902, heart.add(Vec3(z=arm))));
        }
        return found;
    }
    seen = self.look_of(chosen[0]);
    if seen is None {
        return found;
    }
    if self.mode == "face" {
        return found;
    }
    if self.mode == "corner" {
        # Its corners, then the middles of its edges.
        count = 0;
        for corner in brush_corners(chosen[0].sides) {
            found.append((count, corner));
            count += 1;
        }
        for pair in brush_edges(chosen[0].sides) {
            found.append((count, pair[0].add(pair[1]).scale(0.5)));
            count += 1;
        }
        return found;
    }
    for index in range(len(seen.outlines)) {
        outline = seen.outlines[index];
        if len(outline) < 3 {
            continue;
        }
        middle = Vec3();
        for point in outline {
            middle = middle.add(point);
        }
        found.append((index, middle.scale(1.0 / float(len(outline)))));
    }
    return found;
}

impl Studio.draw_handles(scene: Scene, area: Rect) {
    canvas = self.canvas;
    if self.mode == "corner" and self.patch_now(scene) is not None {
        for (index, spot) in self.handles(scene) {
            grabbed = self.resizing and index == self.resize_side;
            at = self.camera.project(area, spot.add(self.corner_by) if grabbed else spot);
            if at is None {
                continue;
            }
            box = Rect(x=at[0] - 4, y=at[1] - 4, w=9, h=9);
            canvas.fill(box, canvas.theme.accent if grabbed else canvas.theme.good);
            canvas.outline(box, canvas.theme.header);
        }
        return;
    }
    if self.mode == "brush" and self.gizmo != "move" {
        self.draw_transform_handles(scene, area);
        return;
    }
    chosen = scene.selected_solids();
    if len(chosen) != 1 or scene.selection() {
        hub = scene.selection_middle();
        if hub is None {
            return;
        }
        centre = self.camera.project(area, hub.add(self.move_by) if self.moving else hub);
        tones = [ink(0xe5484d), ink(0x4cc38a), ink(0x5b8def)];
        for (index, spot) in self.handles(scene) {
            if index < 900 {
                continue;
            }
            at = self.camera.project(area, spot.add(self.move_by) if self.moving else spot);
            if at is None or centre is None {
                continue;
            }
            # An arrow seen end on is no arrow: its handle would sit on the middle.
            if abs(at[0] - centre[0]) + abs(at[1] - centre[1]) < 6 {
                continue;
            }
            tone = tones[index - 900];
            canvas.line(centre[0], centre[1], at[0], at[1], tone);
            box = Rect(x=at[0] - 4, y=at[1] - 4, w=9, h=9);
            canvas.fill(box, canvas.theme.accent if self.resizing and index == self.resize_side else tone);
            canvas.outline(box, canvas.theme.header);
        }
        return;
    }
    brush = chosen[0];
    corners = len(brush_corners(brush.sides)) if self.mode == "corner" else 0;
    for (index, middle) in self.handles(scene) {
        place = middle;
        if self.resizing and index == self.resize_side {
            if self.mode == "corner" {
                place = middle.add(self.corner_by);
            } else {
                place = middle.add(brush.sides[index].plane.normal.scale(self.resize_by));
            }
        }
        at = self.camera.project(area, place);
        if at is None {
            continue;
        }
        grabbed = self.resizing and index == self.resize_side;
        # An edge's handle is smaller than a corner's or a side's.
        half = 3 if self.mode == "corner" and index >= corners else 4;
        box = Rect(x=at[0] - half, y=at[1] - half, w=2 * half + 1, h=2 * half + 1);
        tone = canvas.theme.good if self.mode == "corner" and index >= corners else canvas.theme.text;
        canvas.fill(box, canvas.theme.accent if grabbed else tone);
        canvas.outline(box, canvas.theme.header);
    }
    # Its size, where its top is.
    seen = self.look_of(brush);
    if seen is None {
        return;
    }
    size = seen.high.sub(seen.low);
    words = str(int(round(size.x))) + " x " + str(int(round(size.y))) + " x " + str(int(round(size.z)));
    top = self.camera.project(area, Vec3(x=seen.center().x, y=seen.center().y, z=seen.high.z));
    if top is not None {
        wide = canvas.text_width(words, canvas.theme.small) + 8;
        tag = Rect(x=top[0] - wide // 2, y=top[1] - 30, w=wide, h=16);
        canvas.fill(tag, canvas.theme.header.faded(210));
        canvas.label(words, tag, canvas.theme.text, 0, 0, canvas.theme.small);
    }
}

impl Studio.grab_handle(scene: Scene, x: int, y: int) -> bool {
    area = self.view_area();
    hub = scene.selection_middle();
    if self.mode == "brush" and self.gizmo != "move" {
        hub = self.turn_hub(scene);
    }
    centre = self.camera.project(area, hub) if hub is not None else None;
    for (index, middle) in self.handles(scene) {
        at = self.camera.project(area, middle);
        if index >= 900 and index != 930 and at is not None and centre is not None
            and abs(at[0] - centre[0]) + abs(at[1] - centre[1]) < 6 {
            # An arrow seen end on cannot be taken hold of.
            continue;
        }
        if at is not None and abs(at[0] - x) <= 7 and abs(at[1] - y) <= 7 {
            self.resizing = True;
            self.resize_side = index;
            self.resize_by = 0.0;
            self.corner_by = Vec3();
            self.turn_by = 0.0;
            self.size_by = Vec3(x=1.0, y=1.0, z=1.0);
            return True;
        }
    }
    return False;
}

impl Studio.drag_handle(scene: Scene, x: int, y: int, free: bool) {
    if self.resize_side >= 910 {
        self.drag_transform(scene, x, y, free);
        return;
    }
    if self.resize_side >= 900 {
        # An arrow of the selection's own: move along its axis, as far as
        # the pointer has gone along the arrow as seen.
        hub = scene.selection_middle();
        if hub is None {
            return;
        }
        axis = Vec3(x=1.0) if self.resize_side == 900 else (Vec3(y=1.0) if self.resize_side == 901 else Vec3(z=1.0));
        view = self.view_area();
        from_at = self.camera.project(view, hub);
        to_at = self.camera.project(view, hub.add(axis.scale(64.0)));
        if from_at is None or to_at is None {
            return;
        }
        run = float(to_at[0] - from_at[0]);
        rise = float(to_at[1] - from_at[1]);
        length = run * run + rise * rise;
        if length < 1.0 {
            return;
        }
        along = (float(x - self.press_x) * run + float(y - self.press_y) * rise) / length * 64.0;
        notch = 1.0 if free else self.grid;
        self.moving = True;
        self.move_by = axis.scale(float(round(along / notch)) * notch);
        return;
    }
    chosen = scene.selected_solids();
    patched = self.mode == "corner" and self.patch_now(scene) is not None;
    if (len(chosen) != 1 and not patched) or self.resize_side < 0 {
        return;
    }
    if self.mode == "corner" {
        grabbed: Vec3 | None = None;
        for (index, point) in self.handles(scene) {
            if index == self.resize_side {
                grabbed = point;
            }
        }
        if grabbed is None {
            return;
        }
        # As a dragged selection goes: in the plane that faces the camera.
        dragged = self.on_view_plane(x, y, grabbed).sub(self.on_view_plane(self.press_x, self.press_y, grabbed));
        snap = 1.0 if free else self.grid;
        self.corner_by = Vec3(
            x=float(round(dragged.x / snap)) * snap,
            y=float(round(dragged.y / snap)) * snap,
            z=float(round(dragged.z / snap)) * snap
        );
        return;
    }
    if self.resize_side >= len(chosen[0].sides) {
        return;
    }
    middle: Vec3 | None = None;
    for (index, point) in self.handles(scene) {
        if index == self.resize_side {
            middle = point;
        }
    }
    if middle is None {
        return;
    }
    area = self.view_area();
    normal = chosen[0].sides[self.resize_side].plane.normal;
    start = self.camera.project(area, middle);
    ahead = self.camera.project(area, middle.add(normal.scale(64.0)));
    if start is None or ahead is None {
        return;
    }
    # How far the pointer has gone along the side's normal as seen.
    across = float(ahead[0] - start[0]);
    down = float(ahead[1] - start[1]);
    span = across * across + down * down;
    if span < 1.0 {
        return;
    }
    gone = (float(x - self.press_x) * across + float(y - self.press_y) * down) / span * 64.0;
    step = 1.0 if free else self.grid;
    self.resize_by = float(round(gone / step)) * step;
}

impl Studio.add_shape(scene: Scene, args: list[str], shape: str) {
    app = self.app;
    if app is None {
        return;
    }
    sizes = [64.0, 64.0, 64.0];
    for i in range(3) {
        if len(args) > i + 1 {
            try {
                sizes[i] = max(1.0, float(args[i + 1]));
            } except ValueError {
                self.say("ed_" + shape + " [width depth height]");
                return;
            }
        }
    }
    half = Vec3(x=sizes[0] * 0.5, y=sizes[1] * 0.5, z=sizes[2] * 0.5);
    eye = self.main.eye;
    ahead = self.main.forward();
    trace = app.level.collision.trace_point(eye, eye.add(ahead.scale(1024.0)));
    middle = eye.add(ahead.scale(256.0));
    if trace.fraction < 1.0 and not trace.start_solid {
        # Resting on what the camera looks at.
        touch = eye.add(ahead.scale(1024.0 * trace.fraction));
        middle = touch.add(
            Vec3(x=trace.normal.x * half.x, y=trace.normal.y * half.y, z=trace.normal.z * half.z)
        );
    }
    # Let it down onto whatever is beneath it.
    under = app.level.collision.trace_point(middle, middle.sub(Vec3(z=2048.0)));
    if under.fraction < 1.0 and not under.start_solid {
        middle = Vec3(x=middle.x, y=middle.y, z=middle.z - 2048.0 * under.fraction + half.z);
    }
    snap = 16.0;
    low = Vec3(
        x=float(round((middle.x - half.x) / snap)) * snap,
        y=float(round((middle.y - half.y) / snap)) * snap,
        z=float(round((middle.z - half.z) / snap)) * snap
    );
    high = low.add(Vec3(x=sizes[0], y=sizes[1], z=sizes[2]));
    sides = box_sides(low, high, self.material);
    if shape == "cylinder" {
        count = 12;
        if len(args) > 4 and args[4].isdigit() {
            count = int(args[4]);
        }
        sides = cylinder_sides(low, high, count, self.material);
    } elif shape == "wedge" {
        sides = wedge_sides(low, high, self.material);
    }
    made = scene.create_solid(sides);
    if made is None {
        self.say("That " + shape + " encloses nothing");
    } else {
        self.say("Added a " + shape);
    }
}

impl Studio.list_solids(scene: Scene, rows: list[TreeRow], wanted: str) {
    members: list[Solid] = [];
    for brush in scene.solids() {
        if wanted and wanted not in brush.sides[0].material.lower() and wanted not in "brushes" {
            continue;
        }
        members.append(brush);
    }
    if not members {
        return;
    }
    shown = self.opened.get("brushes", False) or bool(wanted);
    rows.append(
        TreeRow(key="class:brushes", text="brushes", branch=True, opened=shown, note=str(len(members)), tone="accent")
    );
    if not shown {
        return;
    }
    for brush in members {
        holder = scene.owner_of(brush);
        words = brush.sides[0].material if brush.sides[0].material else "(no material)";
        if holder is not None and holder.classname() != "worldspawn" {
            words += "  in " + holder.classname();
        }
        rows.append(
            TreeRow(
                key="solid:" + str(brush.serial),
                text=words,
                depth=1,
                picked=scene.is_solid_selected(brush),
                note="#" + str(brush.serial)
            )
        );
    }
}

impl Studio.fill_solid_form(scene: Scene, ui: StudioUi) {
    form = ui.form;
    chosen = scene.selected_solids();
    heading = "brush #" + str(chosen[0].serial) if len(chosen) == 1 else str(len(chosen)) + " brushes";
    form.adopt(Label(text=heading, tone="accent"));
    first = chosen[0].sides[0].material;
    same = True;
    for brush in chosen {
        for side in brush.sides {
            if side.material != first {
                same = False;
            }
        }
    }
    row = Box(across=True, gap=4);
    form.adopt(row);
    row.adopt(Label(text="material", tone="dim", size=104));
    row.adopt(
        TextField(
            value=first if same else "",
            ghost="" if same else "(mixed)",
            command="ed_material",
            grow=1,
            hint="Enter gives every side of the selected brushes this material"
        )
    );
    if len(chosen) == 1 {
        box = chosen[0].bounds();
        if box is not None {
            size = box[1].sub(box[0]);
            form.adopt(
                Label(
                    text="size   " + str(int(round(size.x))) + " x " + str(int(round(size.y))) + " x "
                        + str(int(round(size.z))),
                    tone="dim"
                )
            );
            form.adopt(
                Label(
                    text="from   " + str(int(round(box[0].x))) + " " + str(int(round(box[0].y))) + " "
                        + str(int(round(box[0].z))),
                    tone="dim"
                )
            );
        }
        holder = scene.owner_of(chosen[0]);
        form.adopt(Label(text="part of   " + (holder.title() if holder is not None else "nothing"), tone="dim"));
        form.adopt(
            Label(
                text="Drag a corner or the middle of an edge."
                    if self.mode == "corner"
                    else "Drag a square to push that side. G: rings that turn, boxes that size.",
                tone="faint",
                small=True
            )
        );
    }
    form.adopt(Spacer(size=6));
    tie = Box(across=True, gap=4);
    form.adopt(tie);
    tie.adopt(
        TextField(
            ghost="func_wall", command="ed_tie", grow=1, hint="Enter hands the selected brushes to a new entity of this class"
        )
    );
    tie.adopt(PushButton(text="To world", command="ed_tie", hint="Hand the selected brushes back to the world"));
    actions = Box(across=True, gap=4);
    form.adopt(actions);
    actions.adopt(PushButton(text="Look at", command="ed_focus", grow=1, hint="Move the camera to the selection (F)"));
    actions.adopt(PushButton(text="Duplicate", command="ed_duplicate", grow=1, hint="Copy the selection (Ctrl+D)"));
    actions.adopt(PushButton(text="Delete", command="ed_delete", grow=1, hint="Delete the selection (Del)"));
    cuts = Box(across=True, gap=4);
    form.adopt(cuts);
    cuts.adopt(
        PushButton(text="Carve", command="ed_carve", grow=1, hint="Cut the selected brushes out of every other brush")
    );
    cuts.adopt(
        PushButton(text="Hollow", command="ed_hollow", grow=1, hint="Turn the selected brushes into shells of walls")
    );
    cuts.adopt(
        PushButton(text="Merge", command="ed_merge", grow=1, hint="Join the selected brushes when together they are convex")
    );
    lays = Box(across=True, gap=4);
    form.adopt(lays);
    lays.adopt(PushButton(text="Fit", command="ed_tex fit", grow=1, hint="Fit the material to every side"));
    lays.adopt(PushButton(text="Flat", command="ed_tex flat", grow=1, hint="Lay the material flat on every side"));
    lays.adopt(PushButton(text="Reset", command="ed_tex reset", grow=1, hint="Lay the material as a new brush has it"));
}

impl Studio.scene_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_save_as" {
        if len(args) > 1 and self.is_built_scene() {
            self.save_scene(args[1]);
        } else {
            self.say("ed_save_as <file.map> saves a scene of brushes");
        }
        return True;
    }
    if name == "ed_box" or name == "ed_cylinder" or name == "ed_wedge" {
        self.add_shape(scene, args, name[3:]);
        return True;
    }
    if name == "ed_clip" {
        if len(args) < 3 or args[1] not in ["x", "y", "z"] {
            self.say("ed_clip <x|y|z> <coordinate> [back|front|both]");
            return True;
        }
        keep = args[3] if len(args) > 3 and args[3] in ["back", "front", "both"] else "both";
        try {
            at = float(args[2]);
        } except ValueError {
            self.say("ed_clip <x|y|z> <coordinate> [back|front|both]");
            return True;
        }
        normal = Vec3(x=1.0) if args[1] == "x" else (Vec3(y=1.0) if args[1] == "y" else Vec3(z=1.0));
        if not scene.selected_solids() {
            self.say("Select the brushes to cut");
        } elif not scene.clip_selection(Plane3(normal=normal, dist=at), keep, self.material) {
            self.say("That plane cuts nothing selected");
        }
        return True;
    }
    if name == "ed_rotate" {
        degrees = 90.0;
        if len(args) > 1 {
            try {
                degrees = float(args[1]);
            } except ValueError {
                self.say("ed_rotate [degrees] [x|y|z]");
                return True;
            }
        }
        about = 2;
        if len(args) > 2 and args[2] in ["x", "y"] {
            about = 0 if args[2] == "x" else 1;
        }
        if not scene.turn_selection(degrees, self.grid, about, self.pivot_for(scene), self.tex_lock) {
            self.say("Nothing to turn");
        }
        return True;
    }
    if name == "ed_matfilter" {
        self.material_filter = args[1] if len(args) > 1 else "";
        self.materials_changed += 1;
        return True;
    }
    if name == "ed_material" {
        if len(args) < 2 or not args[1].strip() {
            self.say("ed_material <name> [side]");
            return True;
        }
        self.material = args[1].strip();
        self.materials_changed += 1;
        side = int(args[2]) if len(args) > 2 and args[2].isdigit() else -1;
        if side >= 0 and scene.selected_solids() {
            if not scene.paint_selection(self.material, side) {
                self.say("Already " + self.material);
            }
        } elif scene.selected_solids() or scene.faces() {
            if not scene.reface(FaceEdit(how="material", material=self.material), "Set material") {
                self.say("Already " + self.material);
            }
        } else {
            self.say("New brushes will be " + self.material);
        }
        return True;
    }
    if name == "ed_push" {
        chosen = scene.selected_solids();
        if len(chosen) != 1 or len(args) < 3 {
            self.say("ed_push <side> <distance> moves a side of the one selected brush");
            return True;
        }
        try {
            if not scene.push_side(chosen[0], int(args[1]), float(args[2])) {
                self.say("That would leave the brush with nothing inside");
            }
        } except ValueError {
            self.say("ed_push <side> <distance>");
        }
        return True;
    }
    if name == "ed_tie" {
        taker = scene.tie_selection(args[1].strip() if len(args) > 1 else "");
        if taker is None {
            self.say("Select brushes to hand to an entity");
        } else {
            self.say("Now part of " + taker.title());
        }
        return True;
    }
    return False;
}

impl Studio.list_materials(ui: StudioUi) {
    rows: list[TreeRow] = [];
    wanted = self.material_filter.lower();
    rows.append(
        TreeRow(key="scene", text="in this scene", picked=self.shelf == "scene" or not self.shelf, tone="accent")
    );
    shelf = self.archive;
    if shelf is None {
        rows.append(TreeRow(key="scene", text="(no game archives found)", tone="faint"));
    } else {
        # The project's own image files, when it has a folder of them.
        if len(shelf.file_names()) > 0 {
            rows.append(TreeRow(key="files", text="your files", picked=self.shelf == "files", tone="accent"));
        }
        for group in shelf.groups() {
            # A filter looks inside the groups already listed once, so typing
            # does not read every map.
            if wanted and wanted not in group.lower() {
                inside = False;
                if group in shelf.listed {
                    for name in shelf.names(group) {
                        if wanted in name.lower() {
                            inside = True;
                        }
                    }
                }
                if not inside {
                    continue;
                }
            }
            rows.append(TreeRow(key=group, text=group, picked=group == self.shelf));
        }
    }
    ui.materials.rows = rows;
    self.fill_gallery(ui);
}
