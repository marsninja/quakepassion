"""Passion's generated expeditions in the studio. `ed_exp open <seed>` runs
the generator and opens what it made as a document of brushes, a group a
room; the expedition's own account of itself (its mission's beats and links,
its site's rooms and the ways between, the proof that it can be finished)
is kept beside the document and said, drawn over the level, and worked on."""

import os;
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Texture }
import from engine.assets.content { game_directory }
import from games.passion.generate { Survey, survey }
import from games.passion.compile { compile_blueprint }
import from games.passion.materials { load_materials }
import from games.passion.mission { beats_of, links_of }
import from games.passion.layout { rooms_of, passages_of }
import from games.passion.playtest { progress }
import from editor.document.scene { Scene }
import from editor.document.expedition { room_groups, room_middle, beat_words, link_words, room_words }
import from editor.formats.bspmap { bsp_items, level_material }
import from editor.formats.map { write_map }
import from editor.tools.host { ToolHost, StudioTool }
import from editor.ui.canvas { ink }

obj Expeditions(StudioTool) {
    has record: Survey | None = None,
        # The materials every expedition is built from, read once.
        textures: list[Texture] = [],
        shown: bool = False;

    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_exp",
                "ed_exp [open <seed> | mission | rooms | ways | proof | show [on|off]]",
                "a Passion expedition: generate a seed and open it as a document of brushes, a group a room; say its mission, its rooms, the ways between them and the proof that it can be finished; draw the ways over the level"
            )
        ];
    }

    """Compile the expedition in hand and open it as a document: a map file
    among the scenes, its world's brushes handed to a group for each room."""
    def open_document(host: ToolHost) -> bool {
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
        bsp = compile_blueprint(bp, site).bsp;
        if len(self.textures) == 0 {
            self.textures = load_materials(game_directory("passion"));
        }
        bsp.textures = self.textures;
        # The size each texture is drawn at as a material.
        sizes: dict[str, list[int]] = {};
        for image in bsp.textures {
            named = level_material("passion", image.name);
            if named and named not in sizes {
                seen = host.picture(named);
                sizes[named] = [max(1, seen.width), max(1, seen.height)]
                    if seen is not None
                    else [max(1, image.width), max(1, image.height)];
            }
        }
        found = bsp_items(bsp, [dict(each.fields) for each in bsp.entities], "blockout", sizes);
        if len(found) == 0 {
            return False;
        }
        grouped = room_groups(found, rooms_of(site));
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
