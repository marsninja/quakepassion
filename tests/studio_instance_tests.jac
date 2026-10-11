import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { box_sides, brush_windings, windings_bounds }
import from editor.document.generate {
    map_box, prefab_placed, prefab_change, prefab_yaw, prefab_turns, map_remapped, with_prefabs
}
import from editor.geometry.linear { linear_turn }

def about(a: float, b: float) -> bool {
    return abs(a - b) < 0.01;
}

"""A bench: a seat 64 long, 16 deep and 8 thick on the origin, a lamp over
one end facing along it, and a spot that faces up."""
def bench -> list[MapItem] {
    return [
        MapItem(fields={"classname": "worldspawn"}, brushes=[box_sides(Vec3(x=-32.0, y=-8.0, z=0.0), Vec3(x=32.0, y=8.0, z=8.0), "wood")]),
        MapItem(fields={"classname": "info_notnull", "origin": "32 0 8", "angle": "0"}, brushes=[]),
        MapItem(fields={"classname": "light", "origin": "-32 0 8", "angle": "-1"}, brushes=[])
    ];
}

def seat_box(items: list[MapItem]) -> list[Vec3] {
    box = windings_bounds(brush_windings(items[0].brushes[0]));
    assert box is not None;
    return box;
}

test "an instance stands its prefab on its origin, as its file has it when nothing else is said" {
    plain = prefab_placed(bench(), {"classname": "misc_prefab", "prefab": "bench", "origin": "100 200 16"});
    assert len(plain) == 3 and prefab_change({"origin": "0 0 0"}) is None and prefab_change({"angle": "0", "_scale": "1"}) is None;
    box = seat_box(plain);
    assert about(box[0].x, 68.0) and about(box[1].x, 132.0) and about(box[0].y, 192.0) and about(box[0].z, 16.0) and about(box[1].z, 24.0);
    assert plain[1].fields["origin"] == "132 200 24" and plain[1].fields["angle"] == "0";
    # Without a place there is nothing to stand, and a prefab of nothing has no size.
    assert prefab_placed(bench(), {"classname": "misc_prefab"}) == [] and prefab_placed([], {"origin": "0 0 0"}) == [];
}

test "an instance turned a quarter round turns its brushes and what its entities face" {
    turned = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "100 200 16", "angle": "90"});
    box = seat_box(turned);
    # Sixty-four long along y now, about the instance's own place.
    assert about(box[0].x, 92.0) and about(box[1].x, 108.0) and about(box[0].y, 168.0) and about(box[1].y, 232.0);
    assert about(box[0].z, 16.0) and about(box[1].z, 24.0);
    # The lamp that stood at the +x end stands at the +y end, and faces a quarter further round.
    assert turned[1].fields["origin"] == "100 232 24" and turned[1].fields["angle"] == "90";
    # What faces up still faces up, where it has been carried to.
    assert turned[2].fields["origin"] == "100 168 24" and turned[2].fields["angle"] == "-1";
    # The wood lies along the seat still: its top's material turned with it.
    top = [side for side in turned[0].brushes[0] if side.plane.normal.z > 0.9][0];
    flat = [side for side in bench()[0].brushes[0] if side.plane.normal.z > 0.9][0];
    assert about(abs(top.mapping.s_axis.dot(Vec3(y=1.0))), abs(flat.mapping.s_axis.dot(Vec3(x=1.0))));
    assert prefab_yaw({"angle": "270"}) == 270.0 and prefab_yaw({"angle": "-1"}) == 0.0 and prefab_yaw({"angle": "north"}) == 0.0;
}

