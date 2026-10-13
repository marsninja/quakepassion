import from engine.math.vec3 { Vec3 }
import from engine.world.world { World }
import from engine.world.bot_routes { build_navmesh }
import from engine.formats.aas { TRAVEL_WALK, TRAVEL_BARRIERJUMP, TRAVEL_WALKOFFLEDGE, AREA_GROUNDED }
import from editor.compile.navigation { Floor, Way, floor_ways, floor_middle, nav_data, ways_count, route_time }

"""A flat square of floors, `side` cells each way, at a height."""
def square(side: int, z: float = 0.0) -> list[Floor] {
    return [Floor(column=column, row=row, z=z) for row in range(side) for column in range(side)];
}

test "neighbouring floors are walked between, jumped onto and dropped from by their heights" {
    flat = floor_ways(square(3));
    # Each of nine floors has a way to each floor beside it: twenty-four in all, every one walked.
    assert len(flat) == 24 and ways_count(flat) == [24, 0, 0];
    assert len([way for way in flat if way.source == 4]) == 4 and len([way for way in flat if way.source == 0]) == 2;
    # A row of five: a step, a ledge, a long fall, and a drop too far.
    row = [
        Floor(column=0, row=0, z=0.0), Floor(column=1, row=0, z=16.0), Floor(column=2, row=0, z=56.0),
        Floor(column=3, row=0, z=-120.0), Floor(column=4, row=0, z=-600.0)
    ];
    ways = floor_ways(row);
    kinds = {(way.source, way.target): way.kind for way in ways};
    assert kinds[(0, 1)] == TRAVEL_WALK and kinds[(1, 0)] == TRAVEL_WALK;
    assert kinds[(1, 2)] == TRAVEL_BARRIERJUMP and kinds[(2, 1)] == TRAVEL_WALKOFFLEDGE;
    assert kinds[(2, 3)] == TRAVEL_WALKOFFLEDGE and (3, 2) not in kinds;
    # Four hundred and eighty down is further than a bot drops; and nothing climbs it.
    assert (3, 4) not in kinds and (4, 3) not in kinds and ways_count(ways) == [2, 1, 2];
    # Two floors in the cell beside: the one within reach is walked to, not the one above the head.
    stacked = [Floor(column=0, row=0, z=0.0), Floor(column=1, row=0, z=8.0), Floor(column=1, row=0, z=128.0)];
    kinds = {(way.source, way.target): way.kind for way in floor_ways(stacked)};
    assert kinds == {(0, 1): TRAVEL_WALK, (1, 0): TRAVEL_WALK, (2, 0): TRAVEL_WALKOFFLEDGE};
}

test "the floors become areas with ways out, and a tree that says where a point is" {
    floors = square(3);
    origin = Vec3(x=-48.0, y=-48.0);
    data = nav_data(floors, floor_ways(floors), origin, 32.0);
    assert len(data.areas) == 10 and len(data.reaches) == 25;
    middle = data.areas[5];
    assert middle.flags & AREA_GROUNDED != 0 and middle.reach_count == 4 and middle.center.x == 0.0 and middle.center.z == 24.0;
    assert middle.mins.x == -16.0 and middle.maxs.x == 16.0 and middle.mins.z == 0.0 and middle.maxs.z == 56.0;
    # A way out is left at the shared edge and arrived at just past it.
    out = [data.reaches[index] for index in range(middle.first_reach, middle.first_reach + middle.reach_count)];
    east = [reach for reach in out if reach.area == 6][0];
    assert east.start.x == 16.0 and east.start.y == 0.0 and east.finish.x == 20.0 and east.kind == TRAVEL_WALK;
    # Every cell's own points are in its area; off the grid, and under the floor, nowhere.
    for (index, floor) in enumerate(floors) {
        spot = floor_middle(floor, origin, 32.0);
        assert data.area_at(Vec3(x=spot.x + 5.0, y=spot.y - 7.0, z=24.0)) == index + 1;
    }
    assert data.area_at(Vec3(x=0.0, y=0.0, z=-20.0)) == 0 and data.area_at(Vec3(x=0.0, y=0.0, z=400.0)) == 5;
    for outside in [Vec3(x=-60.0, z=24.0), Vec3(x=60.0, z=24.0), Vec3(y=-60.0, z=24.0), Vec3(y=60.0, z=24.0)] {
        assert data.area_at(outside) == 0;
    }
    assert data.area_at(Vec3(x=-47.0, y=47.0, z=24.0)) == 7 and data.area_at(Vec3(x=47.0, y=-47.0, z=24.0)) == 3;
    # Floors over floors: a point is in the area of the floor under it.
    tower = [Floor(column=0, row=0, z=0.0), Floor(column=0, row=0, z=128.0), Floor(column=1, row=0, z=0.0)];
    stacked = nav_data(tower, floor_ways(tower), Vec3(), 32.0);
    assert stacked.area_at(Vec3(x=16.0, y=16.0, z=24.0)) == 1 and stacked.area_at(Vec3(x=16.0, y=16.0, z=152.0)) == 2;
    assert stacked.area_at(Vec3(x=48.0, y=16.0, z=152.0)) == 3 and stacked.area_at(Vec3(x=48.0, y=16.0, z=-5.0)) == 0;
    # No floors: the data is empty, and every point is nowhere.
    bare = nav_data([], [], Vec3(), 32.0);
    assert len(bare.areas) == 1 and bare.area_at(Vec3()) == 0;
}

