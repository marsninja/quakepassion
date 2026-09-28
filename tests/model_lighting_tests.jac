"""Q1/Q2 model lighting from the world's lightmaps (R_LightPoint), the
per-game shading rules, vertex normals, fullbright skins and baked brush
pickups."""
import math;
import struct;
import from engine.world.lighting {
    Lighting,
    Illumination,
    LightSpot,
    FlashLight,
    MODEL_LIGHT_VIEW,
    MODEL_LIGHT_MINLIGHT,
    MODEL_LIGHT_FULLBRIGHT,
    MODEL_LIGHT_GLOW,
    QUAKE2_SHADE_REAR
}
import from engine.world.level { Split, BspArea, Front, Back, BspLightPoint }
import from engine.formats.bsp { Bsp, Face, TexInfo }
import from engine.formats.anorms { quake_vertex_normal }
import from engine.formats.animated { frame_normals }
import from engine.formats.q1.model { parse_mdl }
import from engine.formats.q2.model { parse_md2 }
import from engine.formats.q1.item_model { item_light_at }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

"""A floor at z = 0 on one node: 32 units square, a 3x3 lightmap in two
style layers (0 and 2), under empty space and over solid."""
def floor_source(tiled: bool = False, channels: int = 1) -> BspLightPoint {
    face = Face(
        texinfo=TexInfo(s=Vec3(x=1.0), t=Vec3(y=1.0), soff=0.0, toff=0.0, texture=0, flags=0),
        tiled=tiled,
        light_offset=0,
        light_width=3,
        light_height=3,
        styles=[0, 2]
    );
    layer = [10, 20, 30, 40, 50, 60, 70, 80, 90];
    second = [100, 100, 100, 100, 100, 100, 100, 100, 100];
    data: list[int] = [];
    for value in layer + second {
        data.extend([value] * channels if channels == 3 else [value]);
    }
    if channels == 3 {
        # Colour the first layer: red full, green half, blue none.
        for i in range(9) {
            data[i * 3 + 1] = layer[i] // 2;
            data[i * 3 + 2] = 0;
        }
    }
    split = Split(normal=Vec3(z=1.0), distance=0.0, first_face=0, face_count=1);
    box = AABB(mins=Vec3(), maxs=Vec3());
    split +>:Front:+> BspArea(name="air", bounds=box, index=0);
    split +>:Back:+> BspArea(name="solid", bounds=box, index=1);
    return BspLightPoint(faces=[face], lightmaps=bytes(data), channels=channels, head=split);
}

test "R_LightPoint finds the lightmap sample straight below and sums its styles" {
    source = floor_source();
    # (20, 5): s 20 and t 5 are in sample column 1, row 0.
    spot = source.spot(Vec3(x=20.0, y=5.0, z=40.0));
    assert spot.face == 0 and spot.sample == 1;
    light = source.light(Vec3(x=20.0, y=5.0, z=40.0), {0: 1.0, 2: 0.5});
    assert light is not None and light.x == 20.0 + 50.0;
    # Row 2, column 2 at the far edge (s 33 lies past the 32-unit extent).
    assert source.spot(Vec3(x=32.0, y=32.0, z=8.0)).sample == 8;
    assert source.light(Vec3(x=33.0, y=5.0, z=8.0), {}) is None;
    # A point already below the floor traces nothing lit.
    assert source.light(Vec3(x=20.0, y=5.0, z=-4.0), {}) is None;
    # Liquids and sky have no lightmap: the trace passes through them.
    assert floor_source(True).light(Vec3(x=20.0, y=5.0, z=40.0), {}) is None;
}

