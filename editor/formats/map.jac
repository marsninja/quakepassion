"""The .map text format: entities as key/value pairs, each holding the
brushes that make it.

Read and written here in its classic form (Quake, with Quake II's three
trailing numbers) and its Valve 220 form, whose faces carry their texture
axes outright; a face read in either form reads back out as it was. The
studio's own scenes are .map files in the Valve 220 form, so every other
Quake editor can open them."""
import from engine.math.vec3 { Vec3 }
import from ..geometry.brush { Side, Mapping, Plane3, plane_through, classic_mapping, brush_windings }

"""A curved patch as a Quake III map keeps it: `width` by `height` control
points, row by row, and its material."""
obj MapPatch {
    has width: int = 0,
        height: int = 0,
        points: list[Vec3] = [],
        material: str = "";
}

"""One entity of a map: its fields in order, its brushes (each the list of
its sides), and its curved patches."""
obj MapItem {
    has fields: dict[str, str] = {},
        brushes: list[list[Side]] = [],
        patches: list[MapPatch] = [];
}

"""A map as read: its entities, and what could not be read."""
obj MapFile {
    has items: list[MapItem] = [],
        # "valve" when any face was written with texture axes, else "classic".
        form: str = "classic",
        # Blocks left out: Quake III's brushDef and patchDef2 are not read yet.
        skipped: int = 0;
}

"""The words of a map: quoted strings (marked by a leading quote), brackets
and parentheses on their own, and everything else split at spaces. A brace
counts only when it stands alone, since texture names may begin with one."""
def map_tokens(text: str) -> list[str] {
    tokens: list[str] = [];
    count = len(text);
    i = 0;
    while i < count {
        c = text[i];
        if c == " " or c == "\t" or c == "\n" or c == "\r" {
            i += 1;
            continue;
        }
        if c == "/" and i + 1 < count and text[i + 1] == "/" {
            while i < count and text[i] != "\n" {
                i += 1;
            }
            continue;
        }
        if c == "\"" {
            close = text.find("\"", i + 1);
            if close < 0 {
                close = count;
            }
            tokens.append("\"" + text[i + 1:close]);
            i = close + 1;
            continue;
        }
        if c == "(" or c == ")" or c == "[" or c == "]" {
            tokens.append(c);
            i += 1;
            continue;
        }
        start = i;
        while i < count and text[i] not in [" ", "\t", "\n", "\r", "(", ")", "[", "]"] {
            i += 1;
        }
        tokens.append(text[start:i]);
    }
    return tokens;
}

"""Reads a token list from where it stands."""
obj MapCursor {
    has tokens: list[str],
        at: int = 0;

    def more -> bool {
        return self.at < len(self.tokens);
    }

    def peek -> str {
        return self.tokens[self.at] if self.at < len(self.tokens) else "";
    }

    def take -> str {
        word = self.peek();
        self.at += 1;
        return word;
    }

    def expect(word: str) {
        found = self.take();
        if found != word {
            raise ValueError("Map: expected " + word + " and found " + (found if found else "the end"));
        }
    }

    def number -> float {
        word = self.take();
        try {
            return float(word);
        } except ValueError {
            raise ValueError("Map: expected a number and found " + (word if word else "the end"));
        }
    }

    def point -> Vec3 {
        self.expect("(");
        x = self.number();
        y = self.number();
        z = self.number();
        self.expect(")");
        return Vec3(x=x, y=y, z=z);
    }

    """Pass over a block already opened, with whatever it nests."""
    def skip_block {
        depth = 1;
        while self.more() and depth > 0 {
            word = self.take();
            if word == "{" {
                depth += 1;
            } elif word == "}" {
                depth -= 1;
            }
        }
    }
}

"""Read one face: three points, a texture name, and its mapping in either
form. None when the points are in a line."""
def read_side(cursor: MapCursor, found: MapFile) -> Side | None {
    a = cursor.point();
    b = cursor.point();
    c = cursor.point();
    material = cursor.take();
    if material.startswith("\"") {
        material = material[1:];
    }
    plane = plane_through(a, b, c);
    mapping = Mapping();
    if cursor.peek() == "[" {
        found.form = "valve";
        cursor.expect("[");
        s_axis = Vec3(x=cursor.number(), y=cursor.number(), z=cursor.number());
        s_shift = cursor.number();
        cursor.expect("]");
        cursor.expect("[");
        t_axis = Vec3(x=cursor.number(), y=cursor.number(), z=cursor.number());
        t_shift = cursor.number();
        cursor.expect("]");
        rotation = cursor.number();
        s_scale = cursor.number();
        t_scale = cursor.number();
        mapping = Mapping(
            s_axis=s_axis,
            t_axis=t_axis,
            s_shift=s_shift,
            t_shift=t_shift,
            s_scale=s_scale if s_scale != 0.0 else 1.0,
            t_scale=t_scale if t_scale != 0.0 else 1.0,
            rotation=rotation
        );
    } else {
        s_shift = cursor.number();
        t_shift = cursor.number();
        rotation = cursor.number();
        s_scale = cursor.number();
        t_scale = cursor.number();
        if plane is not None {
            mapping = classic_mapping(plane.normal, s_shift, t_shift, rotation, s_scale, t_scale);
        }
    }
    side_contents = 0;
    side_flags = 0;
    side_value = 0;
    # Quake II's contents, surface flags and value follow when present.
    if cursor.more() and map_number(cursor.peek()) {
        side_contents = int(cursor.number());
        if cursor.more() and map_number(cursor.peek()) {
            side_flags = int(cursor.number());
        }
        if cursor.more() and map_number(cursor.peek()) {
            side_value = int(cursor.number());
        }
    }
    if plane is None {
        return None;
    }
    return Side(
        plane=plane,
        points=[a, b, c],
        material=material,
        mapping=mapping,
        contents=side_contents,
        flags=side_flags,
        value=side_value
    );
}

