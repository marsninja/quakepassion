import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, FaceEdit, scene_map, scene_from_map }
import from editor.geometry.mapping { mapping_min_fitted, mapping_wrapped, mapping_bad, mapping_same }
import from editor.document.generate { with_holes, digs, DIGGER_KEY }
import from editor.geometry.brush {
    Side,
    Plane3,
    box_sides,
    brush_volume,
    brush_windings,
    windings_bounds,
    classic_mapping,
    Mapping
}
import from editor.geometry.faces {
    brush_bounded,
    sides_dropped,
    side_flipped,
    cone_on,
    prism_on,
    walls_on,
    outline_width
}
import from editor.formats.map { MapItem, read_map, write_map }

def near(a: float, b: float, slack: float = 0.5) -> bool {
    return abs(a - b) < slack;
}

def cube -> list[Side] {
    return box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall");
}

"""Which side of a brush faces most nearly a way."""
def facing(sides: list[Side], way: Vec3) -> int {
    best = 0;
    for index in range(len(sides)) {
        if sides[index].plane.normal.dot(way) > sides[best].plane.normal.dot(way) {
            best = index;
        }
    }
    return best;
}

def extra(normal: Vec3, dist: float) -> Side {
    return Side(
        plane=Plane3(normal=normal, dist=dist),
        material="trim",
        mapping=classic_mapping(normal, 0.0, 0.0, 0.0, 1.0, 1.0)
    );
}

test "a side is dropped only where the others close without it" {
    sides = cube();
    top = facing(sides, Vec3(z=1.0));
    assert brush_bounded(sides);
    # A cube without its top runs up for ever.
    assert sides_dropped(sides, [top]) == [];
    # A corner cut off by a seventh side: without that side it is the cube again.
    cut = sides + [extra(Vec3(x=1.0, y=1.0).normalized(), 64.0)];
    assert brush_volume(cut) < 64.0 * 64.0 * 64.0 - 1000.0;
    whole = sides_dropped(cut, [6]);
    assert len(whole) == 6 and near(brush_volume(whole), 64.0 * 64.0 * 64.0);
    assert sides_dropped(cut, [6, top]) == [];
}

test "a side turned round leaves what lay beyond it, where that is closed" {
    sides = cube();
    assert side_flipped(sides, facing(sides, Vec3(z=1.0))) == [];
    # A cube with a lid halfway up is its lower half; the lid turned, its upper.
    lidded = sides + [extra(Vec3(z=1.0), 32.0)];
    assert near(brush_volume(lidded), 64.0 * 64.0 * 32.0);
    upper = side_flipped(lidded, 6);
    assert len(upper) == 6 and near(brush_volume(upper), 64.0 * 64.0 * 32.0);
    box = windings_bounds(brush_windings(upper));
    assert box is not None and near(box[0].z, 32.0) and near(box[1].z, 64.0);
}

test "a cone, a prism and walls stand on a face" {
    sides = cube();
    top = facing(sides, Vec3(z=1.0));
    outline = brush_windings(sides)[top];
    cone = cone_on(outline, sides[top], 48.0);
    assert len(cone) == 5 and near(brush_volume(cone), 64.0 * 64.0 * 48.0 / 3.0, 2.0);
    box = windings_bounds(brush_windings(cone));
    assert box is not None and near(box[0].z, 64.0) and near(box[1].z, 112.0);
    assert cone[0].material == "wall" or cone[1].material == "wall";
    prism = prism_on(outline, sides[top], 16.0);
    assert len(prism) == 6 and near(brush_volume(prism), 64.0 * 64.0 * 16.0);
    walls = walls_on(outline, sides[top], 32.0, 8.0);
    assert len(walls) == 4;
    for wall in walls {
        assert near(brush_volume(wall), 64.0 * 8.0 * 32.0);
        reach = windings_bounds(brush_windings(wall));
        assert reach is not None and reach[0].x > -0.1 and reach[1].x < 64.1 and near(reach[0].z, 64.0);
        assert near(reach[1].z, 96.0);
    }
    # Out from a side face they stand sideways.
    east = facing(sides, Vec3(x=1.0));
    side_prism = prism_on(brush_windings(sides)[east], sides[east], 32.0);
    box = windings_bounds(brush_windings(side_prism));
    assert box is not None and near(box[0].x, 64.0) and near(box[1].x, 96.0) and near(box[1].z, 64.0);
    assert cone_on(outline, sides[top], 0.0) == [] and walls_on(outline, sides[top], 32.0, 0.0) == [];
}

