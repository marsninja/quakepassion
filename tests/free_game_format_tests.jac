import os;
import struct;
import tempfile;
import zipfile;
import from engine.formats.q3.model { parse_md3 }
import from engine.formats.q1.bsp { bsp29_child }
import from engine.formats.animated { AnimationFrame }
import from engine.assets.materials { material_name }
import from engine.assets.pk3 { Pk3Assets, file_key }
import from engine.assets.library { AssetLibrary }
import from games.opponents { frame_indices, expand_frames, standard_frames }
import from games.arena_character { player_part }

"""An MD3 of one frame and one tag, with a triangle surface named `name`
skinned `models/test`, and after it, when `empty`, a surface with no
vertices or triangles (OpenArena's telep.md3 and tony's vest)."""
def md3_model(name: str, empty: bool) -> bytes {
    extra = 108 if empty else 0;
    header = b"IDP3"
        + struct.pack("<i", 15)
        + bytes(64)
        + struct.pack("<9i", 0, 1, 1, 2 if empty else 1, 0, 108, 164, 276, 512 + extra);
    frame = bytes(40) + b"idle" + bytes(12);
    tag = b"tag_weapon"
        + bytes(54)
        + struct.pack(
            "<12f", 1.0, 2.0, 3.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0
        );
    label = name.encode("utf-8");
    surface = b"IDP3"
        + label
        + bytes(64 - len(label))
        + struct.pack("<10i", 0, 1, 1, 3, 1, 108, 120, 188, 212, 236);
    triangle = struct.pack("<3i", 0, 1, 2);
    shader = b"models/test" + bytes(53) + bytes(4);
    uv = struct.pack("<6f", 0.0, 0.0, 1.0, 0.0, 0.0, 1.0);
    vertices = struct.pack("<12h", -64, 0, 0, 0, 64, 0, 0, 0, 0, 64, 0, 0);
    hollow = b"IDP3" + b"u_vest" + bytes(58) + struct.pack("<10i", 0, 1, 0, 0, 0, 108, 108, 108, 108, 108);
    return header + frame + tag + surface + triangle + shader + uv + vertices + (hollow if empty else b"");
}

test "an MD3 surface with no vertices or triangles loads and draws nothing" {
    model = parse_md3(md3_model("body", True));
    assert [surface.name for surface in model.surfaces] == ["body"];
    assert model.tags[0].tags[0].name == "tag_weapon";
}

test "BSP29 children past 32767 are indices; the rest count leaves and contents down" {
    data = struct.pack("<HHHH", 40000, 65535, 65534, 7);
    assert bsp29_child(data, 0, 52419) == 40000;
    # Solid (-2) and leaf 0 (-1) as Quake wrote them.
    assert bsp29_child(data, 2, 52419) == -1 and bsp29_child(data, 4, 52419) == -2;
    assert bsp29_child(data, 6, 100) == 7;
    # A small map reads as Quake's signed shorts did.
    assert bsp29_child(struct.pack("<H", 32768), 0, 155) == -32768;
}

test "Quake's standard frame order expands its ranges, repeats included" {
    assert expand_frames("stand1..3 exp attackb1 attackb1..2") == ["stand1", "stand2", "stand3", "exp", "attackb1", "attackb1", "attackb2"];
    ogre = standard_frames("progs/ogre.mdl", 147);
    assert len(ogre) == 147 and ogre[0] == "stand1" and ogre[9] == "walk1";
    shub = standard_frames("progs/oldone.mdl", 67);
    assert shub[46:48] == ["shake1", "shake2"] and shub.count("shake12") == 2;
    # Only a model with Quake's own number of frames is read in Quake's order.
    assert standard_frames("progs/ogre.mdl", 146) == [] and standard_frames("progs/unknown.mdl", 3) == [];
}

test "a Quake model that names its frames otherwise is animated by frame number" {
    generic = [AnimationFrame(name="frame" + str(i + 1)) for i in range(147)];
    ogre = standard_frames("progs/ogre.mdl", 147);
    found = frame_indices(generic, ["pain1", "pain2", "pain3"], "progs/ogre.mdl", "pain");
    assert found == [ogre.index("pain1"), ogre.index("pain1") + 1, ogre.index("pain1") + 2];
    # Its own names still come first.
    assert frame_indices(generic, ["frame3"], "progs/ogre.mdl", "idle") == [2];
    failed = False;
    try {
        frame_indices(generic[:146], ["pain1"], "progs/ogre.mdl", "pain");
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "Quake III names a file or shader whatever its case, a backslash as a slash" {
    assert material_name("Models\\Weapons2\\Grenadel\\Grenadel.tga") == "models/weapons2/grenadel/grenadel";
    assert file_key("Models\\Players\\Neko\\Hair.TGA") == "models/players/neko/hair.tga";
    with tempfile.TemporaryDirectory(prefix="qp-pk3-") as folder {
        with zipfile.ZipFile(folder + "/pak0.pk3", "w") as archive {
            archive.writestr("models/weapons2/grenadel/grenadel.tga", b"tga");
        }
        assets = Pk3Assets();
        assets.open(folder);
        try {
            assert assets.exists("models\\weapons2\\grenadel\\grenadel.tga");
            assert assets.image_name("models\\weapons2\\grenadel\\grenadel") == "models/weapons2/grenadel/grenadel.tga";
            assert assets.read("MODELS\\weapons2\\grenadel\\grenadel.tga") == b"tga";
        } finally {
            assets.close();
        }
    }
}

test "a player's skin names its surfaces whatever their case; an unnamed one takes the default image" {
    with tempfile.TemporaryDirectory(prefix="qp-skin-") as folder {
        with zipfile.ZipFile(folder + "/pak0.pk3", "w") as archive {
            archive.writestr("models/players/neko/lower.md3", md3_model("Skirt", True));
            archive.writestr("models/players/neko/lower_default.skin", "skirt,models/test.tga\ntag_torso,\n");
            archive.writestr("models/players/neko/upper.md3", md3_model("Body", False));
            archive.writestr("models/players/neko/upper_default.skin", "hair,models/test.tga\n");
            archive.writestr("models/test.tga", b"tga");
        }
        library = AssetLibrary(game="q3");
        library.open(folder);
        try {
            lower = player_part(library, "lower", "neko");
            assert [surface.name for surface in lower.model.surfaces] == ["Skirt"];
            assert lower.skins[0].name == "models/test.tga" and lower.skins[0].encoded == b"tga";
            upper = player_part(library, "upper", "neko");
            assert len(upper.skins) == 1 and upper.skins[0].name == "*default";
        } finally {
            library.close();
        }
    }
}
