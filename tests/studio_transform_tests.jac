import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item }
import from editor.geometry.brush { box_sides, brush_volume }
import from editor.geometry.mapping { mapping_same }
import from editor.geometry.patch { patch_points, points_carried, points_reversed }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""A floor, a cube from the origin to (64, 64, 64), and a player start."""
def room -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=64.0, y=64.0, z=64.0), "wall"));
    scene.add_item({"classname": "info_player_start", "origin": "-64 -64 24", "angle": "90"});
    return scene;
}

test "a turn about a given pivot swings the selection round it" {
    scene = room();
    wall = scene.solids()[1];
    start = scene.items()[1];
    scene.select_solid(wall);
    scene.select(start, True);
    # A quarter turn about the vertical through the origin: +x goes to +y.
    assert scene.turn_selection(90.0, 8.0, 2, Vec3());
    box = wall.bounds();
    assert box is not None and about(box[0].x, -64.0) and about(box[1].x, 0.0);
    assert about(box[0].y, 0.0) and about(box[1].y, 64.0) and about(box[1].z, 64.0);
    assert start.fields["origin"] == "64 -64 24" and start.fields["angle"] == "180";
    assert scene.undo() == "Turn";
    # About the x axis through (0, 0, 32) the cube tips over onto its side.
    scene.select_solid(wall);
    assert scene.turn_selection(90.0, 8.0, 0, Vec3(z=32.0));
    box = wall.bounds();
    assert box is not None and about(box[0].y, -32.0) and about(box[1].y, 32.0);
    assert about(box[0].z, 32.0) and about(box[1].z, 96.0) and about(box[0].x, 0.0);
    # Thirty degrees leaves a brush of the same size, off the axes.
    scene.undo();
    assert scene.turn_selection(30.0, 8.0, 2, Vec3(x=32.0, y=32.0));
    assert about(brush_volume(wall.sides), 64.0 * 64.0 * 64.0, 1.0);
    box = wall.bounds();
    assert box is not None and box[0].x < -10.0 and box[1].x > 74.0;
}

test "a stretch about a given pivot leaves the pivot where it is" {
    scene = room();
    wall = scene.solids()[1];
    scene.select_solid(wall);
    assert scene.stretch_selection(Vec3(x=2.0, y=1.0, z=0.5), 8.0, "Resize", Vec3());
    box = wall.bounds();
    assert box is not None and box[0].x == 0.0 and box[1].x == 128.0 and box[1].y == 64.0 and box[1].z == 32.0;
    scene.undo();
    # About its far corner it grows the other way.
    assert scene.stretch_selection(Vec3(x=2.0, y=1.0, z=1.0), 8.0, "Resize", Vec3(x=64.0, y=64.0, z=64.0));
    box = wall.bounds();
    assert box is not None and box[0].x == -64.0 and box[1].x == 64.0;
}

test "with the lock off a material stays where it lies while its face moves" {
    scene = room();
    wall = scene.solids()[1];
    before = [side.mapping for side in wall.sides];
    scene.select_solid(wall);
    assert scene.shift_selection(Vec3(x=16.0, y=8.0), False);
    box = wall.bounds();
    assert box is not None and box[0].x == 16.0 and box[0].y == 8.0;
    for index in range(len(before)) {
        assert mapping_same(before[index], wall.sides[index].mapping);
    }
    scene.undo();
    # Locked, the mappings take up the move.
    assert scene.shift_selection(Vec3(x=16.0, y=8.0));
    changed = 0;
    for index in range(len(before)) {
        if not mapping_same(before[index], wall.sides[index].mapping) {
            changed += 1;
        }
    }
    assert changed > 0;
    scene.undo();
    assert scene.turn_selection(90.0, 8.0, 2, Vec3(), False);
    material = [side.material for side in wall.sides];
    assert len(material) == 6 and material[0] == "wall";
    scene.undo();
    assert scene.stretch_selection(Vec3(x=2.0, y=2.0, z=2.0), 8.0, "Resize", Vec3(), False);
    for index in range(len(before)) {
        # Stretched with the lock off, a texel is as big as it was.
        assert about(wall.sides[index].mapping.s_scale, before[index].s_scale);
    }
}

test "inflating pushes every side out, and leaves alone a brush it would empty" {
    scene = room();
    wall = scene.solids()[1];
    scene.select_solid(wall);
    assert scene.inflate_selection(8.0) == 1;
    box = wall.bounds();
    assert box is not None and box[0].x == -8.0 and box[1].x == 72.0 and box[0].z == -8.0 and box[1].z == 72.0;
    assert scene.inflate_selection(-24.0) == 1;
    box = wall.bounds();
    assert box is not None and box[0].x == 16.0 and box[1].x == 48.0;
    # Sixteen in from every side would leave nothing of a brush thirty-two across.
    assert scene.inflate_selection(-16.0) == 0;
    assert scene.inflate_selection(0.0) == 0;
    assert scene.undo() == "Deflate" and scene.undo() == "Inflate";
    box = wall.bounds();
    assert box is not None and box[0].x == 0.0 and box[1].x == 64.0;
}

test "a group keeps a pivot of its own, which moves and turns with it" {
    scene = room();
    wall = scene.solids()[1];
    scene.select_solid(wall);
    # A lone brush has nowhere to keep one.
    assert not scene.set_pivot(Vec3()) and scene.selection_pivot() is None;
    group = scene.group_selection("pillar");
    assert group is not None;
    scene.select(group);
    assert scene.set_pivot(Vec3(x=64.0, y=64.0));
    kept = scene.selection_pivot();
    assert kept is not None and kept.x == 64.0 and kept.y == 64.0 and kept.z == 0.0;
    assert scene.shift_selection(Vec3(x=16.0));
    kept = scene.selection_pivot();
    assert kept is not None and kept.x == 80.0 and kept.y == 64.0;
    # Turned about the origin, the pivot swings round with the brushes.
    assert scene.turn_selection(90.0, 8.0, 2, Vec3());
    kept = scene.selection_pivot();
    assert kept is not None and about(kept.x, -64.0) and about(kept.y, 80.0);
    assert scene.stretch_selection(Vec3(x=2.0, y=1.0, z=1.0), 8.0, "Resize", Vec3());
    kept = scene.selection_pivot();
    assert kept is not None and about(kept.x, -128.0) and about(kept.y, 80.0);
    scene.undo();
    scene.undo();
    scene.undo();
    kept = scene.selection_pivot();
    assert kept is not None and kept.x == 64.0;
    assert scene.set_pivot(None) and scene.selection_pivot() is None;
    assert scene.undo() == "Pivot" and scene.selection_pivot() is not None;
}

test "a patch's control points turn and stretch with its brushes" {
    scene = room();
    made = patch_points("sheet", Vec3(z=64.0), Vec3(x=128.0, y=64.0, z=64.0));
    assert made[0] == 3 and made[1] == 3;
    patch = scene.make_patch(made[2], made[0], made[1], "wall");
    assert patch is not None;
    scene.select(patch);
    before = scene.patch_control(patch);
    assert before is not None and len(before) == 9;
    assert scene.turn_selection(90.0, 8.0, 2, Vec3());
    after = scene.patch_control(patch);
    assert after is not None;
    for index in range(9) {
        # A quarter turn about the vertical through the origin: (x, y) to (-y, x).
        assert about(after[index].x, -before[index].y) and about(after[index].y, before[index].x);
        assert about(after[index].z, before[index].z);
    }
    assert scene.stretch_selection(Vec3(x=1.0, y=1.0, z=2.0), 8.0, "Resize", Vec3());
    taller = scene.patch_control(patch);
    assert taller is not None and about(taller[0].z, before[0].z * 2.0);
    carried = points_carried("1 2 3", Vec3(x=1.0), Vec3(x=2.0), Vec3(y=1.0), Vec3(z=1.0));
    assert carried == "1 2 3";
}

"""The lowest any of an entity's brushes reaches."""
def floor_of(scene: Scene, item: Item) -> float {
    low = 1000000.0;
    for solid in scene.solids_of(item) {
        box = solid.bounds();
        if box is not None {
            low = min(low, box[0].z);
        }
    }
    return low;
}

