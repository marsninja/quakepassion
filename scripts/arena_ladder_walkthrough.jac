"""Walk Q3's single-player ladder through the real game loop.

Each arena is loaded as the menu loads it and played for QP_SECONDS (default
20) of frames with the player idle in god mode, so the bots fight each
other. Then the player is given the frag limit: the match must end, the
podium and postgame must start, and leaving the postgame must load the next
arena along the ladder. Frame times, bot frags and how far the bots moved
are printed per arena, with any problems at the end.

Build natively and run from the repo root:
    jac build scripts/arena_ladder_walkthrough.jac --native -o .jac/ladder
    DYLD_LIBRARY_PATH=vendor .jac/ladder      # QP_LADDER_ONLY=q3dm7,q3dm12 limits it
"""
import os;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.arena { ArenaMatch, Competes, match_of, standings }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.assets.library { AssetLibrary }
import from games.arenas { load_arenas, ladder }
import from engine.math.vec3 { Vec3 }

"""Arena names in ladder order."""
def ladder_names -> list[str] {
    library = AssetLibrary(game="q3");
    names: list[str] = [];
    try {
        library.open(game_directory("q3"));
        for arena in ladder(load_arenas(library)) {
            names.append(arena.map);
        }
    } finally {
        library.close();
    }
    return names;
}

"""Total frags scored by bots so far."""
def bot_frags(contest: ArenaMatch) -> int {
    total = 0;
    for row in standings(contest) {
        if not row.human {
            total += row.frags;
        }
    }
    return total;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True, overlay=False);
    names = ladder_names();
    only = os.getenv("QP_LADDER_ONLY", "");
    if only {
        names = [name for name in names if name in only.split(",")];
    }
    frames = int(float(os.getenv("QP_SECONDS", "20")) * 60.0);
    problems: list[str] = [];
    app.load_destination("q3", names[0]);
    if not app.audio.ready {
        app.audio.open("q3", game_directory("q3"));
    }
    app.audio.volume = 0.0;
    app.smoke = False;
    app.walking = True;
    for name in names {
        try {
            app.load_destination("q3", name);
        } except Exception as error {
            problems.append(name + ": load failed: " + str(error));
            print("LADDER", name, "LOAD FAILED", error);
            continue;
        }
        if app.level.name != name {
            problems.append(name + ": did not load");
            continue;
        }
        app.player.god_mode = True;
        app.skip_time = True;
        contest = match_of(app.world);
        if contest is None {
            problems.append(name + ": no match");
            continue;
        }
        # Skip the warmup countdown: the bots fight from the first frame.
        contest.warmup = 0.0;
        bots = [app.world->:HasOpponent:->][?:Opponent];
        starts: list[Vec3] = [bot.pos.add(Vec3()) for bot in bots];
        travelled: list[float] = [0.0 for bot in bots];
        times: list[float] = [];
        for i in range(frames) {
            started = time.time();
            app.step();
            times.append((time.time() - started) * 1000.0);
            if i % 30 == 29 {
                for j in range(len(bots)) {
                    travelled[j] += bots[j].pos.sub(starts[j]).length();
                    starts[j] = bots[j].pos.add(Vec3());
                }
            }
        }
        ordered = sorted(times);
        median = ordered[len(ordered) // 2];
        worst = ordered[-1];
        frags = bot_frags(contest);
        idle = len([d for d in travelled if d < 64.0]);
        print("LADDER", name, "bots", len(bots), "median ms", round(median, 1), "worst ms", round(worst, 1), "bot frags", frags, "idle bots", idle);
        if median > 25.0 {
            problems.append(name + ": median frame " + str(round(median, 1)) + " ms");
        }
        if bots and idle == len(bots) {
            problems.append(name + ": no bot moved");
        }
        # The player has the frag limit: the next frag (bots fragging each
        # other or themselves) ends the match into the podium, as the limit
        # is checked when a frag changes the scores. With no frag in time
        # (a lone bot against the idle player), the podium starts directly.
        for score in [edge contest->:Competes:->] {
            if score.human {
                score.frags = contest.fraglimit;
            }
        }
        how = "by frag";
        for i in range(frames) {
            app.step();
            if app.postgame is not None {
                break;
            }
        }
        if app.postgame is None {
            how = "forced";
            contest.finished = True;
            app.begin_podium(contest);
        }
        if app.postgame is None {
            problems.append(name + ": no postgame");
            continue;
        }
        expected = next_arena_name(names, name);
        app.finish_arena(contest);
        print("LADDER", name, "ended", how, "-> next", app.level.name, "(expected", expected + ")");
        if expected and app.level.name != expected {
            problems.append(name + ": left for " + app.level.name + ", expected " + expected);
        }
    }
    print("LADDER PROBLEMS", len(problems));
    for problem in problems {
        print("LADDER PROBLEM", problem);
    }
    renderer.close();
}

"""The arena after `name` in `names`, or "" at the end of the ladder."""
def next_arena_name(names: list[str], name: str) -> str {
    for i in range(len(names) - 1) {
        if names[i] == name {
            return names[i + 1];
        }
    }
    return "";
}
