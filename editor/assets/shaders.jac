"""Quake III shader scripts as text the studio reads, checks and changes.

A script is a row of shaders: a name, then braces holding the shader's own
lines (what it is made of, how it is culled, deformed and sorted) and, in
braces of their own, its stages: each a picture and how it is blended,
coloured and moved. Here a shader is kept as its lines, a line a directive,
so that what is not understood is still kept and written back; the checks
know the words the game knows and say, by line, what it would trip on."""

"""One stage of a shader: its directives, a line each."""
obj ShaderStage {
    has lines: list[str] = [],
        # The line of the script it opened at (0 when it was made here).
        line: int = 0;
}

"""One shader: its name, its own directives and its stages."""
obj ShaderText {
    has name: str,
        lines: list[str] = [],
        stages: list[ShaderStage] = [],
        line: int = 0;
}

"""Something wrong with a script: where, and what."""
obj ShaderFault {
    has line: int,
        words: str,
        shader: str = "";
}

"""What a shader's own lines may begin with (and anything beginning qer_ or
q3map_, which are for map tools)."""
glob SHADER_WORDS: list[str] = [
    "surfaceparm", "cull", "deformvertexes", "tesssize", "skyparms", "fogparms", "nopicmip", "nomipmaps", "polygonoffset",
    "portal", "sort", "entitymergable", "light", "fogonly", "cloudparms", "lightning", "sky", "foggen", "notc"
];

"""What a stage's lines may begin with."""
glob STAGE_WORDS: list[str] = [
    "map", "clampmap", "animmap", "videomap", "blendfunc", "rgbgen", "alphagen", "tcgen", "texgen", "tcmod", "depthfunc",
    "depthwrite", "alphafunc", "detail"
];

glob BLEND_NAMES: list[str] = ["add", "filter", "blend"];

glob BLEND_FACTORS: list[str] = [
    "gl_one", "gl_zero", "gl_dst_color", "gl_one_minus_dst_color", "gl_src_alpha", "gl_one_minus_src_alpha", "gl_dst_alpha",
    "gl_one_minus_dst_alpha", "gl_src_color", "gl_one_minus_src_color", "gl_src_alpha_saturate"
];

"""The words each of these directives may be followed by."""
glob CHOICES: dict[str, list[str]] = {
    "rgbgen": [
        "identity", "identitylighting", "vertex", "exactvertex", "entity", "oneminusentity", "lightingdiffuse", "wave", "const",
        "oneminusvertex"
    ],
    "alphagen": [
        "identity", "vertex", "entity", "oneminusentity", "lightingspecular", "wave", "portal", "const", "oneminusvertex"
    ],
    "tcmod": ["rotate", "scale", "scroll", "stretch", "transform", "turb", "entitytranslate"],
    "tcgen": ["base", "lightmap", "environment", "vector"],
    "texgen": ["base", "lightmap", "environment", "vector"],
    "depthfunc": ["lequal", "equal"],
    "alphafunc": ["gt0", "lt128", "ge128"],
    "cull": ["front", "back", "none", "disable", "twosided"]
};

"""A line without what follows // on it, and without the space round it."""
def:priv bare(line: str) -> str {
    cut = line.find("//");
    return (line[:cut] if cut >= 0 else line).strip();
}

"""Read a script. Answers its shaders and what is wrong with how it is put
together: braces that do not match, and names that are missing."""
def read_shaders(text: str) -> tuple[list[ShaderText], list[ShaderFault]] {
    shaders: list[ShaderText] = [];
    faults: list[ShaderFault] = [];
    depth = 0;
    waiting = "";
    waiting_line = 0;
    number = 0;
    for raw in text.split("\n") {
        number += 1;
        line = bare(raw);
        if not line {
            continue;
        }
        # A brace is a word of its own wherever it stands on the line.
        for word in line.replace("{", "\n{\n").replace("}", "\n}\n").split("\n") {
            piece = word.strip();
            if not piece {
                continue;
            }
            if piece == "{" {
                if depth == 0 {
                    if not waiting {
                        faults.append(ShaderFault(line=number, words="A brace opens with no shader's name before it"));
                        waiting = "(unnamed)";
                    }
                    shaders.append(ShaderText(name=waiting, line=waiting_line if waiting_line > 0 else number));
                    waiting = "";
                    waiting_line = 0;
                } elif depth == 1 {
                    shaders[-1].stages.append(ShaderStage(line=number));
                } else {
                    faults.append(ShaderFault(line=number, words="A brace opens inside a stage", shader=shaders[-1].name));
                }
                depth += 1;
            } elif piece == "}" {
                if depth == 0 {
                    faults.append(ShaderFault(line=number, words="A brace closes that nothing opened"));
                } else {
                    depth -= 1;
                }
            } elif depth == 0 {
                if waiting {
                    faults.append(
                        ShaderFault(line=waiting_line, words="The name " + waiting + " has no braces after it", shader=waiting)
                    );
                }
                waiting = piece;
                waiting_line = number;
            } elif depth == 1 {
                shaders[-1].lines.append(piece);
            } elif depth == 2 {
                shaders[-1].stages[-1].lines.append(piece);
            }
        }
    }
    if waiting {
        faults.append(ShaderFault(line=waiting_line, words="The name " + waiting + " has no braces after it", shader=waiting));
    }
    if depth > 0 and len(shaders) > 0 {
        faults.append(
            ShaderFault(
                line=shaders[-1].line,
                words="The shader " + shaders[-1].name + " is not closed: " + str(depth) + " braces are still open at the end",
                shader=shaders[-1].name
            )
        );
    }
    return (shaders, faults);
}

