import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Item }
import from editor.geometry.terrain { heights_from }
import from editor.geometry.touchup {
    corner_near,
    cell_at,
    kin_corners,
    kin_cells,
    cell_level,
    cells_corners,
    corners_lifted,
    cells_outline
}

"""A terrain four cells by three: flat at 0 but for a terrace at 32 over its
two eastern columns of corners, and one corner of that up at 40."""
def terraced -> list[float] {
    heights: list[float] = [];
    for row in range(4) {
        for col in range(5) {
            heights.append(32.0 if col >= 3 else 0.0);
        }
    }
    heights[1 * 5 + 4] = 40.0;
    return heights;
}

test "a place on a terrain is the corner nearest it and the cell it is in" {
    origin = Vec3(x=-128.0, y=-96.0, z=0.0);
    assert corner_near(origin, 4, 3, 64.0, -128.0, -96.0) == [0, 0] and corner_near(origin, 4, 3, 64.0, -30.0, 40.0) == [2, 2];
    assert corner_near(origin, 4, 3, 64.0, 900.0, -900.0) == [4, 0];
    assert cell_at(origin, 4, 3, 64.0, -100.0, -90.0) == [0, 0] and cell_at(origin, 4, 3, 64.0, 100.0, 90.0) == [3, 2];
    assert cell_at(origin, 4, 3, 64.0, 128.0, 0.0) == [-1, -1] and cell_at(origin, 4, 3, 64.0, 0.0, -97.0) == [-1, -1];
}

test "corners go together when they are joined along the grid within a variance of height" {
    heights = terraced();
    # The low ground: three columns of four corners.
    low = kin_corners(heights, 4, 3, 0, 0);
    assert len(low) == 12 and low[0] == 0;
    # The terrace without its raised corner, and with it once the variance takes it in.
    assert len(kin_corners(heights, 4, 3, 3, 0)) == 7 and len(kin_corners(heights, 4, 3, 3, 0, 8.0)) == 8;
    assert kin_corners(heights, 4, 3, 4, 1) == [1 * 5 + 4];
    # With variance enough for the step, the whole terrain.
    assert len(kin_corners(heights, 4, 3, 0, 0, 40.0)) == 20;
    assert kin_corners(heights, 4, 3, 9, 0) == [] and kin_corners([0.0, 1.0], 4, 3, 0, 0) == [];
    lifted = corners_lifted(heights, low, 16.0);
    assert lifted[0] == 16.0 and lifted[3] == 32.0 and heights[0] == 0.0;
    # Nothing goes below the base.
    assert corners_lifted(heights, low, -50.0)[0] == 0.0;
}

test "cells go together by the mean height of their corners, and have corners and a border" {
    heights = terraced();
    assert cell_level(heights, 4, 0, 0) == 0.0 and cell_level(heights, 4, 2, 0) == 16.0 and cell_level(heights, 4, 3, 2) == 32.0;
    # The two western columns of cells lie flat; the third climbs the step.
    flat = kin_cells(heights, 4, 3, 0, 0);
    assert len(flat) == 6 and flat[0] == 0 and 2 not in flat;
    assert len(kin_cells(heights, 4, 3, 0, 0, 16.0)) == 9;
    assert kin_cells(heights, 4, 3, 4, 0) == [];
    # Their corners: three columns of four.
    assert len(cells_corners(4, 3, flat)) == 12 and cells_corners(4, 3, [99]) == [];
    one = cells_corners(4, 3, [0]);
    assert one == [0, 1, 5, 6];
    # The edge of two columns of three cells: 2 + 2 across the ends, 3 + 3 up the sides.
    origin = Vec3(x=-128.0, y=-96.0, z=0.0);
    border = cells_outline(heights, 4, 3, flat, origin, 64.0, 16.0);
    assert len(border) == 10;
    for line in border {
        # Along the terrain's own surface, just above it.
        assert line[0].z == 17.0 and line[1].z == 17.0;
    }
    # One cell on the terrace has four sides, the raised corner's among them.
    square = cells_outline(heights, 4, 3, [1 * 4 + 3], origin, 64.0, 16.0);
    assert len(square) == 4;
    tallest = 0.0;
    for line in square {
        tallest = max(tallest, max(line[0].z, line[1].z));
    }
    assert tallest == 16.0 + 40.0 + 1.0;
    assert cells_outline(heights, 4, 3, [], origin, 64.0) == [] and cells_outline([0.0], 4, 3, [0], origin, 64.0) == [];
}

