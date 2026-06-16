"""The byte foundation every binary parser builds on (Phase 2).

A `ByteReader` is a cursor over a length-aware `bytes` buffer. Quake's on-disk
formats are little-endian, so `struct` does the endian-correct int/float
reinterpretation and the cursor advances field-by-field. This is pure data
code — no OSP, no raylib; PAK and BSP parsers sit directly on top of it.

The native backend's length-aware `bytes` + `struct` + binary `open` (jaseci
#6727) are what make this expressible natively; the same source runs on @sv.

Method bodies live in impl/bytes.na.impl.jac."""

import struct;


obj ByteReader {
    has data: bytes,
        pos: int = 0;

    """Move the cursor to an absolute offset."""
    def seek(p: int);
    """Current cursor offset."""
    def tell() -> int;
    """Advance the cursor by n bytes."""
    def skip(n: int);
    """Bytes left between the cursor and the end."""
    def remaining() -> int;
    """Is the cursor at or past the end?"""
    def eof() -> bool;

    def u8() -> int;
    def u16() -> int;
    def u32() -> int;
    def i8() -> int;
    def i16() -> int;
    def i32() -> int;
    def f32() -> float;

    """Read n raw bytes at the cursor, advancing it."""
    def take(n: int) -> bytes;
    """Absolute byte slice [off, off+n) — does not move the cursor."""
    def at(off: int, n: int) -> bytes;
    """A fresh reader over an absolute sub-range — the natural way to hand a
    single BSP lump to a record loop without disturbing this cursor."""
    def subreader(off: int, n: int) -> ByteReader;
    """Read a fixed-width, NUL-padded name field (PAK entry names, etc.) and
    decode it up to the first NUL, advancing the cursor by the full width."""
    def cstr(n: int) -> str;
}


"""Read an entire binary file into a length-aware bytes buffer."""
def read_file(path: str) -> bytes;

"""Open a binary file as a ByteReader positioned at 0."""
def reader_from_file(path: str) -> ByteReader;
