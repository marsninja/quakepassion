import from engine.assets.materials { model_materials }
import from engine.render.quake { fog_density, fog_coords, apply_tcmods, fog_adjustment, stage_affine }
import from engine.formats.bsp { FogVolume }
import from engine.render.models { model_fog }
import from engine.math.vec3 { Vec3 }

test "Q3 fog shaders, density and coordinates follow the original renderer" {
    shaders = model_materials("textures/sfx/q3dm9fog\n{\n surfaceparm fog\n fogparms ( .6 .1 .05 ) 384\n}\ntextures/sfx/tight\n{\n fogParms (0.2 0.3 0.4) 0\n}\n");
    lava = shaders["textures/sfx/q3dm9fog"];
    assert lava.fog and abs(lava.fog_color.x - 0.6) < 0.0001 and lava.fog_depth == 384.0;
    # A zero distance is clamped to one, as R_LoadFogs does.
    assert shaders["textures/sfx/tight"].fog and shaders["textures/sfx/tight"].fog_depth == 1.0;
    # R_FogFactor: nothing before the bias or outside t's band, full at 1/8 of s.
    assert fog_density(0.001, 0.9) == 0.0 and fog_density(0.5, 0.01) == 0.0;
    assert fog_density(0.2, 0.99) == 1.0;
    assert abs(fog_density(1.0 / 512.0 + 1.0 / 32.0, 0.99) - 0.5) < 0.02;
    # A pool of fog below z=0: the visible surface faces up, its normal into the fog is -z.
    fog = FogVolume(mins=Vec3(z=-256.0), maxs=Vec3(x=512.0, y=512.0), has_surface=True, inward=Vec3(z=-1.0), offset=0.0, depth=256.0);
    forward = Vec3(z=-1.0);
    eye = Vec3(z=100.0);
    # From outside: a point 100 below the surface is half-way through the depth
    # from the eye, so t keeps 30/32 of that fraction.
    st = fog_coords(fog, Vec3(z=-100.0), eye, forward);
    assert abs(st[0] - (200.0 / 2048.0 + 1.0 / 512.0)) < 0.0001;
    assert abs(st[1] - (1.0 / 32.0 + 30.0 / 32.0 * 0.5)) < 0.0001;
    # Above the fog surface nothing is fogged.
    assert fog_coords(fog, Vec3(z=0.5), eye, forward)[1] == 1.0 / 32.0;
    # From inside, anything in the fog gets the full t.
    assert fog_coords(fog, Vec3(z=-200.0), Vec3(z=-50.0), forward)[1] == 31.0 / 32.0;
    # adjustColorsForFog only for translucent shaders, by blend.
    glow = model_materials("a\n{\n { map a.tga\n blendfunc add\n }\n { map b.tga\n blendfunc blend\n }\n { map c.tga\n blendfunc gl_one gl_one_minus_src_alpha\n }\n}\nb\n{\n { map a.tga\n }\n { map b.tga\n blendfunc add\n }\n}\n");
    lit = glow["a"].stages;
    assert fog_adjustment(lit[0], lit[0]) == 1 and fog_adjustment(lit[0], lit[1]) == 2 and fog_adjustment(lit[0], lit[2]) == 3;
    solid = glow["b"].stages;
    assert fog_adjustment(solid[0], solid[1]) == 0;
    # R_ComputeFogNum: a model whose bounding sphere dips into the fog is fogged.
    assert model_fog([fog], Vec3(x=100.0, y=100.0, z=20.0), 30.0) is fog;
    assert model_fog([fog], Vec3(x=100.0, y=100.0, z=40.0), 30.0) is None;
}

test "tcMod transform and tcGen vector follow tr_shade_calc.c" {
    shaders = model_materials("textures/liquids/calm_pool\n{\n {\n map textures/liquids/pool3d_5c.tga\n tcmod transform 1.5 0 1.5 1 1 2\n }\n {\n map textures/liquids/pool3d_6c.tga\n tcGen vector ( 0.01 0 0 ) (0 0.02 0)\n }\n}\n");
    pool = shaders["textures/liquids/calm_pool"];
    stage = pool.stages[0];
    assert stage.mods[0].kind == "transform" and stage.mods[0].matrix == [1.5, 0.0, 1.5, 1.0, 1.0, 2.0];
    # s' = s*m00 + t*m10 + t0, t' = s*m01 + t*m11 + t1.
    st = apply_tcmods(stage, 0.5, 0.25, Vec3(), 0.0);
    assert abs(st[0] - (0.75 + 0.375 + 1.0)) < 0.0001 and abs(st[1] - (0.0 + 0.25 + 2.0)) < 0.0001;
    vectors = pool.stages[1].vectors;
    assert len(vectors) == 2 and vectors[0].x == 0.01 and vectors[1].y == 0.02;
    assert "tcgen vector" not in pool.unsupported and "tcmod transform" not in pool.unsupported;
}

test "folded tcMods match applying them one by one" {
    shaders = model_materials("x\n{\n {\n map a.tga\n tcMod scroll 0.3 -0.2\n tcMod scale 2 0.5\n tcMod rotate 45\n tcMod stretch sin 1 0.25 0 0.5\n tcMod transform 1.5 0 1.5 1 1 2\n }\n {\n map b.tga\n tcMod turb 0 0.25 0 0.05\n }\n}\n");
    chain = shaders["x"].stages[0];
    for seconds in [0.0, 0.7, 3.2] {
        m = stage_affine(chain, seconds);
        assert len(m) == 6;
        for point in [[0.0, 0.0], [0.25, 0.75], [1.5, -2.0]] {
            expected = apply_tcmods(chain, point[0], point[1], Vec3(), seconds);
            s = m[0] * point[0] + m[1] * point[1] + m[2];
            t = m[3] * point[0] + m[4] * point[1] + m[5];
            assert abs(s - expected[0]) < 0.0001 and abs(t - expected[1]) < 0.0001;
        }
    }
    # Turbulence depends on the vertex, so it keeps the per-vertex path.
    assert stage_affine(shaders["x"].stages[1], 1.0) == [];
}
