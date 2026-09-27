"""GPU model animation against the immediate path: original Q1, Q2 and Q3
models drawn mid-blend, lit, faded, and the Q3 torso again with its quad
damage shell (scrolled, pushed out along the normals), first through the GPU
keyframe shader (model_gpu_smoke_gpu.png) and then through the legacy CPU
pose (model_gpu_smoke_cpu.png), from the same view. The two pictures should
match.

    jac build scripts/model_gpu_smoke.jac --native -o .jac/model-gpu-smoke
    DYLD_LIBRARY_PATH=vendor .jac/model-gpu-smoke
"""
import os;
import from engine.assets.library { AssetLibrary }
import from engine.render.renderer { Renderer }
import from engine.render.models { ModelRenderer }
import from engine.formats.animated { AnimatedModel, AnimatedSurface }
import from games.arena_character { player_part }
import from engine.world.lighting { Illumination }
import from engine.math.vec3 { Vec3 }
import from engine.math.orientation { model_basis }

with entry {
    home = os.getenv("HOME", "");
    games = ["q1", "q2", "q3"];
    directories = [home + "/quake-assets/id1", home + "/quake-assets/baseq2", home + "/quake-assets/baseq3"];
    paths = ["progs/soldier.mdl", "models/monsters/soldier/tris.md2", "models/players/sarge/upper.md3"];
    firsts = [1, 3, 110];
    renderer = Renderer();
    renderer.open_window();
    drawings: list[ModelRenderer] = [];
    shell = ModelRenderer();
    for g in range(len(games)) {
        library = AssetLibrary(game=games[g]);
        library.open(directories[g]);
        loaded = player_part(library, "upper") if games[g] == "q3" else library.model(paths[g]);
        drawing = ModelRenderer();
        drawing.upload(loaded.model, loaded.skins);
        drawings.append(drawing);
        if games[g] == "q3" {
            stages = library.pk3.model_stages("powerups/quad", True);
            assert stages;
            shell.upload(AnimatedModel(surfaces=[AnimatedSurface(name="powerups/quad", stages=stages)]), [stages[0].texture]);
        }
        library.close();
        print("MODEL", paths[g], "frames", drawing.frame_count, "keyframes", drawing.keyframes, "corners", drawing.counts);
    }
    light = Illumination(enabled=True, ambient=Vec3(x=0.35, y=0.3, z=0.3), directed=Vec3(x=0.6, y=0.6, z=0.5), direction=Vec3(x=0.5, y=-0.5, z=0.7).normalized());
    eye = Vec3(x=-170.0);
    yaw = 2.6;
    for name in ["gpu", "cpu"] {
        for frame in range(3) {
            renderer.begin_frame(eye, 0.0, 0.0);
            for i in range(len(drawings)) {
                origin = Vec3(y=40.0 - float(i) * 40.0, z=25.0);
                if name == "gpu" {
                    drawings[i].draw(origin, yaw, firsts[i], firsts[i] + 1, 0.5, eye=eye, illumination=light, basis=model_basis(yaw, 0.0));
                    drawings[i].draw(origin.add(Vec3(z=-60.0)), yaw, firsts[i], firsts[i] + 1, 0.25, eye=eye, seconds=1.3, alpha=0.5);
                } else {
                    drawings[i].draw_immediate(origin, yaw, firsts[i], firsts[i] + 1, 0.5, eye=eye, illumination=light, basis=model_basis(yaw, 0.0));
                    drawings[i].draw_immediate(origin.add(Vec3(z=-60.0)), yaw, firsts[i], firsts[i] + 1, 0.25, eye=eye, seconds=1.3, alpha=0.5);
                }
            }
            # The quad shell over a lit Q3 torso.
            q3 = drawings[2];
            spot = Vec3(y=-80.0, z=-5.0);
            if name == "gpu" {
                q3.draw(spot, yaw, 110, 111, 0.5, eye=eye, illumination=light);
                q3.draw(spot, yaw, 110, 111, 0.5, eye=eye, seconds=1.3, illumination=light, overlay=shell, inflate=3.0);
            } else {
                q3.draw_immediate(spot, yaw, 110, 111, 0.5, eye=eye, illumination=light);
                q3.draw_immediate(spot, yaw, 110, 111, 0.5, eye=eye, seconds=1.3, illumination=light, overlay=shell, inflate=3.0);
            }
            renderer.end_scene();
            if frame == 2 {
                renderer.screenshot("model_gpu_smoke_" + name + ".png");
            }
            renderer.end_frame();
        }
    }
    for drawing in drawings {
        drawing.close();
    }
    shell.close();
    renderer.close();
    print("MODEL GPU SMOKE DONE");
}
