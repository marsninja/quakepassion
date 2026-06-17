"""Implementations for the PAK reader. Declarations live in pak.na.jac."""

glob PAK_ENTRY_SIZE: int = 64,
     PAK_NAME_LEN: int = 56;


impl Pak.lookup(name: str) -> PakEntry | None {
    key = name.lower();
    if key in self.index {
        return self.entries[self.index[key]];
    }
    return None;
}

impl Pak.contains(name: str) -> bool {
    return name.lower() in self.index;
}

impl Pak.read(name: str) -> bytes | None {
    e = self.lookup(name);
    if e is None {
        return None;
    }
    return self.reader.at(e.filepos, e.filelen);
}

impl Pak.count() -> int {
    return len(self.entries);
}


impl PakSet.mount(p: Pak) {
    self.paks.append(p);
}

impl PakSet.lookup(name: str) -> PakEntry | None {
    # search later mounts first so they shadow earlier ones
    i = len(self.paks) - 1;
    while i >= 0 {
        e = self.paks[i].lookup(name);
        if e is not None {
            return e;
        }
        i -= 1;
    }
    return None;
}

impl PakSet.read(name: str) -> bytes | None {
    i = len(self.paks) - 1;
    while i >= 0 {
        d = self.paks[i].read(name);
        if d is not None {
            return d;
        }
        i -= 1;
    }
    return None;
}


impl parse_pak(r: ByteReader) -> Pak | None {
    magic = r.take(4);
    if magic != b"PACK" {
        return None;
    }
    dirofs = r.u32();
    dirlen = r.u32();
    n = dirlen // PAK_ENTRY_SIZE;

    pak = Pak(reader=r);
    r.seek(dirofs);
    for i in range(n) {
        name = r.cstr(PAK_NAME_LEN);
        filepos = r.u32();
        filelen = r.u32();
        pak.entries.append(PakEntry(name=name, filepos=filepos, filelen=filelen));
        # later duplicate names overwrite earlier — last entry wins, as Quake does
        pak.index[name.lower()] = i;
    }
    return pak;
}

impl load_pak(path: str) -> Pak | None {
    return parse_pak(reader_from_file(path));
}
