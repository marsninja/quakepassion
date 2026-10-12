import from engine.input.keys { Keyboard }
import from editor.document.chords { chord_parts, bind_chord, chord_command, bound_chords, layer_of }

test "a chord is its modifiers, in either order, and the word for its key" {
    assert chord_parts("k") == ("", "k") and chord_parts("Ctrl+K") == ("ctrl+", "K");
    assert chord_parts("shift+ctrl+F5") == ("ctrl+shift+", "F5") and chord_parts("ctrl+shift+f5") == ("ctrl+shift+", "f5");
    # A key that is itself a plus, or a modifier's word with nothing after it.
    assert chord_parts("ctrl++") == ("ctrl+", "+") and chord_parts("ctrl+") == ("", "ctrl+");
}

test "chords are bound on keyboards of the engine's, one for each way the modifiers are held" {
    layers: dict[str, Keyboard] = {};
    assert bind_chord(layers, "k", "ed_shape column 64 64 128") == "k";
    assert bind_chord(layers, "Shift+K", "ed_shape cap 128 32 64") == "shift+k";
    assert bind_chord(layers, "ctrl+f5", "ed_play here") == "ctrl+f5";
    # The engine's own names for keys, and none it does not know.
    assert bind_chord(layers, "pgup", "ed_grid up") == "pgup" and bind_chord(layers, "ctrl+nosuchkey", "ed_grid up") == "";
    assert chord_command(layers, "", "k") == "ed_shape column 64 64 128" and chord_command(layers, "shift+", "k") == "ed_shape cap 128 32 64";
    assert chord_command(layers, "ctrl+", "F5") == "ed_play here" and chord_command(layers, "ctrl+", "k") == "";
    assert chord_command(layers, "ctrl+shift+", "k") == "";
    assert bound_chords(layers) == [
        ("ctrl+f5", "ed_play here"), ("k", "ed_shape column 64 64 128"), ("pgup", "ed_grid up"), ("shift+k", "ed_shape cap 128 32 64")
    ];
    # Let go, a chord is no longer listed; the plain key keeps its own.
    assert bind_chord(layers, "shift+k", "") == "shift+k";
    assert [chord for (chord, command) in bound_chords(layers)] == ["ctrl+f5", "k", "pgup"];
    # Each layer is a keyboard with the engine's keys, and they are not one another.
    held = layer_of(layers, "ctrl+").key("F5");
    plain = layer_of(layers, "").key("F5");
    assert held is not None and plain is not None and held.binding == "ed_play here" and plain.binding == "";
}