test "an instance sized is sized about its origin, by one number or three" {
    twice = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "0 0 0", "_scale": "2"});
    box = seat_box(twice);
    assert about(box[0].x, -64.0) and about(box[1].x, 64.0) and about(box[1].y, 16.0) and about(box[0].z, 0.0) and about(box[1].z, 16.0);
    assert twice[1].fields["origin"] == "64 0 16";
    # Longer only, and then turned: sized first, so it is the length that is doubled.
    long = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "0 0 0", "_scale": "2 1 1", "angle": "90"});
    box = seat_box(long);
    assert about(box[0].y, -64.0) and about(box[1].y, 64.0) and about(box[0].x, -8.0) and about(box[1].x, 8.0) and about(box[1].z, 8.0);
    # Mirrored end for end: still a brush, the lamp at the other end.
    back = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "0 0 0", "_scale": "-1 1 1"});
    box = seat_box(back);
    assert about(box[0].x, -32.0) and about(box[1].x, 32.0) and back[1].fields["origin"] == "-32 0 8";
    # A size that would flatten it, or that is not numbers, is not a size.
    assert prefab_change({"_scale": "0"}) is None and prefab_change({"_scale": "2 0 1"}) is None and prefab_change({"_scale": "big"}) is None;
    flat = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "0 0 0", "_scale": "0"});
    assert about(seat_box(flat)[1].x, 32.0);
}

test "instances within a prefab are turned and sized where they stand in it" {
    # Two benches back to back, the second turned half round and half as large.
    pair = [
        MapItem(fields={"classname": "worldspawn"}, brushes=[]),
        MapItem(fields={"classname": "misc_prefab", "prefab": "bench", "origin": "0 -16 0"}, brushes=[]),
        MapItem(fields={"classname": "misc_prefab", "prefab": "bench", "origin": "0 16 0", "angle": "180", "_scale": "0.5"}, brushes=[])
    ];
    whole = with_prefabs(pair, {"bench": bench()});
    assert len(whole) == 7;
    near = seat_box(whole[1:]);
    far = seat_box(whole[4:]);
    assert about(near[0].x, -32.0) and about(near[1].y, -8.0) and about(far[0].x, -16.0) and about(far[1].x, 16.0);
    assert about(far[0].y, 12.0) and about(far[1].y, 20.0) and about(far[1].z, 4.0);
    assert whole[5].fields["origin"] == "-16 16 4" and whole[5].fields["angle"] == "180";
    # A change of the world on its own: a quarter turn about a point leaves the point's own height.
    moved = map_remapped(bench(), Vec3(x=32.0, y=0.0, z=0.0), linear_turn(0, 1, 90.0), 90.0);
    assert moved[2].fields["origin"] == "32 -64 8" and moved[1].fields["origin"] == "32 0 8";
    assert map_box(moved) is not None;
}

test "an instance is tipped nose down and rolled about its length, as its angles say" {
    assert prefab_turns({"angle": "90"}) == [0.0, 90.0, 0.0] and prefab_turns({"angles": "30 90 15", "angle": "45"}) == [30.0, 90.0, 15.0];
    assert prefab_turns({"angles": "30 north 15", "angle": "45"}) == [0.0, 45.0, 0.0] and prefab_turns({"angles": "30 90"}) == [0.0, 0.0, 0.0];
    assert prefab_yaw({"angles": "30 90 15"}) == 90.0;
    # Nose down a quarter: what lay along x hangs down from the origin, and its top faces along x.
    down = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "0 0 0", "angles": "90 0 0"});
    box = seat_box(down);
    assert about(box[0].x, 0.0) and about(box[1].x, 8.0) and about(box[0].y, -8.0) and about(box[1].y, 8.0);
    assert about(box[0].z, -32.0) and about(box[1].z, 32.0);
    assert down[1].fields["origin"] == "8 0 -32";
    # Rolled a quarter: its depth stands up, its top faces the other side.
    over = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "0 0 0", "angles": "0 0 90"});
    box = seat_box(over);
    assert about(box[0].x, -32.0) and about(box[1].x, 32.0) and about(box[0].y, -8.0) and about(box[1].y, 0.0);
    assert about(box[0].z, -8.0) and about(box[1].z, 8.0);
    # Pitched and then turned round: nose down first, so it still hangs straight down.
    both = prefab_placed(bench(), {"classname": "misc_prefab", "origin": "0 0 0", "angles": "90 90 0"});
    box = seat_box(both);
    assert about(box[0].z, -32.0) and about(box[1].z, 32.0) and about(box[0].y, 0.0) and about(box[1].y, 8.0) and about(box[0].x, -8.0);
    # The entities inside face only as much further round as the instance is turned about the upright.
    assert both[1].fields["angle"] == "90" and down[1].fields["angle"] == "0";
}
