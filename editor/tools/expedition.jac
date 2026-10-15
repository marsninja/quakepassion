"""Passion's generated expeditions in the studio. `ed_exp open <seed>` runs
the generator and opens what it made as a document of brushes, a group a
room and a group a corridor; the expedition's own account of itself (its
mission's beats and links, its spaces, the corridors between them, how the
critic measured it) is kept beside the document, said, and drawn over the
level.

`ed_exp watch <seed> [level]` shows a level being made: the generator's
forge is stepped a few steps a frame, and what it has made so far is drawn
in the 3D view (each candidate's rooms placed and shaped, their floors and
stages, each corridor's search as it goes and the corridors found, the
lamps and the cast), with a box to pause it, step it, speed it up or stop
it. Once a candidate is chosen and its brushes written, the level opens as
a document, as `ed_exp open` opens one."""

import os;
import from engine.math.vec3 { Vec3 }
import from games.passion.generate { Survey, survey, Forge, level_name, run_of, CANDIDATES }
import from games.passion.massing { CELL, LIFT }
import from games.passion.spaces { Space }
import from games.passion.mission { beats_of, links_of }
import from games.passion.arrange { estate_spaces, estate_corridors }
import from games.passion.corpus { CORPUS_SP }
import from editor.document.scene { Scene }
import from editor.formats.map { MapItem, write_map }
import from editor.geometry.brush { box_sides }
import from editor.document.expedition { space_groups, space_middle, beat_words, link_words, space_words }
import from editor.tools.host { ToolHost, StudioTool, PanelSpec }
import from editor.ui.canvas { ink, Ink }

# The steps of a forge a frame, from slowest to fastest.
glob WATCH_PACES: list[int] = [1, 2, 4, 8, 16, 32, 64, 128, 256];