test "Q1 models take R_AliasSetupLighting's clamped ambient and shade light" {
    lighting = Lighting(game="q1", point=floor_source(), styles={0: 1.0, 2: 0.0});
    scale = 2.0 / 255.0;
    # Sample 70 (row 2, column 0): ambient and shade both 70.
    lit = lighting.light_model(Vec3(x=5.0, y=40.0 - 8.0, z=30.0));
    assert lit.enabled and abs(lit.ambient.x - 70.0 * scale) < 0.00001;
    assert abs(lit.directed.x - 70.0 * scale) < 0.00001;
    # The shade light comes from lightvec (-1, 0, 0): faces toward +x.
    assert lit.direction.x == 1.0 and lit.rear == 0.0 and not lit.model_space;
    assert lit.shade(Vec3(x=-1.0)).x == lit.ambient.x;
    # Bright: ambient held to 128, the two together to 192.
    lighting.styles = {0: 1.0, 2: 2.0};
    bright = lighting.light_model(Vec3(x=5.0, y=40.0 - 8.0, z=30.0));
    assert abs(bright.ambient.x - 128.0 * scale) < 0.00001;
    assert abs(bright.directed.x - 64.0 * scale) < 0.00001;
    # Model light is held while the styles and dynamic lights stand.
    assert lighting.light_model(Vec3(x=5.0, y=40.0 - 8.0, z=30.0)) is bright;
    # Dark: never below LIGHT_MIN, but the gun is lit at least 24.
    lighting.styles = {0: 0.0, 2: 0.0};
    dark = lighting.light_model(Vec3(x=5.0, y=5.0, z=30.0));
    assert abs(dark.ambient.x - 5.0 * scale) < 0.00001 and dark.directed.x == 0.0;
    gun = lighting.light_model(Vec3(x=5.0, y=5.0, z=30.0), 0.0, MODEL_LIGHT_VIEW);
    assert abs(gun.ambient.x - 24.0 * scale) < 0.00001 and abs(gun.directed.x - 24.0 * scale) < 0.00001;
    # A dynamic light adds its radius less its distance to the ambient light.
    lighting.dynamic = [FlashLight(origin=Vec3(x=5.0, y=5.0, z=130.0), color=Vec3(x=1.0, y=1.0, z=1.0), radius=150.0)];
    flashed = lighting.light_model(Vec3(x=5.0, y=5.0, z=30.0));
    assert abs(flashed.ambient.x - 50.0 * scale) < 0.00001 and flashed.directed.x == 0.0;
    # A map without light data lights everything fully (255: clamped).
    unlit = Lighting(game="q1", point=BspLightPoint()).light_model(Vec3());
    assert abs(unlit.ambient.x - 128.0 * scale) < 0.00001 and abs(unlit.directed.x - 64.0 * scale) < 0.00001;
}

test "Q2 models take coloured light, render flags and shadedots by yaw" {
    lighting = Lighting(game="q2", point=floor_source(channels=3), styles={0: 1.0, 2: 0.0});
    at = Vec3(x=20.0, y=5.0, z=40.0);
    lit = lighting.light_model(at);
    # Sample 20 in the first layer: red 20, green 10, blue 0, over 255, doubled.
    assert abs(lit.ambient.x - 40.0 / 255.0) < 0.00001 and abs(lit.ambient.y - 20.0 / 255.0) < 0.00001;
    assert lit.ambient.z == 0.0 and lit.directed.x == lit.ambient.x;
    assert lit.rear == QUAKE2_SHADE_REAR and lit.model_space;
    # Yaw 0 uses shadedots row 0: the shade vector (1, 0, 1) normalised.
    assert abs(lit.direction.x - math.sqrt(0.5)) < 0.00001 and abs(lit.direction.z - math.sqrt(0.5)) < 0.00001;
    # 30 degrees is row 1 (22.5 degrees); -30 wraps to row 15.
    turned = lighting.light_model(at, 30.0);
    assert abs(turned.direction.y - math.sin(-math.pi / 8.0) / math.sqrt(2.0)) < 0.00001;
    back = lighting.light_model(at, -30.0);
    assert abs(back.direction.y - math.sin(-15.0 * math.pi / 8.0) / math.sqrt(2.0)) < 0.00001;
    # shadedots: facing the vector doubles the light, facing away keeps
    # 1 - 13/44 of it.
    assert abs(lit.shade(lit.direction).x - 2.0 * lit.ambient.x) < 0.00001;
    assert abs(lit.shade(lit.direction.scale(-1.0)).x - lit.ambient.x * (1.0 - 13.0 / 44.0)) < 0.00001;
    # RF_FULLBRIGHT is full light; RF_MINLIGHT keeps at least 0.1.
    assert lighting.light_model(at, 0.0, MODEL_LIGHT_FULLBRIGHT).ambient.x == 2.0;
    lighting.styles = {0: 0.0, 2: 0.0};
    assert lighting.light_model(at).ambient.x == 0.0;
    assert abs(lighting.light_model(at, 0.0, MODEL_LIGHT_MINLIGHT).ambient.y - 0.2) < 0.00001;
    assert abs(lighting.light_model(at, 0.0, MODEL_LIGHT_VIEW).ambient.z - 0.2) < 0.00001;
    # RF_GLOW: 0.1 sin(7t), never below 80%.
    lighting.styles = {0: 0.0, 2: 1.0};
    base = lighting.light_model(at).ambient.x / 2.0;
    glowing = lighting.light_model(at, 0.0, MODEL_LIGHT_GLOW);
    assert glowing.glow and not lighting.light_model(at).glow;
    peak = glowing.at(math.pi / 14.0).ambient.x / 2.0;
    trough = glowing.at(3.0 * math.pi / 14.0).ambient.x / 2.0;
    assert abs(peak - (base + 0.1)) < 0.00001 and abs(trough - max(base * 0.8, base - 0.1)) < 0.00001;
    # A dynamic light adds (intensity - distance) / 256 of its colour.
    lighting.dynamic = [FlashLight(origin=at.add(Vec3(z=72.0)), color=Vec3(x=1.0), radius=200.0)];
    flashed = lighting.light_model(at);
    assert abs(flashed.ambient.x / 2.0 - (base + 128.0 / 256.0)) < 0.00001;
    assert abs(flashed.ambient.y / 2.0 - base) < 0.00001;
}

