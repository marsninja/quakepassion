"""QuakePassion — Phase 1: First Light.

Fly through two graybox rooms (WASD + mouse, Space/Shift for up/down).
C toggles portal culling, F3 toggles the debug overlay.

Set QP_SMOKE=1 to run the headless validation script instead: it steers
the camera through known states, screenshots each, and exits."""

import os;

import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from games.dev.arena { build_arena }


with entry:__main__ {
    world = World();    # unrooted by design: worlds are rebuilt from data
                        # every run; root is reserved for save games (phase 7)
    player = build_arena(world);
    app = App(
        world=world,
        player=player,
        renderer=Renderer(),
        clock=Clock(),
        smoke=("QP_SMOKE" in os.environ)
    );
    app.run();
}
