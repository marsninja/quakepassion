"""The keyboard and mouse buttons as a graph of keys (keys.c, cl_keys.c).

Each Key node is one of the originals' key numbers: its name as configs write
it (Key_KeynumToString), the raylib inputs that press it, whether it is down
and the command bound to it (Q3's qkey_t). The PollKeys walker turns this
frame's raylib state into key events; bindings are data the console's bind,
unbind, unbindall and bindlist commands edit, and that the game's default.cfg
and the user's configuration fill."""
import from vendor.raylib {
    def IsKeyDown(key: i32) -> bool;  def IsKeyPressedRepeat(key: i32) -> bool;  def IsMouseButtonDown(
        button: i32
    ) -> bool;  def GetCharPressed -> i32;  def GetMouseWheelMove -> f32;
}
import from ..console.shell { Shell, quote_command_word }

edge HasKey: Keyboard --> Key {}

"""One key number: `inputs` are raylib key codes, mouse button numbers (for
MOUSE1-5) or the wheel direction (for MWHEELUP/MWHEELDOWN)."""
node Key {
    has name: str,
        device: str = "key",
        inputs: list[int] = [],
        binding: str = "",
        down: bool = False;
}

"""A key going down (or repeating while held) or up this frame."""
obj KeyEvent {
    has key: Key,
        down: bool,
        repeat: bool = False;
}

"""Key_StringToKeynum's names for the keys raylib reports: the originals' key
names (Q1 keynames[], Q3's keypad and COMMAND additions) with the raylib codes
that press each. Printable keys are named by their unshifted character."""
glob KEY_NAME_CODES: list[tuple[str, list[int]]] = [
    ("TAB", [258]),
    ("ENTER", [257]),
    ("ESCAPE", [256]),
    ("SPACE", [32]),
    ("BACKSPACE", [259]),
    ("UPARROW", [265]),
    ("DOWNARROW", [264]),
    ("LEFTARROW", [263]),
    ("RIGHTARROW", [262]),
    ("ALT", [342, 346]),
    ("CTRL", [341, 345]),
    ("SHIFT", [340, 344]),
    ("COMMAND", [343, 347]),
    ("CAPSLOCK", [280]),
    ("F1", [290]),
    ("F2", [291]),
    ("F3", [292]),
    ("F4", [293]),
    ("F5", [294]),
    ("F6", [295]),
    ("F7", [296]),
    ("F8", [297]),
    ("F9", [298]),
    ("F10", [299]),
    ("F11", [300]),
    ("F12", [301]),
    ("INS", [260]),
    ("DEL", [261]),
    ("PGDN", [267]),
    ("PGUP", [266]),
    ("HOME", [268]),
    ("END", [269]),
    ("PAUSE", [284]),
    ("KP_HOME", [327]),
    ("KP_UPARROW", [328]),
    ("KP_PGUP", [329]),
    ("KP_LEFTARROW", [324]),
    ("KP_5", [325]),
    ("KP_RIGHTARROW", [326]),
    ("KP_END", [321]),
    ("KP_DOWNARROW", [322]),
    ("KP_PGDN", [323]),
    ("KP_ENTER", [335]),
    ("KP_INS", [320]),
    ("KP_DEL", [330]),
    ("KP_SLASH", [331]),
    ("KP_MINUS", [333]),
    ("KP_PLUS", [334]),
    ("KP_NUMLOCK", [282]),
    ("KP_STAR", [332]),
    ("KP_EQUALS", [336]),
    ("'", [39]),
    (",", [44]),
    ("-", [45]),
    (".", [46]),
    ("/", [47]),
    ("SEMICOLON", [59]),
    ("=", [61]),
    ("[", [91]),
    ("\\", [92]),
    ("]", [93]),
    ("`", [96])
];

"""The key names that stand for a character a config cannot write bare."""
glob KEY_SPELLINGS: dict[str, str] = {";": "SEMICOLON"};