"""Write shaders as a script: a tab for each brace they are inside."""
def write_shaders(shaders: list[ShaderText]) -> str {
    lines: list[str] = [];
    for shader in shaders {
        lines.append(shader.name);
        lines.append("{");
        for line in shader.lines {
            lines.append("\t" + line);
        }
        for stage in shader.stages {
            lines.append("\t{");
            for line in stage.lines {
                lines.append("\t\t" + line);
            }
            lines.append("\t}");
        }
        lines.append("}");
        lines.append("");
    }
    return "\n".join(lines);
}

"""What follows a directive on the first line that begins with it ("" when
no line does)."""
def directive(lines: list[str], key: str) -> str {
    for line in lines {
        words = line.split();
        if len(words) > 0 and words[0].lower() == key.lower() {
            return " ".join(words[1:]);
        }
    }
    return "";
}

"""Lines with a directive set: the first line that begins with it changed,
or one added; with no value, every such line taken out. `also` is a second
word that must match too, for directives a shader has several of
(`tcmod scroll`, `surfaceparm nolightmap`)."""
def with_directive(lines: list[str], key: str, value: str, also: str = "") -> list[str] {
    made: list[str] = [];
    placed = False;
    for line in lines {
        words = line.split();
        same = len(words) > 0 and words[0].lower() == key.lower()
            and (not also or (len(words) > 1 and words[1].lower() == also.lower()));
        if not same {
            made.append(line);
        } elif value and not placed {
            made.append(key + " " + value);
            placed = True;
        }
    }
    if value and not placed {
        made.append(key + " " + value);
    }
    return made;
}

def shader_named(shaders: list[ShaderText], name: str) -> ShaderText | None {
    for shader in shaders {
        if shader.name.lower() == name.lower() {
            return shader;
        }
    }
    return None;
}

"""What the game would trip on in a line: "" when nothing."""
def line_fault(line: str, staged: bool) -> str {
    words = line.split();
    key = words[0].lower();
    rest = [word.lower() for word in words[1:]];
    if staged {
        if key not in STAGE_WORDS {
            return "A stage has no " + words[0] + (" (that is a line of the shader itself)" if key in SHADER_WORDS else "");
        }
    } elif key not in SHADER_WORDS and not key.startswith("qer_") and not key.startswith("q3map_") {
        return "A shader has no " + words[0] + (" (that is a line of a stage)" if key in STAGE_WORDS else "");
    }
    if key in ["map", "clampmap", "videomap"] and len(rest) != 1 {
        return words[0] + " takes one picture";
    }
    if key == "animmap" and (len(rest) < 2 or len(rest) > 9) {
        return "animMap takes how many frames a second and from one to eight pictures";
    }
    if key == "blendfunc" {
        if len(rest) == 1 and rest[0] in BLEND_NAMES {
            return "";
        }
        if len(rest) != 2 or rest[0] not in BLEND_FACTORS or rest[1] not in BLEND_FACTORS {
            return "blendFunc takes add, filter or blend, or two of the GL_ factors";
        }
    }
    if key in CHOICES and (len(rest) == 0 or rest[0] not in CHOICES[key]) {
        return words[0] + " takes one of: " + ", ".join(CHOICES[key]);
    }
    if key == "surfaceparm" and len(rest) != 1 {
        return "surfaceparm takes one word";
    }
    return "";
}

"""What is wrong inside a shader: lines the game does not know, in the
wrong place or with words it does not take, and stages with no picture."""
def shader_faults(shader: ShaderText) -> list[ShaderFault] {
    found: list[ShaderFault] = [];
    for line in shader.lines {
        wrong = line_fault(line, False);
        if wrong {
            found.append(ShaderFault(line=shader.line, words=shader.name + ": " + wrong, shader=shader.name));
        }
    }
    for (number, stage) in enumerate(shader.stages) {
        pictured = False;
        for line in stage.lines {
            wrong = line_fault(line, True);
            if wrong {
                found.append(
                    ShaderFault(
                        line=stage.line if stage.line > 0 else shader.line,
                        words=shader.name + " stage " + str(number) + ": " + wrong,
                        shader=shader.name
                    )
                );
            }
            if line.split()[0].lower() in ["map", "clampmap", "animmap", "videomap"] {
                pictured = True;
            }
        }
        if not pictured {
            found.append(
                ShaderFault(
                    line=stage.line if stage.line > 0 else shader.line,
                    words=shader.name + " stage " + str(number) + " has no picture (map, clampMap, animMap or videoMap)",
                    shader=shader.name
                )
            );
        }
    }
    return found;
}
