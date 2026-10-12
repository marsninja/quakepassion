import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, box_sides, brush_volume, brush_windings, windings_bounds }
import from editor.formats.map { MapItem }
import from editor.document.generate { makes, made_brushes, with_makers, MAKER_KEYS }

"""The box round several brushes."""
def reach(brushes: list[list[Side]]) -> list[Vec3] {
    low = Vec3(x=100000.0, y=100000.0, z=100000.0);
    high = Vec3(x=-100000.0, y=-100000.0, z=-100000.0);
    for brush in brushes {
        box = windings_bounds(brush_windings(brush));
        if box is not None {
            low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
            high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
        }
    }
    return [low, high];
}

test "a group's fields say whether it makes something of its brushes" {
    assert makes({"classname": "func_group", "_hollow": "16"}) and makes({"_walls": "8"}) and makes({"_arch": "6 24"});
    assert not makes({"classname": "func_group"}) and not makes({"_hollow": "0"}) and not makes({"_walls": "thick"});
    assert not makes({"_arch": "-3"}) and MAKER_KEYS == ["_hollow", "_walls", "_arch"];
}

test "a box is built as a shell, as its walls alone, or as an arch" {
    box = box_sides(Vec3(), Vec3(x=128.0, y=128.0, z=96.0), "wall");
    whole = brush_volume(box);
    # A shell sixteen thick: six slabs, in the box's own room, with its inside left out.
    shell = made_brushes({"_hollow": "16"}, box);
    inside = 96.0 * 96.0 * 64.0;
    assert len(shell) == 6 and abs(sum([brush_volume(piece) for piece in shell]) - (whole - inside)) < 1.0;
    assert reach(shell)[0].x == 0.0 and reach(shell)[1].z == 96.0;
    # Its walls alone: four, as tall as the box, the floor and the roof gone.
    walls = made_brushes({"_walls": "16"}, box);
    assert len(walls) == 4 and abs(sum([brush_volume(piece) for piece in walls]) - (whole - 96.0 * 96.0 * 96.0)) < 1.0;
    for piece in walls {
        span = windings_bounds(brush_windings(piece));
        assert span is not None and span[0].z == 0.0 and span[1].z == 96.0;
    }
    # An arch of six blocks, within the box.
    arch = made_brushes({"_arch": "6 16"}, box);
    assert len(arch) == 6 and reach(arch)[0].x >= -0.01 and reach(arch)[1].x <= 128.01 and reach(arch)[1].z <= 96.01;
    assert arch[0][0].material == "wall";
    # Walls too thick to leave an inside: the brush is built as it is.
    assert made_brushes({"_hollow": "80"}, box) == [box] and made_brushes({}, box) == [box];
}

test "a map is built with its makers' brushes made, and everything else as it was" {
    plain = MapItem(fields={"classname": "worldspawn"}, brushes=[box_sides(Vec3(z=-16.0), Vec3(x=256.0, y=256.0), "floor")]);
    room = MapItem(
        fields={"classname": "func_group", "_group_name": "room", "_hollow": "8"},
        brushes=[box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "wall"), box_sides(Vec3(x=128.0), Vec3(x=192.0, y=64.0, z=64.0), "wall")]
    );
    built = with_makers([plain, room]);
    assert len(built) == 2 and built[0] is plain and len(built[0].brushes) == 1;
    # Two boxes, six slabs each; the group keeps its name and loses the field that made it.
    assert len(built[1].brushes) == 12 and built[1].fields == {"classname": "func_group", "_group_name": "room"};
    assert len(room.brushes) == 2 and "_hollow" in room.fields;
    assert with_makers([plain]) == [plain] and with_makers([]) == [];
}
