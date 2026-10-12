"""What an entity needs that is not there: a class its game has, and the
sounds and models its fields name. Declarations live in studio.jac."""

impl Studio.need_findings(scene: Scene) -> list[Finding] {
    found: list[Finding] = [];
    shelf = self.archive;
    listing = self.asset_index;
    if listing is None and shelf is not None {
        listing = AssetIndex(shelf=shelf);
        self.asset_index = listing;
    }
    held: dict[str, set[str]] = {};
    for item in scene.items() {
        kind = item.classname();
        if not kind {
            continue;
        }
        # A scene of the studio's own is no one game's: each entity carries its own.
        game = scene.game if scene.game in ["q1", "q2", "q3"] else item.fields.get("asset_game", "");
        known = class_info(kind);
        if known is None {
            found.append(Finding(words=item.title() + " is of a class no game's levels use and no add-on names (misspelt?)", item=item));
        } elif scene.game in ["q1", "q2", "q3"] and known.games and scene.game not in known.games.split() {
            found.append(
                Finding(
                    words=item.title() + " is of a class " + scene.game + " does not have (it is of " + " and ".join(known.games.split()) + ")",
                    item=item
                )
            );
        }
        if listing is None or game not in ["q1", "q2", "q3"] {
            continue;
        }
        needs = needed_files(game, item.fields);
        if kind == "misc_model" and not self.is_built_scene() {
            # A shipped level's own: the level compiler built them into it, and the files were left out.
            needs = [need for need in needs if need[0] != "model"];
        }
        if len(needs) == 0 {
            continue;
        }
        if game not in held {
            held[game] = held_names(listing.names(game));
        }
        if len(held[game]) == 0 {
            # That game's archives are not here to ask.
            continue;
        }
        for (key, file) in missing_files(needs, held[game]) {
            what = "model" if key.startswith("model") else "sound";
            found.append(Finding(words=item.title() + " names a " + what + " no archive of " + game + " holds: " + file, item=item));
        }
    }
    return found;
}
