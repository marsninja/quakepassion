"""Read the essences of original levels and prove each, as Passion reads
them: the way out reached for sure, no softlock anywhere a player can get,
the tokens the level requires, and the budget along the route. A line a
level, and for one that does not prove, why (where its traps are, what it
wants and who gives it).

    jac build scripts/level_proof.jac --native -o .jac/level-proof
    QP_MAPS="q1:e1m1 q2:base1" DYLD_LIBRARY_PATH=vendor .jac/level-proof
    QP_PROOF_GAMES="q1 q2 q3" DYLD_LIBRARY_PATH=vendor .jac/level-proof

QP_PROOF_CORPUS=1 keeps each essence read where Passion keeps its corpus
(under QP_CONFIG_DIR, else the home folder), so a run never waits on
reading one."""
import os;
import time;
import from engine.level.graph { LevelGraph, write_graph }
import from engine.level.prove { prove_level, explain_proof }
import from games.passion.essence { read_essence, save_essence, essence_clean }
import from games.passion.originals { originals_of }

with entry {
    specs = (os.getenv("QP_MAPS") or "").split();
    if not specs {
        specs = originals_of((os.getenv("QP_PROOF_GAMES") or "q1").split());
    }
    keep = os.getenv("QP_PROOF_CORPUS", "") != "";
    clean = 0;
    for spec in specs {
        began = time.time();
        try {
            atlas = read_essence(spec);
        } except Exception as failure {
            print("PROOF", spec, "could not be read:", str(failure));
            continue;
        }
        ok = essence_clean(atlas);
        if ok {
            clean += 1;
        }
        print("PROOF", spec, "clean" if ok else "NOT", "in", round(time.time() - began, 1), "s |", " | ".join(atlas.notes));
        if not ok and os.getenv("QP_PROOF_WHY", "1") != "0" {
            for line in explain_proof(atlas, prove_level(atlas)) {
                print("PROOF", spec, "  ", line);
            }
        }
        if keep {
            save_essence(atlas, spec);
        }
    }
    print("PROOF clean", clean, "of", len(specs));
}
