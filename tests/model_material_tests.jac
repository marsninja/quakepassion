import from engine.assets.materials { material_name, model_materials }
import io;
import struct;
import from zipfile { ZipFile }
import from engine.assets.pk3 { Pk3Assets }
import from engine.formats.animated {
    ModelStage,
    stage_frame,
    SHADER_CULL_FRONT,
    SHADER_CULL_BACK,
    SHADER_CULL_NONE
}
import from engine.formats.bsp { Texture }
import from engine.render.models { UploadedStage, MODEL_ENTITY_COLOR }
import from engine.render.quake { packed_deforms }

"""An archive of empty images named `images`, with `scripts` parsed."""
def shader_archive(images: list[str], scripts: str) -> Pk3Assets {
    buffer = io.BytesIO();
    with ZipFile(buffer, "w") as packed {
        for name in images {
            packed.writestr(name, b"image");
        }
    }
    assets = Pk3Assets(archives=[ZipFile(buffer)]);
    for name in images {
        assets.owners[name] = 0;
        assets.canonical_names[name.lower()] = name;
    }
    assets.parse_shaders(scripts);
    return assets;
}

"""A stage as the model renderer plans it."""
def planned_stage(stage: ModelStage) -> UploadedStage {
    planned = UploadedStage(texture=1, surface=0, environment=stage.environment, blend=stage.blend, source=stage, cull=stage.cull);
    planned.plan();
    return planned;
}

test "animated material image lists end at the newline and loop by authored frequency" {
    material = model_materials(
        "grenade {\n{ map base.tga }\n{ animMap 7 red.tga green.tga\nblendFunc add\n} }"
    )["grenade"];
    assert not material.unsupported and len(material.stages) == 2;
    stage = material.stages[1];
    assert stage.frequency == 7.0 and stage.blend == "add";
    assert [frame.name for frame in stage.frames] == ["red.tga", "green.tga"];
    assert stage_frame(0.0, 7.0, 2) == 0;
    assert stage_frame(0.2, 7.0, 2) == 1;
    assert stage_frame(0.3, 7.0, 2) == 0;
    assert stage_frame(-0.1, 7.0, 2) == 0;
    assert stage_frame(10.0, 0.0, 1) == 0;
    assert model_materials("bad { { animMap 0 a.tga\n} }")["bad"].unsupported;
}

test "rocket flare materials retain additive blending and two sided culling" {
    for mode in ["none", "disable", "twosided"] {
        material = model_materials(
            "flare { cull " + mode + " { map flare.tga blendFunc GL_ONE GL_ONE } }"
        )["flare"];
        assert material.two_sided and material.cull == SHADER_CULL_NONE and not material.unsupported;
        assert material.stages[0].blend == "add";
    }
    # tr_shader.c ParseShader: back, backside and backsided draw the far side
    # only; any other word is warned about and leaves the shader front-sided.
    for mode in ["back", "backside", "backsided"] {
        material = model_materials("fluid { cull " + mode + " { map fluid.tga } }")["fluid"];
        assert not material.two_sided and material.cull == SHADER_CULL_BACK and not material.unsupported;
    }
    material = model_materials("body { cull front { map body.tga } }")["body"];
    assert material.cull == SHADER_CULL_FRONT and not material.unsupported;
}

test "PK3 image lookup resolves mixed case and extension aliases" {
    assets = Pk3Assets();
    assets.owners = {"textures/Health.JPG": 0};
    assets.canonical_names = {"textures/health.jpg": "textures/Health.JPG"};
    assert assets.image_name("TEXTURES/health.jpg") == "textures/Health.JPG";
    assert assets.image_name("textures/HEALTH.TGA") == "textures/Health.JPG";
    assets.parse_shaders("Models/Health { { map textures/health.jpg } }");
    assert assets.shaders["models/health"] == "textures/health.jpg";
    assert assets.model_shaders["models/health"].stages[0].texture.name
        == "textures/health.jpg";
    assets.close();
    assert not assets.canonical_names;
}


test "model materials preserve environment base then alpha overlay ordering" {
    materials = model_materials(
        "models/armor { { map specular.tga tcGen environment rgbGen identity } { map red.tga blendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA rgbGen identity } }"
    );
    material = materials["models/armor"];
    assert not material.unsupported and len(material.stages) == 2;
    assert material.stages[0].environment and material.stages[0].blend == "opaque";
    assert material.stages[1].texture.name == "red.tga"
        and material.stages[1].blend == "alpha";
    assert material_name("Models/Armor.TGA") == "models/armor";
}

test "model material parser reports unsupported directives and handles archive overrides" {
    archive = Pk3Assets();
    archive.parse_shaders("models/a { { map old.tga tcMod entityTranslate } }");
    assert archive.model_shaders["models/a"].unsupported == ["tcmod entitytranslate"];
    archive.parse_shaders("// override\nmodels/a { { map new.tga blendFunc add } }");
    material = archive.model_shaders["models/a"];
    assert not material.unsupported;
    assert material.stages[0].texture.name == "new.tga"
        and material.stages[0].blend == "add";
    archive.close();
    assert not archive.model_shaders and not archive.shaders;
}

