"""The studio's maps for other tools: a scene written as a map in Valve's
form, the classic one or Quake III's own, and a Quake III map's materials
found among the game's when it is opened. Declarations live in studio.jac."""

impl Studio.file_material(name: str) -> str {
    # Quake III's maps leave the folder every texture is in unsaid.
    if name.startswith("q3:textures/") {
        return name[12:];
    }
    return name[3:] if name.startswith("q3:") else name;
}

impl Studio.scene_material(name: str) -> str {
    stock = self.archive;
    if stock is None or ":" in name or not name {
        return name;
    }
    for wanted in ["q3:textures/" + name, "q3:" + name] {
        if stock.fetch(wanted) is not None {
            return wanted;
        }
    }
    return name;
}

impl Studio.texture_sizes(names: list[str], as_file: bool) -> dict[str, list[int]] {
    sizes: dict[str, list[int]] = {};
    for name in names {
        # By the name a file has for it: the size of the texture the scene knows it by.
        known = name if as_file else self.scene_material(name);
        image = self.materials.texture(known);
        sizes[self.file_material(name) if as_file else name] = [max(1, image.width), max(1, image.height)];
    }
    return sizes;
}

impl Studio.q3map_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_export" {
        return False;
    }
    form = args[2] if len(args) > 2 else "valve";
    if len(args) < 2 or form not in ["valve", "classic", "q3"] or not args[1].lower().endswith(".map") {
        self.say("ed_export <file.map> [valve|classic|q3]: the scene as a map for another tool");
        return True;
    }
    if not self.is_built_scene() {
        self.say("ed_export writes a scene of brushes (ed_convert makes one of a shipped level)");
        return True;
    }
    written = scene_map(scene);
    text = "";
    if form == "q3" {
        # Brushes with a matrix a side, patches as patches, materials as Quake III's tools name them.
        whole = with_patches(written);
        used = map_materials(whole);
        renames: dict[str, str] = {};
        for each in used {
            renames[each] = self.file_material(each);
        }
        text = write_map(
            map_renamed(whole, renames), "primitives", False, self.map_comments, self.map_whole, self.texture_sizes(used, True)
        );
    } else {
        text = write_map(written, form, False, self.map_comments, self.map_whole);
    }
    try {
        folder = os.path.dirname(args[1]);
        if folder {
            os.makedirs(folder, exist_ok=True);
        }
        with open(args[1], "w") as file {
            file.write(text);
        }
    } except OSError {
        self.say("ed_export: could not write " + args[1]);
        return True;
    }
    print(
        "studio: exported " + os.path.basename(args[1]) + " form=" + form + " brushes=" + str(text.count("// brush ") if self.map_comments else -1)
            + " primitives=" + str(text.count("brushDef")) + " patches=" + str(text.count("patchDef2")) + " bytes=" + str(len(text))
    );
    self.say("Wrote " + args[1] + " in " + ("Quake III's" if form == "q3" else ("Valve's" if form == "valve" else "the classic")) + " form");
    return True;
}
