"""The command shell (cmd.c, cvar.c): the graph of names the console knows and
the command buffer that runs text through them.

A Shell node declares every cvar, command and alias. Subsystems register the
cvars and commands they own; the shell runs the ones it owns itself (set, seta,
toggle, reset, cvarlist, cmdlist, alias, echo, wait, vstr, cvar_restart,
clear) and hands the others back to their owner. Text reaches it through the
command buffer (Cbuf_AddText / Cbuf_InsertText), which splits lines on `;` and
newlines outside quotes and stops at `wait` until the next frame."""
import from .cvar {
    ConsoleName,
    Cvar,
    CVAR_ARCHIVE,
    CVAR_ROM,
    CVAR_USER_CREATED,
    cvar_number,
    cvar_number_text
}

edge Declares: Shell --> ConsoleName {}

"""A command; `owner` names the subsystem that runs it ("shell" for the
shell's own)."""
node Command(ConsoleName) {
    has usage: str = "",
        owner: str = "shell";
}

"""Cmd_Alias_f: a name standing for a line of commands."""
node Alias(ConsoleName) {
    has text: str = "";
}

"""The console's text: printed lines, oldest first (con.text), capped like
the originals' fixed scrollback."""
obj ConsoleLog {
    has lines: list[str] = [],
        limit: int = 1024,
        printed: int = 0;

    def add(text: str) {
        for line in text.split("\n") {
            self.lines.append(line);
            self.printed += 1;
        }
        while len(self.lines) > self.limit {
            self.lines.pop(0);
        }
    }

    def clear {
        self.lines = [];
    }
}

"""Find the cvar, command or alias a word names."""
walker FindName {
    has word: str,
        found: ConsoleName | None = None;

    can start with Shell entry {
        visit [here->:Declares:->];
    }

    can check with ConsoleName entry {
        if here.answers(self.word) {
            self.found = here;
            disengage;
        }
    }
}

"""Every declared name, sorted by kind, whose name matches `pattern` (Q3
Com_Filter's `*` wildcard; empty matches all)."""
walker Roster {
    has pattern: str = "",
        cvars: list[Cvar] = [],
        commands: list[Command] = [],
        aliases: list[Alias] = [];

    can start with Shell entry {
        visit [here->:Declares:->];
    }

    can cvar with Cvar entry {
        if name_matches(self.pattern, here.name) {
            self.cvars.append(here);
        }
    }

    can command with Command entry {
        if name_matches(self.pattern, here.name) {
            self.commands.append(here);
        }
    }

    can alias with Alias entry {
        if name_matches(self.pattern, here.name) {
            self.aliases.append(here);
        }
    }
}

"""Cmd_ExecuteString: walk to the node the first word names. A cvar is shown or
set (Cvar_Command), an alias's text runs next, and a command runs here when the
shell owns it or is handed back through `forwarded` for its owner."""
walker Execute {
    has shell: Shell,
        args: list[str],
        handled: bool = False,
        forwarded: Command | None = None;

    can start with Shell entry {
        visit [
            name
            for name in [here->:Declares:->][?:ConsoleName]
            if name.answers(self.args[0])
        ];
    }

    can variable with Cvar entry {
        self.handled = True;
        self.shell.cvar_command(here, self.args);
        disengage;
    }

    can expand with Alias entry {
        self.handled = True;
        self.shell.run_alias(here);
        disengage;
    }

    can command with Command entry {
        self.handled = True;
        if here.owner == "shell" {
            self.shell.builtin(self.args);
        } else {
            self.forwarded = here;
        }
        disengage;
    }
}

"""Cvar_Restart_f: every cvar that is not read-only back to its default."""
walker ResetCvars {
    has archived_only: bool = False,
        reset: int = 0;

    can start with Shell entry {
        visit [here->:Declares:->];
    }

    can restore with Cvar entry {
        if here.flags & CVAR_ROM or (self.archived_only and not here.flags & CVAR_ARCHIVE) {
            return;
        }
        if here.flags & CVAR_USER_CREATED {
            return;
        }
        here.assign(here.reset_text);
        self.reset += 1;
    }
}


