import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, box_sides, brush_windings, brush_volume, windings_bounds }
import from editor.formats.map { MapItem, MapFile, map_tokens, read_map, write_map, map_decimal }

"""A 64 cube at the origin as Quake's own editor wrote brushes."""
glob CLASSIC_MAP: str = "// a room\n{\n\"classname\" \"worldspawn\"\n\"wad\" \"gfx/base.wad\"\n{\n"
         + "( 0 0 0 ) ( 0 64 0 ) ( 0 0 64 ) tech04_1 0 0 0 1 1\n"
         + "( 64 0 0 ) ( 64 0 64 ) ( 64 64 0 ) tech04_1 16 8 90 2 0.5\n"
         + "( 0 0 0 ) ( 0 0 64 ) ( 64 0 0 ) *water0 0 0 0 1 1\n"
         + "( 0 64 0 ) ( 64 64 0 ) ( 0 64 64 ) {grate 0 0 0 1 1\n"
         + "( 0 0 0 ) ( 64 0 0 ) ( 0 64 0 ) +0button 0 0 0 1 1\n"
         + "( 0 0 64 ) ( 0 64 64 ) ( 64 0 64 ) sky1 0 0 0 1 1\n"
         + "}\n}\n{\n\"classname\" \"info_player_start\"\n\"origin\" \"32 32 24\"\n\"angle\" \"90\"\n}\n";

def near(a: float, b: float) -> bool {
    return abs(a - b) < 0.001;
}

test "a map splits into words, with braces only where they stand alone" {
    words = map_tokens("{ \"classname\" \"func wall\" // note\n{ ( 1 -2 3.5 ) {grate [ 0 1 ] }\n}");
    assert words == ["{", "\"classname", "\"func wall", "{", "(", "1", "-2", "3.5", ")", "{grate", "[", "0", "1", "]", "}", "}"];
    assert map_tokens("(0 0 0)(1 2 3)") == ["(", "0", "0", "0", ")", "(", "1", "2", "3", ")"];
}

test "a classic map reads into entities, brushes and faces" {
    found = read_map(CLASSIC_MAP);
    assert found.form == "classic" and found.skipped == 0 and len(found.items) == 2;
    world = found.items[0];
    assert world.fields == {"classname": "worldspawn", "wad": "gfx/base.wad"};
    assert len(world.brushes) == 1 and len(world.brushes[0]) == 6;
    sides = world.brushes[0];
    assert [side.material for side in sides] == ["tech04_1", "tech04_1", "*water0", "{grate", "+0button", "sky1"];
    # The six planes face out of the cube.
    assert near(sides[0].plane.normal.x, -1.0) and near(sides[1].plane.normal.x, 1.0) and near(sides[1].plane.dist, 64.0);
    assert near(sides[2].plane.normal.y, -1.0) and near(sides[3].plane.normal.y, 1.0);
    assert near(sides[4].plane.normal.z, -1.0) and near(sides[5].plane.normal.z, 1.0) and near(sides[5].plane.dist, 64.0);
    assert near(brush_volume(sides), 64.0 ** 3);
    turned = sides[1].mapping;
    assert near(turned.s_shift, 16.0) and near(turned.t_shift, 8.0) and near(turned.rotation, 90.0);
    assert near(turned.s_scale, 2.0) and near(turned.t_scale, 0.5);
    start = found.items[1];
    assert start.fields["origin"] == "32 32 24" and len(start.brushes) == 0;
}

test "a classic map writes back as it was read" {
    found = read_map(CLASSIC_MAP);
    written = write_map(found.items, form="classic");
    again = read_map(written);
    assert len(again.items) == 2 and len(again.items[0].brushes[0]) == 6;
    lines = [line for line in written.splitlines() if line.startswith("(")];
    assert lines[0] == "( 0 0 0 ) ( 0 64 0 ) ( 0 0 64 ) tech04_1 0 0 0 1 1";
    assert lines[1] == "( 64 0 0 ) ( 64 0 64 ) ( 64 64 0 ) tech04_1 16 8 90 2 0.5";
    assert lines[3] == "( 0 64 0 ) ( 64 64 0 ) ( 0 64 64 ) {grate 0 0 0 1 1";
    assert "\"origin\" \"32 32 24\"" in written;
}

