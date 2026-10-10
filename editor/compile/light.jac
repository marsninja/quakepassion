"""Light for a scene, from its own lights.

Every entity whose class begins with `light` is a lamp. The world's faces
get a lightmap each, a sample every `luxel` units, lit through the engine's
own shading with shadows cast by the scene's brushes; the faces of doors and
other moving brushes keep their flat shade. A scene with no lights is left
as the live compiler made it, so a blockout reads before any light is
placed."""
import math;
import from engine.formats.bsp { Bsp, Face }
import from engine.math.vec3 { Vec3 }
import from engine.world.lighting { Lamp, Occluder, shade }
import from ..document.scene { Scene, Item, Solid, read_vector }
import from ..geometry.brush { Side, brush_windings, windings_bounds, ray_enters_brush }
import from .live { LiveLevel, material_hidden }

"""Shadows cast by brushes: a sample sees a lamp when no brush stands
between them."""
obj BrushOccluder(Occluder) {
    has brushes: list[list[Side]] = [],
        lows: list[Vec3] = [],
        highs: list[Vec3] = [];

    def add(sides: list[Side]) {
        box = windings_bounds(brush_windings(sides));
        if box is None {
            return;
        }
        self.brushes.append(sides);
        self.lows.append(box[0]);
        self.highs.append(box[1]);
    }

    def visibility(point: Vec3, target: Vec3) -> float {
        along = target.sub(point);
        reach = along.length();
        if reach < 0.001 {
            return 1.0;
        }
        direction = along.scale(1.0 / reach);
        low = Vec3(x=min(point.x, target.x), y=min(point.y, target.y), z=min(point.z, target.z));
        high = Vec3(x=max(point.x, target.x), y=max(point.y, target.y), z=max(point.z, target.z));
        for index in range(len(self.brushes)) {
            a = self.lows[index];
            b = self.highs[index];
            if a.x > high.x or b.x < low.x or a.y > high.y or b.y < low.y or a.z > high.z or b.z < low.z {
                continue;
            }
            entered = ray_enters_brush(self.brushes[index], point, direction);
            if entered[1] >= 0 and entered[0] > 0.01 and entered[0] < reach - 0.5 {
                return 0.0;
            }
        }
        return 1.0;
    }
}

"""A colour field as three parts of one: "1 0.5 0" or "255 128 0"."""
def:priv lamp_color(words: str) -> Vec3 {
    found = read_vector(words);
    if found is None {
        return Vec3(x=1.0, y=1.0, z=1.0);
    }
    if max(found.x, max(found.y, found.z)) > 1.0 {
        return found.scale(1.0 / 255.0);
    }
    return found;
}

"""The scene's lamps: every `light*` entity that is somewhere. Its `light`
is how far it reaches at full strength (300 when it does not say)."""
def scene_lamps(scene: Scene) -> list[Lamp] {
    lamps: list[Lamp] = [];
    for item in scene.items() {
        at = item.origin();
        if at is None or not item.classname().startswith("light") {
            continue;
        }
        level = 300.0;
        try {
            level = float(item.fields.get("light", item.fields.get("_light", "300")).split()[0]);
        } except (ValueError, IndexError) {
            level = 300.0;
        }
        if level <= 0.0 {
            continue;
        }
        lamps.append(
            Lamp(
                origin=at,
                color=lamp_color(item.fields.get("_color", item.fields.get("color", ""))),
                radius=max(64.0, level * 2.0),
                strength=1.7
            )
        );
    }
    return lamps;
}

