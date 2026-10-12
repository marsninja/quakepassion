"""Passion's generated expeditions in the studio. `ed_exp open <seed>` runs
the generator and opens what it made as a document of brushes, a group a
room; the expedition's own account of itself (its mission's beats and links,
its site's rooms and the ways between, the proof that it can be finished)
is kept beside the document and said, drawn over the level, and worked on."""

import os;
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Texture }
import from engine.assets.content { game_directory }
import from games.passion.generate { Survey, Candidate, survey, measure, judge }
import from games.passion.compile { compile_blueprint }
import from games.passion.materials {
    load_materials, district_names, kept_table, material_word, editor_material_names, SLOT_NAMES
}
import from games.passion.director { ROSTER }
import from games.passion.mission { Expedition, PATTERNS, beats_of, links_of }
import from editor.document.missionedit {
    LINK_MODES, BEAT_KINDS, mission_copy, mission_fault, add_link, drop_link, set_link, set_grant, add_beat, lay_pattern
}
import from games.passion.layout { Site, rooms_of, passages_of, embed, relay, target_heights, solve_heights }
import from games.passion.blueprint { new_blueprint, carve_rooms, carve_corridors, carve_windows }
import from games.passion.interior { RECIPES }
import from games.passion.director { direct }
import from games.passion.random { stream_for }
import from games.passion.playtest { progress }
import from editor.document.scene { Scene, scene_map, item_switched, LOCK_KEY }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { box_sides }
import from editor.document.expedition { room_groups, room_middle, beat_words, link_words, room_words }
import from editor.formats.bspmap { bsp_items, level_material }
import from editor.formats.map { write_map, map_renamed }
import from editor.tools.host { ToolHost, StudioTool, PanelSpec }
import from editor.ui.canvas { ink }

