"""Models between the editing graph and the forms they are kept in: the
engine's own picture of a model (what its readers give for MDL, MD2 and MD3
files, and what its viewer draws), and Quake III's MD3 written out.

The games' files wind a triangle clockwise as seen from outside; the
editor's meshes go the other way round, as its tools and a mesh's volume
expect. So a triangle's last two corners change places on the way in and
again on the way out."""
import math;
import struct;
import from engine.math.vec3 { Vec3 }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame, ModelTag, TagFrame }
import from engine.formats.anorms { quake_vertex_normal }
import from .mesh { Mesh }
import from .document { ModelDoc, Part, Pose, Tag, HasPart, HasPose, HasTag }

"""A file's corners as the editor has them, or the editor's as a file has
them: each triangle's last two changed about."""
def turned_about(corners: list[int]) -> list[int] {
    made: list[int] = [];
    for index in range(len(corners) // 3) {
        made.extend([corners[index * 3], corners[index * 3 + 2], corners[index * 3 + 1]]);
    }
    return made;
}

"""A model the engine read, as a graph to edit. The engine gives each corner
of each triangle its own place on the skin; here a point has one, so a point
that the skin is cut at becomes a point on either side of the cut."""
def doc_from_model(model: AnimatedModel, name: str = "model") -> ModelDoc {
    doc = ModelDoc(name=name);
    for (number, surface) in enumerate(model.surfaces) {
        part = Part(name=surface.name if surface.name else "part " + str(number), skins=list(surface.skins));
        known: dict[str, int] = {};
        # Each new point's number in the file, to take its place at every frame.
        source: list[int] = [];
        # A file whose every point has one place on the skin keeps its
        # points as it numbers them.
        count = len(surface.frames[0].vertices) if len(surface.frames) > 0 else 0;
        places: list[float] = [0.0 for index in range(count * 2)];
        placed: list[bool] = [False for index in range(count)];
        as_numbered = count > 0;
        for corner in range(len(surface.indices)) {
            vertex = surface.indices[corner];
            if vertex < 0 or vertex >= count or corner * 2 + 1 >= len(surface.uv) {
                as_numbered = False;
                break;
            }
            if placed[vertex] and (abs(places[vertex * 2] - surface.uv[corner * 2]) > 0.00001
                or abs(places[vertex * 2 + 1] - surface.uv[corner * 2 + 1]) > 0.00001) {
                as_numbered = False;
                break;
            }
            placed[vertex] = True;
            places[vertex * 2] = surface.uv[corner * 2];
            places[vertex * 2 + 1] = surface.uv[corner * 2 + 1];
        }
        if as_numbered {
            part.corners = turned_about(surface.indices);
            part.uvs = places;
            doc +>:HasPart(index=number):+> part;
            for (index, frame) in enumerate(surface.frames) {
                part +>:HasPose(index=index):+> Pose(
                    name=frame.name if frame.name else "frame " + str(index), points=list(frame.vertices)
                );
            }
            continue;
        }
        for corner in range(len(surface.indices)) {
            vertex = surface.indices[corner];
            across = surface.uv[corner * 2] if corner * 2 + 1 < len(surface.uv) else 0.0;
            down = surface.uv[corner * 2 + 1] if corner * 2 + 1 < len(surface.uv) else 0.0;
            key = str(vertex) + "/" + str(round(across, 5)) + "/" + str(round(down, 5));
            if key not in known {
                known[key] = len(source);
                source.append(vertex);
                part.uvs.append(across);
                part.uvs.append(down);
            }
            part.corners.append(known[key]);
        }
        part.corners = turned_about(part.corners);
        doc +>:HasPart(index=number):+> part;
        for (index, frame) in enumerate(surface.frames) {
            points = [frame.vertices[vertex] for vertex in source if vertex < len(frame.vertices)];
            part +>:HasPose(index=index):+> Pose(name=frame.name if frame.name else "frame " + str(index), points=points);
        }
    }
    if len(model.tags) > 0 {
        for (number, first) in enumerate(model.tags[0].tags) {
            tag = Tag(name=first.name);
            for held in model.tags {
                if number < len(held.tags) {
                    tag.origins.append(held.tags[number].origin);
                    tag.axes.append(list(held.tags[number].axes));
                }
            }
            doc +>:HasTag:+> tag;
        }
    }
    doc.dirty = False;
    return doc;
}