node Shell {
    has log: ConsoleLog = ConsoleLog(),
        pending: str = "",
        waiting: bool = False,
        alias_runs: int = 0,
        booted: bool = False;

    """Declare the shell's own commands (Cmd_Init, Cvar_Init)."""
    def boot {
        if self.booted {
            return;
        }
        self.booted = True;
        for (name, usage, description) in [
            ("set", "set <variable> <value>", "set a cvar, creating it if needed"),
            ("seta", "seta <variable> <value>", "set a cvar and archive it"),
            ("toggle", "toggle <variable>", "flip a cvar between 0 and 1"),
            ("reset", "reset <variable>", "restore a cvar's default"),
            ("cvar_restart", "cvar_restart", "restore every cvar's default"),
            ("cvarlist", "cvarlist [match]", "list cvars"),
            ("cmdlist", "cmdlist [match]", "list commands"),
            ("alias", "alias <name> <commands>", "name a line of commands"),
            ("echo", "echo <text>", "print text"),
            ("wait", "wait", "run the rest next frame"),
            ("vstr", "vstr <variable>", "run a cvar's text as commands"),
            ("clear", "clear", "clear the console text")
        ] {
            self.command(name, "shell", usage, description);
        }
    }

    def print(text: str) {
        self.log.add(text);
    }

    """Cvar_Get: declare an owner's cvar. A cvar of that name (or of one of its
    aliases) that `set` made earlier gives up its value to it."""
    def register(cvar: Cvar) -> Cvar {
        adopted = "";
        adopting = False;
        for word in [cvar.name] + cvar.aliases {
            found = self.find(word);
            if found is cvar {
                return cvar;
            }
            if found is not None and isinstance(found, Cvar) and found.flags & CVAR_USER_CREATED {
                adopted = found.text;
                adopting = True;
                self del --> found;
            } elif found is not None {
                raise ValueError("Console name already declared: " + word);
            }
        }
        self +>:Declares:+> cvar;
        cvar.assign(adopted if adopting else cvar.reset_text);
        cvar.modified = True;
        return cvar;
    }

    """Cmd_AddCommand."""
    def command(name: str, owner: str, usage: str = "", description: str = "") -> Command {
        found = self.find(name);
        if found is not None {
            if isinstance(found, Command) and found.owner == owner {
                return found;
            }
            raise ValueError("Console name already declared: " + name);
        }
        declared = Command(name=name, owner=owner, usage=usage, description=description);
        self +>:Declares:+> declared;
        return declared;
    }

    def find(word: str) -> ConsoleName | None {
        search = self spawn FindName(word=word);
        return search.found;
    }

    def cvar(word: str) -> Cvar | None {
        found = self.find(word);
        if found is not None and isinstance(found, Cvar) {
            return found;
        }
        return None;
    }

    """Cvar_Set2: set (or, unless it names something else, create) a cvar."""
    def set_cvar(word: str, value: str, archive: bool = False) -> Cvar | None {
        found = self.find(word);
        if found is None {
            made = Cvar(
                name=word,
                reset_text=value,
                flags=CVAR_USER_CREATED | (CVAR_ARCHIVE if archive else 0)
            );
            self +>:Declares:+> made;
            made.assign(value);
            return made;
        }
        if not isinstance(found, Cvar) {
            self.print(found.name + " is a command");
            return None;
        }
        if found.flags & CVAR_ROM {
            self.print(found.name + " is read only.");
            return found;
        }
        if archive {
            found.flags = found.flags | CVAR_ARCHIVE;
        }
        found.assign(value);
        return found;
    }

    """Cvar_Command: show a cvar, or set it to the first argument."""
    def cvar_command(cvar: Cvar, args: list[str]) {
        if len(args) == 1 {
            self.print("\"" + cvar.name + "\" is:\"" + cvar.text + "\" default:\"" + cvar.reset_text + "\"");
            return;
        }
        if cvar.flags & CVAR_ROM {
            self.print(cvar.name + " is read only.");
            return;
        }
        cvar.assign(args[1]);
    }

    def run_alias(alias: Alias) {
        # Cmd_ExecuteString's ALIAS_LOOP_COUNT: a runaway alias stops.
        self.alias_runs += 1;
        if self.alias_runs > 16 {
            self.print("ALIAS_LOOP_COUNT");
            self.pending = "";
            return;
        }
        self.insert_text(alias.text);
    }

    """Cbuf_AddText: run `text` after what is already buffered."""
    def add_text(text: str) {
        if self.pending and not self.pending.endswith("\n") {
            self.pending += "\n";
        }
        self.pending += text;
    }

    """Cbuf_InsertText: run `text` before what is already buffered."""
    def insert_text(text: str) {
        self.pending = text + "\n" + self.pending;
    }

    """Cbuf_Execute's next command: the words of the next non-empty line, or
    none when the buffer is empty or a `wait` holds the rest for next frame."""
    def next_command -> list[str] {
        while self.pending {
            if self.waiting {
                self.waiting = False;
                return [];
            }
            cut = command_line_end(self.pending);
            line = self.pending[:cut];
            self.pending = self.pending[cut + 1:] if cut < len(self.pending) else "";
            args = command_tokens(line);
            if args {
                return args;
            }
        }
        self.alias_runs = 0;
        return [];
    }

    """Run one command; a command another subsystem owns is returned for it."""
    def run(args: list[str]) -> Command | None {
        if not args {
            return None;
        }
        run = self spawn Execute(shell=self, args=args);
        if not run.handled {
            self.print("Unknown command \"" + args[0] + "\"");
        }
        return run.forwarded;
    }

    """Run text now, handing back what other owners must run (for callers
    without a dispatcher, such as tests and configs of shell commands)."""
    def execute_text(text: str) -> list[list[str]] {
        self.insert_text(text);
        forwarded: list[list[str]] = [];
        while True {
            args = self.next_command();
            if not args {
                break;
            }
            if self.run(args) is not None {
                forwarded.append(args);
            }
        }
        return forwarded;
    }

    """Command and cvar names starting with `prefix` (with the other games'
    names of the cvars), sorted."""
    def completions(prefix: str) -> list[str] {
        roster = self spawn Roster();
        lowered = prefix.lower();
        names: list[str] = [];
        for cvar in roster.cvars {
            for word in [cvar.name] + cvar.aliases {
                if word.lower().startswith(lowered) and word not in names {
                    names.append(word);
                }
            }
        }
        for command in roster.commands {
            if command.name.lower().startswith(lowered) and command.name not in names {
                names.append(command.name);
            }
        }
        for alias in roster.aliases {
            if alias.name.lower().startswith(lowered) and alias.name not in names {
                names.append(alias.name);
            }
        }
        return sorted(names);
    }

    """Cvar_WriteVariables: `seta` lines for every archived cvar."""
    def archive_lines -> list[str] {
        lines: list[str] = [];
        for cvar in self.sorted_cvars("") {
            if cvar.flags & CVAR_ARCHIVE and not cvar.flags & CVAR_ROM {
                lines.append("seta " + cvar.name + " " + quote_command_word(cvar.text));
            }
        }
        return lines;
    }

    """The cvars whose names match `pattern`, sorted by name."""
    def sorted_cvars(pattern: str) -> list[Cvar] {
        roster = self spawn Roster(pattern=pattern);
        by_name: dict[str, Cvar] = {};
        for cvar in roster.cvars {
            by_name[cvar.name.lower()] = cvar;
        }
        return [by_name[key] for key in sorted(by_name.keys())];
    }

    """The shell's own commands."""
    def builtin(args: list[str]) {
        name = args[0].lower();
        if name == "set" or name == "seta" {
            if len(args) < 3 {
                self.print("usage: " + name + " <variable> <value>");
                return;
            }
            self.set_cvar(args[1], " ".join(args[2:]), archive=name == "seta");
        } elif name == "toggle" {
            target = self.cvar(args[1]) if len(args) == 2 else None;
            if target is None {
                self.print("usage: toggle <variable>");
                return;
            }
            target.assign("0" if target.on() else "1");
        } elif name == "reset" {
            target = self.cvar(args[1]) if len(args) == 2 else None;
            if target is None {
                self.print("usage: reset <variable>");
                return;
            }
            target.assign(target.reset_text);
        } elif name == "cvar_restart" {
            self spawn ResetCvars();
        } elif name == "cvarlist" {
            listed = self.sorted_cvars(args[1] if len(args) > 1 else "");
            for cvar in listed {
                self.print(cvar.flag_letters() + " " + cvar.name + " \"" + cvar.text + "\"");
            }
            self.print(str(len(listed)) + " total cvars");
        } elif name == "cmdlist" {
            roster = self spawn Roster(pattern=args[1] if len(args) > 1 else "");
            names = sorted([command.name for command in roster.commands]);
            for word in names {
                self.print(word);
            }
            self.print(str(len(names)) + " commands");
        } elif name == "alias" {
            self.alias_command(args);
        } elif name == "echo" {
            self.print(" ".join(args[1:]));
        } elif name == "wait" {
            self.waiting = True;
        } elif name == "vstr" {
            target = self.cvar(args[1]) if len(args) == 2 else None;
            if target is None {
                self.print("vstr <variablename> : execute a variable command");
                return;
            }
            self.insert_text(target.text);
        } elif name == "clear" {
            self.log.clear();
        }
    }

    """Cmd_Alias_f."""
    def alias_command(args: list[str]) {
        if len(args) == 1 {
            roster = self spawn Roster();
            self.print("Current alias commands:");
            for alias in roster.aliases {
                self.print(alias.name + " : " + alias.text);
            }
            return;
        }
        found = self.find(args[1]);
        if found is not None and not isinstance(found, Alias) {
            self.print(args[1] + " is already a command or cvar");
            return;
        }
        text = " ".join(args[2:]);
        if found is not None and isinstance(found, Alias) {
            if len(args) == 2 {
                self.print(found.name + " : " + found.text);
            } else {
                found.text = text;
            }
            return;
        }
        if len(args) == 2 {
            self.print("alias " + args[1] + " is not defined");
            return;
        }
        self +>:Declares:+> Alias(name=args[1], text=text);
    }
}

