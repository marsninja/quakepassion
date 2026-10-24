"""The studio's navigation: a built scene's level graph (`engine/level/`),
read off the level as the game plays it, routed over by the games' bots,
drawn in the views, and proven: a scene can be finished when its graph
proves clean. Declarations live in studio.jac."""

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

impl Studio.nav_words -> str {
    mesh = self.nav_mesh;
    atlas = self.nav_atlas;
    if mesh is None or atlas is None {
        return "studio: nav none";
    }
    kinds: dict[int, int] = {};
    for place in level_places(atlas) {
        for move in [edge place->:Move:->] {
            kinds[move.kind] = kinds.get(move.kind, 0) + 1;
        }
    }
    return "studio: nav places=" + str(len(level_places(atlas))) + " walk=" + str(kinds.get(TRAVEL_WALK, 0)) + " jump="
        + str(kinds.get(TRAVEL_BARRIERJUMP, 0) + kinds.get(TRAVEL_JUMP, 0)) + " drop=" + str(kinds.get(TRAVEL_WALKOFFLEDGE, 0)) + " areas="
        + str(len(mesh.areas) - 1) + " shown=" + ("1" if self.nav_shown else "0") + " teleport=" + str(kinds.get(TRAVEL_TELEPORT, 0))
        + " jumppad=" + str(kinds.get(TRAVEL_JUMPPAD, 0)) + " ladder=" + str(kinds.get(TRAVEL_LADDER, 0)) + " swim="
        + str(kinds.get(TRAVEL_SWIM, 0)) + " lift=" + str(kinds.get(TRAVEL_ELEVATOR, 0));
}

impl Studio.draw_nav {
    atlas = self.nav_atlas;
    if not self.nav_shown or atlas is None {
        return;
    }
    tones = {
        TRAVEL_WALK: ink(0x4cc38a, 170), TRAVEL_BARRIERJUMP: ink(0xffc94d, 220), TRAVEL_JUMP: ink(0xffc94d, 220),
        TRAVEL_WALKOFFLEDGE: ink(0xe5484d, 200), TRAVEL_TELEPORT: ink(0xc76bff, 230), TRAVEL_JUMPPAD: ink(0xff8a3d, 230),
        TRAVEL_LADDER: ink(0xffffff, 230), TRAVEL_SWIM: ink(0x4f8ef7, 200), TRAVEL_ELEVATOR: ink(0x3dd6d0, 230)
    };
    drawn = 0;
    for place in level_places(atlas) {
        for move in [edge place->:Move:->] {
            if drawn >= 8000 or move.fall {
                continue;
            }
            # A walked way is there and back: drawn once.
            if move.kind == TRAVEL_WALK and place.area > move.to {
                continue;
            }
            wire_line(move.start.add(Vec3(z=-20.0)), move.finish.add(Vec3(z=-20.0)), tones.get(move.kind, ink(0xffffff, 200)));
            drawn += 1;
        }
    }
    # The graph's gates (amber when they want a key, orange when something
    # else opens them, grey when they come by themselves), each opener a
    # cross joined to the places it is done from.
    for gate in graph_gates(atlas) {
        tone = ink(0x8a8a8a, 160) if not gate.needs else (ink(0xffc94d, 230) if [need for need in gate.needs if need.startswith("key")] else ink(0xff8a3d, 230));
        wire_box(gate.box.mins, gate.box.maxs, tone);
    }
    for opener in graph_openers(atlas) {
        at = opener.point;
        mark = ink(0xff5fd2, 230);
        wire_line(at.add(Vec3(x=-12.0)), at.add(Vec3(x=12.0)), mark);
        wire_line(at.add(Vec3(y=-12.0)), at.add(Vec3(y=12.0)), mark);
        wire_line(at.add(Vec3(z=-12.0)), at.add(Vec3(z=12.0)), mark);
        for place in opener_places(opener)[:3] {
            wire_line(at, place.center, ink(0xff5fd2, 90));
        }
    }
    # The proof's sure route, white and raised, and its traps in red.
    proof = self.nav_proof;
    if proof is not None {
        by_area: dict[int, LevelPlace] = {};
        for place in level_places(atlas) {
            by_area[place.area] = place;
        }
        last: Vec3 | None = None;
        for area in proof.route {
            place = by_area.get(area, None);
            if place is None {
                continue;
            }
            here = place.center.add(Vec3(z=8.0));
            if last is not None {
                wire_line(last, here, ink(0xffffff, 255));
            }
            last = here;
        }
        for trap in proof.traps {
            place = by_area.get(int(trap.split(" ")[0]), None);
            if place is not None {
                wire_box(place.box.mins, place.box.maxs.add(Vec3(z=56.0)), ink(0xe5484d, 255));
            }
        }
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
            found.append(Finding(words=item.title() + " cannot be reached from " + starts[0].title() + " over the level graph", item=item));
        }
    }
    return found;
}