test "the engine's router finds its way over what was baked" {
    # Two rooms on one level with a gap of floor missing between them, and a bridge at one end.
    floors: list[Floor] = [];
    for row in range(4) {
        for column in range(9) {
            if column == 4 and row != 3 {
                continue;
            }
            floors.append(Floor(column=column, row=row, z=0.0));
        }
    }
    data = nav_data(floors, floor_ways(floors), Vec3(), 64.0);
    mesh = build_navmesh(World(), data);
    near = Vec3(x=32.0, y=32.0, z=24.0);
    far = Vec3(x=544.0, y=32.0, z=24.0);
    beside = Vec3(x=96.0, y=32.0, z=24.0);
    assert mesh.locate(near) == 1 and mesh.locate(far) > 1 and route_time(mesh, near, near) == 0;
    # The way round by the bridge is longer than the way to the cell next door.
    round_about = route_time(mesh, near, far);
    next_door = route_time(mesh, near, beside);
    assert next_door > 0 and round_about > next_door * 8 , str(round_about) + " " + str(next_door);
    # With the bridge gone the far room is cut off; the near room is still its own.
    apart = [floor for floor in floors if floor.column != 4];
    lonely = build_navmesh(World(), nav_data(apart, floor_ways(apart), Vec3(), 64.0));
    assert route_time(lonely, near, far) == -1 and route_time(lonely, near, Vec3(x=160.0, y=160.0, z=24.0)) > 0;
    # A place on no floor has no way to it or from it.
    assert route_time(lonely, near, Vec3(x=288.0, y=32.0, z=24.0)) == -1 and route_time(lonely, Vec3(x=-500.0), near) == -1;
    # A ledge is dropped from and not climbed: down there is a way, up there is none.
    cliff = [Floor(column=0, row=0, z=200.0), Floor(column=1, row=0, z=0.0)];
    fall = build_navmesh(World(), nav_data(cliff, floor_ways(cliff), Vec3(), 64.0));
    top = Vec3(x=32.0, y=32.0, z=224.0);
    foot = Vec3(x=96.0, y=32.0, z=24.0);
    assert route_time(fall, top, foot) > 0 and route_time(fall, foot, top) == -1;
    # A low ledge is jumped onto, at a cost.
    ledge = [Floor(column=0, row=0, z=0.0), Floor(column=1, row=0, z=40.0)];
    hop = build_navmesh(World(), nav_data(ledge, floor_ways(ledge), Vec3(), 64.0));
    assert route_time(hop, Vec3(x=32.0, y=32.0, z=24.0), Vec3(x=96.0, y=32.0, z=64.0)) > next_door;
}

import from editor.compile.navigation { Link, floor_under, linked_ways }
import from engine.formats.aas { TRAVEL_TELEPORT, TRAVEL_JUMPPAD }

test "teleporters and jump pads join the floors under their two ends" {
    # Two rooms of floor apart, one high, with nothing between them.
    floors: list[Floor] = [];
    for column in range(3) {
        floors.append(Floor(column=column, row=0, z=0.0));
        floors.append(Floor(column=column + 10, row=0, z=128.0));
    }
    origin = Vec3();
    assert floor_under(floors, origin, 32.0, Vec3(x=48.0, y=16.0, z=24.0)) == 2;
    # Over the high room: its floor, not one above the point.
    assert floors[floor_under(floors, origin, 32.0, Vec3(x=336.0, y=16.0, z=200.0))].column == 10;
    assert floor_under(floors, origin, 32.0, Vec3(x=900.0, y=16.0, z=24.0)) == -1;
    links = [
        Link(start=Vec3(x=16.0, y=16.0, z=24.0), finish=Vec3(x=368.0, y=16.0, z=152.0), kind=TRAVEL_TELEPORT),
        Link(start=Vec3(x=80.0, y=16.0, z=24.0), finish=Vec3(x=336.0, y=16.0, z=160.0), kind=TRAVEL_JUMPPAD),
        Link(start=Vec3(x=900.0, y=16.0, z=24.0), finish=Vec3(x=336.0, y=16.0, z=160.0))
    ];
    ways = linked_ways(floors, origin, 32.0, links);
    assert len(ways) == 2 and ways[0].kind == TRAVEL_TELEPORT and ways[1].kind == TRAVEL_JUMPPAD;
    assert floors[ways[0].source].column == 0 and floors[ways[0].target].column == 11;
    # The router goes through the teleporter: the two rooms are joined.
    aas = nav_data(floors, floor_ways(floors) + ways, origin, 32.0);
    assert len([reach for reach in aas.reaches if reach.kind == TRAVEL_TELEPORT]) == 1;
}

