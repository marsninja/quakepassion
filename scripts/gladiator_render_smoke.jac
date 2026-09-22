"""Render the original Q2 gladiator rail windup in a supplied campaign map."""
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
    rule = enemy_rule("q2", "monster_gladiator");
    assert rule is not None;
    enemy = Opponent(rule=rule, attack_wait=0.0, modeled=True);
    found = False;
    for i in range(16) {
        angle = float(i) * math.pi / 8.0;
        origin = player.pos.add(
            Vec3(x=math.cos(angle) * 160.0, y=math.sin(angle) * 160.0)
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
            name="gladiator-rail", model=loaded.model, skins=loaded.skins
        );
        world +>:HasModelResource:+> resource;
        enemy.visual = attach_model(enemy, resource);
        enemy.visual.offset = Vec3(z=-level.collision.eye_height);
        names = [frame.name for frame in loaded.model.surfaces[0].frames];
        for name in rule.attack_frames {
            enemy.attack_animation.append(names.index(name));
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
    assert not enemy.attack_melee and player.health == 100;
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_gladiator_windup.png");
    world spawn CombatTick(
        player=player, collision=level.collision, state=app.combat, dt=0.1
    );
    assert player.health == 50 and enemy.attack_event == 1;
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_gladiator_rail.png");
    app.models.close();
    app.quake.close();
    renderer.close();
    print("GLADIATOR RAIL RENDER PASS");
}
