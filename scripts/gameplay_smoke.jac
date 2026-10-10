"""Exercise combat and terminal states through the real desktop input loop."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, selected_weapon }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.world.arena { match_of, Competes }
import from engine.world.demise { Mortality, HasMortality, mortality_of }
import from scripts.input_events { event, key }
import from engine.input.input { _capture, _release }

"""Whether `fallen` is still the death of the app's player (no restart yet)."""
def still_lying(fallen: Mortality, app: App) -> bool {
    return fallen in [app.player->:HasMortality:->][?:Mortality];
}

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
            contest = match_of(app.world);
            if game == "q3" {
                # Skip the arena's prepare-to-fight countdown.
                assert contest is not None and contest.warmup > 0.0;
                contest.warmup = 0.0;
            }
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
            # The world runs on around the body in every game, and the body
            # touches nothing in it. (Frames here can be shorter than a tick.)
            fallen = mortality_of(app.player);
            frames = 0;
            while frames < 240 and app.simulation_time < before + 0.05 {
                assert app.step();
                frames += 1;
            }
            renderer.screenshot("qp_gameplay_dead_" + game + ".png");
            print("GAMEPLAY", game, "dead for", app.simulation_time - before, "s after", frames, "frames");
            assert app.simulation_time >= before + 0.05;
            assert fallen.dead and not app.in_touch();
            # Q1 Host_Savegame_f and Q2 SV_Savegame_f refuse a dead player.
            app.quicksave();
            assert app.notice.startswith("Can't savegame"), app.notice;
            if game == "q3" {
                # Firing 1.7 s after the death respawns the player in the arena.
                key(app, 32);
                assert app.player.health == 0;
                fallen.clock = 2.0;
                # Jump respawns as well as fire (g_client.c respawn on any button).
                key(app, 32);
                assert app.player.health == app.player.max_health + 25;
                assert not fallen.dead and app.in_touch();
                assert app.level.collision.eye_height == 26.0 and app.level.collision.top_drop == 0.0;
                assert app.level.name == name and not app.menu.opened;
                assert contest is not None;
                scores = [edge contest->:Competes:->];
                human = [score for score in scores if score.human][0];
                human.frags = contest.fraglimit;
                contest.finished = True;
                contest.winner = human.name;
                before = app.simulation_time;
                for frame in range(3) { assert app.step(); }
                assert app.simulation_time == before;
                renderer.screenshot("qp_gameplay_arena_won.png");
                key(app, 257);
                # A win advances along the ladder: q3dm1 leads to q3dm2.
                assert app.level.name == "q3dm2" and app.player.health > 0;
                assert not app.menu.opened;
            } else {
                # The buttons count only once the body has lain a while (Q1's
                # death frames, Q2's respawn_time); a press before then
                # restarts nothing in Q1 and is latched in Q2.
                key(app, 32);
                assert app.player.health == 0 and still_lying(fallen, app);
                fallen.clock = 2.0;
                if game == "q1" {
                    # PlayerDeathThink: released, then pressed.
                    assert app.step() and app.player.health == 0;
                    key(app, 32);
                } else {
                    assert app.step();
                }
                assert app.player.health > 0 and app.combat.kills == 0;
                assert app.level.name == name and not app.menu.opened;
                if rule.ammo {
                    assert quantity(app.player.inventory, rule.ammo) == starting;
                }
                # Enter restarts as well, whatever the body is doing.
                app.player.health = 0;
                for frame in range(2) { assert app.step(); }
                key(app, 257);
                assert app.player.health > 0 and app.level.name == name and not app.menu.opened;
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
