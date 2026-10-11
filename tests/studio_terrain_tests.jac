import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, brush_volume, brush_windings, windings_bounds, brush_holds }
import from editor.geometry.csg { common_sides }
import from editor.geometry.terrain {
    terrain_brushes,
    flat_heights,
    heights_text,
    heights_from,
    sculpted,
    heights_image,
    image_heights
}

def near(a: float, b: float) -> bool {
    return abs(a - b) < 0.5;
}

test "heights are kept as a field and read back" {
    heights = [0.0, 16.0, 7.5, 128.0];
    assert heights_text(heights) == "0 16 7.5 128";
    back = heights_from("0 16 7.5 128", 1, 1);
    assert back is not None and back[2] == 7.5 and len(back) == 4;
    assert heights_from("0 16 7.5", 1, 1) is None and heights_from("0 16 x 128", 1, 1) is None;
    assert len(flat_heights(4, 3)) == 20 and flat_heights(1, 1, 8.0)[3] == 8.0;
}

test "a flat terrain is two prisms a cell, filling its slab" {
    made = terrain_brushes(Vec3(x=-64.0, y=-64.0, z=0.0), 2, 2, 64.0, flat_heights(2, 2), 16.0, "grass");
    assert len(made) == 8;
    total = 0.0;
    for brush in made {
        assert len(brush) == 5 and brush[0].material == "grass";
        total += brush_volume(brush);
    }
    assert near(total, 128.0 * 128.0 * 16.0);
    assert len(common_sides(made[0], made[1])) == 0;
    assert len(terrain_brushes(Vec3(), 2, 2, 64.0, [0.0, 1.0], 16.0)) == 0;
}

test "a raised corner lifts the prisms that meet at it" {
    heights = flat_heights(2, 2);
    heights[4] = 64.0;
    made = terrain_brushes(Vec3(x=0.0, y=0.0, z=0.0), 2, 2, 64.0, heights, 16.0);
    tallest = 0.0;
    lifted = 0;
    for brush in made {
        box = windings_bounds(brush_windings(brush));
        assert box is not None and near(box[0].z, 0.0);
        tallest = max(tallest, box[1].z);
        if box[1].z > 17.0 {
            lifted += 1;
        }
    }
    # The middle corner belongs to six of the eight prisms.
    assert near(tallest, 80.0) and lifted == 6;
    held = 0;
    for brush in made {
        if brush_holds(brush, Vec3(x=64.0, y=64.0, z=70.0)) {
            held += 1;
        }
    }
    assert held >= 1;
}

test "a stroke raises most at its centre and nothing past its edge" {
    origin = Vec3(x=0.0, y=0.0, z=0.0);
    flat = flat_heights(8, 8);
    raised = sculpted(flat, origin, 8, 8, 32.0, 128.0, 128.0, 96.0, 64.0);
    centre = raised[4 * 9 + 4];
    assert centre == 64.0 and raised[4 * 9 + 5] < centre and raised[4 * 9 + 5] > 0.0;
    assert raised[0] == 0.0 and raised[4 * 9 + 8] == 0.0 and flat[4 * 9 + 4] == 0.0;
    # Lowering never goes under the base; flattening pulls toward a height.
    assert min(sculpted(raised, origin, 8, 8, 32.0, 128.0, 128.0, 96.0, -500.0)) == 0.0;
    level = sculpted(raised, origin, 8, 8, 32.0, 128.0, 128.0, 200.0, 32.0, "flatten");
    assert level[4 * 9 + 4] == 32.0 and level[4 * 9 + 5] > 20.0;
    # Smoothing brings a spike toward its neighbours; noise roughens, the same way each time.
    spike = flat_heights(8, 8);
    spike[4 * 9 + 4] = 80.0;
    smooth = sculpted(spike, origin, 8, 8, 32.0, 128.0, 128.0, 96.0, 1.0, "smooth");
    assert smooth[4 * 9 + 4] < 80.0 and smooth[4 * 9 + 5] > 0.0;
    rough = sculpted(sculpted(flat, origin, 8, 8, 32.0, 128.0, 128.0, 300.0, 40.0), origin, 8, 8, 32.0, 128.0, 128.0, 300.0, 16.0, "noise");
    again = sculpted(sculpted(flat, origin, 8, 8, 32.0, 128.0, 128.0, 300.0, 40.0), origin, 8, 8, 32.0, 128.0, 128.0, 300.0, 16.0, "noise");
    assert rough == again and len(set(rough)) > 10;
}

test "heights go out as a grey image and come back" {
    heights = flat_heights(2, 1);
    heights[1] = 128.0;
    heights[5] = 64.0;
    text = heights_image(heights, 2, 1);
    assert text.startswith("P2\n3 2\n255\n") and text.splitlines()[3] == "0 0 128" and text.splitlines()[4] == "0 255 0";
    back = image_heights(text.encode("utf-8"), 128.0);
    assert back is not None and back[0] == 2 and back[1] == 1;
    assert back[2][1] == 128.0 and back[2][5] == 64.0 and back[2][0] == 0.0;
    # The other kind of PGM: bytes after the header.
    raw = b"P5\n# a comment\n2 2\n255\n" + bytes([0, 255, 128, 64]);
    read = image_heights(raw, 100.0);
    assert read is not None and read[0] == 1 and read[1] == 1 and read[2][3] == 100.0 and read[2][0] == 50.0;
    assert image_heights(b"JUNK", 1.0) is None and image_heights(b"P2\n2 2\n255\n0 1\n", 1.0) is None;
}