test "a mirrored patch built again thickens toward the side it did" {
    assert points_reversed("0 0 0 1 0 0 2 0 0 0 1 0 1 1 0 2 1 0", 3) == "2 0 0 1 0 0 0 0 0 2 1 0 1 1 0 0 1 0";
    assert points_reversed("0 0 0 1 0 0", 4) == "0 0 0 1 0 0";
    scene = room();
    made = patch_points("sheet", Vec3(x=32.0, z=64.0), Vec3(x=160.0, y=64.0, z=64.0));
    patch = scene.make_patch(made[2], made[0], made[1], "wall");
    assert patch is not None;
    scene.select(patch);
    before = floor_of(scene, patch);
    assert scene.stretch_selection(Vec3(x=-1.0, y=1.0, z=1.0), 8.0, "Mirror", Vec3());
    assert floor_of(scene, patch) == before;
    mirrored = scene.patch_control(patch);
    # Each row runs the other way now, so the sheet faces the way it did.
    assert mirrored is not None and about(mirrored[0].x, -160.0) and about(mirrored[2].x, -32.0);
    # Bent a little, it is built again from its points: as thick, the same way.
    nudged = [Vec3(x=point.x, y=point.y, z=point.z) for point in mirrored];
    nudged[4] = Vec3(x=nudged[4].x, y=nudged[4].y, z=nudged[4].z - 1.0);
    assert scene.set_patch(patch, nudged);
    assert about(floor_of(scene, patch), before, 1.5);
}
