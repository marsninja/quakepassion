"""A project: a folder of one's own with a manifest at its top and, under it,
`scenes/` (a map file a scene), `prefabs/`, `textures/` (image files used as
materials) and whatever add-ons it lists. The manifest is text, a line a
fact, written the same way every time so that two versions of it compare
line by line:

    // A QuakePassion project.
    name "The keep"
    game passion
    start yard
    material blockout
    build quick
    bake 128
    scene hall
    scene yard
    addon classes/traps.txt
    recipe fine "ed_build full; ed_bake 128"

An add-on is a text file too: lines of entity classes, in the form the
studio's own table has them, after the word `class`."""

"""What a project's manifest says."""
obj Project {
    has name: str = "",
        game: str = "passion",
        # The scene opened with the project, and the scenes it has.
        start: str = "",
        scenes: list[str] = [],
        # What a new brush is made of, how levels are lit (full, quick or
        # flat) and how wide a bake's cells are (0 for no bake).
        material: str = "",
        build: str = "",
        bake: int = 0,
        addons: list[str] = [],
        recipes: dict[str, str] = {},
        # Lines it did not understand, kept as they were.
        other: list[str] = [];
}

glob MANIFEST_NAME: str = "project.qp";

"""A line's words: apart at spaces, with what is in double quotes one word."""
def manifest_words(line: str) -> list[str] {
    words: list[str] = [];
    word = "";
    quoted = False;
    began = False;
    for letter in line {
        if letter == "\"" {
            quoted = not quoted;
            began = True;
        } elif letter in " \t" and not quoted {
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

"""A word as a manifest writes it: in quotes when it has a space or is empty."""
def manifest_word(word: str) -> str {
    plain = word.replace("\"", "'");
    return "\"" + plain + "\"" if " " in plain or ";" in plain or not plain else plain;
}

"""A name fit for a file: letters, digits, - and _ ("" when none are left)."""
def file_name(words: str) -> str {
    return "".join([letter for letter in words.strip().replace(" ", "_") if letter.isalnum() or letter in "_-"]);
}

def read_project(text: str) -> Project {
    found = Project();
    for raw in text.split("\n") {
        line = raw.strip();
        if not line or line.startswith("//") {
            continue;
        }
        words = manifest_words(line);
        key = words[0];
        value = words[1] if len(words) > 1 else "";
        if key == "name" {
            found.name = " ".join(words[1:]);
        } elif key == "game" and value in ["passion", "q1", "q2", "q3"] {
            found.game = value;
        } elif key == "start" {
            found.start = file_name(value);
        } elif key == "material" {
            found.material = value;
        } elif key == "build" and value in ["full", "quick", "flat"] {
            found.build = value;
        } elif key == "bake" and value.isdigit() {
            found.bake = int(value);
        } elif key == "scene" and file_name(value) {
            if file_name(value) not in found.scenes {
                found.scenes.append(file_name(value));
            }
        } elif key == "addon" and value and ".." not in value {
            if value not in found.addons {
                found.addons.append(value);
            }
        } elif key == "recipe" and len(words) > 2 and file_name(value) {
            found.recipes[file_name(value)] = " ".join(words[2:]);
        } else {
            found.other.append(line);
        }
    }
    return found;
}

def write_project(project: Project) -> str {
    lines = ["// A QuakePassion project.", "name " + manifest_word(project.name), "game " + project.game];
    if project.start {
        lines.append("start " + project.start);
    }
    if project.material {
        lines.append("material " + manifest_word(project.material));
    }
    if project.build {
        lines.append("build " + project.build);
    }
    if project.bake > 0 {
        lines.append("bake " + str(project.bake));
    }
    for scene_name in sorted(project.scenes) {
        lines.append("scene " + scene_name);
    }
    for addon in sorted(project.addons) {
        lines.append("addon " + manifest_word(addon));
    }
    for recipe in sorted(project.recipes.keys()) {
        lines.append("recipe " + recipe + " " + manifest_word(project.recipes[recipe]));
    }
    for line in project.other {
        lines.append(line);
    }
    return "\n".join(lines) + "\n";
}

"""The entity classes an add-on's text holds: each line after the word
`class`, as the studio's table has a class."""
def addon_classes(text: str) -> list[str] {
    found: list[str] = [];
    for raw in text.split("\n") {
        line = raw.strip();
        if line.startswith("class ") and len(line[6:].split("|")) >= 4 {
            found.append(line[6:].strip());
        }
    }
    return found;
}