"""Whether a word is a number (and so not the start of the next face)."""
def map_number(word: str) -> bool {
    if not word or word in ["(", ")", "{", "}", "[", "]"] or word.startswith("\"") {
        return False;
    }
    try {
        float(word);
        return True;
    } except ValueError {
        return False;
    }
}

"""Read a map's text."""
def read_map(text: str) -> MapFile {
    found = MapFile();
    cursor = MapCursor(tokens=map_tokens(text));
    while cursor.more() {
        cursor.expect("{");
        item = MapItem();
        while cursor.more() and cursor.peek() != "}" {
            word = cursor.take();
            if word.startswith("\"") {
                value = cursor.take();
                if not value.startswith("\"") {
                    raise ValueError("Map: the field " + word[1:] + " has no value");
                }
                item.fields[word[1:]] = value[1:];
            } elif word == "{" {
                if cursor.peek() == "patchDef2" {
                    cursor.take();
                    patch = read_patch(cursor);
                    cursor.expect("}");
                    if patch is not None {
                        item.patches.append(patch);
                    } else {
                        found.skipped += 1;
                    }
                    continue;
                }
                if cursor.peek() == "brushDef" {
                    cursor.take();
                    primitive = read_primitive(cursor);
                    cursor.expect("}");
                    if len(primitive) >= 4 {
                        item.brushes.append(primitive);
                    }
                    continue;
                }
                if cursor.peek() != "(" {
                    # A block of a kind this does not read.
                    found.skipped += 1;
                    cursor.skip_block();
                    continue;
                }
                sides: list[Side] = [];
                while cursor.more() and cursor.peek() == "(" {
                    side = read_side(cursor, found);
                    if side is not None {
                        sides.append(side);
                    }
                }
                cursor.expect("}");
                if len(sides) >= 4 {
                    item.brushes.append(sides);
                }
            } else {
                raise ValueError("Map: unexpected " + word + " in an entity");
            }
        }
        cursor.expect("}");
        found.items.append(item);
    }
    return found;
}

"""A Quake III curved patch, from after its `patchDef2` word to the brace
that closes it: the material, the size, then `width` rows of `height`
control points, each a place and two texture coordinates. Kept row by row
of `width` points. None when the size is not odd by odd."""
def read_patch(cursor: MapCursor) -> MapPatch | None {
    cursor.expect("{");
    material = cursor.take();
    if material.startswith("\"") {
        material = material[1:];
    }
    cursor.expect("(");
    width = int(cursor.number());
    height = int(cursor.number());
    while cursor.more() and cursor.peek() != ")" {
        cursor.take();
    }
    cursor.expect(")");
    columns: list[list[Vec3]] = [];
    cursor.expect("(");
    while cursor.more() and cursor.peek() == "(" {
        cursor.expect("(");
        column: list[Vec3] = [];
        while cursor.more() and cursor.peek() == "(" {
            cursor.expect("(");
            column.append(Vec3(x=cursor.number(), y=cursor.number(), z=cursor.number()));
            # Its texture coordinates, and anything a later format adds.
            while cursor.more() and cursor.peek() != ")" {
                cursor.take();
            }
            cursor.expect(")");
        }
        cursor.expect(")");
        columns.append(column);
    }
    cursor.expect(")");
    cursor.expect("}");
    if width < 3 or height < 3 or width % 2 == 0 or height % 2 == 0 or len(columns) != width {
        return None;
    }
    points: list[Vec3] = [];
    for row in range(height) {
        for column in columns {
            if len(column) != height {
                return None;
            }
            points.append(column[row]);
        }
    }
    return MapPatch(width=width, height=height, points=points, material=material);
}

