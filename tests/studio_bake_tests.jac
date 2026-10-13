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

import from editor.compile.bake { bake_planes, BAKE_BY_PLANES, portal_file_text, portal_file_windings }
import from engine.world.world { World }
import from engine.world.map_areas { AreaMap, AreaPortal }
import from engine.world.area_portals { chart_areas, load_area_portals, HasAreaPortal, AreaPortalTick }
import from engine.world.signals { Fire }

"""The cluster a point is in, in a baked level (-1 in what is solid)."""
def cluster_at(made: LiveLevel, point: Vec3) -> int {
    return made.bsp.leaves[leaf_at(made.bsp, made.bsp.models[0].head, point)].cluster;
}

import from editor.compile.live { LiveLevel }

"""A corridor that turns back on itself: an arm running west at the south,
a column up the east side, and an arm running back west at the north, with
a block between the arms and walls, floor and roof all round. A hint across
both arms where they meet the column cuts each from its corner (without it
an arm and its corner are one leaf, and see the other's up the column)."""
def bend(standing: bool = True) -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-528.0, y=-80.0, z=-16.0), Vec3(x=144.0, y=528.0, z=0.0), "floor"));
    scene.add_solid(world, box_sides(Vec3(x=-528.0, y=-80.0, z=128.0), Vec3(x=144.0, y=528.0, z=144.0), "roof"));
    scene.add_solid(world, box_sides(Vec3(x=-512.0, y=64.0, z=0.0), Vec3(x=0.0, y=384.0, z=128.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-528.0, y=-80.0, z=0.0), Vec3(x=-512.0, y=528.0, z=128.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=128.0, y=-80.0, z=0.0), Vec3(x=144.0, y=528.0, z=128.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-512.0, y=-80.0, z=0.0), Vec3(x=128.0, y=-64.0, z=128.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-512.0, y=512.0, z=0.0), Vec3(x=128.0, y=528.0, z=128.0), "wall"));
    scene.add_solid(world, box_sides(Vec3(x=-16.0, y=-64.0, z=0.0), Vec3(x=0.0, y=512.0, z=128.0), "common/hint"));
    if standing {
        scene.add_item({"classname": "info_player_start", "origin": "-448 0 24"});
        scene.add_item({"classname": "light", "origin": "-448 448 64"});
    }
    return scene;
}

test "a bake by planes cuts space at the brushes' own faces, fills the outside and buries hidden faces" {
    scene = hall(True);
    made = compile_scene(scene, SwatchMaterials());
    faces = len(made.bsp.leaves[0].faces);
    outcome = bake_planes(scene, made);
    bsp = made.bsp;
    assert not outcome.leaked and not outcome.capped and outcome.leaves == len(bsp.leaves);
    assert outcome.cells >= 3 and outcome.leaves > outcome.cells and outcome.portals >= outcome.cells - 1;
    assert bsp.clusters == outcome.cells and len(bsp.visibility) == 8 + outcome.cells * bsp.cluster_bytes;
    for leaf in bsp.leaves {
        # Solid (a brush, or the outside filled) or a cluster, never both.
        assert (leaf.contents == 1) == (leaf.cluster < 0);
        assert leaf.contents == 0 or len(leaf.faces) == 0;
    }
    # In the room, in a wall, and outside the level.
    assert cluster_at(made, Vec3(x=-200.0, y=0.0, z=32.0)) >= 0 and cluster_at(made, Vec3(x=200.0, y=0.0, z=32.0)) >= 0;
    assert cluster_at(made, Vec3(x=0.0, y=-100.0, z=100.0)) < 0;
    assert cluster_at(made, Vec3(x=-300.0, y=0.0, z=100.0)) < 0 and cluster_at(made, Vec3(x=0.0, y=0.0, z=300.0)) < 0;
    # The faces looking out of the level, and those against another brush,
    # are buried; those looking into the hall are kept.
    kept: set[int] = set();
    for leaf in bsp.leaves {
        for index in leaf.faces {
            kept.add(index);
        }
    }
    assert outcome.buried > 0 and len(kept) + outcome.buried == faces and len(kept) >= 12;
    assert len(made.portals) == outcome.portals and len(made.portal_ends) == outcome.portals * 2;
    assert len(made.shapes) == outcome.leaves;
    # Written as a portal file and read back, every portal between clusters.
    text = portal_file_text(made);
    assert text.startswith("PRT1\n" + str(outcome.cells) + "\n");
    read = portal_file_windings(text);
    assert read is not None and len(read) == int(text.split("\n")[2]) and len(read) >= 1;
    assert len(read[0]) >= 3;
    # Quake III's form, with a count of faces and a flag after the clusters.
    q3 = portal_file_windings("PRT1\n2\n1\n0\n4 0 1 0 (0 0 0 ) (0 64 0 ) (0 64 64 ) (0 0 64 ) \n");
    assert q3 is not None and len(q3) == 1 and q3[0][2].y == 64.0 and q3[0][2].z == 64.0;
    assert portal_file_windings("not a portal file") is None;
    # Two rooms joined only by a doorway see each other through it.
    assert cell_sees(bsp, cluster_at(made, Vec3(x=-200.0, y=0.0, z=32.0)), cluster_at(made, Vec3(x=200.0, y=0.0, z=32.0)));
}

