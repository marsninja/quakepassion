import from engine.assets.materials { model_materials }
import from engine.render.quake { fog_density, fog_coords, apply_tcmods }
import from engine.formats.bsp { FogVolume }
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
