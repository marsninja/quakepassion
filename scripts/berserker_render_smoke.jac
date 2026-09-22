"""Render the original Q2 berserker spike and club in a supplied campaign map."""
import os;
import math;
import from engine.assets.library { AssetLibrary }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, move_to_area }
import from engine.world.level { load_level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent, CombatTick }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.math.vec3 { Vec3 }
import from games.enemies { enemy_rule }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/baseq2";
    world = World();
    level = load_level(world, directory, "base1", "q2");
    player = spawn_player(level);
    rule = enemy_rule("q2", "monster_berserk");
    assert rule is not None;
    enemy = Opponent(rule=rule, attack_wait=0.0, modeled=True);
    found = False;
    for i in range(16) {
        angle = float(i) * math.pi / 8.0;
        origin = player.pos.add(
            Vec3(x=math.cos(angle) * 60.0, y=math.sin(angle) * 60.0)
        );
        ray = level.collision.trace_point(player.pos, origin);
        if not ray.start_solid and ray.fraction == 1.0 {
            enemy.pos = origin;
            enemy.yaw = angle + math.pi;
            player.yaw = angle;
            found = True;
            break;
        }
    }
    assert found;
    library = AssetLibrary(game="q2");
    library.open(directory);
    try {
        loaded = library.model(rule.model);
        resource = ModelResource(
            name="berserker", model=loaded.model, skins=loaded.skins
        );
        world +>:HasModelResource:+> resource;
        enemy.visual = attach_model(enemy, resource);
        enemy.visual.offset = Vec3(z=-level.collision.eye_height);
        names = [frame.name for frame in loaded.model.surfaces[0].frames];
        for name in rule.melee_frames {
            enemy.melee_animation.append(names.index(name));
        }
        for name in rule.alternate_melee_frames {
            enemy.alternate_melee_animation.append(names.index(name));
        }
    } finally {
        library.close();
    }
    world +>:HasOpponent:+> enemy;
    move_to_area(enemy, level.areas[level.locate(enemy.pos)]);
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
    app.models.upload(world);
    world spawn CombatTick(
        player=player, collision=level.collision, state=app.combat, dt=0.2
    );
    assert enemy.attack_melee and player.health == 100;
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_berserker_windup.png");
    world spawn CombatTick(
        player=player, collision=level.collision, state=app.combat, dt=0.1
    );
    assert player.health >= 80 and player.health <= 85 and enemy.attack_event == 1;
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_berserker_spike.png");
    enemy.attack_clock = -1.0;
    enemy.attack_wait = 0.0;
    enemy.decision_wait = 0.0;
    enemy.shot_random = 30000;
    player.health = 100;
    world spawn CombatTick(
        player=player, collision=level.collision, state=app.combat, dt=0.8
    );
    assert enemy.alternate_melee and player.health >= 90 and player.health <= 95;
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_berserker_club.png");
    app.models.close();
    app.quake.close();
    renderer.close();
    print("BERSERKER RENDER PASS");
}