"""Read the level graph of what is built now (as the game plays it, every
door posed open), give it to the router, and keep it."""
impl Studio.nav_read(sims: bool) -> LevelGraph | None {
    self.nav_proof = None;
    app = self.app;
    if app is None {
        return None;
    }
    for old in [app.world->:HasNavMesh:->][?:NavMesh] {
        app.world del->:HasNavMesh:-> old;
    }
    atlas = read_level_graph(app.world, app.level, None, ReadOptions(sims=sims));
    self.nav_atlas = atlas;
    self.nav_aas = graph_aas(atlas);
    baked = self.nav_aas;
    if baked is not None {
        self.nav_mesh = build_navmesh(app.world, baked, app.level.bsp);
    }
    return atlas;
}

impl Studio.nav_command(scene: Scene, args: list[str]) -> bool {
    if args[0] == "ed_playtest" {
        if not self.is_built_scene() {
            self.say("A playtest is of a scene of brushes (ed_scene, ed_convert)");
            return True;
        }
        # What can never be set off, a lock with no key: the logic first;
        # then the level graph, read with its jumps and falls run, proven.
        lost = scene.softlocks();
        atlas = self.nav_read(True);
        rows: list[TreeRow] = [];
        self.findings = [];
        verdict = "";
        if atlas is not None {
            proof = prove_level(atlas);
            self.nav_proof = proof;
            if proof.finishes and proof.softlocks == 0 {
                verdict = "It can be finished: the way out is reached for sure, nothing strands a player"
                    + (", and it requires " + ", ".join(proof.required) if proof.required else "");
            } else {
                for line in explain_proof(atlas, proof) {
                    lost.append(Finding(words=line));
                }
                if not proof.finishes {
                    lost.append(Finding(words="The way out is not reached for sure from the start"));
                } else {
                    lost.append(Finding(words=str(proof.softlocks) + " states strand a player"));
                }
            }
        }
        for finding in lost {
            print("studio: playtest stopped " + finding.words);
            rows.append(TreeRow(key=str(len(rows)), text=finding.words, tone="text", note="!"));
            self.findings.append(finding);
        }
        print("studio: playtest finish=" + ("1" if len(lost) == 0 else "0") + " stopped=" + str(len(lost)));
        panel = self.ui;
        if panel is not None {
            if not rows {
                rows.append(TreeRow(key="none", text=verdict or "It can be finished.", tone="faint"));
            }
            panel.checks.rows = rows;
        }
        self.say(verdict if len(lost) == 0 else "It cannot be finished: " + lost[len(lost) - 1].words + " (the Checks tab lists why)");
        return True;
    }
    if args[0] != "ed_nav" {
        return False;
    }
    app = self.app;
    how = args[1] if len(args) > 1 else "";
    if not how {
        print(self.nav_words());
        self.say("No level graph is read (ed_nav bake)" if self.nav_mesh is None else self.nav_words()[8:]);
        return True;
    }
    if how == "bake" {
        if app is None or not self.is_built_scene() {
            self.say("A level graph is read for a scene (ed_scene): a shipped arena has its own");
            return True;
        }
        atlas = self.nav_read(False);
        if atlas is None or len(level_places(atlas)) == 0 {
            self.say("The scene has no floor to stand on");
            return True;
        }
        print(self.nav_words());
        self.say("Read " + str(len(level_places(atlas))) + " places to stand and the ways between them");
        return True;
    }
    if how == "write" {
        baked = self.nav_aas;
        if baked is None {
            self.say("ed_nav write: read the level graph first (ed_nav bake)");
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
        self.nav_atlas = None;
        self.nav_proof = None;
        self.say("The level graph is forgotten");
        return True;
    }
    if how == "show" {
        word = args[2] if len(args) > 2 else "";
        self.nav_shown = (not self.nav_shown) if word not in ["on", "off"] else word == "on";
        self.say("The level graph is drawn: ways walked green, jumped yellow, dropped red, climbed white, swum blue, lifted cyan, teleported violet, thrown orange; gates boxed (amber a key, orange opened elsewhere), openers pink; after a playtest the proven route white and traps red" if self.nav_shown else "The level graph is not drawn");
        return True;
    }
    mesh = self.nav_mesh;
    if mesh is None {
        self.say("Read the level graph first (ed_nav bake)");
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
    self.say("ed_nav [bake | check | route <from xyz> <to xyz> | show [on|off] | write [file] | clear]");
    return True;
}
