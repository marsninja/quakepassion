import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene }
import from editor.geometry.brush { box_sides }
import from editor.compile.live { compile_scene, SwatchMaterials }
import from editor.compile.bake { bake_cells, leaf_at, cell_sees, scene_occluder }
import from editor.compile.light { bake_light }
import from editor.compile.kept { keep_bake, give_bake }

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

test "a bake kept from one build is given whole to a level compiled of the same again" {
    scene = hall(False);
    scene.add_item({"classname": "light", "origin": "-128 0 128", "light": "300"});
    scene.add_item({"classname": "light", "origin": "128 0 128", "light": "300"});
    door = scene.add_item({"classname": "func_door", "angle": "-1"});
    scene.add_solid(door, box_sides(Vec3(x=-200.0, y=-16.0, z=0.0), Vec3(x=-184.0, y=16.0, z=96.0), "wall"));
    first = compile_scene(scene, SwatchMaterials());
    plane_base = len(first.bsp.planes);
    lit = bake_light(scene, first, 32.0);
    cut = bake_cells(scene, first, 128.0);
    assert lit > 0 and cut.cells >= 8 and cut.hidden > 0;
    kept = keep_bake(first, "mark", plane_base, len(first.warnings), lit, cut);
    assert kept.face_count == len(first.bsp.faces) and kept.clusters == cut.cells and kept.lit_samples == lit;
    # A game played in the first writes on it; what was kept is its own.
    first.bsp.leaves[0].faces.append(0);
    first.bsp.faces[0].light_uv[0] = -5.0;
    again = compile_scene(scene, SwatchMaterials());
    assert len(again.bsp.leaves) == 1 and again.bsp.clusters == 1 and len(again.bsp.lighting) == 0;
    assert give_bake(again, kept);
    bsp = again.bsp;
    assert bsp.clusters == cut.cells and len(bsp.leaves) == cut.cells and bsp.models[0].head == first.bsp.models[0].head;
    assert bsp.visibility == first.bsp.visibility and bsp.lighting == first.bsp.lighting and bsp.light_channels == 3;
    assert len(bsp.planes) == len(first.bsp.planes) and len(bsp.branches) == len(first.bsp.branches);
    west = leaf_at(bsp, bsp.models[0].head, Vec3(x=-200.0, y=0.0, z=32.0));
    east = leaf_at(bsp, bsp.models[0].head, Vec3(x=200.0, y=0.0, z=32.0));
    assert west == leaf_at(first.bsp, first.bsp.models[0].head, Vec3(x=-200.0, y=0.0, z=32.0));
    assert not cell_sees(bsp, west, east) and cell_sees(bsp, west, west);
    total = 0;
    for leaf in bsp.leaves {
        total += len(leaf.faces);
    }
    assert total == len(first.bsp.leaves[0].faces) - 1 + sum([len(leaf.faces) for leaf in first.bsp.leaves[1:]]);
    for (index, face) in enumerate(bsp.faces) {
        was = first.bsp.faces[index];
        assert face.light_width == was.light_width and face.light_offset == was.light_offset;
        assert face.colors == was.colors and len(face.light_uv) == len(was.light_uv);
    }
    assert bsp.faces[0].light_uv[0] != -5.0;
    # A level with another count of faces is left as it was compiled (the
    # mark is what says two are the same; this only stops a misfit).
    bigger = hall(True);
    bigger.add_solid(bigger.world(), box_sides(Vec3(x=64.0, y=-16.0, z=0.0), Vec3(x=96.0, y=16.0, z=32.0), "wall"));
    other = compile_scene(bigger, SwatchMaterials());
    assert not give_bake(other, kept) and other.bsp.clusters == 1 and len(other.bsp.leaves) == 1;
}

import from editor.compile.bake { cell_job }

test "cells baked a few lines of sight at a time come out as cells baked at once" {
    for doorway in [True, False] {
        scene = hall(doorway);
        whole = compile_scene(scene, SwatchMaterials());
        outcome = bake_cells(scene, whole, 128.0);
        sliced = compile_scene(scene, SwatchMaterials());
        job = cell_job(scene, sliced, 128.0);
        assert not job.finished() and job.share() < 0.1;
        steps = 0;
        last = 0.0;
        while not job.step(40) {
            steps += 1;
            assert job.share() >= last;
            last = job.share();
        }
        assert steps > 2 and job.finished() and job.share() == 1.0;
        assert sliced.bsp.visibility == whole.bsp.visibility and job.outcome.hidden == outcome.hidden;
        assert job.outcome.cells == outcome.cells;
    }
}