node Keyboard {
    has booted: bool = False,
        dirty: bool = False,
        wheel: float = 0.0;

    """Key_Init: one node per key the platform can press."""
    def boot {
        if self.booted {
            return;
        }
        self.booted = True;
        for (name, codes) in KEY_NAME_CODES {
            self +>:HasKey:+> Key(name=name, inputs=codes);
        }
        for digit in range(10) {
            self +>:HasKey:+> Key(name=str(digit), inputs=[48 + digit]);
        }
        for letter in range(26) {
            self +>:HasKey:+> Key(name=chr(97 + letter), inputs=[65 + letter]);
        }
        for button in range(5) {
            self +>:HasKey:+> Key(name="MOUSE" + str(button + 1), device="mouse", inputs=[button]);
        }
        self +>:HasKey:+> Key(name="MWHEELUP", device="wheel", inputs=[1]);
        self +>:HasKey:+> Key(name="MWHEELDOWN", device="wheel", inputs=[-1]);
    }

    """Key_StringToKeynum: the key a config or the console names, or None.
    Single characters name themselves (letters in lower case, as Q3); other
    names match case-insensitively. With `make`, a character no key sends
    (such as "~" or "+") still gets a key so it can hold a binding."""
    def key(word: str, make: bool = False) -> Key | None {
        if not word {
            return None;
        }
        name = key_canonical_name(word);
        search = self spawn FindKey(name=name);
        found = search.found;
        if found is None and make and len(name) == 1 {
            made = Key(name=name, device="none");
            self +>:HasKey:+> made;
            return made;
        }
        return found;
    }

    def is_down(name: str) -> bool {
        found = self.key(name);
        return found is not None and found.down;
    }

    """This frame's key events and typed characters (Sys_SendKeyEvents)."""
    def poll -> tuple[list[KeyEvent], list[str]] {
        self.wheel = float(GetMouseWheelMove());
        poll = self spawn PollKeys(wheel=self.wheel);
        typed: list[str] = [];
        code = int(GetCharPressed());
        while code > 0 {
            if code >= 32 and code < 127 {
                typed.append(chr(code));
            }
            code = int(GetCharPressed());
        }
        return (poll.events, typed);
    }

    """Key_ClearStates: forget which keys are down (and send the key up
    commands for the button bindings they hold)."""
    def release_all -> list[KeyEvent] {
        clear = self spawn ReleaseKeys();
        return clear.events;
    }

    """The keys whose binding is exactly `command` (M_FindKeysForCommand)."""
    def keys_for(command: str) -> list[str] {
        search = self spawn BoundKeys(command=command);
        return search.names;
    }

    """Bind `command` to the key named `word`; an empty command unbinds."""
    def set_binding(word: str, command: str) -> bool {
        found = self.key(word, make=True);
        if found is None {
            return False;
        }
        if found.binding != command {
            found.binding = command;
            self.dirty = True;
        }
        return True;
    }

    """Key_WriteBindings: an `unbindall` and a `bind` line for every bound key."""
    def binding_lines -> list[str] {
        search = self spawn BoundKeys();
        lines = ["unbindall"];
        for i in range(len(search.names)) {
            lines.append("bind " + key_config_word(search.names[i]) + " " + quote_command_word(search.bindings[i]));
        }
        return lines;
    }

    """bind, unbind, unbindall and bindlist (Key_Bind_f and friends)."""
    def command(shell: Shell, args: list[str]) {
        name = args[0].lower();
        if name == "bind" {
            if len(args) < 2 {
                shell.print("bind <key> [command] : attach a command to a key");
                return;
            }
            found = self.key(args[1], make=len(args) > 2);
            if found is None {
                shell.print("\"" + args[1] + "\" isn't a valid key");
                return;
            }
            if len(args) == 2 {
                if found.binding {
                    shell.print("\"" + args[1] + "\" = \"" + found.binding + "\"");
                } else {
                    shell.print("\"" + args[1] + "\" is not bound");
                }
                return;
            }
            self.set_binding(found.name, " ".join(args[2:]));
        } elif name == "unbind" {
            if len(args) != 2 {
                shell.print("unbind <key> : remove commands from a key");
                return;
            }
            found = self.key(args[1]);
            if found is None {
                shell.print("\"" + args[1] + "\" isn't a valid key");
                return;
            }
            self.set_binding(found.name, "");
        } elif name == "unbindall" {
            self spawn Unbind();
            self.dirty = True;
        } elif name == "bindlist" {
            search = self spawn BoundKeys();
            for i in range(len(search.names)) {
                shell.print(search.names[i] + " \"" + search.bindings[i] + "\"");
            }
        }
    }

    """Declare the key commands with the shell."""
    def declare(shell: Shell) {
        self.boot();
        shell.command("bind", "keys", "bind <key> [command]", "attach a command to a key");
        shell.command("unbind", "keys", "unbind <key>", "remove the command from a key");
        shell.command("unbindall", "keys", "unbindall", "remove every key's command");
        shell.command("bindlist", "keys", "bindlist", "list the bound keys");
    }
}

