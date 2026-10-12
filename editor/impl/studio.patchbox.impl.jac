"""The patch's material box: the selected patch's material, with the places
its control points lie at on it drawn over it to be dragged, and fields to
set one point, slide a row, a column or the whole by numbers. Declarations
live in studio.jac."""

"""A number of texels as the command takes it: whole when it is."""
def:priv place_word(value: float) -> str {
    near = round(value, 3);
    return str(int(near)) if near == float(int(near)) else str(near);
}

impl Studio.patch_box_state(scene: Scene) -> list[float] {
    bent = self.patch_now(scene);
    return scene.patch_places(bent) if bent is not None else [];
}

impl Studio.keep_patch_box {
    casing = self.patch_box;
    scene = self.scene;
    if casing is None or scene is None {
        return;
    }
    bent = self.patch_now(scene);
    places = scene.patch_places(bent) if bent is not None else [];
    lay = scene.patch_grid(bent) if bent is not None else None;
    words = (str(bent.serial) if bent is not None else "none") + "|" + str(len(places));
    if words == self.patch_box_for {
        return;
    }
    self.patch_box_for = words;
    casing.clear();
    self.patch_pane = None;
    form = Box(pad=8, gap=4, fill="panel");
    casing.adopt(form);
    if bent is None or lay is None {
        form.adopt(Label(text="Select a patch.", tone="dim"));
        return;
    }
    if len(places) == 0 {
        form.adopt(Label(text="Its control points have not been told where they lie.", tone="dim", small=True));
        row = Box(across=True, gap=4);
        form.adopt(row);
        row.adopt(PushButton(text="Fit once", command="ed_patch uv fit", hint="Spread the material over it once"));
        row.adopt(PushButton(text="As the tagged face", command="ed_patch uv project", hint="Lay it as the tagged face has it"));
        return;
    }
    # The material's own picture, kept under a name of its own.
    owned = scene.solids_of(bent);
    material = owned[0].sides[0].material if len(owned) > 0 else "";
    image = self.materials.texture(material) if material else None;
    if image is not None {
        colours = texture_rgba(image);
        if len(colours) > 0 {
            self.canvas.keep_picture("patchmat", image.width, image.height, colours);
        }
        self.patch_box_size = [float(max(1, image.width)), float(max(1, image.height))];
    } else {
        self.patch_box_size = [64.0, 64.0];
    }
    pane = SkinPane(key="", size=220);
    form.adopt(pane);
    self.patch_pane = pane;
    form.adopt(Label(text="Drag a point's place; the numbers below are in texels.", tone="faint", small=True));
    for (called, order, ghost) in [
        ("point", "ed_patch uv point", "column row s t"),
        ("row", "ed_patch uv row", "row ds dt"),
        ("column", "ed_patch uv col", "column ds dt"),
        ("all", "ed_patch uv all", "ds dt")
    ] {
        row = Box(across=True, gap=4);
        form.adopt(row);
        row.adopt(Label(text=called, tone="dim", size=56));
        row.adopt(TextField(ghost=ghost, command=order, grow=1, hint=order + " <" + ghost + ">: Enter sets it"));
    }
    row = Box(across=True, gap=4);
    form.adopt(row);
    row.adopt(PushButton(text="Fit once", command="ed_patch uv fit", hint="Spread the material over it once"));
    row.adopt(PushButton(text="Forget", command="ed_patch uv clear", hint="Forget where the points lie"));
}

