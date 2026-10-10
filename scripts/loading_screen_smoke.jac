"""Each game's loading screen as a level load shows it, saved to
.jac/screenshots/loading/: Quake's gfx/loading.lmp over the view and status
bar, Quake II's pics/loading.pcx over the last frame and over black after a
film, and Quake III's information screen with the next arena's levelshot.

    jac build scripts/loading_screen_smoke.jac --native -o .jac/loading-screen-smoke
    DYLD_LIBRARY_PATH=vendor .jac/loading-screen-smoke
"""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }

"""Draw the loading screen for `following` and save it. It is drawn twice,
so the capture reads a frame that was presented."""
def shoot(app: App, game: str, following: str, name: str, black: bool = False) {
    for attempt in range(2) {
        app.loading_black = black;
        app.draw_loading(game, following);
    }
    app.renderer.screenshot(".jac/screenshots/loading/" + name);
    print("LOADING SHOT", name);
}

with entry {
    os.makedirs(".jac/screenshots/loading", exist_ok=True);
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    app.host.overlay.assign("0");
    for (game, first, following) in [("q1", "e1m1", "e1m2"), ("q2", "base1", "base2"), ("q3", "q3dm1", "q3dm7")] {
        app.smoke = True;
        app.load_destination(game, first);
        assert app.level.name == first;
        if game == "q3" {
            app.audio.close();
            app.audio.open("q3", game_directory("q3"));
            app.audio.volume.assign("0");
        }
        app.smoke = False;
        app.walking = True;
        app.host.overlay.assign("0");
        for frame in range(3) {
            app.render_frame();
        }
        assert app.hud.ready , game;
        assert game == "q3" or app.hud.has_pic("loading") , game;
        shoot(app, game, following, game + "_loading.png");
        if game == "q2" {
            shoot(app, game, following, "q2_loading_after_film.png", True);
        }
        if game == "q3" {
            assert app.hud.has_pic("levelshot") and app.hud.has_pic("levelshot_detail");
            # An arena without a levelshot takes menu/art/unknownmap.
            shoot(app, game, "no_such_arena", "q3_loading_unknown.png");
            assert not app.hud.has_pic("levelshot") and app.hud.has_pic("unknownmap");
        }
    }
    renderer.close();
    print("LOADING SCREEN SMOKE PASSED");
}
