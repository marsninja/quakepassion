"""Implementations for the PAK archive reader. Declarations live in pak.jac."""

impl PakArchive.names() -> list[str] {
    return [e.name for e in self.entries];
}

impl PakArchive.has_file(name: str) -> bool {
    return name.lower() in self.index;
}

impl PakArchive.read_file(name: str) -> bytes {
    key = name.lower();
    if key not in self.index {
        raise KeyError(f"no such file in pak: {name}");
    }
    pak_entry = self.entries[self.index[key]];
    return self.data[pak_entry.offset:pak_entry.offset + pak_entry.size];
}


impl _entry_name(raw: bytes) -> str {
    end = 0;
    while end < len(raw) and raw[end] != 0 {
        end += 1;
    }
    return raw[0:end].decode("utf-8");
}


impl parse_pak(data: bytes) -> PakArchive {
    if len(data) < HEADER_SIZE {
        raise ValueError(f"pak too small for header: {len(data)} bytes");
    }
    if data[0:4] != b"PACK" {
        raise ValueError("bad pak magic, expected b'PACK'");
    }
    header = struct.unpack("<ii", data[4:HEADER_SIZE]);
    dir_offset: int = header[0];
    dir_length: int = header[1];
    if dir_offset < 0 or dir_length < 0 or dir_offset + dir_length > len(data) {
        raise ValueError(
            f"pak directory out of bounds: offset={dir_offset} "
            f"length={dir_length} file={len(data)}"
        );
    }
    if dir_length % ENTRY_SIZE != 0 {
        raise ValueError(
            f"pak directory length {dir_length} is not a multiple of {ENTRY_SIZE}"
        );
    }

    pak = PakArchive(data=data);
    count = dir_length // ENTRY_SIZE;
    for i in range(count) {
        base = dir_offset + i * ENTRY_SIZE;
        name = _entry_name(data[base:base + NAME_SIZE]);
        loc = struct.unpack("<ii", data[base + NAME_SIZE:base + ENTRY_SIZE]);
        offset: int = loc[0];
        size: int = loc[1];
        if offset < 0 or size < 0 or offset + size > len(data) {
            raise ValueError(
                f"pak entry '{name}' out of bounds: offset={offset} "
                f"size={size} file={len(data)}"
            );
        }
        pak.index[name.lower()] = len(pak.entries);
        pak.entries.append(PakEntry(name=name, offset=offset, size=size));
    }
    return pak;
}


impl open_pak(path: str) -> PakArchive {
    with open(path, "rb") as f {
        data = f.read();
    }
    return parse_pak(data);
}
