"""Original maps: Q3 fog volumes load their shader's colour and thickness, and
draw from outside and from inside the fog."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from engine.render.quake { QuakeRenderer, fog_density }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3, forward_from }

def shoot(renderer: Renderer, drawing: QuakeRenderer, level: Level, world: World, eye: Vec3, yaw: float, pitch: float, name: str) {
    for frame in range(3) {
        renderer.begin_frame(eye, yaw, pitch);
        drawing.view_forward = forward_from(yaw, pitch);
        drawing.draw(level, level.visible(world, eye, False), eye);
        renderer.end_scene();
        renderer.end_frame();
    }
    renderer.screenshot(name);
}

"""An open point above the fog's middle with a clear view down into it."""
def overlook(level: Level, middle: Vec3, top: float) -> Vec3 | None {
    for height in [96.0, 160.0, 64.0, 256.0, 32.0] {
        for offset in [Vec3(), Vec3(x=128.0), Vec3(x=-128.0), Vec3(y=128.0), Vec3(y=-128.0)] {
            spot = Vec3(x=middle.x + offset.x, y=middle.y + offset.y, z=top + height);
            if level.collision.trace_point(spot, spot).start_solid {
                continue;
            }
            return spot;
        }
    }
    return None;
}

with entry {
    assert fog_density(0.0, 0.5) == 0.0 and fog_density(0.2, 31.5 / 32.0) == 1.0;
    renderer = Renderer();
    renderer.open_window();
    for name in ["q3dm9", "q3tourney2", "q3dm12"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        drawing = QuakeRenderer();
        drawing.upload(level);
        fogs = level.bsp.fogs;
        fogged = len([face for face in level.bsp.faces if face.fog >= 0]);
        only = len([face for face in level.bsp.faces if face.fog_only]);
        print("FOG", name, "volumes", len(fogs), "fogged faces", fogged, "fog surfaces", only);
        assert fogs and fogged > 0;
        for i in range(len(fogs)) {
            fog = fogs[i];
            print("FOG", name, i, fog.shader, "color", fog.color.x, fog.color.y, fog.color.z, "depth", fog.depth, "surface", fog.has_surface);
            assert fog.color.length() > 0.0;
        }
        # The largest volume, looked into from above and from within.
        biggest = fogs[0];
        for fog in fogs {
            if fog.maxs.sub(fog.mins).length() > biggest.maxs.sub(biggest.mins).length() {
                biggest = fog;
            }
        }
        middle = biggest.mins.lerp(biggest.maxs, 0.5);
        eye = overlook(level, middle, biggest.maxs.z);
        if eye is not None {
            shoot(renderer, drawing, level, world, eye, 0.3, -0.9, "fog_" + name + "_above.png");
        }
        inside = Vec3(x=middle.x, y=middle.y, z=biggest.maxs.z - 8.0);
        if not level.collision.trace_point(inside, inside).start_solid {
            shoot(renderer, drawing, level, world, inside, 0.3, 0.0, "fog_" + name + "_inside.png");
        }
        drawing.close();
        print("FOG PASS", name);
    }
    renderer.close();
}
