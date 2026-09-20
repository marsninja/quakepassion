"""Desktop model geometry, skin and vertex-animation inspection."""
import os;
import from engine.assets.pak { open_pak, PakArchive }
import from engine.world.level { asset }
import from engine.formats.q2.model { parse_md2, parse_pcx }
import from engine.render.models { ModelRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/baseq2";
    paks: list[PakArchive] = [];
    for filename in sorted(os.listdir(directory)) {
        if filename.lower().endswith(".pak") {
            paks.append(open_pak(directory + "/" + filename));
        }
    }
    renderer = Renderer();
    renderer.open_window();
    for name in ["soldier", "berserk"] {
        model = parse_md2(asset(paks, "models/monsters/" + name + "/tris.md2"));
        skin = parse_pcx(asset(paks, model.surfaces[0].skins[0]), name);
        drawing = ModelRenderer();
        drawing.upload(model, [skin]);
        for frame in [0, 10] {
            for i in range(3) {
                renderer.begin_frame(Vec3(x=100.0, z=24.0), 3.14159265359, -0.1);
                drawing.draw(Vec3(), 0.0, frame, frame + 1, 0.5);
                renderer.end_scene();
                renderer.end_frame();
            }
            renderer.screenshot("qp_model_" + name + "_" + str(frame) + ".png");
        }
        drawing.close();
        print("MODEL RENDER PASS", name);
    }
    renderer.close();
}
