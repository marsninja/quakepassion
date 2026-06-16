"""Implementations for the ByteReader and file helpers. Declarations (and the
`struct` import) live in bytes.na.jac."""

impl ByteReader.seek(p: int) {
    self.pos = p;
}

impl ByteReader.tell() -> int {
    return self.pos;
}

impl ByteReader.skip(n: int) {
    self.pos += n;
}

impl ByteReader.remaining() -> int {
    return len(self.data) - self.pos;
}

impl ByteReader.eof() -> bool {
    return self.pos >= len(self.data);
}

impl ByteReader.u8() -> int {
    v = struct.unpack("<B", self.data[self.pos:self.pos + 1])[0];
    self.pos += 1;
    return v;
}

impl ByteReader.u16() -> int {
    v = struct.unpack("<H", self.data[self.pos:self.pos + 2])[0];
    self.pos += 2;
    return v;
}

impl ByteReader.u32() -> int {
    v = struct.unpack("<I", self.data[self.pos:self.pos + 4])[0];
    self.pos += 4;
    return v;
}

impl ByteReader.i8() -> int {
    v = struct.unpack("<b", self.data[self.pos:self.pos + 1])[0];
    self.pos += 1;
    return v;
}

impl ByteReader.i16() -> int {
    v = struct.unpack("<h", self.data[self.pos:self.pos + 2])[0];
    self.pos += 2;
    return v;
}

impl ByteReader.i32() -> int {
    v = struct.unpack("<i", self.data[self.pos:self.pos + 4])[0];
    self.pos += 4;
    return v;
}

impl ByteReader.f32() -> float {
    v = struct.unpack("<f", self.data[self.pos:self.pos + 4])[0];
    self.pos += 4;
    return v;
}

impl ByteReader.take(n: int) -> bytes {
    s = self.data[self.pos:self.pos + n];
    self.pos += n;
    return s;
}

impl ByteReader.at(off: int, n: int) -> bytes {
    return self.data[off:off + n];
}

impl ByteReader.subreader(off: int, n: int) -> ByteReader {
    return ByteReader(data=self.data[off:off + n]);
}

impl ByteReader.cstr(n: int) -> str {
    raw = self.data[self.pos:self.pos + n];
    self.pos += n;
    end = 0;
    while end < len(raw) and raw[end] != 0 {
        end += 1;
    }
    return raw[0:end].decode("utf-8");
}


impl read_file(path: str) -> bytes {
    f = open(path, "rb");
    d = f.read();
    f.close();
    return d;
}

impl reader_from_file(path: str) -> ByteReader {
    return ByteReader(data=read_file(path));
}
