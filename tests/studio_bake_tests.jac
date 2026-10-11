import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene }
import from editor.geometry.brush { box_sides }
import from editor.compile.live { compile_scene, SwatchMaterials }
import from editor.compile.bake { bake_cells, leaf_at, cell_sees, scene_occluder }

"""A hall 512 long and 256 deep with a floor, a roof and walls all round,
and across its middle a wall with (or without) a doorway."""
def hall(doorway: bool) -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-256.0, y=-128.0, z=-16.0), Vec3(x=256.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=-256.0, y=-128.0, z=192.0), Vec3(x=256.0, y=128.0, z=208.0), "roof"));
    scene.add_solid(world, box_sides(Vec3(x=-272.0, y=-128.0, z=0.0), Vec3(x=-256.0, y=128.0, z=192.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=256.0, y=-128.0, z=0.0), Vec3(x=272.0, y=128.0, z=192.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-272.0, y=-144.0, z=0.0), Vec3(x=272.0, y=-128.0, z=192.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-272.0, y=128.0, z=0.0), Vec3(x=272.0, y=144.0, z=192.0), "wall"));
    if doorway {
        # The wall across the middle, in two pieces with a gap between them.
        scene.add_solid(world, box_sides(Vec3(x=-8.0, y=-128.0, z=0.0), Vec3(x=8.0, y=-32.0, z=192.0), "wall"));
        scene.add_solid(world, box_sides(Vec3(x=-8.0, y=32.0, z=0.0), Vec3(x=8.0, y=128.0, z=192.0), "wall"));
    } else {
        scene.add_solid(world, box_sides(Vec3(x=-8.0, y=-128.0, z=0.0), Vec3(x=8.0, y=128.0, z=192.0), "wall"));
    }
    scene.add_item({"classname": "info_player_start", "origin": "-192 0 24"});
    return scene;
}

test "a level is cut into cells, each a leaf with the faces that lie in it" {
    scene = hall(True);
    made = compile_scene(scene, SwatchMaterials());
    faces = len(made.bsp.leaves[0].faces);
    outcome = bake_cells(scene, made, 128.0);
    bsp = made.bsp;
    assert outcome.cells == len(bsp.leaves) and outcome.cells >= 8 and bsp.clusters == outcome.cells;
    assert bsp.models[0].head >= 0 and bsp.models[0].vis_leaf_count == outcome.cells - 1;
    # Every face is in one cell and no other.
    total = 0;
    for leaf in bsp.leaves {
        total += len(leaf.faces);
        assert leaf.cluster >= 0 and leaf.maxs.x - leaf.mins.x <= 128.5 and leaf.maxs.y - leaf.mins.y <= 128.5;
    }
    assert total == faces;
    # A point is in the cell whose rectangle holds it.
    for point in [Vec3(x=-200.0, y=-100.0, z=32.0), Vec3(x=200.0, y=100.0, z=32.0), Vec3(x=10.0, y=0.0, z=32.0)] {
        leaf = bsp.leaves[leaf_at(bsp, bsp.models[0].head, point)];
        assert leaf.mins.x <= point.x and point.x <= leaf.maxs.x and leaf.mins.y <= point.y and point.y <= leaf.maxs.y;
    }
    assert len(bsp.visibility) == 8 + outcome.cells * bsp.cluster_bytes;
}

test "a wall hides what is beyond it, and a doorway lets it be seen" {
    shut = hall(False);
    sealed = compile_scene(shut, SwatchMaterials());
    outcome = bake_cells(shut, sealed, 128.0);
    west = leaf_at(sealed.bsp, sealed.bsp.models[0].head, Vec3(x=-200.0, y=0.0, z=32.0));
    east = leaf_at(sealed.bsp, sealed.bsp.models[0].head, Vec3(x=200.0, y=0.0, z=32.0));
    assert west != east and outcome.hidden > 0 and not outcome.capped;
    assert not cell_sees(sealed.bsp, west, east) and not cell_sees(sealed.bsp, east, west);
    # A cell sees itself and the one beside it.
    beside = leaf_at(sealed.bsp, sealed.bsp.models[0].head, Vec3(x=-100.0, y=0.0, z=32.0));
    assert cell_sees(sealed.bsp, west, west) and cell_sees(sealed.bsp, west, beside);
    opened_scene = hall(True);
    opened = compile_scene(opened_scene, SwatchMaterials());
    through = bake_cells(opened_scene, opened, 128.0);
    west = leaf_at(opened.bsp, opened.bsp.models[0].head, Vec3(x=-200.0, y=0.0, z=32.0));
    east = leaf_at(opened.bsp, opened.bsp.models[0].head, Vec3(x=200.0, y=0.0, z=32.0));
    assert cell_sees(opened.bsp, west, east) and through.hidden < outcome.hidden;
}

test "a level that fits one cell stays one leaf, and a budget spent leaves the rest in sight" {
    scene = hall(False);
    whole = compile_scene(scene, SwatchMaterials());
    faces = len(whole.bsp.leaves[0].faces);
    outcome = bake_cells(scene, whole, 4096.0);
    assert outcome.cells == 1 and len(whole.bsp.leaves) == 1 and len(whole.bsp.leaves[0].faces) == faces;
    assert whole.bsp.models[0].head < 0;
    hurried = compile_scene(scene, SwatchMaterials());
    spent = bake_cells(scene, hurried, 128.0, 10);
    assert spent.capped and spent.hidden == 0;
    assert len(scene_occluder(scene).brushes) == 7;
}