"""Light the level a scene compiled to. Answers how many samples were lit:
none when the scene has no lamps, or when it would take more than `budget`
of them (the level is then left flat)."""
def bake_light(scene: Scene, made: LiveLevel, luxel: float = 16.0, budget: int = 400000) -> int {
    lamps = scene_lamps(scene);
    bsp = made.bsp;
    if len(lamps) == 0 or len(bsp.models) == 0 {
        return 0;
    }
    occluder = BrushOccluder();
    for item in scene.items() {
        # What moves, and what is only a volume, casts no fixed shadow.
        if item.classname() not in ["worldspawn", "func_group", "func_wall", "func_static"] {
            continue;
        }
        for solid in scene.solids_of(item) {
            if not material_hidden(solid.sides[0].material) {
                occluder.add(solid.sides);
            }
        }
    }
    world = bsp.models[0];
    last = world.first_face + world.face_count;
    # The size of every face's lightmap first, to hold to the budget.
    frames: list[list[Vec3]] = [];
    sizes: list[list[float]] = [];
    total = 0;
    for index in range(world.first_face, last) {
        face = bsp.faces[index];
        u = face.vertices[1].sub(face.vertices[0]).normalized();
        v = face.normal.cross(u).normalized();
        u_low = face.vertices[0].dot(u);
        u_high = u_low;
        v_low = face.vertices[0].dot(v);
        v_high = v_low;
        for vertex in face.vertices {
            u_low = min(u_low, vertex.dot(u));
            u_high = max(u_high, vertex.dot(u));
            v_low = min(v_low, vertex.dot(v));
            v_high = max(v_high, vertex.dot(v));
        }
        frames.append([u, v]);
        sizes.append([u_low, u_high, v_low, v_high]);
        total += (int(math.ceil((u_high - u_low) / luxel)) + 1) * (int(math.ceil((v_high - v_low) / luxel)) + 1);
    }
    if total > budget {
        made.warnings.append("The scene is too large to light at once (" + str(total) + " samples)");
        return 0;
    }
    pixels = bytearray(total * 3);
    offset = 0;
    for index in range(world.first_face, last) {
        face = bsp.faces[index];
        u = frames[index - world.first_face][0];
        v = frames[index - world.first_face][1];
        span = sizes[index - world.first_face];
        wide = max(0.001, span[1] - span[0]);
        tall = max(0.001, span[3] - span[2]);
        across = int(math.ceil(wide / luxel)) + 1;
        down = int(math.ceil(tall / luxel)) + 1;
        face.light_width = across;
        face.light_height = down;
        face.light_offset = offset;
        face.styles = [0];
        face.colors = [];
        face.light_uv = [];
        for vertex in face.vertices {
            face.light_uv.extend(
                [
                    (vertex.dot(u) - span[0]) / wide * float(across - 1),
                    (vertex.dot(v) - span[2]) / tall * float(down - 1)
                ]
            );
        }
        # The corner of the face's rectangle, on its plane.
        start = face.vertices[0];
        corner = start.add(u.scale(span[0] - start.dot(u))).add(v.scale(span[2] - start.dot(v)));
        for y in range(down) {
            for x in range(across) {
                # Samples on the rim sit a little inside it, off the neighbouring wall.
                s = max(0.5, min(wide - 0.5, wide * float(x) / float(max(1, across - 1))));
                t = max(0.5, min(tall - 0.5, tall * float(y) / float(max(1, down - 1))));
                point = corner.add(u.scale(s)).add(v.scale(t)).add(face.normal.scale(0.25));
                sample = shade(point, face.normal, lamps, occluder);
                color = sample.ambient.add(sample.directed);
                pixels[offset] = u8(int(max(0.0, min(127.0, color.x * 127.5))));
                pixels[offset + 1] = u8(int(max(0.0, min(127.0, color.y * 127.5))));
                pixels[offset + 2] = u8(int(max(0.0, min(127.0, color.z * 127.5))));
                offset += 3;
            }
        }
    }
    bsp.lighting = bytes(pixels);
    bsp.light_channels = 3;
    # What moves has no lightmap: each of its corners takes the light where
    # it stands when the level is built.
    for index in range(last, len(bsp.faces)) {
        face = bsp.faces[index];
        if len(face.colors) < len(face.vertices) * 4 {
            continue;
        }
        for (corner_index, vertex) in enumerate(face.vertices) {
            sample = shade(vertex.add(face.normal.scale(0.25)), face.normal, lamps, occluder);
            color = sample.ambient.add(sample.directed);
            face.colors[corner_index * 4] = int(max(0.0, min(255.0, color.x * 255.0)));
            face.colors[corner_index * 4 + 1] = int(max(0.0, min(255.0, color.y * 255.0)));
            face.colors[corner_index * 4 + 2] = int(max(0.0, min(255.0, color.z * 255.0)));
        }
    }
    return total;
}
