"""Native Quake I/II/III and generated Passion expeditions.

QP_GAME selects q1 (default), q2, q3 or passion. QP_ASSETS overrides the game's
asset directory (the common parent for Passion). QP_MAP overrides its default
map basename; QP_SEED selects Passion's version-1 expedition seed.
QP_GRAYBOX=1 selects the development arena. QP_SMOKE=1 captures deterministic
views and exits. All modes require a graphical display.
"""

import os;

import from engine.world.level { Level, spawn_player }
import from games.levels { open_level }
import from engine.core.menu { game_directory }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from games.dev.arena { build_arena }


with entry {
    world = World();  # unrooted by design: worlds are rebuilt from data
    # every run; root is reserved for save games (phase 7)
    level = Level();
    if os.getenv("QP_GRAYBOX", "") == "" {
        game = os.getenv("QP_GAME", "q1");
        map_name = "q3dm1" if game == "q3" else ("base1" if game == "q2" else "e1m1");
        if game == "passion" { map_name = "v2-" + os.getenv("QP_SEED", "1"); }
        level = open_level(
            world,
            game_directory(game),
            os.getenv("QP_MAP", map_name),
            game
        );
        player = spawn_player(level);
    } else {
        player = build_arena(world);
    }
    app = App(
        world=world,
        level=level,
        player=player,
        renderer=Renderer(),
        clock=Clock(),
        smoke=(os.getenv("QP_SMOKE", "") != "")
    );
    if os.getenv("QP_WALK", "1") != "0" and not app.smoke {
        app.toggle_movement();
    }
    app.run();
}
