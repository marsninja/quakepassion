"""Native seeded expedition acceptance on a desktop with real assets.

A scripted bot drives the real game loop (doors, triggers, pickups, traversal,
combat in god mode, exits) along column routes from the playtester: every
objective room in progression order, then extraction. Captures cover the spawn,
the menu, each district, the tallest room, a combat flash and completion.
"""
import os;
import math;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, damage_opponent }
import from engine.world.models { ModelResource, HasModelResource }
import from engine.world.doors { Door, HasDoor }
import from engine.world.inventory { quantity }
import from engine.world.signals { Signal, Targets }
import from engine.input.input { Intent, _release }
import from engine.math.vec3 { Vec3 }
import from scripts.input_events { key, click }
import from games.passion.generate { survey_of, Survey }
import from games.passion.mission { Expedition, beats_of }
import from games.passion.layout { Site, Room, rooms_of, CELL }
import from games.passion.blueprint { Blueprint }
import from games.passion.playtest { Walkway, walkway, route_between, column_of }

def look_at(app: App, target: Vec3) {
    delta = target.sub(app.player.pos);
    app.player.yaw = math.atan2(delta.y, delta.x);
}

def tick(app: App, forward: bool) {
    app.scripted = Intent(move=Vec3(y=1.0 if forward else 0.0));
    app.skip_time = True;
    app.physics_clock.accumulator = app.physics_clock.tick_rate;
    app.step();
}

def stage_column(bp: Blueprint, room: Room) -> int {
    interior = bp.interiors[room.beat];
    lx = interior.stage % interior.width;
    ly = interior.stage // interior.width;
    return bp.index(CELL * room.x + 1 + lx, CELL * room.y + 1 + ly);
}

