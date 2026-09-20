"""Minimal BSP29 fixtures test collision lump validation without game assets."""
import struct;
import from engine.formats.q1.bsp { parse_bsp }

def collision_bsp(clip: bytes, head: int = 0) -> bytes {
    lumps: list[bytes] = [];
    for i in range(15) {
        lumps.append(b"");
    }
    lumps[1] = struct.pack("<4fi", 0.0, 0.0, 1.0, 0.0, 2);
    lumps[2] = struct.pack("<i", 0);
    lumps[5] = struct.pack("<i2h6h2H", 0, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0);
    lumps[9] = clip;
    lumps[10] = struct.pack("<ii6h2H4B", -2, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    lumps[14] = struct.pack(
        "<9f7i", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, head, -1, -1, 0, 0, 0
    );
    header = struct.pack("<i", 29);
    payload = b"";
    for lump in lumps {
        header += struct.pack("<ii", 124 + len(payload), len(lump));
        payload += lump;
    }
    return header + payload;
}

test "Q1 standing hull uses model head one and signed contents" {
    bsp = parse_bsp(collision_bsp(struct.pack("<i2h", 0, -1, -2)));
    assert bsp.models[0].player_hull == 0;
    assert len(bsp.clipnodes) == 1;
    assert bsp.clipnodes[0].front == -1 and bsp.clipnodes[0].back == -2;
}

test "Q1 invalid collision plane child and truncated records reject" {
    for clip in [
        struct.pack("<i2h", 1, -1, -2),
        struct.pack("<i2h", 0, 1, -2),
        b"\x00"
    ] {
        failed = False;
        try {
            parse_bsp(collision_bsp(clip));
        } except ValueError {
            failed = True;
        }
        assert failed;
    }
}

test "Q1 out of range standing hull root rejects" {
    failed = False;
    try {
        parse_bsp(collision_bsp(struct.pack("<i2h", 0, -1, -2), 4));
    } except ValueError {
        failed = True;
    }
    assert failed;
}