test "scrolling additive energy stages retain independent UV rates" {
    material = model_materials(
        "energy { { map energy.tga blendFunc GL_ONE GL_ONE tcMod scroll 7.4 1.3 } }"
    )["energy"];
    assert not material.unsupported;
    assert material.stages[0].blend == "add";
    mods = material.stages[0].mods;
    assert len(mods) == 1 and mods[0].kind == "scroll" and mods[0].a == 7.4 and mods[0].b == 1.3;
}

test "model shaders keep rotating and turbulent stages instead of falling back" {
    archive = Pk3Assets();
    archive.parse_shaders(
        "powerups/quad { deformVertexes wave 100 sin 3 0 0 0 { map textures/effects/quadmap2.tga blendfunc GL_ONE GL_ONE tcGen environment tcmod rotate 30 tcmod scroll 1 .1 } }\n"
            + "models/flame { { map models/flame.tga blendFunc add tcMod turb 0 0.2 0 1 tcMod scale 2 2 } }"
    );
    assert not archive.model_shaders["models/flame"].unsupported;
    assert [mod.kind for mod in archive.model_shaders["powerups/quad"].stages[0].mods] == ["rotate", "scroll"];
    assert [mod.kind for mod in archive.model_shaders["models/flame"].stages[0].mods] == ["turb", "scale"];
    archive.close();
}

test "explosion shaders keep their waved colours and clamped maps, which models draw" {
    materials = model_materials(
        "plasmaExplosion { cull disable { clampmap models/weaphits/plasmaboom.tga blendfunc add tcMod stretch triangle .6 0.1 0 8 tcmod rotate 999 rgbGen wave inversesawtooth 0 1 0 1.5 } }\n"
            + "railExplosion { cull disable {\n animmap 5 a.tga b.tga\n alphaGen wave inversesawtooth 0 1 0 5\n blendfunc blend\n } }"
    );
    plasma = materials["plasmaexplosion"];
    stage = plasma.stages[0];
    assert plasma.two_sided and stage.clamp and stage.blend == "add";
    assert stage.rgb == "wave" and stage.rgb_wave.func == "inversesawtooth" and stage.rgb_wave.frequency == 1.5;
    assert [mod.kind for mod in stage.mods] == ["stretch", "rotate"];
    rail = materials["railexplosion"].stages[0];
    assert rail.alpha == "wave" and rail.blend == "alpha" and len(rail.frames) == 2 and rail.frequency == 5.0;
    assert not plasma.unsupported and not materials["railexplosion"].unsupported;
    # Half way through its 1.5 Hz inverse sawtooth the plasma burst is at half light.
    assert abs(stage.rgb_wave.at(1.0 / 3.0) - 0.5) < 0.00001;
}

test "model shaders draw lit, alpha-tested, specular, custom-blended and entity-coloured stages" {
    assets = shader_archive(
        ["models/skin.tga", "models/glow.tga", "models/bits.tga"],
        "models/cadaver { { map $whiteimage rgbGen lightingDiffuse } { map models/skin.tga blendFunc GL_DST_COLOR GL_SRC_ALPHA rgbGen identity alphaGen lightingSpecular } }\n"
            + "models/flagbits { cull none { map models/bits.tga alphaFunc GE128 rgbGen lightingDiffuse depthWrite } }\n"
            + "models/railgun2 { sort additive cull disable { map models/glow.tga blendfunc GL_ONE GL_ONE rgbGen entity } }\n"
            + "models/fluid { cull back { map models/glow.tga tcMod scroll 0 2 blendfunc GL_ONE GL_ONE } }\n"
            + "models/veil { { map models/bits.tga blendFunc blend alphaFunc GT0 depthWrite alphaGen oneMinusEntity } }"
    );
    # $whiteimage lit by the light grid, then the skin multiplied in with
    # its shine in alpha (GL_DST_COLOR GL_SRC_ALPHA).
    cadaver = [planned_stage(stage) for stage in assets.model_stages("models/cadaver.tga")];
    assert len(cadaver) == 2;
    assert cadaver[0].source.texture.pixels == b"\xff\xff\xff\xff" and cadaver[0].lit and not cadaver[0].blended and cadaver[0].depth_write;
    assert cadaver[1].blended and (cadaver[1].gl_source, cadaver[1].gl_destination) == (774, 770);
    assert not cadaver[1].lit and not cadaver[1].depth_write;
    assert struct.unpack("<ffff", cadaver[1].gen) == (1.0, 0.0, 0.0, 0.0);
    assert struct.unpack("<ffff", cadaver[0].gen) == (0.0, 0.0, 0.0, 0.0);
    # alphaFunc and depthWrite on a two-sided, lit stage.
    bits = planned_stage(assets.model_stages("models/flagbits")[0]);
    assert bits.cull == SHADER_CULL_NONE and bits.lit and bits.depth_write and not bits.blended;
    assert struct.unpack("<ffff", bits.gen) == (0.0, 2.0, 0.0, 0.0);
    # rgbGen entity: the drawn entity's shaderRGBA, black unless it is set.
    glow = planned_stage(assets.model_stages("models/railgun2")[0]);
    assert glow.blended and (glow.gl_source, glow.gl_destination) == (1, 1) and not glow.depth_write and not glow.fixed_tint;
    assert struct.unpack("<ffff", glow.tint(0.0, MODEL_ENTITY_COLOR)) == (0.0, 0.0, 0.0, 1.0);
    assert struct.unpack("<ffff", glow.tint(0.0, [1.0, 0.0, 0.5, 0.0])) == (1.0, 0.0, 0.5, 1.0);
    # cull back draws the far side; its colour never changes.
    fluid = planned_stage(assets.model_stages("models/fluid")[0]);
    assert fluid.cull == SHADER_CULL_BACK and fluid.fixed_tint == struct.pack("<ffff", 1.0, 1.0, 1.0, 1.0);
    # A blended stage writes depth only with depthWrite; alphaGen oneMinusEntity.
    veil = planned_stage(assets.model_stages("models/veil")[0]);
    assert veil.blended and veil.depth_write and (veil.gl_source, veil.gl_destination) == (770, 771);
    assert struct.unpack("<ffff", veil.gen) == (0.0, 1.0, 0.0, 0.0);
    assert struct.unpack("<ffff", veil.tint(0.0, [0.0, 0.0, 0.0, 0.25])) == (1.0, 1.0, 1.0, 0.75);
    assets.close();
}

