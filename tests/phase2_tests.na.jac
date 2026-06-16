"""Phase 2 tests: the binary foundation, exercised with zero graphics —
constructed byte buffers in, known values out. Mirrors Phase 1's discipline
of testing the data/graph logic without a window."""

import from formats.common.bytes { ByteReader }


test "byte reader reads little-endian fields in sequence" {
    # u32=1 | u32=258 | i16=-2 | f32=1.5 | name(6)="AB"
    r = ByteReader(
        data=b"\x01\x00\x00\x00\x02\x01\x00\x00\xfe\xff\x00\x00\xc0\x3f\x41\x42\x00\x00\x00\x00"
    );
    assert r.u32() == 1;
    assert r.u32() == 258;
    assert r.i16() == -2;
    assert abs(r.f32() - 1.5) < 0.0001;
    assert r.cstr(6) == "AB";
    assert r.tell() == 20;
    assert r.eof();
}


test "byte reader subreader is independent and absolute slice is non-advancing" {
    r = ByteReader(data=b"\x00\x00\x00\x00\x07\x00\x09\x00");
    sub = r.subreader(4, 4);          # bytes [4,8) = 07 00 09 00
    assert sub.u16() == 7;
    assert sub.u16() == 9;
    assert sub.eof();
    assert r.tell() == 0;             # parent cursor untouched by subreader
    chunk = r.at(4, 2);               # 07 00
    assert chunk[0] == 7;
    assert r.tell() == 0;             # at() does not move the cursor
}


test "byte reader cursor ops: skip, take, seek, remaining" {
    r = ByteReader(data=b"ABCDEFGH");
    assert r.remaining() == 8;
    r.skip(2);
    assert r.tell() == 2;
    assert r.take(2) == b"CD";
    r.seek(7);
    assert r.u8() == 72;              # 'H'
    assert r.eof();
}


test "byte reader covers signed and unsigned widths" {
    r = ByteReader(data=b"\xff\xff\xff\x7f\xff\xff");
    assert r.u8() == 255;
    assert r.i8() == -1;
    assert r.u16() == 32767;          # 0x7fff
    assert r.i16() == -1;             # 0xffff
}