"""The way each point of a mesh faces: the triangles round it, averaged."""
def point_normals(mesh: Mesh) -> list[Vec3] {
    sums: list[Vec3] = [Vec3() for point in mesh.points];
    for index in range(mesh.triangles()) {
        facing = mesh.normal(index);
        for k in range(3) {
            at = mesh.corners[index * 3 + k];
            sums[at] = sums[at].add(facing);
        }
    }
    return [total.normalized() if total.length() > 0.0001 else Vec3(z=1.0) for total in sums];
}

"""The graph as the engine pictures a model: for its viewer, and to write."""
def model_of(doc: ModelDoc) -> AnimatedModel {
    model = AnimatedModel();
    for part in doc.parts() {
        surface = AnimatedSurface(name=part.name, indices=turned_about(part.corners), skins=list(part.skins));
        skinned = len(part.uvs) > 0;
        for at in surface.indices {
            surface.uv.append(part.uvs[at * 2] if skinned and at * 2 + 1 < len(part.uvs) else 0.0);
            surface.uv.append(part.uvs[at * 2 + 1] if skinned and at * 2 + 1 < len(part.uvs) else 0.0);
        }
        for pose in doc.poses(part) {
            mesh = Mesh(points=pose.points, corners=part.corners);
            surface.frames.append(AnimationFrame(name=pose.name, vertices=list(pose.points), normals=point_normals(mesh)));
        }
        model.surfaces.append(surface);
    }
    held = doc.tags();
    for frame in range(doc.frames()) {
        stood = TagFrame();
        for tag in held {
            if frame < len(tag.origins) and frame < len(tag.axes) {
                stood.tags.append(ModelTag(name=tag.name, origin=tag.origins[frame], axes=list(tag.axes[frame])));
            }
        }
        model.tags.append(stood);
    }
    return model;
}

"""A name in a file: so many bytes, the rest nothing."""
def:priv name_bytes(name: str, size: int) -> bytes {
    raw = name.encode("utf-8")[:size - 1];
    return raw + bytes(size - len(raw));
}

def:priv vector_bytes(vector: Vec3) -> bytes {
    return struct.pack("<fff", vector.x, vector.y, vector.z);
}

"""What an MD3 can hold of a model: a line for each thing it cannot."""
def md3_limits(doc: ModelDoc) -> list[str] {
    found: list[str] = [];
    frames = doc.frames();
    if frames < 1 or frames > 1024 {
        found.append("An MD3 has from 1 to 1024 frames; this has " + str(frames));
    }
    if len(doc.parts()) > 32 {
        found.append("An MD3 has 32 parts at most; this has " + str(len(doc.parts())));
    }
    if len(doc.tags()) > 16 {
        found.append("An MD3 has 16 tags at most; this has " + str(len(doc.tags())));
    }
    for part in doc.parts() {
        stood = doc.poses(part);
        points = len(stood[0].points) if len(stood) > 0 else 0;
        if points < 1 or points > 4096 or len(part.corners) // 3 < 1 or len(part.corners) // 3 > 8192 {
            found.append(part.name + ": an MD3 part has from 1 to 4096 points and 1 to 8192 triangles");
        }
        if len(stood) != frames {
            found.append(part.name + " has " + str(len(stood)) + " frames, the model " + str(frames));
        }
        for pose in stood {
            for point in pose.points {
                if abs(point.x) > 511.0 or abs(point.y) > 511.0 or abs(point.z) > 511.0 {
                    found.append(part.name + ": a point lies more than 511 units from the middle, further than an MD3 can say");
                    break;
                }
            }
        }
    }
    return found;
}

