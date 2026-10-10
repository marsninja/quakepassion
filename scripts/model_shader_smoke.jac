"""Q3 model shaders on the models that carry them: three pages of original
MD3s whose skins are shader scripts (lit and alpha-tested stages, specular
skins, custom blends, back-sided fluid, entity colour, deformVertexes), each
captured at two shader times (`model_shaders_<page>_<n>.png`). The two
captures of a page must differ: its scrolls, waves and deforms move.

    jac build scripts/model_shader_smoke.jac --native -o .jac/model-shader-smoke
    DYLD_LIBRARY_PATH=vendor .jac/model-shader-smoke
"""
import os;
import from pathlib { Path }
import from scripts.png_checks { read_png, different_pixels }
import from engine.assets.library { AssetLibrary, ModelAsset }
import from engine.render.renderer { Renderer }
import from engine.render.models { ModelRenderer }
import from games.arena_character { player_part }
import from engine.world.lighting { Illumination }
import from engine.math.vec3 { Vec3 }

"""One gallery entry: a model, the frame it shows and how far it stands from
the next."""
obj GalleryModel {
    has drawing: ModelRenderer,
        frame: int = 0,
        width: float = 40.0,
        lift: float = 0.0;
}

def gallery_model(loaded: ModelAsset, frame: int = 0, width: float = 40.0, lift: float = 0.0) -> GalleryModel {
    drawing = ModelRenderer();
    drawing.upload(loaded.model, loaded.skins);
    return GalleryModel(drawing=drawing, frame=min(frame, max(0, drawing.frame_count - 1)), width=width, lift=lift);
}

"""Draw `row` side by side in front of the eye at shader time `seconds`."""
def draw_gallery(renderer: Renderer, row: list[GalleryModel], seconds: float, light: Illumination, name: str) {
    total = 0.0;
    for shown in row {
        total += shown.width;
    }
    eye = Vec3(x=-max(90.0, total * 0.42), z=10.0);
    for frame in range(3) {
        renderer.begin_frame(eye, 0.0, 0.0);
        at = total * 0.5;
        for shown in row {
            at -= shown.width * 0.5;
            shown.drawing.draw(
                Vec3(y=at, z=shown.lift), 2.5, shown.frame, shown.frame, 0.0, eye=eye,
                seconds=seconds, illumination=light, entity_color=[1.0, 0.5, 0.0, 1.0]
            );
            at -= shown.width * 0.5;
        }
        renderer.end_scene();
        if frame == 2 {
            renderer.screenshot(name);
        }
        renderer.end_frame();
    }
}

with entry {
    library = AssetLibrary(game="q3");
    library.open(os.getenv("HOME", "") + "/quake-assets/baseq3");
    renderer = Renderer();
    renderer.open_window();
    pages: dict[str, list[GalleryModel]] = {
        "items": [
            gallery_model(library.model("models/flags/b_flag.md3"), width=70.0, lift=-30.0),
            gallery_model(library.model("models/powerups/holdable/medkit.md3")),
            gallery_model(library.model("models/powerups/holdable/teleporter.md3")),
            gallery_model(library.model("models/powerups/armor/shard.md3")),
            gallery_model(library.model("models/powerups/ammo/rocketam.md3")),
            gallery_model(library.model("models/weapons2/railgun/railgun.md3"), width=60.0),
            gallery_model(library.model("models/weapons2/plasma/plasma.md3"), width=60.0),
            gallery_model(library.model("models/weapons2/bfg/bfg.md3"), width=60.0),
            gallery_model(library.model("models/weaphits/bfg.md3"))
        ],
        "players": [
            gallery_model(player_part(library, "head", "bones"), width=30.0),
            gallery_model(player_part(library, "head", "hunter"), width=30.0),
            gallery_model(player_part(library, "upper", "uriel"), frame=151, width=70.0),
            gallery_model(player_part(library, "upper", "xaero"), frame=151, width=50.0),
            gallery_model(player_part(library, "lower", "xaero"), frame=180, width=50.0),
            gallery_model(player_part(library, "lower", "slash", "yuriko"), frame=180, width=50.0),
            gallery_model(player_part(library, "upper", "biker", "cadavre"), frame=151, width=50.0),
            gallery_model(player_part(library, "upper", "lucy", "angel"), frame=151, width=50.0),
            gallery_model(player_part(library, "head", "xian"), width=30.0)
        ],
        "objects": [
            gallery_model(library.model("models/mapobjects/jets/jets01.md3"), width=80.0),
            gallery_model(library.model("models/mapobjects/bitch/fembotbig.md3"), width=160.0, lift=-60.0),
            gallery_model(library.model("models/mapobjects/skel/xray.md3"), width=90.0, lift=-40.0),
            gallery_model(library.model("models/mapobjects/pipe/pipe02.md3"), width=120.0)
        ]
    };
    library.close();
    light = Illumination(
        enabled=True, ambient=Vec3(x=0.3, y=0.3, z=0.32), directed=Vec3(x=0.7, y=0.65, z=0.55),
        direction=Vec3(x=-0.6, y=-0.4, z=0.7).normalized()
    );
    for (page, row) in pages.items() {
        for (n, seconds) in [(0, 0.4), (1, 1.3)] {
            draw_gallery(renderer, row, seconds, light, "model_shaders_" + page + "_" + str(n) + ".png");
        }
        first = read_png(Path("model_shaders_" + page + "_0.png"));
        second = read_png(Path("model_shaders_" + page + "_1.png"));
        moved = different_pixels(first, second);
        print("MODEL SHADERS", page, "models", len(row), "moved pixels", moved);
        assert moved > 100;
        for shown in row {
            shown.drawing.close();
        }
    }
    renderer.close();
    print("MODEL SHADER SMOKE DONE");
}
