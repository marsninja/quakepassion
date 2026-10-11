"""The .map text format: entities as key/value pairs, each holding the
brushes that make it.

Read and written here in its classic form (Quake, with Quake II's three
trailing numbers) and its Valve 220 form, whose faces carry their texture
axes outright; a face read in either form reads back out as it was. The
studio's own scenes are .map files in the Valve 220 form, so every other
Quake editor can open them."""
import from engine.math.vec3 { Vec3 }
import from ..geometry.brush { Side, Mapping, Plane3, plane_through, classic_mapping, brush_windings }
import from ..geometry.primitive { mapping_of_primitive, primitive_of_mapping }

"""A curved patch as a Quake III map keeps it: `width` by `height` control
points, row by row, and its material."""
obj MapPatch {
    has width: int = 0,
        height: int = 0,
        points: list[Vec3] = [],
        material: str = "",
        # Where each control point lies on the material, in texels, two
        # numbers a point in the order of `points`; empty when not said.
        places: list[float] = [];
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
        # "valve" when any face was written with texture axes, "primitives"
        # when any brush was a Quake III brushDef, else "classic".
        form: str = "classic",
        # Blocks of a kind that is not read.
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
def read_map(text: str, sizes: dict[str, list[int]] = {}) -> MapFile {
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
                    patch = read_patch(cursor, sizes);
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
                    primitive = read_primitive(cursor, sizes);
                    cursor.expect("}");
                    found.form = "primitives";
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
def read_patch(cursor: MapCursor, sizes: dict[str, list[int]] = {}) -> MapPatch | None {
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
    # Beside each point, where it lies on the texture, in whole repeats of it.
    shares: list[list[Vec3]] = [];
    cursor.expect("(");
    while cursor.more() and cursor.peek() == "(" {
        cursor.expect("(");
        column: list[Vec3] = [];
        laid: list[Vec3] = [];
        while cursor.more() and cursor.peek() == "(" {
            cursor.expect("(");
            column.append(Vec3(x=cursor.number(), y=cursor.number(), z=cursor.number()));
            if cursor.more() and map_number(cursor.peek()) {
                across = cursor.number();
                laid.append(Vec3(x=across, y=cursor.number() if cursor.more() and map_number(cursor.peek()) else 0.0));
            }
            # Anything a later format adds.
            while cursor.more() and cursor.peek() != ")" {
                cursor.take();
            }
            cursor.expect(")");
        }
        cursor.expect(")");
        columns.append(column);
        shares.append(laid);
    }
    cursor.expect(")");
    cursor.expect("}");
    if width < 3 or height < 3 or width % 2 == 0 or height % 2 == 0 or len(columns) != width {
        return None;
    }
    points: list[Vec3] = [];
    places: list[float] = [];
    size = sizes.get(material, [64, 64]);
    said = len([laid for laid in shares if len(laid) == height]) == width;
    for row in range(height) {
        for (place, column) in enumerate(columns) {
            if len(column) != height {
                return None;
            }
            points.append(column[row]);
            if said {
                places.append(shares[place][row].x * float(size[0]));
                places.append(shares[place][row].y * float(size[1]));
            }
        }
    }
    return MapPatch(width=width, height=height, points=points, material=material, places=places);
}

"""A Quake III brush written as `brushDef`: each side three points, a
texture matrix and a material. The matrix says how the material lies in
repeats of its texture, so the texture's size is wanted to read it: `sizes`
gives it by the material's name as the file has it (64 by 64 when it does
not)."""
def read_primitive(cursor: MapCursor, sizes: dict[str, list[int]] = {}) -> list[Side] {
    sides: list[Side] = [];
    cursor.expect("{");
    while cursor.more() and cursor.peek() == "(" {
        a = cursor.point();
        b = cursor.point();
        c = cursor.point();
        cursor.expect("(");
        matrix: list[float] = [];
        for row in range(2) {
            cursor.expect("(");
            while cursor.more() and cursor.peek() != ")" {
                word = cursor.take();
                if map_number(word) {
                    matrix.append(float(word));
                }
            }
            cursor.expect(")");
        }
        cursor.expect(")");
        material = cursor.take();
        if material.startswith("\"") {
            material = material[1:];
        }
        # Its contents, flags and value, when it has them.
        extras: list[int] = [];
        while cursor.more() and cursor.peek() != "(" and cursor.peek() != "}" {
            word = cursor.take();
            if map_number(word) {
                extras.append(int(float(word)));
            }
        }
        plane = plane_through(a, b, c);
        if plane is not None {
            size = sizes.get(material, [64, 64]);
            sides.append(
                Side(
                    plane=plane,
                    points=[a, b, c],
                    material=material,
                    mapping=mapping_of_primitive(plane, matrix, size[0], size[1]),
                    contents=extras[0] if len(extras) > 0 else 0,
                    flags=extras[1] if len(extras) > 1 else 0,
                    value=extras[2] if len(extras) > 2 else 0
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

"""A number of a texture matrix: to ten places, since a step of a unit is a
small share of a texture and maps are large."""
def:priv map_fine(value: float) -> str {
    text = str(round(value, 10));
    if "e" in text or "E" in text {
        return "0";
    }
    if "." in text {
        text = text.rstrip("0").rstrip(".");
    }
    return "0" if text in ["-0", ""] else text;
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

"""The materials a map names, each once, in the order met: its brushes'
sides and its patches."""
def map_materials(items: list[MapItem]) -> list[str] {
    found: list[str] = [];
    for item in items {
        for sides in item.brushes {
            for side in sides {
                if side.material not in found {
                    found.append(side.material);
                }
            }
        }
        for patch in item.patches {
            if patch.material not in found {
                found.append(patch.material);
            }
        }
    }
    return found;
}

"""A patch as a `patchDef2` block's lines: its material, its size, and its
control points a column at a time, each with its place on the texture in
repeats. Without places of its own the texture is spread once over it."""
def:priv patch_lines(patch: MapPatch, size: list[int]) -> list[str] {
    lines = ["{", "patchDef2", "{", patch.material if patch.material else "__TB_empty"];
    lines.append("( " + str(patch.width) + " " + str(patch.height) + " 0 0 0 )");
    lines.append("(");
    said = len(patch.places) == patch.width * patch.height * 2;
    for column in range(patch.width) {
        words = "(";
        for row in range(patch.height) {
            at = row * patch.width + column;
            point = patch.points[at];
            across = patch.places[at * 2] / float(max(1, size[0])) if said else float(column) / float(max(1, patch.width - 1));
            down = patch.places[at * 2 + 1] / float(max(1, size[1])) if said else float(row) / float(max(1, patch.height - 1));
            words += " ( " + map_decimal(point.x) + " " + map_decimal(point.y) + " " + map_decimal(point.z) + " "
                + map_fine(across) + " " + map_fine(down) + " )";
        }
        lines.append(words + " )");
    }
    lines.append(")");
    lines.append("}");
    lines.append("}");
    return lines;
}

"""Write a map. `form` is "valve" (texture axes on every face), "classic",
or "primitives" (Quake III's `brushDef`, a matrix a face, for which `sizes`
gives each material's texture size by its name; 64 by 64 when it does not);
`quake2` adds each face's contents, flags and value. Without `comments` the
lines that number entities and brushes are left out, and with `whole` every
plane point is written as whole numbers, for tools that read nothing else.
An entity's curved patches are written as `patchDef2` in any form."""
def write_map(
    items: list[MapItem], form: str = "valve", quake2: bool = False, comments: bool = True, whole: bool = False,
    sizes: dict[str, list[int]] = {}
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
            if form == "primitives" {
                lines.append("brushDef");
                lines.append("{");
            }
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
                if form == "primitives" {
                    size = sizes.get(side.material, [64, 64]);
                    matrix = primitive_of_mapping(side.plane, mapping, size[0], size[1]);
                    lines.append(
                        map_point(points[0]) + " " + map_point(points[1]) + " " + map_point(points[2]) + " ( ( "
                            + map_fine(matrix[0]) + " " + map_fine(matrix[1]) + " " + map_fine(matrix[2]) + " ) ( "
                            + map_fine(matrix[3]) + " " + map_fine(matrix[4]) + " " + map_fine(matrix[5]) + " ) ) "
                            + (side.material if side.material else "__TB_empty") + " " + str(side.contents) + " "
                            + str(side.flags) + " " + str(side.value)
                    );
                    continue;
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
            if form == "primitives" {
                lines.append("}");
            }
            lines.append("}");
        }
        for patch in item.patches {
            if patch.width * patch.height == len(patch.points) and patch.width >= 3 and patch.height >= 3 {
                lines.extend(patch_lines(patch, sizes.get(patch.material, [64, 64])));
            }
        }
        lines.append("}");
    }
    return "\n".join(lines) + "\n";
}

"""A map with its materials called other names: every side and patch whose
material `names` has takes the name it gives; the rest keep theirs."""
def map_renamed(items: list[MapItem], names: dict[str, str]) -> list[MapItem] {
    made: list[MapItem] = [];
    for item in items {
        brushes: list[list[Side]] = [];
        for sides in item.brushes {
            brushes.append(
                [
                    Side(
                        plane=side.plane,
                        points=side.points,
                        material=names.get(side.material, side.material),
                        mapping=side.mapping,
                        contents=side.contents,
                        flags=side.flags,
                        value=side.value
                    )
                    for side in sides
                ]
            );
        }
        patches = [
            MapPatch(
                width=bent.width, height=bent.height, points=bent.points, material=names.get(bent.material, bent.material),
                places=bent.places
            )
            for bent in item.patches
        ];
        made.append(MapItem(fields=dict(item.fields), brushes=brushes, patches=patches));
    }
    return made;
}
