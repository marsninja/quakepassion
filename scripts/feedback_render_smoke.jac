"""Native visual check of real Q1 shotgun pellet impacts."""
import os;
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from engine.world.level { load_level, spawn_player }
import from engine.world.combat { fire_weapon, Opponent, HasOpponent, CombatTick }
import from engine.world.particles { HasParticle, ParticleTick }
import from games.opponents { populate_opponents }
import from engine.math.vec3 { Vec3 }
import from games.weapons { equip_player }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/id1";
    world = World();
    level = load_level(world, directory, "e1m1", "q1");
    player = spawn_player(level);
    player.yaw += math.pi / 2.0;
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=world,
        player=player,
        level=level,
        renderer=renderer,
        clock=Clock(),
        smoke=True,
        culling=False
    );
    app.quake.upload(level);
    equip_player(player, app.combat, "q1");
    assert fire_weapon(world, player, level.collision, app.combat);
    assert len([world->:HasParticle:->]) > 0;
    world spawn ParticleTick(dt=0.08);
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_feedback.png");
    populate_opponents(world, level, directory);
    app.models.upload(world);
    enemy = [world->:HasOpponent:->][?:Opponent][0];
    found = False;
    for candidate in [world->:HasOpponent:->][?:Opponent] {
        for i in range(16) {
            angle = float(i) * math.pi / 8.0;
            vantage = candidate.pos.add(
                Vec3(x=math.cos(angle) * 80.0, y=math.sin(angle) * 80.0)
            );
            ray = level.collision.trace_point(vantage, candidate.pos);
            if not ray.start_solid and ray.fraction == 1.0 {
                player.pos = vantage;
                player.yaw = angle + math.pi;
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
    app.combat.cooldown = 0.0;
    assert fire_weapon(world, player, level.collision, app.combat);
    world spawn ParticleTick(dt=0.04);
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_feedback_blood.png");
    app.combat.cooldown = 0.0;
    assert fire_weapon(world, player, level.collision, app.combat);
    for i in range(10) {
        if enemy.health <= 0 {
            break;
        }
        app.combat.cooldown = 0.0;
        fire_weapon(world, player, level.collision, app.combat);
    }
    assert enemy.health <= 0 and enemy.death_animation;
    world spawn CombatTick(
        player=player, collision=level.collision, state=app.combat, dt=1.5
    );
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_feedback_corpse.png");
    app.models.close();
    app.quake.close();
    renderer.close();
    print("SHOTGUN FEEDBACK RENDER PASS");
}
