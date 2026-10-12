"""A project's scripts: Jac walkers that the studio runs outside itself.

The studio is one native program and cannot take new code in. A script is
run by the jac toolchain in a process of its own, on a copy of the level
made into a graph (editor/userland/qp.jac: a Level that holds Things, with
Fires edges between them), and all it can do to the studio is ask: a line
for each thing asked, of a few kinds the studio knows. What is here writes
the level for a script, writes the few lines that start one, and reads back
what it asked, what the compiler said of it, and what it declares."""

import from .scriptlib { script_library }

"""The kinds of thing a script may ask: set a field, fire an entity, pick
one, say something, add an entity. A line of any other kind is not read."""
glob ASK_KINDS: list[str] = ["set", "fire", "pick", "say", "add"];

"""Text as a word of JSON: in quotation marks, with what would break it written out."""
def json_word(text: str) -> str {
    said = "\"";
    for letter in text {
        if letter == "\"" {
            said += "\\\"";
        } elif letter == "\\" {
            said += "\\\\";
        } elif letter == "\n" {
            said += "\\n";
        } elif letter == "\r" {
            said += "\\r";
        } elif letter == "\t" {
            said += "\\t";
        } elif ord(letter) < 32 {
            said += " ";
        } else {
            said += letter;
        }
    }
    return said + "\"";
}

"""A level as a script is given it: its name and game, what is happening
(`run` when asked for by hand, `fired` when its entity fires in a played
game), words handed to it, the number of the entity it is attached to
(below zero for the level itself), and every entity by its number with
its fields."""
def scene_json(
    name: str, game: str, event: str, words: list[str], on: int, entities: list[tuple[int, dict[str, str]]]
) -> str {
    rows: list[str] = [];
    for (number, fields) in entities {
        pairs = [json_word(key) + ": " + json_word(fields[key]) for key in sorted(fields.keys())];
        rows.append("  {\"number\": " + str(number) + ", \"fields\": {" + ", ".join(pairs) + "}}");
    }
    return "{\"name\": " + json_word(name) + ", \"game\": " + json_word(game) + ", \"event\": " + json_word(event)
        + ", \"words\": [" + ", ".join([json_word(each) for each in words]) + "], \"on\": " + str(on) + ", \"entities\": [\n"
        + ",\n".join(rows) + "\n]}\n";
}

"""The few lines that run a walker of a script: read the level, set the
walker down on what it is attached to (or on the level), write what it
asked. `module` is the script's file without its ending."""
def launcher_text(module: str, named: str, source: str, result: str) -> str {
    return "import from qp { read_level, attached, write_asked }\n" + "import from " + module + " { " + named + " }\n\n"
        + "with entry {\n" + "    level = read_level(" + json_word(source) + ");\n" + "    thing = attached(level);\n"
        + "    if thing is not None {\n" + "        thing spawn " + named + "();\n" + "    } else {\n"
        + "        level spawn " + named + "();\n" + "    }\n" + "    write_asked(" + json_word(result) + ");\n" + "}\n";
}

"""The words of a line a script asked: its kind bare, the rest as words of JSON."""
def asked_words(line: str) -> list[str] {
    words: list[str] = [];
    word = "";
    quoted = False;
    escaped = False;
    began = False;
    for letter in line.strip() {
        if quoted {
            if escaped {
                word += "\n" if letter == "n" else ("\t" if letter == "t" else ("" if letter == "r" else letter));
                escaped = False;
            } elif letter == "\\" {
                escaped = True;
            } elif letter == "\"" {
                quoted = False;
            } else {
                word += letter;
            }
        } elif letter == "\"" {
            quoted = True;
            began = True;
        } elif letter == " " {
            if began {
                words.append(word);
            }
            word = "";
            began = False;
        } else {
            word += letter;
            began = True;
        }
    }
    if began {
        words.append(word);
    }
    return words;
}

"""What a script asked for, a list of words each, in order: only the kinds
the studio knows, and only when they have the words that kind needs."""
def read_asked(text: str) -> list[list[str]] {
    needed = {"set": 4, "fire": 2, "pick": 2, "say": 2, "add": 3};
    found: list[list[str]] = [];
    for line in text.split("\n") {
        words = asked_words(line);
        if len(words) > 0 and words[0] in ASK_KINDS and len(words) >= needed[words[0]] {
            found.append(words);
        }
    }
    return found;
}

