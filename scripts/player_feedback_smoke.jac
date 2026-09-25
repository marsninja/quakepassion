"""Player feedback render check: each game's rocket and grenade explosions,
the Q1 Thunderbolt beam, Q2/Q3 rail trails, the damage flash, the underwater
tint and pickup messages, drawn by the real App frame into screenshots."""
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.combat { fire_weapon, select_weapon, CombatTick }
import from engine.world.particles { explode, ParticleTick, HasExplosion, HasTrail }
import from engine.world.inventory { AdjustInventory }
import from games.weapons { equip_player, weapon_effects }
import from games.viewweapons { view_weapons }
import from engine.math.vec3 { Vec3, forward_from }

"""A clear view: turn until the wall ahead is 150-600 units away."""
def pf_face_open(app: App) -> Vec3 {
    player = app.player;
    best = 0.0;
    best_yaw = player.yaw;
    for i in range(16) {
        yaw = float(i) * math.pi / 8.0;
        ahead = forward_from(yaw, -0.15);
        wall = app.level.collision.trace_point(player.pos, player.pos.add(ahead.scale(700.0)));
        reach = wall.fraction * 700.0;
        if reach > best and reach < 650.0 {
            best = reach;
            best_yaw = yaw;
        }
    }
    player.yaw = best_yaw;
    player.pitch = -0.15;
    ahead = forward_from(player.yaw, player.pitch);
    return player.pos.add(ahead.scale(max(80.0, min(best - 24.0, 220.0))));
}

def pf_frames(app: App, dt: float, count: int) {
    for i in range(count) {
        app.world spawn ParticleTick(dt=dt);
        app.frame_dt = dt;
        app.render_frame();
    }
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        world = World();
        level = load_level(world, game_directory(game), name, game);
        player = spawn_player(level);
        app = App(
            world=world,
            player=player,
            level=level,
            renderer=renderer,
            clock=Clock(),
            overlay=False,
            culling=False
        );
        equip_player(player, app.combat, game);
        app.quake.upload(level);
        app.models.upload(world);
        app.effects.upload(game, game_directory(game), weapon_effects(game));
        app.viewweapon.upload(game, game_directory(game), view_weapons(game));
        app.prepare_presentation();
        spot = pf_face_open(app);
        # Rocket explosion a few frames in.
        rocket = {"q1": "q1_explosion", "q2": "q2_explosion", "q3": "q3_rocket_explosion"}[game];
        explode(world, spot, rocket);
        pf_frames(app, 0.05, 3);
        renderer.screenshot("qp_pf_" + game + "_rocket.png");
        pf_frames(app, 0.1, 6);
        renderer.screenshot("qp_pf_" + game + "_rocket_late.png");
        pf_frames(app, 0.5, 4);
        assert not [world->:HasExplosion:->];
        grenade = {"q1": "q1_explosion", "q2": "q2_grenade_explosion", "q3": "q3_grenade_explosion"}[game];
        explode(world, spot, grenade);
        pf_frames(app, 0.05, 3);
        renderer.screenshot("qp_pf_" + game + "_grenade.png");
        pf_frames(app, 0.5, 5);
        # The beam weapons.
        player.inventory spawn AdjustInventory(kind="weapon_lightning", amount=1);
        player.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1);
        player.inventory spawn AdjustInventory(kind="cells", amount=50, capacity=200);
        player.inventory spawn AdjustInventory(kind="lightning", amount=50, capacity=200);
        player.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=200);
        if game in ["q1", "q3"] {
            assert select_weapon(player, app.combat, 8 if game == "q1" else 6);
            app.combat.cooldown = 0.0;
            assert fire_weapon(world, player, level.collision, app.combat);
            pf_frames(app, 0.01, 2);
            renderer.screenshot("qp_pf_" + game + "_lightning.png");
            pf_frames(app, 0.5, 2);
        }
        if game in ["q2", "q3"] {
            assert select_weapon(player, app.combat, 9 if game == "q2" else 7);
            player.yaw += 0.35;
            app.combat.cooldown = 0.0;
            assert fire_weapon(world, player, level.collision, app.combat);
            player.yaw -= 0.35;
            assert [world->:HasTrail:->];
            pf_frames(app, 0.05, 2);
            renderer.screenshot("qp_pf_" + game + "_rail.png");
            pf_frames(app, 0.5, 3);
        }
        # A hit from the right, the damage flash and kick.
        app.combat.punch_left = 0.0;
        player.damage_blood = 25;
        player.damage_from = player.pos.add(Vec3(y=-100.0));
        player.health = 60;
        pf_frames(app, 0.02, 2);
        renderer.screenshot("qp_pf_" + game + "_damage.png");
        pf_frames(app, 1.0, 2);
        # Under water.
        player.water_depth = 3;
        player.liquid_kind = 1;
        pf_frames(app, 0.02, 2);
        renderer.screenshot("qp_pf_" + game + "_underwater.png");
        player.water_depth = 0;
        player.liquid_kind = 0;
        # Pickup feedback: Q1 prints, Q2/Q3 show the icon and name.
        if game == "q1" {
            app.notify("You got the Rocket Launcher");
            app.notify("You receive 25 health");
            app.show_notice("You need the gold key");
        } else {
            app.pickup_icon = "w_rlauncher" if game == "q2" else "icons/iconw_rocket";
            app.pickup_name = "Rocket Launcher";
            app.pickup_time = 3.0;
        }
        app.view.pickup();
        pf_frames(app, 0.02, 2);
        renderer.screenshot("qp_pf_" + game + "_pickup.png");
        # The dead view.
        player.health = 0;
        pf_frames(app, 0.02, 2);
        renderer.screenshot("qp_pf_" + game + "_dead.png");
        app.effects.close();
        app.viewweapon.close();
        app.models.close();
        app.quake.close();
        app.hud.close();
        print("FEEDBACK", game, "rendered");
    }
    renderer.close();
    print("PLAYER FEEDBACK RENDER PASS");
}
