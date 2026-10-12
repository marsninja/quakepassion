"""A project's scripts: Jac walkers written beside the project and run by
the jac toolchain in a process of their own, on the level as a graph (see
editor/document/scripting.jac and editor/userland/qp.jac). A script is
edited in a box with what the compiler says of it beside, attached to
entities, run by hand on the level or the selection, and run when the
entity it is attached to fires in a game played from the studio. All a
script can do is ask: set a field, fire, pick, say, add an entity."""

import os;
import from editor.document.scene { Scene, Item }
import from editor.document.scripting {
    scene_json, launcher_text, read_asked, script_walkers, script_classes, said_faults, starter_script, library_text
}
import from editor.tools.host { ToolHost, StudioTool, PanelSpec }

"""A script started in the background at play time: what it was for, and
the files it leaves when it is done."""
obj ScriptRun {
    has label: str,
        done: str,
        result: str,
        heard: str,
        file_name: str;
}

obj Scripts(StudioTool) {
    has toolchain: str = "jac",
        # The script in the box, what was last said of it, how much of the
        # played game's firings has been seen, and what is still running.
        editing: str = "",
        notes: list[str] = [],
        fired_seen: int = 0,
        was_playing: bool = False,
        waiting: list[ScriptRun] = [],
        runs: int = 0;

    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_script",
                "ed_script [new <file> [walker] | edit <file> | write | check [file] | run <file> <walker> [words] | attach <file> <walker> | detach | go | jac <command>]",
                "a project's scripts, Jac walkers run outside the studio on the level as a graph: write one, edit it with the compiler's faults beside it, run one on the level, attach one to the selected entities (it runs when they fire in a played game), run those attached"
            )
        ];
    }

    """A script's file name with its ending, and the module it is imported as."""
    def named(word: str) -> str {
        base = os.path.basename(word.strip());
        return base if base.endswith(".jac") else base + ".jac";
    }

    def read(path: str) -> str {
        try {
            with open(path, "r") as file {
                return file.read();
            }
        } except OSError {
            return "";
        }
    }

    def write(path: str, text: str) -> bool {
        try {
            os.makedirs(os.path.dirname(path), exist_ok=True);
            with open(path, "w") as file {
                file.write(text);
            }
        } except OSError {
            return False;
        }
        return True;
    }

    """The scripts there are, by file name."""
    def files(host: ToolHost) -> list[str] {
        folder = host.folder("scripts");
        if not os.path.isdir(folder) {
            return [];
        }
        return sorted(
            [each for each in os.listdir(folder) if each.endswith(".jac") and each != "qp.jac" and not each.startswith("_")]
        );
    }

    """Write what a run needs beside the scripts: the library, the level,
    and the lines that start the walker. Answers the launcher, where what
    it asks will be, and where what is said will be."""
    def prepare(
        host: ToolHost, scene: Scene, file_name: str, walker_name: str, event: str, words: list[str], on: int
    ) -> list[str] {
        folder = host.folder("scripts");
        self.runs += 1;
        stem = "_run" + str(self.runs);
        if self.read(folder + "/qp.jac") != library_text() {
            self.write(folder + "/qp.jac", library_text());
        }
        self.write(
            folder + "/" + stem + ".json",
            scene_json(
                scene.name, scene.game, event, words, on, [(item.serial, dict(item.fields)) for item in scene.items()]
            )
        );
        self.write(
            folder + "/" + stem + ".jac", launcher_text(file_name[:-4], walker_name, stem + ".json", stem + ".asked")
        );
        return [stem + ".jac", folder + "/" + stem + ".asked", folder + "/" + stem + ".log"];
    }

    """Forget a run's own files."""
    def tidy(host: ToolHost, launcher: str) {
        folder = host.folder("scripts");
        stem = launcher[:-4];
        for ending in [".jac", ".json", ".asked", ".log", ".done"] {
            try {
                os.remove(folder + "/" + stem + ending);
            } except OSError {
                continue;
            }
        }
    }

    """Do what a script asked, in the document: fields set, entities picked
    and added, things said. Answers how many things were done."""
    def apply(host: ToolHost, asked: list[list[str]]) -> int {
        did = 0;
        picked = False;
        for words in asked {
            kind = words[0];
            if kind == "say" {
                host.say(" ".join(words[1:]));
            } elif kind == "set" and words[1].isdigit() {
                host.run(["ed_select", words[1]]);
                host.run(["ed_set", words[2], words[3]]);
            } elif kind == "pick" and words[1].isdigit() {
                host.run(["ed_select", words[1]] + (["add"] if picked else []));
                picked = True;
            } elif kind == "add" {
                host.run(["ed_new", words[1]]);
                host.run(["ed_set", "origin", words[2]]);
                for at in range(3, len(words) - 1, 2) {
                    host.run(["ed_set", words[at], words[at + 1]]);
                }
            } elif kind == "fire" {
                host.say(words[1] + " would be fired (it is, when the level is played)");
            } else {
                continue;
            }
            did += 1;
        }
        return did;
    }

    """Run a walker now and do what it asks. Answers what it asked for, or
    None when it could not be run; what went wrong is said."""
    def run_now(
        host: ToolHost, scene: Scene, file_name: str, walker_name: str, words: list[str], on: int
    ) -> int {
        folder = host.folder("scripts");
        if not os.path.isfile(folder + "/" + file_name) {
            host.say("There is no script " + file_name + " (ed_script new " + file_name[:-4] + " writes one)");
            return -1;
        }
        made = self.prepare(host, scene, file_name, walker_name, "run", words, on);
        status = os.system(
            "cd \"" + folder + "\" && ( " + self.toolchain + " run -b python " + made[0] + " ) > \"" + made[2] + "\" 2>&1"
        );
        said = self.read(made[2]);
        asked = read_asked(self.read(made[1]));
        faults = said_faults(said, file_name);
        self.tidy(host, made[0]);
        if status != 0 or len(faults) > 0 {
            for (line, fault) in faults {
                print("studio: script fault " + file_name + ":" + str(line) + " " + fault);
            }
            print("studio: script ran " + walker_name + " status=" + str(status) + " faults=" + str(len(faults)));
            host.say(
                file_name + " did not run" + (": line " + str(faults[0][0]) + ", " + faults[0][1] if faults else " (is " + self.toolchain + " there to run it?)")
            );
            return -1;
        }
        for each in asked {
            print("studio: script asked " + " ".join(each));
        }
        did = self.apply(host, asked);
        print("studio: script ran " + walker_name + " on=" + str(on) + " asked=" + str(len(asked)) + " did=" + str(did));
        return did;
    }

    """What the compiler says of a script, as notes for the box and lines
    of the log; the walkers it has follow when it is sound. The classes
    the scripts declare are given to the studio as an add-on."""
    def check(host: ToolHost, file_name: str) -> list[str] {
        folder = host.folder("scripts");
        heard = folder + "/_check.log";
        if self.read(folder + "/qp.jac") != library_text() {
            self.write(folder + "/qp.jac", library_text());
        }
        os.system("cd \"" + folder + "\" && ( " + self.toolchain + " check " + file_name + " ) > \"" + heard + "\" 2>&1");
        said = self.read(heard);
        if os.path.isfile(heard) {
            os.remove(heard);
        }
        faults = said_faults(said, file_name);
        notes: list[str] = [];
        for (line, fault) in faults {
            notes.append(("line " + str(line) + ": " if line > 0 else "") + fault);
            print("studio: script fault " + file_name + ":" + str(line) + " " + fault);
        }
        source = self.read(folder + "/" + file_name);
        walkers = script_walkers(source);
        if len(faults) == 0 {
            notes.append("The compiler finds nothing wrong.");
            notes.append("Walkers: " + (", ".join(walkers) if walkers else "none"));
        }
        # Every script's classes together, as the add-on the studio reads.
        lines: list[str] = ["// The classes this project's scripts declare (written by ed_script)."];
        for each in self.files(host) {
            for declared in script_classes(self.read(folder + "/" + each)) {
                lines.append("class " + declared);
            }
        }
        if len(lines) > 1 or os.path.isfile(folder + "/_classes.txt") {
            self.write(folder + "/_classes.txt", "\n".join(lines) + "\n");
            host.run(["ed_addon", folder + "/_classes.txt"]);
            if len(lines) > 1 {
                notes.append("Classes: " + ", ".join([row.split("|")[0][6:] for row in lines[1:]]));
            }
        }
        print(
            "studio: script checked " + file_name + " faults=" + str(len(faults)) + " walkers=" + ",".join(walkers)
                + " classes=" + str(len(lines) - 1)
        );
        return notes;
    }

    """Show a script in the box, with what was last said of it."""
    def show(host: ToolHost, file_name: str) {
        folder = host.folder("scripts");
        self.editing = file_name;
        host.panel(
            "script",
            PanelSpec(
                title="Script: " + file_name,
                text=self.read(folder + "/" + file_name).rstrip("\n"),
                order="ed_script write",
                notes=self.notes if len(self.notes) > 0 else ["Ctrl+Enter, or a click outside the words, saves", "and asks the compiler."],
                buttons=[("Check", "ed_script check"), ("Run attached", "ed_script go")]
            )
        );
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        if args[0] != "ed_script" {
            return False;
        }
        how = args[1] if len(args) > 1 else "";
        folder = host.folder("scripts");
        if how == "jac" and len(args) > 2 {
            self.toolchain = " ".join(args[2:]);
            host.say("Scripts are run by: " + self.toolchain);
            return True;
        }
        if how == "new" and len(args) > 2 {
            file_name = self.named(args[2]);
            if os.path.isfile(folder + "/" + file_name) {
                host.say("There is a script " + file_name + " already (ed_script edit " + file_name[:-4] + ")");
                return True;
            }
            first = args[3] if len(args) > 3 else "Look";
            if not self.write(folder + "/" + file_name, starter_script(first)) {
                host.say("ed_script: could not write " + folder + "/" + file_name);
                return True;
            }
            print("studio: script new " + file_name + " walker=" + first);
            host.say("Wrote " + file_name + " with a walker called " + first + " (ed_script edit " + file_name[:-4] + " opens it)");
            return True;
        }
        if how == "edit" and len(args) > 2 {
            file_name = self.named(args[2]);
            if not os.path.isfile(folder + "/" + file_name) {
                host.say("There is no script " + file_name + " (ed_script new " + file_name[:-4] + " writes one)");
                return True;
            }
            self.notes = [];
            self.show(host, file_name);
            return True;
        }
        if how == "write" {
            if not self.editing {
                host.say("No script is being edited (ed_script edit <file>)");
                return True;
            }
            text = host.panel_text("script");
            if text and not self.write(folder + "/" + self.editing, text.rstrip("\n") + "\n") {
                host.say("ed_script: could not write " + self.editing);
                return True;
            }
            # Saved, and asked of the compiler at once: what it runs as from now on.
            self.notes = self.check(host, self.editing);
            self.show(host, self.editing);
            host.say("Saved " + self.editing + ": " + self.notes[0]);
            return True;
        }
        if how == "check" {
            file_name = self.named(args[2]) if len(args) > 2 else self.editing;
            if not file_name or not os.path.isfile(folder + "/" + file_name) {
                host.say("ed_script check <file>");
                return True;
            }
            self.notes = self.check(host, file_name);
            if self.editing == file_name and host.panel_text("script") {
                self.show(host, file_name);
            }
            host.say(file_name + ": " + self.notes[0]);
            return True;
        }
        if how == "run" and len(args) > 3 {
            did = self.run_now(host, scene, self.named(args[2]), args[3], args[4:], -1);
            if did >= 0 {
                host.say(args[3] + " ran on the level and " + str(did) + " things were done as it asked");
            }
            return True;
        }
        if how == "attach" and len(args) > 3 {
            file_name = self.named(args[2]);
            if args[3] not in script_walkers(self.read(folder + "/" + file_name)) {
                host.say(file_name + " has no walker called " + args[3]);
                return True;
            }
            if len(scene.selection()) == 0 {
                host.say("Select the entities it is to be attached to first");
                return True;
            }
            host.run(["ed_set", "_walker", file_name[:-4] + ":" + args[3]]);
            host.say(args[3] + " is attached to " + str(len(scene.selection())) + " entities: it runs when they fire in a played game, or on ed_script go");
            return True;
        }
        if how == "detach" {
            host.run(["ed_unset", "_walker"]);
            return True;
        }
        if how == "go" {
            chosen = scene.selection();
            members = chosen if len(chosen) > 0 else scene.items();
            ran = 0;
            for item in [each for each in members if ":" in each.fields.get("_walker", "")] {
                halves = item.fields["_walker"].split(":", 1);
                if self.run_now(host, scene, self.named(halves[0]), halves[1], [], item.serial) >= 0 {
                    ran += 1;
                }
            }
            host.say(str(ran) + " attached walkers ran" if ran > 0 else "Nothing here has a walker attached (ed_script attach <file> <walker>)");
            return True;
        }
        if how {
            host.say("ed_script [new <file> [walker] | edit <file> | write | check [file] | run <file> <walker> [words] | attach <file> <walker> | detach | go | jac <command>]");
            return True;
        }
        for each in self.files(host) {
            print("studio: script " + each + " walkers=" + ",".join(script_walkers(self.read(folder + "/" + each))));
        }
        for item in scene.items() {
            if item.fields.get("_walker", "") {
                print("studio: script on #" + str(item.serial) + " " + item.classname() + " " + item.fields["_walker"]);
            }
        }
        host.say(
            "Scripts in " + folder + ": " + ", ".join(self.files(host)) if len(self.files(host)) > 0
            else "No scripts yet in " + folder + " (ed_script new <file> writes one)"
        );
        return True;
    }

    """In a game played from the studio: when an entity that has a walker
    fires, the walker is run in the background, and what it asks (to fire
    something, to say something) is done when it has finished."""
    def tick(host: ToolHost, dt: float) {
        scene = host.scene_now();
        if not host.playing() or scene is None {
            self.was_playing = False;
            self.fired_seen = 0;
            return;
        }
        if not self.was_playing {
            self.was_playing = True;
            self.fired_seen = 0;
        }
        folder = host.folder("scripts");
        log = host.fired_log();
        for label in log[self.fired_seen:] {
            for item in scene.items() {
                attached_to = item.fields.get("_walker", "");
                if ":" not in attached_to or item.fields.get("targetname", item.classname()) != label {
                    continue;
                }
                halves = attached_to.split(":", 1);
                file_name = self.named(halves[0]);
                if not os.path.isfile(folder + "/" + file_name) or len(self.waiting) >= 8 {
                    continue;
                }
                made = self.prepare(host, scene, file_name, halves[1], "fired", [label], item.serial);
                done = folder + "/" + made[0][:-4] + ".done";
                os.system(
                    "( cd \"" + folder + "\" && ( " + self.toolchain + " run -b python " + made[0] + " ) > \"" + made[2]
                        + "\" 2>&1 ; touch \"" + done + "\" ) > /dev/null 2>&1 &"
                );
                self.waiting.append(ScriptRun(label=label, done=done, result=made[1], heard=made[2], file_name=made[0]));
                print("studio: script started " + halves[1] + " for " + label);
            }
        }
        self.fired_seen = len(log);
        still: list[ScriptRun] = [];
        for run in self.waiting {
            if not os.path.isfile(run.done) {
                still.append(run);
                continue;
            }
            asked = read_asked(self.read(run.result));
            fired = 0;
            for words in asked {
                if words[0] == "fire" {
                    host.run(["ed_fire", words[1]]);
                    fired += 1;
                } elif words[0] == "say" {
                    host.say(" ".join(words[1:]));
                }
            }
            print("studio: script finished for " + run.label + " asked=" + str(len(asked)) + " fired=" + str(fired));
            self.tidy(host, run.file_name);
        }
        self.waiting = still;
    }

    def draw_through(host: ToolHost, scene: Scene) {}

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        attached = len([item for item in scene.items() if item.fields.get("_walker", "")]);
        if attached == 0 and not self.editing {
            return [];
        }
        return ["studio: scripts attached=" + str(attached) + " editing=" + (self.editing if self.editing else "-")];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return ["ed_script jac " + self.toolchain] if self.toolchain != "jac" else [];
    }
}
