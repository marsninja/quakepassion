"""Read the level atlas off levels and prove them: the way out reached for
sure, no softlock anywhere a player can get, and the budget of health and
ammunition along the route; then the proof checked against itself, each
token left out in turn (a level that needs it must then fail), and a
softlock put in on purpose (it must be found).

    jac build scripts/level_proof.jac --native -o .jac/level-proof
    QP_MAPS="q1:e1m1 passion:trace-e1m1" DYLD_LIBRARY_PATH=vendor .jac/level-proof"""
import os;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.math.vec3 { Vec3 }
import from engine.nav.compile { compile_navigation, NavStep, NavSpot }
import from engine.nav.levelgraph { LevelGraph, Place, Move, Opener, Gate, Holds, Guards, Offers, Bars, DoneFrom, read_level_graph, prove, budget, graph_places }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    for spec in (os.getenv("QP_MAPS") or "q1:e1m1").split() {
        parts = spec.split(":");
        app.load_destination(parts[0], parts[1]);
        began = time.time();
        build = compile_navigation(app.world, app.level);
        look = [int(word) for word in (os.getenv("QP_PROOF_AREA") or "").split()];
        grid = build.grid;
        if look and grid is not None {
            for spot in grid.spots {
                if spot.area in look {
                    print("PROOF spot", spot.index, "area", spot.area, "at", int(spot.origin.x), int(spot.origin.y), int(spot.origin.z), "grounded", spot.grounded, "liquid", spot.liquid, "pose", spot.pose, "expanded", spot.expanded, "ledge", spot.ledge, "walks", spot.walks, "steps", [str(step.kind) + ">" + str(grid.spots[step.target].area) for step in [edge spot->:NavStep:->]], "solid", grid.sweep(spot.origin, spot.origin).start_solid, "live solid", app.level.collision.trace(spot.origin, spot.origin).start_solid, "from", [str(other.index) + "@" + str(int(other.origin.x)) + "," + str(int(other.origin.y)) + "," + str(int(other.origin.z)) + "/" + str(other.liquid) for other in [spot<-:NavStep:<-][?:NavSpot]][:4]);
                }
            }
        }
        atlas = read_level_graph(app.world, app.level, build, os.getenv("QP_PROOF_FALLS", "1") != "0");
        print("PROOF", spec, "read in", round(time.time() - began, 1), "s");
        for note in atlas.notes {
            print("PROOF", spec, note);
        }
        for gate in [atlas->:Guards:->][?:Gate] {
            print("PROOF", spec, "gate", gate.model, "needs", gate.needs, "bars", len([gate->:Bars:->]));
        }
        for opener in [atlas->:Offers:->][?:Opener] {
            print("PROOF", spec, "opener", opener.kind, opener.token, "at", int(opener.point.x), int(opener.point.y), int(opener.point.z), "from", len([opener->:DoneFrom:->]), "places");
        }
        started = time.time();
        proof = prove(atlas);
        print("PROOF", spec, "finishes", proof.finishes, "states", proof.states, "softlocks", proof.softlocks, "route", len(proof.route), "areas, in", round(time.time() - started, 2), "s", " ".join(proof.notes));
        for line in proof.barred {
            print("PROOF", spec, "barred", line);
        }
        for gate in [atlas->:Guards:->][?:Gate] {
            print("PROOF", spec, "gate", gate.model, "places", [place.area for place in [gate->:Bars:->][?:Place]]);
        }
        for opener in [atlas->:Offers:->][?:Opener] {
            print("PROOF", spec, "opener", opener.kind, opener.token, "places", [place.area for place in [opener->:DoneFrom:->][?:Place]]);
        }
        for trap in proof.traps {
            print("PROOF", spec, "softlock", trap);
            area = int(trap.split(" ")[0]);
            for place in graph_places(atlas) {
                if place.area == area {
                    print("PROOF", spec, "  moves", [str(move.to) + ":" + str(move.kind) + ("" if move.must else "?") for move in [edge place->:Move:->]], "deadly", place.deadly);
                }
            }
        }
        if proof.finishes {
            ledger = budget(atlas, proof.route, app.level.collision);
            print("PROOF", spec, "budget fights", ledger.fights, "lowest health", int(ledger.lowest), "after", ledger.worst, "end health", int(ledger.health), "armor", int(ledger.armor), "axed", ledger.axed, "ammo", ledger.ammo, "weapons", ledger.weapons);
            if os.getenv("QP_PROOF_LEDGER", "") {
                for line in ledger.lines {
                    print("PROOF", spec, "ledger", line);
                }
            }
        }
        # The proof against itself: each token left out must fail a level
        # that needs it.
        for token in proof.tokens {
            without = prove(atlas, [token]);
            print("PROOF", spec, "without", token, "finishes", without.finishes);
        }
        # A softlock put in on purpose: a fall from the start into a closed
        # room no sure way leaves.
        places = graph_places(atlas);
        pit = Place(area=max([place.area for place in places]) + 1, center=Vec3(x=0.0, y=0.0, z=-9999.0));
        atlas +>:Holds:+> pit;
        for place in places {
            if place.start {
                place +>:Move(kind=7, to=pit.area, must=False):+> pit;
            }
        }
        trapped = prove(atlas);
        print("PROOF", spec, "with a pit put in: finishes", trapped.finishes, "softlocks", trapped.softlocks);
    }
}
