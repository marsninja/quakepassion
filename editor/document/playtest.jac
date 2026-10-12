"""What a level asks of whoever plays it, in the order they would come to
it: the keys, then what opens the way (buttons, and triggers that fire
something), then the way out. The playtest of an authored scene goes down
this list and says the first that cannot be reached."""

"""Whether a class is a key to be picked up."""
def is_key_class(classname: str) -> bool {
    return classname.startswith("key_") or classname.startswith("item_key") or classname == "item_sigil"
        or classname.startswith("item_runekey");
}

"""Whether a class ends the level."""
def is_exit_class(classname: str) -> bool {
    return classname in ["trigger_changelevel", "target_changelevel", "trigger_exit", "target_exit"];
}

"""The objectives among a level's entities, each by its place in the list
and what it is called: keys first, then buttons and the triggers that fire
something, then the ways out. Within a kind, in the order the level has
them."""
def objectives(entities: list[dict[str, str]]) -> list[tuple[int, str]] {
    keys: list[tuple[int, str]] = [];
    openers: list[tuple[int, str]] = [];
    exits: list[tuple[int, str]] = [];
    for (index, fields) in enumerate(entities) {
        kind = fields.get("classname", "");
        called = kind + (" " + fields["targetname"] if fields.get("targetname", "") else "");
        if is_key_class(kind) {
            keys.append((index, "the key " + called));
        } elif is_exit_class(kind) {
            exits.append((index, "the way out (" + called + ")"));
        } elif kind == "func_button" or (kind.startswith("trigger_") and fields.get("target", "") and kind != "trigger_relay") {
            openers.append((index, called + ", which fires " + fields.get("target", "nothing")));
        }
    }
    return keys + openers + exits;
}