"""A Quake III brush written as `brushDef`: each side three points, a
texture matrix and a material. The matrix is not kept: the material lies as
it would on a new brush."""
def read_primitive(cursor: MapCursor) -> list[Side] {
    sides: list[Side] = [];
    cursor.expect("{");
    while cursor.more() and cursor.peek() == "(" {
        a = cursor.point();
        b = cursor.point();
        c = cursor.point();
        cursor.expect("(");
        for row in range(2) {
            cursor.expect("(");
            while cursor.more() and cursor.peek() != ")" {
                cursor.take();
            }
            cursor.expect(")");
        }
        cursor.expect(")");
        material = cursor.take();
        if material.startswith("\"") {
            material = material[1:];
        }
        # Its contents, flags and value, when it has them.
        while cursor.more() and cursor.peek() != "(" and cursor.peek() != "}" {
            cursor.take();
        }
        plane = plane_through(a, b, c);
        if plane is not None {
            sides.append(
                Side(
                    plane=plane,
                    points=[a, b, c],
                    material=material,
                    mapping=classic_mapping(plane.normal, 0.0, 0.0, 0.0, 1.0, 1.0)
                )
            );
        }
    }
    cursor.expect("}");
    return sides;
}

"""A number as a map writes it: whole when it is whole, else to six places
without trailing zeros."""
def map_decimal(value: float) -> str {
    nearest = round(value);
    if abs(value - float(nearest)) < 0.000001 {
        return str(int(nearest));
    }
    text = str(round(value, 6));
    if "e" in text or "E" in text {
        return "0";
    }
    if "." in text {
        text = text.rstrip("0").rstrip(".");
    }
    return text;
}

def:priv map_point(point: Vec3) -> str {
    return "( " + map_decimal(point.x) + " " + map_decimal(point.y) + " " + map_decimal(point.z) + " )";
}

"""Three points of a side for writing: the ones it was read with, else three
corners of its outline, which lie on its plane in the map's winding."""
def side_points(side: Side, outline: list[Vec3]) -> list[Vec3] {
    if len(side.points) == 3 {
        return side.points;
    }
    if len(outline) >= 3 {
        return [outline[0], outline[1], outline[2]];
    }
    return [];
}

"""Write a map. `form` is "valve" (texture axes on every face) or "classic";
`quake2` adds each face's contents, flags and value. Without `comments` the
lines that number entities and brushes are left out, and with `whole` every
plane point is written as whole numbers, for tools that read nothing else."""
def write_map(
    items: list[MapItem], form: str = "valve", quake2: bool = False, comments: bool = True, whole: bool = False
) -> str {
    lines: list[str] = [];
    if form == "valve" {
        # What other editors look for to pick the form.
        lines.append("// Format: Valve");
    }
    for (index, item) in enumerate(items) {
        if comments {
            lines.append("// entity " + str(index));
        }
        lines.append("{");
        for (key, value) in item.fields.items() {
            if form == "valve" and index == 0 and key == "mapversion" {
                continue;
            }
            lines.append("\"" + key.replace("\"", "") + "\" \"" + value.replace("\"", "") + "\"");
        }
        if form == "valve" and index == 0 {
            lines.append("\"mapversion\" \"220\"");
        }
        for (number, sides) in enumerate(item.brushes) {
            outlines = brush_windings(sides);
            if comments {
                lines.append("// brush " + str(number));
            }
            lines.append("{");
            for (which, side) in enumerate(sides) {
                points = side_points(side, outlines[which]);
                if len(points) != 3 {
                    continue;
                }
                mapping = side.mapping;
                if whole {
                    points = [
                        Vec3(x=float(round(point.x)), y=float(round(point.y)), z=float(round(point.z)))
                        for point in points
                    ];
                }
                words = map_point(points[0]) + " " + map_point(points[1]) + " " + map_point(points[2]) + " "
                    + (side.material if side.material else "__TB_empty");
                if form == "valve" {
                    words += " [ " + map_decimal(mapping.s_axis.x) + " " + map_decimal(mapping.s_axis.y) + " "
                        + map_decimal(mapping.s_axis.z) + " " + map_decimal(mapping.s_shift) + " ] [ "
                        + map_decimal(mapping.t_axis.x) + " " + map_decimal(mapping.t_axis.y) + " "
                        + map_decimal(mapping.t_axis.z) + " " + map_decimal(mapping.t_shift) + " ]";
                } else {
                    words += " " + map_decimal(mapping.s_shift) + " " + map_decimal(mapping.t_shift);
                }
                words += " " + map_decimal(mapping.rotation) + " " + map_decimal(mapping.s_scale) + " "
                    + map_decimal(mapping.t_scale);
                if quake2 or side.contents != 0 or side.flags != 0 or side.value != 0 {
                    # A side that carries any of the three keeps them, whatever the map is for.
                    words += " " + str(side.contents) + " " + str(side.flags) + " " + str(side.value);
                }
                lines.append(words);
            }
            lines.append("}");
        }
        lines.append("}");
    }
    return "\n".join(lines) + "\n";
}
