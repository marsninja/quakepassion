"""What the bits of a brush side's contents and surface flags are called.

A Quake II or Quake III map file keeps three numbers on every side of a
brush: what the brush is made of, how the face behaves, and a value. Each
game reads the bits its own way; Quake's map files have none."""

"""Quake II's contents (q_shared.h CONTENTS_*), by bit."""
glob Q2_CONTENTS: dict[str, int] = {
    "solid": 0, "window": 1, "aux": 2, "lava": 3, "slime": 4, "water": 5, "mist": 6, "areaportal": 15, "playerclip": 16,
    "monsterclip": 17, "current_0": 18, "current_90": 19, "current_180": 20, "current_270": 21, "current_up": 22,
    "current_down": 23, "origin": 24, "monster": 25, "deadmonster": 26, "detail": 27, "translucent": 28, "ladder": 29
};

"""Quake II's surface flags (q_shared.h SURF_*), by bit."""
glob Q2_SURFACE: dict[str, int] = {
    "light": 0, "slick": 1, "sky": 2, "warp": 3, "trans33": 4, "trans66": 5, "flowing": 6, "nodraw": 7, "hint": 8, "skip": 9
};

"""Quake III's contents (surfaceflags.h CONTENTS_*), by bit."""
glob Q3_CONTENTS: dict[str, int] = {
    "solid": 0, "lava": 3, "slime": 4, "water": 5, "fog": 6, "areaportal": 15, "playerclip": 16, "monsterclip": 17,
    "teleporter": 18, "jumppad": 19, "clusterportal": 20, "donotenter": 21, "origin": 24, "body": 25, "corpse": 26,
    "detail": 27, "structural": 28, "translucent": 29, "trigger": 30, "nodrop": 31
};

"""Quake III's surface flags (surfaceflags.h SURF_*), by bit."""
glob Q3_SURFACE: dict[str, int] = {
    "nodamage": 0, "slick": 1, "sky": 2, "ladder": 3, "noimpact": 4, "nomarks": 5, "flesh": 6, "nodraw": 7, "hint": 8,
    "skip": 9, "nolightmap": 10, "pointlight": 11, "metalsteps": 12, "nosteps": 13, "nonsolid": 14, "lightfilter": 15,
    "alphashadow": 16, "nodlight": 17, "dust": 18
};

"""A game's names for the bits of a side's "contents" or "flags", each with
its bit. Empty for a game whose maps keep none, and for the value."""
def bit_table(game: str, which: str) -> dict[str, int] {
    if game == "q2" {
        return Q2_CONTENTS if which == "contents" else (Q2_SURFACE if which == "flags" else {});
    }
    if game == "q3" {
        return Q3_CONTENTS if which == "contents" else (Q3_SURFACE if which == "flags" else {});
    }
    return {};
}

"""The names, lowest bit first."""
def bit_names(game: str, which: str) -> list[str] {
    table = bit_table(game, which);
    found: list[str] = [];
    for bit in range(32) {
        for (name, place) in table.items() {
            if place == bit {
                found.append(name);
            }
        }
    }
    return found;
}

"""The bit a name stands for in a game, or -1 when the game has no such name."""
def bit_of(game: str, which: str, name: str) -> int {
    return bit_table(game, which).get(name.lower(), -1);
}

"""A number's bits by their names in a game, lowest first; a bit the game
has no name for is given as its number. "none" for nothing."""
def bits_named(game: str, which: str, value: int) -> str {
    table = bit_table(game, which);
    called: dict[int, str] = {};
    for (name, bit) in table.items() {
        called[bit] = name;
    }
    words: list[str] = [];
    for bit in range(32) {
        if (value >> bit) % 2 == 1 {
            words.append(called[bit] if bit in called else str(1 << bit));
        }
    }
    return " ".join(words) if len(words) > 0 else "none";
}
