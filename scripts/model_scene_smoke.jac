"""Native shared model resources collected through the spatial world graph."""
import os;
import from engine.assets.library { AssetLibrary }
import from engine.world.world { World, Area, Actor, move_to_area }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.render.models { ModelScene }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

with entry {
    library = AssetLibrary(game="q2");
    library.open(os.getenv("HOME", "") + "/quake-assets/baseq2");
    loaded = library.model("models/monsters/soldier/tris.md2");
    assert library.model("models/monsters/soldier/tris.md2") is loaded;
    world = World();
    area = Area(
        name="stage",
        bounds=AABB(
            mins=Vec3(x=-100.0, y=-100.0, z=-100.0),
            maxs=Vec3(x=100.0, y=100.0, z=100.0)
        )
    );
    world ++> area;
    resource = ModelResource(name="soldier", model=loaded.model, skins=loaded.skins);
    world +>:HasModelResource:+> resource;
    for y in [-25.0, 25.0] {
        actor = Actor(pos=Vec3(y=y));
        move_to_area(actor, area);
        attach_model(actor, resource);
    }
    library.close();
    renderer = Renderer();
    renderer.open_window();
    scene = ModelScene();
    scene.upload(world);
    assert len(scene.resources) == 1;
    for i in range(3) {
        renderer.begin_frame(Vec3(x=120.0, z=24.0), 3.14159265359, -0.1);
        scene.draw(world);
        renderer.end_scene();
        renderer.end_frame();
    }
    renderer.screenshot("qp_model_scene.png");
    scene.close();
    renderer.close();
    print("MODEL SCENE PASS shared resource spatial traversal");
}
