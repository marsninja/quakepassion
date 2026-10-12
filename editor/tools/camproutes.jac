"""The ways bots take between the spots they camp at and roam through,
walked over the level's navigation (baked in the studio, or a shipped
arena's own) and drawn in the views. A tool of the studio in a module of
its own (see editor/tools/host.jac)."""
import from engine.math.vec3 { Vec3 }
import from engine.formats.aas { TRAVEL_WALK, TRAVEL_BARRIERJUMP, TRAVEL_WALKOFFLEDGE }
import from editor.tools.host { ToolHost, StudioTool }
import from editor.document.scene { Scene, Item }
import from editor.compile.navigation { Leg, route_legs, legs_count }
import from editor.ui.canvas { ink }

def:priv is_camp_spot(item: Item) -> bool {
    return item.classname() == "info_camp" or item.classname() == "item_botroam";
}

obj CampRoutes(StudioTool) {
    has shown: bool = False,
        # What is drawn of the ways, how many were found and not, and what
        # the scene was when they were walked.
        legs: list[Leg] = [],
        found: int = 0,
        lost: int = 0,
        mark: int = -1;

    def commands -> list[tuple[str, str, str]] {
        # `ed_camps` is the studio's own; this answers its `routes`.
        return [];
    }

    """From the one thing picked to every spot; or each spot to the next, in
    the order they were made."""
    def pairs(scene: Scene) -> list[tuple[Item, Item]] {
        joined: list[tuple[Item, Item]] = [];
        spots = [item for item in scene.items() if is_camp_spot(item) and item.origin() is not None];
        chosen = [item for item in scene.selection() if item.origin() is not None];
        if len(chosen) == 1 {
            for spot in spots {
                if spot is not chosen[0] {
                    joined.append((chosen[0], spot));
                }
            }
            return joined;
        }
        for place in range(len(spots) - 1) {
            joined.append((spots[place], spots[place + 1]));
        }
        return joined;
    }

    """Walk the ways again. Answers a line for each, for the console."""
    def walk(host: ToolHost, scene: Scene) -> list[str] {
        lines: list[str] = [];
        self.legs = [];
        self.found = 0;
        self.lost = 0;
        mesh = host.navigation();
        if mesh is None {
            return lines;
        }
        for (from_item, to_item) in self.pairs(scene) {
            begin = from_item.origin();
            finish = to_item.origin();
            if begin is None or finish is None {
                continue;
            }
            said = "studio: camp route #" + str(from_item.serial) + " " + from_item.classname() + " > #" + str(to_item.serial) + " "
                + to_item.classname();
            way = route_legs(mesh, begin, finish);
            if way is None {
                self.lost += 1;
                lines.append(said + " time=-1");
                continue;
            }
            self.found += 1;
            counts = legs_count(way);
            lines.append(
                said + " time=" + str(sum([leg.time for leg in way])) + " legs=" + str(len(way)) + " walk=" + str(counts[0])
                    + " jump=" + str(counts[1]) + " drop=" + str(counts[2]) + " other=" + str(counts[3])
            );
            # What is drawn: the run to each leg, and the leg, and the run from the last.
            stood = begin;
            for leg in way {
                self.legs.append(Leg(start=stood, finish=leg.start, kind=TRAVEL_WALK, time=0));
                self.legs.append(leg);
                stood = leg.finish;
            }
            self.legs.append(Leg(start=stood, finish=finish, kind=TRAVEL_WALK, time=0));
        }
        return lines;
    }

    def words -> str {
        return "studio: camp routes ways=" + str(self.found) + " lost=" + str(self.lost) + " drawn=" + str(len(self.legs));
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_camps" or len(args) < 2 or args[1] != "routes" {
            return False;
        }
        word = args[2] if len(args) > 2 else "";
        if word not in ["", "on", "off"] {
            host.say("ed_camps routes [on|off]: the ways bots take between the camp spots, or from the one thing picked to each");
            return True;
        }
        wanted = (not self.shown) if not word else word == "on";
        if not wanted {
            self.shown = False;
            self.legs = [];
            host.say("The ways between camp spots are not drawn");
            return True;
        }
        if host.navigation() is None {
            host.say("There is no navigation to ask the way of: bake it (ed_nav bake), or open an arena that has its own");
            return True;
        }
        self.shown = True;
        self.mark = -1;
        for line in self.walk(host, scene) {
            print(line);
        }
        print(self.words());
        if self.found + self.lost == 0 {
            host.say("No two camp spots to go between: add an info_camp or an item_botroam, or pick one thing to go from");
        } else {
            host.say(
                str(self.found) + (" way" if self.found == 1 else " ways") + " drawn: run pink, jumped yellow, dropped red"
                    + ("" if self.lost == 0 else "; " + str(self.lost) + (" spot" if self.lost == 1 else " spots") + " cannot be reached")
            );
        }
        return True;
    }

    def draw_through(host: ToolHost, scene: Scene) {
        if not self.shown {
            return;
        }
        if host.navigation() is None {
            # The navigation went (the level was built again): nothing to draw until it is baked.
            self.legs = [];
            self.found = 0;
            self.lost = 0;
            return;
        }
        chosen = scene.selection();
        now = scene.revision * 4 + (chosen[0].serial * 8 + 1 if len(chosen) == 1 else 0) + host.navigation_mark() * 2;
        if now != self.mark {
            self.walk(host, scene);
            self.mark = now;
        }
        tones = {TRAVEL_WALK: ink(0xff7bd5, 235), TRAVEL_BARRIERJUMP: ink(0xffc94d, 255), TRAVEL_WALKOFFLEDGE: ink(0xe5484d, 255)};
        for leg in self.legs {
            tone = tones[leg.kind] if leg.kind in tones else ink(0x8ad7ff, 255);
            host.line(
                Vec3(x=leg.start.x, y=leg.start.y, z=leg.start.z - 12.0), Vec3(x=leg.finish.x, y=leg.finish.y, z=leg.finish.z - 12.0), tone
            );
        }
    }

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        return [self.words()] if self.shown else [];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return [];
    }
}
