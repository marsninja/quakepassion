"""Q3's 3D status bar icons: ammo, armor and head models draw into the bar."""
import from engine.core.menu { game_directory }
import from engine.render.hud { HudRenderer, HudStatus }
import from engine.render.hud_models { HudModels }
import from engine.render.renderer { Renderer }
import from engine.assets.library { AssetLibrary }
import from games.hud_art { load_hud_art, load_q3_models }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    library = AssetLibrary(game="q3");
    library.open(game_directory("q3"));
    hud = HudRenderer();
    load_hud_art(hud, library, "q3");
    models = HudModels();
    load_q3_models(models, library);
    library.close();
    print("ICONS ammo", len(models.ammo), "armor", models.armor is not None, "head", models.head is not None, "head origin", models.head_origin.x, models.head_origin.z);
    assert models.ready() and len(models.ammo) == 8 and models.armor is not None;
    hud.three_d = True;
    status = HudStatus(game="q3", health=100, armor=50, ammo=40, weapon="rocketlauncher");
    for frame in range(90) {
        status.clock = float(frame) / 30.0;
        # A hit two thirds of the way through kicks the head.
        status.health = 100 if frame < 60 else 80;
        renderer.begin_frame(Vec3(), 0.0, 0.0);
        renderer.end_scene();
        hud.draw(status, renderer.width, renderer.height);
        models.draw(hud, status, renderer.width, renderer.height);
        renderer.end_frame();
        if frame == 45 {
            renderer.screenshot("hud_icons_q3.png");
        }
    }
    renderer.screenshot("hud_icons_q3_hurt.png");
    assert models.damage_time > 1.9;
    models.close();
    hud.close();
    renderer.close();
    print("ICONS PASS");
}
