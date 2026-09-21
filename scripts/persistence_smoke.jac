"""Exercise application save/load with HOME set to a disposable validation directory."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.preferences { Preferences }
import from engine.core.savegame { read_save, write_save }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.world.combat { Opponent, HasOpponent }

with entry {
    assert os.getenv("QP_VALIDATE_HOME", "") == os.getenv("HOME", "missing"),
        "Set HOME and QP_VALIDATE_HOME to the same disposable directory";
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        app.load_destination(game, name);
        assert not app.menu.opened, app.menu.message;
        app.walking = True;
        app.player.health = 57;
        app.player.inventory spawn AdjustInventory(kind="shells", amount=7, capacity=100);
        app.combat.kills = 2;
        enemies = [app.world->:HasOpponent:->][?:Opponent];
        assert len(enemies) > 0;
        enemies[0].health = 0;
        enemies[0].visual.visible = False;
        app.quicksave();
        assert app.notice == "Saved - F9 to load", app.notice;
        path = os.getenv("HOME", "") + "/.quakepassion-save.txt";
        assert not os.path.exists(path + ".tmp");
        saved = read_save(path);
        app.player.health = 1;
        app.combat.kills = 0;
        app.quickload();
        assert app.notice == "Loaded", app.notice;
        assert app.player.health == 57 and app.combat.kills == 2;
        assert quantity(app.player.inventory, "shells") == 7;
        enemies = [app.world->:HasOpponent:->][?:Opponent];
        assert enemies[0].health == 0 and not enemies[0].visual.visible;
        for frame in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_persistence_" + game + ".png");
        # A malformed entity record must not replace the current playable world.
        write_save(path, saved + "INVALID\n");
        app.quickload();
        assert app.notice != "Loaded";
        assert app.player.health == 57 and app.combat.kills == 2;
        assert app.level.name == name;
        write_save(path, saved);
        # Return from a different game through the same quickload entry point.
        other = "q2" if game == "q1" else "q1";
        app.load_destination(other, "base1" if other == "q2" else "e1m1");
        assert not app.menu.opened, app.menu.message;
        app.quickload();
        assert app.notice == "Loaded", app.notice;
        assert app.level.bsp.game == game and app.player.health == 57;
        print("PERSISTENCE PASS", game);
    }
    app.renderer.fov = 85.0;
    app.audio.volume = 0.4;
    app.save_preferences();
    assert app.menu.message == "Settings saved", app.menu.message;
    preferences = Preferences();
    preferences.load();
    assert preferences.fov == 85.0 and abs(preferences.volume - 0.4) < 0.0001;
    app.reset_settings();
    preferences.load();
    assert preferences.fov == 72.0 and preferences.volume == 0.25;
    print("PREFERENCES PASS");
    app.audio.close();
    app.models.close();
    app.quake.close();
    renderer.close();
}
