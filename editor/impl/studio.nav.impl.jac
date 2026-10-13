"""The studio's navigation bake: a built scene's floors sampled on a grid
and made into the navigation data the games' bots route over, checked with
the engine's own router and drawn in the views. Declarations live in
studio.jac."""

def:priv nav_numbers(words: list[str]) -> list[float] {
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

impl Studio.nav_floors_of(scene: Scene, cell: float) -> list[Floor] {
    found: list[Floor] = [];
    app = self.app;
    if app is None {
        return found;
    }
    boxes = [solid.bounds() for solid in scene.solids() if not solid.hidden];
    spans = [box for box in boxes if box is not None];
    if len(spans) == 0 {
        return found;
    }
    low = spans[0][0];
    high = spans[0][1];
    for box in spans {
        low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
        high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
    }
    self.nav_origin = Vec3(x=math.floor(low.x / cell) * cell, y=math.floor(low.y / cell) * cell);
    columns = int(math.ceil((high.x - self.nav_origin.x) / cell));
    rows = int(math.ceil((high.y - self.nav_origin.y) / cell));
    hull = app.level.collision;
    inset = cell * 0.5 - 2.0;
    for row in range(rows) {
        for column in range(columns) {
            middle = Vec3(
                x=self.nav_origin.x + (float(column) + 0.5) * cell, y=self.nav_origin.y + (float(row) + 0.5) * cell
            );
            top = high.z + 64.0;
            layers = 0;
            while top > low.z - 8.0 and layers < 4 {
                eye = Vec3(x=middle.x, y=middle.y, z=top);
                down = hull.trace_point(eye, Vec3(x=middle.x, y=middle.y, z=low.z - 16.0), self.nav_exclude);
                if down.start_solid {
                    # Inside something: on down until out of it.
                    top -= 8.0;
                    continue;
                }
                if down.fraction >= 1.0 {
                    break;
                }
                stood = down.end.z;
                # A place to stand: floor under each corner of the cell too, at
                # about this height, and nothing as high as a head over it.
                sound = True;
                for (across, along) in [(0.0, 0.0), (-inset, -inset), (inset, -inset), (inset, inset), (-inset, inset)] {
                    foot = Vec3(x=middle.x + across, y=middle.y + along, z=stood + NAV_STEP);
                    under = hull.trace_point(foot, Vec3(x=foot.x, y=foot.y, z=stood - NAV_STEP), self.nav_exclude);
                    over = hull.trace_point(
                        Vec3(x=foot.x, y=foot.y, z=stood + NAV_STEP), Vec3(x=foot.x, y=foot.y, z=stood + 56.0), self.nav_exclude
                    );
                    if under.start_solid or under.fraction >= 1.0 or over.start_solid or over.fraction < 1.0 {
                        sound = False;
                    }
                }
                if sound {
                    found.append(Floor(column=column, row=row, z=float(round(stood))));
                    layers += 1;
                }
                top = stood - 8.0;
            }
        }
    }
    return found;
}

impl Studio.nav_clear_ways(floors: list[Floor], ways: list[Way], cell: float) -> list[Way] {
    kept: list[Way] = [];
    app = self.app;
    if app is None {
        return kept;
    }
    hull = app.level.collision;
    for way in ways {
        from_spot = floor_middle(floors[way.source], self.nav_origin, cell);
        to_spot = floor_middle(floors[way.target], self.nav_origin, cell);
        # Nothing between the two at the knee or at the head, at the height of the higher.
        level = max(from_spot.z, to_spot.z);
        open_way = True;
        for lift in [NAV_STEP + 1.0, 50.0] {
            line = hull.trace_point(
                Vec3(x=from_spot.x, y=from_spot.y, z=level + lift), Vec3(x=to_spot.x, y=to_spot.y, z=level + lift),
                self.nav_exclude
            );
            if line.start_solid or line.fraction < 1.0 {
                open_way = False;
            }
        }
        if open_way {
            kept.append(way);
        }
    }
    return kept;
}

"""What a material is to a bot: a liquid (Quake's `*` names, and those of
water, slime and lava), a ladder, or nothing in particular ("")."""
def:priv nav_material(material: str) -> str {
    last = material.lower().replace(":", "/").split("/")[-1];
    if last.startswith("*") or "water" in last or "slime" in last or "lava" in last {
        return "liquid";
    }
    return "ladder" if "ladder" in last else "";
}

impl Studio.nav_words -> str {
    mesh = self.nav_mesh;
    if mesh is None {
        return "studio: nav none";
    }
    counts = ways_count(self.nav_ways);
    return "studio: nav cell=" + str(int(self.nav_cell)) + " floors=" + str(len(self.nav_floors)) + " ways="
        + str(len(self.nav_ways)) + " walk=" + str(counts[0]) + " jump=" + str(counts[1]) + " drop=" + str(counts[2])
        + " areas=" + str(len(mesh.areas) - 1) + " shown=" + ("1" if self.nav_shown else "0") + " teleport="
        + str(len([way for way in self.nav_ways if way.kind == TRAVEL_TELEPORT])) + " jumppad="
        + str(len([way for way in self.nav_ways if way.kind == TRAVEL_JUMPPAD])) + " ladder="
        + str(len([way for way in self.nav_ways if way.kind == TRAVEL_LADDER])) + " swim="
        + str(len([way for way in self.nav_ways if way.kind == TRAVEL_SWIM])) + " lift="
        + str(len([way for way in self.nav_ways if way.kind == TRAVEL_ELEVATOR]));
}

impl Studio.draw_nav {
    if not self.nav_shown or self.nav_mesh is None {
        return;
    }
    tones = {
        TRAVEL_WALK: ink(0x4cc38a, 170), TRAVEL_BARRIERJUMP: ink(0xffc94d, 220), TRAVEL_WALKOFFLEDGE: ink(0xe5484d, 200),
        TRAVEL_TELEPORT: ink(0xc76bff, 230), TRAVEL_JUMPPAD: ink(0xff8a3d, 230), TRAVEL_LADDER: ink(0xffffff, 230),
        TRAVEL_SWIM: ink(0x4f8ef7, 200), TRAVEL_ELEVATOR: ink(0x3dd6d0, 230)
    };
    drawn = 0;
    for way in self.nav_ways {
        if drawn >= 8000 {
            break;
        }
        # Each walked way is two ways, there and back: drawn once.
        if way.kind == TRAVEL_WALK and way.source > way.target {
            continue;
        }
        from_spot = floor_middle(self.nav_floors[way.source], self.nav_origin, self.nav_cell);
        to_spot = floor_middle(self.nav_floors[way.target], self.nav_origin, self.nav_cell);
        wire_line(Vec3(x=from_spot.x, y=from_spot.y, z=from_spot.z + 4.0), Vec3(x=to_spot.x, y=to_spot.y, z=to_spot.z + 4.0), tones.get(way.kind, ink(0xffffff, 200)));
        drawn += 1;
    }
}

impl Studio.nav_findings(scene: Scene) -> list[Finding] {
    found: list[Finding] = [];
    mesh = self.nav_mesh;
    if mesh is None {
        return found;
    }
    starts = [item for item in scene.items() if item.classname().startswith("info_player") and item.origin() is not None];
    if len(starts) == 0 {
        return found;
    }
    begin = starts[0].origin();
    if begin is None {
        return found;
    }
    for item in scene.items() {
        at = item.origin();
        if at is None or item is starts[0] or item.classname().startswith("light") {
            continue;
        }
        if route_time(mesh, begin, at) < 0 {
            found.append(Finding(words=item.title() + " cannot be reached from " + starts[0].title() + " over the baked floors", item=item));
        }
    }
    return found;
}

impl Studio.nav_command(scene: Scene, args: list[str]) -> bool {
    if args[0] == "ed_playtest" {
        if not self.is_built_scene() {
            self.say("A playtest is of a scene of brushes (ed_scene, ed_convert, ed_exp open)");
            return True;
        }
        if self.nav_mesh is None or (len(args) > 1 and args[1] == "bake") {
            # The floors are walked over as they are built now, every door open:
            # whether a door can be opened is the logic's to say.
            self.nav_command(scene, ["ed_nav", "bake", "32", "open"]);
        }
        lost = self.playtest(scene);
        asked = objectives([item.fields for item in scene.items()]);
        rows: list[TreeRow] = [];
        self.findings = [];
        for finding in lost {
            print("studio: playtest stopped " + finding.words);
            rows.append(TreeRow(key=str(len(rows)), text=finding.words, tone="text", note="!"));
            self.findings.append(finding);
        }
        print("studio: playtest finish=" + ("1" if len(lost) == 0 else "0") + " objectives=" + str(len(asked)) + " stopped=" + str(len(lost)));
        panel = self.ui;
        if panel is not None {
            if not rows {
                rows.append(TreeRow(key="none", text="It can be finished: every objective is reached.", tone="faint"));
            }
            panel.checks.rows = rows;
        }
        self.say(
            "It can be finished: " + str(len(asked)) + " objectives are reached from the start" if len(lost) == 0
            else "It cannot be finished: " + lost[len(lost) - 1].words + " (the Checks tab lists what stops it)"
        );
        return True;
    }
    if args[0] != "ed_nav" {
        return False;
    }
    app = self.app;
    how = args[1] if len(args) > 1 else "";
    if not how {
        print(self.nav_words());
        self.say("No navigation is baked (ed_nav bake)" if self.nav_mesh is None else self.nav_words()[8:]);
        return True;
    }
    if how == "bake" {
        if app is None or not self.is_built_scene() {
            self.say("Navigation is baked for a scene (ed_scene): a shipped arena has its own");
            return True;
        }
        sizes = nav_numbers(args[2:]);
        cell = max(16.0, min(128.0, sizes[0])) if len(sizes) > 0 else 32.0;
        # With `open`, what moves (doors, platforms, buttons) is left out:
        # the floors are walked as if every door stood open.
        self.nav_exclude = [];
        if "open" in args[2:] {
            movers: list[int] = [];
            for held in app.level.bsp.entities {
                kind = held.fields.get("classname", "");
                shape = held.fields.get("model", "");
                if shape.startswith("*") and shape[1:].isdigit()
                    and (kind.startswith("func_door") or kind in ["func_plat", "func_button", "func_train", "func_wall_toggle"]) {
                    movers.append(int(shape[1:]));
                }
            }
            for (number, model) in enumerate(app.level.collision.models) {
                if model in movers {
                    self.nav_exclude.append(number);
                }
            }
        }
        floors = self.nav_floors_of(scene, cell);
        if len(floors) == 0 {
            self.say("The scene has no floor to stand on");
            return True;
        }
        if len(floors) > 60000 {
            self.say("That is " + str(len(floors)) + " places to stand: bake with a wider cell (ed_nav bake 64)");
            return True;
        }
        self.nav_floors = floors;
        self.nav_cell = cell;
        ways = self.nav_clear_ways(floors, floor_ways(floors), cell) + linked_ways(floors, self.nav_origin, cell, self.nav_links(scene))
            + swim_ways(floors, self.nav_origin, cell, self.nav_waters(scene));
        for old in [app.world->:HasNavMesh:->][?:NavMesh] {
            app.world del->:HasNavMesh:-> old;
        }
        self.nav_floors = floors;
        self.nav_ways = ways;
        self.nav_cell = cell;
        self.nav_aas = nav_data(floors, ways, self.nav_origin, cell);
        self.nav_mesh = build_navmesh(app.world, self.nav_aas, app.level.bsp);
        print(self.nav_words());
        self.say("Baked " + str(len(floors)) + " places to stand and " + str(len(ways)) + " ways between them");
        return True;
    }
    if how == "write" {
        baked = self.nav_aas;
        if baked is None {
            self.say("ed_nav write: bake the navigation first (ed_nav bake)");
            return True;
        }
        # An arena's file, beside the scene's map unless told where.
        path = args[2] if len(args) > 2 else self.scene_path(scene.name[7:] if scene.name.startswith("studio:") else scene.name)[:-4] + ".aas";
        try {
            os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True);
            with open(path, "wb") as file {
                file.write(aas_bytes(baked));
            }
        } except OSError {
            self.say("ed_nav write: could not write " + path);
            return True;
        }
        print("studio: nav written " + path + " areas=" + str(len(baked.areas) - 1) + " ways=" + str(len(baked.reaches) - 1));
        self.say("The navigation is written as an arena's file: " + path);
        return True;
    }
    if how == "clear" {
        if app is not None {
            for old in [app.world->:HasNavMesh:->][?:NavMesh] {
                app.world del->:HasNavMesh:-> old;
            }
        }
        self.nav_mesh = None;
        self.nav_aas = None;
        self.nav_floors = [];
        self.nav_ways = [];
        self.say("The baked navigation is forgotten");
        return True;
    }
    if how == "show" {
        word = args[2] if len(args) > 2 else "";
        self.nav_shown = (not self.nav_shown) if word not in ["on", "off"] else word == "on";
        self.say("The baked ways are drawn: walked green, jumped yellow, dropped red, climbed white, swum blue, lifted cyan, teleported violet, thrown orange" if self.nav_shown else "The baked ways are not drawn");
        return True;
    }
    mesh = self.nav_mesh;
    if mesh is None {
        self.say("Bake the navigation first (ed_nav bake)");
        return True;
    }
    if how == "route" {
        ends = nav_numbers(args[2:]);
        if len(ends) < 6 {
            self.say("ed_nav route <x y z> <x y z>: how long the way from one place to the other is");
            return True;
        }
        took = route_time(mesh, Vec3(x=ends[0], y=ends[1], z=ends[2]), Vec3(x=ends[3], y=ends[4], z=ends[5]));
        print("studio: nav route time=" + str(took));
        self.say("No way between them" if took < 0 else "A way of " + str(round(float(took) / 100.0, 1)) + " seconds");
        return True;
    }
    if how == "check" {
        lost = self.nav_findings(scene);
        for finding in lost {
            print("studio: nav lost " + finding.words);
        }
        print("studio: nav checked lost=" + str(len(lost)));
        self.say("Everything can be reached from the first player start" if len(lost) == 0 else str(len(lost)) + " things cannot be reached: ed_check lists them in the Checks tab");
        return True;
    }
    self.say("ed_nav [bake [cell] | check | route <from xyz> <to xyz> | show [on|off] | clear]");
    return True;
}

