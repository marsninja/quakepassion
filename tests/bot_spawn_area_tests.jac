"""Q3 bots find their AAS area from where they stand: an origin on the plane
where a grounded area begins is looked up in that area, not the solid below
it or the air above."""
import from engine.formats.aas { Aas, AasArea, AasReach, AREA_GROUNDED }
import from engine.world.bot_routes { NavMesh }
import from engine.math.vec3 { Vec3 }

"""Solid below z=24, a thin grounded area with a way out up to z=26, and air
above it with none (q3dm10's spawn spots sit on such a floor)."""
def floor_aas -> Aas {
    ground = AasArea(
        center=Vec3(z=25.0),
        mins=Vec3(x=-64.0, y=-64.0, z=24.0),
        maxs=Vec3(x=64.0, y=64.0, z=26.0),
        flags=AREA_GROUNDED,
        first_reach=0,
        reach_count=1
    );
    air = AasArea(
        center=Vec3(z=60.0),
        mins=Vec3(x=-64.0, y=-64.0, z=26.0),
        maxs=Vec3(x=64.0, y=64.0, z=96.0)
    );
    return Aas(
        normals=[Vec3(z=1.0), Vec3(z=1.0)],
        dists=[24.0, 26.0],
        node_planes=[0, 0, 1],
        front=[0, 2, -2],
        back=[0, 0, -1],
        areas=[AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3()), ground, air],
        reaches=[AasReach(area=1, start=Vec3(), finish=Vec3(), kind=2, time=0)]
    );
}

test "an origin on the floor plane is in the grounded area" {
    mesh = NavMesh(aas=floor_aas());
    assert mesh.aas.area_at(Vec3(z=24.0)) == 0;
    assert mesh.locate(Vec3(z=24.0)) == 1;
    assert mesh.locate(Vec3(z=25.0)) == 1;
}
