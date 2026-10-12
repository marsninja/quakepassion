"""The files an entity's fields name: the sounds it plays and the models it
is drawn as, by the game's own rules for where they are kept. Whether an
archive holds them is for whoever has the archives to say."""

"""The file a sound field names: Quake and Quake II keep sounds under
`sound/` and name them from there; Quake III names them from the top. A
name beginning with `*` is a player's own sound, kept with each model, and
names no one file."""
def sound_file(game: str, value: str) -> str {
    name = value.strip().replace("\\", "/");
    if not name or name.startswith("*") {
        return "";
    }
    if "." not in name.split("/")[-1] {
        name += ".wav";
    }
    if game == "q3" or name.lower().startswith("sound/") {
        return name;
    }
    return "sound/" + name;
}

"""The file a model field names. `*3` is one of the level's own brush
models, and names no file."""
def model_file(value: str) -> str {
    name = value.strip().replace("\\", "/");
    if not name or name.startswith("*") or "." not in name.split("/")[-1] {
        return "";
    }
    return name;
}

"""The files an entity's fields name, as (field, file): its `noise` and
`music` as sounds (Quake III's music may name two, an opening and a loop),
its `model` and `model2` as models."""
def needed_files(game: str, fields: dict[str, str]) -> list[tuple[str, str]] {
    found: list[tuple[str, str]] = [];
    for key in sorted(fields.keys()) {
        value = fields[key];
        if key in ["noise", "noise1", "noise2", "noise3", "noise4"] {
            wanted = sound_file(game, value);
            if wanted {
                found.append((key, wanted));
            }
        } elif key == "music" and game == "q3" {
            for part in value.split() {
                wanted = sound_file(game, part);
                if wanted {
                    found.append((key, wanted));
                }
            }
        } elif key in ["model", "model2"] {
            wanted = model_file(value);
            if wanted {
                found.append((key, wanted));
            }
        }
    }
    return found;
}

"""Those of the needed files that are not among a game's files (names are
matched whatever their case, as the games match them)."""
def missing_files(needed: list[tuple[str, str]], held: set[str]) -> list[tuple[str, str]] {
    return [need for need in needed if need[1].lower() not in held];
}

"""A game's file names as a set to look names up in, whatever their case."""
def held_names(names: list[str]) -> set[str] {
    return {name.lower() for name in names};
}

"""Whether an entity's fields name a file: by the file its game would look
for, or by the very words of the field (a sound named `misc/talk.wav` is
found by that, and by `sound/misc/talk.wav`). Case does not matter."""
def names_file(game: str, fields: dict[str, str], name: str) -> bool {
    wanted = name.strip().replace("\\", "/").lower();
    if not wanted {
        return False;
    }
    for (key, file) in needed_files(game, fields) {
        if file.lower() == wanted or fields.get(key, "").strip().replace("\\", "/").lower() == wanted {
            return True;
        }
    }
    return False;
}

"""What kind of file a field names, by its key: "sound", "model", or ""
when it names none."""
def file_field(key: str) -> str {
    if key in ["noise", "noise1", "noise2", "noise3", "noise4", "music"] {
        return "sound";
    }
    if key in ["model", "model2"] {
        return "model";
    }
    return "";
}

"""The values a field of that kind can take in a game, from the game's
files, as the field would name them: Quake and Quake II name a sound from
`sound/` on, Quake III from the top; a model is named whole. Sorted."""
def field_choices(game: str, kind: str, names: list[str]) -> list[str] {
    found: list[str] = [];
    for name in names {
        low = name.lower();
        if kind == "sound" and low.endswith(".wav") {
            if game == "q3" {
                found.append(name);
            } elif low.startswith("sound/") {
                found.append(name[6:]);
            }
        } elif kind == "model" and (low.endswith(".mdl") or low.endswith(".md2") or low.endswith(".md3") or low.endswith(".spr")
            or low.endswith(".sp2")) {
            found.append(name);
        }
    }
    return sorted(found);
}
