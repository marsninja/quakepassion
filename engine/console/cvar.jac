"""Console variables (cvar.c): named, typed settings that the subsystems owning
them register with the shell (Cvar_Get) and then read through the node they
hold, as the engines kept a `cvar_t *` to each of theirs.

A cvar keeps its text as typed and the number parsed from it (cvar_t string
and value). Registration gives it a kind that validates assignments (Q3's
Cvar_CheckRange): numbers are clamped to their bounds, integers truncated,
booleans held as 0 or 1. A cvar may answer to other games' names for the same
setting (`s_volume` for `volume`, `cg_fov` for `fov`), so each game's configs
and habits work while the engine keeps one value."""

# cvar_t flags (Q3 q_shared.h): ARCHIVE cvars are written to the user's
# configuration, ROM ones only display, USER_CREATED ones were made by `set`
# before any subsystem registered them.
glob CVAR_ARCHIVE: int = 1,
     CVAR_ROM: int = 64,
     CVAR_USER_CREATED: int = 128;


"""What the console can name: a cvar, a command or an alias."""
node ConsoleName {
    has name: str,
        description: str = "";

    """Whether the console text `word` names this (case-insensitively)."""
    def answers(word: str) -> bool {
        return self.name.lower() == word.lower();
    }
}


node Cvar(ConsoleName) {
    has reset_text: str = "",
        flags: int = 0,
        kind: str = "string",
        low: float = 0.0,
        high: float = 0.0,
        aliases: list[str] = [],
        text: str = "",
        number: float = 0.0,
        integer: int = 0,
        modified: bool = False;

    """Cvar_Get: a cvar holds its reset value from the start, before any
    shell registers it (Shell.register may then adopt a value typed before
    it existed)."""
    def postinit {
        if self.reset_text and not self.text {
            self.assign(self.reset_text);
            self.modified = False;
        }
    }

    def answers(word: str) -> bool {
        lowered = word.lower();
        if self.name.lower() == lowered {
            return True;
        }
        for alias in self.aliases {
            if alias.lower() == lowered {
                return True;
            }
        }
        return False;
    }

    """Cvar_Set: validate `value` for the kind and store it; True when the
    value changed."""
    def assign(value: str) -> bool {
        shown = value.strip();
        parsed = cvar_number(shown);
        if self.kind == "bool" {
            shown = "1" if parsed != 0.0 else "0";
            parsed = float(shown);
        } elif self.kind == "int" or self.kind == "float" {
            bounded = parsed;
            if self.low < self.high {
                bounded = max(self.low, min(self.high, parsed));
            }
            if self.kind == "int" {
                bounded = float(int(bounded));
            }
            shown = cvar_number_text(bounded);
            parsed = bounded;
        }
        changed = shown != self.text;
        self.text = shown;
        self.number = parsed;
        self.integer = int(parsed);
        if changed {
            self.modified = True;
        }
        return changed;
    }

    """A boolean cvar's state (any non-zero value)."""
    def on -> bool {
        return self.number != 0.0;
    }

    """Q3 Cvar_List_f's flag column."""
    def flag_letters -> str {
        return ("R" if self.flags & CVAR_ROM else " ")
            + ("A" if self.flags & CVAR_ARCHIVE else " ")
            + ("U" if self.flags & CVAR_USER_CREATED else " ");
    }
}


"""atof: the number a cvar's text starts with (0 when it has none)."""
def cvar_number(text: str) -> float {
    end = 0;
    seen_digit = False;
    seen_point = False;
    seen_exponent = False;
    i = 0;
    if i < len(text) and text[i] in ["-", "+"] {
        i += 1;
    }
    while i < len(text) {
        c = text[i];
        if c >= "0" and c <= "9" {
            seen_digit = True;
            end = i + 1;
        } elif c == "." and not seen_point and not seen_exponent {
            seen_point = True;
        } elif (c == "e" or c == "E") and seen_digit and not seen_exponent {
            seen_exponent = True;
            if i + 1 < len(text) and text[i + 1] in ["-", "+"] {
                i += 1;
            }
        } else {
            break;
        }
        i += 1;
    }
    if not seen_digit {
        return 0.0;
    }
    try {
        return float(text[:end]);
    } except Exception {
        return 0.0;
    }
}

"""A cvar number as the console shows it: integers without a decimal point,
other values without trailing zeros."""
def cvar_number_text(value: float) -> str {
    if value == float(int(value)) and abs(value) < 1000000000.0 {
        return str(int(value));
    }
    text = str(value);
    if "." in text and "e" not in text {
        while text.endswith("0") {
            text = text[:-1];
        }
        if text.endswith(".") {
            text = text[:-1];
        }
    }
    return text;
}
