import from engine.world.lighting {
    Lamp,
    Lighting,
    ProbeRegion,
    Illumination,
    irradiance
}
import from engine.math.vec3 { Vec3 }
import from engine.physics.collision { CollisionMap }
import from games.passion.lighting { pack_probes, unpack_probes }

test "baked lighting respects blockers surface normals and light color" {
    collision = CollisionMap();
    lamp = Lamp(origin=Vec3(z=100.0), color=Vec3(x=1.0, y=0.5, z=0.25));
    lit = irradiance(Vec3(), Vec3(z=1.0), [lamp], collision, []);
    assert lit.directed.x > lit.directed.y and lit.directed.y > lit.directed.z;
    back = irradiance(Vec3(), Vec3(z=-1.0), [lamp], collision, []);
    assert back.directed.length() == 0.0;
    collision.add_box(
        Vec3(x=-20.0, y=-20.0, z=40.0),
        Vec3(x=20.0, y=20.0, z=60.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    shadow = irradiance(Vec3(), Vec3(z=1.0), [lamp], collision, []);
    assert shadow.directed.length() == 0.0;
    assert shadow.ambient.x > 0.0;
    assert irradiance(Vec3(), Vec3(z=1.0), [lamp], collision, [0]).directed.x
        == lit.directed.x;
}

test "probe interpolation is continuous and ignores solid samples" {
    region = ProbeRegion(origin=Vec3());
    for i in range(64) {
        region.samples.append(Illumination(ambient=Vec3(x=float(i % 4))));
        region.valid.append(True);
    }
    assert abs(region.sample(Vec3(x=80.0)).ambient.x - 0.5) < 0.00001;
    region.valid[0] = False;
    assert abs(region.sample(Vec3(x=80.0)).ambient.x - 1.0) < 0.00001;
    region.valid = [False for i in range(64)];
    assert region.sample(Vec3()).ambient.x == 0.12;
}

test "probe caches round trip and reject malformed values" {
    lighting = Lighting();
    for room in range(20) {
        region = ProbeRegion(origin=Vec3());
        for i in range(64) {
            region.samples.append(Illumination(ambient=Vec3(x=0.25, y=0.5, z=0.75)));
            region.valid.append(i % 2 == 0);
        }
        lighting.regions.append(region);
    }
    data = pack_probes(lighting);
    unpack_probes(data, lighting);
    assert lighting.regions[19].samples[63].ambient.z == 0.75;
    assert lighting.regions[0].valid[0] and not lighting.regions[0].valid[1];
    rejected = False;
    try {
        unpack_probes(data[:-1], lighting);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
    rejected = False;
    try {
        unpack_probes(b"\x02" + data[1:], lighting);
    } except ValueError {
        rejected = True;
    }
    assert rejected;
}

test "moving geometry can sample static probes without double counting flashes" {
    import from engine.world.lighting { FlashLight }
    lighting = Lighting();
    for room in range(20) {
        region = ProbeRegion(origin=Vec3());
        region.samples = [Illumination(ambient=Vec3(x=0.25)) for i in range(64)];
        region.valid = [True for i in range(64)];
        lighting.regions.append(region);
    }
    lighting.dynamic.append(FlashLight(origin=Vec3(), color=Vec3(x=1.0)));
    assert lighting.sample(Vec3(), False).ambient.x == 0.25;
    assert lighting.sample(Vec3()).ambient.x == 1.25;
}
