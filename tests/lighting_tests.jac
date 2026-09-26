import from engine.world.lighting {
    Lamp,
    Lighting,
    ProbeRegion,
    Illumination,
    irradiance,
    LightGrid,
    load_light_grid,
    shift_light
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

test "Q3 models take the light grid, shifted for overbright, around walls" {
    # A 2x2x2 lattice over a 64x64x128 cell: the lower four points lit, the
    # upper four inside walls (black).
    data: list[int] = [];
    for spot in range(8) {
        if spot < 4 {
            # Ambient 20, directed 40 (red only), light from straight above
            # (longitude 0).
            data.extend([20, 20, 20, 40, 0, 0, 0, 0]);
        } else {
            data.extend([0, 0, 0, 0, 0, 0, 0, 0]);
        }
    }
    grid = load_light_grid(bytes(data), Vec3(x=0.0, y=0.0, z=0.0), Vec3(x=64.0, y=64.0, z=128.0));
    assert grid is not None and grid.bounds == [2, 2, 2];
    # R_ColorShiftLightingBytes: four times brighter, whole colours scaled back.
    assert shift_light(True, 20, 40, 100) == (51, 102, 255);
    assert shift_light(False, 20, 40, 200) == (40, 80, 255);
    lit = grid.sample(Vec3(x=32.0, y=32.0, z=64.0));
    assert lit.enabled;
    # Ambient 80 scaled by 0.6 plus the minimum 32; the wall points are
    # left out rather than darkening the blend.
    assert abs(lit.ambient.x * 255.0 - 80.0) < 0.01;
    assert abs(lit.directed.x * 255.0 - 160.0) < 0.01 and lit.directed.y == 0.0;
    assert lit.direction.z > 0.99;
    # Lit from above: a face turned up takes the directed light, one turned
    # down only the ambient.
    assert lit.shade(Vec3(z=1.0)).x > lit.shade(Vec3(z=-1.0)).x;
    # A lump that does not fit the lattice leaves models without the grid.
    assert load_light_grid(bytes([1, 2, 3]), Vec3(), Vec3(x=64.0, y=64.0, z=128.0)) is None;
    lighting = Lighting(grid=grid);
    assert lighting.sample(Vec3(x=10.0, y=10.0, z=10.0)).enabled;
    assert not Lighting().sample(Vec3()).enabled;
}