def blockout -> Scene {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    scene.add_solid(world, box_sides(Vec3(x=-128.0, y=-128.0, z=-16.0), Vec3(x=128.0, y=128.0, z=0.0), "floor"));
    scene.add_solid(world, cube());
    return scene;
}

test "the document drops and turns faces and stands brushes on them, undoably" {
    scene = blockout();
    wall = scene.solids()[1];
    top = facing(wall.sides, Vec3(z=1.0));
    scene.select_face(wall, top);
    assert scene.drop_faces() == 0 and len(wall.sides) == 6 and len(scene.faces()) == 1;
    assert scene.flip_faces() == 0;
    assert scene.build_on_faces("cone", 32.0) == 1;
    made = scene.selected_solids();
    assert len(made) == 1 and len(scene.solids()) == 3 and scene.faces() == [];
    box = made[0].bounds();
    assert box is not None and near(box[0].z, 64.0) and near(box[1].z, 96.0);
    assert scene.owner_of(made[0]) is scene.world();
    assert scene.undo() == "Cone on face" and len(scene.solids()) == 2;
    scene.select_face(wall, top);
    assert scene.build_on_faces("walls", 32.0, 8.0) == 4 and len(scene.selected_solids()) == 4;
    assert scene.undo() == "Walls";
    scene.select_face(wall, top);
    scene.select_face(wall, facing(wall.sides, Vec3(x=1.0)), True);
    assert scene.build_on_faces("prism", 16.0) == 2 and len(scene.solids()) == 4;
    assert scene.undo() == "Extrude";
    assert scene.build_on_faces("prism", 16.0) == 0;
    # A lidded cube: the lid is dropped, or turned.
    lidded = scene.add_solid(scene.world(), cube() + [extra(Vec3(z=1.0), 32.0)]);
    scene.select_face(lidded, 6);
    assert scene.flip_faces() == 1 and scene.faces() == [];
    box = lidded.bounds();
    assert box is not None and near(box[0].z, 32.0) and near(box[1].z, 64.0);
    assert scene.undo() == "Flip face" and len(lidded.sides) == 7;
    scene.select_face(lidded, 6);
    assert scene.drop_faces() == 1 and len(lidded.sides) == 6;
    box = lidded.bounds();
    assert box is not None and near(box[0].z, 0.0) and near(box[1].z, 64.0);
    assert scene.undo() == "Delete face" and len(lidded.sides) == 7;
}

test "sides carry contents, surface flags and a value through the map" {
    scene = blockout();
    wall = scene.solids()[1];
    scene.select_solid(wall);
    # Detail: every side of the brush.
    assert scene.flag_sides("contents", 134217728) == 6;
    assert scene.flag_sides("contents", 134217728) == 0;
    assert wall.sides[0].contents == 134217728 and wall.sides[5].contents == 134217728;
    assert scene.flag_sides("contents", 2, "set") == 6 and wall.sides[0].contents == 134217730;
    assert scene.flag_sides("contents", 134217728, "clear") == 6 and wall.sides[3].contents == 2;
    # One picked face alone.
    top = facing(wall.sides, Vec3(z=1.0));
    scene.select_face(wall, top);
    assert scene.flag_sides("flags", 4) == 1 and scene.flag_sides("value", 300, "put") == 1;
    assert wall.sides[top].flags == 4 and wall.sides[top].value == 300;
    assert sum([side.flags for side in wall.sides]) == 4;
    assert scene.flag_sides("nothing", 1) == 0 and scene.flag_sides("flags", 1, "toggle") == 0;
    again = scene_from_map("passion", "studio:test", read_map(write_map(scene_map(scene))));
    kept = again.solids()[1].sides[top];
    assert kept.contents == 2 and kept.flags == 4 and kept.value == 300;
    assert scene.undo() == "Side flags" and wall.sides[top].value == 0;
}

