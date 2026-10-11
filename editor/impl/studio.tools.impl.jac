"""The studio's faces, corners, wider selections and brush tools: their
commands, the face inspector, the rectangle that selects, the materials
gallery and the map check. Declarations live in studio.jac."""

impl Studio.select_wide(scene: Scene, args: list[str]) -> bool {
    word = args[1];
    count = -1;
    if word == "all" {
        count = scene.select_all();
    } elif word == "brushes" or word == "entities" {
        count = scene.select_all(word);
    } elif word == "invert" {
        count = scene.invert_selection();
    } elif word.startswith("material:") {
        count = scene.select_material(word[9:]);
    } elif word.startswith("name:") {
        count = scene.select_named(word[5:]);
    } elif word.startswith("field:") {
        pair = word[6:].split("=", 1);
        count = scene.select_field(pair[0], pair[1] if len(pair) > 1 else "");
    }
    if count < 0 {
        return False;
    }
    self.say("Selected " + str(count));
    return True;
}

impl Studio.material_sizes(scene: Scene) -> dict[str, list[int]] {
    sizes: dict[str, list[int]] = {};
    brushes = scene.selected_solids();
    for face in scene.faces() {
        if face.solid not in brushes {
            brushes.append(face.solid);
        }
    }
    for item in scene.selection() {
        for owned in scene.solids_of(item) {
            if owned not in brushes {
                brushes.append(owned);
            }
        }
    }
    for brush in brushes {
        for side in brush.sides {
            if side.material not in sizes {
                image = self.materials.texture(side.material);
                sizes[side.material] = [max(1, image.width), max(1, image.height)];
            }
        }
    }
    return sizes;
}

impl Studio.grip_spots(scene: Scene, index: int) -> list[Vec3] {
    chosen = scene.selected_solids();
    spots: list[Vec3] = [];
    if len(chosen) != 1 or index < 0 {
        return spots;
    }
    corners = brush_corners(chosen[0].sides);
    if index < len(corners) {
        spots.append(corners[index]);
        return spots;
    }
    pairs = brush_edges(chosen[0].sides);
    if index - len(corners) < len(pairs) {
        pair = pairs[index - len(corners)];
        spots.append(pair[0]);
        spots.append(pair[1]);
    }
    return spots;
}

impl Studio.select_in_box(scene: Scene, port: int, area: Rect, add: bool) {
    if port < 0 or port >= len(self.ports) {
        return;
    }
    camera = self.ports[port].camera;
    view = self.ports[port].view.area;
    if not add {
        scene.clear_selection();
    }
    count = 0;
    for shape in self.shapes {
        at = camera.project(view, shape.center());
        if at is not None and area.holds(at[0], at[1]) and not scene.is_selected(shape.item) {
            scene.select(shape.item, True);
            count += 1;
        }
    }
    for seen in self.looks {
        holder = scene.owner_of(seen.solid);
        # A brush entity's brushes come with the entity.
        if holder is None or holder.classname() != "worldspawn" {
            continue;
        }
        at = camera.project(view, seen.center());
        if at is not None and area.holds(at[0], at[1]) and not scene.is_solid_selected(seen.solid) {
            scene.select_solid(seen.solid, True);
            count += 1;
        }
    }
    scene.picks += 1;
    self.say("Selected " + str(count));
}

impl Studio.draw_faces(scene: Scene) {
    for face in scene.faces() {
        seen = self.look_of(face.solid);
        if seen is None or face.side >= len(seen.outlines) {
            continue;
        }
        outline = seen.outlines[face.side];
        for i in range(len(outline)) {
            wire_line(outline[i], outline[(i + 1) % len(outline)], ink(0xff7a18));
        }
        # Lines to its middle mark it as a face rather than an edge loop.
        if len(outline) >= 3 {
            middle = Vec3();
            for point in outline {
                middle = middle.add(point);
            }
            middle = middle.scale(1.0 / float(len(outline)));
            for point in outline {
                wire_line(point, middle, ink(0xff7a18, 130));
            }
        }
    }
    hovered = self.hover_solid;
    if self.mode == "face" and hovered is not None and self.hover_side >= 0 {
        seen = self.look_of(hovered);
        if seen is not None and self.hover_side < len(seen.outlines) {
            outline = seen.outlines[self.hover_side];
            for i in range(len(outline)) {
                wire_line(outline[i], outline[(i + 1) % len(outline)], ink(0xffffff));
            }
        }
    }
}

