import from engine.math.vec3 { Vec3 }
import from engine.world.world { World }
import from engine.world.level { Level, prepare_level, spawn_player }
import from editor.document.scene { Scene }
import from editor.geometry.brush { box_sides }
import from editor.compile.live { compile_scene, SwatchMaterials, swatch_texture, material_hidden }

"""A room: a floor, two walls, a door of one brush, a trigger and a start."""
def room -> Scene {
    scene = Scene(game="passion", name="studio:room");
    world = scene.world();
    world.fields["message"] = "A room";
    scene.add_solid(world, box_sides(Vec3(x=-256.0, y=-256.0, z=-16.0), Vec3(x=256.0, y=256.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=-256.0, y=240.0, z=0.0), Vec3(x=256.0, y=256.0, z=128.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=240.0, y=-256.0, z=0.0), Vec3(x=256.0, y=240.0, z=128.0), "clip"));
    door = scene.add_item({"classname": "func_door", "angle": "-1", "model": "*9"});
    scene.add_solid(door, box_sides(Vec3(x=-32.0, y=100.0, z=0.0), Vec3(x=32.0, y=116.0, z=96.0), "door"));
    pad = scene.add_item({"classname": "trigger_once", "target": "t1"});
    scene.add_solid(pad, box_sides(Vec3(x=-64.0, y=-64.0, z=0.0), Vec3(x=64.0, y=64.0, z=64.0), "trigger"));
    scene.add_item({"classname": "info_player_start", "origin": "0 -128 24", "angle": "90"});
    scene.add_item({"classname": "func_wall", "model": "*3"});
    return scene;
}

test "a swatch is a colour from the name with its grid drawn in" {
    one = swatch_texture("wall");
    two = swatch_texture("floor");
    assert one.width == 64 and one.height == 64 and len(one.rgba) == 64 * 64 * 4 and one.name == "studio:wall";
    assert one.rgba[0:3] != two.rgba[0:3];
    # The line at the edge is darker than the field.
    assert int(one.rgba[0]) < int(one.rgba[(9 * 64 + 9) * 4]);
    assert swatch_texture("wall").rgba == one.rgba;
    assert material_hidden("clip") and material_hidden("common/caulk") and material_hidden("q3:textures/common/trigger");
    assert not material_hidden("q1:e1m1/tech04_1");
}

test "the world's brushes are model 0 and each brush entity gets a model" {
    built = compile_scene(room(), SwatchMaterials());
    bsp = built.bsp;
    assert bsp.game == "passion" and built.brushes == 5 and len(bsp.brushes) == 5;
    assert len(bsp.models) == 3 and bsp.models[0].head == -1 and bsp.models[0].vis_leaf_count == 0;
    # Two world brushes draw six faces each; the clip brush draws none.
    assert bsp.models[0].first_face == 0 and bsp.models[0].face_count == 12 and len(bsp.models[0].brushes) == 3;
    assert bsp.models[1].first_face == 12 and bsp.models[1].face_count == 6;
    assert bsp.models[2].face_count == 0 and len(bsp.models[2].brushes) == 1;
    assert bsp.brushes[4].contents == 0 and bsp.brushes[0].contents == 1 and len(bsp.brushes[0].planes) == 6;
    assert len(bsp.faces) == 18 and len(bsp.leaves) == 1 and len(bsp.leaves[0].faces) == 18;
    assert bsp.models[1].mins.y == 100.0 and bsp.models[1].maxs.z == 96.0;
    assert bsp.leaves[0].mins.x <= -320.0 and bsp.leaves[0].maxs.z >= 192.0;
    assert bsp.clusters == 1 and bsp.cluster_bytes == 1 and len(bsp.visibility) == 9 and int(bsp.visibility[8]) == 1;
    assert [texture.name for texture in bsp.textures] == ["studio:floor", "studio:wall", "studio:door"];
}

test "entities carry their models by number, and what cannot be is said" {
    built = compile_scene(room(), SwatchMaterials());
    fields = [entity.fields for entity in built.bsp.entities];
    assert fields[0] == {"classname": "worldspawn", "message": "A room"};
    assert fields[1]["classname"] == "func_door" and fields[1]["model"] == "*1";
    assert fields[2]["classname"] == "trigger_once" and fields[2]["model"] == "*2";
    assert fields[3]["origin"] == "0 -128 24";
    assert "model" not in fields[4];
    assert built.warnings == ["func_wall names a map model the scene does not have"];
    empty = compile_scene(Scene(game="passion", name="studio:empty"), SwatchMaterials());
    assert len(empty.bsp.models) == 2 and "The scene has no info_player_start" in empty.warnings;
}

test "faces wind for the renderer, map their material and remember their brush" {
    scene = room();
    built = compile_scene(scene, SwatchMaterials());
    bsp = built.bsp;
    floor = scene.solids()[0];
    assert built.faces_of[floor.serial] == [0, 1, 2, 3, 4, 5];
    for index in built.faces_of[floor.serial] {
        face = bsp.faces[index];
        assert len(face.vertices) == 4 and face.indices == [0, 1, 2, 0, 2, 3];
        facing = face.vertices[1].sub(face.vertices[0]).cross(face.vertices[2].sub(face.vertices[0])).normalized();
        assert abs(facing.dot(face.normal) - 1.0) < 0.001;
        assert len(face.uv) == 8 and len(face.colors) == 16;
    }
    top = bsp.faces[4];
    assert top.normal.z == 1.0 and top.plane_dist == 0.0 and top.colors[0] == 255;
    # 512 units of floor across a 64 texel swatch is eight repeats.
    spread = max([top.uv[i] for i in range(0, 8, 2)]) - min([top.uv[i] for i in range(0, 8, 2)]);
    assert abs(spread - 8.0) < 0.001;
}

test "a compiled scene prepares as a level and holds the player up" {
    built = compile_scene(room(), SwatchMaterials());
    world = World();
    level = Level(active=True, name="studio:room", bsp=built.bsp);
    prepare_level(world, level);
    assert len(level.areas) == 1 and level.locate(Vec3(x=0.0, y=0.0, z=32.0)) == 0;
    assert len(level.source_entities) == 5;
    player = spawn_player(level);
    assert player.pos.x == 0.0 and player.pos.y == -128.0;
    # Straight down from above the floor stops on it; out past the clip wall does not pass.
    down = level.collision.trace_point(Vec3(x=0.0, y=-128.0, z=64.0), Vec3(x=0.0, y=-128.0, z=-64.0));
    assert abs(down.fraction - 0.5) < 0.01;
    across = level.collision.trace_point(Vec3(x=0.0, y=0.0, z=32.0), Vec3(x=400.0, y=0.0, z=32.0));
    assert across.fraction < 0.62;
    faces = level.visible(world, Vec3(x=0.0, y=0.0, z=32.0), True);
    assert len(faces) == 18;
}
