"""What the generator covers of a game, and what it leaves to the game's
own data: a count by kind of asset, and the names it leaves, by folder.

    jac build scripts/generated_coverage.jac --native -o .jac/qp-coverage
    .jac/qp-coverage q1            # or q2, q3; QP_ASSETS as for the game
    QP_COVERAGE_NAMES=1 .jac/qp-coverage q3   # every name left, too

Text (scripts, configs, bot files), shader scripts and maps are left by
design: the generator makes what a game draws and plays, not what it
reads as rules or what its levels are built of."""
import os;
import sys;
import from engine.assets.content { shelf, pack_path, assets_root }
import from games.procgen.manifest { build_manifest, slots_of }
import from games.procgen.bake { fill, BakeContext, atlas_skins }
import from games.procgen.palette { quake_palette, quake2_palette }

glob BY_DESIGN: list[str] = ["text", "shader", "map", "other", "wal_ref"];

with entry {
    game = sys.argv[1] if len(sys.argv) > 1 else "q1";
    pack = shelf().find(game);
    if pack is None {
        print("generated-coverage: no pack " + game);
        sys.exit(2);
    }
    path = pack_path(pack);
    manifest = build_manifest(game, game, path);
    palette = quake2_palette() if game == "q2" else quake_palette();
    context = BakeContext(game=game, palette=palette, atlas=atlas_skins(manifest));
    for slot in slots_of(manifest) {
        context.slots[slot.kind + ":" + slot.name.lower()] = slot;
    }
    made: dict[str, int] = {};
    left: dict[str, int] = {};
    left_folders: dict[str, int] = {};
    left_names: list[str] = [];
    for slot in slots_of(manifest) {
        if fill(context, slot) {
            made[slot.kind] = made.get(slot.kind, 0) + 1;
        } else {
            left[slot.kind] = left.get(slot.kind, 0) + 1;
            if slot.kind not in BY_DESIGN {
                folder = slot.name.rsplit("/", 1)[0] if "/" in slot.name else "(top)";
                left_folders[slot.kind + " " + folder] = left_folders.get(slot.kind + " " + folder, 0) + 1;
                left_names.append(slot.kind + " " + slot.name);
            }
        }
    }
    total_made = sum(made.values());
    total_left = sum([count for (kind, count) in left.items() if kind not in BY_DESIGN]);
    print("generated-coverage " + game + ": made " + str(total_made) + ", left " + str(total_left) + " (and " + str(sum([count for (kind, count) in left.items() if kind in BY_DESIGN])) + " by design)");
    for kind in sorted(set(list(made.keys()) + list(left.keys()))) {
        note = " (by design)" if kind in BY_DESIGN else "";
        print("  " + kind + ": made " + str(made.get(kind, 0)) + ", left " + str(left.get(kind, 0)) + note);
    }
    if left_folders {
        print("left, by folder:");
        for key in sorted(left_folders.keys()) {
            print("  " + key + ": " + str(left_folders[key]));
        }
    }
    if os.getenv("QP_COVERAGE_NAMES", "") != "" {
        for name in sorted(left_names) {
            print("  " + name);
        }
    }
}
