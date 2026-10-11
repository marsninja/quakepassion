"""Steps of a build beyond the studio's own. A recipe is a row of commands
kept under a name; a step for another program is a command line run over
the scene written out as a map; and what such a program says is read for
the entities and brushes it speaks of, so that they can be gone to. A built
level is also known by a mark made from what it was built of, so that the
same thing is not built twice."""

"""Something a compiler spoke of: an entity and one of its brushes as the map
numbers them (the brush -1 when it named none), and the line it said."""
obj Place {
    has entity: int,
        brush: int = -1,
        words: str = "";
}

"""The commands of a recipe: its words apart at each semicolon."""
def recipe_steps(words: str) -> list[str] {
    steps: list[str] = [];
    for part in words.split(";") {
        step = part.strip();
        if step {
            steps.append(step);
        }
    }
    return steps;
}

"""A command line for another program with the scene's map put in: %map% is
the file's path (in quotes when it has a space in it), %dir% its folder and
%name% its name without the ending."""
def step_line(template: str, map_path: str) -> str {
    cut = map_path.rfind("/");
    folder = map_path[:cut] if cut > 0 else ".";
    name = map_path[cut + 1:];
    dot = name.rfind(".");
    if dot > 0 {
        name = name[:dot];
    }
    # A path with a space in it goes in quotes, to stay one word.
    whole = "\"" + map_path + "\"" if " " in map_path else map_path;
    return template.replace("%map%", whole).replace("%dir%", folder).replace("%name%", name);
}

"""The whole number that follows a word in a line, past what punctuation
lies between ("entity 4", "Entity #4:", "brush=12"), or -1."""
def number_after(line: str, word: str) -> int {
    at = line.find(word);
    while at >= 0 {
        index = at + len(word);
        while index < len(line) and line[index] in " #:=(\t" {
            index += 1;
        }
        digits = "";
        while index < len(line) and line[index].isdigit() {
            digits += line[index];
            index += 1;
        }
        if digits {
            return int(digits);
        }
        at = line.find(word, at + len(word));
    }
    return -1;
}

"""Which entity and brush a line of a map's text lies in, by the numbered
comments the studio writes before each."""
def place_of_line(map_text: str, number: int) -> Place | None {
    entity = -1;
    brush = -1;
    count = 0;
    for line in map_text.split("\n") {
        count += 1;
        if count > number {
            break;
        }
        if line.startswith("// entity ") {
            entity = number_after(line, "entity");
            brush = -1;
        } elif line.startswith("// brush ") {
            brush = number_after(line, "brush");
        }
    }
    if entity < 0 or number > count {
        return None;
    }
    return Place(entity=entity, brush=brush);
}

"""The places a compiler's words speak of: every line that names an entity
by number, with the brush if it names one, and, given the map's own text,
every line that names a line of it."""
def places_named(text: str, map_text: str = "") -> list[Place] {
    found: list[Place] = [];
    for raw in text.split("\n") {
        said = raw.strip();
        if not said {
            continue;
        }
        lower = said.lower();
        entity = number_after(lower, "entity");
        if entity >= 0 {
            found.append(Place(entity=entity, brush=number_after(lower, "brush"), words=said));
            continue;
        }
        line = number_after(lower, "line");
        if line < 0 {
            # As compilers name a place in a file: its name, a colon, the line.
            line = number_after(lower, ".map");
        }
        if line > 0 and map_text {
            spot = place_of_line(map_text, line);
            if spot is not None {
                spot.words = said;
                found.append(spot);
            }
        }
    }
    return found;
}

"""A short mark that two texts share only if they are the same, as near as
makes no difference: two sums over the letters and the length."""
def text_mark(text: str) -> str {
    first = 7;
    second = 11;
    for letter in text {
        code = ord(letter);
        first = (first * 31 + code) % 2147483647;
        second = (second * 131 + code) % 2147483629;
    }
    return str(first) + "-" + str(second) + "-" + str(len(text));
}
