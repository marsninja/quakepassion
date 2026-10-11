"""Models written out and read in as glTF, the form engines and modelling
programs trade in now. A glTF is a description in JSON beside the numbers
it describes; a `.glb` is both in one file, which is what is written here,
and either is read. glTF's y is up and Quake's z is, so points are turned
on the way out and back on the way in.

What is written is the model as it stands at one frame: a mesh of one
primitive a part, each with its points, the way each faces, its places on
the skin and its triangles. What is read is every triangle primitive of
every mesh, as a part each; what a file says of where its meshes stand in
a scene is not followed, nor are files that keep their numbers in another
file beside them."""
import struct;
import from engine.math.vec3 { Vec3 }
import from .mesh { Mesh }

"""A JSON value: "null", "bool", "number", "text", "list" or "object". A
list's items are in `items`; an object's are too, beside their `names`."""
obj Json {
    has kind: str = "null",
        text: str = "",
        number: float = 0.0,
        items: list[Json] = [],
        names: list[str] = [];

    """An object's value of a name, or none."""
    def of(name: str) -> Json | None {
        for (place, held) in enumerate(self.names) {
            if held == name and place < len(self.items) {
                return self.items[place];
            }
        }
        return None;
    }

    """An object's whole number of a name (`otherwise` when it has none)."""
    def whole(name: str, otherwise: int = 0) -> int {
        found = self.of(name);
        return int(found.number) if found is not None and found.kind == "number" else otherwise;
    }

    """An object's words of a name (nothing when it has none)."""
    def words(name: str) -> str {
        found = self.of(name);
        return found.text if found is not None and found.kind == "text" else "";
    }

    """An object's list of a name (empty when it has none)."""
    def listed(name: str) -> list[Json] {
        found = self.of(name);
        return found.items if found is not None and found.kind == "list" else [];
    }
}

def:priv past_space(text: str, at: int) -> int {
    while at < len(text) and text[at] in " \t\r\n" {
        at += 1;
    }
    return at;
}

"""Read one value from `text` at `cursor[0]`, which is left after it. None
when what stands there is no JSON."""
def:priv json_value(text: str, cursor: list[int], deep: int = 0) -> Json | None {
    at = past_space(text, cursor[0]);
    if at >= len(text) or deep > 64 {
        return None;
    }
    mark = text[at];
    if mark == "{" or mark == "[" {
        made = Json(kind="object" if mark == "{" else "list");
        close = "}" if mark == "{" else "]";
        at = past_space(text, at + 1);
        if at < len(text) and text[at] == close {
            cursor[0] = at + 1;
            return made;
        }
        while at < len(text) {
            if mark == "{" {
                cursor[0] = at;
                key = json_value(text, cursor, deep + 1);
                if key is None or key.kind != "text" {
                    return None;
                }
                at = past_space(text, cursor[0]);
                if at >= len(text) or text[at] != ":" {
                    return None;
                }
                made.names.append(key.text);
                at += 1;
            }
            cursor[0] = at;
            held = json_value(text, cursor, deep + 1);
            if held is None {
                return None;
            }
            made.items.append(held);
            at = past_space(text, cursor[0]);
            if at < len(text) and text[at] == "," {
                at = past_space(text, at + 1);
                continue;
            }
            if at < len(text) and text[at] == close {
                cursor[0] = at + 1;
                return made;
            }
            return None;
        }
        return None;
    }
    if mark == "\"" {
        parts: list[str] = [];
        at += 1;
        while at < len(text) and text[at] != "\"" {
            if text[at] == "\\" and at + 1 < len(text) {
                follows = text[at + 1];
                if follows == "u" and at + 5 < len(text) {
                    try {
                        parts.append(chr(int(text[at + 2:at + 6], 16)));
                    } except ValueError {
                        return None;
                    }
                    at += 6;
                    continue;
                }
                parts.append("\n" if follows == "n" else ("\t" if follows == "t" else ("\r" if follows == "r" else follows)));
                at += 2;
                continue;
            }
            parts.append(text[at]);
            at += 1;
        }
        if at >= len(text) {
            return None;
        }
        cursor[0] = at + 1;
        return Json(kind="text", text="".join(parts));
    }
    for (word, kind, value) in [("true", "bool", 1.0), ("false", "bool", 0.0), ("null", "null", 0.0)] {
        if text[at:at + len(word)] == word {
            cursor[0] = at + len(word);
            return Json(kind=kind, number=value);
        }
    }
    end = at;
    while end < len(text) and text[end] in "+-0123456789.eE" {
        end += 1;
    }
    try {
        number = float(text[at:end]);
    } except ValueError {
        return None;
    }
    cursor[0] = end;
    return Json(kind="number", number=number);
}

