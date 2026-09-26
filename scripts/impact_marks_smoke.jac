"""Visual check of Q3 impact marks and wall sparks: every hitscan and missile
weapon fired at a wall of q3dm1, the marks rendered where they struck, and
again after the energy marks' glow has died."""
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from engine.world.level { load_level, spawn_player }
import from engine.world.combat {
    fire_weapon,
    ProjectileTick,
    HasProjectile,
    weapon_rule
}
import from engine.world.particles {
    HasMark,
    ImpactMark,
    HasImpactSound,
    ImpactSound,
    ParticleTick
}
import from engine.world.inventory { AdjustInventory }
import from engine.math.vec3 { Vec3, forward_from }
import from games.weapons { equip_player, weapon_effects }

with entry {
    world = World();
    level = load_level(world, game_directory("q3"), "q3dm1", "q3");
    player = spawn_player(level);
    # A plain world wall 100-300 units ahead of some spawn point, faced
    # squarely and broad enough for every shot.
    found = False;
    for entity in level.bsp.entities {
        if found or entity.fields.get("classname", "") != "info_player_deathmatch" {
            continue;
        }
        coords = entity.fields.get("origin", "0 0 0").split();
        player.pos = Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2]) + level.collision.eye_height);
        for step in range(144) {
            yaw = float(step) * math.pi / 72.0;
            ahead = forward_from(yaw, 0.0);
            hit = level.collision.trace_point(player.pos, player.pos.add(ahead.scale(400.0)));
            reach = hit.fraction * 400.0;
            if hit.fraction >= 1.0 or reach < 100.0 or reach > 300.0
                or hit.normal.dot(ahead) > -0.95 or hit.model > 0
                or level.collision.surface_class(hit) != 0 {
                continue;
            }
            broad = True;
            plane = player.pos.add(ahead.scale(reach));
            for turn in [-0.3, -0.15, 0.15, 0.3] {
                heading = forward_from(yaw + turn, 0.0);
                side = level.collision.trace_point(player.pos, player.pos.add(heading.scale(600.0)));
                point = player.pos.add(heading.scale(side.fraction * 600.0));
                if side.fraction >= 1.0 or side.normal.dot(hit.normal) < 0.99
                    or abs(point.sub(plane).dot(hit.normal)) > 1.0 {
                    broad = False;
                }
            }
            if broad {
                player.yaw = yaw;
                print("Wall", reach, "ahead of", player.pos.x, player.pos.y, player.pos.z);
                found = True;
                break;
            }
        }
    }
    assert found;
    renderer = Renderer(width=960, height=540);
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
    app.effects.upload("q3", game_directory("q3"), weapon_effects("q3"));
    state = app.combat;
    equip_player(player, state, "q3");
    player.god_mode = True;
    aim = player.yaw;
    # Machine gun, shotgun, lightning, railgun, plasma, rocket: each at its
    # own spot along the wall.
    shots = [(2, -0.28, 6), (3, -0.16, 1), (6, -0.05, 6), (7, 0.05, 1), (8, 0.16, 4), (5, 0.28, 1)];
    first = True;
    for shot in shots {
        rule = weapon_rule(state, shot[0]);
        assert rule is not None;
        player.inventory spawn AdjustInventory(kind="weapon_" + rule.key, amount=1, capacity=1);
        player.inventory spawn AdjustInventory(kind=rule.ammo, amount=50, capacity=200);
        state.weapon = shot[0];
        for i in range(shot[2]) {
            player.yaw = aim + shot[1] + float(i) * 0.008;
            player.pitch = -0.05 + float(i % 3) * 0.05;
            state.cooldown = 0.0;
            assert fire_weapon(world, player, level.collision, state);
        }
        if first {
            # The machine gun's sparks off the wall (CG_MissileHitWall).
            first = False;
            player.yaw = aim;
            player.pitch = 0.0;
            world spawn ParticleTick(dt=0.03);
            for i in range(3) {
                app.render_frame();
            }
            renderer.screenshot("qp_impact_sparks.png");
        }
    }
    player.yaw = aim;
    player.pitch = 0.0;
    for tick in range(40) {
        if not [world->:HasProjectile:->] {
            break;
        }
        world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=0.05);
    }
    marks = [world->:HasMark:->][?:ImpactMark];
    shaders = set([mark.shader for mark in marks]);
    print("Marks:", len(marks), sorted(shaders));
    print("Impact sounds:", sorted(set([sound.sound for sound in [world->:HasImpactSound:->][?:ImpactSound]])));
    assert "gfx/damage/bullet_mrk" in shaders and "gfx/damage/plasma_mrk" in shaders;
    assert "gfx/damage/burn_med_mrk" in shaders and "gfx/damage/hole_lg_mrk" in shaders;
    # Once the trails and explosions have gone, the marks.
    world spawn ParticleTick(dt=1.2);
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_impact_marks.png");
    # Four seconds on the energy marks have gone dark; the rest remain.
    world spawn ParticleTick(dt=3.0);
    for i in range(2) {
        app.render_frame();
    }
    renderer.screenshot("qp_impact_marks_later.png");
    world spawn ParticleTick(dt=6.5);
    assert not [world->:HasMark:->];
    app.quake.close();
    app.effects.close();
    renderer.close();
    print("IMPACT MARKS RENDER PASS");
}
