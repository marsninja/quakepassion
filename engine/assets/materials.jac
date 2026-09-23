"""Initial ordered Q3 model shader stages; archive/image resolution stays separate."""
import from ..formats.animated { ModelStage, ShaderWave, TexMod, Deform }
import from ..math.vec3 { Vec3 }
import from ..formats.bsp { Texture }

obj ModelMaterial {
    has stages: list[ModelStage] = [],
        two_sided: bool = False,
        unsupported: list[str] = [],
        advanced: list[str] = [],
        sky: bool = False,
        farbox: str = "",
        cloud_height: float = 128.0,
        deforms: list[Deform] = [];
}

def number_at(tokens: list[str], i: int) -> float {
    if i >= len(tokens) {
        return 0.0;
    }
    try {
        return float(tokens[i]);
    } except ValueError {
        return 0.0;
    }
}

"""A wave's func base amplitude phase frequency, starting at token i."""
def wave_at(tokens: list[str], i: int) -> ShaderWave {
    return ShaderWave(
        func=tokens[i].lower() if i < len(tokens) else "sin",
        base=number_at(tokens, i + 1),
        amplitude=number_at(tokens, i + 2),
        phase=number_at(tokens, i + 3),
        frequency=number_at(tokens, i + 4)
    );
}

"""GL blend factor names in their canonical spelling."""
def blend_factors(source: str, destination: str) -> str {
    if source == "gl_one" and destination == "gl_zero" {
        return "opaque";
    }
    if source == "gl_one" and destination == "gl_one" {
        return "add";
    }
    if source == "gl_src_alpha" and destination == "gl_one_minus_src_alpha" {
        return "alpha";
    }
    if (source == "gl_dst_color" and destination == "gl_zero")
        or (source == "gl_zero" and destination == "gl_src_color") {
        return "multiply";
    }
    return "custom";
}

"""Parse one stage keyword starting at token i; returns the index of its last
argument. Features the model renderer cannot draw are listed as advanced so
model shaders keep their plain-skin fallback; BSP surfaces draw them all."""
def parse_stage_token(tokens: list[str], i: int, stage: ModelStage, material: ModelMaterial) -> int {
    token = tokens[i].lower();
    if i + 1 >= len(tokens) {
        return i;
    }
    argument = tokens[i + 1].lower();
    if token == "animmap" {
        stage.frequency = float(tokens[i + 1]);
        i += 2;
        while i < len(tokens) and tokens[i] not in ["\n", "{", "}"] {
            stage.frames.append(Texture(name=tokens[i]));
            i += 1;
        }
        if stage.frames and stage.frequency > 0.0 {
            stage.texture = stage.frames[0];
        } else {
            material.unsupported.append("invalid animmap");
        }
        return i - 1;
    }
    if token == "map" or token == "clampmap" {
        stage.texture = Texture(name=tokens[i + 1]);
        if argument == "$lightmap" {
            stage.lightmap = True;
            material.advanced.append("lightmap");
        } elif argument == "$whiteimage" {
            stage.white = True;
            material.advanced.append("white");
        }
        if token == "clampmap" {
            material.advanced.append("clampmap");
        }
        return i + 1;
    }
    if token == "tcgen" {
        stage.environment = argument == "environment";
        if argument == "lightmap" {
            stage.lightmap = True;
            material.advanced.append("tcgen lightmap");
        } elif argument not in ["environment", "base", "texture"] {
            material.unsupported.append("tcgen " + argument);
        }
        return i + 1;
    }
    if token == "blendfunc" {
        if argument in ["add", "blend", "filter"] {
            stage.blend = "add" if argument == "add" else ("alpha" if argument == "blend" else "multiply");
            return i + 1;
        }
        if i + 2 < len(tokens) {
            destination = tokens[i + 2].lower();
            stage.blend = blend_factors(argument, destination);
            if stage.blend == "custom" {
                stage.blend_source = argument;
                stage.blend_destination = destination;
                material.advanced.append("blendfunc " + argument + " " + destination);
            }
            return i + 2;
        }
        return i + 1;
    }
    if token == "rgbgen" {
        if argument in ["identity", "identitylighting"] {
            return i + 1;
        }
        material.advanced.append("rgbgen " + argument);
        if argument in ["vertex", "exactvertex", "lightingdiffuse"] {
            stage.rgb = "vertex";
            return i + 1;
        }
        if argument == "wave" {
            stage.rgb = "wave";
            stage.rgb_wave = wave_at(tokens, i + 2);
            return i + 6;
        }
        if argument == "const" {
            stage.rgb = "const";
            stage.rgb_const = [number_at(tokens, i + 3), number_at(tokens, i + 4), number_at(tokens, i + 5)];
            return i + 6;
        }
        return i + 1;
    }
    if token == "alphagen" {
        material.advanced.append("alphagen " + argument);
        if argument == "wave" {
            stage.alpha = "wave";
            stage.alpha_wave = wave_at(tokens, i + 2);
            return i + 6;
        }
        if argument == "const" {
            stage.alpha = "const";
            stage.alpha_const = number_at(tokens, i + 2);
            return i + 2;
        }
        if argument == "vertex" {
            stage.alpha = "vertex";
        } elif argument == "lightingspecular" {
            stage.alpha = "specular";
        }
        return i + 1;
    }
    if token == "tcmod" {
        if argument == "scroll" {
            stage.scroll_u += number_at(tokens, i + 2);
            stage.scroll_v += number_at(tokens, i + 3);
            stage.mods.append(TexMod(kind="scroll", a=number_at(tokens, i + 2), b=number_at(tokens, i + 3)));
            return i + 3;
        }
        material.advanced.append("tcmod " + argument);
        if argument == "scale" {
            stage.mods.append(TexMod(kind="scale", a=number_at(tokens, i + 2), b=number_at(tokens, i + 3)));
            return i + 3;
        }
        if argument == "rotate" {
            stage.mods.append(TexMod(kind="rotate", a=number_at(tokens, i + 2)));
            return i + 2;
        }
        if argument == "turb" {
            stage.mods.append(
                TexMod(
                    kind="turb",
                    wave=ShaderWave(
                        base=number_at(tokens, i + 2),
                        amplitude=number_at(tokens, i + 3),
                        phase=number_at(tokens, i + 4),
                        frequency=number_at(tokens, i + 5)
                    )
                )
            );
            return i + 5;
        }
        if argument == "stretch" {
            stage.mods.append(TexMod(kind="stretch", wave=wave_at(tokens, i + 2)));
            return i + 6;
        }
        material.unsupported.append("tcmod " + argument);
        return i + 1;
    }
    if token == "alphafunc" {
        stage.alpha_test = 1 if argument == "gt0" else (2 if argument == "ge128" else (3 if argument == "lt128" else 0));
        material.advanced.append("alphafunc");
        return i + 1;
    }
    if token == "depthwrite" {
        stage.depth_write = True;
        material.advanced.append("depthwrite");
        return i;
    }
    if token == "depthfunc" {
        return i + 1;
    }
    return i;
}