"""The canonical spelling of a key name: one character as itself (letters
lower case, ";" as SEMICOLON), other names upper case."""
def key_canonical_name(word: str) -> str {
    if len(word) == 1 {
        return KEY_SPELLINGS.get(word, word.lower());
    }
    return word.upper();
}

"""A key name as a config line writes it: quoted when it is a character the
command parser would take apart."""
def key_config_word(name: str) -> str {
    if name in ["\"", "/"] or ord(name[0]) <= 32 {
        return quote_command_word(name);
    }
    return name;
}

walker FindKey {
    has name: str,
        found: Key | None = None;

    can start with Keyboard entry {
        visit [here->:HasKey:->];
    }

    can check with Key entry {
        if here.name == self.name {
            self.found = here;
            disengage;
        }
    }
}

"""Sys_SendKeyEvents: compare each key's raylib state with its last one. A
wheel notch is a press and release in the same frame, as the originals sent
K_MWHEELUP down and up together."""
walker PollKeys {
    has wheel: float = 0.0,
        events: list[KeyEvent] = [];

    can start with Keyboard entry {
        visit [here->:HasKey:->];
    }

    can sample with Key entry {
        if here.device == "none" {
            return;
        }
        if here.device == "wheel" {
            if (here.inputs[0] > 0 and self.wheel > 0.0) or (here.inputs[0] < 0 and self.wheel < 0.0) {
                self.events.append(KeyEvent(key=here, down=True));
                self.events.append(KeyEvent(key=here, down=False));
            }
            return;
        }
        now = False;
        repeating = False;
        for code in here.inputs {
            if here.device == "mouse" {
                now = now or IsMouseButtonDown(i32(code));
            } else {
                now = now or IsKeyDown(i32(code));
                repeating = repeating or IsKeyPressedRepeat(i32(code));
            }
        }
        if now != here.down {
            here.down = now;
            self.events.append(KeyEvent(key=here, down=now));
        } elif now and repeating {
            self.events.append(KeyEvent(key=here, down=True, repeat=True));
        }
    }
}

walker ReleaseKeys {
    has events: list[KeyEvent] = [];

    can start with Keyboard entry {
        visit [here->:HasKey:->];
    }

    can clear with Key entry {
        if here.down {
            here.down = False;
            self.events.append(KeyEvent(key=here, down=False));
        }
    }
}

"""The bound keys in key order (every one, or those bound to `command`)."""
walker BoundKeys {
    has command: str = "",
        names: list[str] = [],
        bindings: list[str] = [];

    can start with Keyboard entry {
        visit [here->:HasKey:->];
    }

    can gather with Key entry {
        if not here.binding {
            return;
        }
        if self.command and here.binding.lower() != self.command.lower() {
            return;
        }
        self.names.append(here.name);
        self.bindings.append(here.binding);
    }
}

walker Unbind {
    can start with Keyboard entry {
        visit [here->:HasKey:->];
    }

    can clear with Key entry {
        here.binding = "";
    }
}

"""Key_Event's commands for a key: a binding of button commands (a leading
"+", Q3 allowing several joined by ";") gets the key's name appended so the
release can be matched, and its release sends the "-" forms; any other binding
runs once on the press."""
def key_event_commands(binding: str, key_name: str, down: bool) -> list[str] {
    if not binding {
        return [];
    }
    if not binding.startswith("+") {
        return [binding] if down else [];
    }
    commands: list[str] = [];
    for part in binding.split(";") {
        word = part.strip();
        if not word {
            continue;
        }
        if word.startswith("+") {
            commands.append((word if down else "-" + word[1:]) + " " + key_config_word(key_name));
        } elif down {
            commands.append(word);
        }
    }
    return commands;
}
