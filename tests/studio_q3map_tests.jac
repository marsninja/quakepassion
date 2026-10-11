import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, Mapping, box_sides, brush_windings }
import from editor.formats.map { MapItem, MapPatch, MapFile, read_map, write_map, map_materials, map_renamed }
import from editor.document.scene { scene_from_map, scene_map }
import from editor.document.generate { with_patches }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""A box with a material that lies turned and stretched on every side, and
a side that is a ladder."""
def crate -> list[Side] {
    sides = box_sides(Vec3(x=-32.0, y=-64.0, z=0.0), Vec3(x=96.0, y=64.0, z=48.0), "base_wall/concrete");
    made: list[Side] = [];
    for (index, side) in enumerate(sides) {
        lay = Mapping(
            s_axis=side.mapping.s_axis.scale(0.8).add(side.mapping.t_axis.scale(0.6)),
            t_axis=side.mapping.t_axis.scale(0.8).sub(side.mapping.s_axis.scale(0.6)),
            s_shift=13.0 + float(index),
            t_shift=-7.5,
            s_scale=0.5,
            t_scale=2.0
        );
        made.append(
            Side(plane=side.plane, material=side.material, mapping=lay, contents=1 << 27 if index == 2 else 0, flags=8 if index == 2 else 0)
        );
    }
    return made;
}

test "a brush written as Quake III's brushDef is read back with its material where it lay" {
    sizes = {"base_wall/concrete": [128, 64]};
    world = MapItem(fields={"classname": "worldspawn"}, brushes=[crate()]);
    text = write_map([world], "primitives", False, True, False, sizes);
    assert "brushDef" in text and "// Format: Valve" not in text and "mapversion" not in text and "[" not in text;
    # A side is three points, a matrix of two rows, the material and its three numbers.
    first = [line for line in text.split("\n") if line.startswith("( ")][0];
    assert first.count("(") == 6 and first.endswith(" base_wall/concrete 0 0 0") , first;
    read = read_map(text, sizes);
    assert read.form == "primitives" and read.skipped == 0 and len(read.items) == 1 and len(read.items[0].brushes) == 1;
    back = read.items[0].brushes[0];
    assert len(back) == 6 and back[2].contents == 1 << 27 and back[2].flags == 8 and back[0].contents == 0;
    outlines = brush_windings(crate());
    for (index, side) in enumerate(crate()) {
        assert about(back[index].plane.normal.dot(side.plane.normal), 1.0, 0.0001) and back[index].material == "base_wall/concrete";
        for corner in outlines[index] {
            was = side.mapping.texel(corner);
            now = back[index].mapping.texel(corner);
            assert about(was[0], now[0]) and about(was[1], now[1]) , str(index);
        }
    }
    assert map_materials(read.items) == ["base_wall/concrete"];
    # Read as if the texture were another size, the same matrix lays it at another scale.
    other = read_map(text, {"base_wall/concrete": [256, 64]}).items[0].brushes[0];
    assert about(other[0].mapping.s_scale, back[0].mapping.s_scale * 0.5, 0.0001) and about(other[0].mapping.t_scale, back[0].mapping.t_scale, 0.0001);
    # And with no size said it is taken as 64 by 64.
    plain = read_map(text).items[0].brushes[0];
    assert about(plain[0].mapping.s_scale, back[0].mapping.s_scale * 2.0, 0.0001);
}

test "a map goes from Valve's form to Quake III's and back with nothing moved" {
    world = MapItem(fields={"classname": "worldspawn", "message": "yard"}, brushes=[crate()]);
    lamp = MapItem(fields={"classname": "light", "origin": "0 0 96"}, brushes=[]);
    valve = write_map([world, lamp], "valve");
    sizes = {"base_wall/concrete": [64, 64]};
    there = read_map(write_map(read_map(valve).items, "primitives", False, True, False, sizes), sizes);
    again = read_map(write_map(there.items, "valve")).items;
    assert len(again) == 2 and again[1].fields["origin"] == "0 0 96" and again[0].fields["message"] == "yard";
    outlines = brush_windings(crate());
    for (index, side) in enumerate(crate()) {
        for corner in outlines[index] {
            was = side.mapping.texel(corner);
            now = again[0].brushes[0][index].mapping.texel(corner);
            assert about(was[0], now[0]) and about(was[1], now[1]);
        }
    }
}

test "a curved patch is written as patchDef2 with its places on the texture, and read back" {
    points: list[Vec3] = [];
    places: list[float] = [];
    for row in range(3) {
        for column in range(5) {
            points.append(Vec3(x=float(column) * 32.0, y=float(row) * 48.0, z=16.0 if column == 2 else 0.0));
            places.append(float(column) * 32.0);
            places.append(float(row) * 16.0);
        }
    }
    bent = MapPatch(width=5, height=3, points=points, material="base_wall/metal", places=places);
    sizes = {"base_wall/metal": [128, 32]};
    text = write_map([MapItem(fields={"classname": "worldspawn"}, patches=[bent])], "primitives", False, True, False, sizes);
    assert "patchDef2" in text and "( 5 3 0 0 0 )" in text and text.count("base_wall/metal") == 1;
    # The last point of the last column: a whole texture across and a whole one down.
    assert "( 128 96 0 1 1 ) )" in text , text;
    read = read_map(text, sizes);
    assert read.skipped == 0 and len(read.items[0].patches) == 1;
    back = read.items[0].patches[0];
    assert back.width == 5 and back.height == 3 and back.material == "base_wall/metal" and len(back.points) == 15;
    for index in range(15) {
        assert about(back.points[index].sub(points[index]).length(), 0.0) and about(back.places[index * 2], places[index * 2]);
        assert about(back.places[index * 2 + 1], places[index * 2 + 1]);
    }
    # A patch with no places of its own has the texture spread once over it; it is written in any form.
    bare = MapPatch(width=3, height=3, points=points[:9], material="base_wall/metal");
    spread = write_map([MapItem(fields={"classname": "worldspawn"}, patches=[bare])], "valve");
    assert "patchDef2" in spread and "0.5 0.5 )" in spread;
    even = read_map(spread, sizes).items[0].patches[0];
    assert about(even.places[8], 64.0) and about(even.places[9], 16.0) and about(even.places[16], 128.0) and about(even.places[17], 32.0);
    # A patch whose points do not make its grid is left out.
    broken = MapPatch(width=3, height=3, points=points[:5], material="x");
    assert "patchDef2" not in write_map([MapItem(fields={"classname": "worldspawn"}, patches=[broken])], "valve");
}

test "a patch read into a scene is a group of prisms, and written out is a patch again" {
    points: list[Vec3] = [];
    places: list[float] = [];
    for row in range(3) {
        for column in range(3) {
            points.append(Vec3(x=float(column) * 64.0, y=float(row) * 64.0, z=32.0 if column == 1 and row == 1 else 0.0));
            places.append(float(column) * 64.0);
            places.append(float(row) * 32.0);
        }
    }
    sizes = {"base_wall/metal": [128, 64], "base_wall/concrete": [64, 64]};
    world = MapItem(
        fields={"classname": "worldspawn"},
        brushes=[crate()],
        patches=[MapPatch(width=3, height=3, points=points, material="base_wall/metal", places=places)]
    );
    scene = scene_from_map("passion", "studio:bend", read_map(write_map([world], "primitives", False, True, False, sizes), sizes));
    groups = [item for item in scene.items() if item.classname() == "func_group"];
    assert len(groups) == 1 and groups[0].fields["_patch"] == "3 3 4 8" and len(scene.solids_of(groups[0])) > 8;
    assert groups[0].fields["_st"].split()[:4] == ["0", "0", "64", "0"] and len(scene.solids()) > 9;
    # As a scene keeps it the map has the group and its prisms; for Quake III the group gives way
    # to the patch it stands for, in the world.
    kept = scene_map(scene);
    out = with_patches(kept);
    assert len(kept) == 2 and len(out) == 1 and len(out[0].brushes) == 1 and len(out[0].patches) == 1;
    again = out[0].patches[0];
    assert again.width == 3 and again.material == "base_wall/metal" and again.places == places;
    for index in range(9) {
        assert about(again.points[index].sub(points[index]).length(), 0.0);
    }
    text = write_map(out, "primitives", False, True, False, sizes);
    assert text.count("patchDef2") == 1 and text.count("brushDef") == 1 and "func_group" not in text and "_points" not in text;
    # A map with no patches is the same map; a group that only looks like one is left alone.
    assert len(with_patches([world])) == 1 and len(with_patches([])) == 0;
    odd = MapItem(fields={"classname": "func_group", "_patch": "3 3 4 8", "_points": "1 2 3"}, brushes=[crate()]);
    assert len(with_patches([world, odd])) == 2 and len(with_patches([world, odd])[1].brushes) == 1;
    # Materials are called what a file calls them, and back.
    named = map_renamed(out, {"base_wall/metal": "q3:textures/base_wall/metal"});
    assert named[0].patches[0].material == "q3:textures/base_wall/metal" and named[0].brushes[0][0].material == "base_wall/concrete";
    assert out[0].patches[0].material == "base_wall/metal";
}
