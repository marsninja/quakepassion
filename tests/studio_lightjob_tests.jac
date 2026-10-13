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

import from editor.compile.kept { keep_bake, give_bake }
import from engine.world.lighting { load_light_grid }

"""The floor's top face of a compiled yard."""
def floor_top(made: LiveLevel) -> int {
    for (index, face) in enumerate(made.bsp.faces) {
        if face.normal.z > 0.5 and face.plane_dist == 0.0 {
            return index;
        }
    }
    return -1;
}

import from editor.compile.live { LiveLevel }

"""The light of one sample of a face's steady layer: column x, row y."""
def sample_light(made: LiveLevel, index: int, x: int, y: int) -> int {
    face = made.bsp.faces[index];
    at = face.light_offset + (y * face.light_width + x) * 3;
    return int(made.bsp.lighting[at]) + int(made.bsp.lighting[at + 1]) + int(made.bsp.lighting[at + 2]);
}

test "light bounces off what it lights into the shadows" {
    flat = lit_yard();
    flat.world().fields["_bounce"] = "0";
    direct = compile_scene(flat, SwatchMaterials());
    bake_light(flat, direct);
    scene = lit_yard();
    bounced = compile_scene(scene, SwatchMaterials());
    bake_light(scene, bounced);
    top = floor_top(bounced);
    # The wall's side the lamp lights takes light back from the lit floor
    # before it, more toward its foot.
    side = [index for (index, face) in enumerate(bounced.bsp.faces) if face.normal.x < -0.5 and abs(face.plane_dist + 32.0) < 0.01][0];
    wall = bounced.bsp.faces[side];
    assert sum([sample_light(bounced, side, x, 0) for x in range(wall.light_width)]) > sum([sample_light(direct, side, x, 0) for x in range(wall.light_width)]);
    # The floor takes some back from the wall, and never loses any.
    assert sample_light(bounced, top, 4, 8) >= sample_light(direct, top, 4, 8);
    assert "patches=" in bounced.light_notes and "rays=0" not in bounced.light_notes;
    assert "patches=0" in direct.light_notes;
}

test "a face whose material glows lights what is near it" {
    scene = lit_yard();
    scene.world().fields["_bounce"] = "1";
    for item in list(scene.items()) {
        if item.classname() == "light" {
            item.fields["light"] = "1";
        }
    }
    plain = compile_scene(scene, SwatchMaterials());
    bake_light(scene, plain);
    wall = scene.solids()[1];
    # The wall's side facing the floor's west half glows (Quake II's light flag and value).
    for side in wall.sides {
        if side.plane.normal.x < -0.5 {
            side.flags = 1;
            side.value = 300;
        }
    }
    glowing = compile_scene(scene, SwatchMaterials());
    bake_light(scene, glowing);
    top = floor_top(glowing);
    assert sample_light(glowing, top, 9, 8) > sample_light(plain, top, 9, 8) + 30;
    assert "glowing=1" in glowing.light_notes;
}

test "a switched light and a flickering one each light a layer of their own" {
    scene = lit_yard();
    scene.add_item({"classname": "light", "origin": "-64 64 48", "light": "200", "targetname": "lamp"});
    scene.add_item({"classname": "light", "origin": "-64 -64 48", "light": "200", "style": "1"});
    made = compile_scene(scene, SwatchMaterials());
    switched = [entity for entity in made.bsp.entities if entity.fields.get("targetname", "") == "lamp"];
    assert len(switched) == 1 and switched[0].fields.get("style", "") == "32";
    samples = bake_light(scene, made);
    face = made.bsp.faces[floor_top(made)];
    assert face.styles[0] == 0 and 32 in face.styles and 1 in face.styles and len(face.styles) == 3;
    # A layer of samples for each style the face has.
    total = 0;
    for each in made.bsp.faces[made.bsp.models[0].first_face:made.bsp.models[0].first_face + made.bsp.models[0].face_count] {
        total += each.light_width * each.light_height * len(each.styles) * 3;
    }
    assert len(made.bsp.lighting) == total and total > samples * 3;
    # The switched lamp is not in the steady layer: lit without it, that
    # layer is the same.
    without = lit_yard();
    without.add_item({"classname": "light", "origin": "-64 -64 48", "light": "200", "style": "1"});
    other = compile_scene(without, SwatchMaterials());
    bake_light(without, other);
    steady = other.bsp.faces[floor_top(other)];
    size = face.light_width * face.light_height * 3;
    assert made.bsp.lighting[face.light_offset:face.light_offset + size] == other.bsp.lighting[steady.light_offset:steady.light_offset + size];
}

test "a grid of light for models, dark only inside the brushes" {
    scene = lit_yard();
    made = compile_scene(scene, SwatchMaterials());
    bake_light(scene, made);
    world = made.bsp.models[0];
    grid = load_light_grid(made.bsp.light_grid, world.mins, world.maxs);
    assert grid is not None;
    lit_grid: LightGrid = grid;
    # Beside the lamp it is lit.
    assert len(made.bsp.light_grid) == lit_grid.bounds[0] * lit_grid.bounds[1] * lit_grid.bounds[2] * 8;
    beside = lit_grid.sample(Vec3(x=0.0, y=0.0, z=96.0));
    assert beside.enabled and beside.directed.x > 0.1 and beside.direction.length() > 0.5;
    # Kept with the build and given back.
    kept = keep_bake(made, "mark", len(made.bsp.planes), 0, 1, VisReport());
    again = compile_scene(scene, SwatchMaterials());
    assert give_bake(again, kept) and again.bsp.light_grid == made.bsp.light_grid;
    assert [face.styles for face in again.bsp.faces] == [face.styles for face in made.bsp.faces];
    assert again.light_notes == made.light_notes;
}

import from engine.world.lighting { LightGrid }
import from editor.compile.bake { VisReport }
