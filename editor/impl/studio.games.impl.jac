"""Entities that carry the game whose rules they run under, and the spots
bots camp at. A scene of the studio's own is no one game's: an item, a
monster or a fixture in it spawns by the rules of the game named in its
`asset_game` field, as in a generated level. Declarations live in
studio.jac."""

impl Studio.game_for(scene: Scene, classname: str) -> str {
    if scene.game != "passion" {
        # A level of one game: everything in it is that game's.
        return "";
    }
    known = class_info(classname);
    if known is None or known.solid {
        return "";
    }
    # What a game's own rules spawn: its pickups, monsters and fixtures. A
    # player start, a light or a trigger is the same thing in every game.
    family = classname.split("_")[0];
    if "_" not in classname or family not in ["item", "weapon", "ammo", "monster", "misc", "trap", "key", "holdable", "team", "turret", "light"] {
        return "";
    }
    games = [each for each in known.games.split() if each in ["q1", "q2", "q3"]];
    if len(games) == 0 {
        return "";
    }
    project = self.project;
    if project is not None and project.game in games {
        return project.game;
    }
    return games[0];
}

impl Studio.game_findings(scene: Scene) -> list[Finding] {
    found: list[Finding] = [];
    if scene.game != "passion" {
        return found;
    }
    for item in scene.items() {
        kind = item.classname();
        carried = item.fields.get("asset_game", "");
        wanted_game = self.game_for(scene, kind);
        if not wanted_game {
            continue;
        }
        known = class_info(kind);
        if not carried {
            found.append(
                Finding(words=item.title() + " carries no game: it is spawned by no game's rules (ed_assetgame fill)", item=item)
            );
        } elif known is not None and carried not in known.games.split() {
            found.append(Finding(words=item.title() + " carries " + carried + ", a game that has no " + kind, item=item));
        }
    }
    return found;
}

impl Studio.draw_camps {
    # How far a bot camps from each camp spot, and where bots are told to roam.
    for shape in self.shapes {
        kind = shape.item.classname();
        if kind != "info_camp" and kind != "item_botroam" {
            continue;
        }
        at = shape.center();
        reach = 0.0;
        try {
            reach = float(shape.item.fields.get("range", "0"));
        } except ValueError {
            reach = 0.0;
        }
        tone = ink(0x3ddc97, 200) if kind == "info_camp" else ink(0x5b8def, 200);
        if reach <= 0.0 {
            reach = 24.0;
        }
        for i in range(24) {
            first = 2.0 * math.pi * float(i) / 24.0;
            second = 2.0 * math.pi * float(i + 1) / 24.0;
            wire_line(
                Vec3(x=at.x + reach * math.cos(first), y=at.y + reach * math.sin(first), z=at.z),
                Vec3(x=at.x + reach * math.cos(second), y=at.y + reach * math.sin(second), z=at.z),
                tone
            );
        }
    }
}

impl Studio.games_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    if name == "ed_camps" {
        count = 0;
        for item in scene.items() {
            if item.classname() == "info_camp" or item.classname() == "item_botroam" {
                print(
                    "studio: camp " + item.classname() + " origin=" + item.fields.get("origin", "").replace(" ", ",")
                        + " range=" + item.fields.get("range", "0") + " weight=" + item.fields.get("weight", "0")
                );
                count += 1;
            }
        }
        print("studio: camps " + str(count));
        self.say(
            str(count) + " spots for bots: a ring shows how far each is camped at"
            if count
            else "No camp spots: add an info_camp (range, weight) where a bot should wait, or an item_botroam to draw bots through"
        );
        return True;
    }
    if name != "ed_assetgame" {
        return False;
    }
    count = 0;
    if how == "fill" {
        # Every entity that needs a game and has none takes its class's.
        for item in scene.items() {
            needs = self.game_for(scene, item.classname());
            if needs and not item.fields.get("asset_game", "") {
                scene.select(item);
                if scene.set_fields({"asset_game": needs}, "Asset game") {
                    count += 1;
                }
            }
        }
        scene.clear_selection();
    } elif how in ["q1", "q2", "q3"] or how == "none" {
        chosen = scene.selection();
        if len(chosen) == 0 {
            self.say("Select the entities to give a game to");
            return True;
        }
        if scene.set_fields({"asset_game": None if how == "none" else how}, "Asset game") {
            count = len(chosen);
        }
    } else {
        self.say("ed_assetgame <q1|q2|q3|none|fill>: the game whose rules the selected entities are spawned by; fill gives every entity its class's");
        return True;
    }
    print("studio: asset games set=" + str(count));
    self.say("Gave " + str(count) + " entities a game" if count else "Nothing changed");
    return True;
}
