"""Validate every installed Q2 MD2 and referenced PCX skin without a window."""
import os;
import from engine.assets.pak { open_pak, PakArchive }
import from engine.world.level { asset }
import from engine.formats.q2.model { parse_md2, parse_pcx }
import from engine.formats.animated { pose }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/baseq2";
    paks: list[PakArchive] = [];
    names: list[str] = [];
    for filename in sorted(os.listdir(directory)) {
        if filename.lower().endswith(".pak") {
            archive = open_pak(directory + "/" + filename);
            paks.append(archive);
            for name in archive.names() {
                if name.endswith(".md2") and name not in names {
                    names.append(name);
                }
            }
        }
    }
    frames = 0;
    skins: list[str] = [];
    for name in names {
        model = parse_md2(asset(paks, name));
        for surface in model.surfaces {
            frames += len(surface.frames);
            positions = pose(surface, 0, len(surface.frames) - 1, 0.5);
            assert len(positions) == len(surface.frames[0].vertices);
            for skin in surface.skins {
                if skin and skin not in skins {
                    texture = parse_pcx(asset(paks, skin), skin);
                    assert len(texture.pixels) == texture.width * texture.height * 4;
                    skins.append(skin);
                }
            }
        }
        print("MODEL PASS", name);
    }
    assert len(names) > 0 and len(skins) > 0;
    print("MODELS PASS", len(names), "models", frames, "frames", len(skins), "skins");
}
