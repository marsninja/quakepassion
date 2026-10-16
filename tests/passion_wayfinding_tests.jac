import from games.passion.wayfinding { Wayfinding, RouteCue, HasCue, floor_light, room_paths, orient_arrivals }
import from games.passion.massing { Massing }
import from games.passion.spaces { Space }
import from games.passion.arrange { Estate, Corridor }
import from games.passion.mission { Expedition }
import from games.passion.dress { Lamp3, plain_box }
import from games.passion.experience { detail_boxes, clear_sight }
import from games.passion.cast { Director3, cast_teleporter, device_marks }
import from games.passion.random { stream_for }
import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }

test "a lamp behind a wall cannot certify a dark walking route" {
    mass = Massing(nx=20, ny=12, nz=12);
    mass.carve(1, 1, 1, 19, 11, 10, 0);
    point = [240.0, 176.0, 40.0];
    lamps = [Lamp3(x=304.0, y=176.0, z=96.0, level=240)];
    assert floor_light(mass, point, lamps, []) > 48.0;
    wall = detail_boxes([plain_box(Vec3(x=270.0, y=100.0, z=16.0), Vec3(x=274.0, y=250.0, z=160.0), "wall", 1.0)]);
    assert floor_light(mass, point, lamps, wall) == 0.0;
    lamps.append(Lamp3(x=240.0, y=176.0, z=96.0, level=210));
    assert floor_light(mass, point, lamps, wall) > 48.0;
}

test "walking route sampling finds a detour around thin dressing" {
    mass = Massing(nx=20, ny=12, nz=12);
    mass.carve(1, 1, 1, 19, 11, 10, 0);
    room = Space(id=0, x=1, y=1, z=1, w=18, d=10, h=9, stage=[3, 5, 1]);
    wall = detail_boxes([plain_box(Vec3(x=250.0, y=64.0, z=16.0), Vec3(x=258.0, y=224.0, z=160.0), "wall", 1.0)]);
    paths = room_paths(mass, room, wall);
    target = (1 * mass.ny + 5) * mass.nx + 12;
    assert target in paths;
    passed_end = False;
    while target >= 0 {
        y = (target // mass.nx) % mass.ny;
        if y >= 7 { passed_end = True; }
        target = paths[target];
    }
    assert passed_end;
}

test "portal pairs arrive beside their return pad without touching it" {
    mass = Massing(nx=40, ny=16, nz=16);
    mass.carve(1, 1, 1, 15, 15, 12, 0);
    mass.carve(20, 1, 1, 34, 15, 12, 1);
    one = Space(id=0, x=1, y=1, z=1, w=14, d=14, h=11, stage=[8, 8, 1]);
    two = Space(id=1, x=20, y=1, z=1, w=14, d=14, h=11, stage=[27, 8, 1]);
    director = Director3(estate=Estate(), mass=mass, plan=Expedition(seed=12), dice=stream_for(12, "test"), spaces={0: one, 1: two});
    cast_teleporter(director, Corridor(link=3, tail=0, head=1, teleport=True));
    assert not director.made.issues;
    pads = [item.fields for item in director.made.items if item.fields.get("classname", "") == "trigger_teleport"];
    arrivals = [item.fields for item in director.made.items if item.fields.get("classname", "") == "info_teleport_destination"];
    assert len(pads) == 2 and len(arrivals) == 2;
    for arrival in arrivals {
        pad = [p for p in pads if p["_room"] == arrival["_room"]][0];
        a = [float(v) for v in arrival["_portal_point"].split()];
        b = [float(v) for v in pad["_portal_point"].split()];
        assert a[2] == b[2];
        assert abs(a[0] - b[0]) + abs(a[1] - b[1]) == 96.0;
        assert clear_sight(mass, a, b);
        # Player half-width 16 plus trigger half-width 24 leaves a 56-unit gap.
        assert max(abs(a[0] - b[0]), abs(a[1] - b[1])) > 40.0;
    }
}

test "arrival faces a visible onward route before an optional or locked branch" {
    mass = Massing(nx=20, ny=20, nz=12);
    mass.carve(1, 1, 1, 19, 19, 10, 0);
    room = Space(id=0, stage=[5, 5, 1]);
    nav = Wayfinding();
    for cue in [
        RouteCue(room=0, destination=1, link=0, kind="gate", point=[176.0, 400.0, 40.0], gated=True),
        RouteCue(room=0, destination=2, link=1, kind="optional", point=[176.0, 80.0, 40.0], optional=True),
        RouteCue(room=0, destination=3, link=2, kind="forward", point=[400.0, 176.0, 40.0])
    ] { nav +>:HasCue:+> cue; }
    start_item = MapItem(fields={"classname": "info_player_start", "_room": "0", "origin": "176 176 40", "angle": "90"});
    orient_arrivals(nav, [room], mass, [start_item], []);
    assert start_item.fields["angle"] == "0";
    # Solid geometry hides that route; keep the existing view, don't aim at a wall.
    wall = detail_boxes([plain_box(Vec3(x=240.0, y=32.0, z=16.0), Vec3(x=248.0, y=550.0, z=160.0), "wall", 1.0)]);
    start_item.fields["angle"] = "90";
    orient_arrivals(nav, [room], mass, [start_item], wall);
    assert start_item.fields["angle"] == "90";
}

test "device marks have different shapes and stay within the moving platform" {
    assert len(device_marks(0.0, 0.0, 100.0, "light", 1.0, "exit")) == 4;
    assert len(device_marks(0.0, 0.0, 100.0, "light", 1.0, "jump")) == 3;
    lift = detail_boxes(device_marks(0.0, 0.0, 100.0, "light", 1.0, "lift"));
    assert len(lift) == 2;
    for bounds in lift { assert bounds[0] >= -30.0 and bounds[3] <= 30.0 and bounds[2] == 100.0 and bounds[5] == 101.0; }
}
