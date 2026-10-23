"""Make Passion levels as the game makes them and say how each went: the
essence picked, each candidate's proof and budget, and how long each stage
took.

    jac build scripts/passion_forge.jac --native -o .jac/qp-forge
    QP_LEVELS="v4-1 v4-1-2 trace-e1m1" DYLD_LIBRARY_PATH=vendor .jac/qp-forge

QP_ASSETS is the folder holding id1, baseq2 and baseq3 (default
~/quake-assets); QP_FORGE_LIGHT=0 leaves the light out."""
import os;
import time;
import from games.passion.generate { Forge }

with entry {
    home = os.getenv("HOME") or "";
    assets = os.getenv("QP_ASSETS") or (home + "/quake-assets");
    lit = os.getenv("QP_FORGE_LIGHT", "1") != "0";
    for name in (os.getenv("QP_LEVELS") or "v4-1").split() {
        forge = Forge(name=name, directory=assets if lit else "");
        if not lit {
            forge.directory = "";
        }
        began = time.time();
        forge.complete();
        record = forge.survey;
        print("FORGE", name, "in", round(time.time() - began, 1), "s", ("failed: " + forge.failure) if forge.failure else "made", "longest step", round(forge.longest, 2), "s at", forge.longest_step);
        if record is not None {
            print("FORGE", name, "essence", record.essence, "candidates", record.candidates, "proven", record.proven, "budget lowest", int(record.lowest));
            for note in record.notes {
                print("FORGE", name, "  ", note);
            }
            casting = record.casting;
            if casting is not None {
                print("FORGE", name, "cast", len(casting.items), "items,", casting.monsters, "monsters,", casting.doors, "doors", " ".join(casting.notes));
            }
        }
    }
}
