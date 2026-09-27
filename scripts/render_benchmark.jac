"""Render benchmark: frame time and per-stage render cost on original maps.

Each map in QP_BENCH_MAPS is loaded as the menu loads it. The player stands
at the start in god mode while the view turns a full circle over QP_BENCH_FRAMES
frames (default 600), so every direction is drawn. For each map it prints the
median and 95th percentile frame time, the frame rate at the median, and the
median cost of each render stage (App.render_times). Run it on a quiet
machine and compare runs made back to back. With QP_BENCH_SHOTS=1 it also
saves four views per map, a quarter turn apart, as bench_<map>_<n>.png in the
working directory, for comparing renderers by eye.

    jac build scripts/render_benchmark.jac --native -o .jac/render-benchmark
    DYLD_LIBRARY_PATH=vendor .jac/render-benchmark
"""
import os;
import math;
import time;
import from engine.core.app { App, RenderTimes }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }

glob BENCH_DEFAULT: str = "q1:e1m1,q1:e4m7,q2:base1,q2:bunk1,q2:train,q3:q3dm1,q3:q3dm7,q3:q3dm11,q3:q3dm12,q3:q3tourney2";

"""The median of `values`."""
def median_of(values: list[float]) -> float {
    ordered = sorted(values);
    return ordered[len(ordered) // 2] if ordered else 0.0;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True, overlay=False);
    frames = int(os.getenv("QP_BENCH_FRAMES", "600"));
    shots = os.getenv("QP_BENCH_SHOTS", "") != "";
    specs = os.getenv("QP_BENCH_MAPS", BENCH_DEFAULT).split(",");
    opened: list[str] = [];
    for spec in specs {
        game = spec.split(":")[0];
        name = spec.split(":")[1];
        app.smoke = True;
        app.load_destination(game, name);
        if game not in opened {
            app.audio.close();
            app.audio.open(game, game_directory(game));
            opened.append(game);
        }
        app.audio.volume = 0.0;
        app.smoke = False;
        app.walking = True;
        app.player.god_mode = True;
        start_yaw = app.player.yaw;
        for i in range(60) {
            app.step();
        }
        times: list[float] = [];
        stages: dict[str, list[float]] = {
            "visible": [], "portal": [], "world": [], "models": [],
            "effects": [], "weapon": [], "hud": [], "present": []
        };
        for i in range(frames) {
            app.player.yaw = start_yaw + 2.0 * math.pi * float(i) / float(frames);
            app.player.pitch = 0.0;
            started = time.time();
            app.step();
            times.append((time.time() - started) * 1000.0);
            if shots and i % (frames // 4) == 0 {
                renderer.screenshot("bench_" + name + "_" + str(i // (frames // 4)) + ".png");
            }
            r = app.render_times;
            stages["visible"].append(r.visible);
            stages["portal"].append(r.portal);
            stages["world"].append(r.world);
            stages["models"].append(r.models);
            stages["effects"].append(r.effects);
            stages["weapon"].append(r.weapon);
            stages["hud"].append(r.hud);
            stages["present"].append(r.present);
        }
        ordered = sorted(times);
        median = ordered[len(ordered) // 2];
        p95 = ordered[(len(ordered) * 95) // 100];
        parts = [key + "=" + str(round(median_of(values), 2)) for (key, values) in stages.items()];
        print(
            "BENCH", game + ":" + name,
            "fps", round(1000.0 / max(median, 0.001), 1),
            "median_ms", round(median, 2),
            "p95_ms", round(p95, 2),
            "|", " ".join(parts)
        );
    }
    renderer.close();
}
