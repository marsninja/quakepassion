"""A shelf of the library as rows: files kept in folders, each folder a
heading that opens and shuts; and the names such files go by."""

"""One row of a shelf: a folder's heading, or a file."""
obj ShelfRow {
    has key: str,
        text: str,
        depth: int = 1,
        folder: bool = False,
        opened: bool = False,
        count: int = 0;
}

"""A name with folders, made safe to keep a file under: no way up out of
the shelf, no empty parts, no backslashes. Empty when nothing is left."""
def shelf_name(name: str) -> str {
    parts: list[str] = [];
    for part in name.replace("\\", "/").split("/") {
        word = part.strip();
        if word and word != "." and word != ".." {
            parts.append(word);
        }
    }
    return "/".join(parts);
}

"""A name moved into a folder of the shelf ("" for the shelf itself): its
last part, under that folder."""
def shelf_moved(name: str, folder: str) -> str {
    last = shelf_name(name).split("/")[-1];
    into = shelf_name(folder);
    return (into + "/" + last) if into and last else last;
}

"""How many of the names lie under a folder, at any depth."""
def:priv shelf_count(names: list[str], folder: str) -> int {
    return len([name for name in names if name.startswith(folder + "/")]);
}

"""The rows under one folder of a shelf, added to `rows`: its folders, each
with what is in it when open, and then its files."""
def:priv shelf_under(
    names: list[str], folder: str, level: int, lead: str, heading: str, opened: dict[str, bool], rows: list[ShelfRow]
) {
    inside = folders_and_files(names, folder);
    for name in inside[0] {
        whole = (folder + "/" + name) if folder else name;
        shown = opened.get(heading + whole, False);
        rows.append(
            ShelfRow(key=heading + whole, text=name, depth=level, folder=True, opened=shown, count=shelf_count(names, whole))
        );
        if shown {
            shelf_under(names, whole, level + 1, lead, heading, opened, rows);
        }
    }
    for name in inside[1] {
        rows.append(ShelfRow(key=lead + ((folder + "/" + name) if folder else name), text=name, depth=level));
    }
}

"""The rows of a shelf whose files have these names (a path from the
shelf's own folder, without an ending): each folder a heading keyed
`heading` + its path, shut unless `opened` says otherwise, with what is in
it under it when open; each file keyed `lead` + its name. Folders come
before files, both in order."""
def shelf_rows(names: list[str], lead: str, heading: str, opened: dict[str, bool], depth: int = 1) -> list[ShelfRow] {
    rows: list[ShelfRow] = [];
    shelf_under(names, "", depth, lead, heading, opened, rows);
    return rows;
}

"""The folders and the files directly under a folder of the names."""
def folders_and_files(names: list[str], folder: str) -> tuple[list[str], list[str]] {
    lead = folder + "/" if folder else "";
    folders: list[str] = [];
    files: list[str] = [];
    for name in names {
        if not name.startswith(lead) or len(name) == len(lead) {
            continue;
        }
        rest = name[len(lead):];
        cut = rest.find("/");
        if cut < 0 {
            files.append(rest);
        } elif rest[:cut] not in folders {
            folders.append(rest[:cut]);
        }
    }
    return (sorted(folders), sorted(files));
}
