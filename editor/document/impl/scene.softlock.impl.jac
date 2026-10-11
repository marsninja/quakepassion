"""The document's softlocks: where a map's logic can leave a player with no
way on. Declarations live in scene.jac."""

"""What fires once and never again: a trigger made for it, a monster's
death, a thing picked up, a button or trigger told to wait for ever."""
def:priv fires_once(item: Item) -> bool {
    kind = item.classname();
    if kind == "trigger_once" or kind.startswith("monster_") or kind.startswith("item_") or kind.startswith("weapon_")
        or kind.startswith("ammo_") or kind.startswith("key_") {
        return True;
    }
    return kind in ["func_button", "trigger_multiple"] and item.fields.get("wait", "").strip() in ["-1", "-1.0"];
}

def:priv whole_number(words: str, otherwise: int) -> int {
    try {
        return int(float(words.strip()));
    } except ValueError {
        return otherwise;
    }
}

def:priv listed(found: list[Item]) -> str {
    titles = [item.title() for item in found[:3]];
    return ", ".join(titles) + (" and " + str(len(found) - 3) + " more" if len(found) > 3 else "");
}

impl Scene.waits(item: Item) -> bool {
    kind = item.classname();
    if kind in ["trigger_relay", "trigger_counter", "path_corner", "info_notnull"] or kind.startswith("target_") {
        return True;
    }
    if not item.fields.get("targetname", "") {
        return False;
    }
    if kind == "func_timer" {
        # One that starts on runs from the first; any other waits to be started.
        return whole_number(item.fields.get("spawnflags", "0"), 0) % 2 == 0;
    }
    return kind.startswith("func_") and kind != "func_button";
}

impl Scene.woken -> list[Item] {
    self.links();
    found: list[Item] = [];
    for item in self.items() {
        if item.held and not self.waits(item) {
            traveller = item spawn Wake(woken=found);
            found = traveller.woken;
        }
    }
    return found;
}

impl Scene.softlocks -> list[Finding] {
    found: list[Finding] = [];
    live = self.woken();
    members = [item for item in self.items() if item.held];
    kinds = [item.classname() for item in members];
    for item in members {
        kind = item.classname();
        firers = [other for other in [item<-:Fires:key == "target":<-] if other.held];
        if self.waits(item) and len(firers) > 0 and item not in live {
            found.append(
                Finding(
                    words=item.title() + " is never set off: what fires it (" + listed(firers) + ") is never set off itself",
                    item=item
                )
            );
        }
        if kind == "trigger_counter" and item in live {
            wanted = max(1, whole_number(item.fields.get("count", "2"), 2));
            able = [other for other in firers if other in live];
            if len([other for other in able if not fires_once(other)]) == 0 and len(able) < wanted {
                found.append(
                    Finding(
                        words=item.title() + " counts to " + str(wanted) + ", and only " + str(len(able))
                            + (" thing ever fires it, once" if len(able) == 1 else " things ever fire it, once each"),
                        item=item
                    )
                );
            }
        }
        if self.game == "q1" and kind == "func_door" {
            flags = whole_number(item.fields.get("spawnflags", "0"), 0);
            for (bit, colour, key) in [(8, "gold", "item_key2"), (16, "silver", "item_key1")] {
                if (flags // bit) % 2 == 1 and key not in kinds {
                    found.append(
                        Finding(words=item.title() + " wants the " + colour + " key, and the level has none (" + key + ")", item=item)
                    );
                }
            }
        }
        wanted_key = item.fields.get("item", "");
        if kind == "trigger_key" and wanted_key and wanted_key not in kinds {
            found.append(
                Finding(
                    words=item.title() + " wants " + wanted_key + ", and this level has none (unless it is carried in from another)",
                    item=item
                )
            );
        }
    }
    return found;
}