test "a corridor that turns back on itself hides each arm from the other" {
    scene = bend();
    made = compile_scene(scene, SwatchMaterials());
    outcome = bake_planes(scene, made);
    south = cluster_at(made, Vec3(x=-448.0, y=0.0, z=32.0));
    corner = cluster_at(made, Vec3(x=64.0, y=0.0, z=32.0));
    north = cluster_at(made, Vec3(x=-448.0, y=448.0, z=32.0));
    top = cluster_at(made, Vec3(x=64.0, y=448.0, z=32.0));
    assert not outcome.leaked and outcome.hidden > 0 and not outcome.capped;
    # The column up the east side is one leaf: nothing cuts it.
    assert south >= 0 and north >= 0 and len(set([south, corner, north])) == 3 and corner == top;
    assert cell_sees(made.bsp, south, corner) and cell_sees(made.bsp, north, top) and cell_sees(made.bsp, corner, top);
    assert not cell_sees(made.bsp, south, north) and not cell_sees(made.bsp, north, south);
    # With nothing standing in it, the bend is outside and filled.
    empty = bend(False);
    bare = compile_scene(empty, SwatchMaterials());
    open_outcome = bake_planes(empty, bare);
    assert open_outcome.cells == open_outcome.leaves - len([leaf for leaf in bare.bsp.leaves if leaf.contents == 1]);
}

test "an area portal in a doorway divides the level into two areas it joins" {
    scene = hall(True);
    scene.add_item({"classname": "light", "origin": "192 0 64"});
    portal = scene.add_item({"classname": "func_areaportal", "targetname": "gate"});
    scene.add_solid(portal, box_sides(Vec3(x=-8.0, y=-32.0, z=0.0), Vec3(x=8.0, y=32.0, z=192.0), "common/areaportal"));
    made = compile_scene(scene, SwatchMaterials());
    outcome = bake_planes(scene, made);
    bsp = made.bsp;
    assert outcome.areas == 2 and len(bsp.areas) == 3 and len(made.warnings) == 0;
    west = bsp.leaves[leaf_at(bsp, bsp.models[0].head, Vec3(x=-200.0, y=0.0, z=32.0))].area;
    east = bsp.leaves[leaf_at(bsp, bsp.models[0].head, Vec3(x=200.0, y=0.0, z=32.0))].area;
    assert west > 0 and east > 0 and west != east;
    assert len(bsp.areas[west]) == 1 and bsp.areas[west][0].portal == 1 and bsp.areas[west][0].area == east;
    assert bsp.areas[east][0].area == west;
    styled = [entity for entity in bsp.entities if entity.fields.get("classname", "") == "func_areaportal"];
    assert len(styled) == 1 and styled[0].fields.get("style", "") == "1";
    # The engine charts the areas and the portal between them, shut until used.
    world = World();
    charted = chart_areas(world, bsp, []);
    assert charted is not None;
    chart: AreaMap = charted;
    assert len(chart.areas) == 3;
    load_area_portals(world, bsp, chart);
    gates = [world->:HasAreaPortal:->][?:AreaPortal];
    assert len(gates) == 1 and gates[0].style == 1 and not chart.connected(west, east);
    gates[0].activation spawn Fire(emit=False);
    world spawn AreaPortalTick();
    assert chart.connected(west, east);
    # Its brush is not drawn and stops nothing.
    model = int(styled[0].fields.get("model", "*0")[1:]);
    assert model > 0 and bsp.models[model].face_count == 0 and len(bsp.models[model].brushes) == 1;
    assert bsp.brushes[bsp.models[model].brushes[0]].contents == 0;
    # Kept and given to the level compiled again, it is the same.
    first = compile_scene(scene, SwatchMaterials());
    base = len(first.bsp.planes);
    done = bake_planes(scene, first);
    kept = keep_bake(first, "mark", base, 0, 0, done);
    again = compile_scene(scene, SwatchMaterials());
    assert give_bake(again, kept);
    assert len(again.bsp.leaves) == len(first.bsp.leaves) and again.bsp.visibility == first.bsp.visibility;
    assert [leaf.area for leaf in again.bsp.leaves] == [leaf.area for leaf in first.bsp.leaves];
    assert [leaf.contents for leaf in again.bsp.leaves] == [leaf.contents for leaf in first.bsp.leaves];
    assert len(again.bsp.areas) == 3 and len(again.portals) == done.portals;
    assert [entity for entity in again.bsp.entities if entity.fields.get("style", "") == "1"];
}

test "a bake by planes done a slice at a time comes out as one done at once" {
    scene = bend();
    whole = compile_scene(scene, SwatchMaterials());
    outcome = bake_planes(scene, whole);
    sliced = compile_scene(scene, SwatchMaterials());
    job = cell_job(scene, sliced, BAKE_BY_PLANES);
    assert not job.finished() and job.share() < 0.2;
    steps = 0;
    last = 0.0;
    while not job.step(3) {
        steps += 1;
        assert job.share() >= last;
        last = job.share();
    }
    assert steps > 4 and job.share() == 1.0;
    assert sliced.bsp.visibility == whole.bsp.visibility and job.outcome.leaves == outcome.leaves;
    assert job.outcome.hidden == outcome.hidden and job.outcome.buried == outcome.buried;
}
