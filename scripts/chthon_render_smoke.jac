"""Render the original boss and its attack pose in e1m7."""
import os;
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from engine.world.level { load_level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.chthon { boss_pose }
import from games.opponents { populate_opponents }
import from games.weapons { weapon_effects }
import from engine.math.vec3 { Vec3 }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/id1";
    world = World();
    level = load_level(world, directory, "e1m7", "q1");
    populate_opponents(world, level, directory);
    boss = [
        enemy
        for enemy in [world->:HasOpponent:->][?:Opponent]
        if enemy.rule.script == "chthon"
    ][0];
    assert boss.activation.enabled;
    boss.dormant = False;
    boss.boss_phase = 2;
    boss.boss_time = 0.8;
    boss.visual.visible = True;
    boss_pose(boss);
    player = spawn_player(level);
    player.pos = boss.pos.add(Vec3(x=500.0, z=130.0));
    player.yaw = math.pi;
    player.pitch = 0.0;
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
    app.effects.upload("q1", directory, weapon_effects("q1"));
    for i in range(3) {
        app.render_frame();
    }
    renderer.screenshot("qp_chthon.png");
    app.effects.close();
    app.models.close();
    app.quake.close();
    renderer.close();
    print("CHTHON RENDER PASS");
}