import from editor.compile.navigation { swim_ways, aas_bytes }
import from engine.formats.aas { parse_aas, TRAVEL_SWIM, TRAVEL_LADDER, TRAVEL_ELEVATOR }

test "deep water's floor is swum to and from the shore" {
    # The shore at 0, then the bottom of a pool 128 deep with water up to -8.
    floors = [Floor(column=0, row=0, z=0.0), Floor(column=1, row=0, z=-128.0), Floor(column=2, row=0, z=-128.0)];
    pool = [[Vec3(x=32.0, y=0.0, z=-128.0), Vec3(x=96.0, y=32.0, z=-8.0)]];
    walked = floor_ways(floors);
    # Without the water the bottom is only dropped into.
    assert len([way for way in walked if way.source == 1 and way.target == 0]) == 0;
    swum = swim_ways(floors, Vec3(), 32.0, pool);
    kinds = [(way.source, way.target) for way in swum];
    assert (1, 0) in kinds and (0, 1) in kinds and (1, 2) in kinds and (2, 1) in kinds;
    assert len([way for way in swum if way.kind != TRAVEL_SWIM]) == 0 and swim_ways(floors, Vec3(), 32.0, []) == [];
    # Water too far below the shore to climb out of: no way up.
    low_pool = [[Vec3(x=32.0, y=0.0, z=-128.0), Vec3(x=96.0, y=32.0, z=-64.0)]];
    assert (1, 0) not in [(way.source, way.target) for way in swim_ways(floors, Vec3(), 32.0, low_pool)];
}

test "ladders and lifts join the floors at their ends, and a lift carries its model" {
    floors = [Floor(column=0, row=0, z=0.0), Floor(column=1, row=0, z=192.0)];
    links = [
        Link(start=Vec3(x=16.0, y=16.0, z=24.0), finish=Vec3(x=48.0, y=16.0, z=216.0), kind=TRAVEL_LADDER),
        Link(start=Vec3(x=16.0, y=16.0, z=24.0), finish=Vec3(x=48.0, y=16.0, z=216.0), kind=TRAVEL_ELEVATOR, model=3)
    ];
    ways = linked_ways(floors, Vec3(), 32.0, links);
    assert len(ways) == 2 and ways[1].model == 3;
    aas = nav_data(floors, ways, Vec3(), 32.0);
    lifts = [reach for reach in aas.reaches if reach.kind == TRAVEL_ELEVATOR];
    assert len(lifts) == 1 and lifts[0].face_num == 3 and lifts[0].time > 100;
}

test "the navigation is written as an arena's file and reads back the same" {
    floors = [Floor(column=column, row=row, z=0.0) for row in range(3) for column in range(3)];
    aas = nav_data(floors, floor_ways(floors), Vec3(x=-48.0, y=-48.0), 32.0);
    data = aas_bytes(aas);
    assert data[:4] == b"EAAS";
    back = parse_aas(data);
    assert len(back.areas) == len(aas.areas) and len(back.reaches) == len(aas.reaches);
    assert len(back.node_planes) == len(aas.node_planes) and back.front == aas.front and back.back == aas.back;
    for (index, area) in enumerate(aas.areas) {
        assert back.areas[index].first_reach == area.first_reach and back.areas[index].reach_count == area.reach_count;
        assert abs(back.areas[index].center.z - area.center.z) < 0.01;
    }
    # The tree finds the same area for a point.
    assert back.area_at(Vec3(x=0.0, y=0.0, z=24.0)) == aas.area_at(Vec3(x=0.0, y=0.0, z=24.0)) and back.area_at(Vec3(z=24.0)) > 0;
}

test "a lift's top is the ledge at its height, not the lift it rose on" {
    # The lift's own cell, lowered, and the ledge beside it up high.
    floors = [Floor(column=0, row=0, z=6.0), Floor(column=1, row=0, z=128.0), Floor(column=-1, row=0, z=0.0)];
    up = Link(start=Vec3(x=16.0, y=16.0, z=30.0), finish=Vec3(x=16.0, y=16.0, z=152.0), kind=TRAVEL_ELEVATOR, model=1);
    ways = linked_ways(floors, Vec3(), 32.0, [up]);
    assert len(ways) == 1 and ways[0].source == 0 and ways[0].target == 1;
    # With nothing at its height, no way.
    assert linked_ways(floors[:1] + floors[2:], Vec3(), 32.0, [up]) == [];
}
