"""Materials' pictures written as the games' own wall textures: one as a
Quake II WAL among the project's textures, several as a Quake WAD. A
picture's colours become the nearest of the game's 256. A tool of the
studio in a module of its own (see editor/tools/host.jac)."""
import os;
import from editor.tools.host { ToolHost, StudioTool }
import from editor.document.scene { Scene }
import from editor.formats.texwrite { write_wal, write_miptex, write_wad, texture_refusal, texture_short }

obj TextureWriter(StudioTool) {
    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_texwal",
                "ed_texwal <material> [name]",
                "write a material's picture as a Quake II WAL among the project's textures, in Quake II's colours"
            ),
            (
                "ed_texwad",
                "ed_texwad <out.wad> <material ...|used>",
                "write materials' pictures as a Quake WAD of textures, in Quake's colours: those named, or every one the scene uses"
            )
        ];
    }

    def as_wal(host: ToolHost, args: list[str]) {
        if len(args) < 2 {
            host.say("ed_texwal <material> [name]");
            return;
        }
        picture = host.picture(args[1]);
        colours = host.palette("q2");
        if picture is None {
            host.say("Nothing holds the material " + args[1] + ", or its picture does not read");
            return;
        }
        if len(colours) != 768 {
            host.say("Quake II's colours are in its archives, and they are not here");
            return;
        }
        refusal = texture_refusal(picture.width, picture.height);
        if refusal {
            host.say(args[1] + ": " + refusal);
            return;
        }
        name = args[2].strip("/") if len(args) > 2 else texture_short(args[1]);
        if not name or ".." in name {
            host.say("ed_texwal <material> [name]: a name for the texture");
            return;
        }
        data = write_wal(name, picture.rgba, picture.width, picture.height, colours);
        path = host.folder("textures") + "/" + name + ".wal";
        try {
            os.makedirs(os.path.dirname(path), exist_ok=True);
            with open(path, "wb") as file {
                file.write(data);
            }
        } except OSError {
            host.say("Could not write " + path);
            return;
        }
        host.files_changed();
        print(
            "studio: texwal " + args[1] + " > " + name + ".wal " + str(picture.width) + "x" + str(picture.height) + " bytes="
                + str(len(data))
        );
        host.say("Wrote " + path);
    }

    def as_wad(host: ToolHost, scene: Scene, args: list[str]) {
        if len(args) < 3 or not args[1].lower().endswith(".wad") {
            host.say("ed_texwad <out.wad> <material ...|used>");
            return;
        }
        wanted = args[2:];
        if wanted == ["used"] {
            # Every material on the scene's brushes, once.
            wanted = [];
            for brush in scene.solids() {
                for side in brush.sides {
                    if side.material and side.material not in wanted {
                        wanted.append(side.material);
                    }
                }
            }
            wanted = sorted(wanted);
        }
        colours = host.palette("q1");
        if len(colours) != 768 {
            host.say("Quake's colours are in its archives, and they are not here");
            return;
        }
        lumps: list[tuple[str, bytes]] = [];
        taken: list[str] = [];
        skipped = 0;
        for material in wanted {
            picture = host.picture(material);
            if picture is None {
                print("studio: texwad skipped " + material + " no picture");
                skipped += 1;
                continue;
            }
            refusal = texture_refusal(picture.width, picture.height);
            if refusal {
                print("studio: texwad skipped " + material + " " + str(picture.width) + "x" + str(picture.height));
                skipped += 1;
                continue;
            }
            # A WAD keeps fifteen letters of a name, each name once.
            name = texture_short(material)[:15];
            tries = 1;
            while name in taken {
                tries += 1;
                name = texture_short(material)[:15 - len(str(tries))] + str(tries);
            }
            taken.append(name);
            lumps.append((name, write_miptex(name, picture.rgba, picture.width, picture.height, colours)));
        }
        if len(lumps) == 0 {
            host.say("None of those materials has a picture that can be a Quake texture");
            return;
        }
        path = args[1];
        # A path that does not begin at the root is under the project's folder, or
        # with no project beside the textures: never wherever the studio was started.
        home = host.folder("") if host.folder("") else host.folder("textures");
        if not os.path.isabs(path) and home {
            path = home + "/" + path;
        }
        data = write_wad(lumps);
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
            return;
        }
        host.files_changed();
        print("studio: texwad " + os.path.basename(path) + " textures=" + str(len(lumps)) + " skipped=" + str(skipped) + " bytes=" + str(len(data)));
        host.say(
            "Wrote " + str(len(lumps)) + " textures to " + path
                + ("" if skipped == 0 else "; " + str(skipped) + " left out (no picture, or sides that are not whole sixteens)")
        );
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] == "ed_texwal" {
            self.as_wal(host, args);
            return True;
        }
        if args[0] == "ed_texwad" {
            self.as_wad(host, scene, args);
            return True;
        }
        return False;
    }

    def draw_through(host: ToolHost, scene: Scene) {}

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        return [];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return [];
    }
}
