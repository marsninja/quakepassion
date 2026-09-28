"""Native Quake I/II/III and generated Passion expeditions.

QP_GAME selects q1 (default), q2, q3 or passion. QP_ASSETS overrides the game's
asset directory (the common parent for Passion). QP_MAP overrides its default
map basename; QP_SEED selects Passion's version-1 expedition seed.
QP_GRAYBOX=1 selects the development arena. QP_SMOKE=1 captures deterministic
views and exits. QP_CAPTURE=<frame>:<file.png> plays normally and saves one
full screenshot (HUD and weapon included) at that frame, then exits. All modes
require a graphical display. QP_CONFIG_DIR keeps the settings and bindings
somewhere other than HOME. Arguments starting with "+" run as console commands
after the configuration (quake.rc's stuffcmds): `./qp +map e1m2 +god`.
"""

import os;
import sys;

import from engine.world.level { Level, spawn_player }
import from games.levels { open_level }
import from engine.core.preferences { Preferences }
import from engine.core.menu { game_directory }
import from engine.core.app { App, HostCvars }
import from engine.console.shell { Shell, command_line_text }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from games.dev.arena { build_arena }


with entry {
    world = World();  # unrooted by design: worlds are rebuilt from data
    # every run; root is reserved for save games (phase 7)
    level = Level();
    # The first level honours the saved skill before the app reads the rest
    # of its settings into the same shell.
    shell = Shell();
    shell.boot();
    host = HostCvars();
    host.skill = shell.register(host.skill);
    try {
        shell.execute_text(Preferences().settings_text());
    } except Exception as error {
        shell.print("Settings: " + str(error));
    }
    skill = host.skill.integer;
    if os.getenv("QP_GRAYBOX", "") == "" {
        game = os.getenv("QP_GAME", "q1");
        map_name = "q3dm1" if game == "q3" else ("base1" if game == "q2" else "e1m1");
        if game == "passion" {
            map_name = "v2-" + os.getenv("QP_SEED", "1");
        }
        level = open_level(
            world,
            game_directory(game),
            os.getenv("QP_MAP", map_name),
            game,
            # Q1 and Q2 play the fifth skill (Q3's Nightmare!) as Nightmare.
            skill if game == "q3" else min(3, skill)
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
        smoke=(os.getenv("QP_SMOKE", "") != ""),
        shell=shell,
        host=host
    );
    # quake.rc's stuffcmds: `./qp +map e1m2 +god`.
    app.stuffed = command_line_text(sys.argv[1:]);
    # Quake II's newgame is "map *ntro.cin+base1": the introduction first.
    if os.getenv("QP_GRAYBOX", "") == "" and os.getenv("QP_GAME", "q1") == "q2" and os.getenv("QP_MAP", "") == "" {
        app.opening = "*ntro.cin+base1";
    }
    capture = os.getenv("QP_CAPTURE", "");
    if ":" in capture {
        app.capture_frame = int(capture.split(":", 1)[0]);
        app.capture_path = capture.split(":", 1)[1];
    }
    if os.getenv("QP_WALK", "1") != "0" and not app.smoke {
        app.toggle_movement();
    }
    app.run();
}
