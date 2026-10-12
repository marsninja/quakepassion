"""Paths as wholes: from any corner of a path, every corner it leads to and
is led to from, picked or moved together. A tool of the studio in a module
of its own (see editor/tools/host.jac)."""
import from engine.math.vec3 { Vec3 }
import from editor.tools.host { ToolHost, StudioTool }
import from editor.document.scene { Scene, Item }

"""The entities of a path: those reached from the given ones by `target`
and `targetname`, either way, through entities that have an origin (a path
is its corners, a train's stops, a camera's marks). In the order they are
met; the given ones first."""
def path_of(items: list[Item], begun: list[Item]) -> list[Item] {
    named: dict[str, list[Item]] = {};
    aiming: dict[str, list[Item]] = {};
    for item in items {
        if item.origin() is None {
            continue;
        }
        name = item.fields.get("targetname", "");
        if name {
            if name not in named {
                named[name] = [];
            }
            named[name].append(item);
        }
        aim = item.fields.get("target", "");
        if aim {
            if aim not in aiming {
                aiming[aim] = [];
            }
            aiming[aim].append(item);
        }
    }
    found: list[Item] = [];
    waiting = [item for item in begun if item.origin() is not None];
    while len(waiting) > 0 {
        item = waiting.pop(0);
        if item in found {
            continue;
        }
        found.append(item);
        # Where it leads, and what leads to it.
        for other in named.get(item.fields.get("target", ""), []) {
            if other not in found {
                waiting.append(other);
            }
        }
        for other in aiming.get(item.fields.get("targetname", ""), []) {
            if other not in found {
                waiting.append(other);
            }
        }
    }
    return found;
}

obj Paths(StudioTool) {
    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_path",
                "ed_path [pick] | move <dx> <dy> <dz>",
                "the whole path a selected corner belongs to: pick every corner of it, or move them all together"
            )
        ];
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_path" {
            return False;
        }
        how = args[1] if len(args) > 1 else "pick";
        chosen = scene.selection();
        if how not in ["pick", "move"] {
            host.say("ed_path [pick] | move <dx> <dy> <dz>");
            return True;
        }
        whole = path_of(scene.items(), chosen);
        if len(whole) < 2 {
            host.say("Select a corner of a path: an entity with a target, or one that is a target");
            return True;
        }
        moved_by = Vec3();
        if how == "move" {
            try {
                moved_by = Vec3(x=float(args[2]), y=float(args[3]), z=float(args[4]));
            } except (ValueError, IndexError) {
                host.say("ed_path move <dx> <dy> <dz>");
                return True;
            }
        }
        scene.clear_selection();
        for item in whole {
            scene.select(item, add=True);
        }
        if how == "move" and not scene.shift_selection(moved_by, True) {
            host.say("The path did not move");
            return True;
        }
        print("studio: path corners=" + str(len(whole)) + (" moved=" + str(int(moved_by.x)) + "," + str(int(moved_by.y)) + "," + str(int(moved_by.z)) if how == "move" else ""));
        host.say(str(len(whole)) + " corners of the path " + ("moved together" if how == "move" else "picked"));
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