obj Expeditions(StudioTool) {
    has record: Survey | None = None,
        # The materials every expedition is built from, read once.
        textures: list[Texture] = [],
        shown: bool = False,
        # How many times each stage's dice have been rolled again, and how
        # many changes have been made to the mission by hand.
        salts: dict[str, int] = {},
        edits: int = 0,
        # Where rooms are being put ([x, y, w, h] by beat) while the site is
        # laid out again, and the floors rooms have been given by hand.
        places: dict[int, list[int]] = {},
        floors: dict[int, int] = {},
        # The foes the rooms are filled from ([] for the director's whole
        # roster), materials given to one room's slot ("7:wall" by room and
        # slot), the niche asked for, and whether the graphs are open.
        roster: list[str] = [],
        slots: dict[str, str] = {},
        graphing: bool = False;

    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_exp",
                "ed_exp [open <seed> | mission | rooms | ways | proof | show [on|off] | again [rooms|population|layout] | fill <room> <recipe|any> | district <room> <n> | tension <room> <0..1> | budget <room> <threat|auto> | density <0.15..1> | niche | link <beat> <beat> [mode] [tokens] | unlink <link> | mode <link> <mode> [tokens] | grant|ungrant <beat> <token> | beat <from beat> [kind] [size] | pattern <name> <beat> <beat> | move <room> <dx> <dy> | size <room> <w> <h> | floor <room> <height|auto> | reroute | graphs | niche <measure> <0..1> | roster <classes>|all | budget route <threat|auto> | slot <room> <slot> <material|auto>]",
                "a Passion expedition: generate a seed and open it as a document of brushes, a group a room; say its mission, rooms, ways and proof; draw the ways over the level; and make parts of it again while what is locked is kept: rooms' insides, who is in them, the layout; a room's recipe, district, tension and budget"
            )
        ];
    }

    """Compile the expedition in hand and open it as a document: a map file
    among the scenes, its world's brushes handed to a group for each room."""
    def open_document(host: ToolHost, kept: list[MapItem] = []) -> bool {
        record = self.record;
        if record is None {
            return False;
        }
        bp = record.bp;
        site = record.site;
        folder = host.folder("scenes");
        if bp is None or site is None or not folder {
            return False;
        }
        compiled = compile_blueprint(bp, site);
        bsp = compiled.bsp;
        if len(self.textures) == 0 {
            self.textures = load_materials(game_directory("passion"));
        }
        bsp.textures = self.textures;
        # The size each texture is drawn at as a material.
        # A Quake texture goes by its name alone in the level, and by its map
        # and name as a material the studio can find: sizes are kept under both.
        renames = editor_material_names();
        sizes: dict[str, list[int]] = {};
        for image in bsp.textures {
            named = level_material("passion", image.name);
            if named and named not in sizes {
                as_material = renames[named] if named in renames else named;
                seen = host.picture(as_material);
                sizes[named] = [max(1, seen.width), max(1, seen.height)]
                    if seen is not None
                    else [max(1, image.width), max(1, image.height)];
                sizes[as_material] = sizes[named];
            }
        }
        found = bsp_items(bsp, [dict(each.fields) for each in bsp.entities], "blockout", sizes);
        if len(found) == 0 {
            return False;
        }
        found = map_renamed(found, renames);
        grouped = room_groups(found, rooms_of(site));
        if len(compiled.exit_low) >= 3 and len(compiled.exit_high) >= 3 {
            # The way out is a volume of the generator's own, not an entity
            # of the level: in the document it is one, so that it is seen,
            # kept and played to.
            grouped.append(
                MapItem(
                    fields={"classname": "trigger_changelevel", "map": "passion_complete"},
                    brushes=[
                        box_sides(
                            Vec3(x=compiled.exit_low[0], y=compiled.exit_low[1], z=compiled.exit_low[2]),
                            Vec3(x=compiled.exit_high[0], y=compiled.exit_high[1], z=compiled.exit_high[2]),
                            "trigger"
                        )
                    ]
                )
            );
        }
        if len(self.slots) > 0 {
            # A room given a material of its own for a slot: its brushes
            # that have the district's material there have that one.
            table = kept_table();
            painted = 0;
            for item in grouped {
                words = item.fields.get("_group_name", "").split();
                if len(words) < 2 or words[0] != "room" or not words[1].isdigit() or int(words[1]) >= len(rooms_of(site)) {
                    continue;
                }
                room = rooms_of(site)[int(words[1])];
                for (number, slot) in enumerate(SLOT_NAMES) {
                    wanted = self.slots.get(words[1] + ":" + slot, "");
                    if not wanted or room.district >= len(table.slots) or number >= len(table.slots[room.district]) {
                        continue;
                    }
                    usual = material_word(table.slots[room.district][number]);
                    for sides in item.brushes {
                        for side in sides {
                            if side.material == usual {
                                side.material = wanted;
                                painted += 1;
                            }
                        }
                    }
                }
            }
            print("studio: expedition slots=" + str(len(self.slots)) + " faces=" + str(painted));
        }
        if len(kept) > 0 {
            # Rooms that were locked are as they were left, hand edits and all.
            names = [each.fields.get("_group_name", "") for each in kept];
            grouped = [each for each in grouped if each.fields.get("_group_name", "") not in names] + kept;
        }
        path = folder + "/expedition_" + str(record.seed) + ".map";
        try {
            os.makedirs(folder, exist_ok=True);
            with open(path, "w") as file {
                file.write(write_map(grouped, sizes=sizes));
            }
        } except OSError {
            host.say("ed_exp: could not write " + path);
            return False;
        }
        host.run(["ed_open", path]);
        brushes = 0;
        for item in grouped {
            brushes += len(item.brushes);
        }
        print(
            "studio: expedition opened seed=" + str(record.seed) + " entities=" + str(len(grouped)) + " brushes=" + str(brushes)
                + " rooms=" + str(len(rooms_of(site))) + " file=" + os.path.basename(path)
        );
        return True;
    }

    """The words a stage's dice are found by: its own, or with how many
    times they have been rolled again."""
    def dice(stage: str) -> str {
        count = self.salts.get(stage, 0);
        return stage if count == 0 else stage + "#" + str(count);
    }

    """Run the generator again from a stage on (layout, or rooms), with what
    has been asked of the rooms and the dice as they stand. Answers what
    stopped it, or "" when the expedition was made and proved."""
    def rebuild(stage: str) -> str {
        record = self.record;
        if record is None {
            return "none";
        }
        plan = record.plan;
        site = record.site;
        if plan is None or site is None {
            return "none";
        }
        stream = stream_for(record.seed, "candidate").child("k", plan.candidate);
        beats = beats_of(plan);
        if stage == "layout" {
            fresh = embed(plan, stream.derive(self.dice("layout")));
            if fresh.failures {
                return "layout " + fresh.failures;
            }
            target_heights(fresh, stream.derive(self.dice("heights")), plan.verticality);
            if not solve_heights(fresh) {
                return "heights";
            }
            for room in rooms_of(fresh) {
                room.district = beats[room.beat].district;
            }
            site = fresh;
        } elif stage == "relay" {
            # The rooms where they are said to be, the ways routed afresh,
            # and the floors solved again.
            moved = relay(plan, site, self.places, stream.derive(self.dice("relay")));
            if moved.failures {
                return "layout: " + moved.failures;
            }
            target_heights(moved, stream.derive(self.dice("heights")), plan.verticality);
            for room in rooms_of(moved) {
                if room.beat in self.floors {
                    room.target = self.floors[room.beat];
                    room.z = room.target;
                }
            }
            if not solve_heights(moved) {
                return "heights";
            }
            site = moved;
        }
        bp = new_blueprint(site);
        try {
            if not carve_rooms(bp, site, stream.derive(self.dice("rooms")), plan.verticality) {
                return "interior";
            }
            if not carve_corridors(bp, site, plan, stream.derive(self.dice("corridors")), beats) {
                return "corridor";
            }
        } except (AssertionError, ValueError) {
            return "carving";
        }
        carve_windows(bp, site);
        if len([door for door in bp.doors if door.kind == "invalid"]) > 0 {
            return "doors";
        }
        economy = direct(plan, site, bp, stream.derive(self.dice("director")), plan.density, self.roster);
        starts = [mark for mark in bp.marks if mark.kind == "info_player_start"];
        if len(starts) == 0 {
            return "start";
        }
        proof = progress(plan, bp, site, starts[0].x, starts[0].y);
        if not proof.reached_exit {
            return "proof";
        }
        record.site = site;
        record.bp = bp;
        record.economy = economy;
        record.start = [starts[0].x, starts[0].y, starts[0].z];
        judged = Candidate(plan=plan, site=site, bp=bp, economy=economy, proof=proof);
        record.measured = measure(judged);
        record.quality = judge(judged);
        return "";
    }

    """The rooms whose groups are locked in a scene, by their beats, and
    those groups as the scene has them."""
    def locked_rooms(scene: Scene) -> tuple[list[int], list[MapItem]] {
        beats: list[int] = [];
        kept: list[MapItem] = [];
        owners = scene.items();
        written = scene_map(scene);
        for at in range(min(len(owners), len(written))) {
            item = owners[at];
            words = item.fields.get("_group_name", "").split();
            if item.classname() == "func_group" and item_switched(item, LOCK_KEY) and len(words) >= 2 and words[0] == "room"
                and words[1].isdigit() {
                beats.append(int(words[1]));
                kept.append(written[at]);
            }
        }
        return (beats, kept);
    }

    """Make the expedition again after something was asked of it, and open
    it; `stage` is where from. False (and what stopped it said) when it
    could not be made: the caller puts back what it changed."""
    def remake(host: ToolHost, scene: Scene, stage: str) -> bool {
        reason = self.rebuild(stage);
        if reason {
            print("studio: expedition refused " + reason);
            host.say("The expedition could not be made that way (" + reason + "): it is as it was");
            return False;
        }
        self.open_document(host, self.locked_rooms(scene)[1]);
        print(self.words());
        if self.graphing {
            self.show_graphs(host);
        }
        return True;
    }

    """The expedition as bars to drag: how full it is, what it aims at on
    each of its four measures (with what it measures said beside), and
    every room's tension in the order the rooms are come to."""
    def show_graphs(host: ToolHost) {
        record = self.record;
        if record is None {
            return;
        }
        plan = record.plan;
        site = record.site;
        if plan is None or site is None {
            return;
        }
        bars: list[tuple[str, float, str]] = [("how full it is", plan.density, "ed_exp density")];
        called = ["loops", "height", "density", "size"];
        for axis in range(min(4, len(record.niche), len(record.measured))) {
            bars.append(
                (
                    "aims at " + called[axis] + " (measures " + str(round(record.measured[axis], 2)) + ")",
                    float(record.niche[axis]) / 2.0,
                    "ed_exp niche " + called[axis]
                )
            );
        }
        ordered: list[int] = [];
        rooms = rooms_of(site);
        for room in rooms {
            at = len(ordered);
            while at > 0 and rooms[ordered[at - 1]].order > room.order {
                at -= 1;
            }
            ordered.insert(at, room.beat);
        }
        for beat in ordered {
            room = rooms[beat];
            bars.append(("room " + str(beat) + " " + room.kind + " tension", room.tension, "ed_exp tension " + str(beat)));
        }
        economy = record.economy;
        host.panel(
            "expedition",
            PanelSpec(
                title="Expedition " + str(record.seed) + ": its tension along the way, and what it aims at",
                notes=[
                    record.briefing,
                    "Quality " + str(round(record.quality, 2)) + (
                        ", " + str(economy.monsters) + " opponents at a threat of " + str(round(economy.threat, 1))
                        if economy is not None
                        else ""
                    ),
                    "Drag a bar and let go: that part is made again and proved."
                ],
                bars=bars,
                buttons=[("Rooms again", "ed_exp again rooms"), ("Population again", "ed_exp again population")]
            )
        );
    }

    """Prove a mission that was just changed by hand and lay the expedition
    out again from it. One that is not sound, or cannot be laid out and
    finished, is given up: `backup` (the mission as it was) is gone back
    to. Answers whether the change stands."""
    def mission_changed(host: ToolHost, scene: Scene, backup: Expedition) -> bool {
        record = self.record;
        if record is None {
            return False;
        }
        plan = record.plan;
        fault = mission_fault(plan) if plan is not None else "there is no mission";
        if fault {
            record.plan = backup;
            print("studio: expedition unsound " + fault);
            host.say("The mission would not be sound (" + fault + "): it is as it was");
            return False;
        }
        if not self.remake(host, scene, "layout") {
            record.plan = backup;
            self.rebuild("layout");
            return False;
        }
        return True;
    }

    """How the expedition in hand stands, in a line."""
    def words -> str {
        record = self.record;
        if record is None {
            return "studio: expedition none";
        }
        plan = record.plan;
        site = record.site;
        return "studio: expedition seed=" + str(record.seed) + " archetype=" + record.archetype + " beats="
            + str(len(beats_of(plan)) if plan is not None else 0) + " links=" + str(len(links_of(plan)) if plan is not None else 0)
            + " rooms=" + str(len(rooms_of(site)) if site is not None else 0) + " ways="
            + str(len(passages_of(site)) if site is not None else 0) + " quality=" + str(round(record.quality, 2))
            + " tried=" + str(record.candidates) + " valid=" + str(record.valid) + " shown=" + ("1" if self.shown else "0");
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_exp" {
            return False;
        }
        how = args[1] if len(args) > 1 else "";
        if how == "open" {
            if len(args) < 3 or not args[2].isdigit() {
                host.say("ed_exp open <seed>: a whole number, the expedition's own");
                return True;
            }
            made: Survey | None = None;
            try {
                made = survey(int(args[2]));
            } except ValueError {
                made = None;
            }
            if made is None {
                host.say("No expedition could be made of seed " + args[2]);
                return True;
            }
            self.record = made;
            # A seed opened is as the generator makes it: nothing asked of it yet.
            self.salts = {};
            self.floors = {};
            self.places = {};
            self.edits = 0;
            self.roster = [];
            self.slots = {};
            if not self.open_document(host) {
                host.say("The expedition of seed " + args[2] + " could not be opened as a document");
                return True;
            }
            print(self.words());
            host.say("Seed " + args[2] + ": " + made.briefing);
            return True;
        }
        record = self.record;
        if record is None {
            host.say("No expedition is in hand (ed_exp open <seed> generates one and opens it)");
            return True;
        }
        plan = record.plan;
        site = record.site;
        bp = record.bp;
        if plan is None or site is None or bp is None {
            return True;
        }
        if how == "mission" {
            for beat in beats_of(plan) {
                print("studio: expedition " + beat_words(beat));
            }
            for link in links_of(plan) {
                print("studio: expedition " + link_words(link));
            }
            host.say(str(len(beats_of(plan))) + " beats and " + str(len(links_of(plan))) + " links: " + record.briefing);
            return True;
        }
        if how == "rooms" {
            for room in rooms_of(site) {
                print("studio: expedition " + room_words(room));
            }
            host.say(str(len(rooms_of(site))) + " rooms on a site of " + str(site.width) + " by " + str(site.height));
            return True;
        }
        if how == "ways" {
            for passage in passages_of(site) {
                print(
                    "studio: expedition way " + str(passage.link) + " " + str(passage.tail) + ">" + str(passage.head) + " "
                        + passage.mode + (" needs=" + ",".join(passage.needs) if passage.needs else "")
                        + (" teleport" if passage.teleport else "") + (" window" if passage.window else "")
                        + (" drop=" + str(passage.drop) if passage.drop else "")
                );
            }
            host.say(str(len(passages_of(site))) + " ways between the rooms");
            return True;
        }
        if how == "proof" {
            if len(record.start) < 2 {
                host.say("The expedition has no start to prove it from");
                return True;
            }
            proof = progress(plan, bp, site, record.start[0], record.start[1]);
            print(
                "studio: expedition proof exit=" + ("1" if proof.reached_exit else "0") + " rounds=" + str(proof.rounds)
                    + " rooms=" + str(len(proof.rooms)) + " of=" + str(len(rooms_of(site))) + " tokens="
                    + (",".join(proof.tokens) if proof.tokens else "-")
            );
            host.say(
                "It can be finished: the exit is reached in " + str(proof.rounds) + " rounds, through "
                    + str(len(proof.rooms)) + " rooms"
                if proof.reached_exit
                else "It cannot be finished: the exit is not reached (" + str(len(proof.rooms)) + " rooms are)"
            );
            return True;
        }
        if how in ["link", "unlink", "mode", "grant", "ungrant", "beat", "pattern"] {
            # The mission's own graph is changed, proved, and laid out again.
            backup = mission_copy(plan);
            self.edits += 1;
            rolls = stream_for(record.seed, "edit").child("n", self.edits);
            numbers = [int(word) if word.isdigit() else -1 for word in args[2:]];
            done = False;
            told = "";
            if how == "link" and len(args) > 3 {
                way = args[4].lower() if len(args) > 4 else "open";
                done = add_link(plan, rolls, numbers[0], numbers[1], way, args[5:]);
                told = "A link from beat " + args[2] + " to beat " + args[3] + " (" + way + ")";
            } elif how == "unlink" and len(args) > 2 {
                done = drop_link(plan, numbers[0]);
                told = "Link " + args[2] + " is gone";
            } elif how == "mode" and len(args) > 3 {
                done = set_link(plan, numbers[0], args[3].lower(), args[4:]);
                told = "Link " + args[2] + " is " + args[3].lower() + (", needing " + ", ".join(args[4:]) if len(args) > 4 else "");
            } elif how in ["grant", "ungrant"] and len(args) > 3 {
                done = set_grant(plan, numbers[0], args[3], how == "grant");
                told = "Beat " + args[2] + (" grants " if how == "grant" else " no longer grants ") + args[3];
            } elif how == "beat" and len(args) > 2 {
                kind = args[3].lower() if len(args) > 3 else "room";
                added = add_beat(plan, rolls, numbers[0], kind, numbers[2] if len(numbers) > 2 and numbers[2] >= 0 else 1);
                done = added >= 0;
                told = "Beat " + str(added) + " (" + kind + ") is reached from beat " + args[2];
            } elif how == "pattern" and len(args) > 4 {
                grown = lay_pattern(plan, rolls, args[2].lower(), numbers[1], numbers[2]);
                done = grown >= 0;
                told = "The pattern " + args[2].lower() + " lies between beats " + args[3] + " and " + args[4] + ", with "
                    + str(max(0, grown)) + " beats of its own";
            }
            if not done {
                host.say(
                    "ed_exp link <beat> <beat> [" + "|".join(LINK_MODES) + "] [tokens] | unlink <link> | mode <link> <mode> [tokens] | "
                        + "grant|ungrant <beat> <token> | beat <from beat> [" + "|".join(BEAT_KINDS) + "] [size] | pattern <"
                        + "|".join(PATTERNS) + "> <beat> <beat>"
                );
                return True;
            }
            if self.mission_changed(host, scene, backup) {
                print("studio: expedition mission " + how + " beats=" + str(len(beats_of(plan))) + " links=" + str(len(links_of(plan))));
                host.say(told + ": proved, and laid out again");
            }
            return True;
        }
        if how in ["move", "size", "floor", "reroute"] {
            rooms = rooms_of(site);
            which = int(args[2]) if len(args) > 2 and args[2].isdigit() else -1;
            amounts: list[int] = [];
            for word in args[3:] {
                try {
                    amounts.append(int(float(word)));
                } except ValueError {
                    continue;
                }
            }
            had_floor = self.floors.get(which, -100000);
            self.places = {};
            if how == "reroute" {
                self.salts["relay"] = self.salts.get("relay", 0) + 1;
            } elif which < 0 or which >= len(rooms) {
                host.say("ed_exp move <room> <dx> <dy> | size <room> <w> <h> | floor <room> <height|auto> | reroute");
                return True;
            } elif how == "move" and len(amounts) >= 2 {
                self.places[which] = [rooms[which].x + amounts[0], rooms[which].y + amounts[1], rooms[which].w, rooms[which].h];
            } elif how == "size" and len(amounts) >= 2 {
                self.places[which] = [rooms[which].x, rooms[which].y, amounts[0], amounts[1]];
            } elif how == "floor" and len(amounts) >= 1 {
                self.floors[which] = amounts[0];
            } elif how == "floor" and len(args) > 3 and args[3] == "auto" {
                self.floors.pop(which, None);
            } else {
                host.say("ed_exp move <room> <dx> <dy> | size <room> <w> <h> | floor <room> <height|auto> | reroute");
                return True;
            }
            stood = self.remake(host, scene, "relay");
            self.places = {};
            if not stood {
                # The site is as it was: only what was asked is put back.
                if how == "reroute" {
                    self.salts["relay"] = self.salts["relay"] - 1;
                } elif how == "floor" {
                    if had_floor == -100000 {
                        self.floors.pop(which, None);
                    } else {
                        self.floors[which] = had_floor;
                    }
                }
                return True;
            }
            after = rooms_of(record.site) if record.site is not None else rooms;
            if which >= 0 and which < len(after) {
                print("studio: expedition " + room_words(after[which]));
            }
            print("studio: expedition laid " + how + " ways=" + str(len(passages_of(record.site)) if record.site is not None else 0));
            host.say(
                "The ways between the rooms are routed again" if how == "reroute"
                else "Room " + str(which) + ": " + how + " " + " ".join(args[3:]) + ", the ways routed again and the floors solved"
            );
            return True;
        }
        if how == "again" {
            what = args[2] if len(args) > 2 else "rooms";
            if what not in ["rooms", "population", "layout"] {
                host.say("ed_exp again [rooms|population|layout]");
                return True;
            }
            locked = self.locked_rooms(scene)[0];
            rolled: list[int] = [];
            if what == "rooms" {
                # Every room whose group is not locked rolls its own dice again.
                for room in rooms_of(site) {
                    if room.beat not in locked {
                        room.roll += 1;
                        rolled.append(room.beat);
                    }
                }
            } elif what == "population" {
                self.salts["director"] = self.salts.get("director", 0) + 1;
            } else {
                self.salts["layout"] = self.salts.get("layout", 0) + 1;
                self.salts["heights"] = self.salts.get("heights", 0) + 1;
            }
            if not self.remake(host, scene, "layout" if what == "layout" else "rooms") {
                # As it was: the dice go back, and it is made as before.
                for room in rooms_of(site) {
                    if room.beat in rolled {
                        room.roll -= 1;
                    }
                }
                if what == "population" {
                    self.salts["director"] = self.salts["director"] - 1;
                } elif what == "layout" {
                    self.salts["layout"] = self.salts["layout"] - 1;
                    self.salts["heights"] = self.salts["heights"] - 1;
                }
                self.rebuild("rooms");
                return True;
            }
            print(
                "studio: expedition again " + what + " rolled=" + str(len(rolled)) + " kept="
                    + (",".join([str(each) for each in locked]) if locked else "-")
            );
            host.say(
                "Made again: " + (
                    str(len(rolled)) + " rooms' insides, " + str(len(locked)) + " kept as they were locked"
                    if what == "rooms"
                    else ("who and what is in the rooms" if what == "population" else "where the rooms lie and the ways between")
                )
            );
            return True;
        }
        if how in ["fill", "district", "tension", "budget"] and not (how == "budget" and len(args) > 2 and args[2] == "route") {
            rooms = rooms_of(site);
            which = int(args[2]) if len(args) > 3 and args[2].isdigit() else -1;
            if which < 0 or which >= len(rooms) {
                host.say("ed_exp " + how + " <room> <value>: a room by its number (ed_exp rooms lists them)");
                return True;
            }
            room = rooms[which];
            value = args[3].lower();
            was_wanted = room.wanted;
            was_district = room.district;
            was_tension = room.tension;
            was_budget = room.budget;
            if how == "fill" {
                if value != "any" and value not in RECIPES {
                    host.say("ed_exp fill <room> <" + "|".join(RECIPES) + "|any>");
                    return True;
                }
                room.wanted = "" if value == "any" else value;
            } elif how == "district" {
                if not value.isdigit() or int(value) >= len(district_names()) {
                    host.say("ed_exp district <room> <0.." + str(len(district_names()) - 1) + ">: " + ", ".join(district_names()));
                    return True;
                }
                room.district = int(value);
                beats_of(plan)[room.beat].district = int(value);
            } else {
                amount = -1.0;
                try {
                    amount = float(value) if value != "auto" else -1.0;
                } except ValueError {
                    host.say("ed_exp " + how + " <room> <number>");
                    return True;
                }
                if how == "tension" {
                    room.tension = max(0.0, min(1.0, amount));
                } else {
                    room.budget = amount if amount >= 0.0 else -1.0;
                }
            }
            if not self.remake(host, scene, "rooms") {
                room.wanted = was_wanted;
                room.district = was_district;
                beats_of(plan)[room.beat].district = was_district;
                room.tension = was_tension;
                room.budget = was_budget;
                self.rebuild("rooms");
                return True;
            }
            print("studio: expedition " + room_words(room) + " tension=" + str(round(room.tension, 2)) + " budget=" + str(round(room.budget, 2)));
            host.say(
                "Room " + str(which) + " is made by " + room.recipe + (" (asked for " + room.wanted + ")" if room.wanted and room.wanted != room.recipe else "")
                if how == "fill"
                else "Room " + str(which) + ": " + how + " " + value
            );
            return True;
        }
        if how == "graphs" {
            word = args[2] if len(args) > 2 else "";
            if word == "close" or (not word and self.graphing) {
                self.graphing = False;
                host.panel_close("expedition");
                return True;
            }
            self.graphing = True;
            self.show_graphs(host);
            print("studio: expedition graphs rooms=" + str(len(rooms_of(site))));
            return True;
        }
        if how == "roster" {
            known = [foe.kind for foe in ROSTER];
            chosen = [word.lower() for word in args[2:]];
            if len(chosen) == 0 {
                print("studio: expedition roster " + (",".join(self.roster) if self.roster else "all") + " of " + ",".join(known));
                host.say("Filled from: " + (", ".join(self.roster) if self.roster else "the director's whole roster") + " (ed_exp roster <classes>|all)");
                return True;
            }
            if chosen != ["all"] and len([each for each in chosen if each not in known]) > 0 {
                host.say("ed_exp roster <" + "|".join(known) + " ...>|all");
                return True;
            }
            was_roster = self.roster;
            self.roster = [] if chosen == ["all"] else chosen;
            if not self.remake(host, scene, "rooms") {
                self.roster = was_roster;
                self.rebuild("rooms");
                return True;
            }
            economy = record.economy;
            print("studio: expedition roster " + (",".join(self.roster) if self.roster else "all") + " opponents=" + str(economy.monsters if economy is not None else 0));
            host.say("The rooms are filled from " + (", ".join(self.roster) if self.roster else "the whole roster"));
            return True;
        }
        if how == "slot" {
            rooms = rooms_of(site);
            which = int(args[2]) if len(args) > 4 and args[2].isdigit() else -1;
            slot = args[3].lower() if len(args) > 3 else "";
            if which < 0 or which >= len(rooms) or slot not in SLOT_NAMES {
                host.say("ed_exp slot <room> <" + "|".join(SLOT_NAMES) + "> <material|auto>");
                return True;
            }
            if args[4] == "auto" {
                self.slots.pop(str(which) + ":" + slot, None);
            } else {
                self.slots[str(which) + ":" + slot] = args[4];
            }
            self.open_document(host, self.locked_rooms(scene)[1]);
            host.say(
                "Room " + str(which) + " has its district's " + slot if args[4] == "auto"
                else "Room " + str(which) + " has " + args[4] + " for its " + slot
            );
            return True;
        }
        if how == "budget" and len(args) > 3 and args[2] == "route" {
            # Every room along the way the mission means to be taken.
            rooms = rooms_of(site);
            amount = -1.0;
            try {
                amount = float(args[3]) if args[3] != "auto" else -1.0;
            } except ValueError {
                host.say("ed_exp budget route <threat|auto>");
                return True;
            }
            before = [room.budget for room in rooms];
            along = [beat for beat in plan.route if beat >= 0 and beat < len(rooms)];
            for beat in along {
                rooms[beat].budget = amount if amount >= 0.0 else -1.0;
            }
            if not self.remake(host, scene, "rooms") {
                for (number, room) in enumerate(rooms) {
                    room.budget = before[number];
                }
                self.rebuild("rooms");
                return True;
            }
            print("studio: expedition route rooms=" + ",".join([str(beat) for beat in along]) + " budget=" + args[3]);
            host.say(str(len(along)) + " rooms along the way are filled to " + args[3]);
            return True;
        }
        if how == "niche" and len(args) > 3 {
            # A measure it aims at, set: the seed is surveyed again for that niche.
            called = ["loops", "height", "density", "size"];
            if args[2] not in called {
                host.say("ed_exp niche <loops|height|density|size> <0..1>: low, middle or high");
                return True;
            }
            level = 0.5;
            try {
                level = float(args[3]);
            } except ValueError {
                host.say("ed_exp niche <loops|height|density|size> <0..1>");
                return True;
            }
            wanted_niche = list(record.niche);
            wanted_niche[called.index(args[2])] = max(0, min(2, int(round(level * 2.0))));
            fresh: Survey | None = None;
            try {
                fresh = survey(record.seed, wanted_niche);
            } except ValueError {
                fresh = None;
            }
            if fresh is None {
                host.say("No expedition of this seed could be made for that niche: it is as it was");
                return True;
            }
            self.record = fresh;
            self.salts = {};
            self.floors = {};
            self.edits = 0;
            if len(self.roster) > 0 {
                # Filled from the roster that was asked for, as before.
                self.rebuild("rooms");
            }
            self.open_document(host);
            print(self.words());
            print("studio: expedition niche set " + ",".join([str(each) for each in wanted_niche]));
            if self.graphing {
                self.show_graphs(host);
            }
            host.say("Surveyed again aiming at " + args[2] + " " + ["low", "middle", "high"][wanted_niche[called.index(args[2])]]);
            return True;
        }
        if how == "density" {
            was = plan.density;
            try {
                plan.density = max(0.15, min(1.0, float(args[2]) if len(args) > 2 else was));
            } except ValueError {
                host.say("ed_exp density <0.15..1>");
                return True;
            }
            if not self.remake(host, scene, "rooms") {
                plan.density = was;
                self.rebuild("rooms");
                return True;
            }
            economy = record.economy;
            host.say(
                "Filled to a density of " + str(round(plan.density, 2)) + (": " + str(economy.monsters) + " opponents" if economy is not None else "")
            );
            return True;
        }
        if how == "niche" {
            called = ["loops", "height", "density", "size"];
            for axis in range(min(4, len(record.measured), len(record.target))) {
                print(
                    "studio: expedition niche " + called[axis] + " target=" + str(round(record.target[axis], 2)) + " measured="
                        + str(round(record.measured[axis], 2))
                );
            }
            economy = record.economy;
            if economy is not None {
                print(
                    "studio: expedition economy opponents=" + str(economy.monsters) + " threat=" + str(round(economy.threat, 1))
                        + " health=" + str(economy.placed_health) + " armor=" + str(economy.placed_armor) + " shells="
                        + str(economy.placed_shells) + " lowest=" + str(round(economy.low, 1))
                );
            }
            for room in rooms_of(site) {
                print(
                    "studio: expedition tension room=" + str(room.beat) + " order=" + str(room.order) + " " + str(round(room.tension, 2))
                        + " " + "#" * int(round(room.tension * 20.0))
                );
            }
            host.say("Quality " + str(round(record.quality, 2)) + ": what it aimed at and what it measures are printed, with each room's tension");
            return True;
        }
        if how == "show" {
            word = args[2] if len(args) > 2 else "";
            self.shown = word == "on" if word in ["on", "off"] else not self.shown;
            host.say("The ways between the rooms are drawn over the level" if self.shown else "The ways are not drawn");
            return True;
        }
        print(self.words());
        host.say(record.briefing);
        return True;
    }

    def tick(host: ToolHost, dt: float) {}

    def draw_through(host: ToolHost, scene: Scene) {
        record = self.record;
        if not self.shown or record is None {
            return;
        }
        site = record.site;
        if site is None {
            return;
        }
        rooms = rooms_of(site);
        tones = {
            "open": ink(0x4cc38a), "locked": ink(0xe5484d), "gate": ink(0xe5484d), "valve": ink(0x5b8def),
            "shortcut": ink(0xf5a524), "secret": ink(0x9a9186), "window": ink(0x6b645b)
        };
        lift = Vec3(z=96.0);
        for passage in passages_of(site) {
            if passage.tail < 0 or passage.tail >= len(rooms) or passage.head < 0 or passage.head >= len(rooms) {
                continue;
            }
            start = room_middle(rooms[passage.tail]).add(lift);
            finish = room_middle(rooms[passage.head]).add(lift);
            tone = tones[passage.mode] if passage.mode in tones else ink(0xe6dfd4);
            host.line(start, finish, tone);
            # Which way it goes: a tick a quarter of the way back from its end.
            back = finish.add(start.sub(finish).scale(0.25));
            host.line(back, back.add(Vec3(z=24.0)), tone);
        }
    }

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        return [self.words()] if self.record is not None else [];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return [];
    }
}
