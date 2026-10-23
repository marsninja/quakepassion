"""Trace original levels for Passion and say what came of it: the skeleton
read off each (grounds, ways by kind, what the grid made too steep, lifts,
doors), the rooms and passages found, the massing sculpted and what was
cast; with QP_TRACE_FORGE=1 the whole level made as the game makes it
(compiled and lit).

    jac build scripts/passion_trace.jac --native -o .jac/qp-trace
    QP_TRACE="e1m1 e1m2" DYLD_LIBRARY_PATH=vendor .jac/qp-trace

QP_ASSETS is the folder holding id1, baseq2 and baseq3 (default
~/quake-assets)."""
import os;
import time;
import from games.passion.trace { Tracing, Ground, Way, trace_source, trace_steps }
import from games.passion.generate { Forge }

with entry {
    home = os.getenv("HOME") or "";
    assets = os.getenv("QP_ASSETS") or (home + "/quake-assets");
    for map in (os.getenv("QP_TRACE") or "e1m1").split() {
        name = "trace-" + map;
        source = trace_source(name);
        if source is None {
            continue;
        }
        began = time.time();
        made = Tracing();
        for label in trace_steps(source, assets, made) {
            print("trace " + map + " " + label + " at " + str(round(time.time() - began, 2)) + " s");
        }
        for line in made.notes {
            print("trace " + map + " " + line);
        }
        # QP_TRACE_AT="x y": the grounds of the original's columns round that
        # point (original units), and the ways out of each.
        at = [float(word) for word in (os.getenv("QP_TRACE_AT") or "").split()];
        if len(at) == 2 {
            cx = int(at[0] // 32.0);
            cy = int(at[1] // 32.0);
            for dy in range(-2, 3) {
                for dx in range(-2, 3) {
                    for ground in made.columns.get((cx + dx, cy + dy), []) {
                        print("trace " + map + " ground " + str(ground.x) + "," + str(ground.y) + " z " + str(ground.z) + " base " + str(round(ground.base, 1)) + " liquid " + str(ground.liquid) + "/" + str(ground.surface) + " ceiling " + str(ground.ceiling) + " roof " + str(ground.roof) + " top " + str(ground.top) + " plat " + str(ground.plat) + " space " + str(ground.space) + " reach " + str(ground.reach) + " ways " + " ".join([str(way.kind) for way in [edge ground->:Way:->]]));
                    }
                }
            }
            print("trace " + map + " offset " + str(made.offset));
        }
        casting = made.casting;
        if casting is not None {
            print("trace " + map + " cast " + str(len(casting.items)) + " items, " + str(casting.monsters) + " monsters, " + str(casting.doors) + " doors, start " + str(casting.start) + " exit " + str(casting.exit_low));
        }
        brushes = 0;
        for item in made.items {
            brushes += len(item.brushes);
        }
        print("trace " + map + " map items " + str(len(made.items)) + " brushes " + str(brushes) + " briefing " + made.briefing);
        if os.getenv("QP_TRACE_FORGE", "") {
            forge = Forge(name=name, directory=assets);
            started = time.time();
            forge.complete();
            print("trace " + map + " forged in " + str(round(time.time() - started, 2)) + " s, longest step " + str(round(forge.longest, 3)) + " s at " + forge.longest_step + (" failed: " + forge.failure if forge.failure else ""));
        }
    }
}
