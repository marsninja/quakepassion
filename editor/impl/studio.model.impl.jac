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
    return True;
}

impl Studio.fresh_model {
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
        + str(int(round(box[1].z))) + " tags=" + str(len(doc.tags())) + " undo=" + str(len(doc.done));
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
            wire_line(at.sub(Vec3(x=tick * 2.0)), at.add(Vec3(x=tick * 2.0)), ink(0xffd166));
            wire_line(at.sub(Vec3(y=tick * 2.0)), at.add(Vec3(y=tick * 2.0)), ink(0xffd166));
            wire_line(at.sub(Vec3(z=tick * 2.0)), at.add(Vec3(z=tick * 2.0)), ink(0xffd166));
        }
    }
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
        }
    }
}

impl Studio.model_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name != "ed_model" and name != "ed_pick" and name != "ed_mesh" {
        return False;
    }
    app = self.app;
    doc = self.model_doc;
    how = args[1] if len(args) > 1 else "";
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
            self.say("ed_model open <file.obj|file.md3>: no such file " + path);
            return True;
        }
        label = os.path.basename(path).split(".")[0];
        opened_doc: ModelDoc | None = None;
        try {
            if path.lower().endswith(".obj") {
                text = "";
                with open(path, "r") as file {
                    text = file.read();
                }
                read = obj_mesh(text);
                if read.triangles() > 0 {
                    opened_doc = ModelDoc(name=label);
                    opened_doc.add_part(label, read);
                    opened_doc.dirty = False;
                }
            } elif path.lower().endswith(".md3") {
                data = b"";
                with open(path, "rb") as file {
                    data = file.read();
                }
                opened_doc = doc_from_model(parse_md3(data), label);
            }
        } except Exception {
            opened_doc = None;
        }
        if opened_doc is None {
            self.say("ed_model open: " + path + " is not an OBJ or MD3 model this reads");
            return True;
        }
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
            } else {
                self.say("ed_model frame copy [name] | drop | name <words>  (ed_frame <number|next|prev> goes to another)");
                return True;
            }
            self.say("Frame " + str(doc.frame) + " of " + str(doc.frames()) + ": " + doc.frame_name(doc.frame));
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
            data = b"";
            if path.lower().endswith(".obj") and part is not None {
                data = mesh_obj(doc.mesh(part), doc.name).encode("utf-8");
            } elif path.lower().endswith(".md3") {
                limits = md3_limits(doc);
                for limit in limits {
                    print("studio: limit " + limit);
                }
                data = write_md3(doc);
            }
            if len(data) == 0 {
                self.say("ed_model save <file.obj|file.md3>: nothing to write there (ed_model check)");
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
            doc.dirty = False;
            print("studio: saved model " + path + " bytes=" + str(len(data)));
            self.say("Saved " + path);
        } else {
            self.say("ed_model [new|add <kind>] [edit] [open|save <file>] [part <n>] [frame copy|drop|name] [check] [match] [box] [axes] [undo|redo] [close]");
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
        } elif how == "front" or how == "back" {
            doc.pick_facing(self.model_camera.forward(), how == "front");
        } elif how == "none" or not how {
            doc.pick_faces([]);
            doc.pick_points([]);
        } else {
            self.say("ed_pick points|faces <numbers|all> [add] | front | back | none");
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
    } elif how == "extrude" and len(numbers) > 0 and len(part.picked_faces) > 0 {
        done = doc.reshape(
            Reshape(kind="extrude", faces=faces, amount=numbers[0], bulk=len(args) > 3 and args[3] == "bulk"), "Extrude"
        );
    } else {
        self.say(
            "ed_mesh move <dx dy dz> | turn <x|y|z> <degrees> | scale <f> or <fx fy fz> | mirror <x|y|z> | flip | subdivide <2|3|4> | extrude <distance> [bulk]  (move, turn and scale: this frame, or every frame with all)"
        );
        return True;
    }
    self.say("Done: " + doc.done[-1].label if done and len(doc.done) > 0 else "That changed nothing");
    return True;
}
