import from engine.assets.materials { material_name, model_materials }
import from engine.assets.pk3 { Pk3Assets }

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
    archive.parse_shaders("models/a { { map old.tga tcMod rotate 30 } }");
    assert archive.model_shaders["models/a"].unsupported == ["tcmod"];
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