"""The walkers a script declares, by name, in its order."""
def script_walkers(source: str) -> list[str] {
    found: list[str] = [];
    for raw in source.split("\n") {
        words = raw.strip().replace("(", " ").replace("{", " ").split();
        if len(words) >= 2 and words[0] == "walker" and words[1] not in found {
            found.append(words[1]);
        }
    }
    return found;
}

"""The entity classes a script declares: every `node` that derives from
Thing, as a line of the studio's class table. Its fields are what it
`has`, numbers and text told apart, with what each begins as; what the
node says of itself in a doc string before it is the class's help."""
def script_classes(source: str) -> list[str] {
    found: list[str] = [];
    lines = source.split("\n");
    help_words = "";
    at = 0;
    while at < len(lines) {
        line = lines[at].strip();
        at += 1;
        if line.startswith("\"\"\"") and line.endswith("\"\"\"") and len(line) >= 6 {
            help_words = line[3:len(line) - 3].strip();
            continue;
        }
        words = line.replace("(", " ").replace(")", " ").replace("{", " ").split();
        if len(words) < 3 or words[0] != "node" or words[2] != "Thing" {
            if line and not line.startswith("#") {
                help_words = "";
            }
            continue;
        }
        fields: list[str] = [];
        # What it has: up to the brace that closes it.
        body = "";
        while at < len(lines) and not lines[at].strip().startswith("}") {
            body += " " + lines[at].strip();
            at += 1;
        }
        for clause in body.replace(";", ",").split(",") {
            said = clause.strip();
            if said.startswith("has ") {
                said = said[4:].strip();
            }
            if ":" not in said or said.startswith("def ") or said.startswith("can ") {
                continue;
            }
            key = said.split(":", 1)[0].strip();
            rest = said.split(":", 1)[1];
            kind = rest.split("=", 1)[0].strip();
            preset = rest.split("=", 1)[1].strip().strip("\"") if "=" in rest else "";
            if not key.replace("_", "").isalnum() {
                continue;
            }
            fields.append(key + ":" + ("n" if kind in ["int", "float"] else "t") + ":" + preset + ":");
        }
        found.append(words[1] + "|point|passion|" + (help_words if help_words else "A class of the project's scripts") + "|" + ",".join(fields) + "|");
        help_words = "";
    }
    return found;
}

"""What the compiler, or a script as it ran, said was wrong: each fault by
the line of `file_name` it is at (0 when it names none) and its words."""
def said_faults(said: str, file_name: str) -> list[tuple[int, str]] {
    found: list[tuple[int, str]] = [];
    waiting = "";
    for raw in said.split("\n") {
        line = raw.strip();
        told = "";
        if "error[" in line and "]: " in line {
            told = line.split("]: ", 1)[1];
        } elif line.startswith("✖ Error: ") {
            told = line[len("✖ Error: "):];
        }
        if told {
            if waiting {
                found.append((0, waiting));
            }
            waiting = told;
            continue;
        }
        place = line.rfind(file_name + ":");
        if waiting and place >= 0 {
            digits = "";
            for letter in line[place + len(file_name) + 1:] {
                if not letter.isdigit() {
                    break;
                }
                digits += letter;
            }
            found.append((int(digits) if digits else 0, waiting));
            waiting = "";
        }
    }
    if waiting {
        found.append((0, waiting));
    }
    return found;
}

"""A script to begin from: one walker that says what it stands on."""
def starter_script(named: str) -> str {
    return "\"\"\"A script of this project: walkers the studio sets down on the level's entities.\n"
        + "ed_script run " + named + " runs this one on the level; ed_script attach puts it on the selection.\"\"\"\n\n"
        + "import from qp { Thing, Level, Holds, Fires }\n\n" + "walker " + named + " {\n"
        + "    can look with Level entry {\n" + "        things = [here->:Holds:->];\n"
        + "        here.say(str(len(things)) + \" entities in \" + here.name);\n" + "    }\n\n"
        + "    can touch with Thing entry {\n" + "        here.pick();\n" + "        visit [here->:Fires:->];\n" + "    }\n" + "}\n";
}

"""The library the scripts import, as its file."""
def library_text -> str {
    return script_library();
}
