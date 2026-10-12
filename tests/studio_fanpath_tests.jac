import math;
import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { box_sides, brush_volume, brush_windings, windings_bounds }
import from editor.geometry.shapes { level_fan_brushes, shape_brushes, SHAPE_KINDS }
import from editor.document.generate { path_spots, image_sets, duplicates }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

test "a fan is wedges round the middle that together fill the round of the box" {
    fan = level_fan_brushes(Vec3(), Vec3(x=128.0, y=128.0, z=32.0), 8, "floor");
    assert len(fan) == 8 and "fan" in SHAPE_KINDS and len(shape_brushes("fan", Vec3(), Vec3(x=128.0, y=128.0, z=32.0))) == 8;
    total = 0.0;
    for wedge in fan {
        # A slice of cake: top, bottom, two straight sides and the rim.
        assert len(wedge) == 5 and wedge[0].material == "floor";
        total += brush_volume(wedge);
        box = windings_bounds(brush_windings(wedge));
        assert box is not None and about(box[0].z, 0.0) and about(box[1].z, 32.0);
    }
    # Eight sides round a circle of radius 64, thirty-two high.
    assert about(total, 4.0 * 64.0 * 64.0 * math.sin(math.pi / 4.0) * 32.0, 1.0);
    # In a box that is not square it is an oval; three wedges at the fewest.
    oval = level_fan_brushes(Vec3(), Vec3(x=128.0, y=64.0, z=16.0), 12, "floor");
    wide = 0.0;
    for wedge in oval {
        wide += brush_volume(wedge);
    }
    assert len(oval) == 12 and about(wide, 6.0 * 64.0 * 32.0 * math.sin(math.pi / 6.0) * 16.0, 1.0);
    assert len(level_fan_brushes(Vec3(), Vec3(x=64.0, y=64.0, z=16.0), 1, "floor")) == 3;
}

test "copies are laid along a path a tile apart, with an elbow at each bend" {
    # One leg of 256: four tiles of 64, each in the middle of its stretch, facing along it.
    straight = path_spots([Vec3(), Vec3(x=256.0)], 64.0);
    assert len(straight) == 4 and [spot[0] for spot in straight] == [32.0, 96.0, 160.0, 224.0];
    assert about(straight[0][3], 0.0) and about(straight[3][1], 0.0);
    # A leg that is not a whole number of tiles has the slack shared between its ends.
    loose = path_spots([Vec3(), Vec3(x=200.0)], 64.0);
    assert len(loose) == 3 and about(loose[0][0], 36.0) and about(loose[2][0], 164.0);
    # Round a bend: half a tile is kept clear each side of it, and an elbow stands on it facing
    # half way between the two legs.
    bent = path_spots([Vec3(), Vec3(x=256.0), Vec3(x=256.0, y=256.0)], 64.0);
    assert len(bent) == 7;
    assert [round(spot[0]) for spot in bent[:3]] == [48, 112, 176] and about(bent[3][0], 256.0) and about(bent[3][1], 0.0);
    assert about(bent[3][3], math.pi / 4.0) and [round(spot[1]) for spot in bent[4:]] == [80, 144, 208];
    assert about(bent[4][3], math.pi / 2.0) and about(bent[4][0], 256.0);
    # Up a slope the tiles climb with it, a tile's length apart along the slope itself; a leg shorter
    # than a tile has none; no tile, no path, nothing.
    climb = path_spots([Vec3(), Vec3(x=128.0, z=64.0)], 64.0);
    assert len(climb) == 2 and about(climb[1][2] - climb[0][2], 64.0 * 64.0 / math.sqrt(128.0 * 128.0 + 64.0 * 64.0), 0.01);
    assert about(climb[0][2] + climb[1][2], 64.0) and about(climb[0][0] + climb[1][0], 128.0);
    assert path_spots([Vec3(), Vec3(x=40.0)], 64.0) == [] and path_spots([Vec3(), Vec3(x=256.0)], 0.0) == [];
    assert path_spots([Vec3()], 64.0) == [];
}

test "a duplicator with a tile lays its images along the path, and without one stands them on its corners" {
    post = [box_sides(Vec3(x=-8.0, y=-8.0, z=0.0), Vec3(x=8.0, y=8.0, z=32.0), "wood")];
    others = [
        MapItem(fields={"classname": "path_corner", "targetname": "p1", "target": "p2", "origin": "0 0 0"}),
        MapItem(fields={"classname": "path_corner", "targetname": "p2", "target": "p3", "origin": "256 0 0"}),
        MapItem(fields={"classname": "path_corner", "targetname": "p3", "origin": "256 256 0"})
    ];
    assert duplicates({"_path": "p1"}) and len(image_sets({"_path": "p1"}, post, others)) == 3;
    tiled = image_sets({"_path": "p1", "_tile": "64"}, post, others);
    assert len(tiled) == 7;
    first = windings_bounds(brush_windings(tiled[0][0]));
    elbow = windings_bounds(brush_windings(tiled[3][0]));
    assert first is not None and about(first[0].x, 40.0) and about(first[1].x, 56.0) and about(first[0].y, -8.0);
    # The elbow is the post turned an eighth round on the bend: wider across than the post itself.
    assert elbow is not None and about((elbow[0].x + elbow[1].x) * 0.5, 256.0) and elbow[1].x - elbow[0].x > 20.0;
    # A tile that is no number is no tile.
    assert len(image_sets({"_path": "p1", "_tile": "wide"}, post, others)) == 3;
}
