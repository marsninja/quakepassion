"""A Quake II wall texture's own facts. A WAL file begins with its name,
its size, where its four sizes of picture are, the name of the texture that
follows it in an animation, and three numbers a map compiler gives every
face that uses it unless the face says otherwise: its surface flags, its
contents and its value (how much light it sheds). Those are read here, and
written back into the file without touching its pictures."""
import struct;

"""What a WAL says of itself."""
obj WalFacts {
    has name: str = "",
        width: int = 0,
        height: int = 0,
        # The texture shown after this one, when it is one of a chain.
        next_name: str = "",
        flags: int = 0,
        contents: int = 0,
        value: int = 0;
}

"""A name kept in so many bytes, up to its first nothing."""
def:priv held_name(data: bytes, at: int, size: int) -> str {
    end = at;
    while end < at + size and data[end] != 0 {
        end += 1;
    }
    return data[at:end].decode("utf-8", "replace");
}

"""What a surface flag's bit is called."""
glob SURFACE_FLAGS: list[str] = ["light", "slick", "sky", "warp", "trans33", "trans66", "flowing", "nodraw"];

"""Read a WAL's facts, or none when the bytes are too few to be one."""
def wal_facts(data: bytes) -> WalFacts | None {
    if len(data) < 100 {
        return None;
    }
    found = WalFacts(name=held_name(data, 0, 32), next_name=held_name(data, 56, 32));
    found.width = int(struct.unpack("<I", data[32:36])[0]);
    found.height = int(struct.unpack("<I", data[36:40])[0]);
    found.flags = int(struct.unpack("<i", data[88:92])[0]);
    found.contents = int(struct.unpack("<i", data[92:96])[0]);
    found.value = int(struct.unpack("<i", data[96:100])[0]);
    if found.width < 1 or found.height < 1 or found.width > 4096 or found.height > 4096 {
        return None;
    }
    return found;
}

"""The file with other facts: its flags, contents, value and the texture
that follows it. Its name, size and pictures are as they were. Empty when
the bytes are not a WAL."""
def wal_with(data: bytes, flags: int, contents: int, value: int, next_name: str) -> bytes {
    if wal_facts(data) is None {
        return b"";
    }
    follows = next_name.encode("utf-8")[:31];
    out = bytearray(data);
    for index in range(32) {
        out[56 + index] = follows[index] if index < len(follows) else 0;
    }
    packed = struct.pack("<iii", flags, contents, value);
    for index in range(12) {
        out[88 + index] = packed[index];
    }
    return bytes(out);
}

"""The names of the flags set in a number, in the order of their bits."""
def flag_names(flags: int) -> list[str] {
    return [SURFACE_FLAGS[bit] for bit in range(len(SURFACE_FLAGS)) if flags & (1 << bit) != 0];
}

"""A number with a flag set or cleared by name; the number as it was when
the name is none of them."""
def flag_named(flags: int, name: str, on: bool) -> int {
    for bit in range(len(SURFACE_FLAGS)) {
        if SURFACE_FLAGS[bit] == name.lower() {
            return (flags | (1 << bit)) if on else (flags & ~(1 << bit));
        }
    }
    return flags;
}

"""The frames of a Quake texture that is one of an animation: a name that
begins with + and a digit (or a letter from a to j, the frames shown while
its button is pressed) is followed by the others of its row that the names
given hold, in order. One name alone when it is not animated."""
def quake_frames(names: list[str], name: str) -> list[str] {
    tail = name.split("/")[-1];
    if len(tail) < 3 or tail[0] != "+" {
        return [name];
    }
    lead = name[:len(name) - len(tail)];
    row = "0123456789" if tail[1].isdigit() else "abcdefghij";
    if tail[1].lower() not in row {
        return [name];
    }
    found: list[str] = [];
    for mark in row {
        for other in names {
            if other.lower() == (lead + "+" + mark + tail[2:]).lower() {
                found.append(other);
            }
        }
    }
    return found if len(found) > 0 else [name];
}
