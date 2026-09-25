"""Level-change leak probe: load the listed maps one after another through
App.load_destination (the menu / changelevel path) and time 240 app frames
after each load. Memory is sampled from outside (see
docs/performance-status.md): the probe prints one LOAD line per map so a
wrapper can read the process RSS between loads.

QP_MAPS is a comma list of game:map (default: base1 five times); QP_FRAMES
overrides the frame count."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from vendor.raylib { def GetTime -> f64;  }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(),
        player=Player(),
        renderer=renderer,
        clock=Clock(),
        smoke=True,
        overlay=False
    );
    frames = int(os.getenv("QP_FRAMES", "240"));
    specs = os.getenv(
        "QP_MAPS", "q2:base1,q2:base1,q2:base1,q2:base1,q2:base1"
    ).split(",");
    load = 0;
    for spec in specs {
        parts = spec.split(":");
        game = parts[0];
        name = parts[1];
        start = float(GetTime());
        app.smoke = True;
        app.load_destination(game, name);
        assert not app.menu.opened , app.menu.message;
        load_ms = (float(GetTime()) - start) * 1000.0;
        if not app.audio.ready {
            app.audio.open(game, game_directory(game));
        }
        app.audio.volume = 0.0;
        app.smoke = False;
        app.walking = True;
        app.player.god_mode = True;
        app.skip_time = True;
        times: list[float] = [];
        for i in range(frames) {
            t = float(GetTime());
            app.step();
            times.append((float(GetTime()) - t) * 1000.0);
        }
        ordered = sorted(times);
        load += 1;
        print(
            "LOAD",
            load,
            game,
            name,
            "load_ms",
            round(load_ms, 1),
            "median_ms",
            round(ordered[len(ordered) // 2], 2),
            "p95_ms",
            round(ordered[(len(ordered) * 95) // 100], 2)
        );
    }
    renderer.close();
}
