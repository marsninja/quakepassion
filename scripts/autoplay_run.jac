"""Watch the player bot play: the real game loop in a window, the bot at the
controls, a line every few seconds and one when the level changes.

    jac build scripts/autoplay_run.jac --native -o .jac/autoplay
    QP_RUN=q1:e1m1 QP_SECONDS=120 DYLD_LIBRARY_PATH=vendor .jac/autoplay

QP_KILL=<seconds> kills the player once at that time (to see a restart);
QP_GOD=1 plays in god mode; QP_AUTOPLAY_SHOTS works as in qp."""
import os;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.player_bot { PlayerBot }
import from engine.core.savegame { unpack_campaign }

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    spec = os.getenv("QP_RUN", "q1:e1m1").split(":");
    game = spec[0];
    name = spec[1];
    seconds = float(os.getenv("QP_SECONDS", "120"));
    kill_at = float(os.getenv("QP_KILL", "-1"));
    app.load_destination(game, name);
    if not app.audio.ready {
        app.audio.open(game, game_directory(game));
    }
    app.walking = True;
    bot = PlayerBot();
    bot.shot_every = float(os.getenv("QP_AUTOPLAY_SHOTS", "0") or "0");
    if not os.getenv("QP_NOBOT", "") {
        app.autoplay = bot;
    }
    if os.getenv("QP_SAVEDUMP", "") {
        tags: dict[str, int] = {};
        for line in unpack_campaign(app.entry_save).active.splitlines() {
            word = line.split(" ")[0] if line else "";
            tags[word] = tags.get(word, 0) + 1;
        }
        print("RUN entry save records", tags);
        app.restart_level();
        print("RUN restart without play:", app.menu.message if app.menu.opened else "ok");
    }
    if os.getenv("QP_GOD", "") {
        app.player.god_mode = True;
    }
    started = time.time();
    level = app.level;
    killed = False;
    while time.time() - started < seconds {
        if not app.step() {
            break;
        }
        played = time.time() - started;
        if kill_at >= 0.0 and played > kill_at and not killed {
            killed = True;
            print("RUN kill at", round(played, 1));
            app.host_command(["kill"]);
        }
        if app.level is not level {
            level = app.level;
            print("RUN level", app.level.name, "at", round(played, 1), "s");
        }
        if app.menu.opened and app.menu.message {
            print("RUN menu:", app.menu.message);
        }
    }
    print("RUN end", app.level.name, "health", app.player.health, "after", round(time.time() - started, 1), "s");
    renderer.close();
}