impl Studio.fill_face_form(scene: Scene, ui: StudioUi) {
    form = ui.form;
    picks = scene.faces();
    first = picks[0];
    side = first.solid.sides[first.side];
    heading = "face " + str(first.side) + " of brush #" + str(first.solid.serial)
        if len(picks) == 1
        else str(len(picks)) + " faces";
    form.adopt(Label(text=heading, tone="accent"));
    same = True;
    for face in picks {
        if face.solid.sides[face.side].material != side.material {
            same = False;
        }
    }
    row = Box(across=True, gap=4);
    form.adopt(row);
    row.adopt(Label(text="material", tone="dim", size=104));
    row.adopt(
        TextField(
            value=side.material if same else "",
            ghost="" if same else "(mixed)",
            command="ed_material",
            grow=1,
            hint="Enter gives the selected faces this material"
        )
    );
    lay = side.mapping;
    fields = [
        ("shift", field_words(lay.s_shift) + " " + field_words(lay.t_shift), "ed_tex shiftto", "Texels the material is slid by: across, then down"),
        ("scale", field_words(lay.s_scale) + " " + field_words(lay.t_scale), "ed_tex scale", "World units to a texel: across, then down (negative mirrors)"),
        ("angle", field_words(lay.rotation), "ed_tex turnto", "Degrees the material is turned on the face")
    ];
    for (title, shown, asked, told) in fields {
        line = Box(across=True, gap=4);
        form.adopt(line);
        line.adopt(Label(text=title, tone="dim", size=104));
        line.adopt(TextField(value=shown, command=asked, grow=1, hint=told));
    }
    image = self.materials.texture(side.material);
    form.adopt(
        Label(text="texture   " + str(image.width) + " x " + str(image.height) + " texels", tone="dim")
    );
    form.adopt(Spacer(size=6));
    nudges = Box(across=True, gap=4);
    form.adopt(nudges);
    nudges.adopt(PushButton(text="<", command="ed_tex shift -8 0", grow=1, hint="Slide the material 8 texels left"));
    nudges.adopt(PushButton(text=">", command="ed_tex shift 8 0", grow=1, hint="Slide the material 8 texels right"));
    nudges.adopt(PushButton(text="^", command="ed_tex shift 0 -8", grow=1, hint="Slide the material 8 texels up"));
    nudges.adopt(PushButton(text="v", command="ed_tex shift 0 8", grow=1, hint="Slide the material 8 texels down"));
    nudges.adopt(PushButton(text="-15", command="ed_tex turn -15", grow=1, hint="Turn the material 15 degrees back"));
    nudges.adopt(PushButton(text="+15", command="ed_tex turn 15", grow=1, hint="Turn the material 15 degrees on"));
    fits = Box(across=True, gap=4);
    form.adopt(fits);
    fits.adopt(PushButton(text="Fit", command="ed_tex fit", grow=1, hint="Cover the face with the whole texture once"));
    fits.adopt(PushButton(text="Flat", command="ed_tex flat", grow=1, hint="Lay the material in the face's own plane"));
    fits.adopt(PushButton(text="Reset", command="ed_tex reset", grow=1, hint="Lay the material as a new brush has it"));
    form.adopt(Spacer(size=6));
    others = Box(across=True, gap=4);
    form.adopt(others);
    others.adopt(
        PushButton(text="Take material", command="ed_pickmat", grow=1, hint="New brushes and faces get this face's material")
    );
    others.adopt(
        PushButton(
            text="Whole brush",
            command="ed_select solid:" + str(first.solid.serial),
            grow=1,
            hint="Select the brush this face is a side of"
        )
    );    spread = Box(across=True, gap=4);
    form.adopt(spread);
    spread.adopt(PushButton(text="All faces", command="ed_faces all", grow=1, hint="Pick every face of this brush"));
    spread.adopt(PushButton(text="Others", command="ed_faces invert", grow=1, hint="Pick the brush's other faces instead"));
    spread.adopt(
        PushButton(text="Same plane", command="ed_faces extend", grow=1, hint="Pick every face that lies in this face's plane")
    );
    spread.adopt(PushButton(text="Tag", command="ed_tag", grow=1, hint="Remember this face, to glue brushes against"));
}

