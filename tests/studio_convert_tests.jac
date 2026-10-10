import math;
import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, scene_map, scene_from_map }
import from editor.geometry.brush { Side, box_sides, wedge_sides, brush_volume, brush_windings, windings_bounds, brush_holds }
import from editor.geometry.mapping { side_like, mapping_slid, mapping_sized, mapping_spun }
import from editor.compile.live { compile_scene, SwatchMaterials }
import from editor.formats.map { MapItem, MapFile }
import from editor.formats.bspmap { bsp_items, face_mapping, level_material }
import from editor.compile.leak { find_leak, LeakReport }
import from editor.document.generate { duplicates, image_brushes, with_images }

def near(a: float, b: float) -> bool {
    return abs(a - b) < 0.01;
}

"""A closed room: six walls round a space 256 across and 128 high."""
def sealed_room -> list[list[Side]] {
    return [
        box_sides(Vec3(x=-144.0, y=-144.0, z=-16.0), Vec3(x=144.0, y=144.0, z=0.0), "floor"),
        box_sides(Vec3(x=-144.0, y=-144.0, z=128.0), Vec3(x=144.0, y=144.0, z=144.0), "roof"),
        box_sides(Vec3(x=-144.0, y=-144.0, z=0.0), Vec3(x=-128.0, y=144.0, z=128.0), "wall"),
        box_sides(Vec3(x=128.0, y=-144.0, z=0.0), Vec3(x=144.0, y=144.0, z=128.0), "wall"),
        box_sides(Vec3(x=-128.0, y=-144.0, z=0.0), Vec3(x=128.0, y=-128.0, z=128.0), "wall"),
        box_sides(Vec3(x=-128.0, y=128.0, z=0.0), Vec3(x=128.0, y=144.0, z=128.0), "wall")
    ];
}

test "a level's texture names become the names scenes use" {
    assert level_material("q2", "e1u1/metal3_2") == "q2:e1u1/metal3_2";
    assert level_material("q3", "textures/base_wall/concrete") == "q3:textures/base_wall/concrete";
    assert level_material("passion", "q3:textures/x/y") == "q3:textures/x/y" and level_material("passion", "brick") == "brick";
    assert level_material("q2", "") == "";
}

test "a built level's brushes come back with their materials and how they lie" {
    scene = Scene(game="passion", name="studio:back");
    world = scene.world();
    floor = box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor");
    # The floor's top slid, scaled and turned, to be recovered.
    floor[4] = side_like(floor[4], "tiles", mapping_spun(mapping_sized(mapping_slid(floor[4].mapping, 8.0, 4.0), 2.0, 0.5), 30.0));
    scene.add_solid(world, floor);
    scene.add_solid(world, wedge_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=64.0, y=64.0, z=32.0), "ramp"));
    door = scene.add_item({"classname": "func_door", "angle": "90"});
    scene.add_solid(door, box_sides(Vec3(x=-64.0, y=64.0, z=0.0), Vec3(x=-48.0, y=128.0, z=96.0), "door"));
    scene.add_item({"classname": "info_player_start", "origin": "0 -64 24"});
    made = compile_scene(scene, SwatchMaterials());
    items = bsp_items(made.bsp, [dict(entity.fields) for entity in made.bsp.entities]);
    assert len(items) == 3;
    assert items[0].fields["classname"] == "worldspawn" and len(items[0].brushes) == 2;
    assert items[1].fields["classname"] == "func_door" and "model" not in items[1].fields and len(items[1].brushes) == 1;
    assert items[2].fields["origin"] == "0 -64 24" and len(items[2].brushes) == 0;
    back_floor = items[0].brushes[0];
    assert near(brush_volume(back_floor), 256.0 * 256.0 * 16.0);
    assert near(brush_volume(items[0].brushes[1]), 64.0 * 64.0 * 32.0 * 0.5);
    top = [side for side in back_floor if side.plane.normal.z > 0.5][0];
    assert top.material == "studio:tiles";
    # The same texel under the same point, before and after.
    for point in [Vec3(x=16.0, y=32.0, z=0.0), Vec3(x=-100.0, y=7.0, z=0.0)] {
        before = floor[4].mapping.texel(point);
        after = top.mapping.texel(point);
        assert near(before[0], after[0]) and near(before[1], after[1]);
    }
    assert [side.material for side in items[1].brushes[0]] == ["studio:door"] * 6;
    # Told the scene draws that material at another size, the lie is solved for that size.
    wider = bsp_items(made.bsp, [dict(entity.fields) for entity in made.bsp.entities], "blockout", {"studio:tiles": [128, 64]});
    wide_top = [side for side in wider[0].brushes[0] if side.plane.normal.z > 0.5][0];
    assert near(wide_top.mapping.s_scale * 2.0, top.mapping.s_scale) and near(wide_top.mapping.t_scale, top.mapping.t_scale);
    # Through a document and built again, it is the same level.
    again = compile_scene(scene_from_map("passion", "studio:again", MapFile(items=items)), SwatchMaterials());
    assert len(again.bsp.faces) == len(made.bsp.faces) and len(again.bsp.models) == len(made.bsp.models);
}

