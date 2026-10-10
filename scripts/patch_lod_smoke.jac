"""Original arenas: Q3 patches thinned with distance (RB_SurfaceGrid). From
each map's first spawn point, looking the way it faces, the view is drawn
with r_lodCurveError at its default, with every row and column
(a huge allowance) and with the fewest (a negative one), and saved as
patch_lod_<map>_default.png, _full.png and _coarse.png. The patches in view
and their triangles are printed for each; the default must draw no more
than the full set and no fewer than the coarsest, and thinning must change
the picture.

    jac build scripts/patch_lod_smoke.jac --native -o .jac/patch-lod-smoke
    DYLD_LIBRARY_PATH=vendor .jac/patch-lod-smoke
"""
import math;
import from pathlib { Path }
import from scripts.png_checks { read_png, different_pixels }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.render.quake { QuakeRenderer }
import from engine.render.world_mesh { grid_lines, CURVE_LOD_ERROR }
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from engine.math.vec3 { Vec3, forward_from }

"""The triangles the view's patches were last gathered with."""
def curve_triangles(level: Level, drawing: QuakeRenderer) -> int {
    total = 0;
    for view in drawing.views {
        if view.used != drawing.view_clock {
            continue;
        }
        for k in range(len(view.curves)) {
            face = level.bsp.faces[view.curves[k]];
            steps = drawing.curve_steps[view.curves[k]];
            allowed = steps[view.levels[k] - 1] if view.levels[k] > 0 else 0.0;
            total += (len(grid_lines(face.width_errors, allowed)) - 1) * (len(grid_lines(face.height_errors, allowed)) - 1) * 2;
        }
    }
    return total;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    for name in ["q3dm1", "q3dm7", "q3dm17"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        drawing = QuakeRenderer();
        drawing.upload(level);
        eye = Vec3();
        yaw = 0.0;
        for entity in level.bsp.entities {
            if entity.fields.get("classname", "") == "info_player_deathmatch" {
                parts = entity.fields.get("origin", "0 0 0").split();
                eye = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]) + 26.0);
                yaw = math.radians(float(entity.fields.get("angle", "0") or "0"));
                break;
            }
        }
        counts: list[int] = [];
        shots: list[str] = [];
        for (label, allowance) in [("default", CURVE_LOD_ERROR), ("full", 1000000000.0), ("coarse", -1.0)] {
            drawing.lod_curve_error = allowance;
            for frame in range(3) {
                renderer.begin_frame(eye, yaw, 0.0);
                drawing.view_forward = forward_from(yaw, 0.0);
                drawing.draw(level, level.visible(world, eye, True), eye);
                renderer.end_scene();
                renderer.end_frame();
            }
            shot = "patch_lod_" + name + "_" + label + ".png";
            renderer.screenshot(shot);
            shots.append(shot);
            patches = 0;
            for view in drawing.views {
                if view.used == drawing.view_clock {
                    patches = len(view.curves);
                }
            }
            counts.append(curve_triangles(level, drawing));
            print("PATCH LOD", name, label, "patches in view", patches, "triangles", counts[-1], "->", shot);
        }
        assert counts[2] <= counts[0] and counts[0] <= counts[1] and counts[2] < counts[1];
        thinned = different_pixels(read_png(Path(shots[1])), read_png(Path(shots[2])));
        kept = different_pixels(read_png(Path(shots[1])), read_png(Path(shots[0])));
        print("PATCH LOD", name, "pixels full to coarse", thinned, "full to default", kept);
        assert thinned > 0;
        drawing.close();
    }
    renderer.close();
    print("PATCH LOD SMOKE PASS");
}