test "a digger's brushes are holes in what is built, and the document keeps them" {
    whole = MapItem(fields={"classname": "worldspawn"}, brushes=[cube()]);
    hole = MapItem(
        fields={"classname": "func_group", DIGGER_KEY: "1"},
        brushes=[box_sides(Vec3(x=16.0, y=16.0, z=-8.0), Vec3(x=48.0, y=48.0, z=72.0), "trim")]
    );
    lamp = MapItem(fields={"classname": "light", "origin": "0 0 96"}, brushes=[]);
    assert digs(hole.fields) and not digs(whole.fields);
    assert len(with_holes([whole, lamp])) == 2;
    built = with_holes([whole, hole, lamp]);
    assert len(built) == 2 and built[0].fields["classname"] == "worldspawn" and built[1].fields["classname"] == "light";
    volume = 0.0;
    for brush in built[0].brushes {
        volume += brush_volume(brush);
    }
    # The cube less a square shaft through it.
    assert len(built[0].brushes) == 4 and near(volume, 64.0 * 64.0 * 64.0 - 32.0 * 32.0 * 64.0, 2.0);
    # What was handed in is as it was.
    assert len(whole.brushes) == 1 and len(hole.brushes) == 1;
    # A digger that touches nothing cuts nothing.
    far = MapItem(
        fields={"classname": "func_group", DIGGER_KEY: "1"},
        brushes=[box_sides(Vec3(x=200.0), Vec3(x=232.0, y=32.0, z=32.0), "trim")]
    );
    untouched = with_holes([whole, far]);
    assert len(untouched) == 1 and len(untouched[0].brushes) == 1;
}

test "a map is written without comments, or in whole numbers, when asked" {
    scene = blockout();
    plain = write_map(scene_map(scene));
    assert "// entity 0" in plain and "// brush 1" in plain;
    bare = write_map(scene_map(scene), "valve", False, False);
    assert "// entity" not in bare and "// brush" not in bare and bare.startswith("// Format: Valve");
    # The same map either way.
    assert write_map(scene_map(scene_from_map("passion", "studio:test", read_map(bare)))) == plain;
    # A brush turned off the grid has corners that are not whole; written whole, every plane point is.
    wall = scene.solids()[1];
    scene.select_solid(wall);
    assert scene.turn_selection(30.0, 8.0, 2, Vec3(x=32.0, y=32.0));
    exact = write_map(scene_map(scene));
    rounded = write_map(scene_map(scene), "valve", False, True, True);
    assert exact != rounded;
    for line in rounded.splitlines() {
        if line.startswith("( ") {
            points = line.split(" [ ")[0];
            for word in points.replace("(", " ").replace(")", " ").split()[:9] {
                assert "." not in word , line;
            }
        }
    }
}

test "a face's width is what it is at its narrowest, and the check names slivers" {
    square = [Vec3(), Vec3(x=64.0), Vec3(x=64.0, y=64.0), Vec3(y=64.0)];
    strip = [Vec3(), Vec3(x=64.0), Vec3(x=64.0, y=0.5), Vec3(y=0.5)];
    wedge = [Vec3(), Vec3(x=64.0), Vec3(x=64.0, y=0.25)];
    assert near(outline_width(square), 64.0) and near(outline_width(strip), 0.5, 0.01);
    assert outline_width(wedge) < 0.3;
    scene = blockout();
    assert [finding.words for finding in scene.problems() if "thinner" in finding.words] == [];
    # A cube with a corner shaved by half a unit has a sliver of a face.
    shaved = scene.add_solid(scene.world(), cube() + [extra(Vec3(x=1.0, y=1.0).normalized(), 90.2)]);
    words = [finding.words for finding in scene.problems() if "thinner" in finding.words];
    assert len(words) == 1 and words[0] == "Brush #" + str(shaved.serial) + " has 1 faces thinner than a unit" , str(words);
}

test "the face pick steps round a brush's faces and back" {
    scene = blockout();
    wall = scene.solids()[1];
    assert not scene.step_face();
    scene.select_face(wall, 0);
    seen: list[int] = [0];
    for turn in range(5) {
        assert scene.step_face();
        seen.append(scene.faces()[0].side);
    }
    assert sorted(seen) == [0, 1, 2, 3, 4, 5] and len(scene.faces()) == 1;
    assert scene.step_face() and scene.faces()[0].side == 0;
    assert scene.step_face(-1) and scene.faces()[0].side == 5;
    scene.select_face(wall, 2, True);
    assert not scene.step_face();
}