"""JSON text as a value. None when it is not JSON, or more follows it."""
def json_read(text: str) -> Json | None {
    cursor = [0];
    made = json_value(text, cursor);
    if made is None or past_space(text, cursor[0]) != len(text) {
        return None;
    }
    return made;
}

"""Text as JSON has it between its quotes."""
def:priv json_text(words: str) -> str {
    return "\"" + words.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ") + "\"";
}

def:priv json_number(value: float) -> str {
    near = round(value, 6);
    return str(int(near)) if near == float(int(near)) else str(near);
}

"""The bytes base64 text stands for. None when it is not base64."""
def base64_bytes(text: str) -> bytes | None {
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    values: dict[str, int] = {};
    for (place, letter) in enumerate(letters) {
        values[letter] = place;
    }
    made = bytearray();
    held = 0;
    bits = 0;
    for letter in text {
        if letter == "=" or letter in " \r\n" {
            continue;
        }
        if letter not in values {
            return None;
        }
        held = (held << 6) | values[letter];
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            made.append((held >> bits) & 0xFF);
        }
    }
    return bytes(made);
}

"""The way each point of a mesh faces: the triangles round it, averaged."""
def:priv facings(mesh: Mesh) -> list[Vec3] {
    sums: list[Vec3] = [Vec3() for point in mesh.points];
    for index in range(mesh.triangles()) {
        facing = mesh.normal(index);
        for k in range(3) {
            at = mesh.corners[index * 3 + k];
            if at >= 0 and at < len(sums) {
                sums[at] = sums[at].add(facing);
            }
        }
    }
    return [total.normalized() if total.length() > 0.0001 else Vec3(z=1.0) for total in sums];
}

