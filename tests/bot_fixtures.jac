"""Shared navigation fixtures without registering another test suite."""
import from engine.formats.aas { Aas, AasArea, AasReach, AREA_GROUNDED, AREACONTENTS_LAVA, TRAVEL_ROCKETJUMP }
import from engine.math.vec3 { Vec3 }

"""A strip of areas 64 units wide along x (area i centred at x = 64 i), found
by a chain of split planes; `links` are (from, to, travel type) and
`lava` areas hold lava."""
def strip_aas(count: int, links: list[tuple[int, int, int]], lava: list[int] = []) -> Aas {
    areas: list[AasArea] = [AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3())];
    reaches: list[AasReach] = [];
    for i in range(1, count + 1) {
        center = Vec3(x=float(i) * 64.0);
        mine = [link for link in links if link[0] == i];
        areas.append(
            AasArea(
                center=center,
                mins=center.sub(Vec3(x=32.0, y=32.0, z=32.0)),
                maxs=center.add(Vec3(x=32.0, y=32.0, z=32.0)),
                flags=AREA_GROUNDED,
                contents=AREACONTENTS_LAVA if i in lava else 0,
                first_reach=len(reaches),
                reach_count=len(mine)
            )
        );
        for link in mine {
            reaches.append(
                AasReach(
                    area=link[1],
                    start=center.add(Vec3(x=16.0 if link[1] > i else -16.0)),
                    finish=Vec3(x=float(link[1]) * 64.0),
                    kind=link[2],
                    time=40 if link[2] == TRAVEL_ROCKETJUMP else 20
                )
            );
        }
    }
    # Node k splits at x = 64 k + 32: in front, the next node; behind, area k.
    normals: list[Vec3] = [Vec3(x=1.0)];
    dists: list[float] = [0.0];
    planes: list[int] = [0];
    front: list[int] = [0];
    back: list[int] = [0];
    for k in range(1, count) {
        normals.append(Vec3(x=1.0));
        dists.append(float(k) * 64.0 + 32.0);
        planes.append(k);
        front.append(k + 1 if k + 1 < count else -count);
        back.append(-k);
    }
    return Aas(normals=normals, dists=dists, node_planes=planes, front=front, back=back, areas=areas, reaches=reaches);
}

