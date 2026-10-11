import os;
import tempfile;
import from zipfile { ZipFile }
import from engine.assets.pak { parse_pak }
import from editor.formats.archive { write_pak, write_zip, crc32_of, folder_children, file_kind }

test "a PAK written is read back by the engine's reader" {
    files = [("maps/yard.map", b"{\n\"classname\" \"worldspawn\"\n}\n"), ("textures/wall.wal", bytes(range(200))), ("empty.txt", b"")];
    packed = write_pak(files);
    assert packed[:4] == b"PACK";
    archive = parse_pak(packed);
    names = archive.names();
    assert len(names) == 3 and names[0] == "maps/yard.map" and names[2] == "empty.txt";
    assert archive.read_file("textures/wall.wal") == bytes(range(200));
    assert archive.read_file("maps/yard.map").decode("utf-8").startswith("{") and len(archive.read_file("empty.txt")) == 0;
    assert len(parse_pak(write_pak([])).names()) == 0;
    refused = False;
    try {
        write_pak([("a" * 60, b"x")]);
    } except ValueError {
        refused = True;
    }
    assert refused;
}

test "the checksum is the one zips use" {
    assert crc32_of(b"") == 0;
    assert crc32_of(b"123456789") == 0xCBF43926;
    assert crc32_of(b"The quick brown fox jumps over the lazy dog") == 0x414FA339;
}

test "a PK3 written is read back as a zip" {
    files = [("scripts/yard.shader", b"textures/yard/wall\n{\n}\n"), ("maps/yard.map", b"// a map\n" * 40), ("levelshots/none.txt", b"")];
    folder = tempfile.mkdtemp(prefix="qp-zip-");
    path = folder + "/yard.pk3";
    with open(path, "wb") as handle {
        handle.write(write_zip(files));
    }
    archive = ZipFile(path);
    names = archive.namelist();
    assert len(names) == 3 and names[0] == "scripts/yard.shader" and names[1] == "maps/yard.map";
    assert archive.read("maps/yard.map") == b"// a map\n" * 40;
    assert archive.read("scripts/yard.shader").decode("utf-8").startswith("textures/yard/wall");
    assert len(archive.read("levelshots/none.txt")) == 0;
    archive.close();
    os.remove(path);
    os.rmdir(folder);
}

test "file names list as folders, and say what kind of thing they are" {
    names = ["maps/e1m1.bsp", "maps/e1m2.bsp", "progs/player.mdl", "sound/items/r_item1.wav", "sound/misc/menu1.wav", "gfx.wad", "default.cfg"];
    top = folder_children(names, "");
    assert top[0] == ["maps", "progs", "sound"] and top[1] == ["default.cfg", "gfx.wad"];
    sounds = folder_children(names, "sound");
    assert sounds[0] == ["items", "misc"] and len(sounds[1]) == 0;
    assert folder_children(names, "sound/items")[1] == ["r_item1.wav"];
    assert len(folder_children(names, "nothing")[0]) == 0 and len(folder_children(names, "map")[1]) == 0;
    assert file_kind("textures/e1u1/metal1_1.wal") == "image" and file_kind("scripts/base.shader") == "text";
    assert file_kind("sound/misc/menu1.wav") == "sound" and file_kind("models/weapons/v_rail/tris.md2") == "model";
    assert file_kind("maps/base1.bsp") == "map" and file_kind("README") == "other" and file_kind("pics/CONCHARS.PCX") == "image";
}
