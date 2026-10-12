import from editor.assets.shaders { ShaderText, ShaderStage, read_shaders }
import from editor.assets.shadertext { script_shown, script_faults, script_sound, shader_brief }

glob WALL: str = "textures/try/wall\n{\n    surfaceparm nodraw\n    {\n        map $lightmap\n        rgbGen identity\n    }\n    {\n        map textures/try/wall.tga\n        blendFunc filter\n    }\n}";

test "a script is shown as it is saved, with spaces for tabs and no empty end" {
    shaders = [
        ShaderText(
            name="textures/try/wall",
            lines=["surfaceparm nodraw"],
            stages=[
                ShaderStage(lines=["map $lightmap", "rgbGen identity"]),
                ShaderStage(lines=["map textures/try/wall.tga", "blendFunc filter"])
            ]
        )
    ];
    assert script_shown(shaders) == WALL;
    # What is shown reads back as the same shaders.
    again = read_shaders(script_shown(shaders));
    assert len(again[1]) == 0 and len(again[0]) == 1 and again[0][0].stages[1].lines == ["map textures/try/wall.tga", "blendFunc filter"];
    assert script_shown([]) == "";
}

test "a sound script has no faults, and a line the game does not know is said at its own line" {
    assert script_faults(WALL) == [] and script_sound(WALL);
    wrong = WALL.replace("rgbGen identity", "rgbGen identity\n        shine brightly");
    found = script_faults(wrong);
    assert len(found) == 1 and found[0].line == 7 and found[0].words.startswith("textures/try/wall: ");
    assert script_sound(wrong);
}

test "braces that do not match are said first by line, and the text is not sound" {
    open_ended = "textures/try/wall\n{\n    {\n        map $lightmap\n";
    found = script_faults(open_ended);
    assert not script_sound(open_ended) and len(found) == 1 and found[0].line == 1 and "not closed" in found[0].words;
    nameless = "{\n}\n";
    assert not script_sound(nameless) and script_faults(nameless)[0].line == 1;
}

test "a stage with no picture is said where it opens, in the order of the lines" {
    bare = "a\n{\n    cull sideways\n    {\n        rgbGen identity\n    }\n}";
    found = script_faults(bare);
    assert [fault.line for fault in found] == [3, 4];
    assert "cull" in found[0].words and found[1].words.endswith("has no picture (map, clampMap, animMap or videoMap)");
}

test "a shader in brief names each stage's picture and how it is laid on" {
    read = read_shaders(WALL);
    assert shader_brief(read[0][0]) == [
        "textures/try/wall", "1 line of its own", "stage 0: $lightmap", "stage 1: textures/try/wall.tga (filter)"
    ];
}