"""Where the first command of `text` ends: a newline, or a `;` outside quotes
and `//` comments (Cbuf_Execute)."""
def command_line_end(text: str) -> int {
    quoted = False;
    comment = False;
    i = 0;
    while i < len(text) {
        c = text[i];
        if c == "\n" {
            return i;
        }
        if not comment {
            if c == "\"" {
                quoted = not quoted;
            } elif not quoted and c == "/" and i + 1 < len(text) and text[i + 1] == "/" {
                comment = True;
            } elif not quoted and c == ";" {
                return i;
            }
        }
        i += 1;
    }
    return len(text);
}

"""Cmd_TokenizeString: a command line's words. Blanks separate words, double
quotes keep one whole, and `//` and `/* */` comments are skipped."""
def command_tokens(line: str) -> list[str] {
    words: list[str] = [];
    i = 0;
    n = len(line);
    while i < n {
        while i < n and ord(line[i]) <= 32 {
            i += 1;
        }
        if i >= n {
            break;
        }
        if line[i] == "/" and i + 1 < n and line[i + 1] == "/" {
            break;
        }
        if line[i] == "/" and i + 1 < n and line[i + 1] == "*" {
            close = line.find("*/", i + 2);
            if close < 0 {
                break;
            }
            i = close + 2;
            continue;
        }
        if line[i] == "\"" {
            close = line.find("\"", i + 1);
            if close < 0 {
                words.append(line[i + 1:]);
                break;
            }
            words.append(line[i + 1:close]);
            i = close + 1;
            continue;
        }
        start = i;
        while i < n and ord(line[i]) > 32 {
            if line[i] == "\"" {
                break;
            }
            if line[i] == "/" and i + 1 < n and (line[i + 1] == "/" or line[i + 1] == "*") and i > start {
                break;
            }
            i += 1;
        }
        words.append(line[start:i]);
    }
    return words;
}

