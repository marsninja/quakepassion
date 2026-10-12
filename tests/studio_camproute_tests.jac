import from engine.math.vec3 { Vec3 }
import from engine.world.world { World }
import from engine.world.bot_routes { build_navmesh }
import from engine.formats.aas { TRAVEL_WALK, TRAVEL_BARRIERJUMP, TRAVEL_WALKOFFLEDGE }
import from editor.compile.navigation {
    Floor, floor_ways, nav_data, route_time, route_legs, route_corners, legs_count
}

"""Two rooms on one level with a gap of floor missing between them, and a
bridge at one end."""
def rooms -> list[Floor] {
    floors: list[Floor] = [];
    for row in range(4) {
        for column in range(9) {
            if column == 4 and row != 3 {
                continue;
            }
            floors.append(Floor(column=column, row=row, z=0.0));
        }
    }
    return floors;
}

test "a way is walked area by area, down the time still to go" {
    floors = rooms();
    mesh = build_navmesh(World(), nav_data(floors, floor_ways(floors), Vec3(), 64.0));
    near = Vec3(x=32.0, y=32.0, z=24.0);
    far = Vec3(x=544.0, y=32.0, z=24.0);
    legs = route_legs(mesh, near, far);
    assert legs is not None;
    # Eight cells along and three up to the bridge and three back: fourteen areas crossed into, all walked.
    assert len(legs) == 14 and legs_count(legs) == [14, 0, 0, 0] , str(len(legs));
    # What the legs take is what the router said the way takes.
    assert sum([leg.time for leg in legs]) == route_time(mesh, near, far);
    # It goes by the bridge: some leg is left on the fourth row, in the column of the gap.
    assert len([leg for leg in legs if leg.start.y > 192.0 and 256.0 <= leg.start.x <= 320.0]) > 0;
    # Each leg is arrived at just past where it is left, and the next is left from the area it entered.
    for (index, leg) in enumerate(legs) {
        assert leg.start.sub(leg.finish).length() < 16.0;
        if index > 0 {
            assert mesh.locate(legs[index - 1].finish) == mesh.locate(Vec3(x=leg.start.x * 2.0 - leg.finish.x, y=leg.start.y * 2.0 - leg.finish.y, z=leg.start.z));
        }
    }
    assert mesh.locate(legs[-1].finish) == mesh.locate(far);
    # The corners to draw it by: both ends and each leg's two.
    corners = route_corners(near, legs, far);
    assert len(corners) == 30 and corners[0].x == 32.0 and corners[-1].x == 544.0;
    # The way back is as long.
    back = route_legs(mesh, far, near);
    assert back is not None and len(back) == 14;
}

test "one area has no legs; no floor and no way have no route" {
    floors = rooms();
    mesh = build_navmesh(World(), nav_data(floors, floor_ways(floors), Vec3(), 64.0));
    near = Vec3(x=32.0, y=32.0, z=24.0);
    same = route_legs(mesh, near, Vec3(x=40.0, y=20.0, z=24.0));
    assert same is not None and len(same) == 0;
    assert len(route_corners(near, [], near)) == 2;
    assert route_legs(mesh, near, Vec3(x=288.0, y=32.0, z=24.0)) is None;
    assert route_legs(mesh, Vec3(x=-500.0), near) is None;
    apart = [floor for floor in floors if floor.column != 4];
    lonely = build_navmesh(World(), nav_data(apart, floor_ways(apart), Vec3(), 64.0));
    assert route_legs(lonely, near, Vec3(x=544.0, y=32.0, z=24.0)) is None;
    inside = route_legs(lonely, near, Vec3(x=160.0, y=160.0, z=24.0));
    assert inside is not None and len(inside) == 4;
}

test "a ledge is a jumped leg up and a dropped leg down" {
    steps = [Floor(column=0, row=0, z=0.0), Floor(column=1, row=0, z=40.0), Floor(column=2, row=0, z=240.0), Floor(column=3, row=0, z=0.0)];
    mesh = build_navmesh(World(), nav_data(steps, floor_ways(steps), Vec3(), 64.0));
    low = Vec3(x=32.0, y=32.0, z=24.0);
    ledge = Vec3(x=96.0, y=32.0, z=64.0);
    up = route_legs(mesh, low, ledge);
    assert up is not None and legs_count(up) == [0, 1, 0, 0] and up[0].kind == TRAVEL_BARRIERJUMP;
    down = route_legs(mesh, ledge, low);
    assert down is not None and legs_count(down) == [0, 0, 1, 0] and down[0].kind == TRAVEL_WALKOFFLEDGE;
    # From the tower both neighbours are dropped to; nothing climbs it.
    top = Vec3(x=160.0, y=32.0, z=264.0);
    fall = route_legs(mesh, top, low);
    assert fall is not None and legs_count(fall) == [0, 0, 2, 0];
    assert route_legs(mesh, low, top) is None;
    assert TRAVEL_WALK not in [leg.kind for leg in fall];
}
