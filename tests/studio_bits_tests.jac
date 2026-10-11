import from editor.geometry.bits { bit_names, bit_of, bits_named, bit_table }

test "the bits of a side's contents and flags have each game's own names" {
    # The same bit is another thing in another game.
    assert bit_of("q2", "contents", "window") == 1 and bit_of("q3", "contents", "window") == -1;
    assert bit_of("q2", "flags", "light") == 0 and bit_of("q3", "flags", "nodamage") == 0;
    assert bit_of("q2", "contents", "ladder") == 29 and bit_of("q3", "flags", "ladder") == 3;
    assert bit_of("q2", "contents", "detail") == 27 and bit_of("q3", "contents", "detail") == 27;
    assert bit_of("q3", "contents", "NoDrop") == 31 and bit_of("q2", "flags", "nosuch") == -1;
    # Quake's maps keep none, and a value has no bits to name.
    assert bit_names("q1", "contents") == [] and bit_names("q2", "value") == [] and bit_table("q9", "flags") == {};
    assert bit_names("q2", "flags") == ["light", "slick", "sky", "warp", "trans33", "trans66", "flowing", "nodraw", "hint", "skip"];
    assert bit_names("q3", "contents")[:4] == ["solid", "lava", "slime", "water"] and len(bit_names("q3", "flags")) == 19;
    assert len(bit_names("q2", "contents")) == 22 and bit_names("q2", "contents")[-1] == "ladder";
}

test "a number is said by its bits' names, and what has no name by its number" {
    assert bits_named("q2", "flags", 0) == "none" and bits_named("q2", "flags", 2 + 4) == "slick sky";
    assert bits_named("q2", "contents", 1 + (1 << 27)) == "solid detail";
    assert bits_named("q3", "contents", (1 << 16) + (1 << 31)) == "playerclip nodrop";
    # Bit ten is nothing in Quake II; in Quake it all goes by number.
    assert bits_named("q2", "flags", 2 + 1024) == "slick 1024" and bits_named("q1", "flags", 3) == "1 2";
    for game in ["q2", "q3"] {
        for which in ["contents", "flags"] {
            for name in bit_names(game, which) {
                assert bits_named(game, which, 1 << bit_of(game, which, name)) == name;
            }
        }
    }
}
