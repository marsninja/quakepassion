"""Original arenas: Q3 light flares. On each map the camera stands in front of
the first few flare surfaces with open space before them and captures the
view with r_flares off and on (flares_<map>_<n>_off.png, _on.png). With
r_flares on the flare in view must fade in fully and the two captures must
differ; with it off no flare may be lit.

    jac build scripts/flares_smoke.jac --native -o .jac/flares-smoke
    DYLD_LIBRARY_PATH=vendor .jac/flares-smoke
"""
import math;
import from pathlib { Path }
import from scripts.png_checks { read_png, different_pixels }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.render.quake { QuakeRenderer }
import from engine.render.effects { EffectQuads }
import from engine.render.flares { FlareRenderer }
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from engine.world.flares { LightFlare, HasFlare }
import from engine.math.vec3 { Vec3, forward_from }

"""The world and its flares from `eye`, eight frames a twentieth of a second
apart (a flare takes a seventh of a second to fade in), ending at `now`."""
def flare_frames(
    renderer: Renderer, drawing: QuakeRenderer, flares: FlareRenderer, quads: EffectQuads,
    world: World, level: Level, eye: Vec3, yaw: float, pitch: float, now: float
) -> float {
    for frame in range(8) {
        now += 0.05;
        renderer.begin_frame(eye, yaw, pitch);
        drawing.view_forward = forward_from(yaw, pitch);
        drawing.draw(level, level.visible(world, eye, False), eye);
        flares.draw(
            world, level, drawing.shown_flares, quads, eye, yaw, pitch, renderer.fov,
            float(renderer.width) / float(max(1, renderer.height)), now
        );
        renderer.end_scene();
        renderer.end_frame();
    }
    return now;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    quads = EffectQuads();
    for name in ["q3dm12", "q3dm7"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        drawing = QuakeRenderer();
        drawing.upload(level);
        flares = FlareRenderer();
        flares.upload(level);
        lights = [world->:HasFlare:->][?:LightFlare];
        print("FLARES", name, "surfaces", len(lights), "image", flares.texture != 0);
        assert lights and flares.texture != 0;
        now = 0.0;
        taken = 0;
        for light in lights {
            if taken >= 3 {
                break;
            }
            # Stand off along the light's normal, a little to one side.
            eye = light.origin.add(light.normal.scale(160.0)).add(Vec3(x=24.0, y=24.0));
            if level.collision.trace_point(eye, eye).start_solid
                or level.collision.trace_point(eye, light.origin).fraction < 0.9 {
                continue;
            }
            toward = light.origin.sub(eye);
            yaw = math.atan2(toward.y, toward.x);
            pitch = math.atan2(toward.z, math.sqrt(toward.x * toward.x + toward.y * toward.y));
            shots: list[str] = [];
            for setting in ["0", "1"] {
                flares.cvars.flares.assign(setting);
                now = flare_frames(renderer, drawing, flares, quads, world, level, eye, yaw, pitch, now);
                shot = "flares_" + name + "_" + str(taken) + ("_on" if setting == "1" else "_off") + ".png";
                renderer.screenshot(shot);
                shots.append(shot);
                lit = len([other for other in lights if other.intensity > 0.0]);
                print("FLARE", name, taken, "r_flares", setting, "lit", lit, "this", round(light.intensity, 3), "->", shot);
                if setting == "1" {
                    assert light.intensity == 1.0 and light.visible;
                } else {
                    assert lit == 0;
                }
            }
            changed = different_pixels(read_png(Path(shots[0])), read_png(Path(shots[1])));
            print("FLARE", name, taken, "pixels changed", changed);
            assert changed > 500;
            for other in lights {
                other.intensity = 0.0;
            }
            taken += 1;
        }
        assert taken > 0;
        flares.close();
        drawing.close();
    }
    quads.close();
    renderer.close();
    print("FLARES SMOKE PASS");
}
