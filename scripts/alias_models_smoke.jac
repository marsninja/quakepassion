"""Original MDL and MD3 assets rendered through the shared model renderer."""
import os;
import from pathlib { Path }
import from scripts.png_checks { check_image, different_pixels }
import from engine.assets.pak { open_pak, PakArchive }
import from engine.assets.pk3 { Pk3Assets }
import from engine.world.level { asset }
import from engine.formats.q1.model { parse_mdl }
import from engine.formats.q3.model { parse_md3 }
import from engine.formats.animated { AnimatedModel }
import from engine.formats.bsp { Texture }
import from engine.render.models { ModelRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

def capture(
    renderer: Renderer,
    model: AnimatedModel,
    skins: list[Texture],
    name: str,
    seconds: float = 0.0
) {
    drawing = ModelRenderer();
    drawing.upload(model, skins);
    for i in range(3) {
        renderer.begin_frame(Vec3(x=100.0, z=24.0), 3.14159265359, -0.1);
        drawing.draw(Vec3(), 0.4, eye=Vec3(x=100.0, z=24.0), seconds=seconds);
        renderer.end_scene();
        renderer.end_frame();
    }
    renderer.screenshot("qp_model_" + name + ".png");
    drawing.close();
    print("MODEL RENDER PASS", name);
}

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/";
    paks: list[PakArchive] = [];
    for filename in sorted(os.listdir(directory + "id1")) {
        if filename.lower().endswith(".pak") {
            paks.append(open_pak(directory + "id1/" + filename));
        }
    }
    renderer = Renderer();
    renderer.open_window();
    palette = asset(paks, "gfx/palette.lmp");
    for name in ["soldier", "shambler"] {
        model = parse_mdl(asset(paks, "progs/" + name + ".mdl"), palette);
        capture(renderer, model, [model.surfaces[0].embedded_skins[0]], "q1_" + name);
    }
    pk3 = Pk3Assets();
    pk3.open(directory + "baseq3");
    model = parse_md3(pk3.read("models/powerups/armor/armor_red.md3"));
    skins: list[Texture] = [];
    for surface in model.surfaces {
        surface.stages = pk3.model_stages(surface.skins[0]);
        texture = Texture(name=surface.skins[0]);
        pk3.texture(texture);
        skins.append(texture);
    }
    capture(renderer, model, skins, "q3_armor");
    capture(renderer, model, skins, "q3_armor_scrolled", 0.07);
    first = check_image(Path("qp_model_q3_armor.png"));
    second = check_image(Path("qp_model_q3_armor_scrolled.png"));
    assert different_pixels(first, second) > 100;
    pk3.close();
    renderer.close();
}
