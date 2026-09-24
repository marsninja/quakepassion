import from engine.assets.materials { material_name, model_materials }
import from engine.assets.pk3 { Pk3Assets }
import from engine.formats.animated { stage_frame }

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
        assert material.two_sided and not material.unsupported;
        assert material.stages[0].blend == "add";
    }
    material = model_materials("body { cull back { map body.tga } }")["body"];
    assert not material.two_sided and material.unsupported == ["cull back"];
    material = model_materials("body { cull front { map body.tga } }")["body"];
    assert material.unsupported == ["cull front"];
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
    assert material.stages[0].scroll_u == 7.4 and material.stages[0].scroll_v == 1.3;
}
