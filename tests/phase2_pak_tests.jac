"""Phase 2 tests: the PAK archive reader, exercised on synthetic archives
built in memory — no id assets required, embedded NULs included on purpose."""

import os;
import struct;

import from engine.assets.pak {
    PakArchive, PakEntry, parse_pak, open_pak,
    HEADER_SIZE, ENTRY_SIZE, NAME_SIZE
}


"""Build a well-formed pak from parallel name/payload lists: payloads first
(directly after the header, like real paks), directory last. Parallel lists
rather than (name, payload) tuples: tuple destructuring and per-index tuple
element types are still unsupported on the na pathway (upstream issue)."""
def build_pak(names: list[str], payloads: list[bytes]) -> bytes {
    body = b"";
    dir_entries = b"";
    offset = HEADER_SIZE;
    for i in range(len(names)) {
        name_bytes = names[i].encode("utf-8");
        padded = name_bytes + bytes([0] * (NAME_SIZE - len(name_bytes)));
        dir_entries += padded + struct.pack("<ii", offset, len(payloads[i]));
        body += payloads[i];
        offset += len(payloads[i]);
    }
    header = b"PACK" + struct.pack("<ii", offset, len(dir_entries));
    return header + body + dir_entries;
}


test "parses a synthetic pak directory" {
    data = build_pak(
        ["gfx/palette.lmp", "maps/e1m1.bsp", "sound/misc/menu1.wav"],
        [b"\x00\x01\x02rgb", b"BSP\x00DATA", b"RIFFxxxx"],
    );
    pak = parse_pak(data);
    assert len(pak.entries) == 3;
    assert pak.names() == ["gfx/palette.lmp", "maps/e1m1.bsp", "sound/misc/menu1.wav"];
    assert pak.has_file("maps/e1m1.bsp");
    assert not pak.has_file("maps/e2m1.bsp");
}

test "payloads survive byte-exact, embedded NULs included" {
    data = build_pak(
        ["gfx/palette.lmp", "maps/e1m1.bsp"],
        [b"\x00\x01\x02rgb", b"BSP\x00DATA"],
    );
    pak = parse_pak(data);
    assert pak.read_file("gfx/palette.lmp") == b"\x00\x01\x02rgb";
    assert pak.read_file("maps/e1m1.bsp") == b"BSP\x00DATA";
    assert len(pak.read_file("maps/e1m1.bsp")) == 8;
}

test "empty payload and max-length name round-trip" {
    long_name = "x" * (NAME_SIZE - 4) + ".lmp";
    assert len(long_name) == NAME_SIZE;
    data = build_pak([long_name, "a"], [b"", b"1"]);
    pak = parse_pak(data);
    assert pak.has_file(long_name);
    assert pak.read_file(long_name) == b"";
    assert pak.read_file("a") == b"1";
}

test "missing file raises KeyError" {
    pak = parse_pak(build_pak(["a"], [b"1"]));
    raised = False;
    try {
        pak.read_file("nope");
    } except KeyError {
        raised = True;
    }
    assert raised;
}

test "bad magic raises ValueError" {
    data = b"ZIP!" + struct.pack("<ii", HEADER_SIZE, 0);
    raised = False;
    try {
        parse_pak(data);
    } except ValueError {
        raised = True;
    }
    assert raised;
}

test "truncated header raises ValueError" {
    raised = False;
    try {
        parse_pak(b"PACK\x0c");
    } except ValueError {
        raised = True;
    }
    assert raised;
}

test "directory out of bounds raises ValueError" {
    data = b"PACK" + struct.pack("<ii", 4096, ENTRY_SIZE);
    raised = False;
    try {
        parse_pak(data);
    } except ValueError {
        raised = True;
    }
    assert raised;
}

test "ragged directory length raises ValueError" {
    data = b"PACK" + struct.pack("<ii", HEADER_SIZE, 33);
    data += bytes([0] * 33);
    raised = False;
    try {
        parse_pak(data);
    } except ValueError {
        raised = True;
    }
    assert raised;
}

test "entry pointing outside the file raises ValueError" {
    name = b"a" + bytes([0] * (NAME_SIZE - 1));
    directory_entry = name + struct.pack("<ii", 4096, 8);
    data = b"PACK" + struct.pack("<ii", HEADER_SIZE, ENTRY_SIZE) + directory_entry;
    raised = False;
    try {
        parse_pak(data);
    } except ValueError {
        raised = True;
    }
    assert raised;
}

test "open_pak reads an archive from disk" {
    data = build_pak(["maps/e1m1.bsp"], [b"BSP\x00DATA"]);
    path = os.path.join(os.getenv("TMPDIR", "/tmp"), "qp_pak_test.pak");
    with open(path, "wb") as f {
        f.write(data);
    }
    pak = open_pak(path);
    assert pak.read_file("maps/e1m1.bsp") == b"BSP\x00DATA";
    os.remove(path);
}
