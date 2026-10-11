import from editor.assets.shaders {
    ShaderText,
    ShaderStage,
    read_shaders,
    write_shaders,
    directive,
    with_directive,
    shader_named,
    shader_faults
}

glob SCRIPT: str = "// Two shaders.\ntextures/keep/water\n{\n\tqer_editorimage textures/keep/water.tga\n\tsurfaceparm trans // lets light through\n"
    + "\tsurfaceparm water\n\tcull none\n\t{\n\t\tmap textures/keep/water.tga\n\t\tblendFunc GL_DST_COLOR GL_ZERO\n"
    + "\t\ttcMod scroll 0.1 0.05\n\t\ttcMod turb 0 0.2 0 0.1\n\t}\n\t{\n\t\tmap $lightmap\n\t\tblendFunc filter\n\t}\n}\n\n"
    + "textures/keep/glow { { map textures/keep/glow.tga\nrgbGen wave sin 0.5 0.5 0 1 } }\n";

test "a script is read into shaders, their own lines and their stages" {
    read = read_shaders(SCRIPT);
    shaders = read[0];
    assert len(read[1]) == 0 and len(shaders) == 2;
    water = shaders[0];
    assert water.name == "textures/keep/water" and water.line == 2 and len(water.lines) == 4 and len(water.stages) == 2;
    # A comment after a line is not part of it.
    assert water.lines[1] == "surfaceparm trans" and directive(water.lines, "CULL") == "none";
    assert directive(water.lines, "surfaceparm") == "trans" and directive(water.lines, "sort") == "";
    assert water.stages[0].lines[0] == "map textures/keep/water.tga" and len(water.stages[0].lines) == 4;
    assert directive(water.stages[1].lines, "blendfunc") == "filter";
    # Braces on the lines of what they hold are read as well.
    glow = shaders[1];
    assert glow.name == "textures/keep/glow" and len(glow.stages) == 1 and len(glow.stages[0].lines) == 2;
    assert shader_named(shaders, "TEXTURES/keep/glow") is glow and shader_named(shaders, "nothing") is None;
}

test "shaders written as a script read back the same, and are written the same again" {
    shaders = read_shaders(SCRIPT)[0];
    text = write_shaders(shaders);
    assert text.startswith("textures/keep/water\n{\n\tqer_editorimage textures/keep/water.tga\n\tsurfaceparm trans\n");
    assert "\t{\n\t\tmap $lightmap\n\t\tblendFunc filter\n\t}\n}\n" in text;
    again = read_shaders(text);
    assert len(again[1]) == 0 and len(again[0]) == 2 and write_shaders(again[0]) == text;
    assert again[0][0].stages[0].lines == shaders[0].stages[0].lines and again[0][1].stages[0].lines == shaders[1].stages[0].lines;
    assert write_shaders([]) == "";
}

test "a directive is set, changed among several of its kind, and taken out" {
    lines = ["surfaceparm trans", "surfaceparm water", "cull none"];
    assert with_directive(lines, "cull", "back") == ["surfaceparm trans", "surfaceparm water", "cull back"];
    assert with_directive(lines, "sort", "additive") == ["surfaceparm trans", "surfaceparm water", "cull none", "sort additive"];
    assert with_directive(lines, "cull", "") == ["surfaceparm trans", "surfaceparm water"];
    # One of several: the one whose next word matches.
    assert with_directive(lines, "surfaceparm", "", "water") == ["surfaceparm trans", "cull none"];
    assert with_directive(lines, "surfaceparm", "nolightmap", "nolightmap")[-1] == "surfaceparm nolightmap";
    stage = ["map a.tga", "tcMod scroll 1 0", "tcMod turb 0 1 0 1"];
    assert with_directive(stage, "tcMod", "scroll 2 0", "scroll") == ["map a.tga", "tcMod scroll 2 0", "tcMod turb 0 1 0 1"];
    # The lines given are left as they were.
    assert lines == ["surfaceparm trans", "surfaceparm water", "cull none"];
}

test "what is wrong with how a script is put together is said by line" {
    broken = "textures/a\n{\n\t{\n\t\tmap a.tga\n\t}\n\ntextures/b\ntextures/c\n{\n}\n}\n}\n{\n}\n";
    read = read_shaders(broken);
    said = [str(fault.line) + ": " + fault.words for fault in read[1]];
    # b and c are read as lines of a, which was never closed before them; then the braces run out.
    assert len(read[0]) >= 1 and read[0][0].name == "textures/a";
    assert len(said) >= 2 , str(said);
    assert len([each for each in said if "closes that nothing opened" in each]) == 1 , str(said);
    assert len([each for each in said if "no shader's name before it" in each]) == 1 , str(said);
    open_ended = read_shaders("textures/a\n{\n\tcull none\n");
    assert len(open_ended[1]) == 1 and "is not closed" in open_ended[1][0].words and open_ended[1][0].line == 1;
    lonely = read_shaders("textures/a\ntextures/b\n{\n}\n");
    assert len(lonely[1]) == 1 and lonely[1][0].words == "The name textures/a has no braces after it" and lonely[1][0].line == 1;
    assert len(read_shaders("")[0]) == 0 and len(read_shaders("")[1]) == 0;
}

test "what the game would trip on inside a shader is found" {
    shaders = read_shaders(SCRIPT)[0];
    assert shader_faults(shaders[0]) == [] and shader_faults(shaders[1]) == [];
    bad = ShaderText(name="textures/bad", line=7);
    bad.lines = ["cull sideways", "blendFunc add", "glitter 5", "q3map_surfacelight 200", "surfaceparm"];
    bad.stages = [
        ShaderStage(lines=["map a.tga", "blendFunc GL_ONE", "rgbGen rainbow", "cull none"], line=9),
        ShaderStage(lines=["tcMod scroll 1 0"], line=14),
        ShaderStage(lines=["animMap 10 a.tga b.tga", "alphaFunc GE128", "depthFunc equal", "tcGen environment"], line=18)
    ];
    said = [fault.words for fault in shader_faults(bad)];
    assert "textures/bad: cull takes one of: front, back, none, disable, twosided" in said;
    assert "textures/bad: A shader has no blendFunc (that is a line of a stage)" in said;
    assert "textures/bad: A shader has no glitter" in said and "textures/bad: surfaceparm takes one word" in said;
    assert "textures/bad stage 0: blendFunc takes add, filter or blend, or two of the GL_ factors" in said;
    assert "textures/bad stage 0: A stage has no cull (that is a line of the shader itself)" in said;
    assert len([each for each in said if each.startswith("textures/bad stage 0: rgbGen takes one of:")]) == 1;
    assert "textures/bad stage 1 has no picture (map, clampMap, animMap or videoMap)" in said;
    # The third stage is sound, and a line for map tools is none of the game's business.
    assert len([each for each in said if "stage 2" in each]) == 0 and len([each for each in said if "q3map" in each]) == 0;
    assert len(said) == 8;
    lines = [fault.line for fault in shader_faults(bad)];
    assert lines.count(7) == 4 and lines.count(9) == 3 and lines.count(14) == 1;
}
