"""Bounded normal-mode walkthroughs through the actual game loop.

    jac build scripts/passion_walkthrough.jac --native -o .jac/qp-walk
    QP_HEADLESS=1 QP_SEEDS="4 25 84 100" .jac/qp-walk

Each seed starts with its normal inventory. The player bot must complete
the level within QP_WALK_SECONDS (default 600 simulation seconds), with at
most QP_WALK_DEATHS deaths (default 3). No warping, god mode, or inventory
grants are used. Fixed simulation ticks and uncapped rendering let the run
advance faster than real time. QP_CONFIG_DIR can isolate preferences.
Prints one WALK JSON result per seed and exits unsuccessfully on a failure.
"""
import os;
import sys;
import json;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.player_bot { PlayerBot }
import from games.passion.generate { level_name }

def walk(app: App, seed: int, seconds: float, max_deaths: int) -> dict[str, any] {
    name = level_name(seed, 1);
    app.autoplay = None;
    app.host.skill.assign(os.getenv("QP_WALK_SKILL", "1"));
    app.host.god.assign("0");
    app.load_destination("passion", name);
    if app.menu.opened {
        return {"seed": seed, "status": "fail", "reason": "load: " + app.menu.message};
    }
    app.player.god_mode = False;
    app.walking = True;
    app.fixed_dt = 1.0 / 60.0;
    app.renderer.set_frame_limit(0);
    bot = PlayerBot();
    traces = os.getenv("QP_WALK_TRACES", ".jac/walkthroughs");
    os.makedirs(traces, exist_ok=True);
    bot.trace.path = traces + "/seed_" + str(seed) + ".jsonl";
    app.autoplay = bot;
    deaths = 0;
    was_dead = False;
    began = time.time();
    ticks = 0;
    outcome = "simulation budget exhausted";
    while ticks < int(seconds * 60.0) {
        app.skip_time = False;
        if not app.step() {
            outcome = "game loop ended";
            break;
        }
        ticks += 1;
        if app.expedition_complete or app.level.name != name {
            return {
                "seed": seed,
                "status": "pass",
                "simulation_seconds": float(ticks) / 60.0,
                "wall_seconds": time.time() - began,
                "deaths": deaths,
                "kills": app.combat.kills
            };
        }
        dead = app.player.health <= 0;
        if dead and not was_dead {
            deaths += 1;
        }
        was_dead = dead;
        if deaths >= max_deaths {
            outcome = "death budget exhausted";
            break;
        }
    }
    app.renderer.screenshot(traces + "/seed_" + str(seed) + ".png");
    return {
        "seed": seed,
        "status": "fail",
        "reason": outcome,
        "simulation_seconds": float(ticks) / 60.0,
        "wall_seconds": time.time() - began,
        "deaths": deaths,
        "kills": app.combat.kills,
        "goal": bot.goal_name,
        "mode": bot.mind.current
    };
}

with entry {
    renderer = Renderer();
    renderer.cvars.width.assign("640");
    renderer.cvars.height.assign("360");
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    app.configure();
    failed = 0;
    for word in os.getenv("QP_SEEDS", "4").split() {
        result = walk(
            app,
            int(word),
            float(os.getenv("QP_WALK_SECONDS", "600")),
            int(os.getenv("QP_WALK_DEATHS", "3"))
        );
        print("WALK " + json.dumps(result));
        if result["status"] != "pass" {
            failed += 1;
        }
    }
    renderer.close();
    sys.exit(1 if failed else 0);
}
