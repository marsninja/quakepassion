"""Original maps: each game's status bar art loads and draws, and Q1/Q2 light
styles animate the lightmaps."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.lightstyles { LightStyles, HasLightStyles, LightStyleTick }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.render.hud { HudRenderer, HudStatus }
import from engine.assets.library { AssetLibrary }
import from games.hud_art { load_hud_art }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer();
    renderer.open_window();
    cases: list[tuple[str, str]] = [("q1", "e1m1"), ("q2", "base1"), ("q3", "q3dm1")];
    for scenario in cases {
        game = scenario[0];
        name = scenario[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        drawing = QuakeRenderer();
        drawing.upload(level);
        hud = HudRenderer();
        library = AssetLibrary(game=game);
        library.open(game_directory(game));
        load_hud_art(hud, library, game);
        library.close();
        print("HUD", game, name, "ready", hud.ready, "pictures", len(hud.pics));
        assert hud.ready;
        styles = [world->:HasLightStyles:->][?:LightStyles];
        if game != "q3" {
            assert styles and drawing.styled;
            before = styles[0].serial;
            for tick in range(12) {
                world spawn LightStyleTick(dt=0.1);
            }
            assert styles[0].serial > before;
            drawing.animate_styles(level, styles[0].values);
            print("STYLES", game, name, "styled faces", len(drawing.styled), "serial", styles[0].serial);
        } else {
            assert not styles;
            # Layered Q3 shaders: animated, moving, pulsing and blended stages.
            print("SHADERS", game, name, "layered", len(level.surface_stages), "uploaded", len(drawing.stage_images));
            assert level.surface_stages and len(drawing.stage_images) == len(level.surface_stages);
        }
        status = HudStatus(
            game=game, health=87, armor=45, armor_ratio=0.6, ammo=23,
            ammo_kind="shells" if game != "q3" else "bullets",
            weapon="shotgun" if game != "q3" else "machinegun",
            weapons=["shotgun", "nailgun", "machinegun"],
            ammo_counts={"shells": 23, "nails": 50, "rockets": 5, "cells": 0},
            keys=["key1"], sigils=1, powerups=["quad"], powerup_time=17.0
        );
        eye = spawn_player(level).pos;
        for frame in range(3) {
            drawing.time = 1.5 + float(frame) * 0.1;
            renderer.begin_frame(eye, 0.3, 0.0);
            drawing.draw(level, level.visible(world, eye, False), eye);
            renderer.end_scene();
            hud.draw(status, renderer.width, renderer.height);
            renderer.end_frame();
        }
        renderer.screenshot("qp_hud_" + name + ".png");
        hud.close();
        drawing.close();
    }
    renderer.close();
    print("PRESENTATION PASS");
}
