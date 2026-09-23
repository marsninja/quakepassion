"""Exercise combat and terminal states through the real desktop input loop."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, selected_weapon }
import from engine.world.inventory { AdjustInventory, quantity }
import from scripts.input_events { event, key }
import from engine.input.input { _capture, _release }

with entry {
    assert os.getenv("QP_VALIDATE_HOME", "") == os.getenv("HOME", "missing"),
        "Use a disposable HOME and matching QP_VALIDATE_HOME";
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock());
    try {
        for game in ["q1", "q2", "q3"] {
            name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
            app.load_destination(game, name);
            assert not app.menu.opened, app.menu.message;
            assert app.walking;
            # Freeze opponents while checking input and pause deterministically.
            enemies = [app.world->:HasOpponent:->][?:Opponent];
            for enemy in enemies { enemy.attack_wait = 1000.0; }
            # Starting loadouts differ; track the selected weapon's own ammunition.
            key(app, 50);
            rule = selected_weapon(app.combat);
            assert app.combat.weapon == rule.slot;
            starting = quantity(app.player.inventory, rule.ammo) if rule.ammo else 0;
            if rule.ammo {
                app.player.inventory spawn AdjustInventory(kind=rule.ammo, amount=5, capacity=500);
            }
            _capture();
            for frame in range(12) { assert app.step(); }
            event(6, 0);
            app.physics_clock.accumulator = app.physics_clock.tick_rate;
            assert app.step();
            event(5, 0);
            assert app.step();
            assert app.combat.shots == 1;
            if rule.ammo {
                assert quantity(app.player.inventory, rule.ammo) == starting + 5 - rule.cost;
            }
            key(app, 256);
            assert app.menu.opened;
            before = app.simulation_time;
            cooldown = app.combat.cooldown;
            event(6, 0);
            for frame in range(3) { assert app.step(); }
            event(5, 0);
            assert app.simulation_time == before and app.combat.cooldown == cooldown;
            assert app.combat.shots == 1;
            key(app, 256);
            assert not app.menu.opened;
            app.player.health = 0;
            before = app.simulation_time;
            for frame in range(3) { assert app.step(); }
            assert app.simulation_time == before;
            renderer.screenshot("qp_gameplay_dead_" + game + ".png");
            key(app, 257);
            assert app.player.health > 0 and app.combat.kills == 0;
            assert app.level.name == name and not app.menu.opened;
            if rule.ammo {
                assert quantity(app.player.inventory, rule.ammo) == starting;
            }
            if game == "q3" {
                app.combat.kills = 10;
                before = app.simulation_time;
                for frame in range(3) { assert app.step(); }
                assert app.simulation_time == before;
                renderer.screenshot("qp_gameplay_arena_won.png");
                key(app, 257);
                assert app.combat.kills == 0 and app.player.health > 0;
                assert app.level.name == name and not app.menu.opened;
            }
            print("GAMEPLAY INPUT PASS", game);
        }
    } finally {
        _release();
        app.audio.close();
        app.models.close();
        app.quake.close();
        renderer.close();
    }
}
