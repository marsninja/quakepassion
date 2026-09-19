"""Quake 1 BSP viewer. Defaults to ~/quake-assets/id1 and e1m1.

QP_ASSETS selects the id1 directory; QP_MAP selects a map basename.
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
        level = load_level(
            world,
            os.getenv("QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/id1"),
            os.getenv("QP_MAP", "e1m1")
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
    app.run();
}
