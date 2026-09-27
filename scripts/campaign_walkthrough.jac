"""Walk the whole Q1 and Q2 campaigns through the real game loop.

Starting from each campaign's first map, every level exit is followed. For each
exit the level is loaded as the menu loads it and the player is placed inside
the exit trigger (Q1 trigger_changelevel) or inside a touch trigger whose
chain reaches the exit (Q2 target_changelevel). The game then runs, scripted
input passing any stats screen, until the next level loads. Exits no touch
trigger reaches (buttons, shooting, monster deaths) are fired directly and
reported as such. Every map is also played for a few seconds, god mode on,
to catch crashes, stuck starts and runaway frame times.

Build natively and run from the repo root:
    jac build scripts/campaign_walkthrough.jac --native -o .jac/walkthrough
    DYLD_LIBRARY_PATH=vendor .jac/walkthrough      # QP_WALK_GAMES=q2 limits the games
"""
import os;
import math;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.input.input { Intent }
import from engine.world.world { World, Player }
import from engine.world.exits { LevelExit, HasExit, exit_map, exit_spawn }
import from engine.world.signals { Signal, Targets, Fire }
import from engine.world.triggers { TouchTrigger, HasTrigger }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

"""The middle of a trigger volume's first hull, or None when it has none."""
def volume_center(volume: CollisionMap) -> Vec3 | None {
    if not volume.bounds {
        return None;
    }
    box = volume.bounds[0];
    return box.mins.add(box.maxs).scale(0.5);
}

"""A touch trigger whose signal chain reaches `goal`, found by walking the
Targets edges backwards from it."""
def trigger_reaching(world: World, goal: Signal) -> TouchTrigger | None {

    frontier = [goal];
    seen: list[Signal] = [goal];
    depth = 0;
    while frontier and depth < 12 {
        next_frontier: list[Signal] = [];
        for signal in frontier {
            for source in [signal<-:Targets:<-][?:Signal] {
                if source not in seen {
                    seen.append(source);
                    next_frontier.append(source);
                }
            }
        }
        frontier = next_frontier;
        depth += 1;
    }
    for trigger in [world->:HasTrigger:->][?:TouchTrigger] {
        source = trigger.signal;
        if source is not None and source in seen and trigger.players and trigger.touchable {
            return trigger;
        }
    }
    return None;
}

"""Play `frames` frames with idle input; each frame's time in milliseconds."""
def settle(app: App, frames: int) -> list[float] {
    times: list[float] = [];
    for i in range(frames) {
        started = time.time();
        app.step();
        times.append((time.time() - started) * 1000.0);
    }
    return times;
}

