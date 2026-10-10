"""Original arenas: Q3 light flares. On each map the camera stands in front of
the first few flare surfaces with open space before them and captures the
view with r_flares off and on (flares_<map>_<n>_off.png, _on.png). With
r_flares on the flare in view must fade in fully and the two captures must
differ; with it off no flare may be lit. Then a cube is drawn between the
eye and the light, which no trace through the world would notice: the depth
buffer must hide the flare (_blocked.png). The cost of the depth readback
is printed: per read, and per frame with flares on and off.

    jac build scripts/flares_smoke.jac --native -o .jac/flares-smoke
    DYLD_LIBRARY_PATH=vendor .jac/flares-smoke
"""
import math;
import time;
import from pathlib { Path }
import from scripts.png_checks { read_png, different_pixels }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.render.quake { QuakeRenderer }
import from engine.render.effects { EffectQuads }
import from engine.render.flares { FlareRenderer }
import from engine.render.gpu { read_depth }
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from engine.world.flares { LightFlare, HasFlare }
import from engine.math.vec3 { Vec3, forward_from }

"""The world and its flares from `eye`, `count` frames a twentieth of a second
apart (a flare takes a seventh of a second to fade in), ending at `now`.
With `block`, a cube of that size is drawn 60 units along the view first,
as a model would be: into the depth buffer, not the collision world."""
def flare_frames(
    renderer: Renderer, drawing: QuakeRenderer, flares: FlareRenderer, quads: EffectQuads,
    world: World, level: Level, eye: Vec3, yaw: float, pitch: float, now: float, count: int = 8, block: float = 0.0
) -> float {
    ahead = forward_from(yaw, pitch);
    for frame in range(count) {
        now += 0.05;
        renderer.begin_frame(eye, yaw, pitch);
        drawing.view_forward = ahead;
        drawing.draw(level, level.visible(world, eye, True), eye);
        if block > 0.0 {
            middle = eye.add(ahead.scale(60.0));
            renderer.cubes.add(middle.x, middle.y, middle.z, block, 60, 90, 160, 255);
            renderer.cubes.draw();
        }
        flares.draw(world, level, drawing.shown_flares, quads, eye, ahead, now);
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
                lit = len([other for other in lights if other.main.intensity > 0.0]);
                print(
                    "FLARE", name, taken, "r_flares", setting, "lit", lit, "this", round(light.main.intensity, 3),
                    "adds", flares.adds, "tests", flares.tests, "renders", flares.renders, "->", shot
                );
                if setting == "1" {
                    assert light.main.intensity == 1.0 and light.main.visible and flares.tests >= 1;
                } else {
                    assert lit == 0 and flares.tests == 0;
                }
            }
            changed = different_pixels(read_png(Path(shots[0])), read_png(Path(shots[1])));
            print("FLARE", name, taken, "pixels changed", changed);
            assert changed > 500;
            # Something drawn in front of the light that the collision world
            # knows nothing of: RB_TestFlare's depth read hides the flare.
            assert level.collision.trace_point(eye, light.origin).fraction >= 0.9;
            now = flare_frames(renderer, drawing, flares, quads, world, level, eye, yaw, pitch, now, block=40.0);
            blocked = "flares_" + name + "_" + str(taken) + "_blocked.png";
            renderer.screenshot(blocked);
            print("FLARE", name, taken, "behind a cube: visible", light.main.visible, "intensity", round(light.main.intensity, 3), "->", blocked);
            assert not light.main.visible and light.main.intensity == 0.0;
            now = flare_frames(renderer, drawing, flares, quads, world, level, eye, yaw, pitch, now);
            assert light.main.visible and light.main.intensity == 1.0;
            if taken == 0 {
                # What the readback costs: one read, and a frame with and without flares.
                renderer.begin_frame(eye, yaw, pitch);
                drawing.draw(level, level.visible(world, eye, True), eye);
                started = time.time();
                for k in range(200) {
                    read_depth(0.0, 0.0);
                }
                each = (time.time() - started) * 1000.0 / 200.0;
                renderer.end_scene();
                renderer.end_frame();
                costs: list[float] = [];
                tests = 0;
                for setting in ["0", "1"] {
                    flares.cvars.flares.assign(setting);
                    now = flare_frames(renderer, drawing, flares, quads, world, level, eye, yaw, pitch, now, count=10);
                    started = time.time();
                    now = flare_frames(renderer, drawing, flares, quads, world, level, eye, yaw, pitch, now, count=120);
                    costs.append((time.time() - started) * 1000.0 / 120.0);
                    tests = flares.tests;
                }
                print(
                    "FLARE READBACK", name, "ms per depth read", round(each, 4), "frame ms without flares", round(costs[0], 3),
                    "with", round(costs[1], 3), "tests a frame", tests
                );
            }
            for other in lights {
                other.main.intensity = 0.0;
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