test "the Valve form carries each face's texture axes and round-trips" {
    found = read_map(CLASSIC_MAP);
    written = write_map(found.items);
    assert written.startswith("// Format: Valve\n") and "\"mapversion\" \"220\"" in written;
    faces = [line for line in written.splitlines() if line.startswith("(")];
    assert faces[5] == "( 0 0 64 ) ( 0 64 64 ) ( 64 0 64 ) sky1 [ 1 0 0 0 ] [ 0 -1 0 0 ] 0 1 1";
    # The rotated face's axes are written out; reading them back gives the same texels.
    again = read_map(written);
    assert again.form == "valve" and again.items[0].fields["mapversion"] == "220";
    before = found.items[0].brushes[0][1].mapping;
    after = again.items[0].brushes[0][1].mapping;
    for point in [Vec3(x=64.0, y=10.0, z=20.0), Vec3(x=64.0, y=50.0, z=3.0)] {
        assert near(before.texel(point)[0], after.texel(point)[0]) and near(before.texel(point)[1], after.texel(point)[1]);
    }
    # Writing what was read changes nothing more.
    assert write_map(again.items) == written;
}

test "a brush made in the studio writes with points taken from its faces" {
    item = MapItem(fields={"classname": "worldspawn"}, brushes=[box_sides(Vec3(x=-32.0, y=-32.0, z=0.0), Vec3(x=32.0, y=32.0, z=16.0), "q1:e1m1/sfloor4_2")]);
    written = write_map([item]);
    again = read_map(written);
    sides = again.items[0].brushes[0];
    assert len(sides) == 6 and sides[0].material == "q1:e1m1/sfloor4_2";
    bounds = windings_bounds(brush_windings(sides));
    assert bounds is not None and near(bounds[0].x, -32.0) and near(bounds[1].z, 16.0);
    assert near(brush_volume(sides), 64.0 * 64.0 * 16.0);
}

test "Quake II's contents, flags and value ride along; unreadable blocks are counted" {
    text = "{\n\"classname\" \"worldspawn\"\n{\n"
        + "( 0 0 0 ) ( 0 64 0 ) ( 0 0 64 ) e1u1/metal3_2 0 0 0 1 1 1 16 100\n"
        + "( 64 0 0 ) ( 64 0 64 ) ( 64 64 0 ) e1u1/metal3_2 0 0 0 1 1 1 0 0\n"
        + "( 0 0 0 ) ( 0 0 64 ) ( 64 0 0 ) e1u1/metal3_2 0 0 0 1 1 1 0 0\n"
        + "( 0 64 0 ) ( 64 64 0 ) ( 0 64 64 ) e1u1/metal3_2 0 0 0 1 1 1 0 0\n"
        + "( 0 0 0 ) ( 64 0 0 ) ( 0 64 0 ) e1u1/metal3_2 0 0 0 1 1 1 0 0\n"
        + "( 0 0 64 ) ( 0 64 64 ) ( 64 0 64 ) e1u1/metal3_2 0 0 0 1 1 1 0 0\n"
        + "}\n{\npatchDef2\n{\ncommon/caulk\n( 3 3 0 0 0 )\n(\n( ( 0 0 0 0 0 ) )\n)\n}\n}\n}\n";
    found = read_map(text);
    assert found.skipped == 1 and len(found.items[0].brushes) == 1;
    first = found.items[0].brushes[0][0];
    assert first.contents == 1 and first.flags == 16 and first.value == 100;
    written = write_map(found.items, form="classic", quake2=True);
    assert "e1u1/metal3_2 0 0 0 1 1 1 16 100" in written;
}

test "a broken map says what it wanted" {
    for text in ["{ \"classname\" }", "{ \"a\" \"b\" { ( 0 0 x ) } }", "\"classname\" \"x\""] {
        raised = "";
        try {
            read_map(text);
        } except ValueError as error {
            raised = str(error);
        }
        assert raised.startswith("Map: ");
    }
    assert map_decimal(0.5) == "0.5" and map_decimal(-64.0) == "-64" and map_decimal(0.1234567) == "0.123457";
}
