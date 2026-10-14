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
        # QP_NAV_BOX=x,y,z: sweep the player's box 32 units each way from
        # there through the live level (doors as they start) and say what stops it.
        box_at = [float(word) for word in os.getenv("QP_NAV_BOX", "").split(",") if word];
        if len(box_at) == 3 {
            here = Vec3(x=box_at[0], y=box_at[1], z=box_at[2]);
            for way in [Vec3(x=32.0), Vec3(x=-32.0), Vec3(y=32.0), Vec3(y=-32.0), Vec3(z=-8.0)] {
                swept = app.level.collision.trace(here, here.add(way));
                print("NAV box", way.x, way.y, way.z, "fraction", round(swept.fraction, 3), "solid", swept.start_solid, swept.all_solid, "normal", swept.normal.x, swept.normal.y, swept.normal.z, "model", swept.model);
            }
        }
        # QP_NAV_FROM=x,y,z: plan from there instead of the start.
        from_point = [float(word) for word in os.getenv("QP_NAV_FROM", "").split(",") if word];
        if len(from_point) == 3 {
            origin = Vec3(x=from_point[0], y=from_point[1], z=from_point[2]);
        }
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
        # QP_NAV_GAP=1: where the start's part of the map comes nearest the
        # part each exit is in (what reaches the exit backwards), to find a
        # missing way between them.
        if os.getenv("QP_NAV_GAP", "") {
            backward: dict[int, list[int]] = {};
            for a in range(1, len(build.aas.areas)) {
                info = build.aas.areas[a];
                for r in range(info.first_reach, info.first_reach + info.reach_count) {
                    t = build.aas.reaches[r].area;
                    if t not in backward {
                        backward[t] = [];
                    }
                    backward[t].append(a);
                }
            }
            for portal in [app.world->:HasExit:->][?:LevelExit] {
                if not portal.volume.bounds {
                    continue;
                }
                box = portal.volume.bounds[0];
                goal_area = mesh.locate(box.mins.add(box.maxs).scale(0.5));
                into: set[int] = set([goal_area]);
                todo = [goal_area];
                while todo {
                    a = todo.pop();
                    for b in backward.get(a, []) {
                        if b not in into {
                            into.add(b);
                            todo.append(b);
                        }
                    }
                }
                pairs: list[tuple[float, int, int]] = [];
                for a in reached {
                    ca = build.aas.areas[a].center;
                    for b in into {
                        gap = build.aas.areas[b].center.sub(ca).length();
                        if gap < 400.0 {
                            pairs.append((gap, a, b));
                        }
                    }
                }
                # Every other island: how near it comes to what the start reaches.
                label: dict[int, int] = {};
                for a in range(1, len(build.aas.areas)) {
                    if a in reached or a in label {
                        continue;
                    }
                    stack = [a];
                    label[a] = a;
                    while stack {
                        cur = stack.pop();
                        cur_info = build.aas.areas[cur];
                        neighbours = [build.aas.reaches[r].area for r in range(cur_info.first_reach, cur_info.first_reach + cur_info.reach_count)];
                        neighbours.extend(backward.get(cur, []));
                        for n in neighbours {
                            if n not in reached and n not in label {
                                label[n] = a;
                                stack.append(n);
                            }
                        }
                    }
                }
                islands: dict[int, list[int]] = {};
                for (area, founder) in label.items() {
                    if founder not in islands {
                        islands[founder] = [];
                    }
                    islands[founder].append(area);
                }
                ranked: list[tuple[float, int, int, int]] = [];
                for (founder, members) in islands.items() {
                    if len(members) < 5 {
                        continue;
                    }
                    best_gap = 1.0e9;
                    pa = 0;
                    pb = 0;
                    for b in members {
                        cb = build.aas.areas[b].center;
                        for a in reached {
                            g = build.aas.areas[a].center.sub(cb).length();
                            if g < best_gap {
                                best_gap = g;
                                pa = a;
                                pb = b;
                            }
                        }
                    }
                    ranked.append((best_gap, len(members), pa, pb));
                }
                for (g, size, pa, pb) in sorted(ranked)[0:8] {
                    ca = build.aas.areas[pa].center;
                    cb = build.aas.areas[pb].center;
                    print("NAV island of", size, "areas, nearest", int(g), ": reached", int(ca.x), int(ca.y), int(ca.z), "island", int(cb.x), int(cb.y), int(cb.z), "exit side" if pb in into else "");
                }
                pairs = sorted(pairs)[0:6];
                print("NAV gap to", portal.destination, ": exit side has", len(into), "areas");
                for (gap, a, b) in pairs {
                    ca = build.aas.areas[a].center;
                    cb = build.aas.areas[b].center;
                    print("NAV   near", int(gap), "from", int(ca.x), int(ca.y), int(ca.z), "to", int(cb.x), int(cb.y), int(cb.z));
                }
            }
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
                leg_area = route.areas[k];
                leg_mover = area_mover_model(build.aas.areas[leg_area].contents) if leg_area > 0 else 0;
                print("NAV leg", int(point.x), int(point.y), int(point.z), "kind", kind, "area", leg_area, "mover", leg_mover);
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