"""Meshes as one `.glb` file's bytes: a mesh of one primitive a part, each
part's name kept. Empty when there is nothing to write."""
def write_glb(parts: list[tuple[str, Mesh]], name: str = "model") -> bytes {
    held = [(label, mesh) for (label, mesh) in parts if len(mesh.points) > 0 and mesh.triangles() > 0];
    if len(held) == 0 {
        return b"";
    }
    numbers = bytearray();
    views: list[str] = [];
    accessors: list[str] = [];
    primitives: list[str] = [];
    for (label, mesh) in held {
        count = len(mesh.points);
        skinned = len(mesh.uvs) == count * 2;
        # The triangles, then the points, the ways they face, and their places on the skin.
        start = len(numbers);
        for corner in mesh.corners {
            numbers.extend(struct.pack("<I", corner));
        }
        views.append("{\"buffer\":0,\"byteOffset\":" + str(start) + ",\"byteLength\":" + str(len(mesh.corners) * 4) + ",\"target\":34963}");
        accessors.append("{\"bufferView\":" + str(len(views) - 1) + ",\"componentType\":5125,\"count\":" + str(len(mesh.corners)) + ",\"type\":\"SCALAR\"}");
        triangles_at = len(accessors) - 1;
        start = len(numbers);
        low = [1000000.0, 1000000.0, 1000000.0];
        high = [-1000000.0, -1000000.0, -1000000.0];
        for point in mesh.points {
            turned = [point.x, point.z, -point.y];
            for k in range(3) {
                low[k] = min(low[k], turned[k]);
                high[k] = max(high[k], turned[k]);
            }
            numbers.extend(struct.pack("<fff", turned[0], turned[1], turned[2]));
        }
        views.append("{\"buffer\":0,\"byteOffset\":" + str(start) + ",\"byteLength\":" + str(count * 12) + ",\"target\":34962}");
        accessors.append(
            "{\"bufferView\":" + str(len(views) - 1) + ",\"componentType\":5126,\"count\":" + str(count) + ",\"type\":\"VEC3\",\"min\":["
                + ",".join([json_number(value) for value in low]) + "],\"max\":[" + ",".join([json_number(value) for value in high]) + "]}"
        );
        words = "\"POSITION\":" + str(len(accessors) - 1);
        start = len(numbers);
        for facing in facings(mesh) {
            numbers.extend(struct.pack("<fff", facing.x, facing.z, -facing.y));
        }
        views.append("{\"buffer\":0,\"byteOffset\":" + str(start) + ",\"byteLength\":" + str(count * 12) + ",\"target\":34962}");
        accessors.append("{\"bufferView\":" + str(len(views) - 1) + ",\"componentType\":5126,\"count\":" + str(count) + ",\"type\":\"VEC3\"}");
        words += ",\"NORMAL\":" + str(len(accessors) - 1);
        if skinned {
            start = len(numbers);
            for place in mesh.uvs {
                numbers.extend(struct.pack("<f", place));
            }
            views.append("{\"buffer\":0,\"byteOffset\":" + str(start) + ",\"byteLength\":" + str(count * 8) + ",\"target\":34962}");
            accessors.append("{\"bufferView\":" + str(len(views) - 1) + ",\"componentType\":5126,\"count\":" + str(count) + ",\"type\":\"VEC2\"}");
            words += ",\"TEXCOORD_0\":" + str(len(accessors) - 1);
        }
        primitives.append("{\"attributes\":{" + words + "},\"indices\":" + str(triangles_at) + ",\"mode\":4,\"extras\":{\"part\":" + json_text(label) + "}}");
    }
    told = "{\"asset\":{\"version\":\"2.0\",\"generator\":\"QuakePassion studio\"},\"scene\":0,\"scenes\":[{\"nodes\":[0]}],\"nodes\":[{\"mesh\":0,\"name\":"
        + json_text(name) + "}],\"meshes\":[{\"name\":" + json_text(name) + ",\"primitives\":[" + ",".join(primitives)
        + "]}],\"buffers\":[{\"byteLength\":" + str(len(numbers)) + "}],\"bufferViews\":[" + ",".join(views) + "],\"accessors\":["
        + ",".join(accessors) + "]}";
    described = bytearray(told.encode("utf-8"));
    while len(described) % 4 != 0 {
        described.extend(b" ");
    }
    while len(numbers) % 4 != 0 {
        numbers.extend(b"\x00");
    }
    out = bytearray(b"glTF");
    out.extend(struct.pack("<II", 2, 12 + 8 + len(described) + 8 + len(numbers)));
    out.extend(struct.pack("<II", len(described), 0x4E4F534A));
    out.extend(described);
    out.extend(struct.pack("<II", len(numbers), 0x004E4942));
    out.extend(numbers);
    return bytes(out);
}

"""One accessor's numbers, so many to an item. Empty when it cannot be read
(numbers kept in another file, a kind this does not read, a view that runs
past its buffer)."""
def:priv accessor_numbers(told: Json, buffers: list[bytes], index: int, each: int) -> list[float] {
    accessors = told.listed("accessors");
    if index < 0 or index >= len(accessors) {
        return [];
    }
    accessor = accessors[index];
    kinds = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4};
    if kinds.get(accessor.words("type"), 0) != each or accessor.of("sparse") is not None {
        return [];
    }
    views = told.listed("bufferViews");
    view_at = accessor.whole("bufferView", -1);
    if view_at < 0 or view_at >= len(views) {
        return [];
    }
    view = views[view_at];
    buffer_at = view.whole("buffer", 0);
    if buffer_at < 0 or buffer_at >= len(buffers) {
        return [];
    }
    data = buffers[buffer_at];
    component = accessor.whole("componentType", 0);
    sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4};
    if component not in sizes {
        return [];
    }
    size = sizes[component];
    count = accessor.whole("count", 0);
    stride = view.whole("byteStride", 0);
    if stride <= 0 {
        stride = size * each;
    }
    start = view.whole("byteOffset", 0) + accessor.whole("byteOffset", 0);
    if count <= 0 or start < 0 or start + (count - 1) * stride + size * each > len(data) {
        return [];
    }
    found: list[float] = [];
    for item in range(count) {
        for k in range(each) {
            at = start + item * stride + k * size;
            # A byte, two or four, with or without a sign, or a float: glTF's six kinds of number.
            if component == 5126 {
                found.append(float(struct.unpack("<f", data[at:at + 4])[0]));
            } elif component == 5125 {
                found.append(float(struct.unpack("<I", data[at:at + 4])[0]));
            } elif component == 5123 {
                found.append(float(struct.unpack("<H", data[at:at + 2])[0]));
            } elif component == 5122 {
                found.append(float(struct.unpack("<h", data[at:at + 2])[0]));
            } elif component == 5121 {
                found.append(float(int(data[at])));
            } else {
                found.append(float(int(data[at]) - 256 if int(data[at]) > 127 else int(data[at])));
            }
        }
    }
    return found;
}

