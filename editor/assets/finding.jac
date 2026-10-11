"""What a search asks for, read from the words typed, and whether a file or
a texture answers it.

A search is words every name must hold, and beside them any of `kind:`,
`game:`, `tag:` and `size:`: `wall kind:image game:q2`, `size:64x64`,
`size:>=128 tag:trim`. Tags are words a user hangs on files to find them
again; they are kept as text, a file a line."""
import from ..formats.archive { file_kind }

"""What was asked: the words, and the other things when they were said."""
obj Search {
    has words: list[str] = [],
        kind: str = "",
        game: str = "",
        tag: str = "",
        size: str = "";

    """Whether nothing was asked at all."""
    def idle -> bool {
        return len(self.words) == 0 and not (self.kind or self.game or self.tag or self.size);
    }
}

"""The kinds of file by the names people give them."""
glob KIND_WORDS: dict[str, str] = {
    "image": "image", "images": "image", "texture": "image", "textures": "image", "picture": "image", "text": "text",
    "script": "text", "scripts": "text", "sound": "sound", "sounds": "sound", "model": "model", "models": "model",
    "map": "map", "maps": "map", "level": "map", "levels": "map", "other": "other"
};

"""The games by the names people give them."""
glob GAME_WORDS: dict[str, str] = {
    "q1": "q1", "quake": "q1", "quake1": "q1", "q2": "q2", "quake2": "q2", "q3": "q3", "quake3": "q3", "arena": "q3"
};

"""A search read from what was typed. A `kind:` or `game:` that names none
is kept as it is, and then nothing answers it."""
def search_of(text: str) -> Search {
    asked = Search();
    for word in text.lower().split() {
        if word.startswith("kind:") or word.startswith("type:") {
            asked.kind = KIND_WORDS.get(word[5:], word[5:]);
        } elif word.startswith("game:") {
            asked.game = GAME_WORDS.get(word[5:], word[5:]);
        } elif word.startswith("tag:") {
            asked.tag = word[4:];
        } elif word.startswith("size:") {
            asked.size = word[5:];
        } else {
            asked.words.append(word);
        }
    }
    return asked;
}

"""Whether a game's file answers a search (its size aside), given the tags
hung on it."""
def name_found(asked: Search, game: str, name: str, tags: list[str] = []) -> bool {
    low = name.lower();
    for word in asked.words {
        if word not in low {
            return False;
        }
    }
    if asked.game and asked.game != game {
        return False;
    }
    if asked.kind and file_kind(name) != asked.kind {
        return False;
    }
    return not asked.tag or asked.tag in tags;
}

def:priv whole(words: str) -> int {
    try {
        return int(words);
    } except ValueError {
        return -1;
    }
}

"""Whether a picture of a size answers what a search says of size: `64x64`
is that size exactly, `64` either side of it, `>=128` and `<=32` its longer
side at least or at most so much, and `>128`, `<32` the same without the
number itself. Nothing said, or something that is no size: every size."""
def size_fits(rule: str, wide: int, tall: int) -> bool {
    longer = max(wide, tall);
    for (mark, slack) in [(">=", 0), ("<=", 0), (">", 1), ("<", 1)] {
        if rule.startswith(mark) {
            bound = whole(rule[len(mark):]);
            if bound < 0 {
                return True;
            }
            return longer >= bound + slack if mark[0] == ">" else longer <= bound - slack;
        }
    }
    if "x" in rule {
        parts = rule.split("x");
        if len(parts) != 2 or whole(parts[0]) < 0 or whole(parts[1]) < 0 {
            return True;
        }
        return wide == whole(parts[0]) and tall == whole(parts[1]);
    }
    one = whole(rule);
    return one < 0 or wide == one or tall == one;
}

"""Tags read from their text: a file a line, its key (`game:name`) and then
its tags."""
def tags_from(text: str) -> dict[str, list[str]] {
    found: dict[str, list[str]] = {};
    for line in text.split("\n") {
        parts = line.split();
        if len(parts) >= 2 and not parts[0].startswith("//") {
            found[parts[0]] = sorted(parts[1:]);
        }
    }
    return found;
}

"""Tags as text, the files in order."""
def tags_text(tags: dict[str, list[str]]) -> str {
    lines: list[str] = [];
    for key in sorted(list(tags.keys())) {
        if len(tags[key]) > 0 {
            lines.append(key + " " + " ".join(sorted(tags[key])));
        }
    }
    return "\n".join(lines) + ("\n" if len(lines) > 0 else "");
}

"""Tags with a word hung on a file (or, with `on` false, taken off it)."""
def tags_with(tags: dict[str, list[str]], key: str, word: str, on: bool = True) -> dict[str, list[str]] {
    made: dict[str, list[str]] = {};
    for (held, words) in tags.items() {
        made[held] = list(words);
    }
    mark = word.lower().strip();
    if not mark or " " in mark or ":" in mark {
        return made;
    }
    had = made.get(key, []);
    if on and mark not in had {
        made[key] = sorted(had + [mark]);
    } elif not on and mark in had {
        left = [each for each in had if each != mark];
        if len(left) > 0 {
            made[key] = left;
        } else {
            made.pop(key);
        }
    }
    return made;
}

"""How many colours a picture of four numbers a texel uses (no more than
`most` are counted), and how many of its texels are clear."""
def colours_used(rgba: bytes, most: int = 4096) -> tuple[int, int] {
    seen: dict[int, bool] = {};
    clear = 0;
    for at in range(len(rgba) // 4) {
        if int(rgba[at * 4 + 3]) == 0 {
            clear += 1;
        }
        if len(seen) < most {
            seen[(int(rgba[at * 4]) << 16) | (int(rgba[at * 4 + 1]) << 8) | int(rgba[at * 4 + 2])] = True;
        }
    }
    return (len(seen), clear);
}
