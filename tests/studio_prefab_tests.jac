import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { box_sides, brush_windings, windings_bounds }
import from editor.document.generate { map_box, map_shifted, prefab_overridden, with_prefabs }

def about(a: float, b: float) -> bool {
    return abs(a - b) < 0.01;
}

"""A post 16 square and 64 tall on the origin, with a light at its top that a button fires."""
def post -> list[MapItem] {
    return [
        MapItem(fields={"classname": "worldspawn"}, brushes=[box_sides(Vec3(x=-8.0, y=-8.0, z=0.0), Vec3(x=8.0, y=8.0, z=64.0), "wood")]),
        MapItem(fields={"classname": "light", "origin": "0 0 72", "targetname": "lamp", "light": "200"}, brushes=[]),
        MapItem(fields={"classname": "func_button", "target": "lamp"}, brushes=[box_sides(Vec3(x=8.0, y=-4.0, z=24.0), Vec3(x=12.0, y=4.0, z=32.0), "metal")])
    ];
}

test "a map's box takes in its brushes and its entities, and the whole of it is moved" {
    box = map_box(post());
    assert box is not None and about(box[0].x, -8.0) and about(box[1].x, 12.0) and about(box[0].z, 0.0) and about(box[1].z, 72.0);
    assert map_box([]) is None and map_box([MapItem(fields={"classname": "worldspawn"}, brushes=[])]) is None;
    moved = map_shifted(post(), Vec3(x=100.0, y=0.0, z=16.0));
    far = map_box(moved);
    assert far is not None and about(far[0].x, 92.0) and about(far[1].z, 88.0) and moved[1].fields["origin"] == "100 0 88";
    # What was given is left where it was.
    again = map_box(post());
    assert again is not None and about(again[0].x, -8.0);
}

test "an instance of a prefab swaps materials, sets fields and takes names of its own" {
    plain = prefab_overridden(post(), {"classname": "misc_prefab", "prefab": "post"});
    assert len(plain) == 3 and plain[0].brushes[0][0].material == "wood" and plain[1].fields["targetname"] == "lamp";
    changed = prefab_overridden(
        post(),
        {"_swap": "wood stone metal brass", "_put": "light light 400; lamp _color 1 0.8 0.6; func_button wait -1", "_names": "_a"}
    );
    assert changed[0].brushes[0][0].material == "stone" and changed[2].brushes[0][0].material == "brass";
    # A field set by classname, and one by the name it had before the word was added.
    assert changed[1].fields["light"] == "400" and changed[1].fields["_color"] == "1 0.8 0.6" and changed[2].fields["wait"] == "-1";
    assert changed[1].fields["targetname"] == "lamp_a" and changed[2].fields["target"] == "lamp_a";
    # The prefab itself is as it was.
    again = post();
    assert again[0].brushes[0][0].material == "wood" and again[1].fields["light"] == "200";
    # Half a pair of materials, or a put with too few words, changes nothing.
    assert prefab_overridden(post(), {"_swap": "wood", "_put": "light light"})[0].brushes[0][0].material == "wood";
}

test "prefabs within a prefab stand on their instances, each changed as its instance says" {
    # A gate: a lintel, and two posts as instances of the post, the second in stone with names of its own.
    gate = [
        MapItem(fields={"classname": "worldspawn"}, brushes=[box_sides(Vec3(x=-72.0, y=-8.0, z=64.0), Vec3(x=72.0, y=8.0, z=80.0), "wood")]),
        MapItem(fields={"classname": "misc_prefab", "prefab": "post", "origin": "-64 0 0"}, brushes=[]),
        MapItem(fields={"classname": "misc_prefab", "prefab": "post", "origin": "64 0 0", "_swap": "wood stone", "_names": "_east"}, brushes=[]),
        MapItem(fields={"classname": "misc_prefab", "prefab": "lost", "origin": "0 0 0"}, brushes=[])
    ];
    whole = with_prefabs(gate, {"post": post()});
    # The lintel, and three things from each post; the prefab nothing holds is left out.
    assert len(whole) == 7 and len([item for item in whole if item.fields.get("classname", "") == "misc_prefab"]) == 0;
    # The post's box runs from -8 to 12: its middle, 2, stands on the instance's place.
    west = windings_bounds(brush_windings(whole[1].brushes[0]));
    east = windings_bounds(brush_windings(whole[4].brushes[0]));
    assert west is not None and east is not None and about(west[0].x, -74.0) and about(west[0].z, 0.0) and about(east[0].x, 54.0);
    assert whole[1].brushes[0][0].material == "wood" and whole[4].brushes[0][0].material == "stone";
    assert whole[2].fields["targetname"] == "lamp" and whole[5].fields["targetname"] == "lamp_east" and whole[6].fields["target"] == "lamp_east";
    assert whole[5].fields["origin"] == "62 0 72";
    # With nothing to put in, a map without instances is the same map.
    assert len(with_prefabs(post(), {})) == 3;
}
