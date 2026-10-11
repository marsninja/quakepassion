import os;
import struct;
import tempfile;
import from engine.assets.pak { parse_pak }
import from editor.formats.archive {
    write_pak, write_zip, pak_files, zip_files, files_with, files_without, wad_member, wad_names, wad_lump, folder_children,
    lies_in
}

"""A WAD2 of the lumps given: (name, kind, bytes)."""
def wad_of(lumps: list[tuple[str, int, bytes]]) -> bytes {
    body = bytearray();
    table = bytearray();
    for (name, kind, data) in lumps {
        table.extend(struct.pack("<iii", 12 + len(body), len(data), len(data)));
        table.extend(bytes([kind, 0, 0, 0]));
        raw = name.encode("utf-8")[:15];
        table.extend(raw + bytes(16 - len(raw)));
        body.extend(data);
    }
    head = bytearray(b"WAD2");
    head.extend(struct.pack("<ii", len(lumps), 12 + len(body)));
    return bytes(head) + bytes(body) + bytes(table);
}

test "an archive's files are read out, one put in or changed, one or a folder dropped" {
    files = [("maps/yard.map", b"{}\n"), ("textures/yard/wall.wal", bytes(range(100))), ("textures/yard/floor.wal", b"floor"), ("readme.txt", b"hello")];
    held = pak_files(write_pak(files));
    assert held == files;
    # Put in place of the file of that name, however its case is written; a new name goes last.
    changed = files_with(held, "README.TXT", b"changed");
    assert [name for (name, data) in changed] == [name for (name, data) in files] and changed[3][1] == b"changed";
    more = files_with(changed, "sound\\yard\\wind.wav", b"RIFF");
    assert len(more) == 5 and more[4] == ("sound/yard/wind.wav", b"RIFF") and held == files;
    # One file dropped, and a whole folder; a name that is not there drops nothing.
    assert [name for (name, data) in files_without(more, "maps/yard.map")] == [
        "textures/yard/wall.wal", "textures/yard/floor.wal", "readme.txt", "sound/yard/wind.wav"
    ];
    assert [name for (name, data) in files_without(more, "textures/")] == ["maps/yard.map", "readme.txt", "sound/yard/wind.wav"];
    assert len(files_without(more, "textures")) == 5 and len(files_without(more, "nothing.txt")) == 5;
    # What is written again the engine reads.
    again = parse_pak(write_pak(files_without(more, "Textures/Yard/")));
    assert again.names() == ["maps/yard.map", "readme.txt", "sound/yard/wind.wav"] and again.read_file("readme.txt") == b"changed";
    assert pak_files(write_pak([])) == [];
}

test "a PK3 on disk is read out and written again with a file changed" {
    files = [("scripts/yard.shader", b"textures/yard/wall\n{\n}\n"), ("maps/yard.map", b"// a map\n" * 40), ("empty.txt", b"")];
    folder = tempfile.mkdtemp(prefix="qp-repack-");
    path = folder + "/yard.pk3";
    with open(path, "wb") as handle {
        handle.write(write_zip(files));
    }
    held = zip_files(path);
    assert held == files;
    with open(path, "wb") as handle {
        handle.write(write_zip(files_without(files_with(held, "maps/yard.map", b"// another\n"), "empty.txt")));
    }
    again = zip_files(path);
    assert again == [("scripts/yard.shader", b"textures/yard/wall\n{\n}\n"), ("maps/yard.map", b"// another\n")];
    os.remove(path);
    os.rmdir(folder);
}

test "a WAD's lumps are files inside it" {
    picture = struct.pack("<ii", 2, 2) + bytes([1, 2, 3, 4]);
    wad = wad_of([("SBAR", 66, picture), ("conchars", 64, bytes(16)), ("palette", 64, bytes(8))]);
    assert wad_names("gfx.wad", wad) == ["gfx.wad/sbar", "gfx.wad/conchars", "gfx.wad/palette"];
    assert wad_names("gfx.wad", b"PACK") == [] and wad_names("gfx.wad", b"") == [];
    assert wad_member("gfx.wad/sbar") == ("gfx.wad", "sbar") and wad_member("GFX.WAD/Sbar") == ("GFX.WAD", "Sbar");
    assert wad_member("gfx.wad") is None and wad_member("gfx.wad/") is None and wad_member("gfx/palette.lmp") is None;
    lump = wad_lump(wad, "sbar");
    assert lump is not None and lump[0] == picture and lump[1] == 66;
    assert wad_lump(wad, "Conchars") == (bytes(16), 64) and wad_lump(wad, "missing") is None and wad_lump(b"junk", "sbar") is None;
    # Beside a game's other files the WAD is a file and a folder of its lumps.
    listed = sorted(["gfx.wad", "gfx/palette.lmp"] + wad_names("gfx.wad", wad));
    assert folder_children(listed, "") == (["gfx", "gfx.wad"], ["gfx.wad"]);
    assert folder_children(listed, "gfx.wad") == ([], ["conchars", "palette", "sbar"]);
}

test "a file is known to lie in a folder however the two are written" {
    folder = tempfile.mkdtemp(prefix="qp-lies-");
    os.makedirs(folder + "/id1/deeper");
    os.makedirs(folder + "/mine");
    assert lies_in(folder + "/id1/pak0.pak", [folder + "/baseq2", folder + "/id1"]);
    assert lies_in(folder + "/mine/../id1/pak0.pak", [folder + "/id1/"]) and lies_in(folder + "/id1/./pak0.pak", [folder + "/id1/deeper/.."]);
    # Not a folder under it, nor beside it, nor a folder that is not named.
    assert not lies_in(folder + "/id1/deeper/pak0.pak", [folder + "/id1"]) and not lies_in(folder + "/mine/pak0.pak", [folder + "/id1"]);
    assert not lies_in(folder + "/id1/pak0.pak", []) and not lies_in(folder + "/id1/pak0.pak", [""]);
    os.rmdir(folder + "/id1/deeper");
    os.rmdir(folder + "/id1");
    os.rmdir(folder + "/mine");
    os.rmdir(folder);
}
