"""The ways bots take between the spots they camp at and roam through,
walked over the level's navigation (baked here, or a shipped arena's own)
and drawn in the views. Declarations live in studio.jac."""

def:priv camp_spot(item: Item) -> bool {
    return item.classname() == "info_camp" or item.classname() == "item_botroam";
}

impl Studio.route_mesh -> NavMesh | None {
    baked = self.nav_mesh;
    if baked is not None {
        return baked;
    }
    app = self.app;
    if app is None {
        return None;
    }
    # A shipped arena's own, when it came with one.
    meshes = [app.world->:HasNavMesh:->][?:NavMesh];
    return meshes[0] if len(meshes) > 0 else None;
}

impl Studio.camp_pairs(scene: Scene) -> list[tuple[Item, Item]] {
    found: list[tuple[Item, Item]] = [];
    spots = [item for item in scene.items() if camp_spot(item) and item.origin() is not None];
    chosen = [item for item in scene.selection() if item.origin() is not None];
    if len(chosen) == 1 {
        # From the one thing picked to every spot.
        for spot in spots {
            if spot is not chosen[0] {
                found.append((chosen[0], spot));
            }
        }
        return found;
    }
    # Each spot to the next, in the order they were made.
    for place in range(len(spots) - 1) {
        found.append((spots[place], spots[place + 1]));
    }
    return found;
}

impl Studio.camp_route_lines(scene: Scene) -> list[str] {
    lines: list[str] = [];
    self.camp_legs = [];
    self.camp_found = 0;
    self.camp_lost = 0;
    mesh = self.route_mesh();
    if mesh is None {
        return lines;
    }
    for (from_item, to_item) in self.camp_pairs(scene) {
        begin = from_item.origin();
        finish = to_item.origin();
        if begin is None or finish is None {
            continue;
        }
        said = "studio: camp route #" + str(from_item.serial) + " " + from_item.classname() + " > #" + str(to_item.serial) + " "
            + to_item.classname();
        legs = route_legs(mesh, begin, finish);
        if legs is None {
            self.camp_lost += 1;
            lines.append(said + " time=-1");
            continue;
        }
        self.camp_found += 1;
        counts = legs_count(legs);
        lines.append(
            said + " time=" + str(sum([leg.time for leg in legs])) + " legs=" + str(len(legs)) + " walk=" + str(counts[0])
                + " jump=" + str(counts[1]) + " drop=" + str(counts[2]) + " other=" + str(counts[3])
        );
        # What is drawn: the run to each leg, and the leg, and the run from the last.
        stood = begin;
        for leg in legs {
            self.camp_legs.append(Leg(start=stood, finish=leg.start, kind=TRAVEL_WALK, time=0));
            self.camp_legs.append(leg);
            stood = leg.finish;
        }
        self.camp_legs.append(Leg(start=stood, finish=finish, kind=TRAVEL_WALK, time=0));
    }
    return lines;
}

impl Studio.camp_routes_words -> str {
    return "studio: camp routes ways=" + str(self.camp_found) + " lost=" + str(self.camp_lost) + " drawn="
        + str(len(self.camp_legs));
}

impl Studio.draw_camp_routes(scene: Scene) {
    if not self.camp_routes {
        return;
    }
    chosen = scene.selection();
    mark = scene.revision * 4 + (chosen[0].serial * 8 + 1 if len(chosen) == 1 else 0) + len(self.nav_floors) * 2;
    if mark != self.camp_mark {
        self.camp_route_lines(scene);
        self.camp_mark = mark;
    }
    tones = {TRAVEL_WALK: ink(0xff7bd5, 235), TRAVEL_BARRIERJUMP: ink(0xffc94d, 255), TRAVEL_WALKOFFLEDGE: ink(0xe5484d, 255)};
    for leg in self.camp_legs {
        tone = tones[leg.kind] if leg.kind in tones else ink(0x8ad7ff, 255);
        wire_line(Vec3(x=leg.start.x, y=leg.start.y, z=leg.start.z - 12.0), Vec3(x=leg.finish.x, y=leg.finish.y, z=leg.finish.z - 12.0), tone);
    }
}

impl Studio.camproute_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_camps" or len(args) < 2 or args[1] != "routes" {
        return False;
    }
    word = args[2] if len(args) > 2 else "";
    if word not in ["", "on", "off"] {
        self.say("ed_camps routes [on|off]: the ways bots take between the camp spots, or from the one thing picked to each");
        return True;
    }
    wanted = (not self.camp_routes) if not word else word == "on";
    if not wanted {
        self.camp_routes = False;
        self.camp_legs = [];
        self.say("The ways between camp spots are not drawn");
        return True;
    }
    if self.route_mesh() is None {
        self.say("There is no navigation to ask the way of: bake it (ed_nav bake), or open an arena that has its own");
        return True;
    }
    self.camp_routes = True;
    self.camp_mark = -1;
    for line in self.camp_route_lines(scene) {
        print(line);
    }
    print(self.camp_routes_words());
    if self.camp_found + self.camp_lost == 0 {
        self.say("No two camp spots to go between: add an info_camp or an item_botroam, or pick one thing to go from");
    } else {
        self.say(
            str(self.camp_found) + (" way" if self.camp_found == 1 else " ways") + " drawn: run pink, jumped yellow, dropped red"
                + ("" if self.camp_lost == 0 else "; " + str(self.camp_lost) + (" spot" if self.camp_lost == 1 else " spots") + " cannot be reached")
        );
    }
    return True;
}
