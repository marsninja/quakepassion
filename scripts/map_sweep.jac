"""Acceptance sweep: every original Q1, Q2 and Q3 map loads through the game,
runs two seconds of simulation with its monsters, movers and effects, and
renders. Failures are reported per map rather than stopping the sweep."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { LevelMenu }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent }

with entry {
    only = os.getenv("QP_SWEEP_GAMES", "q1,q2,q3").split(",");
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(),
        player=Player(),
        renderer=renderer,
        clock=Clock(),
        save_path=".jac/map-sweep-save.txt",
        smoke=True
    );
    failures: list[str] = [];
    total = 0;
    os.makedirs(".jac/screenshots/sweep", exist_ok=True);
    for index in range(3) {
        menu = LevelMenu();
        menu.game = index;
        game = menu.games[index];
        if game not in only {
            continue;
        }
        menu.scan();
        for name in menu.maps {
            total += 1;
            try {
                app.load_destination(game, name);
                if not app.level.active or app.menu.opened {
                    failures.append(game + "/" + name + ": " + app.menu.message);
                    print("SWEEP FAIL", game, name, app.menu.message);
                    app.menu.opened = False;
                    continue;
                }
                app.player.god_mode = True;
                for tick in range(240) {
                    app.physics_clock.accumulator = app.physics_clock.tick_rate;
                    app.skip_time = True;
                    app.step();
                }
                monsters = [enemy for enemy in [app.world->:HasOpponent:->][?:Opponent]];
                alive = len([enemy for enemy in monsters if enemy.health > 0]);
                renderer.screenshot(".jac/screenshots/sweep/" + game + "_" + name + ".png");
                print("SWEEP OK", game, name, "faces", app.last_drawn, "opponents", len(monsters), "alive", alive);
            } except Exception as error {
                failures.append(game + "/" + name + ": " + type(error).__name__ + ": " + str(error));
                print("SWEEP FAIL", game, name, type(error).__name__, str(error));
                app.menu.opened = False;
            }
        }
    }
    renderer.close();
    print("SWEEP", total, "maps", len(failures), "failures");
    for failure in failures {
        print("  ", failure);
    }
    assert not failures;
}
