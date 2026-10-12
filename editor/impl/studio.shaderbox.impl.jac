"""The shader box: the shader in hand as a list of its own lines and of its
stages' lines, each a field to change, with stages added, moved and
dropped; and its preview, drawn on a square in the explorer's model view
by the engine's own model shader stages. Declarations live in studio.jac."""

impl Studio.keep_shader_box {
    casing = self.shader_box;
    if casing is None {
        return;
    }
    shader = self.shader_in_hand();
    words = (write_shaders([shader]) if shader is not None else "none") + "|" + str(len(self.shader_list));
    if words == self.shader_box_for {
        return;
    }
    self.shader_box_for = words;
    previewing = self.model_now;
    if previewing is not None and previewing.name.startswith("shader:") and shader is not None {
        # The preview is drawn again with every change: it is live while the box is open.
        self.preview_shader();
    }
    casing.clear();
    form = Box(pad=8, gap=4, fill="panel");
    casing.adopt(form);
    if shader is None {
        form.adopt(Label(text="No shader is in hand.", tone="dim"));
        form.adopt(Label(text="ed_shader open <file>, take, or new <name>.", tone="faint", small=True));
        return;
    }
    names = [held.name for held in self.shader_list];
    form.adopt(
        Dropdown(
            text=shader.name, labels=names, commands=["ed_shader pick " + quote_command_word(name) for name in names],
            hint="The shader in hand, among the script's"
        )
    );
    window = Scroll(grow=1);
    form.adopt(window);
    side = Box(gap=3);
    window.adopt(side);
    side.adopt(Label(text="The shader's own lines (an empty line drops it)", tone="dim", small=True));
    for (index, line) in enumerate(shader.lines) {
        side.adopt(TextField(value=line, command="ed_shaderline -1 " + str(index), hint="Enter changes the line"));
    }
    side.adopt(TextField(ghost="a line more: cull none, surfaceparm nolightmap ...", command="ed_shaderline -1 add"));
    for (number, layer) in enumerate(shader.stages) {
        row = Box(across=True, gap=4);
        side.adopt(row);
        row.adopt(Label(text="Stage " + str(number + 1), tone="accent", grow=1));
        if number > 0 {
            row.adopt(PushButton(text="Up", command="ed_shader stage " + str(number) + " move " + str(number - 1), hint="Draw it before the one above"));
        }
        row.adopt(PushButton(text="Drop", command="ed_shader stage " + str(number) + " drop", hint="Take the stage away"));
        for (index, line) in enumerate(layer.lines) {
            side.adopt(TextField(value=line, command="ed_shaderline " + str(number) + " " + str(index), hint="Enter changes the line"));
        }
        side.adopt(TextField(ghost="a line more: blendFunc add, tcMod scroll 0 1 ...", command="ed_shaderline " + str(number) + " add"));
    }
    row = Box(across=True, gap=4);
    form.adopt(row);
    row.adopt(PushButton(text="Add a stage", command="ed_shader stage add", hint="A stage of $whiteimage at the end"));
    row.adopt(PushButton(text="Preview", command="ed_shader preview", hint="Draw it on a square in the explorer, as the game would"));
    row.adopt(PushButton(text="Check", command="ed_shader check"));
    row.adopt(PushButton(text="Save", command="ed_shader save"));
}

impl Studio.shader_box_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_shaderline" {
        shader = self.shader_in_hand();
        if shader is None or len(args) < 3 or not args[1].lstrip("-").isdigit() {
            self.say("ed_shaderline <stage|-1> <line|add> [words]: change, add or (with no words) drop a line of the shader in hand");
            return True;
        }
        number = int(args[1]);
        # A field hands its words over as one.
        said = " ".join(" ".join(args[3:]).split());
        lines = shader.lines if number < 0 else (shader.stages[number].lines if number < len(shader.stages) else None);
        if lines is None {
            self.say("ed_shaderline: the shader has no stage " + str(number + 1));
            return True;
        }
        if args[2] == "add" {
            if said {
                lines.append(said);
            }
        } elif args[2].isdigit() and int(args[2]) < len(lines) {
            if said {
                lines[int(args[2])] = said;
            } else {
                lines.pop(int(args[2]));
            }
        } else {
            self.say("ed_shaderline: no such line");
            return True;
        }
        self.shader_dirty = True;
        print(self.shader_words());
        return True;
    }
    if name != "ed_shaderbox" {
        return False;
    }
    stage = self.stage;
    how = args[1] if len(args) > 1 else "";
    casing = self.shader_box;
    if how == "close" or (not how and casing is not None) {
        if casing is not None and stage is not None {
            stage.close(casing);
        }
        self.shader_box = None;
        return True;
    }
    if casing is None and stage is not None {
        casing = Floater(title="Shader", command="ed_shaderbox close", least_wide=300, least_tall=240);
        casing.area = Rect(x=max(8, stage.width - 380), y=100, w=360, h=480);
        casing.settle(stage);
        stage.open(casing);
        self.shader_box = casing;
    }
    self.shader_box_for = "";
    self.keep_shader_box();
    print(self.shader_words());
    return True;
}

impl Studio.preview_shader -> str {
    shader = self.shader_in_hand();
    stock = self.archive;
    if shader is None or stock is None {
        return "No shader is in hand";
    }
    pack: Pk3Assets | None = None;
    try {
        pack = stock.reader().catalog.source("q3").pk3;
    } except Exception {
        return "Quake III's archives are not installed";
    }
    if pack is None {
        return "Quake III's archives are not installed";
    }
    # The shader as it now reads, taken by the game's own parser over what the archives had.
    pack.parse_shaders(write_shaders([shader]));
    stages = pack.model_stages(shader.name);
    if len(stages) == 0 {
        blockers = pack.model_blockers(shader.name);
        return "It draws nothing as it is" + (": " + ", ".join(blockers) if blockers else "");
    }
    # A square standing up, a hundred and twenty-eight units a side, facing the eye.
    corners = [Vec3(y=-64.0, z=0.0), Vec3(y=64.0, z=0.0), Vec3(y=64.0, z=128.0), Vec3(y=-64.0, z=128.0)];
    order = [0, 1, 2, 0, 2, 3];
    places = [0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0];
    flat = AnimatedSurface(
        name=shader.name,
        frames=[AnimationFrame(name="still", vertices=corners, normals=[Vec3(x=-1.0) for corner in corners])],
        indices=order, uv=places, skins=[shader.name], stages=stages
    );
    square = AnimatedModel(surfaces=[flat]);
    drawer = ModelRenderer();
    try {
        drawer.upload(square, [stages[0].texture]);
    } except Exception {
        return "Its pictures could not be loaded";
    }
    self.shader_drawer = drawer;
    shown = ModelLook(game="q3", name="shader:" + shader.name, model=square, frames=1, triangles=2, vertices=4);
    self.model_now = shown;
    self.model_doc = None;
    self.model_frame = 0;
    self.model_edges = [];
    self.model_middle = Vec3(z=64.0);
    self.model_yaw = 0.0;
    self.model_pitch = 0.0;
    self.model_reach = 220.0;
    self.assets_shown = True;
    self.folds += 1;
    ui = self.ui;
    if ui is not None {
        # The explorer lays out its model view for it.
        self.show_asset(ui);
    }
    return "";
}
