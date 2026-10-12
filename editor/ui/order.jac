"""The order of a list of names, changed by carrying one of them."""

"""The names with one of them moved to stand before another (at the end
when `before` is empty or not among them). A name that is not there is put
in; a name moved before itself stays where it is."""
def moved_before(names: list[str], name: str, before: str = "") -> list[str] {
    if name == before {
        return list(names) if name in names else list(names) + [name];
    }
    rest = [other for other in names if other != name];
    if before in rest {
        place = rest.index(before);
        return rest[:place] + [name] + rest[place:];
    }
    return rest + [name];
}
