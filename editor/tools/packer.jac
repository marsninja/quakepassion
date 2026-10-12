"""A project packed to give away: its scenes, and of everything else only
what they use: the prefabs they link, the pictures of their materials and
the sounds and models their entities name. A tool of the studio in a module
of its own (see editor/tools/host.jac)."""
import os;
import from editor.tools.host { ToolHost, StudioTool }
import from editor.document.scene { Scene }
import from editor.formats.map { read_map, MapItem, map_materials }
import from editor.formats.archive { write_pak, write_zip }
import from editor.assets.needs { needed_files, material_spots }

"""What a pack holds so far, and what was asked for and not found."""
obj PackList {
    has files: list[tuple[str, bytes]] = [],
        names: list[str] = [],
        missing: list[str] = [],
        counts: dict[str, int] = {};

    """Put a file in, once. Its kind is counted."""
    def add(kind: str, name: str, data: bytes) {
        if name in self.names {
            return;
        }
        self.names.append(name);
        self.files.append((name, data));
        self.counts[kind] = self.counts.get(kind, 0) + 1;
    }

    def lacks(name: str) {
        if name not in self.missing {
            self.missing.append(name);
        }
    }
}

"""A file on disk, or None."""
def:priv disk_file(path: str) -> bytes | None {
    try {
        with open(path, "rb") as file {
            return file.read();
        }
    } except OSError {
        return None;
    }
}

obj Packer(StudioTool) {
    def commands -> list[tuple[str, str, str]] {
        # `ed_pack` is the studio's own; this answers its `project`.
        return [];
    }

    """Put in what a map's entities and brushes use; and the prefabs it
    links, with what they use."""
    def take_map(host: ToolHost, home: str, items: list[MapItem], pack: PackList, depth: int = 0) {
        for material in map_materials(items) {
            for (game, inner) in material_spots(material) {
                if game == "file" {
                    held = disk_file(host.folder("textures") + "/" + inner);
                    if held is not None {
                        pack.add("textures", "textures/" + inner, held);
                    } else {
                        pack.lacks(material);
                    }
                    break;
                }
                data = host.read_file(game, inner);
                if data is not None {
                    pack.add("textures", inner, data);
                    break;
                }
            }
        }
        for item in items {
            game = item.fields.get("asset_game", "");
            if game in ["q1", "q2", "q3"] {
                for (key, inner) in needed_files(game, item.fields) {
                    data = host.read_file(game, inner);
                    if data is not None {
                        pack.add("models" if key.startswith("model") else "sounds", inner, data);
                    } else {
                        pack.lacks(game + ":" + inner);
                    }
                }
            }
            linked = item.fields.get("prefab", "");
            if item.fields.get("classname", "") == "misc_prefab" and linked and ".." not in linked and depth < 8 {
                held = disk_file(home + "/prefabs/" + linked + ".map");
                if held is None {
                    pack.lacks("prefab " + linked);
                    continue;
                }
                first = "prefabs/" + linked + ".map" not in pack.names;
                pack.add("prefabs", "prefabs/" + linked + ".map", held);
                if first {
                    self.take_map(host, home, read_map(held.decode("utf-8", "replace")).items, pack, depth + 1);
                }
            }
        }
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_pack" or len(args) < 2 or args[1] != "project" {
            return False;
        }
        out = args[2] if len(args) > 2 else "";
        if not (out.lower().endswith(".pak") or out.lower().endswith(".pk3")) {
            host.say("ed_pack project <out.pak|out.pk3>: the project's scenes and only what they use");
            return True;
        }
        home = host.folder("");
        if not home {
            host.say("Open a project to pack (ed_project open <folder>)");
            return True;
        }
        pack = PackList();
        manifest = disk_file(home + "/project.qp");
        if manifest is not None {
            pack.add("project", "project.qp", manifest);
        }
        scenes: list[str] = [];
        if os.path.isdir(home + "/scenes") {
            scenes = sorted([name for name in os.listdir(home + "/scenes") if name.lower().endswith(".map")]);
        }
        for name in scenes {
            held = disk_file(home + "/scenes/" + name);
            if held is None {
                continue;
            }
            pack.add("scenes", "maps/" + name, held);
            self.take_map(host, home, read_map(held.decode("utf-8", "replace")).items, pack);
        }
        if pack.counts.get("scenes", 0) == 0 {
            host.say("The project has no scenes to pack: save one into it first");
            return True;
        }
        if out.lower().endswith(".pak") {
            # A PAK keeps fifty-five letters of a name.
            long_names = [name for name in pack.names if len(name) > 55];
            if len(long_names) > 0 {
                host.say("A PAK cannot hold " + long_names[0] + " (its name is too long): pack a .pk3");
                return True;
            }
        }
        path = out if os.path.isabs(out) else home + "/" + out;
        data = write_pak(pack.files) if out.lower().endswith(".pak") else write_zip(pack.files);
        try {
            folder = os.path.dirname(path);
            if folder {
                os.makedirs(folder, exist_ok=True);
            }
            with open(path, "wb") as file {
                file.write(data);
            }
        } except OSError {
            host.say("Could not write " + path);
            return True;
        }
        for name in pack.missing {
            print("studio: pack missing " + name);
        }
        print(
            "studio: packed project " + os.path.basename(path) + " scenes=" + str(pack.counts.get("scenes", 0)) + " prefabs="
                + str(pack.counts.get("prefabs", 0)) + " textures=" + str(pack.counts.get("textures", 0)) + " sounds="
                + str(pack.counts.get("sounds", 0)) + " models=" + str(pack.counts.get("models", 0)) + " missing="
                + str(len(pack.missing)) + " files=" + str(len(pack.files)) + " bytes=" + str(len(data))
        );
        host.say(
            "Packed " + str(len(pack.files)) + " files into " + path
                + ("" if len(pack.missing) == 0 else "; " + str(len(pack.missing)) + " things the scenes use were not found")
        );
        return True;
    }

    def draw_through(host: ToolHost, scene: Scene) {}

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        return [];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return [];
    }
}