impl Studio.playtest(scene: Scene) -> list[Finding] {
    # What can never be set off, a lock with no key: the logic first.
    found: list[Finding] = scene.softlocks();
    mesh = self.nav_mesh;
    if mesh is None {
        return found;
    }
    members = scene.items();
    starts = [item for item in members if item.classname().startswith("info_player") and item.origin() is not None];
    if len(starts) == 0 {
        found.append(Finding(words="There is nowhere to start: the level has no player start"));
        return found;
    }
    begin = starts[0].origin();
    if begin is None {
        return found;
    }
    for (index, called) in objectives([item.fields for item in members]) {
        item = members[index];
        # Where it is: its own place, or the middle of what it is made of.
        at = item.origin();
        if at is None {
            boxes = [solid.bounds() for solid in scene.solids_of(item)];
            spans = [box for box in boxes if box is not None];
            if len(spans) == 0 {
                continue;
            }
            at = spans[0][0].add(spans[0][1]).scale(0.5);
        }
        # A thing on a wall is come to from beside it, and from the floor under it.
        reached = False;
        for aside in [Vec3(), Vec3(x=48.0), Vec3(x=-48.0), Vec3(y=48.0), Vec3(y=-48.0)] {
            for drop in [0.0, 32.0, 64.0, 96.0] {
                if not reached and route_time(mesh, begin, at.add(aside).sub(Vec3(z=drop))) >= 0 {
                    reached = True;
                }
            }
        }
        if not reached {
            # The first that cannot be come to is what stops the level.
            found.append(Finding(words=called + " cannot be reached from " + starts[0].title() + " over the baked floors", item=item));
            break;
        }
    }
    return found;
}

