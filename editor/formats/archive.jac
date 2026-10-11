"""Archives written: Quake's PAK and Quake III's PK3 (a zip), and the
folders inside a list of file names. The readers are the engine's own; what
is written here they read back."""
import os;
import struct;
import from zipfile { ZipFile }
import from engine.assets.pak { parse_pak }
import from engine.formats.q1.wad { wad_lumps }

"""The bytes of a PAK holding `files` (name, contents), in that order. A
name longer than a PAK allows (55 bytes) raises ValueError."""
def write_pak(files: list[tuple[str, bytes]]) -> bytes {
    body = bytearray();
    directory = bytearray();
    offset = 12;
    for (name, data) in files {
        raw = name.encode("utf-8");
        if len(raw) > 55 {
            raise ValueError("A PAK name is at most 55 bytes: " + name);
        }
        body.extend(data);
        directory.extend(raw);
        directory.extend(bytes(56 - len(raw)));
        directory.extend(struct.pack("<ii", offset, len(data)));
        offset += len(data);
    }
    head = bytearray(b"PACK");
    head.extend(struct.pack("<ii", offset, len(directory)));
    head.extend(body);
    head.extend(directory);
    return bytes(head);
}

"""The table the checksum below is taken from."""
def:priv crc_table -> list[int] {
    table: list[int] = [];
    for n in range(256) {
        c = n;
        for k in range(8) {
            if c & 1 {
                c = 0xEDB88320 ^ (c >> 1);
            } else {
                c = c >> 1;
            }
        }
        table.append(c);
    }
    return table;
}

