"""Native campaign transitions and failed-load rollback through the app loop."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.exits { LevelExit, HasExit, exit_map }
import from engine.input.input { Intent }
import from engine.world.inventory { quantity }

with entry {
    renderer = Renderer();
    renderer.open_window();
    for game in ["q1", "q2"] {
        name = "e1m1" if game == "q1" else "base1";
        world = World();
        level = load_level(world, game_directory(game), name, game);
        app = App(
            world=world,
            level=level,
            player=spawn_player(level),
            renderer=renderer,
            clock=Clock(),
            walking=True,
            overlay=False,
            culling=False
        );
        app.quake.upload(level);
        app.player.health = 73;
        app.player.armor = 42;
        inventory = app.player.inventory;
        exits = [world->:HasExit:->][?:LevelExit];
        assert len(exits) > 0;
        exits[0].activation.pending = 1;
        app.menu.opened = True;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        app.skip_time = True;
        assert app.step();
        assert app.level.name == name;
        app.menu.opened = False;
        app.physics_clock.accumulator = app.physics_clock.tick_rate;
        app.skip_time = True;
        assert app.step();
        # Q1 exits pause on the intermission stats until a key after 2 s.
        if app.stats_screen {
            assert app.level.name == name;
            app.stats_wait = 0.0;
            app.scripted = Intent(fire=True);
            assert app.step();
            app.scripted = None;
        }
        assert app.level.name == exit_map(exits[0].destination);
        assert app.walking and not app.menu.opened;
        assert app.player.health == 73 and app.player.armor == 42;
        # The carried inventory is a copy (keys and unit flags filtered).
        assert quantity(app.player.inventory, "shells") >= quantity(inventory, "shells");
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_exit_" + game + "_arrived.png");
        before = app.world;
        app.load_destination(game, "qp_missing_map");
        assert app.world is before and app.menu.opened;
        assert app.menu.message.startswith("Cannot load level:");
        app.menu.opened = False;
        for i in range(3) {
            app.render_frame();
        }
        print("EXIT RENDER PASS", game, name, "to", app.level.name, "rollback passed");
        app.quake.close();
    }
    renderer.close();
}
