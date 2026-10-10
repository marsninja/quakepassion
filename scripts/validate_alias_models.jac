"""Validate Q1 MDL and Q3 MD3 archives against shared animation records, and
report how every Q3 shader script a model or .skin file names is drawn: with
its stages, hidden (a script without stages) or, with the reason, as the
plain skin."""
import os;
import from engine.assets.pak { open_pak, PakArchive }
import from engine.assets.pk3 { Pk3Assets }
import from engine.world.level { asset }
import from engine.formats.q1.model { parse_mdl }
import from engine.formats.q3.model { parse_md3 }
import from engine.assets.materials { material_name }

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
    # Each shader a model surface or a .skin row names, and one user of it.
    users: dict[str, str] = {};
    for name in sorted(pk3.owners.keys()) {
        if name.endswith(".md3") {
            model = parse_md3(pk3.read(name));
            frames += len(model.tags);
            total += 1;
            for surface in model.surfaces {
                for skin in surface.skins {
                    if skin and skin not in users {
                        users[skin] = name;
                    }
                }
            }
            print("MD3 PASS", name, "surfaces", len(model.surfaces));
        } elif name.endswith(".skin") {
            for line in pk3.read(name).decode("utf-8").splitlines() {
                fields = line.split(",");
                if len(fields) == 2 and fields[1].strip() and fields[1].strip() not in users {
                    users[fields[1].strip()] = name;
                }
            }
        }
    }
    assert total > 0;
    print("MD3 MODELS PASS", total, "frames", frames);
    scripted: dict[str, bool] = {};
    staged = 0;
    hidden = 0;
    plain = 0;
    for skin in sorted(users.keys()) {
        key = material_name(skin);
        if key not in pk3.model_shaders or key in scripted {
            continue;
        }
        scripted[key] = True;
        if pk3.model_hidden(skin) {
            hidden += 1;
            print("MODEL SHADER HIDDEN", key, "in", users[skin]);
        } elif pk3.model_stages(skin) {
            staged += 1;
        } else {
            plain += 1;
            print("MODEL SHADER PLAIN SKIN", key, "in", users[skin], pk3.model_blockers(skin));
        }
    }
    pk3.close();
    print("MODEL SHADERS", len(scripted), "scripted:", staged, "staged,", hidden, "hidden,", plain, "plain skin");
}