test "a material is fitted in whole repeats, wrapped round an edge and found when smeared" {
    sides = box_sides(Vec3(), Vec3(x=128.0, y=64.0, z=64.0), "wall");
    top = facing(sides, Vec3(z=1.0));
    east = facing(sides, Vec3(x=1.0));
    outlines = brush_windings(sides);
    # A 64-texel picture on a 128 by 64 face: twice across, once down, a texel a unit.
    fitted = mapping_min_fitted(sides[top].mapping, outlines[top], 64, 64);
    assert near(abs(fitted.s_scale), 1.0, 0.001) and near(abs(fitted.t_scale), 1.0, 0.001);
    # A 48-texel one: three across (42.7 a repeat) rather than stretched to one.
    close = mapping_min_fitted(sides[top].mapping, outlines[top], 48, 48);
    assert near(abs(close.s_scale), 128.0 / (48.0 * 3.0), 0.001) and near(abs(close.t_scale), 64.0 / 48.0, 0.001);
    # Wrapped from the top onto the east face: along the edge they share, both give a point the same place in the picture.
    wrapped = mapping_wrapped(sides[top].mapping, sides[top].plane, sides[east].plane);
    assert wrapped is not None;
    for point in [Vec3(x=128.0, y=0.0, z=64.0), Vec3(x=128.0, y=64.0, z=64.0), Vec3(x=128.0, y=20.0, z=64.0)] {
        was = sides[top].mapping;
        assert near(point.dot(was.s_axis) / was.s_scale + was.s_shift, point.dot(wrapped.s_axis) / wrapped.s_scale + wrapped.s_shift, 0.01);
        assert near(point.dot(was.t_axis) / was.t_scale + was.t_shift, point.dot(wrapped.t_axis) / wrapped.t_scale + wrapped.t_shift, 0.01);
    }
    # On the east face it runs on down the wall: the axis that ran along x now runs down z.
    assert near(abs(wrapped.s_axis.z) + abs(wrapped.t_axis.z), 1.0, 0.001) and near(wrapped.s_axis.x, 0.0, 0.001);
    # Faces that do not meet have no edge to wrap round.
    assert mapping_wrapped(sides[top].mapping, sides[top].plane, sides[facing(sides, Vec3(z=-1.0))].plane) is None;
    assert not mapping_bad(sides[top].mapping);
    assert mapping_bad(Mapping(s_axis=Vec3(x=1.0), t_axis=Vec3(x=1.0, y=0.01)));
    assert mapping_bad(Mapping(s_axis=Vec3(x=1.0), t_axis=Vec3(y=1.0), s_scale=0.0));
}

test "the document wraps and projects from a face, paints one, and glues one into a plane" {
    scene = blockout();
    wall = scene.solids()[1];
    top = facing(wall.sides, Vec3(z=1.0));
    east = facing(wall.sides, Vec3(x=1.0));
    scene.select_face(wall, top);
    assert scene.reface(FaceEdit(how="material", material="tile"), "Set material");
    assert scene.reface(FaceEdit(how="shift", s=8.0, t=4.0), "Material shift");
    tagged = wall.sides[top];
    scene.select_face(wall, east);
    assert scene.reface(FaceEdit(how="wrap", source=tagged), "Material wrap");
    assert wall.sides[east].material == "tile" and not mapping_same(wall.sides[east].mapping, tagged.mapping);
    assert not scene.reface(FaceEdit(how="wrap", source=tagged), "Material wrap");
    assert scene.undo() == "Material wrap" and wall.sides[east].material == "wall";
    # Projected, it lies on the other face exactly as on the tagged one.
    assert scene.reface(FaceEdit(how="project", source=tagged), "Material project");
    assert wall.sides[east].material == "tile" and mapping_same(wall.sides[east].mapping, tagged.mapping);
    # One face painted.
    north = facing(wall.sides, Vec3(y=1.0));
    assert scene.paint_face(wall, north, "moss") and wall.sides[north].material == "moss";
    assert not scene.paint_face(wall, north, "moss") and not scene.paint_face(wall, 99, "moss");
    assert scene.undo() == "Paint face";
    # The east face put in the plane x = 96: the cube reaches to it.
    scene.select_face(wall, east);
    assert scene.glue_face(Plane3(normal=Vec3(x=-1.0), dist=-96.0));
    box = wall.bounds();
    assert box is not None and near(box[1].x, 96.0) and near(box[0].x, 0.0);
    assert not scene.glue_face(Plane3(normal=Vec3(x=1.0), dist=96.0));
    # Pulled back behind its own far side, nothing would be left.
    assert not scene.glue_face(Plane3(normal=Vec3(x=1.0), dist=-8.0));
    assert scene.undo() == "Glue face";
    # The check finds a side whose material is smeared.
    smeared = scene.add_solid(scene.world(), cube());
    smeared.sides[0] = Side(
        plane=smeared.sides[0].plane, material="wall", mapping=Mapping(s_axis=Vec3(x=1.0), t_axis=Vec3(x=1.0))
    );
    words = [finding.words for finding in scene.problems() if "smeared" in finding.words];
    assert len(words) == 1 and words[0].startswith("Brush #" + str(smeared.serial) + " has 1 sides");
}