impl Studio.patch_box_events {
    pane = self.patch_pane;
    scene = self.scene;
    if pane is None or scene is None {
        return;
    }
    taken = pane.take();
    bent = self.patch_now(scene);
    lay = scene.patch_grid(bent) if bent is not None else None;
    places = scene.patch_places(bent) if bent is not None else [];
    if bent is None or lay is None or len(places) == 0 {
        return;
    }
    texel_span = place_frame(places, self.patch_box_size[0], self.patch_box_size[1]);
    whole = pane.area;
    fit = frame_fit(texel_span, whole.w - 8, whole.h - 8);
    for event in taken {
        x = event.x - whole.x - 4;
        y = event.y - whole.y - 4;
        if event.kind == "press" and event.button == 0 {
            self.patch_held = place_at_pixel(texel_span, fit, places, x, y);
            self.patch_drag = [0.0, 0.0];
            self.patch_press = [x, y];
        } elif event.kind == "drag" and self.patch_held >= 0 {
            # Whole texels, as the numbers say them.
            self.patch_drag = [
                float(round(float(x - self.patch_press[0]) / fit[2])), float(round(float(y - self.patch_press[1]) / fit[2]))
            ];
        } elif event.kind == "release" and event.button == 0 and self.patch_held >= 0 {
            held = self.patch_held;
            moved = self.patch_drag;
            self.patch_held = -1;
            self.patch_drag = [0.0, 0.0];
            if abs(moved[0]) + abs(moved[1]) > 0.0 and held * 2 + 1 < len(places) {
                across = int(lay[0]);
                self.command(
                    [
                        "ed_patch", "uv", "point", str(held % across), str(held // across),
                        place_word(places[held * 2] + moved[0]), place_word(places[held * 2 + 1] + moved[1])
                    ]
                );
                self.patch_box_for = "";
            }
        }
    }
}

impl Studio.draw_patch_box {
    pane = self.patch_pane;
    scene = self.scene;
    if pane is None or scene is None or pane.parent() is None {
        return;
    }
    bent = self.patch_now(scene);
    lay = scene.patch_grid(bent) if bent is not None else None;
    places = scene.patch_places(bent) if bent is not None else [];
    if bent is None or lay is None or len(places) == 0 {
        return;
    }
    canvas = self.canvas;
    whole = pane.area;
    texel_span = place_frame(places, self.patch_box_size[0], self.patch_box_size[1]);
    fit = frame_fit(texel_span, whole.w - 8, whole.h - 8);
    left = whole.x + 4;
    top = whole.y + 4;
    # The picture where its texels lie, once.
    corner = place_pixel(texel_span, fit, 0.0, 0.0);
    far = place_pixel(texel_span, fit, self.patch_box_size[0], self.patch_box_size[1]);
    canvas.picture("patchmat", Rect(x=left + corner[0], y=top + corner[1], w=far[0] - corner[0], h=far[1] - corner[1]));
    across = int(lay[0]);
    count = len(places) // 2;
    spots: list[list[int]] = [];
    for index in range(count) {
        s = places[index * 2] + (self.patch_drag[0] if index == self.patch_held else 0.0);
        t = places[index * 2 + 1] + (self.patch_drag[1] if index == self.patch_held else 0.0);
        at = place_pixel(texel_span, fit, s, t);
        spots.append([left + at[0], top + at[1]]);
    }
    for index in range(count) {
        # To the next along its row, and to the one below it.
        if index % across + 1 < across and index + 1 < count {
            canvas.line(spots[index][0], spots[index][1], spots[index + 1][0], spots[index + 1][1], canvas.theme.dim);
        }
        if index + across < count {
            canvas.line(spots[index][0], spots[index][1], spots[index + across][0], spots[index + across][1], canvas.theme.dim);
        }
    }
    for (index, spot) in enumerate(spots) {
        knob = Rect(x=spot[0] - 3, y=spot[1] - 3, w=7, h=7);
        canvas.fill(knob, canvas.theme.accent if index == self.patch_held else canvas.theme.good);
        canvas.outline(knob, canvas.theme.header);
    }
}

impl Studio.patch_box_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_patchbox" {
        return False;
    }
    stage = self.stage;
    how = args[1] if len(args) > 1 else "";
    casing = self.patch_box;
    if how == "close" or (not how and casing is not None) {
        if casing is not None and stage is not None {
            stage.close(casing);
        }
        self.patch_box = None;
        self.patch_pane = None;
        return True;
    }
    if casing is None and stage is not None {
        casing = Floater(title="Patch material", command="ed_patchbox close", least_wide=260, least_tall=200);
        casing.area = Rect(x=max(8, stage.width - 300), y=110, w=280, h=420);
        casing.settle(stage);
        stage.open(casing);
        self.patch_box = casing;
    }
    self.patch_box_for = "";
    self.keep_patch_box();
    print("studio: patchbox open places=" + str(len(self.patch_box_state(scene)) // 2));
    return True;
}
