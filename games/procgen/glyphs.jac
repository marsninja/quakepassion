"""A stroke font: every printable ASCII character as strokes on a grid four
units wide and six tall (the baseline at six, descenders below it), which
the 2D art draws at any size. Lower case is drawn as small capitals, as the
games' own console fonts mostly were.

A glyph is written as text: strokes split by ';', each a run of points
`x,y` split by spaces."""
import from .field { Field }
import from .canvas { stroke }

glob GLYPHS: dict[str, str] = {
    "A": "0,6 0,2 2,0 4,2 4,6;0,4 4,4",
    "B": "0,0 0,6 3,6 4,5 4,4 3,3 0,3;0,0 3,0 4,1 4,2 3,3",
    "C": "4,1 3,0 1,0 0,1 0,5 1,6 3,6 4,5",
    "D": "0,0 0,6 3,6 4,5 4,1 3,0 0,0",
    "E": "4,0 0,0 0,6 4,6;0,3 3,3",
    "F": "4,0 0,0 0,6;0,3 3,3",
    "G": "4,1 3,0 1,0 0,1 0,5 1,6 3,6 4,5 4,3 2,3",
    "H": "0,0 0,6;4,0 4,6;0,3 4,3",
    "I": "1,0 3,0;2,0 2,6;1,6 3,6",
    "J": "4,0 4,5 3,6 1,6 0,5",
    "K": "0,0 0,6;4,0 0,4;1,3 4,6",
    "L": "0,0 0,6 4,6",
    "M": "0,6 0,0 2,3 4,0 4,6",
    "N": "0,6 0,0 4,6 4,0",
    "O": "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0",
    "P": "0,6 0,0 3,0 4,1 4,2 3,3 0,3",
    "Q": "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0;2,4 4,6",
    "R": "0,6 0,0 3,0 4,1 4,2 3,3 0,3;2,3 4,6",
    "S": "4,1 3,0 1,0 0,1 0,2 1,3 3,3 4,4 4,5 3,6 1,6 0,5",
    "T": "0,0 4,0;2,0 2,6",
    "U": "0,0 0,5 1,6 3,6 4,5 4,0",
    "V": "0,0 2,6 4,0",
    "W": "0,0 1,6 2,3 3,6 4,0",
    "X": "0,0 4,6;4,0 0,6",
    "Y": "0,0 2,3 4,0;2,3 2,6",
    "Z": "0,0 4,0 0,6 4,6",
    "0": "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0;4,1 0,5",
    "1": "1,1 2,0 2,6;1,6 3,6",
    "2": "0,1 1,0 3,0 4,1 4,2 0,6 4,6",
    "3": "0,1 1,0 3,0 4,1 4,2 3,3 1,3;3,3 4,4 4,5 3,6 1,6 0,5",
    "4": "3,6 3,0 0,4 4,4",
    "5": "4,0 0,0 0,3 3,3 4,4 4,5 3,6 0,6",
    "6": "4,1 3,0 1,0 0,1 0,5 1,6 3,6 4,5 4,4 3,3 0,3",
    "7": "0,0 4,0 1,6",
    "8": "1,3 0,2 0,1 1,0 3,0 4,1 4,2 3,3 1,3 0,4 0,5 1,6 3,6 4,5 4,4 3,3",
    "9": "4,3 1,3 0,2 0,1 1,0 3,0 4,1 4,5 3,6 1,6",
    "!": "2,0 2,4;2,5.6 2,6",
    "\"": "1,0 1,1.5;3,0 3,1.5",
    "#": "1,0 1,6;3,0 3,6;0,2 4,2;0,4 4,4",
    "$": "4,1 3,0 1,0 0,1 0,2 1,3 3,3 4,4 4,5 3,6 1,6 0,5;2,-0.5 2,6.5",
    "%": "0,6 4,0;0.7,0.7 0.8,0.8;3.2,5.2 3.3,5.3",
    "&": "4,6 1,2 1,1 2,0 3,1 3,2 0,4 0,5 1,6 2,6 4,4",
    "'": "2,0 2,1.5",
    "(": "3,0 1.5,2 1.5,4 3,6",
    ")": "1,0 2.5,2 2.5,4 1,6",
    "*": "2,1 2,5;0,2 4,4;4,2 0,4",
    "+": "2,1 2,5;0,3 4,3",
    ",": "2,5.4 1.5,7",
    "-": "0.5,3 3.5,3",
    ".": "2,5.6 2,6",
    "/": "0,6 4,0",
    ":": "2,1.6 2,2;2,5.6 2,6",
    ";": "2,1.6 2,2;2,5.4 1.5,7",
    "<": "4,0 0,3 4,6",
    "=": "0,2 4,2;0,4 4,4",
    ">": "0,0 4,3 0,6",
    "?": "0,1 1,0 3,0 4,1 4,2 2,3.5 2,4;2,5.6 2,6",
    "@": "3,4 3,2 1,2 1,4 3,4 4,3 4,1 3,0 1,0 0,1 0,5 1,6 4,6",
    "[": "3,0 1,0 1,6 3,6",
    "\\": "0,0 4,6",
    "]": "1,0 3,0 3,6 1,6",
    "^": "0,2 2,0 4,2",
    "_": "0,6.6 4,6.6",
    "`": "1,0 2,1",
    "{": "3,0 2,0 1.5,1 1.5,2.5 0.5,3 1.5,3.5 1.5,5 2,6 3,6",
    "|": "2,-0.5 2,6.5",
    "}": "1,0 2,0 2.5,1 2.5,2.5 3.5,3 2.5,3.5 2.5,5 2,6 1,6",
    "~": "0,3 1,2 3,4 4,3"
};

