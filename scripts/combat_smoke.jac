"""Native assets, model rendering, shooting and arena respawn validation."""
import math;
import from engine.core.savegame { snapshot, restore, write_save, read_save }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    CombatTick,
    Projectile,
    HasProjectile,
    ProjectileTick,
    fire_weapon,
    select_weapon
}
import from engine.world.inventory { AdjustInventory }
import from games.weapons { equip_player, weapon_sounds, weapon_effects }
import from games.items { populate_pickups }
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
        equip_player(player, app.combat, game);
        populate_pickups(world, level, game_directory(game));
        app.audio.open(game, game_directory(game), weapon_sounds(game));
        app.quake.upload(level);
        app.models.upload(world);
        app.effects.upload(game, game_directory(game), weapon_effects(game));
        opponents = [world->:HasOpponent:->][?:Opponent];
        enemy = opponents[0];
        found = False;
        for candidate in opponents {
            if candidate.dormant {
                continue;
            }
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
        for i in range(100) {
            if enemy.health <= 0 {
                break;
            }
            app.combat.cooldown = 0.0;
            assert fire_weapon(world, player, level.collision, app.combat);
            app.audio.play(2 + app.combat.weapon);
            for tick in range(24) {
                world spawn ProjectileTick(
                    player=player,
                    collision=level.collision,
                    state=app.combat,
                    dt=1.0 / 120.0
                );
            }
        }
        app.render_frame();
        renderer.screenshot("qp_combat_hit_" + game + ".png");
        assert enemy.health == 0 and app.combat.kills == 1;
        # Enemies with a death animation remain as visible corpses.
        assert not enemy.visual.visible or bool(enemy.death_animation);
        data = snapshot(world, level, player, app.combat);
        path = ".jac/combat-save-" + game + ".txt";
        write_save(path, data);
        enemy.health = 60;
        restore(world, level, player, app.combat, read_save(path));
        assert enemy.health == 0 and app.combat.kills == 1;
        if game == "q3" {
            enemy.home = enemy.pos;
            player.health = 100000;
            app.combat.weapon = 2;
            for frag in range(9) {
                world spawn CombatTick(
                    player=player, collision=level.collision, state=app.combat, dt=3.0
                );
                assert enemy.health > 0 and enemy.visual.visible;
                # Bots respawn at the furthest spawn; bring this one back into view.
                enemy.pos = enemy.home;
                enemy.velocity = Vec3();
                player.inventory spawn AdjustInventory(
                    kind="bullets", amount=100, capacity=200
                );
                for shot in range(100) {
                    if enemy.health <= 0 {
                        break;
                    }
                    app.combat.cooldown = 0.0;
                    assert fire_weapon(world, player, level.collision, app.combat);
                }
                assert enemy.health == 0 and app.combat.kills == frag + 2;
            }
            assert app.combat.kills == 10;
            print("ARENA MATCH PASS: ten machinegun kills through respawn");
        }
        if game == "q2" {
            enemy.health = 1000;
            enemy.max_health = 1000;
            enemy.visual.visible = True;
            player.god_mode = True;
            player.inventory spawn AdjustInventory(kind="weapon_bfg", amount=1);
            player.inventory spawn AdjustInventory(
                kind="cells", amount=100, capacity=200
            );
            assert select_weapon(player, app.combat, 10);
            app.combat.cooldown = 0.0;
            assert fire_weapon(world, player, level.collision, app.combat);
            tendrils = False;
            bursting = False;
            for frame in range(100) {
                world spawn ProjectileTick(
                    player=player,
                    collision=level.collision,
                    state=app.combat,
                    dt=1.0 / 120.0
                );
                app.render_frame();
                for orb in [world->:HasProjectile:->][?:Projectile] {
                    if orb.beams and not tendrils {
                        renderer.screenshot("qp_bfg_tendrils.png");
                        tendrils = True;
                    }
                    if orb.phase == 2 and not bursting {
                        renderer.screenshot("qp_bfg_burst.png");
                        bursting = True;
                    }
                }
            }
            assert tendrils and bursting and enemy.health < 800;
            assert not [world->:HasProjectile:->];
            print("BFG SCENE PASS: tendrils, core hit, delayed burst, cleanup");
        }
        print("COMBAT PASS", game, count, "opponents");
        app.audio.close();
        app.models.close();
        app.effects.close();
        assert not app.effects.textures;
        app.quake.close();
    }
    renderer.close();
}