def column_point(bp: Blueprint, column: int) -> Vec3 {
    return Vec3(
        x=float(column % bp.width) * 32.0 + 16.0,
        y=float(column // bp.width) * 32.0 + 16.0,
        z=float(bp.floor[column])
    );
}

def far_apart(bp: Blueprint, a: int, b: int) -> bool {
    dx = abs(a % bp.width - b % bp.width);
    dy = abs(a // bp.width - b // bp.width);
    return dx + dy > 2;
}

def corner_point(bp: Blueprint, way: Walkway, corner: int, tokens: list[str]) -> Vec3 {
    return Vec3(
        x=float(corner % bp.width) * 32.0,
        y=float(corner // bp.width) * 32.0,
        z=float(way.stand(corner, tokens))
    );
}

# Walk a corner route under real physics; waypoints are thinned but every
# change of standing height keeps its own waypoint so stairs stay aligned.
def follow(
    app: App, bp: Blueprint, way: Walkway, tokens: list[str], path: list[int]
) -> bool {
    points: list[int] = [];
    hops: list[bool] = [];
    for index in range(len(path)) {
        corner = path[index];
        last = index == len(path) - 1;
        step = index > 0
            and way.stand(path[index - 1], tokens) != way.stand(corner, tokens);
        turn = 0 < index < len(path) - 1
            and (path[index + 1] - corner) != (corner - path[index - 1]);
        # Corners before and after a teleporter hop are always kept.
        hop = (0 < index and far_apart(bp, path[index - 1], corner))
            or (index < len(path) - 1 and far_apart(bp, corner, path[index + 1]));
        if last or step or turn or hop or index % 4 == 0 {
            points.append(corner);
            hops.append(0 < index and far_apart(bp, path[index - 1], corner));
        }
    }
    for number in range(1, len(points)) {
        corner = points[number];
        if app.expedition_complete {
            break;
        }
        target = corner_point(bp, way, corner, tokens);
        if hops[number] {
            # Walk across the pad (traversal triggers sweep movement) until the
            # teleporter moves us beside the target.
            pad = corner_point(bp, way, points[number - 1], tokens);
            for frame in range(600) {
                if Vec3(
                    x=target.x - app.player.pos.x, y=target.y - app.player.pos.y
                ).length()
                    < 96.0 {
                    break;
                }
                offset = Vec3(x=pad.x - app.player.pos.x, y=pad.y - app.player.pos.y);
                if offset.length() > 20.0 {
                    look_at(app, pad);
                } else {
                    app.player.yaw += 2.4;
                }
                tick(app, True);
            }
        }
        arrived = False;
        best = 1000000.0;
        moving = 0;
        for frame in range(8000) {
            if moving > 480 {
                break;
            }
            flat = Vec3(x=target.x - app.player.pos.x, y=target.y - app.player.pos.y);
            if flat.length() < 6.0 or app.expedition_complete {
                arrived = True;
                break;
            }
            # Fight through anything pinning the hull, as a player would: if the
            # waypoint is not getting closer, clear nearby foes.
            if frame % 60 == 59 {
                remaining = Vec3(
                    x=target.x - app.player.pos.x, y=target.y - app.player.pos.y
                ).length();
                if remaining > best - 8.0 {
                    clear_blockers(app);
                }
                best = min(best, remaining);
            }
            # Wait out an arena lockdown; its doors reopen on a timer.
            if locked_in(app) and frame > 200 {
                tick(app, False);
                continue;
            }
            moving += 1;
            look_at(app, target);
            tick(app, True);
        }
        if not arrived {
            previous = points[number - 1];
            print(
                "PASSION LEG previous",
                (previous % bp.width) * 32,
                (previous // bp.width) * 32,
                "hop",
                hops[number],
                "jumps here",
                way.jumps.get(previous, [])
            );
            print(
                "PASSION STUCK near",
                int(app.player.pos.x),
                int(app.player.pos.y),
                int(app.player.pos.z),
                "heading to",
                int(target.x),
                int(target.y),
                int(target.z)
            );
            print(
                "PASSION STATE health",
                app.player.health,
                "menu",
                app.menu.opened,
                "walking",
                app.walking,
                "finale",
                app.finale_active,
                "complete",
                app.expedition_complete,
                "velocity",
                round(app.player.velocity.length(), 1)
            );
            heading = Vec3(
                x=target.x - app.player.pos.x, y=target.y - app.player.pos.y
            ).normalized();
            for lift in [0.0, 18.0] {
                start = app.player.pos.add(Vec3(z=lift));
                hit = app.level.collision.trace(start, start.add(heading.scale(12.0)));
                print(
                    "PASSION PROBE lift",
                    lift,
                    "fraction",
                    round(hit.fraction, 3),
                    "solid",
                    hit.start_solid,
                    "model",
                    hit.model,
                    "normal",
                    round(hit.normal.x, 2),
                    round(hit.normal.y, 2),
                    round(hit.normal.z, 2)
                );
                if hit.hull >= 0 {
                    cell = app.level.collision.hulls[hit.hull];
                    print(
                        "PASSION HULL",
                        [
                            [
                                round(cell.planes[k].x, 1),
                                round(cell.planes[k].y, 1),
                                round(cell.planes[k].z, 1),
                                round(cell.distances[k], 1)
                            ] for k in range(len(cell.planes))
                        ]
                    );
                }
            }
            for enemy in [app.world->:HasOpponent:->][?:Opponent] {
                if enemy.pos.sub(app.player.pos).length() < 160.0 {
                    print(
                        "PASSION NEAR FOE",
                        enemy.rule.model,
                        "health",
                        enemy.health,
                        "dormant",
                        enemy.dormant,
                        int(enemy.pos.x),
                        int(enemy.pos.y),
                        int(enemy.pos.z)
                    );
                }
            }
            for door in [app.world->:HasDoor:->][?:Door] {
                middle = door.bounds.mins.add(door.bounds.maxs).scale(0.5);
                if Vec3(
                    x=middle.x - app.player.pos.x, y=middle.y - app.player.pos.y
                ).length()
                    < 160.0 {
                    print(
                        "PASSION NEAR DOOR",
                        door.kind,
                        door.state,
                        door.enabled,
                        door.keys,
                        door.names,
                        round(door.position, 2)
                    );
                }
            }
            return False;
        }
    }
    for frame in range(8) {
        tick(app, False);
    }
    return True;
}

def locked_in(app: App) -> bool {
    for door in [app.world->:HasDoor:->][?:Door] {
        locking = [
            name
            for name in door.names
            if name.startswith("lock_")
        ];
        if locking and door.position > 0.01 {
            middle = door.bounds.mins.add(door.bounds.maxs).scale(0.5);
            if middle.sub(app.player.pos).length() < 900.0 {
                return True;
            }
        }
    }
    return False;
}

# Whether a room's objective has visibly taken effect in the running game.
def objective_done(app: App, bp: Blueprint, grants: list[str]) -> bool {
    for token in grants {
        if token.startswith("key_") and quantity(app.player.inventory, token) <= 0 {
            keyed = [
                door
                for door in [app.world->:HasDoor:->][?:Door]
                if token in door.keys and door.unlocked
            ];
            if not keyed {
                return False;
            }
        }
        if token.startswith("switch:") or token.startswith("relay:") {
            names = [
                door.name
                for door in bp.doors
                if token in door.keys and door.name
            ];
            moving = [
                door
                for door in [app.world->:HasDoor:->][?:Door]
                if [
                    name
                    for name in door.names
                    if name in names
                ]
                    and door.state != "closed"
            ];
            if names and not moving {
                return False;
            }
        }
    }
    return True;
}

def clear_blockers(app: App) {
    for enemy in [app.world->:HasOpponent:->][?:Opponent] {
        if enemy.health > 0 and enemy.pos.sub(app.player.pos).length() < 160.0 {
            damage_opponent(enemy, 100000);
        }
    }
}

# A guardian is the opponent whose death signal targets its gate door.
def slay_guardian(app: App, doors: list[str]) {
    gates = [
        door.activation
        for door in [app.world->:HasDoor:->][?:Door]
        if [
            name
            for name in door.names
            if name in doors
        ]
    ];
    for enemy in [app.world->:HasOpponent:->][?:Opponent] {
        fired = [
            signal
            for signal in [enemy.activation->:Targets:->][?:Signal]
            if signal in gates
        ];
        if enemy.health > 0 and fired {
            damage_opponent(enemy, 100000);
        }
    }
}

def capture(app: App, renderer: Renderer, name: str, frames: int = 3) {
    for frame in range(frames) {
        app.render_frame();
    }
    renderer.screenshot(name);
}

with entry {
    assert os.getenv("QP_VALIDATE_HOME", "") == os.getenv("HOME", "missing");
    seed = os.getenv("QP_SEED", "42");
    name = "v2-" + seed;
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(), player=Player(), renderer=renderer, clock=Clock(), overlay=False
    );
    try {
        started = time.perf_counter();
        app.load_destination("passion", name);
        print("PASSION LOAD seconds", round(time.perf_counter() - started, 2));
        if app.menu.opened {
            print("PASSION LOAD FAILED:", app.menu.message);
        }
        assert not app.menu.opened , app.menu.message;
        assert app.level.bsp.game == "passion" and app.level.bsp.clusters > 0;
        found = survey_of(app.world);
        assert found is not None;
        record: Survey = found;
        plan = record.plan;
        bp = record.bp;
        site = record.site;
        assert plan is not None and bp is not None and site is not None;
        print("PASSION BRIEFING", record.briefing);
        assert not app.level.collision.trace(
            app.player.pos, app.player.pos
        ).start_solid;
        for source in ["q1:", "q2:"] {
            assert [
                resource
                for resource in [app.world->:HasModelResource:->][?:ModelResource]
                if resource.name.startswith(source)
            ] , "missing " + source + " models";
        }
        app.god_mode = True;
        app.player.god_mode = True;
        capture(app, renderer, "qp_passion.png");
        # Face the nearest wall from close range: a combat flash must light it.
        home = app.player.pos;
        home_yaw = app.player.yaw;
        nearest = 2.0;
        for quarter in range(4) {
            angle = float(quarter) * math.pi * 0.5;
            ahead = home.add(
                Vec3(x=math.cos(angle) * 400.0, y=math.sin(angle) * 400.0)
            );
            hit = app.level.collision.trace_point(home, ahead);
            if hit.fraction < nearest {
                nearest = hit.fraction;
                app.player.yaw = angle;
            }
        }
        reach = max(0.0, nearest * 400.0 - 48.0);
        app.player.pos = home.add(
            Vec3(x=math.cos(app.player.yaw) * reach, y=math.sin(app.player.yaw) * reach)
        );
        capture(app, renderer, "qp_passion_wall.png");
        app.combat.flash = 0.04;
        capture(app, renderer, "qp_passion_flash.png");
        assert app.level.lighting.dynamic;
        app.combat.flash = 0.0;
        app.render_frame();
        app.player.pos = home;
        app.player.yaw = home_yaw;
        key(app, 256);
        assert app.menu.opened and app.menu.game == 3 and name in app.menu.maps;
        renderer.screenshot("qp_passion_menu.png");
        key(app, 256);
        spawn_pos = app.player.pos;
        spawn_yaw = app.player.yaw;
        rooms = rooms_of(site);
        # One capture per district, looking from a room's entrance to its stage.
        shots = 0;
        districts: list[int] = [];
        for room in rooms {
            interior = bp.interiors[room.beat];
            if room.district in districts or not interior.landings or shots >= 4 {
                continue;
            }
            origin_x = CELL * room.x + 1;
            origin_y = CELL * room.y + 1;
            landing = interior.landings[0];
            column = bp.index(
                origin_x + landing % interior.width,
                origin_y + landing // interior.width
            );
            stand = column_point(bp, column);
            app.player.pos = Vec3(
                x=stand.x, y=stand.y, z=stand.z + app.level.collision.eye_height + 24.0
            );
            look_at(app, column_point(bp, stage_column(bp, room)));
            capture(app, renderer, "qp_passion_theme_" + str(shots) + ".png");
            districts.append(room.district);
            shots += 1;
        }
        assert shots >= 2 , "expected at least two districts";
        tallest = rooms[0];
        for room in rooms {
            if room.span + room.ceiling > tallest.span + tallest.ceiling {
                tallest = room;
            }
        }
        high = column_point(bp, stage_column(bp, tallest));
        tall_interior = bp.interiors[tallest.beat];
        if tall_interior.landings {
            entry_cell = tall_interior.landings[0];
            stand = column_point(
                bp,
                bp.index(
                    CELL * tallest.x + 1 + entry_cell % tall_interior.width,
                    CELL * tallest.y + 1 + entry_cell // tall_interior.width
                )
            );
            app.player.pos = Vec3(
                x=stand.x, y=stand.y, z=stand.z + app.level.collision.eye_height + 24.0
            );
        }
        look_at(app, high);
        capture(app, renderer, "qp_passion_vertical.png");
        # Walkthrough from the spawn under real physics.
        app.player.pos = spawn_pos;
        app.player.yaw = spawn_yaw;
        app.player.velocity = Vec3();
        way: Walkway = walkway(bp, site, True);
        tokens: list[str] = [];
        beats = beats_of(plan);
        targets: list[int] = [
            beat
            for beat in plan.route
            if [
                token
                for token in beats[beat].grants
                if not token.startswith("open:")
            ]
        ];
        goal = [
            beat.id
            for beat in beats
            if beat.kind == "goal"
        ][0];
        for beat in targets + [goal] {
            room = rooms[beat];
            there = stage_column(bp, room);
            # Approach, then confirm the objective took effect; retry after
            # clearing anything that knocked the bot off it.
            for attempt in range(4) {
                here = way.corner(
                    column_of(bp, app.player.pos.x, app.player.pos.y), tokens
                );
                path = route_between(way, here, there, tokens);
                assert path , "No route to room " + str(beat) + " with " + str(tokens);
                assert follow(app, bp, way, tokens, path) , "Route blocked toward room "
                    + str(beat);
                for frame in range(30) {
                    tick(app, False);
                }
                if objective_done(app, bp, beats[beat].grants)
                    or app.expedition_complete {
                    break;
                }
                clear_blockers(app);
            }

            for token in beats[beat].grants {
                if token.startswith("guardian:") {
                    slay_guardian(
                        app,
                        [
                            door.name
                            for door in bp.doors
                            if token in door.keys and door.name
                        ]
                    );
                }
                if token not in tokens and not token.startswith("open:") {
                    tokens.append(token);
                }
            }
            for frame in range(60) {
                tick(app, False);
            }
            print("PASSION ROUTE", room.kind, beat, "tokens", tokens);
            if os.getenv("QP_BOT_TRACE", "") {
                for door in [app.world->:HasDoor:->][?:Door] {
                    print(
                        "PASSION MOVER",
                        door.kind,
                        door.model,
                        door.names,
                        door.state,
                        round(door.position, 2)
                    );
                }
                print(
                    "PASSION AT",
                    int(app.player.pos.x),
                    int(app.player.pos.y),
                    int(app.player.pos.z)
                );
            }
            if app.expedition_complete {
                break;
            }
        }
        for frame in range(120) {
            if app.expedition_complete {
                break;
            }
            tick(app, False);
        }
        assert app.expedition_complete , "Extraction was not reached";
        app.scripted = None;
        capture(app, renderer, "qp_passion_complete.png");
        app.quicksave();
        assert app.notice == "Saved - F9 to load" , app.notice;
        app.load_destination("q1", "e1m1");
        app.quickload();
        assert app.notice == "Loaded"
            and app.level.name == name
            and app.expedition_complete;
        key(app, 257);
        assert not app.expedition_complete and app.level.name == name;
        app.load_destination("passion", "v1-42");
        assert app.menu.opened and app.level.name == name;
        key(app, 256);
        key(app, 256);
        click(app, 865, 165);
        assert app.menu.game == 3 and app.menu.maps;
        selected = app.menu.maps[app.menu.selected];
        assert selected.startswith("v2-");
        key(app, 257);
        assert not app.menu.opened and app.level.name == selected;
        print(
            "PASSION PASS: mixed assets, districts, walkthrough of every objective, extraction, persistence, replay, menu seeds, rollback"
        );
    } finally {
        _release();
        app.audio.close();
        app.models.close();
        app.quake.close();
        renderer.close();
    }
}
