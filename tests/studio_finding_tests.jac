import from editor.assets.finding { Search, search_of, name_found, size_fits, tags_from, tags_text, tags_with, colours_used }

test "a search is words, and a kind, a game, a tag and a size when they are said" {
    asked = search_of("Wall kind:images game:Quake2 metal");
    assert asked.words == ["wall", "metal"] and asked.kind == "image" and asked.game == "q2" and not asked.tag and not asked.size;
    assert search_of("").idle() and not asked.idle() and not search_of("size:64").idle();
    late = search_of("type:model tag:Trim size:>=128 game:arena");
    assert late.words == [] and late.kind == "model" and late.tag == "trim" and late.size == ">=128" and late.game == "q3";
    # Every word must be in the name; the game and the kind of file must be those asked.
    assert name_found(asked, "q2", "textures/e1u1/metal_wall1.wal") and not name_found(asked, "q2", "textures/e1u1/metal1_1.wal");
    assert not name_found(asked, "q1", "textures/metal_wall.wal") and not name_found(asked, "q2", "sound/metal_wall.wav");
    assert name_found(search_of("kind:sound"), "q1", "sound/misc/menu1.wav") and name_found(search_of("kind:map"), "q3", "maps/q3dm1.bsp");
    assert name_found(search_of(""), "q1", "anything") and not name_found(search_of("kind:nonsense"), "q1", "a.wav");
    # A tag is asked of the tags a file has.
    assert name_found(late, "q3", "models/players/sarge/upper.md3", ["trim", "body"]);
    assert not name_found(late, "q3", "models/players/sarge/upper.md3", ["body"]) and not name_found(late, "q3", "models/players/sarge/upper.md3");
}

test "a size is asked exactly, by one side, or by the longer side at least or at most" {
    assert size_fits("64x64", 64, 64) and not size_fits("64x64", 64, 32) and not size_fits("64x32", 32, 64);
    assert size_fits("64", 64, 32) and size_fits("64", 16, 64) and not size_fits("64", 32, 32);
    assert size_fits(">=128", 128, 16) and size_fits(">=128", 32, 256) and not size_fits(">=128", 64, 127);
    assert size_fits("<=32", 32, 16) and not size_fits("<=32", 64, 16);
    assert size_fits(">128", 129, 1) and not size_fits(">128", 128, 128) and size_fits("<32", 31, 31) and not size_fits("<32", 32, 8);
    # Nothing said, and what is no size, leave every size in.
    assert size_fits("", 5, 7) and size_fits("big", 5, 7) and size_fits(">=wide", 5, 7) and size_fits("64xtall", 5, 7) and size_fits("1x2x3", 5, 7);
}

test "tags are hung on files, taken off, and kept as text" {
    tags: dict[str, list[str]] = {};
    tags = tags_with(tags, "q2:textures/e1u1/metal1_1.wal", "Trim");
    tags = tags_with(tags, "q2:textures/e1u1/metal1_1.wal", "base");
    tags = tags_with(tags, "q1:progs/soldier.mdl", "grunt");
    again = tags_with(tags, "q1:progs/soldier.mdl", "grunt");
    assert tags == {"q2:textures/e1u1/metal1_1.wal": ["base", "trim"], "q1:progs/soldier.mdl": ["grunt"]} and again == tags;
    # A word with a gap or a colon in it is no tag.
    assert tags_with(tags, "q1:progs/soldier.mdl", "two words") == tags and tags_with(tags, "q1:progs/soldier.mdl", "a:b") == tags;
    text = tags_text(tags);
    assert text == "q1:progs/soldier.mdl grunt\nq2:textures/e1u1/metal1_1.wal base trim\n" and tags_from(text) == tags;
    assert tags_from("// a note\n\nlone\n") == {} and tags_text({}) == "";
    # The last tag off a file takes the file out; taking off what is not there changes nothing.
    less = tags_with(tags, "q1:progs/soldier.mdl", "grunt", False);
    assert list(less.keys()) == ["q2:textures/e1u1/metal1_1.wal"] and tags_with(less, "q1:progs/soldier.mdl", "grunt", False) == less;
    assert len(tags) == 2;
}

test "the colours a picture uses are counted, and its clear texels" {
    picture = bytes([10, 20, 30, 255, 10, 20, 30, 255, 0, 0, 0, 0, 200, 0, 0, 255]);
    assert colours_used(picture) == (3, 1) and colours_used(b"") == (0, 0);
    assert colours_used(picture, 2) == (2, 1);
}
