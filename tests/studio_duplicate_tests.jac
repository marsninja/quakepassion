import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, scene_map }
import from editor.document.duplicate { regenerate, with_regenerated }
import from editor.geometry.brush { box_sides }
import from editor.formats.map { MapItem }

"""A post in a group that copies it four times along x, held within a
group that copies the whole row twice along y."""
def rows -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-256.0, y=-256.0, z=-16.0), Vec3(x=256.0, y=256.0), "floor"));
    outer = scene.add_item({"classname": "func_group", "_group_id": "7", "_copies": "1", "_offset": "0 128 0"});
    inner = scene.add_item({"classname": "func_group", "_group_id": "8", "_group_in": "7", "_copies": "3", "_offset": "64 0 0"});
    scene.add_solid(inner, box_sides(Vec3(), Vec3(x=16.0, y=16.0, z=64.0), "post"));
    return scene;
}

def brush_count(items: list[MapItem]) -> int {
    count = 0;
    for read in items {
        count += len(read.brushes);
    }
    return count;
}

test "a duplicator within another is copied whole, images and all" {
    scene = rows();
    found = regenerate(scene, scene_map(scene));
    # The inner makes three images of its post; the outer one image of all four.
    assert len(found.sets) == 2 and found.made == 2 and found.kept == 0;
    built = with_regenerated(scene, scene_map(scene));
    # The floor, four posts in the first row and four in the second.
    assert brush_count(built) == 1 + 4 + 4;
}

test "images are made again only when what they copy has changed" {
    scene = rows();
    regenerate(scene, scene_map(scene));
    again = regenerate(scene, scene_map(scene));
    assert again.made == 0 and again.kept == 2;
    # The inner group's count changed: it and the group holding it are made again.
    inner = [item for item in scene.items() if item.fields.get("_group_id", "") == "8"][0];
    inner.fields["_copies"] = "1";
    changed = regenerate(scene, scene_map(scene));
    assert changed.made == 2 and changed.kept == 0;
    assert brush_count(with_regenerated(scene, scene_map(scene))) == 1 + 2 + 2;
    # A duplicator that holds nothing and has no brushes of its own makes nothing.
    scene.add_item({"classname": "func_group", "_copies": "4", "_offset": "8 0 0"});
    assert len(regenerate(scene, scene_map(scene)).sets) == 2;
}
