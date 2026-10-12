"""The model editor: a model as a graph to edit, shown in the explorer's
model view; its points and triangles picked, moved and reshaped; its frames
copied, named and dropped; read and written as MD3 and OBJ. Declarations
live in studio.jac."""

"""The numbers at the front of a command's words, as far as they are numbers."""
def:priv model_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            return found;
        }
    }
    return found;
}

impl Studio.model_path(name: str) -> str {
    if name.startswith("/") {
        return name;
    }
    folder = os.getenv("QP_MODELS", "");
    if self.project_folder {
        folder = self.project_folder + "/models";
    } elif not folder {
        folder = os.getcwd() + "/models";
    }
    return folder + "/" + name;
}

impl Studio.show_model_doc(reframe: bool) {
    doc = self.model_doc;
    if doc is None {
        return;
    }
    shown = ModelLook(game="", name=doc.name, model=model_of(doc));
    for surface in shown.model.surfaces {
        shown.frames = max(shown.frames, len(surface.frames));
        shown.triangles += len(surface.indices) // 3;
        if len(surface.frames) > 0 {
            shown.vertices += len(surface.frames[0].vertices);
        }
    }
    doc.frame = max(0, min(doc.frame, max(0, shown.frames - 1)));
    self.model_now = shown;
    self.model_frame = doc.frame;
    self.model_edges = shown.edges(doc.frame);
    self.model_seen = doc.revision;
    if reframe {
        box = doc.bounds(doc.frame);
        self.model_yaw = 0.6;
        self.model_pitch = -0.25;
        self.model_middle = box[0].add(box[1]).scale(0.5);
        self.model_reach = max(32.0, box[1].sub(box[0]).length() * 1.2);
    }
    self.folds += 1;
    ui = self.ui;
    if ui is not None {
        self.show_asset(ui);
    }
}

