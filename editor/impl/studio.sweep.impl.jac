"""Sweeps: an outline carried along a line or a path of entities, kept as a
group that remembers what it was swept from, to be swept again when the path
has moved. Declarations live in studio.jac."""

"""The numbers at the front of a command's words, as far as they are numbers."""
def:priv sweep_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            return found;
        }
    }
    return found;
}

impl Studio.path_of(scene: Scene, name: str) -> list[Vec3] {
    corners: list[Vec3] = [];
    seen: list[str] = [];
    wanted_name = name;
    while wanted_name and len(corners) < 64 {
        if wanted_name in seen {
            # Back where it began: the path is a ring.
            if wanted_name == seen[0] and len(corners) > 2 {
                corners.append(corners[0]);
            }
            break;
        }
        seen.append(wanted_name);
        next_name = "";
        stands: Vec3 | None = None;
        for item in scene.items() {
            if item.fields.get("targetname", "") == wanted_name and stands is None {
                stands = item.origin();
                next_name = item.fields.get("target", "");
            }
        }
        if stands is None {
            break;
        }
        corners.append(stands);
        wanted_name = next_name;
    }
    return corners;
}

impl Studio.swept(scene: Scene, fields: dict[str, str], material: str) -> list[list[Side]] {
    words = fields.get("_sweep", "").split();
    sizes = sweep_numbers(words[1:]);
    if len(words) < 3 or len(sizes) < 2 {
        return [];
    }
    pieces: list[list[tuple[float, float]]] = [];
    if words[0] == "brush" {
        # The outline it was given, kept corner by corner.
        pairs = sweep_numbers(fields.get("_outline", "").split());
        piece: list[tuple[float, float]] = [];
        for index in range(len(pairs) // 2) {
            piece.append((pairs[index * 2], pairs[index * 2 + 1]));
        }
        if len(piece) >= 3 {
            pieces.append(piece);
        }
    } else {
        pieces = profile_pieces(words[0], int(sizes[2]) if len(sizes) > 2 else 8);
    }
    path: list[Vec3] = [];
    if fields.get("_along", "") {
        path = self.path_of(scene, fields["_along"]);
    } else {
        spots = sweep_numbers(fields.get("_line", "").split());
        for index in range(len(spots) // 3) {
            path.append(Vec3(x=spots[index * 3], y=spots[index * 3 + 1], z=spots[index * 3 + 2]));
        }
    }
    ring = fields.get("_closed", "0") == "1"
        or (len(path) > 3 and path[0].sub(path[-1]).length() < 0.01);
    return sweep_brushes(pieces, path, sizes[0], sizes[1], material, ring);
}

impl Studio.sweep_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_sweep" {
        return False;
    }
    kind = args[1] if len(args) > 1 else "";
    if kind == "again" {
        # Those selected, or every sweep there is, from their paths as they stand.
        chosen = [item for item in scene.selection() if "_sweep" in item.fields];
        if len(chosen) == 0 {
            chosen = [item for item in scene.items() if "_sweep" in item.fields];
        }
        count = 0;
        for item in chosen {
            had = scene.solids_of(item);
            remade = self.swept(scene, item.fields, had[0].sides[0].material if len(had) > 0 else self.material);
            if len(remade) > 0 and scene.rebuild_item(item, remade, {}, "Sweep again") {
                count += 1;
                print("studio: swept again brushes=" + str(len(remade)));
            }
        }
        self.say("Swept " + str(count) + " again" if count else "No sweep could be swept again (its path is gone, or there is none)");
        return True;
    }
    usage = "ed_sweep <" + "|".join(PROFILE_KINDS) + "|brush> [wide tall] [count] along <name> | line <x y z> <x y z> ... [closed] | again";
    if kind not in PROFILE_KINDS and kind != "brush" {
        self.say(usage);
        return True;
    }
    rest = args[2:];
    sizes = sweep_numbers(rest);
    rest = rest[len(sizes):];
    told: dict[str, str] = {"classname": "func_group", "_group_name": "sweep"};
    wide = sizes[0] if len(sizes) > 0 else 32.0;
    tall = sizes[1] if len(sizes) > 1 else wide;
    sides_round = int(sizes[2]) if len(sizes) > 2 else 8;
    if kind == "brush" {
        picked = scene.selected_solids();
        if len(picked) != 1 {
            self.say("ed_sweep brush: select the one brush whose outline, seen from the front, is to be swept");
            return True;
        }
        outline = profile_of(picked[0].sides);
        if len(outline[0]) < 3 {
            self.say("That brush has no outline from the front");
            return True;
        }
        if len(sizes) < 2 {
            wide = outline[1];
            tall = outline[2];
        }
        told["_outline"] = " ".join([str(round(pair[0], 4)) + " " + str(round(pair[1], 4)) for pair in outline[0]]);
    }
    if wide < 1.0 or tall < 1.0 {
        self.say(usage);
        return True;
    }
    told["_sweep"] = kind + " " + str(round(wide, 2)) + " " + str(round(tall, 2)) + " " + str(sides_round);
    if len(rest) > 1 and rest[0] == "along" {
        told["_along"] = rest[1];
    } elif len(rest) > 6 and rest[0] == "line" {
        spots = sweep_numbers(rest[1:]);
        if len(spots) < 6 or len(spots) % 3 != 0 {
            self.say("ed_sweep ... line <x y z> <x y z> ...: three numbers a point, two points or more");
            return True;
        }
        told["_line"] = " ".join([str(round(spot, 2)) for spot in spots]);
    } else {
        self.say(usage);
        return True;
    }
    if len(rest) > 0 and rest[-1] == "closed" {
        told["_closed"] = "1";
    }
    made = self.swept(scene, told, self.material);
    if len(made) == 0 {
        self.say(
            "Nothing to sweep along: " + ("no entities are named " + told["_along"] + " in a row" if "_along" in told else "the line has no length")
        );
        return True;
    }
    if scene.insert_map([MapItem(fields=told, brushes=made)], Vec3(), "Sweep") {
        print("studio: swept " + kind + " brushes=" + str(len(made)));
        self.say("Swept a " + kind + " into " + str(len(made)) + " brushes (ed_sweep again sweeps it along its path as that now stands)");
    }
    return True;
}
