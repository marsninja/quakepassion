"""Native Quake I/II/III level viewer.

QP_GAME selects q1 (default), q2, or q3. QP_ASSETS overrides the game's asset
directory under ~/quake-assets; QP_MAP overrides its default map basename.
QP_GRAYBOX=1 selects the development arena. QP_SMOKE=1 captures deterministic
views and exits. All modes require a graphical display.
"""

import os;

import from engine.world.level { Level, load_level, spawn_player }
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
        directory = "baseq3" if game == "q3" else ("baseq2" if game == "q2" else "id1");
        map_name = "q3dm1" if game == "q3" else ("base1" if game == "q2" else "e1m1");
        level = load_level(
            world,
            os.getenv(
                "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + directory
            ),
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
