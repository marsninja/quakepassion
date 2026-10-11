"""The model editor's skin: where a part's points lie on its picture, moved,
stretched, turned, flipped and laid flat; and the picture itself, painted on
the skin or through the model. Declarations live in studio.jac."""

"""The numbers at the front of a command's words, as far as they are numbers."""
def:priv skin_numbers(words: list[str]) -> list[float] {
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

impl Studio.skin_words -> str {
    doc = self.model_doc;
    part = doc.part() if doc is not None else None;
    image = self.model_skin;
    if doc is None or part is None {
        return "studio: skin none";
    }
    box = places_box(part.uvs, []);
    return "studio: skin part=" + part.name + " placed=" + ("1" if len(part.uvs) > 0 else "0") + " box="
        + str(round(box[0], 3)) + "," + str(round(box[1], 3)) + "," + str(round(box[2], 3)) + "," + str(round(box[3], 3))
        + " image=" + (str(image.width) + "x" + str(image.height) if image is not None else "none") + " dabs="
        + str(self.skin_dabs) + " shown=" + ("1" if self.skin_shown else "0");
}

impl Studio.paint_in_model(x: int, y: int) -> bool {
    doc = self.model_doc;
    ui = self.ui;
    image = self.model_skin;
    if doc is None or ui is None or image is None {
        return False;
    }
    part = doc.part();
    if part is None {
        return False;
    }
    line = self.model_camera.sight(ui_model_area(ui), x, y);
    place = place_under(doc.mesh(part), line[0], line[1]);
    if place is None {
        return False;
    }
    skin_dab(image, place[0], place[1], self.skin_radius, self.skin_color, self.skin_soft, self.skin_strength);
    self.skin_dabs += 1;
    self.skin_stale = True;
    print("studio: painted at " + str(round(place[0], 2)) + "," + str(round(place[1], 2)));
    return True;
}

impl Studio.fresh_skin {
    image = self.model_skin;
    if image is not None and self.skin_stale {
        # The picture as it now is, for the panel to show.
        self.canvas.keep_picture("modelskin", image.width, image.height, bytes(image.texels));
        self.skin_stale = False;
    }
}

impl Studio.draw_skin_marks {
    doc = self.model_doc;
    view = self.skin_view;
    if doc is None or view is None or not self.skin_shown or self.model_skin is None or view.parent() is None {
        return;
    }
    part = doc.part();
    image = self.model_skin;
    whole = view.area;
    if part is None or image is None or whole.w <= 8 or whole.h <= 8 or len(part.uvs) == 0 {
        return;
    }
    canvas = self.canvas;
    # Where the picture itself is drawn in its widget: as large as fits, in its middle.
    wide = image.width;
    tall = image.height;
    if wide * (whole.h - 8) > tall * (whole.w - 8) {
        tall = max(1, tall * (whole.w - 8) // wide);
        wide = whole.w - 8;
    } else {
        wide = max(1, wide * (whole.h - 8) // tall);
        tall = whole.h - 8;
    }
    area = Rect(x=whole.x + (whole.w - wide) // 2, y=whole.y + (whole.h - tall) // 2, w=wide, h=tall);
    # The part's triangles as they lie on the picture, and what is picked.
    for index in range(len(part.corners) // 3) {
        for k in range(3) {
            first = part.corners[index * 3 + k];
            second = part.corners[index * 3 + (k + 1) % 3];
            if first * 2 + 1 >= len(part.uvs) or second * 2 + 1 >= len(part.uvs) {
                continue;
            }
            canvas.line(
                area.x + int(part.uvs[first * 2] * float(area.w)),
                area.y + int(part.uvs[first * 2 + 1] * float(area.h)),
                area.x + int(part.uvs[second * 2] * float(area.w)),
                area.y + int(part.uvs[second * 2 + 1] * float(area.h)),
                canvas.theme.dim
            );
        }
    }
    for at in part.picked_points {
        if at * 2 + 1 < len(part.uvs) {
            spot_x = area.x + int(part.uvs[at * 2] * float(area.w));
            spot_y = area.y + int(part.uvs[at * 2 + 1] * float(area.h));
            canvas.fill(Rect(x=spot_x - 2, y=spot_y - 2, w=5, h=5), canvas.theme.accent);
        }
    }
}

impl Studio.skin_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_skin" {
        return False;
    }
    doc = self.model_doc;
    part = doc.part() if doc is not None else None;
    how = args[1] if len(args) > 1 else "";
    numbers = skin_numbers(args[2:]);
    if doc is None or part is None {
        self.say("No model is being edited (ed_model new <kind>, ed_model edit)");
        return True;
    }
    if not how {
        print(self.skin_words());
        return True;
    }
    image = self.model_skin;
    picks = list(part.picked_points);
    mesh = doc.mesh(part);
    if how == "move" and len(numbers) >= 2 {
        doc.reskin(places_moved(part.uvs, picks, numbers[0], numbers[1]), "Move on skin");
    } elif how == "scale" and len(numbers) >= 1 {
        doc.reskin(places_scaled(part.uvs, picks, numbers[0], numbers[1] if len(numbers) > 1 else numbers[0]), "Stretch on skin");
    } elif how == "turn" and len(numbers) >= 1 {
        doc.reskin(places_turned(part.uvs, picks, numbers[0]), "Turn on skin");
    } elif how == "flip" and len(args) > 2 and args[2] in ["u", "v"] {
        doc.reskin(places_flipped(part.uvs, picks, args[2]), "Flip on skin");
    } elif how == "project" and len(args) > 2 and args[2] in ["x", "y", "z"] {
        onto = skin_numbers(args[3:]);
        doc.reskin(
            places_projected(mesh, picks, 0 if args[2] == "x" else (1 if args[2] == "y" else 2), onto if len(onto) == 4 else [0.0, 0.0, 1.0, 1.0]),
            "Lay flat on skin"
        );
    } elif how == "new" and len(numbers) >= 2 {
        tint = [int(numbers[2]), int(numbers[3]), int(numbers[4])] if len(numbers) >= 5 else [128, 128, 128];
        self.model_skin = skin_filled(max(4, min(1024, int(numbers[0]))), max(4, min(1024, int(numbers[1]))), tint);
        self.skin_dabs = 0;
        self.skin_stale = True;
    } elif how == "open" and len(args) > 2 {
        read: Skin | None = None;
        try {
            with open(self.model_path(args[2]), "rb") as file {
                read = tga_skin(file.read());
            }
        } except OSError {
            read = None;
        }
        if read is None {
            self.say("ed_skin open: " + args[2] + " is not an uncompressed TGA this reads");
            return True;
        }
        self.model_skin = read;
        self.skin_dabs = 0;
        self.skin_stale = True;
    } elif how == "save" and len(args) > 2 and image is not None {
        path = self.model_path(args[2]);
        try {
            os.makedirs(os.path.dirname(path), exist_ok=True);
            with open(path, "wb") as file {
                file.write(skin_tga(image));
            }
        } except OSError {
            self.say("ed_skin save: could not write " + path);
            return True;
        }
        print("studio: saved skin " + path);
    } elif how == "colour" and len(numbers) >= 3 {
        self.skin_color = [max(0, min(255, int(numbers[0]))), max(0, min(255, int(numbers[1]))), max(0, min(255, int(numbers[2])))];
    } elif how == "brush" and len(numbers) >= 1 {
        self.skin_radius = max(0.5, min(128.0, numbers[0]));
        self.skin_soft = "soft" in args;
        self.skin_strength = max(0.05, min(1.0, numbers[1])) if len(numbers) > 1 else 1.0;
    } elif how == "dab" and len(numbers) >= 2 and image is not None {
        skin_dab(image, numbers[0], numbers[1], self.skin_radius, self.skin_color, self.skin_soft, self.skin_strength);
        self.skin_dabs += 1;
        self.skin_stale = True;
    } elif how == "show" {
        self.skin_shown = not self.skin_shown;
        if len(args) > 2 and args[2] in ["on", "off"] {
            self.skin_shown = args[2] == "on";
        }
        doc.revision += 1;
    } else {
        self.say(
            "ed_skin move <du dv> | scale <f> [fv] | turn <degrees> | flip u|v | project x|y|z [u0 v0 u1 v1] | new <w h> [r g b] | open|save <file.tga> | colour <r g b> | brush <radius> [soft] | dab <u v> | show"
        );
        return True;
    }
    print(self.skin_words());
    return True;
}
