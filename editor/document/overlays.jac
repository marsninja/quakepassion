"""What a brush is for, when it is not a wall: the volumes that set things
off, and the brushes a player cannot see that hold him in, tell the
compiler where to look, or are left out of the picture. An editor shows
these apart from the rest, each kind in a colour of its own."""

"""The words in a material's name that say a brush is not there to be seen,
with what each makes it."""
glob UNSEEN_WORDS: dict[str, str] = {
    "clip": "clip", "playerclip": "clip", "monsterclip": "clip", "weapclip": "clip", "botclip": "clip", "hint": "hint",
    "skip": "hint", "caulk": "hint", "nodraw": "hint", "trigger": "trigger", "origin": "clip", "areaportal": "hint"
};

"""What kind of brush this is, of the kinds shown apart: "trigger" (a volume
that sets things off: a brush of a `trigger_` entity, or in the trigger
material), "clip" (it stops movement and is not drawn), "hint" (it is for
the compiler: hint, skip, caulk, nodraw), or "" for a brush like any other.
`materials` are the materials of its sides."""
def brush_kind(classname: str, materials: list[str]) -> str {
    if classname.startswith("trigger_") {
        return "trigger";
    }
    found = "";
    for material in materials {
        last = material.lower().replace(":", "/").split("/")[-1];
        kind = UNSEEN_WORDS.get(last, "");
        if not kind {
            # A game's own spellings: common/clip, e1u1/clip, clip_monster ...
            for (word, what) in UNSEEN_WORDS.items() {
                if last.startswith(word + "_") or last.endswith("_" + word) {
                    kind = what;
                }
            }
        }
        if not kind {
            # One side that is seen makes it a brush like any other.
            return "";
        }
        if kind == "trigger" or not found {
            found = kind;
        }
    }
    return found;
}

"""The colour each kind is outlined in."""
def kind_tint(kind: str) -> int {
    if kind == "trigger" {
        return 0xf5c542;
    }
    if kind == "clip" {
        return 0xe54fd0;
    }
    return 0x4fd0e5 if kind == "hint" else -1;
}