impl Studio.nav_links(scene: Scene) -> list[Link] {
    found: list[Link] = [];
    named: dict[str, Vec3] = {};
    for item in scene.items() {
        at = item.origin();
        called = item.fields.get("targetname", "");
        if called and at is not None {
            named[called] = at;
        }
    }
    for item in scene.items() {
        kind = item.classname();
        if kind not in ["trigger_teleport", "trigger_push"] {
            continue;
        }
        aim = named.get(item.fields.get("target", ""));
        brushes = scene.solids_of(item);
        if aim is None or len(brushes) == 0 {
            continue;
        }
        # Where the trigger is: the middle of its brushes.
        low = Vec3(x=1000000.0, y=1000000.0, z=1000000.0);
        high = Vec3(x=-1000000.0, y=-1000000.0, z=-1000000.0);
        for brush in brushes {
            box = brush.bounds();
            if box is not None {
                low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
                high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
            }
        }
        if low.x > high.x {
            continue;
        }
        middle = Vec3(x=(low.x + high.x) * 0.5, y=(low.y + high.y) * 0.5, z=low.z + 24.0);
        found.append(Link(start=middle, finish=aim.add(Vec3(z=24.0)), kind=TRAVEL_TELEPORT if kind == "trigger_teleport" else TRAVEL_JUMPPAD));
    }
    # Ladders: a brush of a ladder's material, climbed from its foot to its top and back.
    for brush in scene.solids() {
        if brush.hidden or len([side for side in brush.sides if nav_material(side.material) == "ladder"]) == 0 {
            continue;
        }
        box = brush.bounds();
        if box is None {
            continue;
        }
        at_x = (box[0].x + box[1].x) * 0.5;
        at_y = (box[0].y + box[1].y) * 0.5;
        foot = Vec3(x=at_x, y=at_y, z=box[0].z + 24.0);
        head = Vec3(x=at_x, y=at_y, z=box[1].z + 24.0);
        found.append(Link(start=foot, finish=head, kind=TRAVEL_LADDER));
        found.append(Link(start=head, finish=foot, kind=TRAVEL_LADDER));
    }
    # Lifts: a func_plat carries what stands under it at its lowest up to its top.
    app = self.app;
    plat_models: list[int] = [];
    if app is not None {
        for held in app.level.bsp.entities {
            shape = held.fields.get("model", "");
            if held.fields.get("classname", "") == "func_plat" and shape.startswith("*") and shape[1:].isdigit() {
                plat_models.append(int(shape[1:]));
            }
        }
    }
    plats = 0;
    for item in scene.items() {
        if item.classname() != "func_plat" {
            continue;
        }
        number = plat_models[plats] if plats < len(plat_models) else 0;
        plats += 1;
        brushes = scene.solids_of(item);
        boxes = [brush.bounds() for brush in brushes];
        spans = [box for box in boxes if box is not None];
        if len(spans) == 0 or number <= 0 {
            continue;
        }
        low = spans[0][0];
        high = spans[0][1];
        for box in spans {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
            high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
        }
        # How far it goes down: its `height`, else its own height less the lip it keeps.
        travel = high.z - low.z - 8.0;
        try {
            travel = float(item.fields.get("height", str(travel)));
        } except ValueError {
            travel = high.z - low.z - 8.0;
        }
        at_x = (low.x + high.x) * 0.5;
        at_y = (low.y + high.y) * 0.5;
        found.append(
            Link(
                start=Vec3(x=at_x, y=at_y, z=high.z - travel + 24.0), finish=Vec3(x=at_x, y=at_y, z=high.z + 24.0),
                kind=TRAVEL_ELEVATOR, model=number
            )
        );
    }
    return found;
}

impl Studio.nav_waters(scene: Scene) -> list[list[Vec3]] {
    found: list[list[Vec3]] = [];
    for brush in scene.solids() {
        if brush.hidden or len([side for side in brush.sides if nav_material(side.material) == "liquid"]) == 0 {
            continue;
        }
        box = brush.bounds();
        if box is not None {
            found.append([box[0], box[1]]);
        }
    }
    return found;
}