"""A scene with the terraced terrain standing on the origin, and its item."""
def ground -> Scene {
    scene = Scene(game="passion", name="studio:test");
    scene.world();
    land = scene.make_terrain(Vec3(), 4, 3, 64.0, "grass", 16.0);
    assert land is not None and scene.set_heights(land, terraced(), "Shape");
    return scene;
}

"""The terrain of that scene, and how high and low its brushes reach."""
def land_of(scene: Scene) -> Item {
    return [item for item in scene.items() if scene.terrain_grid(item) is not None][0];
}

def reach(scene: Scene, item: Item) -> list[float] {
    low = 1000000.0;
    high = -1000000.0;
    for solid in scene.solids_of(item) {
        box = solid.bounds();
        if box is not None {
            low = min(low, box[0].z);
            high = max(high, box[1].z);
        }
    }
    return [low, high];
}

"""Whether a terrain's brushes reach from one height to another."""
def spans(scene: Scene, item: Item, low: float, high: float) -> bool {
    found = reach(scene, item);
    return abs(found[0] - low) < 0.01 and abs(found[1] - high) < 0.01;
}

test "a corner of a terrain is moved with the corners that go with it" {
    scene = ground();
    land = land_of(scene);
    # On the terrace, with no variance: its seven corners at one height, not the raised one.
    assert scene.touch_terrain(land, 200.0, 0.0, 8.0) == 7;
    now = heights_from(land.fields["_heights"], 4, 3);
    assert now is not None and now[3] == 40.0 and now[1 * 5 + 4] == 40.0 and now[0] == 0.0;
    # They are all at 40 now: touched again, the eighth goes with them.
    assert scene.touch_terrain(land, 200.0, 0.0, -8.0) == 8;
    assert scene.undo() == "Touch up" and scene.undo() == "Touch up";
    back = heights_from(land.fields["_heights"], 4, 3);
    assert back is not None and back[3] == 32.0 and back[1 * 5 + 4] == 40.0;
    # With variance for the step, a touch on the low ground takes the terrace too.
    assert scene.touch_terrain(land, 0.0, 0.0, 4.0, 40.0) == 20;
    assert scene.touch_terrain(land, 0.0, 0.0, 0.0) == 0;
}

test "cells of a terrain are lifted, and its top and its bottom moved apart" {
    scene = ground();
    land = land_of(scene);
    assert spans(scene, land, 0.0, 16.0 + 40.0);
    assert scene.lift_cells(land, [0], 8.0) and not scene.lift_cells(land, [], 8.0);
    now = heights_from(land.fields["_heights"], 4, 3);
    assert now is not None and now[0] == 8.0 and now[1] == 8.0 and now[5] == 8.0 and now[6] == 8.0 and now[2] == 0.0;
    assert scene.undo() == "Lift cells";
    # The top: every height up by sixteen, the underside where it was.
    assert scene.move_terrain(land, "top", 16.0) and spans(scene, land, 0.0, 16.0 + 56.0);
    assert scene.undo() == "Move top";
    # The bottom: sixteen lower, the base that much thicker, the top where it was.
    assert scene.move_terrain(land, "bottom", -16.0);
    assert spans(scene, land, -16.0, 56.0) and land.fields["_terrain"] == "4 3 64 32";
    kept = heights_from(land.fields["_heights"], 4, 3);
    assert kept is not None and kept[3] == 32.0;
    # And sculpting still works on it where it now stands.
    assert scene.touch_terrain(land, 0.0, 0.0, 8.0) == 12 and abs(reach(scene, land)[0] + 16.0) < 0.01;
    scene.undo();
    assert scene.undo() == "Move bottom" and spans(scene, land, 0.0, 56.0) and land.fields["_terrain"] == "4 3 64 16";
    # A bottom moved up through its own base, or a part that is neither, is refused.
    assert not scene.move_terrain(land, "bottom", 16.0) and not scene.move_terrain(land, "side", 8.0);
}
