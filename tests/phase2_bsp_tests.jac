"""BSP boundary and visibility tests; no proprietary assets needed."""
import struct;
import from engine.formats.q1.bsp { parse_bsp }
import from engine.formats.bsp { parse_entities, decode_pvs }

test "PVS bits address leaves starting at one" {
    assert decode_pvs(b"\x85", 0, 9) == [1, 3, 8];
}

test "PVS zero runs skip eight leaves per byte" {
    assert decode_pvs(b"\x00\x02\x01", 0, 18) == [17];
}

test "absent PVS exposes every non-solid leaf" {
    assert decode_pvs(b"", -1, 4) == [1, 2, 3];
}

test "truncated PVS rejects missing run length" {
    failed = False;
    try {
        decode_pvs(b"\x00", 0, 9);
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "zero length PVS runs cannot loop forever" {
    failed = False;
    try {
        decode_pvs(b"\x00\x00", 0, 9);
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "entity lump preserves player spawn fields" {
    entities = parse_entities(
        "{\n\"classname\" \"info_player_start\"\n\"origin\" \"12 -34 56\"\n}\x00"
    );
    assert len(entities) == 1;
    assert entities[0].fields["origin"] == "12 -34 56";
}

test "unsupported BSP versions reject before decoding" {
    failed = False;
    try {
        parse_bsp(struct.pack("<i", 30) + bytes(120));
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "truncated BSP header rejects" {
    failed = False;
    try {
        parse_bsp(b"\x1d\x00\x00\x00");
    } except ValueError {
        failed = True;
    }
    assert failed;
}
