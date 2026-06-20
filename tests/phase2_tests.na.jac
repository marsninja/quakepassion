"""Phase 2 tests: the binary foundation, exercised with zero graphics —
constructed byte buffers in, known values out. Mirrors Phase 1's discipline
of testing the data/graph logic without a window."""

import from formats.common.bytes { ByteReader }
import from formats.common.pak { Pak, PakSet, PakEntry, parse_pak }
import from formats.q1.bsp { Bsp, parse_bsp }
import from formats.q1.pvs { vis_row_bytes, decompress_vis, vis_bit }
import from tests.fixtures { PakFile, build_pak, build_bsp }


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


test "pak parses its directory, looks up case-insensitively, and reads payloads" {
    p = parse_pak(ByteReader(data=build_pak([
        PakFile(name="sound/door.wav", data=b"AAA"),
        PakFile(name="MAPS/E1M1.BSP", data=b"BSPDATA")   # stored uppercase
    ])));
    assert p is not None;
    assert p.count() == 2;

    e = p.lookup("sound/door.wav");
    assert e is not None;
    assert e.filelen == 3;

    assert p.read("sound/door.wav") == b"AAA";
    assert p.read("maps/e1m1.bsp") == b"BSPDATA";    # case-insensitive lookup
    assert p.contains("MAPS/e1m1.bsp");

    assert p.lookup("nope.txt") is None;
    assert p.read("nope.txt") is None;
    assert not p.contains("nope.txt");
}


test "pak rejects a buffer without the PACK magic" {
    assert parse_pak(ByteReader(data=b"NOPE\x00\x00\x00\x00\x00\x00\x00\x00")) is None;
}


test "pakset: later mounts shadow earlier ones" {
    pak0 = parse_pak(ByteReader(data=build_pak([
        PakFile(name="gfx/conback.lmp", data=b"OLD"),
        PakFile(name="only0.txt", data=b"zero")
    ])));
    pak1 = parse_pak(ByteReader(data=build_pak([
        PakFile(name="gfx/conback.lmp", data=b"NEW")     # overrides pak0
    ])));
    assert pak0 is not None;
    assert pak1 is not None;

    ps = PakSet();
    ps.mount(pak0);
    ps.mount(pak1);
    assert ps.read("gfx/conback.lmp") == b"NEW";         # later mount wins
    assert ps.read("only0.txt") == b"zero";              # only in earlier pak
    assert ps.read("ghost") is None;                     # absent everywhere
}


test "bsp29 parses every lump and resolves a face polygon" {
    bsp = parse_bsp(build_bsp());
    assert bsp is not None;
    assert bsp.version == 29;

    assert len(bsp.planes) == 1;
    assert abs(bsp.planes[0].normal.z - 1.0) < 0.0001;
    assert len(bsp.vertices) == 3;
    assert abs(bsp.vertices[1].x - 64.0) < 0.0001;
    assert len(bsp.edges) == 3;
    assert bsp.edges[1].v0 == 1 and bsp.edges[1].v1 == 2;
    assert len(bsp.surfedges) == 3;
    assert len(bsp.faces) == 1;
    assert bsp.faces[0].num_edges == 3;
    assert bsp.faces[0].lightmap_ofs == -1;

    assert len(bsp.nodes) == 1;
    assert bsp.nodes[0].back == -2;                      # signed i16 child link
    assert len(bsp.leafs) == 2;
    assert bsp.leafs[0].contents == -2;                 # solid
    assert bsp.leafs[1].contents == -1;                 # empty
    assert len(bsp.marksurfaces) == 1;
    assert len(bsp.models) == 1;
    assert abs(bsp.models[0].maxs.z - 128.0) < 0.0001;
    assert len(bsp.visdata) == 1;
    assert "worldspawn" in bsp.entities;

    # the face's polygon, walked through surfedges + edges (z-up, no swizzle)
    fv = bsp.face_verts(0);
    assert len(fv) == 3;
    assert abs(fv[0].x - 0.0) < 0.0001 and abs(fv[1].x - 64.0) < 0.0001;
    assert abs(fv[2].y - 64.0) < 0.0001;
}


test "bsp29 rejects a non-29 version" {
    assert parse_bsp(b"\x1c\x00\x00\x00") is None;       # version 28
}


test "pvs rle decompress and bit test" {
    # 0x05 literal, then a zero-run of 3 (00 03), then 0xff literal
    row = decompress_vis(b"\x05\x00\x03\xff", 0, 5);
    assert len(row) == 5;
    assert row[0] == 5;
    assert row[1] == 0 and row[2] == 0 and row[3] == 0;
    assert row[4] == 255;

    assert vis_bit(row, 0);          # 0x05 -> bits 0 and 2 set
    assert not vis_bit(row, 1);
    assert vis_bit(row, 2);
    assert vis_bit(row, 32);         # 0xff at byte 4 -> bits 32..39 set
    assert vis_bit(row, 39);
    assert not vis_bit(row, 40);     # past the row -> not visible

    assert vis_row_bytes(8) == 1;
    assert vis_row_bytes(9) == 2;    # ceil(9 / 8)
}