def material_name(name: str) -> str {
    name = name.lower();
    for extension in [".tga", ".jpg", ".jpeg", ".png"] {
        if name.endswith(extension) {
            return name[:-len(extension)];
        }
    }
    return name;
}

def model_materials(clean_source: str) -> dict[str, ModelMaterial] {
    tokens: list[str] = [];
    for line in clean_source.split("\n") {
        tokens.extend(line.replace("{", " { ").replace("}", " } ").split());
        tokens.append("\n");
    }
    result: dict[str, ModelMaterial] = {};
    depth = 0;
    name = "";
    material = ModelMaterial();
    stage = ModelStage();
    i = 0;
    while i < len(tokens) {
        token = tokens[i].lower();
        if token == "\n" {
            i += 1;
            continue;
        }
        if token == "{" {
            depth += 1;
            if depth == 1 {
                material = ModelMaterial();
            }
            if depth == 2 {
                stage = ModelStage();
            }
        } elif token == "}" {
            if depth == 2 and stage.texture.name != "missing" {
                material.stages.append(stage);
            }
            depth -= 1;
            if depth == 0 {
                result[material_name(name)] = material;
            }
        } elif depth == 0 {
            name = tokens[i];
        } elif depth == 2 {
            i = parse_stage_token(tokens, i, stage, material);
        } elif depth == 1 and token == "cull" and i + 1 < len(tokens) {
            mode = tokens[i + 1].lower();
            material.two_sided = mode in ["none", "disable", "twosided"];
            if not material.two_sided {
                material.unsupported.append("cull " + mode);
            }
            i += 1;
        } elif depth == 1 and token == "skyparms" {
            # skyParms <farbox> <cloudheight> <nearbox>
            material.sky = True;
            if i + 2 < len(tokens) {
                material.farbox = "" if tokens[i + 1] == "-" else tokens[i + 1];
                height = tokens[i + 2];
                material.cloud_height = number_at(tokens, i + 2) if height != "-" and number_at(tokens, i + 2) > 0.0 else 128.0;
                i += 3;
            }
        } elif depth == 1 and token == "surfaceparm" and i + 1 < len(tokens) and tokens[i + 1].lower() == "sky" {
            material.sky = True;
        } elif depth == 1 and token == "deformvertexes" and i + 1 < len(tokens) {
            kind = tokens[i + 1].lower();
            material.advanced.append("deformvertexes " + kind);
            if kind == "wave" {
                divisor = number_at(tokens, i + 2);
                material.deforms.append(Deform(kind="wave", spread=1.0 / divisor if divisor != 0.0 else 0.0, wave=wave_at(tokens, i + 3)));
                i += 7;
            } elif kind == "move" {
                material.deforms.append(
                    Deform(kind="move", vector=Vec3(x=number_at(tokens, i + 2), y=number_at(tokens, i + 3), z=number_at(tokens, i + 4)), wave=wave_at(tokens, i + 5))
                );
                i += 9;
            } elif kind == "bulge" {
                material.deforms.append(Deform(kind="bulge", width=number_at(tokens, i + 2), height=number_at(tokens, i + 3), speed=number_at(tokens, i + 4)));
                i += 4;
            } elif kind in ["autosprite", "autosprite2"] {
                material.deforms.append(Deform(kind=kind));
                i += 1;
            } elif kind == "normal" {
                i += 1;
            } else {
                material.unsupported.append("deformvertexes " + kind);
            }
        } elif depth == 1 and token == "deformvertexes" {
            material.unsupported.append(token);
        }
        i += 1;
    }
    return result;
}
