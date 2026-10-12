"""The studio's own keys, held by the engine's binding system: a keyboard
of the engine's (its key nodes, its names for them and its walkers) for
each way Ctrl and Shift can be held, apart from every game's keyboard. A
chord is a key with `ctrl+` and `shift+` before it."""

import from engine.input.keys { Keyboard, BoundKeys }

"""The four ways Ctrl and Shift are held, as a chord begins."""
glob CHORD_LAYERS: list[str] = ["", "ctrl+", "shift+", "ctrl+shift+"];

"""A chord as how its modifiers are held and the word for its key: the
modifiers in either order, capitals ignored. No key when it names none."""
def chord_parts(chord: str) -> tuple[str, str] {
    held_ctrl = False;
    held_shift = False;
    word = chord.strip();
    going = True;
    while going {
        lowered = word.lower();
        if lowered.startswith("ctrl+") and len(word) > 5 {
            held_ctrl = True;
            word = word[5:];
        } elif lowered.startswith("shift+") and len(word) > 6 {
            held_shift = True;
            word = word[6:];
        } else {
            going = False;
        }
    }
    return (("ctrl+" if held_ctrl else "") + ("shift+" if held_shift else ""), word);
}

"""The keyboard for a way the modifiers are held, made and given its keys
the first time it is asked for."""
def layer_of(layers: dict[str, Keyboard], held: str) -> Keyboard {
    if held not in layers {
        made = Keyboard();
        made.boot();
        layers[held] = made;
    }
    return layers[held];
}

"""Bind a chord to a command ("" lets it go). Answers the chord as it is
kept, or "" when its key is none the engine knows."""
def bind_chord(layers: dict[str, Keyboard], chord: str, command: str) -> str {
    parts = chord_parts(chord);
    board = layer_of(layers, parts[0]);
    found = board.key(parts[1], make=bool(command));
    if found is None {
        return "";
    }
    board.set_binding(found.name, command);
    return parts[0] + found.name.lower();
}

"""What a key runs with the modifiers held so ("" when nothing)."""
def chord_command(layers: dict[str, Keyboard], held: str, key_name: str) -> str {
    if held not in layers {
        return "";
    }
    found = layers[held].key(key_name);
    return found.binding if found is not None else "";
}

"""Every chord that is bound and what it runs, in the order of the chords' words."""
def bound_chords(layers: dict[str, Keyboard]) -> list[tuple[str, str]] {
    found: dict[str, str] = {};
    for held in CHORD_LAYERS {
        if held not in layers {
            continue;
        }
        search = layers[held] spawn BoundKeys();
        for at in range(len(search.names)) {
            found[held + search.names[at].lower()] = search.bindings[at];
        }
    }
    return [(chord, found[chord]) for chord in sorted(found.keys())];
}