test "a skin without a script is lit and a script without stages hides its surface" {
    plain = planned_stage(ModelStage(texture=Texture(name="skin"), rgb="diffuse"));
    assert plain.lit and not plain.blended and plain.depth_write and plain.cull == SHADER_CULL_FRONT;
    # Stages without rgbGen are full bright (CGEN_IDENTITY_LIGHTING), not lit.
    assert not planned_stage(ModelStage(texture=Texture(name="skin"))).lit;
    assets = shader_archive(
        ["models/h.tga"],
        "models/harpy_f { surfaceparm nodraw }\nmodels/harpy_h { { map models/h.tga rgbGen lightingDiffuse } }"
    );
    assert assets.model_hidden("models/harpy_f.tga") and not assets.model_stages("models/harpy_f.tga");
    assert not assets.model_hidden("models/harpy_h") and not assets.model_hidden("models/unscripted");
    assert assets.model_stages("models/harpy_h")[0].rgb == "diffuse";
    assets.close();
}

test "model shaders carry their deformVertexes, normal included, to every stage" {
    assets = shader_archive(
        ["models/flag.tga", "models/fx.tga"],
        "models/flag { deformVertexes wave 100 sin 4 3 0 0.3\ndeformVertexes normal .3 .2\ncull none { map models/flag.tga rgbGen identity } { map models/fx.tga tcGen environment blendFunc GL_ONE GL_ONE } }\n"
            + "models/bfg01 { cull none deformVertexes autoSprite { clampmap models/fx.tga blendFunc GL_ONE GL_ONE } }\n"
            + "models/holo { deformVertexes move 0 0 .7 sin 0 5 0 0.2 { map models/flag.tga } }"
    );
    stages = assets.model_stages("models/flag");
    assert len(stages) == 2 and not assets.model_blockers("models/flag");
    for stage in stages {
        assert [deform.kind for deform in stage.deforms] == ["wave", "normal"];
    }
    normal = stages[0].deforms[1];
    assert normal.wave.amplitude == 0.3 and normal.wave.frequency == 0.2;
    # Packed for the shared deform shader: kind 6, the amplitude and frequency
    # where the wave's are.
    packed = packed_deforms(stages[0].deforms, 0.0);
    assert struct.unpack("<ffffffff", packed[0])[0] == 1.0 and struct.unpack("<ffffffff", packed[0])[4] == 6.0;
    waves = struct.unpack("<ffffffff", packed[1]);
    assert abs(waves[5] - 0.3) < 0.00001 and abs(waves[7] - 0.2) < 0.00001;
    # A static shader's deforms are packed once; a move's follow time.
    assert planned_stage(stages[0]).deform_values == packed;
    assert [deform.kind for deform in assets.model_stages("models/bfg01")[0].deforms] == ["autosprite"];
    holo = planned_stage(assets.model_stages("models/holo")[0]);
    assert not holo.deform_values and holo.source.deforms[0].kind == "move";
    quarter = struct.unpack("<ffff", packed_deforms(holo.source.deforms, 1.25)[2]);
    assert abs(quarter[2] - 0.7 * 5.0) < 0.0001 and quarter[0] == 0.0;
    assets.close();
}

test "a shader with a directive the parser does not know keeps the plain skin" {
    assets = shader_archive(["models/a.tga"], "models/a { { map models/a.tga tcMod entityTranslate } }");
    assert assets.model_shaders["models/a"].unsupported == ["tcmod entitytranslate"];
    assert not assets.model_stages("models/a") and not assets.model_hidden("models/a");
    assets.close();
}
