"""Bake one game's generated assets without starting the game: the whole
pack, or only the names under some prefixes, into an archive of its own.

    jac build scripts/generated_bake.jac --native -o .jac/qp-bake
    .jac/qp-bake q3 /tmp/gen                       # all of Quake III
    .jac/qp-bake q1 /tmp/gen sound/ progs/         # only these folders

The archive is written as `<folder>/<game>/zzzz-generated.pak` (`.pk3` for
Quake III), as the game writes its own, so it can be laid over a game with
QP_GENERATED_DIR=<folder>; a partial one is for comparing a family of assets
quickly, not for playing. QP_BAKE_LIST=1 bakes nothing and lists each name
with its kind, the family that makes it and its Quake III shader role."""
import os;
import sys;
import time;
import from engine.assets.content { shelf, pack_path }
import from games.procgen.manifest { build_manifest, slots_of }
import from games.procgen.bake { fill, BakeContext, atlas_skins }
import from games.procgen.writers { ArchiveWriter }
import from games.procgen.palette { quake_palette, quake2_palette }
import from games.procgen.textures { texture_family }
import from games.procgen.sounds { sound_family }
import from games.procgen.voices { spoken }
import from games.procgen.models { model_family }

with entry {
    if len(sys.argv) < 3 {
        print("usage: generated_bake <q1|q2|q3> <folder> [prefix...]");
        sys.exit(2);
    }
    game = sys.argv[1];
    folder = sys.argv[2] + "/" + game;
    prefixes = [prefix.lower() for prefix in sys.argv[3:]];
    pack = shelf().find(game);
    if pack is None {
        print("generated-bake: no pack " + game);
        sys.exit(2);
    }
    began = time.time();
    manifest = build_manifest(game, game, pack_path(pack));
    palette = quake2_palette() if game == "q2" else quake_palette();
    context = BakeContext(game=game, palette=palette, atlas=atlas_skins(manifest));
    for slot in slots_of(manifest) {
        context.slots[slot.kind + ":" + slot.name.lower()] = slot;
    }
    if os.getenv("QP_BAKE_LIST", "") != "" {
        # What the generator makes of each name: its kind, the family that
        # makes it, and (Quake III) the role its shaders give it.
        for slot in slots_of(manifest) {
            family = "";
            if slot.kind in ["sound"] {
                family = "voice" if spoken(slot.name) else sound_family(slot.name);
            } elif slot.kind in ["mdl", "md2", "md3"] {
                family = model_family(slot.name);
            } elif slot.kind in ["miptex", "wal", "image", "pcx", "lmp"] {
                family = texture_family(slot.name, game);
            }
            print(slot.kind + "\t" + slot.name + "\t" + family + "\t" + slot.notes.get("role", ""));
        }
        sys.exit(0);
    }
    os.makedirs(folder, exist_ok=True);
    target = folder + "/zzzz-generated." + ("pk3" if game == "q3" else "pak");
    archive = ArchiveWriter(path=target, zip=game == "q3");
    archive.begin();
    made = 0;
    for slot in slots_of(manifest) {
        if prefixes {
            lower = slot.name.lower();
            wanted = False;
            for prefix in prefixes {
                if lower.startswith(prefix) {
                    wanted = True;
                }
            }
            if not wanted {
                continue;
            }
        }
        for (name, data) in fill(context, slot) {
            archive.add(name, data);
            made += 1;
        }
    }
    archive.finish();
    print("generated-bake " + game + ": " + str(made) + " files in " + str(int(time.time() - began)) + " s -> " + target);
}