"""Cmd_StuffCmds_f: the command line's "+command args" runs as console
lines (`+map e1m2 +god` runs `map e1m2` then `god`)."""
def command_line_text(words: list[str]) -> str {
    lines: list[str] = [];
    current: list[str] = [];
    for word in words {
        if word.startswith("+") and len(word) > 1 {
            if current {
                lines.append(" ".join(current));
            }
            current = [word[1:]];
        } elif current {
            current.append(quote_command_word(word) if " " in word or ";" in word else word);
        }
    }
    if current {
        lines.append(" ".join(current));
    }
    return "\n".join(lines);
}

"""A word as a config file writes it: quoted, as Key_WriteBindings and
Cvar_WriteVariables do (quotes inside cannot be kept)."""
def quote_command_word(text: str) -> str {
    return "\"" + text.replace("\"", "") + "\"";
}

"""Q3 Com_Filter: `*` matches any run of characters, `?` any one; otherwise
names match case-insensitively. An empty pattern matches everything; a pattern
without wildcards matches names containing it."""
def name_matches(pattern: str, name: str) -> bool {
    if not pattern {
        return True;
    }
    lowered = pattern.lower();
    word = name.lower();
    if "*" not in lowered and "?" not in lowered {
        return lowered in word;
    }
    return wildcard_match(lowered, word, 0, 0);
}

def:priv wildcard_match(pattern: str, word: str, p: int, w: int) -> bool {
    while p < len(pattern) {
        c = pattern[p];
        if c == "*" {
            if p + 1 == len(pattern) {
                return True;
            }
            for start in range(w, len(word) + 1) {
                if wildcard_match(pattern, word, p + 1, start) {
                    return True;
                }
            }
            return False;
        }
        if w >= len(word) or (c != "?" and c != word[w]) {
            return False;
        }
        p += 1;
        w += 1;
    }
    return w == len(word);
}
