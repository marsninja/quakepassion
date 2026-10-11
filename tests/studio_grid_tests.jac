import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item }
import from editor.geometry.brush { box_sides }

"""A floor on the grid, two boxes off it (one of them owned by a door), a
sliver that snapping would flatten, and a start standing off it."""
def crooked -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=3.0, y=5.0, z=0.0), Vec3(x=61.0, y=66.0, z=30.5), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=80.0, y=80.0, z=0.0), Vec3(x=82.0, y=83.0, z=64.0), "wall"));
    door = scene.add_item({"classname": "func_door", "angle": "-1"});
    scene.add_solid(door, box_sides(Vec3(x=-100.5, y=0.0, z=0.0), Vec3(x=-84.25, y=64.0, z=96.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "-61 -67 25"});
    return scene;
}

test "a map off the grid is counted, forced on to it, and what would fall flat is left" {
    scene = crooked();
    # Three brushes and one entity are off a grid of eight; the floor is on it.
    assert scene.off_grid(8.0) == 4 and scene.off_grid(1.0) == 2;
    # Nothing is selected: the selection's snap moves nothing, the whole map's moves what it can.
    assert scene.snap_selection(8.0) == 0 and scene.off_grid(8.0) == 4;
    assert scene.snap_selection(8.0, True) == 3;
    solids = scene.solids();
    box = solids[1].bounds();
    assert box is not None and box[0].x == 0.0 and box[0].y == 8.0 and box[1].x == 64.0 and box[1].y == 64.0 and box[1].z == 32.0;
    door_box = solids[3].bounds();
    assert door_box is not None and door_box[0].x == -104.0 and door_box[1].x == -88.0;
    start = scene.items()[2].origin();
    assert start is not None and start.x == -64.0 and start.y == -64.0 and start.z == 24.0;
    # The sliver two units by three would have no size on a grid of eight: it is as it was, and counted.
    sliver = solids[2].bounds();
    assert sliver is not None and sliver[1].x == 82.0 and scene.off_grid(8.0) == 1;
    # One step, undone as one.
    assert scene.undo() == "Snap to grid" and scene.off_grid(8.0) == 4;
    # On a grid of one, everything can be mended.
    assert scene.snap_selection(1.0, True) == 2 and scene.off_grid(1.0) == 0;
}