"""A glyph's strokes in grid units; empty for a space or a character the
font has not got. Lower case is the capital, drawn as a small capital."""
def glyph_strokes(character: str) -> list[list[tuple[float, float]]] {
    key = character;
    small = False;
    if character >= "a" and character <= "z" {
        key = character.upper();
        small = True;
    }
    text = GLYPHS.get(key, "");
    strokes: list[list[tuple[float, float]]] = [];
    if not text {
        return strokes;
    }
    for part in text.split(";") {
        points: list[tuple[float, float]] = [];
        for pair in part.split() {
            xy = pair.split(",");
            x = float(xy[0]);
            y = float(xy[1]);
            if small {
                # A small capital: two thirds the height, sitting on the line.
                x = 0.5 + x * 0.75;
                y = 2.0 + y * (4.0 / 6.0);
            }
            points.append((x, y));
        }
        strokes.append(points);
    }
    return strokes;
}

"""Draw `character` into `into` with its grid's top left at (x, y), each grid
unit `unit` texels, strokes `width` texels wide."""
def draw_glyph(into: Field, character: str, x: float, y: float, unit: float, width: float) {
    placed: list[list[tuple[float, float]]] = [];
    for points in glyph_strokes(character) {
        placed.append([(x + px * unit, y + py * unit) for (px, py) in points]);
    }
    if placed {
        stroke(into, placed, width);
    }
}

"""Draw a line of text into `into`, its first character's grid at (x, y);
each character takes six units of width. Returns where the line ends."""
def draw_text(into: Field, text: str, x: float, y: float, unit: float, width: float) -> float {
    at = x;
    for character in text {
        draw_glyph(into, character, at, y, unit, width);
        at += unit * 6.0;
    }
    return at;
}

"""The width a line of text takes at `unit` texels a grid unit."""
def text_width(text: str, unit: float) -> float {
    return float(len(text)) * unit * 6.0 - unit * 2.0;
}

"""A line of text centred in a field of its own size."""
def text_mask(text: str, w: int, h: int, fill: float = 0.8) -> Field {
    made = Field(w=w, h=h);
    if not text {
        return made;
    }
    unit = min(float(w) * fill / max(1.0, float(len(text)) * 6.0 - 2.0), float(h) * fill / 7.0);
    width = max(1.0, unit * 1.1);
    x = (float(w) - text_width(text, unit)) * 0.5;
    y = (float(h) - unit * 6.0) * 0.5;
    draw_text(made, text, x, y, unit, width);
    return made;
}
