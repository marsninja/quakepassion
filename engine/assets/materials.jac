"""Initial ordered Q3 model shader stages; archive/image resolution stays separate."""
import from ..formats.animated { ModelStage }
import from ..formats.bsp { Texture }

obj ModelMaterial {
    has stages: list[ModelStage] = [],
        unsupported: list[str] = [];
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
    tokens = clean_source.replace("{", " { ").replace("}", " } ").split();
    result: dict[str, ModelMaterial] = {};
    depth = 0;
    name = "";
    material = ModelMaterial();
    stage = ModelStage();
    i = 0;
    while i < len(tokens) {
        token = tokens[i].lower();
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
        } elif depth == 2 and i + 1 < len(tokens) {
            argument = tokens[i + 1].lower();
            if token == "map" or token == "clampmap" {
                stage.texture = Texture(name=tokens[i + 1]);
                if token == "clampmap" {
                    material.unsupported.append("clampmap");
                }
                i += 1;
            } elif token == "tcgen" {
                stage.environment = argument == "environment";
                if argument not in ["environment", "base"] {
                    material.unsupported.append("tcgen " + argument);
                }
                i += 1;
            } elif token == "blendfunc" {
                if argument in ["add", "blend", "filter"] {
                    stage.blend = "add"
                        if argument == "add"
                        else ("alpha" if argument == "blend" else "multiply");
                    i += 1;
                } elif i + 2 < len(tokens) {
                    destination = tokens[i + 2].lower();
                    if argument == "gl_one" and destination == "gl_zero" {
                        stage.blend = "opaque";
                    } elif argument == "gl_one" and destination == "gl_one" {
                        stage.blend = "add";
                    } elif argument == "gl_src_alpha"
                        and destination == "gl_one_minus_src_alpha" {
                        stage.blend = "alpha";
                    } elif argument == "gl_dst_color" and destination == "gl_zero" {
                        stage.blend = "multiply";
                    } else {
                        material.unsupported.append(
                            "blendfunc " + argument + " " + destination
                        );
                    }
                    i += 2;
                }
            } elif token in ["rgbgen", "alphagen"] {
                if argument != "identity" {
                    material.unsupported.append(token + " " + argument);
                }
                i += 1;
            } elif token == "tcmod" and argument == "scroll" and i + 3 < len(tokens) {
                stage.scroll_u += float(tokens[i + 2]);
                stage.scroll_v += float(tokens[i + 3]);
                i += 3;
            } elif token
                in ["tcmod", "animmap", "alphafunc", "depthfunc", "depthwrite"] {
                material.unsupported.append(token);
            }
        } elif depth == 1 and token in ["cull", "deformvertexes"] {
            material.unsupported.append(token);
        }
        i += 1;
    }
    return result;
}
