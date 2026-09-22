"""Native fixed-view renderer and gameplay timing; no settings or save writes."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatTick }
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
    for game in ["q1", "q2", "q3", "passion"] {
        app.load_destination(
            game, "v1-42" if game == "passion" else (
                "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1")
            )
        );
        assert not app.menu.opened , app.menu.message;
        if not app.audio.ready { app.audio.open(game,game_directory(game)); }
        app.audio.volume = 0.0;
        resources = app.models.resources;
        for mode in ["full", "without_models", "full_repeat"] {
            if mode == "without_models" {
                app.models.resources = {};
            } else {
                app.models.resources = resources;
            }
            for i in range(30) {
                app.render_frame();
            }
            start = float(GetTime());
            for i in range(180) {
                app.render_frame();
            }
            seconds = float(GetTime()) - start;
            print(
                "PERF",
                game,
                mode,
                "ms/frame",
                seconds * 1000.0 / 180.0,
                "fps",
                180.0 / seconds
            );
        }
        app.player.health = 100000;
        start = float(GetTime());
        for i in range(120) {
            app.world spawn CombatTick(
                player=app.player,
                collision=app.level.collision,
                state=app.combat,
                dt=1.0 / 120.0
            );
        }
        seconds = float(GetTime()) - start;
        print("PERF", game, "combat ms/tick", seconds * 1000.0 / 120.0);
        app.smoke = False;
        app.walking = True;
        app.player.health = 100000;
        app.skip_time = True;
        for i in range(30) {
            assert app.step();
        }
        times: list[float] = [];
        for i in range(240) {
            start = float(GetTime());
            assert app.step();
            times.append((float(GetTime()) - start) * 1000.0);
        }
        ordered = sorted(times);
        print(
            "PERF",
            game,
            "app ms/frame median",
            ordered[120],
            "p95",
            ordered[228],
            "max",
            ordered[239]
        );
        renderer.screenshot("qp_perf_" + game + ".png");
        app.smoke = True;
    }
    app.audio.close();
    app.models.close();
    app.effects.close();
    app.quake.close();
    renderer.close();
}
