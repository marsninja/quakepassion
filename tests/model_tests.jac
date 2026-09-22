import struct;
import from engine.formats.q2.model { parse_md2, parse_pcx }
import from engine.formats.animated { pose }

# A single triangle, separate UV indices, and two differently transformed frames.
def md2_fixture() -> bytes {
    header = b"IDP2"
        + struct.pack(
            "<16i", 8, 8, 8, 52, 1, 3, 3, 1, 0, 2, 68, 132, 144, 156, 260, 260
        );
    skin = b"skin.pcx" + bytes(56);
    coords = struct.pack("<6h", 0, 0, 7, 0, 0, 7);
    triangle = struct.pack("<6H", 0, 1, 2, 2, 0, 1);
    points = bytes([0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0]);
    first = struct.pack("<6f", 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
        + b"first"
        + bytes(11)
        + points;
    second = struct.pack("<6f", 2.0, 2.0, 2.0, 10.0, 0.0, 0.0)
        + b"second"
        + bytes(10)
        + points;
    return header + skin + coords + triangle + first + second;
}

test "MD2 frames interpolate and UV indices preserve seams" {
    model = parse_md2(md2_fixture());
    mesh = model.surfaces[0];
    assert mesh.skins == ["skin.pcx"] and len(mesh.frames) == 2;
    assert mesh.frames[1].name == "second";
    assert mesh.indices == [0, 1, 2];
    assert mesh.uv[1] == 7.5 / 8.0;
    vertices = pose(mesh, 0, 1, 0.5);
    assert vertices[1].x == 8.0 and vertices[2].y == 3.0;
}

test "MD2 rejects bad indices and truncated frame tables" {
    original = md2_fixture();
    for data in [
        original[:144] + struct.pack("<H", 3) + original[146:],
        original[:-1]
    ] {
        failed = False;
        try {
            parse_md2(data);
        } except ValueError {
            failed = True;
        }
        assert failed;
    }
}

def pcx_fixture(encoded: bytes) -> bytes {
    # Three visible pixels per row, a fourth padding byte, two scanlines.
    header = bytes([10, 5, 1, 8])
        + struct.pack("<4H", 0, 0, 2, 1)
        + bytes(53)
        + bytes([1])
        + struct.pack("<H", 4)
        + bytes(60);
    palette: list[int] = [];
    for i in range(256) {
        palette.extend([i, i, i]);
    }
    return header + encoded + bytes([12]) + bytes(palette);
}

test "PCX run decoding strips scanline padding" {
    texture = parse_pcx(pcx_fixture(bytes([194, 7, 8, 0, 1, 2, 3, 0])), "fixture");
    assert texture.width == 3 and texture.height == 2 and len(texture.pixels) == 24;
    assert int(texture.pixels[0]) == 7 and int(texture.pixels[4]) == 7;
    assert int(texture.pixels[8]) == 8 and int(texture.pixels[12]) == 1;
}

test "PCX rejects zero runs scanline overflow and truncated input" {
    for encoded in [bytes([192, 1]), bytes([197, 1]), bytes([193])] {
        failed = False;
        try {
            parse_pcx(pcx_fixture(encoded), "bad");
        } except ValueError {
            failed = True;
        }
        assert failed;
    }
}

import from engine.formats.q1.model { parse_mdl }
import from engine.formats.q3.model { parse_md3 }

def mdl_fixture() -> bytes {
    header = b"IDPO"
        + struct.pack(
            "<i10f8if",
            6,
            1.0,
            1.0,
            1.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            0.0,
            0.0,
            1,
            2,
            2,
            3,
            1,
            1,
            0,
            0,
            1.0
        );
    skins = struct.pack("<2i2f", 1, 2, 0.1, 0.2) + bytes([0, 1, 2, 3, 3, 2, 1, 0]);
    coords = struct.pack("<9i", 32, 0, 0, 0, 1, 0, 0, 0, 1);
    triangle = struct.pack("<4i", 0, 0, 1, 2);
    group = struct.pack("<2i", 1, 2) + bytes(8) + struct.pack("<2f", 0.1, 0.2);
    first = bytes(8)
        + b"idle"
        + bytes(12)
        + bytes([0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0]);
    second = bytes(8)
        + b"move"
        + bytes(12)
        + bytes([0, 0, 0, 0, 4, 0, 0, 0, 0, 4, 0, 0]);
    return header + skins + coords + triangle + group + first + second;
}

test "MDL grouped frames skins and back-facing seams survive adaptation" {
    model = parse_mdl(mdl_fixture(), bytes(768));
    mesh = model.surfaces[0];
    assert len(mesh.frames) == 2 and len(mesh.embedded_skins) == 2;
    assert mesh.frame_groups[0].count == 2 and mesh.skin_groups[0].count == 2;
    assert mesh.frame_groups[0].intervals[1] > 0.19;
    assert mesh.uv[0] == 0.75 and mesh.frames[1].name == "move";
    assert pose(mesh, 0, 1, 0.5)[1].x == 3.0;
}

def md3_fixture() -> bytes {
    header = b"IDP3"
        + struct.pack("<i", 15)
        + bytes(64)
        + struct.pack("<9i", 0, 1, 1, 1, 0, 108, 164, 276, 512);
    frame = bytes(40) + b"idle" + bytes(12);
    tag = b"tag_weapon"
        + bytes(54)
        + struct.pack(
            "<12f", 1.0, 2.0, 3.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0
        );
    surface = b"IDP3"
        + b"body"
        + bytes(60)
        + struct.pack("<10i", 0, 1, 1, 3, 1, 108, 120, 188, 212, 236);
    triangle = struct.pack("<3i", 0, 1, 2);
    shader = b"models/test" + bytes(53) + bytes(4);
    uv = struct.pack("<6f", 0.0, 0.0, 1.0, 0.0, 0.0, 1.0);
    vertices = struct.pack("<12h", -64, 0, 0, 0, 64, 0, 0, 0, 0, 64, 0, 0);
    return header + frame + tag + surface + triangle + shader + uv + vertices;
}

test "MD3 surfaces signed coordinates and attachment axes decode" {
    model = parse_md3(md3_fixture());
    assert len(model.surfaces) == 1;
    surface = model.surfaces[0];
    assert surface.name == "body" and surface.skins == ["models/test"];
    assert surface.frames[0].vertices[0].x == -1.0;
    tag = model.tags[0].tags[0];
    assert tag.name == "tag_weapon" and tag.origin.z == 3.0;
    assert tag.axes[0].x == 1.0 and tag.axes[2].z == 1.0;
}

test "MDL and MD3 reject incomplete animation data" {
    failed = False;
    try {
        parse_mdl(mdl_fixture()[:-1], bytes(768));
    } except ValueError {
        failed = True;
    }
    assert failed;
    failed = False;
    try {
        parse_md3(md3_fixture()[:-1]);
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "MD3 tag-only models remain valid attachment animation" {
    original = md3_fixture();
    data = original[:84]
        + struct.pack("<i", 0)
        + original[88:104]
        + struct.pack("<i", 276)
        + original[108:276];
    model = parse_md3(data);
    assert not model.surfaces and model.tags[0].tags[0].name == "tag_weapon";
}

import from engine.formats.q2.sprite { parse_sp2 }

test "SP2 validates frame dimensions pivots images and truncated tables" {
    data = b"IDS2"
        + struct.pack("<2i", 2, 1)
        + struct.pack("<4i", 64, 32, 31, 15)
        + b"sprites/test.pcx"
        + bytes(48);
    frames = parse_sp2(data);
    assert len(frames) == 1 and frames[0].width == 64 and frames[0].height == 32;
    assert frames[0].origin_x == 31
        and frames[0].origin_y == 15
        and frames[0].image == "sprites/test.pcx";
    for invalid in [
        data[:-1],
        data[:4] + struct.pack("<i", 3) + data[8:],
        data[:12] + struct.pack("<i", 0) + data[16:]
    ] {
        rejected = False;
        try {
            parse_sp2(invalid);
        } except ValueError {
            rejected = True;
        }
        assert rejected;
    }
}

test "PCX sprite transparency is opt in and does not alter model skin alpha" {
    data = pcx_fixture(bytes([193, 255, 7, 8, 0, 1, 2, 3, 0]));
    sprite = parse_pcx(data, "sprite", transparent=255);
    skin = parse_pcx(data, "skin");
    assert int(sprite.pixels[3]) == 0 and int(skin.pixels[3]) == 255;
    assert int(sprite.pixels[7]) == 255 and int(sprite.pixels[11]) == 255;
}
