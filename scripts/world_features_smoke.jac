"""Original maps: the world renderer's animated and special surfaces, each
looked at up close at a fixed moment: Q1 liquids, sky, animated textures and
flickering light styles, Q2 flowing and translucent surfaces, and Q3 shader
stages (scrolling and pulsing stages, deforms, autosprites, environment
maps). Saves world_<map>_<feature>.png in the working directory, for
comparing renderers by eye or pixel by pixel.

    jac build scripts/world_features_smoke.jac --native -o .jac/world-features
    DYLD_LIBRARY_PATH=vendor .jac/world-features
"""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from engine.world.lightstyles { LightStyles, HasLightStyles, LightStyleTick }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3, forward_from }

"""Whether face `index` shows `feature`."""
def shows(level: Level, index: int, feature: str) -> bool {
    face = level.bsp.faces[index];
    t = face.texture;
    name = level.bsp.textures[t].name.lower();
    if face.hidden or len(face.vertices) < 3 {
        return False;
    }
    if feature == "liquid" {
        return face.warp and face.opacity >= 1.0;
    }
    if feature == "flowing" {
        return face.warp and face.flowing;
    }
    if feature == "translucent" {
        return face.opacity < 1.0;
    }
    if feature == "sky" {
        return name.startswith("sky");
    }
    if feature == "animated" {
        return name.startswith("+");
    }
    if feature == "style" {
        return any([style > 0 and style < 12 for style in face.styles]);
    }
    stages = level.surface_stages[t] if t in level.surface_stages else [];
    deforms = level.surface_deforms[t] if t in level.surface_deforms else [];
    if feature == "scroll" {
        return any([len(stage.mods) > 0 for stage in stages]);
    }
    if feature == "pulse" {
        return any([stage.rgb == "wave" for stage in stages]);
    }
    if feature == "sprite" {
        return any([deform.kind in ["autosprite", "autosprite2"] for deform in deforms]);
    }
    if feature == "wave" {
        return any([deform.kind in ["wave", "bulge", "move"] for deform in deforms]);
    }
    if feature == "chrome" {
        return any([stage.environment for stage in stages]);
    }
    return False;
}

"""An open point in front of `middle` along `facing` with a clear line to it."""
def vantage(level: Level, middle: Vec3, facing: Vec3) -> Vec3 | None {
    for reach in [64.0, 96.0, 160.0, 32.0, 240.0] {
        for lift in [16.0, 0.0, 48.0, -16.0] {
            eye = middle.add(facing.scale(reach)).add(Vec3(z=lift));
            # A floor or ceiling is viewed at an angle: a camera pointing
            # straight up or down has no usable up vector.
            if abs(facing.z) > 0.9 {
                eye = eye.add(Vec3(x=reach * 0.8));
            }
            if level.collision.trace_point(eye, eye).start_solid {
                continue;
            }
            if level.collision.trace_point(eye, middle.add(facing.scale(2.0))).fraction > 0.95 {
                return eye;
            }
        }
    }
    return None;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    cases: list[list[str]] = [
        ["q1", "e1m1", "liquid,sky,animated,style"],
        ["q1", "e1m3", "liquid,sky,style"],
        ["q2", "base1", "liquid,flowing,translucent,animated,style"],
        ["q2", "q2dm1", "liquid,translucent"],
        ["q3", "q3dm1", "scroll,pulse,sprite,wave,chrome"],
        ["q3", "q3dm7", "scroll,pulse,sprite,wave,chrome"],
        ["q3", "q3dm12", "scroll,pulse,sprite,wave"]
    ];
    for scenario in cases {
        game = scenario[0];
        name = scenario[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        drawing = QuakeRenderer();
        drawing.upload(level);
        styles = [world->:HasLightStyles:->][?:LightStyles];
        if styles {
            for tick in range(7) {
                world spawn LightStyleTick(dt=0.1);
            }
            drawing.animate_styles(level, styles[0].values);
        }
        for feature in scenario[2].split(",") {
            # The first face showing the feature that can be seen from open space.
            found = -1;
            eye = Vec3();
            middle = Vec3();
            for index in range(len(level.bsp.faces)) {
                if found >= 0 or not shows(level, index, feature) {
                    continue;
                }
                candidate = level.bsp.faces[index];
                center = Vec3();
                for v in candidate.vertices {
                    center = center.add(v);
                }
                center = center.scale(1.0 / float(len(candidate.vertices)));
                facing = candidate.normal if candidate.normal.length() > 0.5 else Vec3(z=1.0);
                spot = vantage(level, center, facing);
                if spot is not None {
                    found = index;
                    eye = spot;
                    middle = center;
                }
            }
            if found < 0 {
                print("WORLD FEATURE", game, name, feature, "none");
                continue;
            }
            face = level.bsp.faces[found];
            toward = middle.sub(eye);
            yaw = math.atan2(toward.y, toward.x);
            pitch = math.atan2(toward.z, math.sqrt(toward.x * toward.x + toward.y * toward.y));
            for frame in range(3) {
                drawing.time = 2.3 + float(frame) * 0.05;
                renderer.begin_frame(eye, yaw, pitch);
                drawing.view_forward = forward_from(yaw, pitch);
                drawing.draw(level, level.visible(world, eye, False), eye);
                renderer.end_scene();
                renderer.end_frame();
            }
            shot = "world_" + name + "_" + feature + ".png";
            renderer.screenshot(shot);
            print("WORLD FEATURE", game, name, feature, "face", found, level.bsp.textures[face.texture].name, "->", shot);
        }
        drawing.close();
    }
    renderer.close();
    print("WORLD FEATURES PASS");
}
