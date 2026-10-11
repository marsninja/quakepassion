import from engine.math.vec3 { Vec3 }
import from engine.world.world { World }
import from engine.world.level { Level, prepare_level, spawn_player }
import from editor.document.scene { Scene }
import from editor.geometry.brush { box_sides }
import from editor.compile.live { compile_scene, SwatchMaterials, swatch_texture, material_hidden }
import from editor.compile.light { bake_light, scene_lamps, BrushOccluder }
import from editor.compile.bake { bake_cells, leaf_at }

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

def lit_yard -> Scene {
    scene = Scene(game="passion", name="studio:lit");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=32.0, y=-64.0, z=0.0), Vec3(x=48.0, y=64.0, z=128.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "-64 0 24"});
    return scene;
}

test "a group's brushes are built as part of the world" {
    scene = lit_yard();
    group = scene.add_item({"classname": "func_group", "_group_name": "crates"});
    scene.add_solid(group, box_sides(Vec3(x=-96.0, y=64.0, z=0.0), Vec3(x=-64.0, y=96.0, z=32.0), "crate"));
    made = compile_scene(scene, SwatchMaterials());
    assert made.brushes == 3 and made.bsp.models[0].face_count == 18;
    assert len([entity for entity in made.bsp.entities if entity.fields.get("classname", "") == "func_group"]) == 0;
}

test "lamps are the scene's light entities, with their reach and colour" {
    scene = lit_yard();
    assert len(scene_lamps(scene)) == 0;
    scene.add_item({"classname": "light", "origin": "0 0 96"});
    scene.add_item({"classname": "light_torch_small_walltorch", "origin": "-64 0 64", "light": "150", "_color": "255 128 0"});
    scene.add_item({"classname": "light", "light": "200"});
    scene.add_item({"classname": "light", "origin": "0 0 0", "light": "0"});
    lamps = scene_lamps(scene);
    assert len(lamps) == 2;
    assert lamps[0].radius == 600.0 and lamps[0].color.x == 1.0 and lamps[0].origin.z == 96.0;
    assert lamps[1].radius == 300.0 and abs(lamps[1].color.y - 128.0 / 255.0) < 0.001 and lamps[1].color.z == 0.0;
}

test "a brush between a point and a lamp shadows it" {
    shadows = BrushOccluder();
    shadows.add(box_sides(Vec3(x=32.0, y=-64.0, z=0.0), Vec3(x=48.0, y=64.0, z=128.0), "wall"));
    lamp = Vec3(x=0.0, y=0.0, z=64.0);
    assert shadows.visibility(Vec3(x=100.0, y=0.0, z=0.25), lamp) == 0.0;
    assert shadows.visibility(Vec3(x=-100.0, y=0.0, z=0.25), lamp) == 1.0;
    # Round the end of the wall, and from on the wall's own lit side.
    assert shadows.visibility(Vec3(x=100.0, y=120.0, z=0.25), Vec3(x=0.0, y=120.0, z=64.0)) == 1.0;
    assert shadows.visibility(Vec3(x=31.75, y=0.0, z=64.0), lamp) == 1.0;
}

test "a scene with a light gets a lightmap on every face of the world" {
    scene = lit_yard();
    made = compile_scene(scene, SwatchMaterials());
    # Without a light it stays as the compiler shaded it.
    assert bake_light(scene, made) == 0 and len(made.bsp.lighting) == 0;
    assert made.bsp.faces[0].light_offset < 0 and len(made.bsp.faces[0].colors) > 0;
    scene.add_item({"classname": "light", "origin": "0 0 64", "light": "300"});
    made = compile_scene(scene, SwatchMaterials());
    count = bake_light(scene, made);
    assert count > 0 and len(made.bsp.lighting) == count * 3 and made.bsp.light_channels == 3;
    floor_top = [face for face in made.bsp.faces if face.normal.z > 0.5 and face.plane_dist == 0.0][0];
    assert floor_top.light_width == 17 and floor_top.light_height == 17 and floor_top.light_offset >= 0;
    assert len(floor_top.colors) == 0 and len(floor_top.light_uv) == len(floor_top.vertices) * 2;
    for value in floor_top.light_uv {
        assert value >= 0.0 and value <= 16.0;
    }
    block = made.bsp.lighting[floor_top.light_offset:floor_top.light_offset + 17 * 17 * 3];
    # Bright under the lamp, down to the scene's least light in the wall's shadow.
    assert max(block) > 80 and min(block) == 31;
    scene.world().fields["_minlight"] = "20";
    dim = compile_scene(scene, SwatchMaterials());
    assert bake_light(scene, dim) == count;
    dim_top = [face for face in dim.bsp.faces if face.normal.z > 0.5 and face.plane_dist == 0.0][0];
    assert min(dim.bsp.lighting[dim_top.light_offset:dim_top.light_offset + 17 * 17 * 3]) == 15;
    scene.world().fields.pop("_minlight");
    # A scene too large for the budget is left flat, and says so.
    again = compile_scene(scene, SwatchMaterials());
    assert bake_light(scene, again, 16.0, 100) == 0 and len(again.bsp.lighting) == 0;
    assert len([warning for warning in again.warnings if "too large to light" in warning]) == 1;
}

test "a lit scene prepares as a level" {
    scene = lit_yard();
    scene.add_item({"classname": "light", "origin": "0 0 64", "light": "300"});
    made = compile_scene(scene, SwatchMaterials());
    assert bake_light(scene, made) > 0;
    world = World();
    level = Level(active=True, name="studio:lit", bsp=made.bsp);
    prepare_level(world, level);
    assert level.bsp.light_channels == 3 and len(level.bsp.lighting) > 0;
    assert len(level.visible(world, Vec3(x=-64.0, y=0.0, z=32.0), True)) == 12;
}

"""A hall with walls all round, a roof, and a wall across its middle."""
def walled_hall -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-256.0, y=-128.0, z=-16.0), Vec3(x=256.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=-256.0, y=-128.0, z=192.0), Vec3(x=256.0, y=128.0, z=208.0), "roof"));
    scene.add_solid(world, box_sides(Vec3(x=-272.0, y=-128.0, z=0.0), Vec3(x=-256.0, y=128.0, z=192.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=256.0, y=-128.0, z=0.0), Vec3(x=272.0, y=128.0, z=192.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-272.0, y=-144.0, z=0.0), Vec3(x=272.0, y=-128.0, z=192.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-272.0, y=128.0, z=0.0), Vec3(x=272.0, y=144.0, z=192.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-8.0, y=-128.0, z=0.0), Vec3(x=8.0, y=128.0, z=192.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "-192 0 24"});
    return scene;
}

test "a baked level prepares, finds the player's cell and draws less behind a wall" {
    scene = walled_hall();
    made = compile_scene(scene, SwatchMaterials());
    total = len(made.bsp.leaves[0].faces);
    bake_cells(scene, made, 128.0);
    world = World();
    level = Level(active=True, name="studio:test", bsp=made.bsp);
    prepare_level(world, level);
    leaf = level.locate(Vec3(x=-192.0, y=0.0, z=56.0));
    assert leaf == leaf_at(made.bsp, made.bsp.models[0].head, Vec3(x=-192.0, y=0.0, z=56.0));
    # From the west room, the faces of the east room's cells are left out.
    drawn = level.visible(world, Vec3(x=-192.0, y=0.0, z=56.0), True);
    everything = level.visible(world, Vec3(x=-192.0, y=0.0, z=56.0), False);
    assert 0 < len(drawn) and len(drawn) < len(everything) and len(everything) == total;
}
