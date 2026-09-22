"""str.splitlines must not invent an empty line after a final line break."""
with entry {
    text = "QUAKEPASSION SETTINGS 1\n85.0 0.0022 0.0 240.0 0.0 1.0 1.0 0.4\n";
    lines = text.splitlines();
    print("LINES", len(lines));
    for line in lines {
        print("LINE", "[" + line + "]");
    }
    assert len(lines) == 2;
    assert "".splitlines() == [];
    assert "a\nb\n".splitlines() == ["a", "b"];
    assert "a\n\n".splitlines() == ["a", ""];
    assert "a\r\nb\rc\n".splitlines() == ["a", "b", "c"];
    print("SPLITLINES PASS");
}