"""A glTF's meshes as parts: the bytes of a `.glb`, or of a `.gltf` that
keeps its numbers inside itself. None when it is neither, or holds no
triangles this reads."""
def read_gltf(data: bytes) -> list[tuple[str, Mesh]] | None {
    told: Json | None = None;
    buffers: list[bytes] = [];
    inside = b"";
    if data[:4] == b"glTF" and len(data) >= 20 {
        at = 12;
        while at + 8 <= len(data) {
            size = int(struct.unpack("<I", data[at:at + 4])[0]);
            kind = int(struct.unpack("<I", data[at + 4:at + 8])[0]);
            chunk = data[at + 8:at + 8 + size];
            if kind == 0x4E4F534A {
                try {
                    told = json_read(chunk.decode("utf-8"));
                } except Exception {
                    told = None;
                }
            } elif kind == 0x004E4942 and len(inside) == 0 {
                inside = chunk;
            }
            at += 8 + size + ((4 - size % 4) % 4);
        }
    } else {
        try {
            told = json_read(data.decode("utf-8"));
        } except Exception {
            told = None;
        }
    }
    if told is None or told.kind != "object" {
        return None;
    }
    for (place, buffer) in enumerate(told.listed("buffers")) {
        source = buffer.words("uri");
        if not source {
            buffers.append(inside if place == 0 else b"");
        } elif source.startswith("data:") and ";base64," in source {
            decoded = base64_bytes(source.split(";base64,")[1]);
            buffers.append(decoded if decoded is not None else b"");
        } else {
            # Numbers kept in a file beside this one are not gone after.
            buffers.append(b"");
        }
    }
    found: list[tuple[str, Mesh]] = [];
    for (number, mesh) in enumerate(told.listed("meshes")) {
        label = mesh.words("name");
        for (piece, primitive) in enumerate(mesh.listed("primitives")) {
            if primitive.whole("mode", 4) != 4 {
                continue;
            }
            attributes = primitive.of("attributes");
            if attributes is None {
                continue;
            }
            places = accessor_numbers(told, buffers, attributes.whole("POSITION", -1), 3);
            if len(places) < 9 {
                continue;
            }
            made = Mesh();
            for at in range(len(places) // 3) {
                made.points.append(Vec3(x=places[at * 3], y=-places[at * 3 + 2], z=places[at * 3 + 1]));
            }
            skin = accessor_numbers(told, buffers, attributes.whole("TEXCOORD_0", -1), 2);
            if len(skin) == len(made.points) * 2 {
                made.uvs = skin;
            }
            if primitive.of("indices") is not None {
                made.corners = [int(value) for value in accessor_numbers(told, buffers, primitive.whole("indices", -1), 1)];
            } else {
                made.corners = list(range(len(made.points)));
            }
            made.corners = made.corners[:len(made.corners) - len(made.corners) % 3];
            if len(made.corners) == 0 or len([corner for corner in made.corners if corner < 0 or corner >= len(made.points)]) > 0 {
                continue;
            }
            extras = primitive.of("extras");
            called = extras.words("part") if extras is not None else "";
            if not called {
                called = (label if label else "mesh " + str(number)) + (" " + str(piece) if piece > 0 else "");
            }
            found.append((called, made));
        }
    }
    return found if len(found) > 0 else None;
}
