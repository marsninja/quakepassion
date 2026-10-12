"""A starter project: a small lit room with a player's start in it, made
and saved into a project of its own, so that Play has something to play
the first time the studio is opened. A tool of the studio in a module of
its own (see editor/tools/host.jac)."""
import from engine.math.vec3 { Vec3 }
import from editor.tools.host { ToolHost, StudioTool }
import from editor.document.scene { Scene }
import from editor.geometry.brush { box_sides }

"""What the starter room is built of besides the floor a new scene has:
(low corner, high corner, whether it is built as walls alone)."""
glob STARTER_BOXES: list[tuple[Vec3, Vec3, bool]] = [
    # The room: one box the size of the floor, built as its walls.
    (Vec3(x=-256.0, y=-256.0, z=0.0), Vec3(x=256.0, y=256.0, z=192.0), True),
    # A crate to jump on and a pillar to walk round.
    (Vec3(x=96.0, y=64.0, z=0.0), Vec3(x=160.0, y=128.0, z=40.0), False),
    (Vec3(x=-176.0, y=96.0, z=0.0), Vec3(x=-112.0, y=160.0, z=192.0), False)
];

"""Where the starter room's lights hang, and how far each reaches."""
glob STARTER_LIGHTS: list[tuple[Vec3, int]] = [(Vec3(x=0.0, y=0.0, z=160.0), 400), (Vec3(x=-160.0, y=-160.0, z=128.0), 250)];

obj Starter(StudioTool) {
    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_starter",
                "ed_starter [name]",
                "make a starter project: a small lit room with a player's start, saved and ready to play"
            )
        ];
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_starter" {
            return False;
        }
        name = args[1] if len(args) > 1 else "starter";
        if "/" in name or ".." in name or " " in name {
            host.say("ed_starter [name]: one word for the project's folder");
            return True;
        }
        was_open = host.folder("").endswith("/" + name);
        if not was_open {
            host.run(["ed_project", "new", name, "Starter"]);
        }
        if was_open or not host.folder("").endswith("/" + name) {
            # There is one of that name already: it is left as it is.
            host.say("There is a project called " + name + " already: ed_project open " + name + ", or ed_starter <another name>");
            return True;
        }
        host.run(["ed_scene", "room"]);
        made = host.scene_now();
        if made is None {
            return True;
        }
        material = "blockout";
        for brush in made.solids() {
            # What the new scene's floor is made of: the room is made of the same.
            material = brush.sides[0].material;
        }
        for (low, high, walled) in STARTER_BOXES {
            built = made.create_solid(box_sides(low, high, material));
            if built is not None and walled {
                made.clear_selection();
                made.select_solid(built);
                room = made.tie_selection("func_group");
                if room is not None {
                    made.clear_selection();
                    made.select(room);
                    made.set_fields({"_walls": "16", "_group_name": "walls"}, "Maker");
                }
            }
        }
        for (at, reach) in STARTER_LIGHTS {
            lamp = made.create("light", at);
            made.clear_selection();
            made.select(lamp);
            made.set_fields({"light": str(reach)}, "Light");
        }
        made.clear_selection();
        host.run(["ed_light", "on"]);
        host.run(["ed_save"]);
        host.run(["ed_project", "start", "room"]);
        print(
            "studio: starter " + name + " brushes=" + str(len(made.solids())) + " entities=" + str(len(made.items())) + " in "
                + host.folder("")
        );
        host.say("A starter project is ready in " + host.folder("") + ": press Play (F5) to walk in it");
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