"""A number as a form shows it: whole numbers without a point."""
def:priv field_words(value: float) -> str {
    nearest = float(round(value));
    if abs(value - nearest) < 0.0005 {
        return str(int(nearest));
    }
    return str(round(value, 3));
}

"""The numbers among a command's words (a field hands them over as one
word)."""
def:priv numbers_in(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in " ".join(words).split() {
        try {
            found.append(float(word));
        } except ValueError {
            continue;
        }
    }
    return found;
}

impl Studio.fill_gallery(ui: StudioUi) {
    scene = self.scene;
    shelf = self.archive;
    wanted = self.material_filter.lower();
    names: list[str] = [];
    if (not self.shelf or self.shelf == "scene" or shelf is None) {
        names.append("blockout");
        if self.material not in names {
            names.append(self.material);
        }
        if scene is not None {
            used: list[str] = [];
            for brush in scene.solids() {
                for side in brush.sides {
                    if side.material and side.material not in names and side.material not in used {
                        used.append(side.material);
                    }
                }
            }
            names.extend(sorted(used));
        }
    } elif self.shelf == "files" {
        names = shelf.file_names();
    } else {
        names = list(shelf.names(self.shelf));
    }
    tiles: list[Tile] = [];
    for name in names {
        if wanted and wanted not in name.lower() {
            continue;
        }
        tiles.append(Tile(key=name, text=name.split("/")[-1].split(":")[-1], picked=name == self.material));
        if not self.canvas.has_picture(name) and name not in self.thumbs {
            self.thumbs.append(name);
        }
    }
    ui.gallery.tiles = tiles;
}

impl Studio.load_thumbs {
    shelf = self.archive;
    count = 0;
    while len(self.thumbs) > 0 and count < 4 {
        name = self.thumbs.pop(0);
        count += 1;
        image: Texture | None = None;
        if shelf is not None {
            image = shelf.fetch(name);
        }
        if image is None {
            image = swatch_texture(name);
        }
        if len(image.rgba) == 0 and len(image.encoded) > 0 {
            # Quake III keeps its images as files; the canvas decodes them.
            self.canvas.keep_encoded(name, image.extension, image.encoded);
            continue;
        }
        small = small_picture(image, 72);
        self.canvas.keep_picture(name, small.width, small.height, small.rgba);
    }
}

impl Studio.check(scene: Scene, args: list[str]) {
    ui = self.ui;
    if len(args) > 1 and args[1].isdigit() {
        index = int(args[1]);
        if index < len(self.findings) {
            about = self.findings[index];
            about_item = about.item;
            about_solid = about.solid;
            if about_solid is not None and about_solid.held {
                scene.select_solid(about_solid);
                self.focus(scene, ["ed_focus"]);
            } elif about_item is not None and about_item.held {
                scene.select(about_item);
                self.focus(scene, ["ed_focus"]);
            }
            self.say(about.words);
        }
        return;
    }
    self.findings = scene.problems();
    # Materials named as a game's that no archive holds draw as swatches.
    stock = self.archive;
    if stock is not None {
        looked: list[str] = [];
        for brush in scene.solids() {
            for side in brush.sides {
                name = side.material;
                if name in looked or ":" not in name or name.startswith("studio:") {
                    continue;
                }
                looked.append(name);
                if name.split(":", 1)[0] in ["q1", "q2", "q3", "file"] and stock.fetch(name) is None {
                    self.findings.append(
                        Finding(words="No archive holds the material " + name + " (brush #" + str(brush.serial) + ")", solid=brush)
                    );
                }
            }
        }
    }
    rows: list[TreeRow] = [];
    grave = 0;
    for (index, found) in enumerate(self.findings) {
        if found.grave {
            grave += 1;
        }
        rows.append(
            TreeRow(key=str(index), text=found.words, tone="text" if found.grave else "dim", note="!" if found.grave else "")
        );
        print("studio: finding " + ("grave " if found.grave else "") + found.words);
    }
    if ui is not None {
        if not rows {
            rows.append(TreeRow(key="none", text="Nothing is wrong.", tone="faint"));
        }
        ui.checks.rows = rows;
    }
    if len(self.findings) == 0 {
        self.say("Nothing is wrong with the map");
    } else {
        self.say(
            str(len(self.findings)) + " findings" + (", " + str(grave) + " would stop it playing" if grave else "")
        );
    }
}

