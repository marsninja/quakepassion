"""Look at a level from given places, by eye:

    jac build scripts/passion_look.jac --native -o .jac/qp-look
    QP_LOOK_MAP=pfh-3 QP_LOOK_AT="x y z yaw pitch; ..." DYLD_LIBRARY_PATH=vendor .jac/qp-look

The real game loads the level (QP_LOOK_GAME, default passion; QP_LOOK_MAP) and
a view is saved from each place of QP_LOOK_AT (feet height, degrees), as
<prefix>_<n>.png in the working directory (QP_LOOK_PREFIX, default look)."""
import os;
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.math.vec3 { Vec3 }

with entry {
    game = os.environ.get("QP_LOOK_GAME", "passion");
    map_name = os.environ.get("QP_LOOK_MAP", "pfh-1");
    prefix = os.environ.get("QP_LOOK_PREFIX", "look");
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    app.host.overlay.assign("0");
    app.load_destination(game, map_name);
    if app.menu.opened {
        print("LOOK load failed: " + app.menu.message);
    }
    eye = app.level.collision.eye_height;
    for (number, view) in enumerate(os.environ.get("QP_LOOK_AT", "").split(";")) {
        words = [float(word) for word in view.split()];
        if len(words) < 4 {
            continue;
        }
        app.player.pos = Vec3(x=words[0], y=words[1], z=words[2] + eye);
        app.player.yaw = math.radians(words[3]);
        app.player.pitch = math.radians(words[4]) if len(words) > 4 else 0.0;
        for frame in range(3) {
            app.render_frame();
        }
        name = prefix + "_" + str(number) + ".png";
        renderer.screenshot(name);
        print("LOOK " + name);
    }
}
