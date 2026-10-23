"""Read the level graph off original levels and prove each: the way out
reached for sure, no softlock anywhere a player can get, the tokens the
level requires, and the budget of health and ammunition along the route.
A line a level; QP_PROOF_TRAPS=1 also lists the states that strand a
player.

    jac build scripts/level_proof.jac --native -o .jac/level-proof
    QP_MAPS="q1:e1m1 q2:base1" DYLD_LIBRARY_PATH=vendor .jac/level-proof
    QP_PROOF_GAMES="q1 q2 q3" DYLD_LIBRARY_PATH=vendor .jac/level-proof

QP_PROOF_KEEP=<folder> keeps each graph read there (as Passion's essence
corpus keeps them)."""
import os;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.level.graph { LevelGraph, Place, Move, graph_places, write_graph }
import from engine.level.extract { read_level_graph }
import from engine.level.prove { prove_level }
import from engine.level.budget { budget_route, start_kit }
import from games.passion.originals { originals_of }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    specs = (os.getenv("QP_MAPS") or "").split();
    if not specs {
        specs = originals_of((os.getenv("QP_PROOF_GAMES") or "q1").split());
    }
    keep = os.getenv("QP_PROOF_KEEP", "");
    clean = 0;
    for spec in specs {
        parts = spec.split(":");
        began = time.time();
        try {
            app.load_destination(parts[0], parts[1]);
        } except Exception as failure {
            print("PROOF", spec, "could not load:", str(failure));
            continue;
        }
        if app.level.name != parts[1] {
            print("PROOF", spec, "could not load");
            continue;
        }
        atlas = read_level_graph(app.world, app.level);
        read_seconds = time.time() - began;
        proof = prove_level(atlas);
        ledger = budget_route(atlas, proof.route, app.level.collision, start_kit(parts[0]));
        ok = proof.finishes and proof.softlocks == 0;
        if ok {
            clean += 1;
        }
        print(
            "PROOF", spec, "clean" if ok else "NOT", "finishes", proof.finishes, "softlocks", proof.softlocks, "states", proof.states,
            "arena" if atlas.arena else "", "required", proof.required, "places", len(graph_places(atlas)), "route", len(proof.route),
            "lowest", int(ledger.lowest), "end", int(ledger.health), "fights", ledger.fights, "melee", ledger.melee, "seconds",
            round(read_seconds, 1), " | ".join(atlas.notes + proof.notes)
        );
        if os.getenv("QP_PROOF_TRAPS", "") {
            by_area: dict[int, Place] = {};
            for place in graph_places(atlas) {
                by_area[place.area] = place;
            }
            for trap in proof.traps {
                area = int(trap.split(" ")[0]);
                place = by_area.get(area, None);
                where = "";
                if place is not None {
                    where = " at " + str(int(place.center.x)) + "," + str(int(place.center.y)) + "," + str(int(place.center.z)) + " moves "
                        + str([str(move.to) + ":" + str(move.kind) + ("" if move.must else "?") for move in [edge place->:Move:->]]);
                }
                print("PROOF", spec, "  trap", trap + where);
            }
        }
        if keep {
            write_graph(atlas, keep + "/" + parts[0] + "-" + parts[1] + ".graph");
        }
    }
    print("PROOF clean", clean, "of", len(specs));
}