"""Load `name` and reach exit number `which`, by standing in its trigger or a
touch trigger whose chain fires it (otherwise firing it directly), then play
until another level loads. Returns how it was reached and where it led."""
def follow(app: App, game: str, name: str, spot: str, which: int, frames: int) -> str {
    app.load_destination(game, name, spot);
    app.player.god_mode = True;
    app.skip_time = True;
    exits = [app.world->:HasExit:->][?:LevelExit];
    target = exits[which];
    placed = False;
    # A directional trigger (Q1/Q2 "angle") only fires for a player moving
    # along its facing: start behind its middle and walk through.
    facing = Vec3();
    if target.contact {
        center = volume_center(target.volume);
        if center is not None {
            app.player.pos = center.add(Vec3(z=app.level.collision.eye_height));
            placed = True;
        }
    } else {
        trigger = trigger_reaching(app.world, target.activation);
        if trigger is not None {
            center = volume_center(trigger.volume);
            if center is not None {
                facing = trigger.facing;
                # The first free spot behind the trigger (a doorway may be shut).
                stand = center;
                found = False;
                for back in [24.0, 48.0, 72.0, 96.0, 0.0] {
                    for rise in [0.0, 16.0, 32.0, -16.0] {
                        candidate = center.sub(facing.scale(back)).add(Vec3(z=rise));
                        if not found and not app.level.collision.trace(candidate, candidate).start_solid {
                            stand = candidate;
                            found = True;
                        }
                    }
                }
                app.player.pos = stand.add(Vec3(z=app.level.collision.eye_height));
                placed = True;
            }
        }
    }
    # A Q2 TRIGGERED trigger waits to be armed by a use (boss1: buttons
    # feeding a trigger_counter). Use what feeds it, once per press it still
    # needs, the way the buttons would.
    armed = "";
    if not target.contact {
        gate = trigger_reaching(app.world, target.activation);
        if gate is not None
            and gate.signal is not None
            and gate.signal.armable
            and not gate.signal.armed {
            for feeder in [gate.signal<-:Targets:<-][?:Signal] {
                for press in range(max(1, feeder.remaining)) {
                    feeder spawn Fire(emit=False, inventory=app.player.inventory);
                }
            }
            armed = "armed, ";
        }
    }
    walking = facing.length() > 0.5;
    if walking {
        app.player.yaw = math.atan2(facing.y, facing.x);
        app.player.pitch = 0.0;
    }
    if not placed {
        target.activation.pending = 1;
    }
    for i in range(frames) {
        # Pass stats screens and episode texts: fire on alternate frames.
        app.scripted = Intent(
            fire=i % 2 == 1, move=Vec3(y=1.0) if walking and i < 180 else Vec3()
        );
        app.step();
        if app.level.name != name or app.campaign_complete {
            app.scripted = Intent();
            return armed + ("touched " if placed else "fired ") + (
                "the end" if app.campaign_complete else app.level.name
            );
        }
    }
    app.scripted = Intent();
    return ("touched " if placed else "fired ") + "nothing";
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True, overlay=False);
    games = os.getenv("QP_WALK_GAMES", "q1,q2").split(",");
    problems: list[str] = [];
    for game in games {
        start = "start" if game == "q1" else "base1";
        queue: list[str] = [start];
        only = os.getenv("QP_WALK_ONLY", "");
        if only {
            queue = [spec.split(":")[1] for spec in only.split(",") if spec.split(":")[0] == game];
        }
        spawns: dict[str, str] = {start: ""};
        visited: list[str] = [];
        app.load_destination(game, start);
        if not app.audio.ready {
            app.audio.open(game, game_directory(game));
        }
        app.audio.volume = 0.0;
        app.smoke = False;
        app.walking = True;
        while queue {
            name = queue.pop(0);
            if name in visited {
                continue;
            }
            visited.append(name);
            try {
                app.load_destination(game, name, spawns.get(name, ""));
            } except Exception as error {
                problems.append(game + " " + name + ": load failed: " + str(error));
                print("WALK", game, name, "LOAD FAILED", error);
                continue;
            }
            if app.level.name != name {
                problems.append(game + " " + name + ": did not load");
                continue;
            }
            # A few seconds of play at the start, god mode on.
            app.player.god_mode = True;
            app.skip_time = True;
            start_pos = app.player.pos.add(Vec3());
            stuck = app.level.collision.trace(
                start_pos.sub(Vec3(z=app.level.collision.eye_height)),
                start_pos.sub(Vec3(z=app.level.collision.eye_height))
            ).start_solid;
            times = settle(app, 240);
            ordered = sorted(times);
            median = ordered[len(ordered) // 2];
            worst = ordered[-1];
            exits = [app.world->:HasExit:->][?:LevelExit];
            destinations = [portal.destination for portal in exits];
            print("WALK", game, name, "exits", len(exits), "median ms", round(median, 1), "worst ms", round(worst, 1), "start stuck", stuck, "alive", app.player.health > 0);
            if stuck {
                problems.append(game + " " + name + ": player start is inside solid");
            }
            if median > 50.0 {
                problems.append(game + " " + name + ": median frame " + str(round(median, 1)) + " ms");
            }
            if not exits and name not in ["end", "boss2"] {
                problems.append(game + " " + name + ": no exits");
            }
            tried: list[str] = [];
            for which in range(len(exits)) {
                destination = destinations[which];
                if destination in tried {
                    continue;
                }
                tried.append(destination);
                outcome = "";
                try {
                    outcome = follow(app, game, name, spawns.get(name, ""), which, 60 * 30);
                } except Exception as error {
                    outcome = "error " + str(error);
                }
                expected = exit_map(destination);
                print("WALK", game, name, "->", destination, ":", outcome);
                if not outcome.endswith(" " + expected) and not outcome.endswith("the end") {
                    problems.append(game + " " + name + " -> " + destination + ": " + outcome);
                }
                if not only
                    and not expected.endswith(".pcx")
                    and expected not in visited
                    and expected not in queue {
                    queue.append(expected);
                    spawns[expected] = exit_spawn(destination);
                }
            }
        }
        print("WALK", game, "visited", len(visited), "maps:", " ".join(visited));
    }
    print("WALK PROBLEMS", len(problems));
    for problem in problems {
        print("WALK PROBLEM", problem);
    }
    renderer.close();
}
