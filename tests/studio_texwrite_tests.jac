import struct;
import from editor.formats.texwrite { rgba_halved, mip_indices, texture_refusal, write_wal, write_miptex, write_wad, texture_short }
import from editor.formats.wal { wal_facts }
import from engine.formats.q1.wad { wad_lumps }

"""A palette of 256 greys, darkest first."""
def greys -> bytes {
    made = bytearray();
    for index in range(256) {
        made.append(index);
        made.append(index);
        made.append(index);
    }
    return bytes(made);
}

"""A picture of one colour."""
def flat(width: int, height: int, red: int, green: int, blue: int) -> bytes {
    made = bytearray();
    for texel in range(width * height) {
        made.append(red);
        made.append(green);
        made.append(blue);
        made.append(255);
    }
    return bytes(made);
}

test "a picture is halved by the mean of each four texels" {
    # Two by two: black, white, white, black is one mid grey.
    four = bytes([0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 0, 0, 255]);
    assert rgba_halved(four, 2, 2) == bytes([128, 128, 128, 255]);
    assert len(rgba_halved(flat(16, 8, 10, 20, 30), 16, 8)) == 8 * 4 * 4;
    assert rgba_halved(flat(16, 8, 10, 20, 30), 16, 8)[:4] == bytes([10, 20, 30, 255]);
    levels = mip_indices(flat(32, 16, 100, 100, 100), 32, 16, greys());
    assert [len(level) for level in levels] == [512, 128, 32, 8] and levels[0][0] == 100 and levels[3][7] == 100;
}

test "a wall texture's sides are whole sixteens" {
    assert texture_refusal(64, 128) == "" and texture_refusal(16, 16) == "";
    assert "whole sixteens" in texture_refusal(100, 64) and "from 16" in texture_refusal(8, 64);
    assert write_wal("x", flat(100, 64, 1, 1, 1), 100, 64, greys()) == b"";
    assert write_miptex("x", flat(64, 64, 1, 1, 1), 64, 64, b"") == b"";
}

test "a picture written as a WAL reads back as the texture it was" {
    made = write_wal("walls/brick", flat(64, 32, 200, 200, 200), 64, 32, greys(), 2, 1, 150, "walls/brick2");
    # A hundred bytes of facts, then four sizes of picture.
    assert len(made) == 100 + 64 * 32 + 32 * 16 + 16 * 8 + 8 * 4;
    facts = wal_facts(made);
    assert facts is not None and facts.name == "walls/brick" and facts.width == 64 and facts.height == 32;
    assert facts.next_name == "walls/brick2" and facts.flags == 2 and facts.contents == 1 and facts.value == 150;
    first = int(struct.unpack("<I", made[40:44])[0]);
    last = int(struct.unpack("<I", made[52:56])[0]);
    assert first == 100 and last == len(made) - 32 and made[first] == 200 and made[len(made) - 1] == 200;
}

test "pictures written as a Quake WAD are found in it by name, each with its four sizes" {
    brick = write_miptex("brick", flat(32, 32, 90, 90, 90), 32, 32, greys());
    assert len(brick) == 40 + 1024 + 256 + 64 + 16 and brick[:5] == b"brick";
    assert int(struct.unpack("<I", brick[16:20])[0]) == 32 and int(struct.unpack("<I", brick[24:28])[0]) == 40;
    long_name = write_miptex("a_name_far_too_long_for_it", flat(16, 16, 5, 5, 5), 16, 16, greys());
    wad = write_wad([("brick", brick), ("A_Name_Far_Too_Long_For_It", long_name)]);
    lumps = wad_lumps(wad);
    assert [lump.name for lump in lumps] == ["brick", "a_name_far_too_"] and [lump.kind for lump in lumps] == [68, 68];
    assert lumps[0].size == len(brick) and wad[lumps[0].offset:lumps[0].offset + lumps[0].size] == brick;
    assert lumps[1].offset % 4 == 0 and wad[lumps[1].offset + 40] == 5;
    assert wad_lumps(write_wad([])) == [];
}

test "a material's picture goes by the last of its name, in small letters" {
    assert texture_short("q2:e1u1/metal1_1") == "metal1_1" and texture_short("file:walls/Metal1_1.png") == "metal1_1";
    assert texture_short("blockout") == "blockout" and texture_short("q1:e1m1/+0slip") == "+0slip";
    assert texture_short("file:crate.final.tga") == "crate.final";
}
