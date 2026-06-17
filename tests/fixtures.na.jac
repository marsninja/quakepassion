"""Synthetic binary fixtures for Phase 2 parser tests.

Builds PAK/BSP byte buffers in memory from records (struct.pack + concat), so
parser tests run on known-answer data with no committed binaries and no real
Quake game files. This is exactly the in-Jac fixture construction the native
length-aware bytes + struct work (jaseci #6727/#6745/#6749) unblocked.

Test support, not engine code — kept as plain functions (no impl annex)."""

import struct;


"""Encode a name into a fixed-width, NUL-padded byte field (truncating if the
name is too long), matching how PAK stores its 56-byte path entries."""
def padname(name: str, width: int) -> bytes {
    raw = name.encode("utf-8");
    if len(raw) >= width {
        return raw[0:width];
    }
    return raw + b"\x00" * (width - len(raw));
}


"""One file to embed in a synthetic pak: a logical path and its raw bytes."""
obj PakFile {
    has name: str,
        data: bytes;
}


"""Assemble a valid PAK archive buffer: a 12-byte header (PACK magic + directory
offset/length), then 64-byte directory entries, then the concatenated payloads.
Directory and payloads are laid out exactly where the header advertises."""
def build_pak(files: list[PakFile]) -> bytes {
    name_len = 56;
    entry_size = 64;
    header_size = 12;
    dir_size = len(files) * entry_size;

    directory = b"";
    payloads = b"";
    pos = header_size + dir_size;        # first payload sits after the directory
    for f in files {
        directory = directory + padname(f.name, name_len) + struct.pack("<ii", pos, len(f.data));
        payloads = payloads + f.data;
        pos = pos + len(f.data);
    }

    return b"PACK" + struct.pack("<ii", header_size, dir_size) + directory + payloads;
}
