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
import from games.passion.sculpt { Sculpting, Ground, sculpture_grounds }
import from games.passion.massing { CELL, LIFT }

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
            # QP_FORGE_AT="x y": the last candidate's sculpture in the column
            # at that point of the made level (its grounds, its air).
            at = [float(word) for word in (os.getenv("QP_FORGE_AT") or "").split()];
            made = forge.sculpting;
            if len(at) == 2 and made is not None and made.mass is not None {
                mass = made.mass;
                for dx in [-1, 0, 1] {
                    for dy in [-1, 0, 1] {
                        mx = int(at[0] // CELL) + dx;
                        my = int(at[1] // CELL) + dy;
                        runs: list[str] = [];
                        z = 0;
                        while z < mass.nz {
                            owner = mass.at(mx, my, z);
                            start = z;
                            while z < mass.nz and mass.at(mx, my, z) == owner {
                                z += 1;
                            }
                            if owner > 0 {
                                runs.append(str(start) + ".." + str(z) + ":" + str(owner - 1));
                            }
                        }
                        grounds = [g for g in made.columns.get((mx + made.offset[0], my + made.offset[1]), [])];
                        print("FORGE", name, "column", mx, my, "air", runs, "grounds", [str(g.z - made.offset[2]) + "/" + str(g.ceiling - made.offset[2]) + " space " + str(g.space) + " area " + str(g.area) + (" top" if g.top else "") + " stage " + str(g.stage) for g in grounds]);
                    }
                }
            }
            casting = record.casting;
            if casting is not None and len(at) == 2 {
                for item in casting.items {
                    for brush in item.brushes {
                        xs = [side.plane.dist for side in brush if side.plane.normal.x > 0.5] + [-side.plane.dist for side in brush if side.plane.normal.x < -0.5];
                        ys = [side.plane.dist for side in brush if side.plane.normal.y > 0.5] + [-side.plane.dist for side in brush if side.plane.normal.y < -0.5];
                        zs = [side.plane.dist for side in brush if side.plane.normal.z > 0.5] + [-side.plane.dist for side in brush if side.plane.normal.z < -0.5];
                        if len(xs) == 2 and len(ys) == 2 and min(xs) - 32.0 <= at[0] <= max(xs) + 32.0 and min(ys) - 32.0 <= at[1] <= max(ys) + 32.0 {
                            print("FORGE", name, "entity", item.fields, "box", min(xs), min(ys), min(zs), max(xs), max(ys), max(zs));
                        }
                    }
                }
            }
            if casting is not None {
                print("FORGE", name, "cast", len(casting.items), "items,", casting.monsters, "monsters,", casting.doors, "doors", " ".join(casting.notes));
            }
        }
    }
}
