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
