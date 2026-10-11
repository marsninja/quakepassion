"""Native Quake I/II/III and generated Passion expeditions.

QP_GAME selects q1 (default), q2, q3 or passion. QP_PACK selects one of a
game's content packs instead (hipnotic, rogue, q1r, dopa, mg1, mg3, q1ctf,
xatrix, groundzero, q2ctf, teamarena; see engine/assets/content.jac) and
starts on its `start` map when it has one. QP_ASSETS overrides the game's
asset directory (the common parent for Passion). QP_MAP overrides the default
map basename; QP_SEED selects Passion's expedition seed.
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
import from games.levels { open_level, saved_entities, override_path }
import from engine.core.preferences { Preferences }
import from engine.core.menu { game_directory }
import from engine.assets.content { play_pack, pack_start_map }
import from engine.core.app { App, HostCvars }
import from engine.console.shell { Shell, command_line_text }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from games.dev.arena { build_arena }
import from editor.studio { attach_studio }


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
        # A content pack is played by its game's rules.
        pack_id = os.getenv("QP_PACK", "");
        if pack_id != "" {
            game = play_pack(pack_id);
            if game == "" {
                print(
                    "quakepassion: QP_PACK names no content pack: " + repr(pack_id),
                    file=sys.stderr
                );
                sys.exit(2);
            }
        }
        # A mistyped game is a usage error, reported before anything loads;
        # left to load_level it would end the run as an uncaught exception.
        if game not in ["q1", "q2", "q3", "passion"] {
            print(
                "quakepassion: QP_GAME must be q1, q2, q3 or passion, not "
                    + repr(game),
                file=sys.stderr
            );
            sys.exit(2);
        }
        map_name = "q3dm1" if game == "q3" else ("base1" if game == "q2" else "e1m1");
        if pack_id != "" and pack_id != game {
            map_name = pack_start_map(pack_id);
        }
        if game == "passion" {
            map_name = "v2-" + os.getenv("QP_SEED", "1");
        }
        opened = os.getenv("QP_MAP", map_name);
        # Q1 and Q2 play the fifth skill (Q3's Nightmare!) as Nightmare.
        played = skill if game == "q3" else min(3, skill);
        try {
            level = open_level(world, game_directory(game), opened, game, played);
            player = spawn_player(level);
        } except Exception as error {
            if not saved_entities(game, opened) {
                raise error;
            }
            # Entities saved from the studio that do not load must not take
            # the map with them: fall back to the map as shipped.
            print(
                "quakepassion: the saved entities for "
                    + opened
                    + " do not load ("
                    + str(error)
                    + "); playing the map as shipped. Fix or delete "
                    + override_path(game, opened),
                file=sys.stderr
            );
            world = World();
            level = open_level(world, game_directory(game), opened, game, played, entities="");
            player = spawn_player(level);
        }
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
    # The editing studio (`edit`, F8); QP_EDIT=1 starts in it.
    attach_studio(app);
    # quake.rc's stuffcmds: `./qp +map e1m2 +god`.
    app.stuffed = command_line_text(sys.argv[1:]);
    if os.getenv("QP_EDIT", "") != "" {
        app.stuffed = "edit\n" + app.stuffed;
    }
    # Quake II's newgame is "map *ntro.cin+base1": the introduction first.
    if os.getenv("QP_GRAYBOX", "") == "" and os.getenv("QP_GAME", "q1") == "q2" and os.getenv("QP_MAP", "") == "" and os.getenv("QP_PACK", "") == "" {
        app.opening = "*ntro.cin+base1";
    }
    # Quake III starts with the id logo (and its introduction the first time).
    if os.getenv("QP_GRAYBOX", "") == "" and os.getenv("QP_GAME", "q1") == "q3" and os.getenv("QP_MAP", "") == "" and os.getenv("QP_PACK", "") == "" {
        app.opening = "idlogo.RoQ";
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