impl Studio.show_model_form(ui: StudioUi) -> bool {
    doc = self.model_doc;
    figure = self.model_now;
    if doc is None or figure is None or figure.game != "" {
        return False;
    }
    form = ui.asset_form;
    part = doc.part();
    form.adopt(Label(text=doc.name + ("  (edited)" if doc.dirty else ""), tone="accent"));
    form.adopt(
        Label(
            text=str(len(doc.parts())) + " parts, " + str(figure.triangles) + " triangles, " + str(figure.vertices)
                + " points, " + str(figure.frames) + " frames",
            tone="dim",
            small=True
        )
    );
    if part is not None {
        form.adopt(
            Label(
                text="In hand: " + part.name + " (" + str(len(part.corners) // 3) + " triangles); picked "
                    + str(len(part.picked_points)) + " points, " + str(len(part.picked_faces)) + " triangles",
                tone="dim",
                small=True
            )
        );
    }
    form.adopt(ui.model_view);
    frames = Box(across=True, gap=4);
    form.adopt(frames);
    frames.adopt(PushButton(text="<", command="ed_frame prev", size=28, hint="The frame before"));
    frames.adopt(PushButton(text=">", command="ed_frame next", size=28, hint="The frame after"));
    frames.adopt(
        PushButton(
            text="Stop" if self.model_playing else "Play",
            command="ed_frame stop" if self.model_playing else "ed_frame play",
            size=56,
            hint="Run through the frames, ten a second"
        )
    );
    frames.adopt(
        Label(text="frame " + str(doc.frame) + " of " + str(doc.frames()) + "   " + doc.frame_name(doc.frame), tone="dim", grow=1)
    );
    frames.adopt(
        PushButton(
            text="Hide list" if self.frames_listed else "List",
            command="ed_model frames",
            size=72,
            hint="Every frame as a row: click one to go to it, drag it to another place in the order"
        )
    );
    if self.frames_listed {
        # Every frame, a row each: a click goes to it, a drag puts it elsewhere in the order.
        listed = ui.frame_list;
        listed.rows = [
            TreeRow(key=str(number), text=doc.frame_name(number), note=str(number), picked=number == doc.frame)
            for number in range(doc.frames())
        ];
        listed.reveal(doc.frame);
        form.adopt(listed);
        naming = Box(across=True, gap=4);
        form.adopt(naming);
        naming.adopt(
            TextField(ghost="Name this frame", command="ed_model frame name", grow=1, hint="Enter gives the frame in hand this name")
        );
        naming.adopt(PushButton(text="Copy", command="ed_model frame copy", hint="A copy of the frame in hand, after it"));
        naming.adopt(PushButton(text="Drop", command="ed_model frame drop", hint="Take the frame in hand out of the model"));
    }
    tools = Box(across=True, gap=4);
    form.adopt(tools);
    tools.adopt(PushButton(text="Undo", command="ed_model undo", hint="Undo the last change to the model"));
    tools.adopt(PushButton(text="Redo", command="ed_model redo", hint="Do it again"));
    tools.adopt(PushButton(text="Check", command="ed_model check", hint="Look for what is wrong with the model"));
    tools.adopt(PushButton(text="Box", command="ed_model box", hint="Draw the box round the model"));
    tools.adopt(PushButton(text="Axes", command="ed_model axes", hint="Draw the model's own axes"));
    shape = Box(across=True, gap=4);
    form.adopt(shape);
    shape.adopt(PushButton(text="Facing me", command="ed_pick front", hint="Pick the triangles that face the view"));
    shape.adopt(PushButton(text="Turn round", command="ed_mesh flip", hint="Turn the picked triangles to face the other way"));
    shape.adopt(PushButton(text="Cut in 4", command="ed_mesh subdivide 4", hint="Cut each picked triangle into four"));
    shape.adopt(PushButton(text="Push out", command="ed_mesh extrude 8", hint="Push the picked triangles out eight units on walls"));
    clicks = Box(across=True, gap=4);
    form.adopt(clicks);
    clicks.adopt(
        PushButton(
            text="Click picks points" if self.model_pick == "faces" else "Click picks triangles",
            command="ed_pick mode " + ("points" if self.model_pick == "faces" else "faces"),
            hint="What a click in the view picks (Shift adds; Ctrl and a drag moves the picked points)"
        )
    );
    clicks.adopt(PushButton(text="Pick nothing", command="ed_pick none", hint="Let go of what is picked"));
    self.skin_view = None;
    if self.skin_shown and self.model_skin is not None {
        # The picture being painted, with the part's triangles over it.
        shown_skin = Picture(key="modelskin", size=168);
        form.adopt(shown_skin);
        self.skin_view = shown_skin;
    }
    return True;
}

impl Studio.pick_in_model(x: int, y: int, add: bool) {
    doc = self.model_doc;
    ui = self.ui;
    if doc is None or ui is None {
        return;
    }
    part = doc.part();
    if part is None {
        return;
    }
    line = self.model_camera.sight(ui_model_area(ui), x, y);
    mesh = doc.mesh(part);
    found = -1;
    if self.model_pick == "points" {
        found = point_under(mesh, line[0], line[1], 0.03);
        if found >= 0 {
            doc.pick_points([found], add);
            part.picked_faces = [];
        } elif not add {
            doc.pick_points([]);
        }
    } else {
        found = face_under(mesh, line[0], line[1]);
        if found >= 0 {
            doc.pick_faces([found], add);
        } elif not add {
            doc.pick_faces([]);
        }
    }
    print("studio: clicked " + self.model_pick + " " + str(found));
}

impl Studio.model_event(event: UiEvent) -> bool {
    doc = self.model_doc;
    figure = self.model_now;
    ui = self.ui;
    if doc is None or figure is None or figure.game != "" or ui is None {
        return False;
    }
    part = doc.part();
    if self.model_pick == "paint" and self.model_skin is not None {
        # The left button paints through the model; any other turns the view.
        if event.kind == "press" and event.button == 0 {
            self.model_painting = True;
            self.paint_in_model(event.x, event.y);
            return True;
        }
        if event.kind == "release" and event.button == 0 {
            self.model_painting = False;
            return True;
        }
        if event.kind == "drag" and self.model_painting {
            self.paint_in_model(event.x, event.y);
            return True;
        }
        if event.kind == "click" and event.button == 0 {
            return True;
        }
    }
    if self.bone_event(event) {
        return True;
    }
    if event.kind == "press" and event.button == 0 and event.alt {
        # With Alt a press takes the tag under the pointer, to be dragged.
        self.tag_held = self.tag_under(event.x, event.y);
        self.model_travel = 0;
        self.model_drag = Vec3();
        if self.tag_held {
            return True;
        }
    }
    if self.tag_held and event.kind == "drag" {
        through = self.model_camera;
        unit = 2.0 * self.model_reach * through.slope() / float(max(1, ui_model_area(ui).h));
        self.model_drag = self.model_drag.add(through.right().scale(float(event.dx) * unit)).sub(
            through.up().scale(float(event.dy) * unit)
        );
        return True;
    }
    if self.tag_held and event.kind in ["release", "click"] and event.button == 0 {
        moved_tag = doc.tag(self.tag_held);
        if event.kind == "release" and moved_tag is not None and self.model_drag.length() > 0.01 and doc.frame < len(moved_tag.origins) {
            # Where the drag left it, at this frame (with Shift, by as much at every frame).
            went = moved_tag.origins[doc.frame].add(self.model_drag);
            doc.move_tag(self.tag_held, went, event.shift);
            print(
                "studio: tag dragged " + self.tag_held + " at=" + str(int(round(went.x))) + "," + str(int(round(went.y))) + ","
                    + str(int(round(went.z))) + (" all" if event.shift else "")
            );
            self.say(self.tag_held + " moved" + (" at every frame" if event.shift else ""));
        }
        if event.kind == "click" or event.kind == "release" {
            self.model_drag = Vec3();
        }
        if event.kind == "click" {
            self.tag_held = "";
        }
        return True;
    }
    if event.kind == "press" and event.button == 0 {
        self.model_travel = 0;
        self.model_drag = Vec3();
        return False;
    }
    if event.kind == "drag" {
        self.model_travel += abs(event.dx) + abs(event.dy);
        if event.ctrl and part is not None and len(part.picked_points) > 0 {
            # With Ctrl the picked points go with the pointer, in the
            # plane of the view; they are moved when the button is let go.
            through = self.model_camera;
            unit = 2.0 * self.model_reach * through.slope() / float(max(1, ui_model_area(ui).h));
            self.model_drag = self.model_drag.add(through.right().scale(float(event.dx) * unit)).sub(
                through.up().scale(float(event.dy) * unit)
            );
            return True;
        }
        return False;
    }
    if event.kind == "release" and event.button == 0 and self.model_drag.length() > 0.01 and part is not None {
        doc.reshape(Reshape(kind="move", picks=list(part.picked_points), vector=self.model_drag, only=doc.frame), "Drag points");
        self.model_drag = Vec3();
        return True;
    }
    if event.kind == "click" and event.button == 0 {
        if self.model_travel <= 3 {
            self.pick_in_model(event.x, event.y, event.shift);
        }
        return True;
    }
    return False;
}

impl Studio.fresh_model {
    self.fresh_skin();
    doc = self.model_doc;
    if doc is not None and doc.revision != self.model_seen {
        # The model being edited has changed: drawn as it now is.
        self.show_model_doc(False);
    }
}

impl Studio.model_words -> str {
    doc = self.model_doc;
    if doc is None {
        return "studio: modeldoc none";
    }
    part = doc.part();
    points = 0;
    triangles = 0;
    picked = "0/0";
    holds = 0.0;
    loose = 0;
    if part is not None {
        mesh = doc.mesh(part);
        points = len(mesh.points);
        triangles = mesh.triangles();
        picked = str(len(part.picked_points)) + "/" + str(len(part.picked_faces));
        holds = mesh_volume(mesh);
        loose = open_edges(mesh);
    }
    box = doc.bounds(doc.frame);
    return "studio: modeldoc " + doc.name + " parts=" + str(len(doc.parts())) + " part=" + str(doc.part_now) + " frames="
        + str(doc.frames()) + " frame=" + str(doc.frame) + ":" + doc.frame_name(doc.frame).replace(" ", "_") + " points="
        + str(points) + " triangles=" + str(triangles) + " picked=" + picked + " volume=" + str(int(round(holds)))
        + " open=" + str(loose) + " low=" + str(int(round(box[0].x))) + "," + str(int(round(box[0].y))) + ","
        + str(int(round(box[0].z))) + " high=" + str(int(round(box[1].x))) + "," + str(int(round(box[1].y))) + ","
        + str(int(round(box[1].z))) + " tags=" + str(len(doc.tags())) + " undo=" + str(len(doc.done)) + " skins="
        + str(len(part.skins) if part is not None else 0) + " pick=" + self.model_pick;
}

impl Studio.draw_model_marks {
    doc = self.model_doc;
    if doc is None {
        return;
    }
    part = doc.part();
    tick = max(0.5, self.model_reach * 0.012);
    if self.model_axes {
        # The model's own axes, from its origin.
        reach = max(8.0, self.model_reach * 0.3);
        wire_line(Vec3(), Vec3(x=reach), ink(0xe5484d));
        wire_line(Vec3(), Vec3(y=reach), ink(0x3ddc97));
        wire_line(Vec3(), Vec3(z=reach), ink(0x4f8ef7));
    }
    if self.model_box {
        box = doc.bounds(doc.frame);
        wire_box(box[0], box[1], ink(0x8a8378));
    }
    for tag in doc.tags() {
        if doc.frame < len(tag.origins) {
            at = tag.origins[doc.frame];
            if tag.name == self.tag_held {
                # Where the drag would leave it.
                at = at.add(self.model_drag);
            }
            wire_line(at.sub(Vec3(x=tick * 2.0)), at.add(Vec3(x=tick * 2.0)), ink(0xffd166));
            wire_line(at.sub(Vec3(y=tick * 2.0)), at.add(Vec3(y=tick * 2.0)), ink(0xffd166));
            wire_line(at.sub(Vec3(z=tick * 2.0)), at.add(Vec3(z=tick * 2.0)), ink(0xffd166));
        }
    }
    self.draw_bones();
    if part is None {
        return;
    }
    mesh = doc.mesh(part);
    for index in part.picked_faces {
        if index < mesh.triangles() {
            spots = mesh.triangle(index);
            wire_line(spots[0], spots[1], ink(0xff7a18));
            wire_line(spots[1], spots[2], ink(0xff7a18));
            wire_line(spots[2], spots[0], ink(0xff7a18));
        }
    }
    for index in part.picked_points {
        if index < len(mesh.points) {
            at = mesh.points[index];
            wire_line(at.sub(Vec3(x=tick)), at.add(Vec3(x=tick)), ink(0xffffff));
            wire_line(at.sub(Vec3(y=tick)), at.add(Vec3(y=tick)), ink(0xffffff));
            wire_line(at.sub(Vec3(z=tick)), at.add(Vec3(z=tick)), ink(0xffffff));
            if self.model_drag.length() > 0.01 {
                # Where the drag would leave it.
                wire_line(at, at.add(self.model_drag), ink(0xff7a18));
            }
        }
    }
}

impl Studio.model_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name != "ed_model" and name != "ed_pick" and name != "ed_mesh" and name != "ed_framedrop" {
        return False;
    }
    app = self.app;
    doc = self.model_doc;
    how = args[1] if len(args) > 1 else "";
    if name == "ed_framedrop" {
        # A row of the frame list let go on another: that frame put there in the order.
        row_words = (args[2] if len(args) > 2 else "").split(" ", 1);
        if doc is None or row_words[0] != "frame" or len(row_words) < 2 or not row_words[1].isdigit() {
            return True;
        }
        moved_frame = int(row_words[1]);
        # Let go under the last row: to the end.
        to_place = int(how) if how.isdigit() else doc.frames() - 1;
        if moved_frame == to_place or moved_frame >= doc.frames() {
            return True;
        }
        self.set_frame(moved_frame);
        return self.model_command(scene, ["ed_model", "frame", "move", str(to_place)]);
    }
    if name == "ed_model" and how in ["new", "add"] {
        kind = args[2] if len(args) > 2 else "";
        sizes = model_numbers(args[3:]);
        if kind not in PRIMITIVE_KINDS {
            self.say("ed_model " + how + " <" + "|".join(PRIMITIVE_KINDS) + "> [w d h] [sides] [tube sides]");
            return True;
        }
        wide = sizes[0] if len(sizes) > 0 else 64.0;
        deep = sizes[1] if len(sizes) > 1 else wide;
        tall = sizes[2] if len(sizes) > 2 else wide;
        made = primitive_mesh(
            kind,
            Vec3(x=-wide * 0.5, y=-deep * 0.5, z=0.0),
            Vec3(x=wide * 0.5, y=deep * 0.5, z=tall),
            int(sizes[3]) if len(sizes) > 3 else 12,
            int(sizes[4]) if len(sizes) > 4 else 6
        );
        if made.triangles() == 0 {
            self.say("That " + kind + " has no room to be made in " + str(int(wide)) + " by " + str(int(deep)) + " by " + str(int(tall)));
            return True;
        }
        if how == "new" or doc is None {
            doc = ModelDoc(name=kind);
            self.model_doc = doc;
        }
        doc.add_part(kind, made);
        self.show_model_doc(how == "new" or len(doc.parts()) == 1);
        if app is not None and not self.assets_shown {
            app.shell.insert_text("ed_layout assets");
        }
        self.say("A " + kind + " of " + str(made.triangles()) + " triangles" + (" added to " + doc.name if how == "add" else ""));
        return True;
    }
    if name == "ed_model" and how == "edit" {
        figure = self.model_now;
        if figure is None {
            self.say("ed_model edit: open a model in the asset explorer first");
            return True;
        }
        label = figure.name.split("/")[-1];
        taken = doc_from_model(figure.model, label.split(".")[0] if label else "model");
        self.model_doc = taken;
        taken.frame = self.model_frame;
        self.show_model_doc(False);
        self.say("Editing " + taken.name + ": " + str(len(taken.parts())) + " parts, " + str(taken.frames()) + " frames");
        return True;
    }
    if name == "ed_model" and how == "open" {
        path = self.model_path(args[2]) if len(args) > 2 else "";
        if not path or not os.path.isfile(path) {
            self.say("ed_model open <file.qpm|file.md3|file.md2|file.mdl|file.obj|file.glb|file.gltf>: no such file " + path);
            return True;
        }
        opened_doc = self.model_file_doc(path);
        if opened_doc is None {
            self.say("ed_model open: " + path + " is not a work file or an MD3, MD2, MDL, OBJ or glTF model this reads");
            return True;
        }
        if os.path.isfile(path + ".rig") and not path.lower().endswith(".qpm") {
            # Its bones, kept beside it.
            try {
                with open(path + ".rig", "r") as file {
                    opened_doc.read_rig(file.read());
                }
                opened_doc.dirty = False;
            } except OSError {
                print("studio: no bones read from " + path + ".rig");
            }
        }
        self.bone_now = "";
        self.model_doc = opened_doc;
        self.show_model_doc(True);
        if app is not None and not self.assets_shown {
            app.shell.insert_text("ed_layout assets");
        }
        self.say("Opened " + path + ": " + str(len(opened_doc.parts())) + " parts, " + str(opened_doc.frames()) + " frames");
        return True;
    }
    if doc is None {
        if name == "ed_model" and not how {
            print(self.model_words());
        }
        self.say("No model is being edited (ed_model new <kind>, ed_model edit, ed_model open <file>)");
        return True;
    }
    part = doc.part();
    if name == "ed_model" {
        if not how {
            print(self.model_words());
            self.say(doc.name + ": " + str(len(doc.parts())) + " parts, " + str(doc.frames()) + " frames");
        } elif how == "close" {
            self.model_doc = None;
            self.model_now = None;
            self.model_edges = [];
            self.folds += 1;
            shown_ui = self.ui;
            if shown_ui is not None {
                self.show_asset(shown_ui);
            }
            self.say("The model is closed");
        } elif how == "part" {
            held = doc.parts();
            wanted_part = args[2] if len(args) > 2 else "";
            for (index, each) in enumerate(held) {
                if wanted_part == str(index) or wanted_part == each.name {
                    doc.part_now = index;
                    doc.revision += 1;
                }
            }
            for (index, each) in enumerate(held) {
                print("studio: part " + str(index) + " " + each.name + " triangles=" + str(len(each.corners) // 3)
                    + (" in hand" if index == doc.part_now else ""));
            }
            self.say("In hand: part " + str(doc.part_now) + " of " + str(len(held)));
        } elif how == "check" {
            faults = doc.faults();
            for fault in faults {
                print("studio: fault " + fault);
            }
            print("studio: faults " + str(len(faults)));
            self.say(str(len(faults)) + " faults: " + "; ".join(faults[:3]) if faults else "Nothing is wrong with the model");
        } elif how == "frames" {
            # The list of frames in the panel, shown or put away.
            word = args[2] if len(args) > 2 else "";
            self.frames_listed = (not self.frames_listed) if word not in ["on", "off"] else word == "on";
            doc.revision += 1;
            print("studio: frames listed=" + ("1" if self.frames_listed else "0") + " " + ",".join([doc.frame_name(number) for number in range(doc.frames())]));
            self.say("The frames are listed under the view: click one to go to it, drag it to move it" if self.frames_listed else "The list of frames is put away");
            return True;
        } elif how == "frame" {
            # The frame in hand (ed_frame goes from one to another).
            what = args[2] if len(args) > 2 else "";
            if what == "copy" {
                doc.copy_frame(doc.frame, " ".join(args[3:]));
            } elif what == "drop" {
                if not doc.drop_frame(doc.frame) {
                    self.say("A model keeps one frame at least");
                    return True;
                }
            } elif what == "name" and len(args) > 3 {
                doc.name_frame(doc.frame, " ".join(args[3:]));
            } elif what == "move" and len(args) > 3 and args[3].isdigit() {
                if not doc.move_frame(doc.frame, int(args[3])) {
                    self.say("ed_model frame move <to>: a place from 0 to " + str(doc.frames() - 1) + " other than its own");
                    return True;
                }
            } else {
                self.say("ed_model frame copy [name] | drop | name <words> | move <to>  (ed_frame <number|next|prev> goes to another)");
                return True;
            }
            self.say("Frame " + str(doc.frame) + " of " + str(doc.frames()) + ": " + doc.frame_name(doc.frame));
        } elif how == "tag" {
            what = args[2] if len(args) > 2 else "";
            label = args[3] if len(args) > 3 else "";
            spot = model_numbers(args[4:]);
            if what == "add" and label {
                # Where it is told, or in the middle of what is picked.
                at = Vec3(x=spot[0], y=spot[1], z=spot[2]) if len(spot) >= 3 else doc.picked_middle();
                if doc.add_tag(label, at) is None {
                    self.say("There is a tag called " + label + " already");
                    return True;
                }
            } elif what == "drop" and label {
                if not doc.drop_tag(label) {
                    self.say("There is no tag called " + label);
                    return True;
                }
            } elif what == "at" and label and len(spot) >= 3 {
                if not doc.move_tag(label, Vec3(x=spot[0], y=spot[1], z=spot[2]), len(args) > 7 and args[7] == "all") {
                    self.say("There is no tag called " + label);
                    return True;
                }
            } elif what == "turn" and label and len(args) > 5 and args[4] in ["x", "y", "z"] and len(model_numbers(args[5:6])) == 1 {
                if not doc.turn_tag(label, ["x", "y", "z"].index(args[4]), model_numbers(args[5:6])[0], len(args) > 6 and args[6] == "all") {
                    self.say("There is no tag called " + label + ", or that is no turn");
                    return True;
                }
                turned_tag = doc.tag(label);
                if turned_tag is not None and doc.frame < len(turned_tag.axes) {
                    # The three ways it faces at this frame, a tenth at a time.
                    faced: list[str] = [];
                    for way in turned_tag.axes[doc.frame] {
                        faced.append(
                            str(round(way.x, 1) + 0.0) + "," + str(round(way.y, 1) + 0.0) + "," + str(round(way.z, 1) + 0.0)
                        );
                    }
                    print("studio: tagaxes " + label + " frame=" + str(doc.frame) + " " + " ".join(faced));
                }
            } elif what {
                self.say("ed_model tag [add <name> [x y z] | drop <name> | at <name> <x y z> [all] | turn <name> <x|y|z> <degrees> [all]]");
                return True;
            }
            for tag in doc.tags() {
                stands = tag.origins[doc.frame] if doc.frame < len(tag.origins) else Vec3();
                print(
                    "studio: tag " + tag.name + " at=" + str(int(round(stands.x))) + "," + str(int(round(stands.y))) + ","
                        + str(int(round(stands.z))) + " frames=" + str(len(tag.origins)) + " seen=" + self.tag_seen(stands)
                );
            }
            self.say(str(len(doc.tags())) + " tags: " + ", ".join([tag.name for tag in doc.tags()]) if doc.tags() else "The model has no tags");
        } elif how == "skin" {
            what = args[2] if len(args) > 2 else "";
            if part is None {
                self.say("The model has no part to skin");
                return True;
            }
            if what == "add" and len(args) > 3 {
                part.skins.append(args[3]);
                doc.dirty = True;
                doc.revision += 1;
            } elif what == "drop" and len(args) > 3 and args[3].isdigit() and int(args[3]) < len(part.skins) {
                part.skins.pop(int(args[3]));
                doc.dirty = True;
                doc.revision += 1;
            } elif what {
                self.say("ed_model skin [add <name> | drop <number>]: the skins of the part in hand");
                return True;
            }
            for (index, skin) in enumerate(part.skins) {
                print("studio: skin " + str(index) + " " + skin);
            }
            self.say(part.name + " has " + str(len(part.skins)) + " skins: " + ", ".join(part.skins) if part.skins else part.name + " names no skin");
        } elif how == "match" {
            self.say("Gave " + str(doc.match_frames()) + " parts the frames the first has");
        } elif how == "box" or how == "axes" {
            now_on = (not self.model_box) if how == "box" else (not self.model_axes);
            if len(args) > 2 and args[2] in ["on", "off"] {
                now_on = args[2] == "on";
            }
            if how == "box" {
                self.model_box = now_on;
                box = doc.bounds(doc.frame);
                extent = box[1].sub(box[0]);
                self.say("The model's box is " + str(int(round(extent.x))) + " by " + str(int(round(extent.y))) + " by " + str(int(round(extent.z))));
            } else {
                self.model_axes = now_on;
            }
        } elif how == "undo" or how == "redo" {
            label = doc.undo() if how == "undo" else doc.redo();
            self.say(("Undid " if how == "undo" else "Redid ") + label if label else "Nothing to " + how);
        } elif how == "save" and len(args) > 2 {
            path = self.model_path(args[2]);
            data = self.model_file_bytes(doc, path);
            if len(data) == 0 {
                self.say("ed_model save <file.qpm|file.md3|file.md2|file.mdl|file.obj|file.glb>: nothing to write there (ed_model check)");
                return True;
            }
            try {
                os.makedirs(os.path.dirname(path), exist_ok=True);
                with open(path, "wb") as file {
                    file.write(data);
                }
            } except OSError {
                self.say("ed_model save: could not write " + path);
                return True;
            }
            if len(doc.bones()) > 0 and not path.lower().endswith(".qpm") {
                # The games' formats keep no bones: they go in a file beside the model.
                try {
                    with open(path + ".rig", "w") as file {
                        file.write(doc.rig_text());
                    }
                } except OSError {
                    print("studio: could not write " + path + ".rig");
                }
            }
            doc.dirty = False;
            print("studio: saved model " + path + " bytes=" + str(len(data)));
            self.say("Saved " + path);
        } else {
            self.say("ed_model [new|add <kind>] [edit] [open|save <file>] [part <n>] [frame copy|drop|name|move] [tag ...] [skin ...] [check] [match] [box] [axes] [undo|redo] [close]");
        }
        return True;
    }
    if part is None {
        self.say("The model has no part to work on");
        return True;
    }
    mesh = doc.mesh(part);
    if name == "ed_pick" {
        adding = len(args) > 2 and args[-1] == "add";
        rest = [int(number) for number in model_numbers(args[2:])];
        if how == "points" {
            if len(args) > 2 and args[2] == "all" {
                rest = list(range(len(mesh.points)));
            }
            doc.pick_points(rest, adding);
            part.picked_faces = [];
        } elif how == "faces" {
            if len(args) > 2 and args[2] == "all" {
                rest = list(range(mesh.triangles()));
            }
            doc.pick_faces(rest, adding);
        } elif how == "mode" and len(args) > 2 and args[2] in ["points", "faces", "paint"] {
            # What a click in the view picks.
            self.model_pick = args[2];
            doc.revision += 1;
        } elif how == "find" and len(args) > 3 and args[2] in ["points", "faces", "point", "face"] and args[3].isdigit() {
            # By its number: picked, and said.
            rest = [int(args[3])];
            of_faces = args[2].startswith("face");
            said_of = mesh_found(mesh, of_faces, rest[0]);
            if not said_of {
                self.say("There is no " + ("triangle" if of_faces else "point") + " " + str(rest[0]) + " in " + part.name);
                return True;
            }
            if of_faces {
                doc.pick_faces(rest);
            } else {
                doc.pick_points(rest);
                part.picked_faces = [];
            }
            print("studio: found " + said_of);
            self.say(said_of.replace("=", " ").replace(",", ", "));
            return True;
        } elif how == "front" or how == "back" {
            doc.pick_facing(self.model_camera.forward(), how == "front");
        } elif how == "none" or not how {
            doc.pick_faces([]);
            doc.pick_points([]);
        } else {
            self.say("ed_pick points|faces <numbers|all> [add] | find points|faces <number> | front | back | none | mode points|faces");
            return True;
        }
        self.say("Picked " + str(len(part.picked_points)) + " points and " + str(len(part.picked_faces)) + " triangles");
        return True;
    }
    # ed_mesh: a tool carried to the part in hand.
    every = len(args) > 2 and args[-1] == "all";
    numbers = model_numbers(args[2:]);
    picks = part.picked_points if len(part.picked_points) > 0 else list(range(len(mesh.points)));
    faces = part.picked_faces if len(part.picked_faces) > 0 else list(range(mesh.triangles()));
    one = -1 if every else doc.frame;
    axis_word = args[2] if len(args) > 2 else "";
    axis = 0 if axis_word == "x" else (1 if axis_word == "y" else 2);
    done = False;
    if how == "move" and len(numbers) == 3 {
        done = doc.reshape(Reshape(kind="move", picks=picks, vector=Vec3(x=numbers[0], y=numbers[1], z=numbers[2]), only=one), "Move points");
    } elif how == "turn" and axis_word in ["x", "y", "z"] and len(model_numbers(args[3:])) > 0 {
        done = doc.reshape(
            Reshape(kind="turn", picks=picks, pivot=doc.picked_middle(), axis=axis, amount=model_numbers(args[3:])[0], only=one),
            "Turn points"
        );
    } elif how == "scale" and len(numbers) > 0 {
        factors = Vec3(x=numbers[0], y=numbers[1] if len(numbers) > 2 else numbers[0], z=numbers[2] if len(numbers) > 2 else numbers[0]);
        done = doc.reshape(Reshape(kind="scale", picks=picks, pivot=doc.picked_middle(), vector=factors, only=one), "Stretch points");
    } elif how == "mirror" and axis_word in ["x", "y", "z"] {
        middle = doc.bounds(doc.frame);
        along = middle[0].add(middle[1]).scale(0.5);
        done = doc.reshape(
            Reshape(kind="mirror", axis=axis, amount=along.x if axis == 0 else (along.y if axis == 1 else along.z)), "Mirror"
        );
    } elif how == "flip" {
        done = doc.reshape(Reshape(kind="flip", faces=faces), "Turn triangles round");
    } elif how == "subdivide" and len(numbers) > 0 and int(numbers[0]) in [2, 3, 4] {
        done = doc.reshape(Reshape(kind="subdivide", faces=faces, count=int(numbers[0])), "Cut triangles");
    } elif how == "cut" and axis_word in ["x", "y", "z"] {
        # Across an axis, where told or through the middle of what is picked.
        cut_at = model_numbers(args[3:]);
        through = doc.picked_middle();
        if len(cut_at) > 0 {
            through = Vec3(
                x=cut_at[0] if axis == 0 else through.x, y=cut_at[0] if axis == 1 else through.y, z=cut_at[0] if axis == 2 else through.z
            );
        }
        across_it = Vec3(x=1.0 if axis == 0 else 0.0, y=1.0 if axis == 1 else 0.0, z=1.0 if axis == 2 else 0.0);
        done = doc.reshape(Reshape(kind="cut", faces=faces, pivot=through, vector=across_it), "Cut along a plane");
    } elif how == "extrude" and len(numbers) > 0 and len(part.picked_faces) > 0 {
        done = doc.reshape(
            Reshape(kind="extrude", faces=faces, amount=numbers[0], bulk=len(args) > 3 and args[3] == "bulk"), "Extrude"
        );
    } else {
        self.say(
            "ed_mesh move <dx dy dz> | turn <x|y|z> <degrees> | scale <f> or <fx fy fz> | mirror <x|y|z> | flip | subdivide <2|3|4> | cut <x|y|z> [at] | extrude <distance> [bulk]  (move, turn and scale: this frame, or every frame with all)"
        );
        return True;
    }
    self.say("Done: " + doc.done[-1].label if done and len(doc.done) > 0 else "That changed nothing");
    return True;
}

impl Studio.tag_under(x: int, y: int) -> str {
    doc = self.model_doc;
    ui = self.ui;
    if doc is None or ui is None {
        return "";
    }
    area = ui_model_area(ui);
    found = "";
    nearest = 14 * 14;
    for tag in doc.tags() {
        if doc.frame >= len(tag.origins) {
            continue;
        }
        at = self.model_camera.project(area, tag.origins[doc.frame]);
        if at is None {
            continue;
        }
        away = (at[0] - x) * (at[0] - x) + (at[1] - y) * (at[1] - y);
        if away < nearest {
            nearest = away;
            found = tag.name;
        }
    }
    return found;
}

impl Studio.tag_seen(at: Vec3) -> str {
    ui = self.ui;
    if ui is None {
        return "nowhere";
    }
    shown_at = self.model_camera.project(ui_model_area(ui), at);
    return str(shown_at[0]) + "," + str(shown_at[1]) if shown_at is not None else "nowhere";
}
