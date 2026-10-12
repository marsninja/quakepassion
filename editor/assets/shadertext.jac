"""A Quake III shader script as words to edit: the script written out for a
box of text, and what is wrong with a text, each fault at the line it is
on."""

import from .shaders { ShaderText, ShaderFault, read_shaders, write_shaders, shader_faults, line_fault }

"""A script's shaders as the words a box of text shows: as they are saved,
with four spaces where the file has a tab and no empty lines at the end."""
def script_shown(shaders: list[ShaderText]) -> str {
    return write_shaders(shaders).replace("\t", "    ").rstrip();
}

"""What is wrong with a script's text, in the order of its lines: how it is
put together (braces, names), then lines the game does not know or that
have words it does not take, each at its own line, and stages with no
picture at the line they open on."""
def script_faults(text: str) -> list[ShaderFault] {
    read = read_shaders(text);
    found: list[ShaderFault] = list(read[1]);
    # Lines, each where it stands: the reader's depth is followed again.
    depth = 0;
    number = 0;
    named = "";
    waiting = "";
    for raw in text.split("\n") {
        number += 1;
        cut = raw.find("//");
        line = (raw[:cut] if cut >= 0 else raw).strip();
        if not line {
            continue;
        }
        for word in line.replace("{", "\n{\n").replace("}", "\n}\n").split("\n") {
            piece = word.strip();
            if not piece {
                continue;
            }
            if piece == "{" {
                if depth == 0 {
                    named = waiting if waiting else "(unnamed)";
                    waiting = "";
                }
                depth += 1;
            } elif piece == "}" {
                depth = max(0, depth - 1);
            } elif depth == 0 {
                waiting = piece;
            } elif depth <= 2 {
                wrong = line_fault(piece, depth == 2);
                if wrong {
                    found.append(ShaderFault(line=number, words=named + ": " + wrong, shader=named));
                }
            }
        }
    }
    # A stage with no picture is said where the stage opens.
    for shader in read[0] {
        for fault in shader_faults(shader) {
            if fault.words.endswith("has no picture (map, clampMap, animMap or videoMap)") {
                found.append(fault);
            }
        }
    }
    ordered: list[ShaderFault] = [];
    for fault in found {
        at = len(ordered);
        while at > 0 and ordered[at - 1].line > fault.line {
            at -= 1;
        }
        ordered.insert(at, fault);
    }
    return ordered;
}

"""Whether a text is put together soundly enough to stand as the script:
its braces match and every shader has a name."""
def script_sound(text: str) -> bool {
    return len(read_shaders(text)[1]) == 0;
}

"""A shader said in a few lines beside its text: what it has of its own,
then each stage by its picture and how it is laid on."""
def shader_brief(shader: ShaderText) -> list[str] {
    said: list[str] = [shader.name];
    said.append(str(len(shader.lines)) + (" line" if len(shader.lines) == 1 else " lines") + " of its own");
    for (number, stage) in enumerate(shader.stages) {
        picture = "no picture";
        blend = "";
        for line in stage.lines {
            words = line.split();
            key = words[0].lower() if len(words) > 0 else "";
            if key in ["map", "clampmap", "animmap", "videomap"] and len(words) > 1 {
                picture = words[-1] if key != "animmap" else " ".join(words[2:3]) + " ...";
            } elif key == "blendfunc" {
                blend = " ".join(words[1:]);
            }
        }
        said.append("stage " + str(number) + ": " + picture + (" (" + blend + ")" if blend else ""));
    }
    return said;
}