"""The model as an MD3 file's bytes (empty when it is more than one holds:
md3_limits says why)."""
def write_md3(doc: ModelDoc) -> bytes {
    if len(md3_limits(doc)) > 0 {
        return b"";
    }
    parts = doc.parts();
    tags = doc.tags();
    frames = doc.frames();
    head = 108;
    frame_bytes = bytearray();
    for frame in range(frames) {
        box = doc.bounds(frame);
        middle = box[0].add(box[1]).scale(0.5);
        frame_bytes.extend(vector_bytes(box[0]));
        frame_bytes.extend(vector_bytes(box[1]));
        frame_bytes.extend(vector_bytes(Vec3()));
        frame_bytes.extend(struct.pack("<f", box[1].sub(middle).length() + middle.length()));
        frame_bytes.extend(name_bytes(doc.frame_name(frame), 16));
    }
    tag_bytes = bytearray();
    for frame in range(frames) {
        for tag in tags {
            at = tag.origins[frame] if frame < len(tag.origins) else Vec3();
            axes = tag.axes[frame] if frame < len(tag.axes) and len(tag.axes[frame]) == 3 else [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)];
            tag_bytes.extend(name_bytes(tag.name, 64));
            tag_bytes.extend(vector_bytes(at));
            for axis in axes {
                tag_bytes.extend(vector_bytes(axis));
            }
        }
    }
    surface_bytes = bytearray();
    for part in parts {
        stood = doc.poses(part);
        points = len(stood[0].points);
        triangles = len(part.corners) // 3;
        skins = part.skins if len(part.skins) > 0 else [""];
        tri_at = 108;
        shader_at = tri_at + triangles * 12;
        uv_at = shader_at + len(skins) * 68;
        vertex_at = uv_at + points * 8;
        size = vertex_at + frames * points * 8;
        surface_bytes.extend(b"IDP3");
        surface_bytes.extend(name_bytes(part.name, 64));
        surface_bytes.extend(struct.pack("<iiiii", 0, frames, len(skins), points, triangles));
        surface_bytes.extend(struct.pack("<iiiii", tri_at, shader_at, uv_at, vertex_at, size));
        for corner in turned_about(part.corners) {
            surface_bytes.extend(struct.pack("<i", corner));
        }
        for (number, skin) in enumerate(skins) {
            surface_bytes.extend(name_bytes(skin, 64));
            surface_bytes.extend(struct.pack("<i", number));
        }
        for at in range(points) {
            skinned = at * 2 + 1 < len(part.uvs);
            surface_bytes.extend(struct.pack("<ff", part.uvs[at * 2] if skinned else 0.0, part.uvs[at * 2 + 1] if skinned else 0.0));
        }
        for pose in stood {
            facing = point_normals(Mesh(points=pose.points, corners=part.corners));
            for (at, point) in enumerate(pose.points) {
                normal = facing[at];
                # The way it faces as two bytes: down from the pole, and round it.
                tilt = int(round(math.acos(max(-1.0, min(1.0, normal.z))) * 256.0 / (2.0 * math.pi))) & 255;
                swing = int(round(math.atan2(normal.y, normal.x) * 256.0 / (2.0 * math.pi))) & 255;
                surface_bytes.extend(
                    struct.pack("<hhh", int(round(point.x * 64.0)), int(round(point.y * 64.0)), int(round(point.z * 64.0)))
                );
                surface_bytes.extend(bytes([tilt, swing]));
            }
        }
    }
    frames_at = head;
    tags_at = frames_at + len(frame_bytes);
    surfaces_at = tags_at + len(tag_bytes);
    end = surfaces_at + len(surface_bytes);
    out = bytearray();
    out.extend(b"IDP3");
    out.extend(struct.pack("<i", 15));
    out.extend(name_bytes(doc.name, 64));
    out.extend(struct.pack("<iiiii", 0, frames, len(tags), len(parts), 0));
    out.extend(struct.pack("<iiii", frames_at, tags_at, surfaces_at, end));
    out.extend(frame_bytes);
    out.extend(tag_bytes);
    out.extend(surface_bytes);
    return bytes(out);
}