"""The CRC-32 of some bytes, as a zip records it."""
def crc32_of(data: bytes) -> int {
    table = crc_table();
    c = 0xFFFFFFFF;
    for value in data {
        c = table[(c ^ value) & 0xFF] ^ (c >> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

"""The bytes of a zip (a PK3) holding `files` (name, contents), stored
without compression: every reader takes that, and a level's own files are
small beside the textures it shares with the game."""
def write_zip(files: list[tuple[str, bytes]]) -> bytes {
    body = bytearray();
    central = bytearray();
    for (name, data) in files {
        raw = name.encode("utf-8");
        check = crc32_of(data);
        offset = len(body);
        # A local header: signature, version, flags, method, time, date,
        # checksum, sizes, name and extra lengths.
        body.extend(b"PK\x03\x04");
        body.extend(struct.pack("<HHHHH", 20, 0, 0, 0, 33));
        body.extend(struct.pack("<I", check));
        body.extend(struct.pack("<II", len(data), len(data)));
        body.extend(struct.pack("<HH", len(raw), 0));
        body.extend(raw);
        body.extend(data);
        central.extend(b"PK\x01\x02");
        central.extend(struct.pack("<HHHHHH", 20, 20, 0, 0, 0, 33));
        central.extend(struct.pack("<I", check));
        central.extend(struct.pack("<II", len(data), len(data)));
        central.extend(struct.pack("<HHHHH", len(raw), 0, 0, 0, 0));
        central.extend(struct.pack("<II", 0, offset));
        central.extend(raw);
    }
    count = len(files);
    tail = bytearray(b"PK\x05\x06");
    tail.extend(struct.pack("<HHHH", 0, 0, count, count));
    tail.extend(struct.pack("<II", len(central), len(body)));
    tail.extend(struct.pack("<H", 0));
    body.extend(central);
    body.extend(tail);
    return bytes(body);
}

"""What lies directly inside a folder ("" is the top) among file names with
`/` between their parts: its folders and its files, each sorted."""
def folder_children(names: list[str], folder: str) -> tuple[list[str], list[str]] {
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

"""What kind of thing a file is, by its name: "image", "text", "sound",
"model", "map" or "other"."""
def file_kind(name: str) -> str {
    low = name.lower();
    dot = low.rfind(".");
    ending = low[dot + 1:] if dot >= 0 else "";
    if ending in ["wal", "tga", "jpg", "jpeg", "pcx", "png", "lmp"] {
        return "image";
    }
    if ending in ["cfg", "txt", "shader", "arena", "bot", "skin", "menu", "rc", "lst", "def", "c", "h", "map", "ent", "script", "str"] {
        return "text";
    }
    if ending in ["wav"] {
        return "sound";
    }
    if ending in ["mdl", "md2", "md3", "spr", "sp2"] {
        return "model";
    }
    if ending in ["bsp", "aas"] {
        return "map";
    }
    return "other";
}

"""The files a PAK's bytes hold, in the order its directory has them."""
def pak_files(data: bytes) -> list[tuple[str, bytes]] {
    archive = parse_pak(data);
    found: list[tuple[str, bytes]] = [];
    for record in archive.entries {
        found.append((record.name, archive.data[record.offset:record.offset + record.size]));
    }
    return found;
}

"""The files a zip (a PK3) on disk holds, in its own order; folders it
lists as entries of their own are left out."""
def zip_files(path: str) -> list[tuple[str, bytes]] {
    found: list[tuple[str, bytes]] = [];
    archive = ZipFile(path);
    for name in archive.namelist() {
        if not name.endswith("/") {
            found.append((name, archive.read(name)));
        }
    }
    archive.close();
    return found;
}

"""A name as the games look files up: `/` between its parts, no case."""
def:priv packed_name(name: str) -> str {
    return name.replace("\\", "/").strip("/").lower();
}

"""An archive's files with one put in: in place of the file of that name
(the games find files without regard to case), or after the rest."""
def files_with(files: list[tuple[str, bytes]], name: str, data: bytes) -> list[tuple[str, bytes]] {
    wanted = packed_name(name);
    made: list[tuple[str, bytes]] = [];
    placed = False;
    for (held, contents) in files {
        if packed_name(held) == wanted {
            made.append((held, data));
            placed = True;
        } else {
            made.append((held, contents));
        }
    }
    if not placed {
        made.append((name.replace("\\", "/").strip("/"), data));
    }
    return made;
}

"""An archive's files without one, or without a whole folder (a name
ending in `/`): what is left, in order."""
def files_without(files: list[tuple[str, bytes]], name: str) -> list[tuple[str, bytes]] {
    wanted = packed_name(name);
    folder = name.replace("\\", "/").endswith("/");
    made: list[tuple[str, bytes]] = [];
    for (held, contents) in files {
        low = packed_name(held);
        if low == wanted or (folder and low.startswith(wanted + "/")) {
            continue;
        }
        made.append((held, contents));
    }
    return made;
}

"""The name of the WAD a file inside one belongs to and the lump's own
name ("gfx.wad/sbar" is the lump `sbar` of `gfx.wad`), or none for a name
that is not inside a WAD."""
def wad_member(name: str) -> tuple[str, str] | None {
    cut = name.lower().find(".wad/");
    if cut < 0 or cut + 5 >= len(name) {
        return None;
    }
    return (name[:cut + 4], name[cut + 5:]);
}

"""A WAD's lumps as files inside it: each lump's name after the WAD's own."""
def wad_names(wad: str, data: bytes) -> list[str] {
    try {
        return [wad + "/" + lump.name for lump in wad_lumps(data) if lump.name];
    } except ValueError {
        return [];
    }
}

"""One lump of a WAD: its bytes and its kind (66 is a picture with its
size before it), or none when the WAD has no lump of that name."""
def wad_lump(data: bytes, name: str) -> tuple[bytes, int] | None {
    try {
        for lump in wad_lumps(data) {
            if lump.name == name.lower() {
                return (data[lump.offset:lump.offset + lump.size], lump.kind);
            }
        }
    } except ValueError {
        return None;
    }
    return None;
}

"""Whether a file lies directly in one of some folders, however either is
written (a link, a path from here or from the root)."""
def lies_in(path: str, folders: list[str]) -> bool {
    home = os.path.dirname(os.path.realpath(path));
    for folder in folders {
        if folder and os.path.realpath(folder) == home {
            return True;
        }
    }
    return False;
}
