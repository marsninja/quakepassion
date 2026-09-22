"""Native assets, model rendering, shooting and arena respawn validation."""
import math;
import from engine.core.savegame { snapshot, restore, write_save, read_save }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.combat { Opponent, HasOpponent, CombatTick, fire_weapon }
import from engine.world.inventory { AdjustInventory }
import from games.opponents { populate_opponents }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        world = World();
        level = load_level(world, game_directory(game), name, game);
        count = populate_opponents(world, level, game_directory(game));
        assert count > 0;
        player = spawn_player(level);
        app = App(
            world=world,
            player=player,
            level=level,
            renderer=renderer,
            clock=Clock(),
            overlay=False
        );
        app.audio.open(game, game_directory(game));
        app.quake.upload(level);
        app.models.upload(world);
        opponents = [world->:HasOpponent:->][?:Opponent];
        enemy = opponents[0];
        found = False;
        for candidate in opponents {
            for offset in [
                Vec3(x=120.0),
                Vec3(x=-120.0),
                Vec3(y=120.0),
                Vec3(y=-120.0)
            ] {
                eye = candidate.pos.add(offset);
                trace = level.collision.trace_point(eye, candidate.pos);
                if not trace.start_solid and trace.fraction == 1.0 {
                    player.pos = eye;
                    enemy = candidate;
                    found = True;
                    break;
                }
            }
            if found {
                break;
            }
        }
        assert found;
        delta = enemy.pos.sub(player.pos);
        player.yaw = math.atan2(delta.y, delta.x);
        player.pitch = 0.0;
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_combat_" + game + ".png");
        player.inventory spawn AdjustInventory(kind="shells", amount=10, capacity=100);
        app.combat.weapon = 2;
        for i in range(2) {
            app.combat.cooldown = 0.0;
            assert fire_weapon(world, player, level.collision, app.combat);
            app.audio.play(0);
        }
        assert enemy.health == 0 and app.combat.kills == 1;
        assert not enemy.visual.visible;
        data = snapshot(world, level, player, app.combat);
        path = ".jac/combat-save-" + game + ".txt";
        write_save(path, data);
        enemy.health = 60;
        restore(world, level, player, app.combat, read_save(path));
        assert enemy.health == 0 and app.combat.kills == 1;
        if game == "q3" {
            enemy.home = enemy.pos;
            player.health = 100000;
            app.combat.weapon = 1;
            for frag in range(9) {
                world spawn CombatTick(
                    player=player, collision=level.collision, state=app.combat, dt=3.0
                );
                assert enemy.health > 0 and enemy.visual.visible;
                for shot in range(4) {
                    app.combat.cooldown = 0.0;
                    assert fire_weapon(world, player, level.collision, app.combat);
                }
                assert enemy.health == 0 and app.combat.kills == frag + 2;
            }
            assert app.combat.kills == 10;
            print("ARENA MATCH PASS: ten hitscan kills through respawn");
        }
        print("COMBAT PASS", game, count, "opponents");
        app.audio.close();
        app.models.close();
        app.quake.close();
    }
    renderer.close();
}