impl Studio.tool_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_mode" {
        if len(args) < 2 or args[1] not in ["brush", "face", "corner", "sculpt", "clip", "draw"] {
            self.say("ed_mode <brush|face|corner|sculpt|clip|draw>");
            return True;
        }
        self.mode = args[1];
        picks = scene.faces();
        if self.mode != "face" and picks {
            # The picked faces' brushes become the selection.
            scene.clear_selection();
            for face in picks {
                if not scene.is_solid_selected(face.solid) {
                    scene.select_solid(face.solid, True);
                }
            }
        }
        scene.picks += 1;
        self.say(
            "Clicks pick brushes and entities" if self.mode == "brush" else (
                "Clicks pick faces" if self.mode == "face" else (
                    "The selected brush shows its corners and edges"
                        if self.mode == "corner"
                        else (
                            "A drag raises terrain; Shift lowers it, Ctrl smooths it"
                                if self.mode == "sculpt"
                                else (
                                    "Draw a line across a view to cut the selected brushes along it"
                                        if self.mode == "clip"
                                        else "Draw a rectangle in an axis view to make a box"
                                )
                        )
                )
            )
        );
        return True;
    }
    if name == "ed_face" {
        if len(args) < 3 or not args[1].isdigit() or not args[2].isdigit() {
            self.say("ed_face <brush> <side> [add]");
            return True;
        }
        brush = scene.find_solid(int(args[1]));
        if brush is None or int(args[2]) >= len(brush.sides) {
            self.say("ed_face: no such face");
            return True;
        }
        self.mode = "face";
        scene.select_face(brush, int(args[2]), len(args) > 3 and args[3] == "add");
        return True;
    }
    if name == "ed_tex" {
        how = args[1] if len(args) > 1 else "";
        numbers = numbers_in(args[2:]);
        first = numbers[0] if len(numbers) > 0 else 0.0;
        second = numbers[1] if len(numbers) > 1 else 0.0;
        change: FaceEdit | None = None;
        if how == "shift" {
            change = FaceEdit(how="shift", s=first, t=second);
        } elif how == "shiftto" {
            change = FaceEdit(how="shift_to", s=first, t=second);
        } elif how == "scale" and len(numbers) > 0 {
            change = FaceEdit(how="scale", s=first, t=second if len(numbers) > 1 else first);
        } elif how == "turn" and len(numbers) > 0 {
            change = FaceEdit(how="turn", s=first);
        } elif how == "turnto" and len(numbers) > 0 {
            change = FaceEdit(how="turn_to", s=first);
        } elif how == "fit" {
            change = FaceEdit(how="fit", s=first, t=second, sizes=self.material_sizes(scene));
        } elif how == "flat" or how == "reset" {
            change = FaceEdit(how=how);
        }
        if change is None {
            self.say("ed_tex <shift|shiftto|scale|turn|turnto|fit|flat|reset> [a] [b]");
        } elif not scene.faces() and not scene.selected_solids() and not scene.selection() {
            self.say("Select faces or brushes first");
        } elif not scene.reface(change, "Material " + how) {
            self.say("Nothing to change");
            # The inspector shows what the document still has.
            self.seen_revision = -1;
        }
        return True;
    }
    if name == "ed_pickmat" {
        taken = "";
        if len(args) > 2 and args[1].isdigit() and args[2].isdigit() {
            brush = scene.find_solid(int(args[1]));
            if brush is not None and int(args[2]) < len(brush.sides) {
                taken = brush.sides[int(args[2])].material;
            }
        } elif scene.faces() {
            face = scene.faces()[0];
            taken = face.solid.sides[face.side].material;
        } elif scene.selected_solids() {
            taken = scene.selected_solids()[0].sides[0].material;
        }
        if taken {
            self.material = taken;
            self.materials_changed += 1;
            self.say("New brushes and faces will be " + taken);
        } else {
            self.say("ed_pickmat: point at a face, or select one");
        }
        return True;
    }
    if name == "ed_carve" {
        count = scene.carve_selection();
        self.say("Carved " + str(count) + " brushes" if count > 0 else "The selection reaches no other brush");
        return True;
    }
    if name == "ed_intersect" {
        if not scene.intersect_selection() {
            self.say("Select two or more brushes that share some space");
        }
        return True;
    }
    if name == "ed_hollow" {
        thickness = 16.0;
        if len(args) > 1 {
            try {
                thickness = float(args[1]);
            } except ValueError {
                self.say("ed_hollow [thickness]");
                return True;
            }
        }
        if not scene.hollow_selection(thickness) {
            self.say("Select brushes wider than twice the walls");
        }
        return True;
    }
    if name == "ed_merge" {
        if not scene.merge_selection() {
            self.say("Those brushes do not make one convex brush");
        }
        return True;
    }
    if name == "ed_mirror" {
        if len(args) < 2 or args[1] not in ["x", "y", "z"] {
            self.say("ed_mirror <x|y|z>");
            return True;
        }
        factors = Vec3(
            x=-1.0 if args[1] == "x" else 1.0, y=-1.0 if args[1] == "y" else 1.0, z=-1.0 if args[1] == "z" else 1.0
        );
        if not scene.stretch_selection(factors, self.grid, "Mirror") {
            self.say("Nothing to mirror");
        }
        return True;
    }
    if name == "ed_resize" {
        numbers = numbers_in(args[1:]);
        if len(numbers) == 0 or len(numbers) == 2 {
            self.say("ed_resize <fx> [fy fz]");
            return True;
        }
        factors = Vec3(x=numbers[0], y=numbers[0], z=numbers[0]);
        if len(numbers) > 2 {
            factors = Vec3(x=numbers[0], y=numbers[1], z=numbers[2]);
        }
        if not scene.stretch_selection(factors, self.grid, "Resize") {
            self.say("Nothing to resize (a factor cannot be nothing)");
        }
        return True;
    }
    if name == "ed_boxselect" {
        numbers = numbers_in(args[1:]);
        if len(numbers) < 5 {
            self.say("ed_boxselect <view> <x0> <y0> <x1> <y1> [add]");
            return True;
        }
        x0 = int(min(numbers[1], numbers[3]));
        y0 = int(min(numbers[2], numbers[4]));
        band = Rect(x=x0, y=y0, w=int(abs(numbers[3] - numbers[1])) + 1, h=int(abs(numbers[4] - numbers[2])) + 1);
        self.select_in_box(scene, int(numbers[0]), band, len(args) > 6 and args[6] == "add");
        return True;
    }
    if name == "ed_corner" {
        numbers = numbers_in(args[1:]);
        chosen = scene.selected_solids();
        if len(numbers) < 6 or len(numbers) % 3 != 0 or len(chosen) != 1 {
            self.say("ed_corner <dx> <dy> <dz> <x> <y> <z> [...] moves corners of the one selected brush");
            return True;
        }
        spots: list[Vec3] = [];
        for i in range(1, len(numbers) // 3) {
            spots.append(Vec3(x=numbers[i * 3], y=numbers[i * 3 + 1], z=numbers[i * 3 + 2]));
        }
        if not scene.move_corners(chosen[0], spots, Vec3(x=numbers[0], y=numbers[1], z=numbers[2])) {
            self.say("That would leave the brush flat, or it has no corner there");
        }
        return True;
    }
    if name == "ed_display" {
        if len(args) < 2 or args[1] not in ["wire", "textured"] {
            self.say("ed_display <wire|textured> [3d|axis|all]");
            return True;
        }
        which = args[2] if len(args) > 2 else "axis";
        if which == "axis" or which == "all" {
            self.wire_axis = args[1] == "wire";
        }
        if which == "3d" or which == "all" {
            self.wire_main = args[1] == "wire";
        }
        self.keep_settings();
        return True;
    }
    if name == "ed_check" {
        self.check(scene, args);
        return True;
    }
    if name == "ed_shelf" {
        self.shelf = args[1] if len(args) > 1 else "";
        self.materials_changed += 1;
        return True;
    }
    return False;
}
