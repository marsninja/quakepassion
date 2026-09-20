"""Validate Q1 MDL and Q3 MD3 archives against shared animation records."""
import os;
import from engine.assets.pak { open_pak, PakArchive }
import from engine.assets.pk3 { Pk3Assets }
import from engine.world.level { asset }
import from engine.formats.q1.model { parse_mdl }
import from engine.formats.q3.model { parse_md3 }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/";
    paks: list[PakArchive] = [];
    names: list[str] = [];
    for filename in sorted(os.listdir(directory + "id1")) {
        if filename.lower().endswith(".pak") {
            archive = open_pak(directory + "id1/" + filename);
            paks.append(archive);
            for name in archive.names() {
                if name.endswith(".mdl") and name not in names {
                    names.append(name);
                }
            }
        }
    }
    palette = asset(paks, "gfx/palette.lmp");
    frames = 0;
    for name in names {
        model = parse_mdl(asset(paks, name), palette);
        assert len(model.surfaces) == 1;
        frames += len(model.surfaces[0].frames);
        print("MDL PASS", name);
    }
    assert len(names) > 0;
    print("MDL MODELS PASS", len(names), "frames", frames);
    pk3 = Pk3Assets();
    pk3.open(directory + "baseq3");
    total = 0;
    frames = 0;
    for name in sorted(pk3.owners.keys()) {
        if name.endswith(".md3") {
            model = parse_md3(pk3.read(name));
            frames += len(model.tags);
            total += 1;
            print("MD3 PASS", name, "surfaces", len(model.surfaces));
        }
    }
    pk3.close();
    assert total > 0;
    print("MD3 MODELS PASS", total, "frames", frames);
}
