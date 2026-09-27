import from engine.world.bot_routes { NavMesh, build_navmesh, UNREACHED }
import from engine.formats.aas { Aas, AasArea, AasReach, TRAVEL_WALK, TRAVEL_JUMP }
import from engine.world.world { World }
import from engine.math.vec3 { Vec3 }

"""A row of eight areas 64 units apart, walkable both ways, with a one-way
jump from the first to the fifth: area 0 is AAS's null area."""
def row_aas -> Aas {
    areas: list[AasArea] = [AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3())];
    reaches: list[AasReach] = [];
    for i in range(1, 9) {
        center = Vec3(x=float(i) * 64.0);
        links: list[AasReach] = [];
        if i > 1 {
            links.append(AasReach(area=i - 1, start=center, finish=Vec3(x=float(i - 1) * 64.0), kind=TRAVEL_WALK, time=20));
        }
        if i < 8 {
            links.append(AasReach(area=i + 1, start=center, finish=Vec3(x=float(i + 1) * 64.0), kind=TRAVEL_WALK, time=20));
        }
        if i == 1 {
            links.append(AasReach(area=5, start=center, finish=Vec3(x=320.0), kind=TRAVEL_JUMP, time=10));
        }
        areas.append(AasArea(center=center, mins=center.sub(Vec3(x=32.0, y=32.0, z=32.0)), maxs=center.add(Vec3(x=32.0, y=32.0, z=32.0)), first_reach=len(reaches), reach_count=len(links)));
        reaches.extend(links);
    }
    return Aas(areas=areas, reaches=reaches);
}

test "a travel table built a budget at a time matches one built at once" {
    whole = build_navmesh(World(), row_aas());
    direct = whole.times_to(1);
    assert direct[1] == 0;
    assert direct[8] < UNREACHED;
    parts = build_navmesh(World(), row_aas());
    assert parts.times_ready(1) is None;
    assert len(parts.jobs) == 1;
    rounds = 0;
    while parts.times_ready(1) is None and rounds < 100 {
        parts.advance_tables(2);
        rounds += 1;
    }
    assert rounds > 1;
    assert not parts.jobs;
    assert parts.times_ready(1) == direct;
}

test "travel tables follow one-way passages in their direction only" {
    mesh = build_navmesh(World(), row_aas());
    to_five = mesh.times_to(5);
    to_one = mesh.times_to(1);
    # Area 1 jumps straight to 5; from 5 back to 1 is four walks.
    assert to_five[1] < to_one[5];
}
