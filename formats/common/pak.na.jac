"""PAK archive reader (Phase 2).

Quake ships its assets in `.pak` archives: a 12-byte header (`PACK` magic +
directory offset/length), then a flat directory of 64-byte entries — a
56-byte NUL-padded path plus the file's offset and length. Paths are stored
with forward slashes and are matched case-insensitively.

Real games mount several paks (`pak0.pak`, then `pak1.pak`, …) where later
mounts shadow earlier ones; a `PakSet` models that override stack. This is
pure data code over a ByteReader — no OSP, no raylib.

Method/function bodies live in impl/pak.na.impl.jac."""

import from .bytes { ByteReader, reader_from_file }


"""One directory entry: a logical path and where its bytes live in the pak."""
obj PakEntry {
    has name: str,
        filepos: int,
        filelen: int;
}


"""A single mounted pak: the buffer plus its directory and a lowercased-name
index for case-insensitive lookup."""
obj Pak {
    has reader: ByteReader,
        entries: list[PakEntry] = [],
        index: dict[str, int] = {};

    """Directory entry for a path, or None if absent (case-insensitive)."""
    def lookup(name: str) -> PakEntry | None;
    """Is a path present (case-insensitive)?"""
    def contains(name: str) -> bool;
    """Extract a file's raw bytes, or None if the path is absent."""
    def read(name: str) -> bytes | None;
    """Number of directory entries."""
    def count() -> int;
}


"""A stack of mounted paks. Later mounts win, exactly like Quake loading
`pak0` then `pak1`: a file present in both resolves to the later one."""
obj PakSet {
    has paks: list[Pak] = [];

    def mount(p: Pak);
    def lookup(name: str) -> PakEntry | None;
    def read(name: str) -> bytes | None;
}


"""Parse a pak from an open ByteReader. Returns None if the magic isn't PACK."""
def parse_pak(r: ByteReader) -> Pak | None;

"""Load and parse a pak file from disk. Returns None if the magic isn't PACK."""
def load_pak(path: str) -> Pak | None;
