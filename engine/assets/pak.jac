"""Quake PAK archive reader — the front door for every original game asset.

A .pak is id Software's flat archive: a 12-byte header (magic "PACK", then
directory offset and length as little-endian i32), and a directory of 64-byte
entries (56-byte NUL-padded path, then data offset and size as i32). Parsing
is split from file I/O so the format core is testable on pure bytes; method
bodies live in impl/pak.impl.jac."""

import struct;


glob HEADER_SIZE: int = 12;
glob ENTRY_SIZE: int = 64;
glob NAME_SIZE: int = 56;


"""One file inside the archive, as recorded by its directory entry."""
obj PakEntry {
    has name: str,
        offset: int,
        size: int;
}


"""A parsed archive: the raw buffer plus its directory. Payloads are sliced
out of `data` on demand — a Quake-era pak fits comfortably in memory."""
obj PakArchive {
    has data: bytes = b"",
        entries: list[PakEntry] = [],
        index: dict[str, int] = {};

    def names() -> list[str];
    def has_file(name: str) -> bool;
    def read_file(name: str) -> bytes;
}


"""Directory names are 56 bytes, NUL-padded; the name ends at the first NUL."""
def _entry_name(raw: bytes) -> str;


"""Parse a PAK from bytes. Raises ValueError on a malformed archive:
bad magic, truncated header/directory, a directory length that is not a
whole number of entries, or an entry pointing outside the buffer."""
def parse_pak(data: bytes) -> PakArchive;


"""Read and parse a .pak file from disk."""
def open_pak(path: str) -> PakArchive;
