import struct;
import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh, mesh_volume, open_edges }
import from editor.model.gltf { Json, json_read, base64_bytes, write_glb, read_gltf }

def about(a: float, b: float, slack: float = 0.001) -> bool {
    return abs(a - b) < slack;
}

"""A box 64 by 32 by 16 with a corner on the origin, its skin laid from above."""
def crate -> Mesh {
    made = Mesh();
    for z in [0.0, 16.0] {
        for (x, y) in [(0.0, 0.0), (64.0, 0.0), (64.0, 32.0), (0.0, 32.0)] {
            made.points.append(Vec3(x=x, y=y, z=z));
            made.uvs.append(x / 64.0);
            made.uvs.append(y / 32.0);
        }
    }
    made.corners = [
        0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7
    ];
    return made;
}

test "JSON is read into values, and what is not JSON is refused" {
    told = json_read(" {\"name\": \"a \\\"box\\\"\\n\", \"count\": 3, \"sizes\": [1.5, -2e2, 0], \"on\": true, \"none\": null, \"in\": {\"deep\": [[]]}} ");
    assert told is not None and told.kind == "object" and told.names == ["name", "count", "sizes", "on", "none", "in"];
    assert told.words("name") == "a \"box\"\n" and told.whole("count") == 3 and told.whole("missing", 7) == 7 and told.words("count") == "";
    sizes = told.listed("sizes");
    assert len(sizes) == 3 and about(sizes[0].number, 1.5) and about(sizes[1].number, -200.0) and told.listed("name") == [];
    on = told.of("on");
    deep = told.of("in");
    assert on is not None and on.kind == "bool" and on.number == 1.0 and deep is not None and len(deep.listed("deep")) == 1;
    assert told.of("none") is not None and told.of("nowhere") is None;
    letter = json_read("\"\\u0041b\"");
    assert letter is not None and letter.text == "Ab";
    for wrong in ["", "{", "[1,]", "{\"a\" 1}", "{1: 2}", "[1] 2", "\"open", "nope", "{\"a\": }"] {
        assert json_read(wrong) is None , wrong;
    }
    assert json_read("[]") is not None and json_read("  42  ") is not None;
}

test "base64 text is its bytes" {
    assert base64_bytes("aGVsbG8=") == b"hello" and base64_bytes("aGVsbG8h") == b"hello!" and base64_bytes("") == b"";
    assert base64_bytes("AAEC/w==") == bytes([0, 1, 2, 255]) and base64_bytes("aGVs\nbG8=") == b"hello";
    assert base64_bytes("not base64!") is None;
}

test "a model written as a glb is read back as it was, part for part" {
    box = crate();
    lid = Mesh(points=[Vec3(z=20.0), Vec3(x=8.0, z=20.0), Vec3(x=4.0, y=8.0, z=20.0)], corners=[0, 1, 2]);
    data = write_glb([("box", box), ("lid \"one\"", lid), ("nothing", Mesh())], "crate");
    assert data[:4] == b"glTF" and len(data) % 4 == 0 and int(struct.unpack("<I", data[8:12])[0]) == len(data);
    assert int(struct.unpack("<I", data[16:20])[0]) == 0x4E4F534A;
    read = read_gltf(data);
    assert read is not None and len(read) == 2 and read[0][0] == "box" and read[1][0] == "lid \"one\"";
    again = read[0][1];
    assert again.corners == box.corners and len(again.points) == 8 and len(again.uvs) == 16;
    for (index, point) in enumerate(box.points) {
        assert about(again.points[index].sub(point).length(), 0.0);
        assert about(again.uvs[index * 2], box.uvs[index * 2]) and about(again.uvs[index * 2 + 1], box.uvs[index * 2 + 1]);
    }
    assert about(mesh_volume(again), 32768.0, 0.1) and open_edges(again) == 0;
    # The part with no skin comes back with none; the empty one was not written.
    assert read[1][1].uvs == [] and read[1][1].corners == [0, 1, 2] and about(read[1][1].points[2].y, 8.0);
    assert write_glb([], "none") == b"" and write_glb([("flat", Mesh(points=[Vec3()]))]) == b"";
}

test "a gltf that keeps its numbers inside itself is read, and y is up in it" {
    # One triangle standing in glTF's x-y plane (y up), its corners counted with two bytes each.
    numbers = struct.pack("<HHH", 0, 1, 2) + b"\x00\x00" + struct.pack("<fffffffff", 0.0, 0.0, 0.0, 4.0, 0.0, 0.0, 0.0, 8.0, 0.0);
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    packed = "";
    for at in range(0, len(numbers), 3) {
        trio = numbers[at:at + 3];
        value = 0;
        for k in range(3) {
            value = (value << 8) | (int(trio[k]) if k < len(trio) else 0);
        }
        packed += letters[(value >> 18) & 63] + letters[(value >> 12) & 63];
        packed += letters[(value >> 6) & 63] if len(trio) > 1 else "=";
        packed += letters[value & 63] if len(trio) > 2 else "=";
    }
    text = "{\"asset\": {\"version\": \"2.0\"}, \"meshes\": [{\"name\": \"flag\", \"primitives\": [{\"attributes\": {\"POSITION\": 1}, \"indices\": 0}, "
        + "{\"attributes\": {\"POSITION\": 1}, \"mode\": 1}]}], \"buffers\": [{\"byteLength\": 44, \"uri\": \"data:application/octet-stream;base64,"
        + packed + "\"}], \"bufferViews\": [{\"buffer\": 0, \"byteOffset\": 0, \"byteLength\": 6}, {\"buffer\": 0, \"byteOffset\": 8, \"byteLength\": 36}], "
        + "\"accessors\": [{\"bufferView\": 0, \"componentType\": 5123, \"count\": 3, \"type\": \"SCALAR\"}, "
        + "{\"bufferView\": 1, \"componentType\": 5126, \"count\": 3, \"type\": \"VEC3\"}]}";
    read = read_gltf(text.encode("utf-8"));
    assert read is not None and len(read) == 1 and read[0][0] == "flag";
    flag = read[0][1];
    assert flag.corners == [0, 1, 2] and about(flag.points[1].x, 4.0) and about(flag.points[2].z, 8.0) and about(flag.points[2].y, 0.0);
    # What is not glTF, or has no triangles this reads, is nothing.
    assert read_gltf(b"") is None and read_gltf(b"IDP3 not this") is None and read_gltf(b"{\"asset\": {}}") is None;
    assert read_gltf(text.replace("\"POSITION\": 1", "\"POSITION\": 9").encode("utf-8")) is None;
    assert read_gltf(text.replace("\"count\": 3, \"type\": \"VEC3\"", "\"count\": 300, \"type\": \"VEC3\"").encode("utf-8")) is None;
}
