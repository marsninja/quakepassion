"""Draw original projectile assets, including pitched models and additive flares."""
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.render.effects { EffectScene }
import from engine.world.world { World }
import from engine.world.combat { Projectile, HasProjectile }
import from engine.math.vec3 { Vec3 }
import from games.weapons { weapon_effects }

with entry {
    window = Renderer(width=960, height=540);
    window.open_window();
    scene = EffectScene();
    for game in ["q1", "q2", "q3"] {
        rules = weapon_effects(game);
        scene.upload(game, game_directory(game), rules);
        assert len(scene.keys()) == len(rules);
        if game == "q3" {
            rocket = scene.models["q3_rocket"];
            assert any(
                stage.two_sided and stage.blend == "add" for stage in rocket.stages
            );
            grenade = scene.models["q3_grenade"];
            assert any(
                len(stage.frames) == 2 and stage.frequency == 7.0
                for stage in grenade.stages
            );
        }
        for rule in rules {
            world = World();
            world +>:HasProjectile:+> Projectile(
                effect=rule.key,
                pos=Vec3(),
                velocity=Vec3(x=400.0, z=120.0),
                age=0.25,
                remaining=2.0,
                damage=10
            );
            eye = Vec3(x=-70.0, y=-100.0, z=40.0);
            for frame in range(3) {
                window.begin_frame(eye, 0.9600703624, -0.316669);
                scene.draw(world, eye, 0.9600703624, -0.316669);
                window.end_scene();
                window.draw_overlay([game + ": " + rule.key]);
                window.end_frame();
            }
            window.screenshot("qp_effect_" + rule.key + ".png");
            print("Original projectile rendered:", rule.key);
        }
        scene.close();
        assert not scene.textures and not scene.models and not scene.renderers;
    }
    window.close();
}
