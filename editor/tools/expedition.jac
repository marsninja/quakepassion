"""Passion's generated expeditions in the studio. `ed_exp open <seed>` runs
the generator and opens what it made as a document of brushes, a group a
room and a group a corridor; the expedition's own account of itself (its
mission's beats and links, its spaces, the corridors between them, how the
critic measured it) is kept beside the document, said, and drawn over the
level."""

import os;
import from engine.math.vec3 { Vec3 }
import from games.passion.generate { Survey, survey }
import from games.passion.mission { beats_of, links_of }
import from games.passion.arrange { estate_spaces, estate_corridors }
import from games.passion.corpus { CORPUS_SP }
import from editor.document.scene { Scene }
import from editor.formats.map { MapItem, write_map }
import from editor.geometry.brush { box_sides }
import from editor.document.expedition { space_groups, space_middle, beat_words, link_words, space_words }
import from editor.tools.host { ToolHost, StudioTool, PanelSpec }
import from editor.ui.canvas { ink }

obj Expeditions(StudioTool) {
    has record: Survey | None = None,
        shown: bool = False;

    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_exp",
                "ed_exp [open <seed> | mission | rooms | ways | measures | show [on|off]]",
                "a Passion expedition: generate a seed and open it as a document of brushes, a group a room; say its mission, spaces, corridors and how it measures against the original levels; draw the ways over the level"
            )
        ];
    }

    """Open the expedition in hand as a document: a map file among the
    scenes, its world's brushes handed to a group for each space, and the
    way out as a trigger, so it is seen, kept and played to."""
    def open_document(host: ToolHost) -> bool {
        record = self.record;
        folder = host.folder("scenes");
        if record is None or not folder or not record.items {
            return False;
        }
        estate = record.estate;
        casting = record.casting;
        if estate is None or casting is None {
            return False;
        }
        grouped = space_groups(record.items, estate_spaces(estate));
        if len(casting.exit_low) >= 3 and len(casting.exit_high) >= 3 {
            grouped.append(
                MapItem(
                    fields={"classname": "trigger_changelevel", "map": "passion_complete"},
                    brushes=[
                        box_sides(
                            Vec3(x=casting.exit_low[0], y=casting.exit_low[1], z=casting.exit_low[2]),
                            Vec3(x=casting.exit_high[0], y=casting.exit_high[1], z=casting.exit_high[2]),
                            "trigger"
                        )
                    ]
                )
            );
        }
        path = folder + "/expedition_" + str(record.seed) + ".map";
        try {
            os.makedirs(folder, exist_ok=True);
            with open(path, "w") as file {
                file.write(write_map(grouped));
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
        rooms = len([space for space in estate_spaces(estate) if space.role != "corridor"]);
        print(
            "studio: expedition opened seed=" + str(record.seed) + " entities=" + str(len(grouped)) + " brushes=" + str(brushes)
                + " rooms=" + str(rooms) + " file=" + os.path.basename(path)
        );
        return True;
    }

    def words -> str {
        record = self.record;
        if record is None {
            return "studio: expedition none";
        }
        plan = record.plan;
        estate = record.estate;
        spaces = estate_spaces(estate) if estate is not None else [];
        rooms = len([space for space in spaces if space.role != "corridor"]);
        return "studio: expedition seed=" + str(record.seed) + " archetype=" + record.archetype + " beats="
            + str(len(beats_of(plan)) if plan is not None else 0) + " links=" + str(len(links_of(plan)) if plan is not None else 0)
            + " rooms=" + str(rooms) + " corridors=" + str(len(spaces) - rooms) + " score=" + str(round(record.score, 2))
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
        estate = record.estate;
        if plan is None or estate is None {
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
            spaces = estate_spaces(estate);
            count = 0;
            for space in spaces {
                if space.role != "corridor" {
                    print("studio: expedition " + space_words(space));
                    count += 1;
                }
            }
            host.say(str(count) + " rooms in a massing of " + str(estate.nx) + " by " + str(estate.ny) + " by " + str(estate.nz) + " cells");
            return True;
        }
        if how == "ways" {
            corridors = estate_corridors(estate);
            for corridor in corridors {
                print(
                    "studio: expedition way " + str(corridor.link) + " " + str(corridor.tail) + ">" + str(corridor.head) + " "
                        + corridor.mode + (" needs=" + ",".join(corridor.needs) if corridor.needs else "")
                        + (" teleport" if corridor.teleport else "") + (" window" if corridor.window else "")
                        + " blocks=" + str(len(corridor.blocks))
                );
            }
            host.say(str(len(corridors)) + " ways between the rooms, " + str(estate.teleports) + " by teleporter");
            return True;
        }
        if how == "measures" {
            for (name, value) in record.measures.items() {
                quartiles = CORPUS_SP.get(name, [0.0, 0.0, 0.0]);
                print(
                    "studio: expedition measure " + name + "=" + str(round(value, 3)) + " corpus=" + str(quartiles[0]) + ".."
                        + str(quartiles[1]) + ".." + str(quartiles[2])
                );
            }
            host.say("The critic scores it " + str(round(record.score, 2)) + " against the original levels (0 is their median)");
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
        estate = record.estate;
        if estate is None {
            return;
        }
        middles: dict[int, Vec3] = {};
        for space in estate_spaces(estate) {
            middles[space.id] = space_middle(space);
        }
        tones = {
            "open": ink(0x4cc38a), "locked": ink(0xe5484d), "gate": ink(0xe5484d), "valve": ink(0x5b8def),
            "shortcut": ink(0xf5a524), "secret": ink(0x9a9186), "window": ink(0x6b645b)
        };
        lift = Vec3(z=96.0);
        for corridor in estate_corridors(estate) {
            if corridor.tail not in middles or corridor.head not in middles {
                continue;
            }
            start = middles[corridor.tail].add(lift);
            finish = middles[corridor.head].add(lift);
            tone = tones[corridor.mode] if corridor.mode in tones else ink(0xe6dfd4);
            host.line(start, finish, tone);
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
