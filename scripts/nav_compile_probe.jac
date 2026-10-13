"""Compile the navigation of maps as the game loads them and report what came
out: spots, ways, areas, reachabilities, how long it took, and whether the
router finds a way from the player's start to each exit.

    jac build scripts/nav_compile_probe.jac --native -o .jac/navprobe
    QP_MAPS=q1:e1m1,q2:base1 DYLD_LIBRARY_PATH=vendor .jac/navprobe"""
import os;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.bot_routes { build_navmesh, plan_route }
import from engine.nav.compile { compile_navigation, NavStep }
import from engine.world.objectives { exit_objectives }
import from engine.world.doors { Door, HasDoor }
import from engine.formats.aas { Aas, area_mover_model }

"""The areas reached from `start` over the reachabilities, breadth first."""
def reached_from(aas: Aas, start: int) -> set[int] {
    seen: set[int] = set([start]);
    frontier = [start];
    while frontier {
        nxt: list[int] = [];
        for area in frontier {
            info = aas.areas[area];
            for r in range(info.first_reach, info.first_reach + info.reach_count) {
                target = aas.reaches[r].area;
                if target not in seen {
                    seen.add(target);
                    nxt.append(target);
                }
            }
        }
        frontier = nxt;
    }
    return seen;
}
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    maps = os.getenv("QP_MAPS", "q1:e1m1").split(",");
    for spec in maps {
        parts = spec.split(":");
        game = parts[0];
        name = parts[1];
        app.load_destination(game, name);
        started = time.time();
        build = compile_navigation(app.world, app.level);
        seconds = time.time() - started;
        print("NAV", game, name, build.summary(), "seconds", round(seconds, 2));
        for note in build.notes {
            print("NAV note", note);
        }
        mesh = build_navmesh(app.world, build.aas, app.level.bsp);
        eye = app.level.collision.eye_height;
        origin = app.player.pos.sub(Vec3(z=eye));
        start_area = mesh.locate(origin);
        reached = reached_from(build.aas, start_area);
        print("NAV", name, "start area", start_area, "at", origin.x, origin.y, origin.z, "reaches", len(reached), "of", len(build.aas.areas) - 1);
        for door in [app.world->:HasDoor:->][?:Door] {
            record = app.level.bsp.models[door.model];
            print("NAV door", door.model, door.kind, "hulls", len(door.hulls), "travel", door.travel.x, door.travel.y, door.travel.z, "rest", door.rest.z, "box", record.mins.x, record.mins.y, record.mins.z, record.maxs.x, record.maxs.y, record.maxs.z);
        }
        # The edge of what the start reaches: reached areas with a way out
        # to nowhere new, furthest from the start first.
        far = sorted([(build.aas.areas[a].center.sub(origin).length(), a) for a in reached]);
        for pair in far[-8:] {
            c = build.aas.areas[pair[1]].center;
            print("NAV far", pair[1], c.x, c.y, c.z);
        }
        window = [float(word) for word in os.getenv("QP_NAV_DUMP", "").split(",") if word];
        grid = build.grid;
        if len(window) == 4 and grid is not None {
            for spot in grid.spots {
                o = spot.origin;
                if o.x >= window[0] and o.x <= window[2] and o.y >= window[1] and o.y <= window[3] {
                    ways = [str(step.kind) + ">" + str(int(grid.spots[step.target].origin.x)) + "," + str(int(grid.spots[step.target].origin.y)) + "," + str(int(grid.spots[step.target].origin.z)) for step in [edge spot->:NavStep:->]];
                    print("NAV spot", int(o.x), int(o.y), round(o.z, 1), "area", spot.area, "in", spot.area in reached, "mover", spot.mover, "liquid", spot.liquid, " ".join(ways));
                }
            }
        }
        closing = [int(word) for word in os.getenv("QP_NAV_CLOSE", "").split(",") if word];
        for area in range(1, len(build.aas.areas)) {
            if area_mover_model(build.aas.areas[area].contents) in closing {
                mesh.enable_area(area, False);
                print("NAV closed area", area, "of mover", area_mover_model(build.aas.areas[area].contents));
            }
        }
        target = [float(word) for word in os.getenv("QP_NAV_GOAL", "").split(",") if word];
        if len(target) == 3 {
            goal = Vec3(x=target[0], y=target[1], z=target[2]);
            route = plan_route(mesh, origin, goal, limit=4096);
            for k in range(50) {
                if not route.pending {
                    break;
                }
                mesh.advance_tables(1000000);
                route = plan_route(mesh, origin, goal, limit=4096);
            }
            print("NAV goal area", mesh.locate(goal), "found", route.found, "legs", len(route.points));
            for k in range(len(route.points)) {
                point = route.points[k];
                passage = route.passages[k] if k < len(route.passages) else None;
                kind = passage.kind if passage is not None else 0;
                print("NAV leg", int(point.x), int(point.y), int(point.z), "kind", kind, "area", route.areas[k]);
            }
        }
        for portal in [app.world->:HasExit:->][?:LevelExit] {
            chain = exit_objectives(app.world, portal);
            print("NAV exit", portal.destination, "touch volume", bool(portal.volume.bounds), "chain", len(chain));
            for action in chain {
                print("NAV   ", action.kind, int(action.point.x), int(action.point.y), int(action.point.z), "area", mesh.locate(action.point));
            }
            if not portal.volume.bounds {
                continue;
            }
            box = portal.volume.bounds[0];
            goal = box.mins.add(box.maxs).scale(0.5);
            route = plan_route(mesh, origin, goal, limit=4096);
            for k in range(50) {
                if not route.pending {
                    break;
                }
                mesh.advance_tables(1000000);
                route = plan_route(mesh, origin, goal, limit=4096);
            }
            print("NAV", name, "exit", portal.destination, "at", goal.x, goal.y, goal.z, "goal area", mesh.locate(goal), "found", route.found, "legs", len(route.points));
        }
    }
    renderer.close();
}
