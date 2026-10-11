"""The studio's model files: a model written as each game's own file or as
a work file that keeps everything, and read from them. Declarations live in
studio.jac."""

impl Studio.quake_palette -> bytes {
    stock = self.archive;
    if stock is not None {
        known = self.asset_index;
        if known is None {
            known = AssetIndex(shelf=stock);
            self.asset_index = known;
        }
        colours = known.read("q1", "gfx/palette.lmp");
        if colours is not None and len(colours) == 768 {
            return colours;
        }
    }
    # Without Quake at hand: greys, so a skin keeps its lights and darks.
    return grey_palette();
}

impl Studio.model_file_bytes(doc: ModelDoc, path: str) -> bytes {
    kind = path.lower().split(".")[-1];
    painted = self.model_skin;
    limits: list[str] = [];
    data = b"";
    if kind == "obj" {
        part = doc.part();
        data = mesh_obj(doc.mesh(part), doc.name).encode("utf-8") if part is not None else b"";
    } elif kind == "md3" {
        limits = md3_limits(doc);
        data = write_md3(doc);
    } elif kind == "md2" {
        limits = md2_limits(doc);
        # Its places on the skin are whole texels of the skin in hand.
        data = write_md2(doc, painted.width if painted is not None else 256, painted.height if painted is not None else 256);
    } elif kind == "mdl" {
        limits = mdl_limits(doc);
        if painted is not None {
            # The skin in hand goes inside the file, in Quake's own colours.
            data = write_mdl(doc, painted.width, painted.height, palette_indices(bytes(painted.texels), self.quake_palette()));
        } else {
            data = write_mdl(doc);
        }
    } elif kind == "qpm" {
        data = work_text(doc).encode("utf-8");
    } elif kind == "glb" {
        # Every part as it stands at the frame in hand.
        held: list[tuple[str, Mesh]] = [];
        for each in doc.parts() {
            held.append((each.name, doc.mesh(each)));
        }
        data = write_glb(held, doc.name);
    }
    for limit in limits {
        print("studio: limit " + limit);
    }
    return data;
}

impl Studio.model_file_doc(path: str) -> ModelDoc | None {
    kind = path.lower().split(".")[-1];
    label = os.path.basename(path).split(".")[0];
    made: ModelDoc | None = None;
    try {
        if kind == "obj" or kind == "qpm" {
            text = "";
            with open(path, "r") as file {
                text = file.read();
            }
            if kind == "qpm" {
                made = doc_from_work(text);
            } else {
                read = obj_mesh(text);
                if read.triangles() > 0 {
                    made = ModelDoc(name=label);
                    made.add_part(label, read);
                    made.dirty = False;
                }
            }
        } elif kind == "glb" or kind == "gltf" {
            packed = b"";
            with open(path, "rb") as file {
                packed = file.read();
            }
            pieces = read_gltf(packed);
            if pieces is not None {
                made = ModelDoc(name=label);
                for (called, piece) in pieces {
                    made.add_part(called, piece);
                }
                made.part_now = 0;
                made.dirty = False;
            }
        } elif kind in ["md3", "md2", "mdl"] {
            data = b"";
            with open(path, "rb") as file {
                data = file.read();
            }
            if kind == "md3" {
                made = doc_from_model(parse_md3(data), label);
            } elif kind == "md2" {
                made = doc_from_model(parse_md2(data), label);
            } else {
                inside = parse_mdl(data, self.quake_palette());
                made = doc_from_model(inside, label);
                if len(inside.surfaces) > 0 and len(inside.surfaces[0].embedded_skins) > 0 {
                    # The skin an MDL has inside it is the skin in hand.
                    picture = inside.surfaces[0].embedded_skins[0];
                    self.model_skin = Skin(width=picture.width, height=picture.height, texels=bytearray(picture.pixels));
                    self.skin_dabs = 0;
                    self.skin_stale = True;
                }
            }
        }
    } except Exception {
        made = None;
    }
    if made is not None and len(made.parts()) == 0 {
        return None;
    }
    return made;
}
