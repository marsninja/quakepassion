import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene }
import from editor.geometry.brush { box_sides }
import from editor.compile.live { compile_scene, SwatchMaterials }
import from editor.compile.light { bake_light, light_job }

def lit_yard -> Scene {
    scene = Scene(game="passion", name="studio:lit");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=32.0, y=-64.0, z=0.0), Vec3(x=48.0, y=64.0, z=128.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "-64 0 24"});
    scene.add_item({"classname": "light", "origin": "0 0 64", "light": "300"});
    return scene;
}

test "a level lit a few faces at a time comes out as one lit at once" {
    scene = lit_yard();
    whole = compile_scene(scene, SwatchMaterials());
    count = bake_light(scene, whole);
    sliced = compile_scene(scene, SwatchMaterials());
    job = light_job(scene, sliced);
    assert job is not None and job.share() == 0.0 and not job.finished();
    steps = 0;
    while not job.step(2) {
        steps += 1;
        assert job.share() > 0.0 and job.share() < 1.0;
    }
    assert steps > 0 and job.share() == 1.0;
    assert job.finish() == count and sliced.bsp.lighting == whole.bsp.lighting;
    # No lamps: no job.
    bare = Scene(game="passion", name="studio:bare");
    bare.add_solid(bare.world(), box_sides(Vec3(x=-64.0, y=-64.0, z=-16.0), Vec3(x=64.0, y=64.0), "floor"));
    assert light_job(bare, compile_scene(bare, SwatchMaterials())) is None;
}
