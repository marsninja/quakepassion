"""Frame spike probe: play Q3 arenas as the ladder walkthrough does (player
idle in god mode, bots fighting from the first frame) and print every frame
slower than QP_SPIKE_MS (default 50) with its render stages
(App.render_times) and the rest of the frame (simulation, audio). Also the
median, 95th and 99th percentile and worst frame per arena, and load time.

    jac build scripts/frame_spike_probe.jac --native -o .jac/spike-probe
    DYLD_LIBRARY_PATH=vendor .jac/spike-probe   # QP_SPIKE_MAPS=q3dm11,q3dm12
"""
import os;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.arena { match_of }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True, overlay=False);
    names = os.getenv("QP_SPIKE_MAPS", "q3dm11,q3dm12").split(",");
    frames = int(float(os.getenv("QP_SECONDS", "20")) * 60.0);
    limit = float(os.getenv("QP_SPIKE_MS", "50"));
    app.load_destination("q3", names[0]);
    if not app.audio.ready {
        app.audio.open("q3", game_directory("q3"));
    }
    app.audio.volume = 0.0;
    app.smoke = False;
    app.walking = True;
    for name in names {
        started = time.time();
        app.load_destination("q3", name);
        print("SPIKE", name, "load ms", round((time.time() - started) * 1000.0, 1));
        app.player.god_mode = True;
        app.skip_time = True;
        contest = match_of(app.world);
        if contest is not None {
            contest.warmup = 0.0;
        }
        times: list[float] = [];
        for i in range(frames) {
            started = time.time();
            app.step();
            spent = (time.time() - started) * 1000.0;
            times.append(spent);
            if spent >= limit {
                r = app.render_times;
                drawn = r.visible + r.portal + r.world + r.models + r.effects + r.weapon + r.hud + r.present;
                print(
                    "SPIKE", name, "frame", i, "ms", round(spent, 1),
                    "| visible", round(r.visible, 1), "portal", round(r.portal, 1),
                    "world", round(r.world, 1), "models", round(r.models, 1),
                    "effects", round(r.effects, 1), "weapon", round(r.weapon, 1),
                    "hud", round(r.hud, 1), "present", round(r.present, 1),
                    "| rest", round(spent - drawn, 1)
                );
            }
        }
        ordered = sorted(times);
        print(
            "SPIKE", name, "median_ms", round(ordered[len(ordered) // 2], 2),
            "p95_ms", round(ordered[(len(ordered) * 95) // 100], 2),
            "p99_ms", round(ordered[(len(ordered) * 99) // 100], 2),
            "worst_ms", round(ordered[-1], 1),
            "over", len([t for t in times if t >= limit])
        );
    }
    renderer.close();
}