"""What an MD2 can hold of a model: a line for each thing it cannot. An MD2
is one mesh, so a model's parts are written as one; it has no tags."""
def md2_limits(doc: ModelDoc) -> list[str] {
    found: list[str] = [];
    frames = doc.frames();
    points = 0;
    triangles = 0;
    skins = 0;
    for part in doc.parts() {
        stood = doc.poses(part);
        points += len(stood[0].points) if len(stood) > 0 else 0;
        triangles += len(part.corners) // 3;
        skins += len(part.skins);
        if len(stood) != frames {
            found.append(part.name + " has " + str(len(stood)) + " frames, the model " + str(frames));
        }
    }
    if frames < 1 or frames > 512 {
        found.append("An MD2 has from 1 to 512 frames; this has " + str(frames));
    }
    if points < 1 or points > 2048 or triangles < 1 or triangles > 4096 {
        found.append(
            "An MD2 has from 1 to 2048 points and 1 to 4096 triangles; this has " + str(points) + " and " + str(triangles)
        );
    }
    if skins > 32 {
        found.append("An MD2 names 32 skins at most; this names " + str(skins));
    }
    return found;
}

"""Which of the 162 ways Quake lets a point face is nearest a way."""
def:priv nearest_normal(facing: Vec3) -> int {
    best = 0;
    most = -2.0;
    for index in range(162) {
        lean = quake_vertex_normal(index).dot(facing);
        if lean > most {
            most = lean;
            best = index;
        }
    }
    return best;
}

