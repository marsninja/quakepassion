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
    skin_dab(image, place[0], place[1], self.skin_radius, self.skin_color, self.skin_soft, self.skin_strength, self.skin_pattern, self.skin_grain);
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
    # While picked places are dragged, they are drawn where they would go.
    moved_by = self.skin_drag;
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
    for face in part.picked_faces {
        # A picked triangle is outlined on the picture as in the model.
        for k in range(3) {
            if face * 3 + 2 >= len(part.corners) {
                break;
            }
            first = part.corners[face * 3 + k];
            second = part.corners[face * 3 + (k + 1) % 3];
            if first * 2 + 1 < len(part.uvs) and second * 2 + 1 < len(part.uvs) {
                canvas.line(
                    area.x + int(part.uvs[first * 2] * float(area.w)),
                    area.y + int(part.uvs[first * 2 + 1] * float(area.h)),
                    area.x + int(part.uvs[second * 2] * float(area.w)),
                    area.y + int(part.uvs[second * 2 + 1] * float(area.h)),
                    ink(0xff7a18)
                );
            }
        }
    }
    for at in part.picked_points {
        if at * 2 + 1 < len(part.uvs) {
            spot_x = area.x + int((part.uvs[at * 2] + moved_by[0]) * float(area.w));
            spot_y = area.y + int((part.uvs[at * 2 + 1] + moved_by[1]) * float(area.h));
            canvas.fill(Rect(x=spot_x - 2, y=spot_y - 2, w=5, h=5), canvas.theme.accent);
        }
    }
}

impl Studio.skin_events {
    view = self.skin_view;
    doc = self.model_doc;
    image = self.model_skin;
    if view is None {
        return;
    }
    taken = view.take();
    part = doc.part() if doc is not None else None;
    if doc is None or part is None or image is None or len(part.uvs) == 0 {
        return;
    }
    whole = view.area;
    rect = skin_rect(whole.w, whole.h, image.width, image.height);
    for event in taken {
        place = skin_place(rect, event.x - whole.x, event.y - whole.y);
        if event.kind == "press" and event.button == 0 {
            self.skin_drag = [0.0, 0.0];
            self.skin_press = [];
            under = place_nearest(part.uvs, place[0], place[1], 0.04) if len(place) == 2 else -1;
            if under >= 0 and under in part.picked_points {
                # A drag from a picked point carries all of the picked.
                self.skin_press = place;
            }
        } elif event.kind == "drag" and len(self.skin_press) == 2 and len(place) == 2 {
            self.skin_drag = [place[0] - self.skin_press[0], place[1] - self.skin_press[1]];
        } elif event.kind == "release" and event.button == 0 and len(self.skin_press) == 2 {
            moved = self.skin_drag;
            self.skin_press = [];
            self.skin_drag = [0.0, 0.0];
            if abs(moved[0]) + abs(moved[1]) > 0.002 {
                doc.reskin(places_moved(part.uvs, list(part.picked_points), moved[0], moved[1]), "Drag on skin");
                print("studio: skin dragged by " + str(round(moved[0], 3)) + "," + str(round(moved[1], 3)));
                # Let go after a drag: no click follows to pick.
                self.skin_press = [-1.0];
            }
        } elif event.kind == "click" and event.button == 0 {
            if len(self.skin_press) == 1 {
                self.skin_press = [];
                continue;
            }
            if len(place) != 2 {
                continue;
            }
            if self.model_pick == "faces" {
                face = triangle_at(part.corners, part.uvs, place[0], place[1]);
                if face >= 0 {
                    doc.pick_faces([face], event.shift);
                } elif not event.shift {
                    doc.pick_faces([]);
                }
                print("studio: skin clicked face " + str(face));
            } else {
                point = place_nearest(part.uvs, place[0], place[1], 0.04);
                if point >= 0 {
                    doc.pick_points([point], event.shift);
                    part.picked_faces = [];
                } elif not event.shift {
                    doc.pick_points([]);
                }
                print("studio: skin clicked point " + str(point));
            }
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
    } elif how == "import" and len(args) > 2 {
        # A picture out of a game's archives: a PCX, a WAL, an uncompressed TGA, or a Quake model's own skin.
        parts = args[2].split(":", 1);
        taken = self.skin_from(parts[0], parts[1], int(numbers[0]) if len(numbers) > 0 else 0) if len(parts) == 2 else None;
        if taken is None {
            self.say("ed_skin import <q1|q2|q3>:<file> [n]: a PCX, WAL or plain TGA of that game, or the n-th skin of a Quake model");
            return True;
        }
        self.model_skin = taken;
        self.skin_dabs = 0;
        self.skin_stale = True;
        self.skin_shown = True;
        print("studio: skin imported " + args[2] + " " + str(taken.width) + "x" + str(taken.height));
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
        skin_dab(image, numbers[0], numbers[1], self.skin_radius, self.skin_color, self.skin_soft, self.skin_strength, self.skin_pattern, self.skin_grain);
        self.skin_dabs += 1;
        self.skin_stale = True;
    } elif how == "pickat" and len(numbers) >= 2 {
        # What a click on the picture at that place picks.
        added = "add" in args;
        if self.model_pick == "faces" {
            face = triangle_at(part.corners, part.uvs, numbers[0], numbers[1]);
            doc.pick_faces([face] if face >= 0 else [], added);
        } else {
            point = place_nearest(part.uvs, numbers[0], numbers[1], 0.04);
            doc.pick_points([point] if point >= 0 else [], added);
        }
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

impl Studio.skin_from(game: str, name: str, number: int) -> Skin | None {
    stock = self.archive;
    if stock is None or game not in ["q1", "q2", "q3"] {
        return None;
    }
    listing = self.asset_index;
    if listing is None {
        listing = AssetIndex(shelf=stock);
        self.asset_index = listing;
    }
    low = name.lower();
    picture: Texture | None = None;
    if low.endswith(".mdl") {
        # A Quake model carries its skins inside it.
        figure = load_model(stock, game, name);
        if figure is not None and len(figure.model.surfaces) > 0 {
            kept = figure.model.surfaces[0].embedded_skins;
            if number >= 0 and number < len(kept) {
                picture = kept[number];
            }
        }
    } else {
        seen = listing.look(game, name);
        picture = seen.image;
        if picture is not None and len(texture_rgba(picture)) == 0 and low.endswith(".tga") {
            data = listing.read(game, name);
            return tga_skin(data) if data is not None else None;
        }
    }
    if picture is None {
        return None;
    }
    colours = texture_rgba(picture);
    if len(colours) == 0 {
        return None;
    }
    texels = bytearray(colours[:picture.width * picture.height * 4]);
    # A skin is solid all over: the games mark some colours by their alpha, which a picture to paint on has no use for.
    for index in range(3, len(texels), 4) {
        texels[index] = 255;
    }
    return Skin(width=picture.width, height=picture.height, texels=texels);
}