test "a level that keeps no brushes has none to give" {
    scene = Scene(game="passion", name="studio:none");
    scene.world();
    made = compile_scene(scene, SwatchMaterials());
    made.bsp.brushes = [];
    assert len(bsp_items(made.bsp, [{"classname": "worldspawn"}])) == 0;
}

test "a sealed room holds the flood and a hole lets it out" {
    room = sealed_room();
    inside = [Vec3(x=0.0, y=0.0, z=64.0)];
    outcome = find_leak(room, inside, 32.0);
    assert outcome.sealed and not outcome.gave_up and len(outcome.path) == 0;
    assert outcome.cells > 100;
    # Without its roof the flood reaches the void, and the way out begins inside.
    open_room = room[:1] + room[2:];
    leak = find_leak(open_room, inside, 32.0);
    assert not leak.sealed and len(leak.path) >= 3;
    assert abs(leak.path[0].x) < 32.0 and abs(leak.path[0].y) < 32.0;
    last = leak.path[-1];
    assert last.z > 128.0 or abs(last.x) > 144.0 or abs(last.y) > 144.0;
    for i in range(1, len(leak.path)) {
        assert near(leak.path[i].sub(leak.path[i - 1]).length(), 32.0);
    }
    # A thin wall stops it too; a start in the void is a leak at once; too small a budget gives up.
    thin = room[:5] + [box_sides(Vec3(x=-128.0, y=128.0, z=0.0), Vec3(x=128.0, y=132.0, z=128.0), "wall")];
    assert find_leak(thin, inside, 32.0).sealed;
    assert not find_leak(room, [Vec3(x=0.0, y=0.0, z=400.0)], 32.0).sealed;
    assert find_leak(room, inside, 32.0, 10).gave_up;
    assert not find_leak([], inside).sealed and find_leak(room, []).sealed;
}

test "a duplicator's images stand an offset on, turn, and mirror" {
    post = [box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=16.0, y=16.0, z=64.0), "post")];
    assert not duplicates({"classname": "func_group"}) and len(image_brushes({"classname": "func_group"}, post)) == 0;
    row = {"classname": "func_group", "_copies": "3", "_offset": "64 0 0"};
    assert duplicates(row);
    images = image_brushes(row, post);
    assert len(images) == 3;
    for (index, image) in enumerate(images) {
        box = windings_bounds(brush_windings(image));
        assert box is not None and near(box[0].x, 64.0 * float(index + 1)) and near(box[1].z, 64.0);
        assert near(brush_volume(image), 16.0 * 16.0 * 64.0);
    }
    # Four round a pivot: three images, a quarter turn apart.
    ring = {"classname": "func_group", "_copies": "3", "_turn": "90", "_pivot": "64 64 0"};
    turned = image_brushes(ring, post);
    assert len(turned) == 3;
    opposite = windings_bounds(brush_windings(turned[1]));
    assert opposite is not None and near(opposite[0].x, 112.0) and near(opposite[1].y, 128.0);
    # A mirror of the group and of its copies.
    both = {"classname": "func_group", "_copies": "1", "_offset": "0 32 0", "_mirror": "x", "_pivot": "32 0 0"};
    mirrored = image_brushes(both, post);
    assert len(mirrored) == 3;
    across = windings_bounds(brush_windings(mirrored[1]));
    assert across is not None and near(across[0].x, 48.0) and near(across[1].x, 64.0) and near(across[0].y, 0.0);
    built = with_images([MapItem(fields={"classname": "worldspawn"}, brushes=post), MapItem(fields=row, brushes=post)]);
    assert len(built[0].brushes) == 1 and len(built[1].brushes) == 4;
}