"""The model as an MD2 file's bytes, its skin `wide` by `tall` texels (empty
when it is more than one holds: md2_limits says why). Each frame's points
are kept as a byte an axis within the frame's own box, as the format has
them, so they come back to within a 255th of the box's size."""
def write_md2(doc: ModelDoc, wide: int = 256, tall: int = 256) -> bytes {
    if len(md2_limits(doc)) > 0 or wide < 1 or tall < 1 {
        return b"";
    }
    frames = doc.frames();
    # The parts as one mesh: each part's points after those before it.
    corners: list[int] = [];
    places: list[float] = [];
    skins: list[str] = [];
    base = 0;
    for part in doc.parts() {
        count = len(doc.poses(part)[0].points);
        for corner in turned_about(part.corners) {
            corners.append(base + corner);
        }
        for at in range(count) {
            skinned = at * 2 + 1 < len(part.uvs);
            places.append(part.uvs[at * 2] if skinned else 0.0);
            places.append(part.uvs[at * 2 + 1] if skinned else 0.0);
        }
        skins.extend(part.skins);
        base += count;
    }
    points = base;
    triangles = len(corners) // 3;
    skin_bytes = bytearray();
    for skin in skins {
        skin_bytes.extend(name_bytes(skin, 64));
    }
    place_bytes = bytearray();
    for at in range(points) {
        place_bytes.extend(
            struct.pack(
                "<hh",
                max(-32768, min(32767, int(round(places[at * 2] * float(wide) - 0.5)))),
                max(-32768, min(32767, int(round(places[at * 2 + 1] * float(tall) - 0.5))))
            )
        );
    }
    triangle_bytes = bytearray();
    for index in range(triangles) {
        trio = [corners[index * 3], corners[index * 3 + 1], corners[index * 3 + 2]];
        triangle_bytes.extend(struct.pack("<HHHHHH", trio[0], trio[1], trio[2], trio[0], trio[1], trio[2]));
    }
    frame_bytes = bytearray();
    for frame in range(frames) {
        stood: list[Vec3] = [];
        facing: list[Vec3] = [];
        for part in doc.parts() {
            pose = doc.poses(part)[frame];
            stood.extend(pose.points);
            facing.extend(point_normals(Mesh(points=pose.points, corners=part.corners)));
        }
        box = doc.bounds(frame);
        extent = box[1].sub(box[0]);
        scale = Vec3(
            x=extent.x / 255.0 if extent.x > 0.0001 else 1.0,
            y=extent.y / 255.0 if extent.y > 0.0001 else 1.0,
            z=extent.z / 255.0 if extent.z > 0.0001 else 1.0
        );
        frame_bytes.extend(vector_bytes(scale));
        frame_bytes.extend(vector_bytes(box[0]));
        frame_bytes.extend(name_bytes(doc.frame_name(frame), 16));
        for (at, point) in enumerate(stood) {
            frame_bytes.extend(
                bytes(
                    [
                        max(0, min(255, int(round((point.x - box[0].x) / scale.x)))),
                        max(0, min(255, int(round((point.y - box[0].y) / scale.y)))),
                        max(0, min(255, int(round((point.z - box[0].z) / scale.z)))),
                        nearest_normal(facing[at])
                    ]
                )
            );
        }
    }
    # The same triangles as a list of commands for a renderer that wants
    # them so: three corners a time, each with its place on the skin.
    command_bytes = bytearray();
    for index in range(triangles) {
        command_bytes.extend(struct.pack("<i", 3));
        for k in range(3) {
            at = corners[index * 3 + k];
            command_bytes.extend(struct.pack("<ffi", places[at * 2], places[at * 2 + 1], at));
        }
    }
    command_bytes.extend(struct.pack("<i", 0));
    stride = 40 + points * 4;
    skins_at = 68;
    places_at = skins_at + len(skin_bytes);
    triangles_at = places_at + len(place_bytes);
    frames_at = triangles_at + len(triangle_bytes);
    commands_at = frames_at + len(frame_bytes);
    end = commands_at + len(command_bytes);
    out = bytearray();
    out.extend(b"IDP2");
    out.extend(struct.pack("<iiii", 8, wide, tall, stride));
    out.extend(struct.pack("<iiiiii", len(skins), points, points, triangles, len(command_bytes) // 4, frames));
    out.extend(struct.pack("<iiiiii", skins_at, places_at, triangles_at, frames_at, commands_at, end));
    out.extend(skin_bytes);
    out.extend(place_bytes);
    out.extend(triangle_bytes);
    out.extend(frame_bytes);
    out.extend(command_bytes);
    return bytes(out);
}

"""What a Quake MDL can hold of a model: a line for each thing it cannot. An
MDL is one mesh with its skin inside it, so a model's parts are written as
one; it has no tags."""
def mdl_limits(doc: ModelDoc) -> list[str] {
    found: list[str] = [];
    frames = doc.frames();
    points = 0;
    triangles = 0;
    for part in doc.parts() {
        stood = doc.poses(part);
        points += len(stood[0].points) if len(stood) > 0 else 0;
        triangles += len(part.corners) // 3;
        if len(stood) != frames {
            found.append(part.name + " has " + str(len(stood)) + " frames, the model " + str(frames));
        }
    }
    if frames < 1 or frames > 256 {
        found.append("An MDL has from 1 to 256 frames; this has " + str(frames));
    }
    if points < 1 or points > 1024 or triangles < 1 or triangles > 2048 {
        found.append(
            "An MDL has from 1 to 1024 points and 1 to 2048 triangles; this has " + str(points) + " and " + str(triangles)
        );
    }
    return found;
}

"""A palette for when Quake's own is not at hand: 256 greys, dark to light."""
def grey_palette -> bytes {
    made = bytearray();
    for index in range(256) {
        made.extend(bytes([index, index, index]));
    }
    return bytes(made);
}

"""A picture of four numbers a texel as numbers into a palette of 256
colours: each texel the nearest of the first 224 (Quake draws the last 32
unlit, whatever the light)."""
def palette_indices(texels: bytes, palette: bytes) -> bytes {
    made = bytearray();
    known: dict[int, int] = {};
    for at in range(len(texels) // 4) {
        red = int(texels[at * 4]);
        green = int(texels[at * 4 + 1]);
        blue = int(texels[at * 4 + 2]);
        key = (red << 16) | (green << 8) | blue;
        if key not in known {
            best = 0;
            least = 1000000;
            for index in range(min(224, len(palette) // 3)) {
                off = (int(palette[index * 3]) - red) ** 2 + (int(palette[index * 3 + 1]) - green) ** 2
                    + (int(palette[index * 3 + 2]) - blue) ** 2;
                if off < least {
                    least = off;
                    best = index;
                }
            }
            known[key] = best;
        }
        made.append(known[key]);
    }
    return bytes(made);
}

"""The model as a Quake MDL file's bytes, with one skin `wide` by `tall`
texels (empty when it is more than one holds: mdl_limits says why). `skin`
is that picture as numbers into Quake's palette, a row at a time from the
top; without one of the right size the skin is one grey. A point is a byte
an axis within the box round every frame, so it comes back to within a
255th of that box's size, and a place on the skin to within a texel."""
def write_mdl(doc: ModelDoc, wide: int = 128, tall: int = 128, skin: bytes = b"") -> bytes {
    if len(mdl_limits(doc)) > 0 or wide < 1 or tall < 1 {
        return b"";
    }
    frames = doc.frames();
    corners: list[int] = [];
    places: list[float] = [];
    base = 0;
    for part in doc.parts() {
        count = len(doc.poses(part)[0].points);
        for corner in turned_about(part.corners) {
            corners.append(base + corner);
        }
        for at in range(count) {
            skinned = at * 2 + 1 < len(part.uvs);
            places.append(part.uvs[at * 2] if skinned else 0.0);
            places.append(part.uvs[at * 2 + 1] if skinned else 0.0);
        }
        base += count;
    }
    points = base;
    triangles = len(corners) // 3;
    # One box for every frame: the file has one scale.
    low = doc.bounds(0)[0];
    high = doc.bounds(0)[1];
    for frame in range(frames) {
        box = doc.bounds(frame);
        low = Vec3(x=min(low.x, box[0].x), y=min(low.y, box[0].y), z=min(low.z, box[0].z));
        high = Vec3(x=max(high.x, box[1].x), y=max(high.y, box[1].y), z=max(high.z, box[1].z));
    }
    extent = high.sub(low);
    scale = Vec3(
        x=extent.x / 255.0 if extent.x > 0.0001 else 1.0,
        y=extent.y / 255.0 if extent.y > 0.0001 else 1.0,
        z=extent.z / 255.0 if extent.z > 0.0001 else 1.0
    );
    reach = 0.0;
    frame_bytes = bytearray();
    for frame in range(frames) {
        stood: list[Vec3] = [];
        facing: list[Vec3] = [];
        for part in doc.parts() {
            pose = doc.poses(part)[frame];
            stood.extend(pose.points);
            facing.extend(point_normals(Mesh(points=pose.points, corners=part.corners)));
        }
        packed = bytearray();
        least = [255, 255, 255];
        most = [0, 0, 0];
        for (at, point) in enumerate(stood) {
            reach = max(reach, point.length());
            trio = [
                max(0, min(255, int(round((point.x - low.x) / scale.x)))),
                max(0, min(255, int(round((point.y - low.y) / scale.y)))),
                max(0, min(255, int(round((point.z - low.z) / scale.z))))
            ];
            for axis in range(3) {
                least[axis] = min(least[axis], trio[axis]);
                most[axis] = max(most[axis], trio[axis]);
            }
            packed.extend(bytes([trio[0], trio[1], trio[2], nearest_normal(facing[at])]));
        }
        # A frame on its own: the corners of its box, its name, its points.
        frame_bytes.extend(struct.pack("<i", 0));
        frame_bytes.extend(bytes([least[0], least[1], least[2], 0]));
        frame_bytes.extend(bytes([most[0], most[1], most[2], 0]));
        frame_bytes.extend(name_bytes(doc.frame_name(frame), 16));
        frame_bytes.extend(packed);
    }
    out = bytearray();
    out.extend(b"IDPO");
    out.extend(struct.pack("<i", 6));
    out.extend(vector_bytes(scale));
    out.extend(vector_bytes(low));
    out.extend(struct.pack("<f", reach));
    out.extend(vector_bytes(Vec3(z=high.z)));
    out.extend(struct.pack("<iiiiii", 1, wide, tall, points, triangles, frames));
    out.extend(struct.pack("<iif", 0, 0, max(1.0, extent.length() / 16.0)));
    out.extend(struct.pack("<i", 0));
    out.extend(skin if len(skin) == wide * tall else bytes([8]) * (wide * tall));
    for at in range(points) {
        out.extend(
            struct.pack(
                "<iii",
                0,
                max(0, min(wide - 1, int(round(places[at * 2] * float(wide) - 0.5)))),
                max(0, min(tall - 1, int(round(places[at * 2 + 1] * float(tall) - 0.5))))
            )
        );
    }
    for index in range(triangles) {
        out.extend(struct.pack("<iiii", 1, corners[index * 3], corners[index * 3 + 1], corners[index * 3 + 2]));
    }
    out.extend(frame_bytes);
    return bytes(out);
}