test "Q3 dynamic lights add directed light and turn it toward them" {
    import from engine.world.lighting { load_light_grid }
    data: list[int] = [];
    for spot in range(8) {
        data.extend([20, 20, 20, 40, 40, 40, 0, 0]);
    }
    grid = load_light_grid(bytes(data), Vec3(), Vec3(x=64.0, y=64.0, z=128.0));
    lighting = Lighting(grid=grid);
    point = Vec3(x=32.0, y=32.0, z=64.0);
    plain = lighting.sample(point);
    lighting.dynamic = [FlashLight(origin=point.add(Vec3(x=64.0)), color=Vec3(x=1.0), radius=300.0)];
    flashed = lighting.sample(point);
    # DLIGHT_AT_RADIUS 16 * 300^2 / 64^2 of red.
    assert abs((flashed.directed.x - plain.directed.x) * 255.0 - 16.0 * 90000.0 / 4096.0) < 0.01;
    assert flashed.directed.y == plain.directed.y and flashed.ambient.x == plain.ambient.x;
    assert flashed.direction.x > 0.5;
    assert lighting.sample(point, False).directed.x == plain.directed.x;
}

test "MDL and MD2 frames carry their anorms vertex normals" {
    header = b"IDPO" + struct.pack("<i10f8if", 6, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1, 2, 1, 3, 1, 1, 0, 0, 1.0);
    # One 2x1 skin: an ordinary colour and a fullbright one.
    skins = struct.pack("<i", 0) + bytes([7, 230]);
    coords = struct.pack("<9i", 0, 0, 0, 0, 1, 0, 0, 1, 0);
    triangle = struct.pack("<4i", 1, 0, 1, 2);
    frame = struct.pack("<i", 0) + bytes(8) + b"idle" + bytes(12) + bytes([0, 0, 0, 5, 2, 0, 0, 161, 0, 2, 0, 6]);
    palette = bytes([(i * 3 + c) % 256 for i in range(256) for c in range(3)]);
    model = parse_mdl(header + skins + coords + triangle + frame, palette);
    normals = frame_normals(model.surfaces[0].frames[0]);
    assert len(normals) == 3 and normals[0].x == quake_vertex_normal(5).x and normals[1].z == quake_vertex_normal(161).z;
    assert abs(normals[2].length() - 1.0) < 0.001;
    # The colormap leaves indices 224-255 unlit: alpha 0 marks them.
    skin = model.surfaces[0].embedded_skins[0];
    assert skin.fullbright and skin.pixels[3] == 255 and skin.pixels[7] == 0;
    assert skin.pixels[4] == 230 * 3 % 256;
    md2 = b"IDP2" + struct.pack("<16i", 8, 8, 8, 52, 1, 3, 3, 1, 0, 1, 68, 132, 144, 156, 208, 208)
        + b"skin.pcx" + bytes(56) + struct.pack("<6h", 0, 0, 7, 0, 0, 7) + struct.pack("<6H", 0, 1, 2, 2, 0, 1)
        + struct.pack("<6f", 1.0, 1.0, 1.0, 0.0, 0.0, 0.0) + b"first" + bytes(11)
        + bytes([0, 0, 0, 9, 2, 0, 0, 20, 0, 2, 0, 200]);
    frames = parse_md2(md2).surfaces[0].frames;
    assert frames[0].normal_indices == bytes([9, 20, 200]) and not frames[0].normals;
    md2_normals = frame_normals(frames[0]);
    assert md2_normals[0].y == quake_vertex_normal(9).y and md2_normals[1].x == quake_vertex_normal(20).x;
    # Past the table (corrupt files) there is no normal.
    assert md2_normals[2].length() == 0.0;
}

test "Q1 brush pickups bake their own lightmaps between samples" {
    bsp = Bsp(lighting=bytes([0, 64, 128, 192, 0, 64, 128, 192]));
    face = Face(light_offset=0, light_width=2, light_height=2, light_s=0, light_t=0, styles=[0, 1]);
    # Halfway between columns 0 and 1 on row 0: 32, in both layers, at 'm'.
    assert abs(item_light_at(bsp, face, 8.0, 0.0) - 2.0 * 32.0 * 264.0 / 256.0) < 0.001;
    # Past the last sample it holds the edge.
    assert abs(item_light_at(bsp, face, 40.0, 40.0) - 2.0 * 192.0 * 264.0 / 256.0) < 0.001;
    assert item_light_at(bsp, Face(), 0.0, 0.0) == 0.0;
}
