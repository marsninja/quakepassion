"""Check native pain and death poses, and mid-reaction save restoration, with original assets."""
import os;
import math;
import from engine.assets.library { AssetLibrary }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, move_to_area }
import from engine.world.level { load_level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent, CombatTick, damage_opponent }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.math.vec3 { Vec3 }
import from games.enemies { enemy_rule }
import from games.opponents { link_reactions }
import from engine.core.savegame { snapshot, restore }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/baseq2";
    world = World();
    level = load_level(world, directory, "base1", "q2");
    player = spawn_player(level);
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    enemy = Opponent(
        rule=rule, game="q2", attack_wait=30.0, modeled=True, grounded=True,
        eye_height=level.collision.eye_height
    );
    soldier_rule = enemy_rule("q2", "monster_soldier_light");
    assert soldier_rule is not None;
    soldier = Opponent(
        rule=soldier_rule, game="q2", attack_wait=30.0, modeled=True, grounded=True,
        eye_height=level.collision.eye_height,
        health=soldier_rule.health, max_health=soldier_rule.health
    );
    # The infantry stands at the first clear spot round the player, the
    # soldier at the next but one.
    found = 0;
    for i in range(16) {
        angle = float(i) * math.pi / 8.0;
        origin = player.pos.add(
            Vec3(x=math.cos(angle) * 60.0, y=math.sin(angle) * 60.0)
        );
        ray = level.collision.trace_point(player.pos, origin);
        # Room for a body there, not only a line to it.
        feet = origin.sub(Vec3(z=level.collision.eye_height));
        room = level.collision.trace(feet, feet.sub(Vec3(z=16.0)));
        if not ray.start_solid and ray.fraction == 1.0 and not room.start_solid {
            if found == 0 {
                enemy.pos = origin;
                enemy.yaw = angle + math.pi;
                player.yaw = angle + math.pi / 8.0;
            } elif found == 2 {
                soldier.pos = origin;
                soldier.yaw = angle + math.pi;
                break;
            }
            found += 1;
        }
    }
    assert found == 2;
    library = AssetLibrary(game="q2");
    library.open(directory);
    try {
        loaded = library.model(rule.model);
        resource = ModelResource(
            name="infantry-punch", model=loaded.model, skins=loaded.skins
        );
        world +>:HasModelResource:+> resource;
        enemy.visual = attach_model(enemy, resource);
        enemy.visual.offset = Vec3(z=-level.collision.eye_height);
        link_reactions(enemy, loaded.model.surfaces[0].frames, rule, rule.model);
        trooper = library.model(soldier_rule.model);
        trooper_resource = ModelResource(
            name="soldier-death", model=trooper.model, skins=trooper.skins
        );
        world +>:HasModelResource:+> trooper_resource;
        soldier.visual = attach_model(soldier, trooper_resource);
        soldier.visual.offset = Vec3(z=-level.collision.eye_height);
        link_reactions(soldier, trooper.model.surfaces[0].frames, soldier_rule, soldier_rule.model);
    } finally {
        library.close();
    }
    world +>:HasOpponent:+> enemy;
    move_to_area(enemy, level.areas[level.locate(enemy.pos)]);
    world +>:HasOpponent:+> soldier;
    move_to_area(soldier, level.areas[level.locate(soldier.pos)]);
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=world,
        player=player,
        level=level,
        renderer=renderer,
        clock=Clock(),
        smoke=True
    );
    app.renderer.cvars.novis.assign("1");
    app.quake.upload(level);
    app.models.upload(world);
    # Let both settle on the floor before anything is done to them.
    for i in range(12) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=app.combat, dt=1.0 / 60.0
        );
    }
    assert enemy.grounded and soldier.grounded;
    flinched = enemy.pos.add(Vec3());
    damage_opponent(enemy, 1);
    # infantry_pain drew pain1 or pain2, ten frames each, and both stagger
    # back 9 units over the first five (less where a wall stands behind).
    pain = enemy.pain_animations[enemy.pain_variant - 1];
    assert len(pain) == 10;
    for i in range(33) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=app.combat, dt=1.0 / 60.0
        );
    }
    assert enemy.visual.first == pain[5] and player.health == 100;
    print(
        "INFANTRY PAIN", rule.pains[enemy.pain_variant - 1].name, "moved",
        enemy.pos.sub(flinched).length()
    );
    assert enemy.pos.sub(flinched).length() <= 9.01;
    saved = snapshot(world, level, player, app.combat);
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_infantry_pain.png");
    enemy.animation_time = 0.0;
    enemy.pain_wait = 0.0;
    enemy.pose_name = "stand";
    restore(world, level, player, app.combat, saved);
    for i in range(6) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=app.combat, dt=1.0 / 60.0
        );
    }
    assert enemy.visual.first == pain[6] and player.health == 100;
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_infantry_pain_restored.png");
    # infantry_die draws one of three deaths; soldier_die takes death3 for
    # a head shot. Both are caught part way through, striding as they fall.
    stood = enemy.pos.add(Vec3());
    fell = soldier.pos.add(Vec3());
    damage_opponent(enemy, 110);
    soldier.struck = Vec3(z=soldier.pos.z + 3.0);
    damage_opponent(soldier, 25);
    death = enemy.death_animations[enemy.death_variant - 1];
    headshot = soldier.death_animations[soldier.death_variant - 1];
    assert soldier_rule.deaths[soldier.death_variant - 1].name == "death3" and len(headshot) == 45;
    for i in range(51) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=app.combat, dt=1.0 / 60.0
        );
    }
    assert enemy.visual.first == death[min(8, len(death) - 1)];
    assert soldier.visual.first == headshot[8];
    # soldier_move_death3 falls back 15 by 1.2 in its first three frames.
    print(
        "INFANTRY DEATH", rule.deaths[enemy.death_variant - 1].name, "moved",
        enemy.pos.sub(stood).length(), "SOLDIER death3 moved", soldier.pos.sub(fell).length()
    );
    assert soldier.pos.sub(fell).length() <= 18.01;
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_infantry_soldier_death.png");
    saved = snapshot(world, level, player, app.combat);
    for i in range(120) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=app.combat, dt=1.0 / 60.0
        );
    }
    restore(world, level, player, app.combat, saved);
    assert enemy.visual.first == death[min(8, len(death) - 1)];
    assert soldier.visual.first == headshot[8];
    for i in range(240) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=app.combat, dt=1.0 / 60.0
        );
    }
    assert enemy.visual.first == death[-1] and soldier.visual.first == headshot[-1];
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_infantry_soldier_dead.png");
    app.models.close();
    app.quake.close();
    renderer.close();
    print("PAIN AND DEATH RESTORE RENDER PASS");
}