obj Expeditions(StudioTool) {
    has record: Survey | None = None,
        shown: bool = False,
        # A level being watched as it is made: its forge, whether it is
        # held still (and a step asked for), how fast it goes, and what the
        # camera was last set to look at.
        forge: Forge | None = None,
        paused: bool = False,
        stepping: bool = False,
        pace: int = 3,
        framed: str = "",
        since_panel: float = 0.0;

    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_exp",
                "ed_exp [open <seed> | watch <seed> [level] | watch pause|go|step|faster|slower|speed <0..1>|stop | mission | rooms | ways | measures | show [on|off]]",
                "a Passion expedition: generate a seed and open it as a document of brushes, a group a room; watch a level being made; say its mission, spaces, corridors and how it measures against the original levels; draw the ways over the level"
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
        if how == "watch" {
            self.watch_command(host, args[2:]);
            return True;
        }
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

    """`ed_exp watch ...`: begin watching a level made, or hold it, step
    it, pace it or stop it."""
    def watch_command(host: ToolHost, words: list[str]) {
        word = words[0] if words else "";
        if word.isdigit() {
            depth = int(words[1]) if len(words) > 1 and words[1].isdigit() else 1;
            name = level_name(int(word), max(1, depth));
            try {
                run_of(name);
            } except ValueError as error {
                host.say("ed_exp watch: " + str(error));
                return;
            }
            self.forge = Forge(name=name);
            self.paused = False;
            self.stepping = False;
            self.framed = "";
            self.shown = False;
            host.run(["ed_scene", "forge_" + name.replace("-", "_")]);
            host.say("Watching " + name + " being made");
            self.show_panel(host);
            return;
        }
        forge = self.forge;
        if forge is None {
            host.say("No level is being made (ed_exp watch <seed> [level] makes one)");
            return;
        }
        if word == "pause" {
            self.paused = True;
        } elif word == "go" {
            self.paused = False;
        } elif word == "step" {
            self.paused = True;
            self.stepping = True;
        } elif word == "faster" {
            self.pace = min(len(WATCH_PACES) - 1, self.pace + 1);
        } elif word == "slower" {
            self.pace = max(0, self.pace - 1);
        } elif word == "speed" and len(words) > 1 {
            try {
                share = max(0.0, min(1.0, float(words[1])));
                self.pace = int(round(share * float(len(WATCH_PACES) - 1)));
            } except ValueError {
                host.say("ed_exp watch speed <0..1>");
            }
        } elif word == "stop" {
            self.forge = None;
            host.panel_close("forge");
            host.say("Stopped making " + forge.name);
            return;
        } else {
            host.say("ed_exp watch <seed> [level] | pause | go | step | faster | slower | speed <0..1> | stop");
            return;
        }
        self.show_panel(host);
    }

    """The box beside a level being made: how far it has got, what it is
    doing, the candidates turned down, and its controls."""
    def show_panel(host: ToolHost) {
        forge = self.forge;
        if forge is None {
            return;
        }
        notes: list[str] = [];
        record = forge.survey;
        draft = forge.draft;
        tried = record.candidates if record is not None else 0;
        notes.append("Stage: " + (forge.stage if forge.stage else "starting") + " (" + forge.step + ")");
        notes.append("Candidate " + str(tried + 1) + " (the best of " + str(CANDIDATES) + " that work is kept)");
        if draft is not None {
            plan = draft.plan;
            layout = draft.layout;
            estate = layout.estate if layout is not None else None;
            if plan is not None {
                notes.append(str(len(beats_of(plan))) + " beats, " + str(len(links_of(plan))) + " links");
            }
            if estate is not None {
                rooms = [space for space in estate_spaces(estate) if space.role != "corridor"];
                notes.append(str(len(rooms)) + " rooms placed, " + str(len(estate_corridors(estate))) + " ways made, " + str(estate.teleports) + " by teleporter");
            }
        }
        if record is not None {
            for line in record.notes[-6:] {
                notes.append("Turned down: " + line[:90]);
            }
        }
        notes.append(("Held still" if self.paused else "Running") + ", " + str(WATCH_PACES[self.pace]) + " steps a frame");
        host.panel(
            "forge",
            PanelSpec(
                title="Making " + forge.name,
                notes=notes,
                bars=[("speed", float(self.pace) / float(len(WATCH_PACES) - 1), "ed_exp watch speed")],
                buttons=[
                    ("Go" if self.paused else "Hold", "ed_exp watch " + ("go" if self.paused else "pause")),
                    ("Step", "ed_exp watch step"),
                    ("Slower", "ed_exp watch slower"),
                    ("Faster", "ed_exp watch faster"),
                    ("Stop", "ed_exp watch stop")
                ],
                wide=420,
                tall=380,
                right=True
            )
        );
    }

    """Point the camera at a candidate's rooms: from behind and above
    them, the whole in view."""
    def frame_spaces(host: ToolHost, spaces: list[Space]) {
        if not spaces {
            return;
        }
        low_x = min([float(space.x) for space in spaces]) * CELL;
        low_y = min([float(space.y) for space in spaces]) * CELL;
        high_x = max([float(space.x + space.w) for space in spaces]) * CELL;
        high_y = max([float(space.y + space.d) for space in spaces]) * CELL;
        high_z = max([float(space.z + space.h) for space in spaces]) * LIFT;
        span = max(high_x - low_x, high_y - low_y);
        middle_x = (low_x + high_x) * 0.5;
        host.run(
            [
                "ed_cam",
                str(int(middle_x)),
                str(int(low_y - span * 0.55)),
                str(int(high_z + span * 0.55)),
                "90",
                "-40"
            ]
        );
    }

    def tick(host: ToolHost, dt: float) {
        forge = self.forge;
        if forge is None {
            return;
        }
        steps = 0;
        if not self.paused {
            steps = WATCH_PACES[self.pace];
        } elif self.stepping {
            steps = 1;
            self.stepping = False;
        }
        for count in range(steps) {
            if forge.finished or forge.stage not in ["", "survey"] {
                break;
            }
            forge.advance(0.0);
        }
        if forge.failure {
            self.forge = None;
            host.panel_close("forge");
            host.say("The level could not be made: " + forge.failure);
            return;
        }
        draft = forge.draft;
        layout = draft.layout if draft is not None else None;
        estate = layout.estate if layout is not None else None;
        record = forge.survey;
        if estate is not None and record is not None {
            # Again once the rooms are in the massing (they are moved into it).
            key = str(record.candidates) + ("m" if layout is not None and layout.mass is not None else "p");
            spaces = estate_spaces(estate);
            if key != self.framed and (len(spaces) >= 6 or key.endswith("m")) {
                self.framed = key;
                self.frame_spaces(host, spaces);
            }
        }
        if forge.stage not in ["", "survey"] and record is not None {
            # Chosen and written: the level opens as a document.
            self.forge = None;
            self.record = record;
            self.shown = True;
            host.panel_close("forge");
            if self.open_document(host) {
                print(self.words());
                host.say(forge.name + ": " + record.briefing);
            } else {
                host.say("The level of " + forge.name + " could not be opened as a document");
            }
            return;
        }
        self.since_panel += dt;
        if self.since_panel >= 0.25 or self.paused {
            self.since_panel = 0.0;
            self.show_panel(host);
        }
    }

    """What a level being made has so far, drawn: rooms as boxes in their
    role's colour with their floors and stages, corridors as the blocks
    they run through, the corridor being searched for, lamps and the
    cast."""
    def draw_forge(host: ToolHost, forge: Forge) {
        draft = forge.draft;
        if draft is None {
            return;
        }
        layout = draft.layout;
        estate = layout.estate if layout is not None else None;
        if layout is None or estate is None {
            return;
        }
        for space in estate_spaces(estate) {
            low = Vec3(x=float(space.x) * CELL, y=float(space.y) * CELL, z=float(space.z) * LIFT);
            high = Vec3(x=float(space.x + space.w) * CELL, y=float(space.y + space.d) * CELL, z=float(space.z + space.h) * LIFT);
            if space.role == "corridor" {
                continue;
            }
            tone = ink(0x4cc38a) if space.role == "start" else (ink(0xe5484d) if space.role == "goal" else (ink(0xf5a524) if space.stage and space.role not in ["hub", "cache"] else ink(0xe6dfd4)));
            wire_box(host, low, high, tone);
            for level in space.levels {
                at = float(level) * LIFT;
                if at > low.z {
                    host.line(Vec3(x=low.x, y=low.y, z=at), Vec3(x=high.x, y=low.y, z=at), ink(0x6b645b));
                    host.line(Vec3(x=low.x, y=high.y, z=at), Vec3(x=high.x, y=high.y, z=at), ink(0x6b645b));
                }
            }
            if len(space.stage) == 3 {
                spot = Vec3(x=(float(space.stage[0]) + 0.5) * CELL, y=(float(space.stage[1]) + 0.5) * CELL, z=float(space.stage[2]) * LIFT);
                host.line(spot, spot.add(Vec3(z=64.0)), tone);
            }
        }
        tones = {
            "open": ink(0x4cc38a), "locked": ink(0xe5484d), "gate": ink(0xe5484d), "valve": ink(0x5b8def),
            "shortcut": ink(0xf5a524), "secret": ink(0x9a9186), "window": ink(0x6b645b)
        };
        for corridor in estate_corridors(estate) {
            tone = tones[corridor.mode] if corridor.mode in tones else ink(0xe6dfd4);
            previous: Vec3 | None = None;
            for block in corridor.blocks {
                middle = Vec3(x=(float(block[0]) + 1.0) * CELL, y=(float(block[1]) + 1.0) * CELL, z=float(block[2]) * LIFT + 8.0);
                if previous is not None {
                    host.line(previous, middle, tone);
                }
                previous = middle;
            }
        }
        route = layout.route;
        if route is not None and len(route.start) == 3 and len(route.goal) == 3 {
            start = Vec3(x=(float(route.start[0]) + 1.0) * CELL, y=(float(route.start[1]) + 1.0) * CELL, z=float(route.start[2]) * LIFT + 8.0);
            goal = Vec3(x=(float(route.goal[0]) + 1.0) * CELL, y=(float(route.goal[1]) + 1.0) * CELL, z=float(route.goal[2]) * LIFT + 8.0);
            host.line(start, goal, ink(0x5b8def));
            if len(route.at) == 3 {
                head = Vec3(x=float(route.at[0]) * CELL, y=float(route.at[1]) * CELL, z=float(route.at[2]) * LIFT);
                wire_box(host, head, head.add(Vec3(x=2.0 * CELL, y=2.0 * CELL, z=6.0 * LIFT)), ink(0x5b8def));
                host.line(start, head.add(Vec3(x=CELL, y=CELL, z=8.0)), ink(0x3a5ea8));
            }
        }
        dressing = draft.dressing;
        if dressing is not None {
            for lamp in dressing.lamps {
                spot = Vec3(x=lamp.x, y=lamp.y, z=lamp.z);
                host.line(spot.sub(Vec3(z=10.0)), spot.add(Vec3(z=10.0)), ink(0xffd479));
            }
        }
        casting = draft.casting;
        if casting is not None {
            for item in casting.items {
                words = item.fields.get("origin", "").split();
                if len(words) != 3 {
                    continue;
                }
                try {
                    spot = Vec3(x=float(words[0]), y=float(words[1]), z=float(words[2]));
                } except ValueError {
                    continue;
                }
                classname = item.fields.get("classname", "");
                tone = ink(0xe5484d) if classname.startswith("monster_") else (ink(0x4cc38a) if classname.startswith("item_") or classname.startswith("weapon_") else ink(0xb48cf2));
                host.line(spot.sub(Vec3(x=12.0)), spot.add(Vec3(x=12.0)), tone);
                host.line(spot.sub(Vec3(y=12.0)), spot.add(Vec3(y=12.0)), tone);
            }
        }
    }

    def draw_through(host: ToolHost, scene: Scene) {
        forge = self.forge;
        if forge is not None {
            self.draw_forge(host, forge);
            return;
        }
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

"""The twelve edges of a box."""
def wire_box(host: ToolHost, low: Vec3, high: Vec3, tone: Ink) {
    corners = [
        Vec3(x=low.x, y=low.y, z=low.z), Vec3(x=high.x, y=low.y, z=low.z), Vec3(x=high.x, y=high.y, z=low.z), Vec3(x=low.x, y=high.y, z=low.z),
        Vec3(x=low.x, y=low.y, z=high.z), Vec3(x=high.x, y=low.y, z=high.z), Vec3(x=high.x, y=high.y, z=high.z), Vec3(x=low.x, y=high.y, z=high.z)
    ];
    for side in range(4) {
        host.line(corners[side], corners[(side + 1) % 4], tone);
        host.line(corners[side + 4], corners[(side + 1) % 4 + 4], tone);
        host.line(corners[side], corners[side + 4], tone);
    }
}
