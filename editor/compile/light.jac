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
import from .spot { Cone, spot_cone }

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

"""How far a lamp reaches at full strength: its `light` (300 when it does
not say), or nothing for an entity that is no lamp, is nowhere, or is put out."""
def lamp_level(item: Item) -> float {
    if item.origin() is None or not item.classname().startswith("light") {
        return 0.0;
    }
    try {
        return max(0.0, float(item.fields.get("light", item.fields.get("_light", "300")).split()[0]));
    } except (ValueError, IndexError) {
        return 300.0;
    }
}

"""The scene's lamps: every `light*` entity that is somewhere. Its `light`
is how far it reaches at full strength (300 when it does not say)."""
def scene_lamps(scene: Scene) -> list[Lamp] {
    lamps: list[Lamp] = [];
    for item in scene.items() {
        at = item.origin();
        level = lamp_level(item);
        if at is None or level <= 0.0 {
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

"""The cone a lamp shines in, or None for one that shines every way: toward
the entity its `target` names, when one of that name is somewhere, else the
way its `mangle` points."""
def lamp_cone(scene: Scene, item: Item) -> Cone | None {
    at = item.origin();
    if at is None {
        return None;
    }
    aimed_at: Vec3 | None = None;
    wanted = item.fields.get("target", "");
    if wanted {
        for other in scene.items() {
            if other is not item and other.fields.get("targetname", "") == wanted and other.origin() is not None {
                aimed_at = other.origin();
                break;
            }
        }
    }
    return spot_cone(dict(item.fields), at, aimed_at);
}

"""A cone for each of the scene's lamps, in the lamps' order: None for a
lamp that shines every way."""
def scene_cones(scene: Scene) -> list[Cone | None] {
    cones: list[Cone | None] = [];
    for item in scene.items() {
        if lamp_level(item) > 0.0 {
            cones.append(lamp_cone(scene, item));
        }
    }
    return cones;
}

"""The lamps that light a point: those that shine every way, those whose
cone it is inside, and for a point on a cone's rim that lamp at half its
strength (`dims` has each lamp so)."""
def lamps_at(point: Vec3, lamps: list[Lamp], dims: list[Lamp], cones: list[Cone | None]) -> list[Lamp] {
    reaching: list[Lamp] = [];
    for (index, lamp) in enumerate(lamps) {
        cone = cones[index] if index < len(cones) else None;
        if cone is None {
            reaching.append(lamp);
            continue;
        }
        share = cone.share(lamp.origin, point);
        if share == 2 {
            reaching.append(lamp);
        } elif share == 1 and index < len(dims) {
            reaching.append(dims[index]);
        }
    }
    return reaching;
}

"""The least light anything in a scene gets, as a part of one: the world's
`_minlight` (or `ambient`) out of 255 when it names one, else enough to
read the level by where no lamp reaches."""
def scene_floor(scene: Scene) -> float {
    for item in scene.items() {
        if item.classname() != "worldspawn" {
            continue;
        }
        words = item.fields.get("_minlight", item.fields.get("ambient", "")).split();
        if len(words) > 0 {
            try {
                return max(0.0, min(1.0, float(words[0]) / 255.0));
            } except ValueError {
                return 0.25;
            }
        }
    }
    return 0.25;
}

"""Lighting a level a slice at a time: everything the bake needs worked out
once, then the faces of the world lit a few at a time (`step`), and the
lightmap and the corners of what moves written when all are (`finish`). A
bake done all at once is the same job stepped through at once."""
obj LightJob {
    has made: LiveLevel,
        lamps: list[Lamp] = [],
        dims: list[Lamp] = [],
        cones: list[Cone | None] = [],
        spotted: bool = False,
        occluder: BrushOccluder = BrushOccluder(),
        least: float = 0.25,
        luxel: float = 16.0,
        frames: list[list[Vec3]] = [],
        sizes: list[list[float]] = [],
        pixels: bytearray = bytearray(),
        offset: int = 0,
        next_face: int = 0,
        first: int = 0,
        last: int = 0,
        total: int = 0;

    """The lamps that light a point."""
    def lit_by(point: Vec3) -> list[Lamp] {
        return lamps_at(point, self.lamps, self.dims, self.cones) if self.spotted else self.lamps;
    }

    """How far it has got: from 0 to 1."""
    def share -> float {
        span = max(1, self.last - self.first);
        return float(self.next_face - self.first) / float(span);
    }

    def finished -> bool {
        return self.next_face >= self.last;
    }

    """Light up to `limit` more faces of the world. True when every face is."""
    def step(limit: int) -> bool {
        bsp = self.made.bsp;
        luxel = self.luxel;
        least = self.least;
        pixels = self.pixels;
        stop = min(self.last, self.next_face + max(1, limit));
        for index in range(self.next_face, stop) {
            face = bsp.faces[index];
            u = self.frames[index - self.first][0];
            v = self.frames[index - self.first][1];
            span = self.sizes[index - self.first];
            wide = max(0.001, span[1] - span[0]);
            tall = max(0.001, span[3] - span[2]);
            across = int(math.ceil(wide / luxel)) + 1;
            down = int(math.ceil(tall / luxel)) + 1;
            face.light_width = across;
            face.light_height = down;
            face.light_offset = self.offset;
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
            offset = self.offset;
            for y in range(down) {
                for x in range(across) {
                    # Samples on the rim sit a little inside it, off the neighbouring wall.
                    s = max(0.5, min(wide - 0.5, wide * float(x) / float(max(1, across - 1))));
                    t = max(0.5, min(tall - 0.5, tall * float(y) / float(max(1, down - 1))));
                    point = corner.add(u.scale(s)).add(v.scale(t)).add(face.normal.scale(0.25));
                    sample = shade(point, face.normal, self.lit_by(point), self.occluder);
                    color = sample.ambient.add(sample.directed);
                    pixels[offset] = u8(int(max(0.0, min(127.0, max(least, color.x) * 127.5))));
                    pixels[offset + 1] = u8(int(max(0.0, min(127.0, max(least, color.y) * 127.5))));
                    pixels[offset + 2] = u8(int(max(0.0, min(127.0, max(least, color.z) * 127.5))));
                    offset += 3;
                }
            }
            self.offset = offset;
        }
        self.next_face = stop;
        return self.finished();
    }

    """Write what was lit into the level, and light the corners of what
    moves. Answers how many samples were lit."""
    def finish -> int {
        bsp = self.made.bsp;
        least = self.least;
        bsp.lighting = bytes(self.pixels);
        bsp.light_channels = 3;
        # What moves has no lightmap: each of its corners takes the light where
        # it stands when the level is built.
        for index in range(self.last, len(bsp.faces)) {
            face = bsp.faces[index];
            if len(face.colors) < len(face.vertices) * 4 {
                continue;
            }
            for (corner_index, vertex) in enumerate(face.vertices) {
                sample = shade(vertex.add(face.normal.scale(0.25)), face.normal, self.lit_by(vertex), self.occluder);
                color = sample.ambient.add(sample.directed);
                face.colors[corner_index * 4] = int(max(0.0, min(255.0, max(least, color.x) * 255.0)));
                face.colors[corner_index * 4 + 1] = int(max(0.0, min(255.0, max(least, color.y) * 255.0)));
                face.colors[corner_index * 4 + 2] = int(max(0.0, min(255.0, max(least, color.z) * 255.0)));
            }
        }
        return self.total;
    }
}

"""The job of lighting the level a scene compiled to, or none when the
scene has no lamps or it would take more than `budget` samples (the level
is then left flat, with a warning)."""
def light_job(scene: Scene, made: LiveLevel, luxel: float = 16.0, budget: int = 400000) -> LightJob | None {
    lamps = scene_lamps(scene);
    bsp = made.bsp;
    if len(lamps) == 0 or len(bsp.models) == 0 {
        return None;
    }
    job = LightJob(made=made, lamps=lamps, least=scene_floor(scene), luxel=luxel);
    # Lamps that shine one way light only what is in their cones.
    job.cones = scene_cones(scene);
    job.spotted = len([cone for cone in job.cones if cone is not None]) > 0;
    job.dims = [
        Lamp(origin=lamp.origin, color=lamp.color, radius=lamp.radius, strength=lamp.strength * 0.5) for lamp in lamps
    ] if job.spotted else [];
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
    job.occluder = occluder;
    world = bsp.models[0];
    job.first = world.first_face;
    job.last = world.first_face + world.face_count;
    job.next_face = job.first;
    # The size of every face's lightmap first, to hold to the budget.
    total = 0;
    for index in range(job.first, job.last) {
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
        job.frames.append([u, v]);
        job.sizes.append([u_low, u_high, v_low, v_high]);
        total += (int(math.ceil((u_high - u_low) / luxel)) + 1) * (int(math.ceil((v_high - v_low) / luxel)) + 1);
    }
    if total > budget {
        made.warnings.append("The scene is too large to light at once (" + str(total) + " samples)");
        return None;
    }
    job.total = total;
    job.pixels = bytearray(total * 3);
    return job;
}

"""Light the level a scene compiled to. Answers how many samples were lit:
none when the scene has no lamps, or when it would take more than `budget`
of them (the level is then left flat)."""
def bake_light(scene: Scene, made: LiveLevel, luxel: float = 16.0, budget: int = 400000) -> int {
    job = light_job(scene, made, luxel, budget);
    if job is None {
        return 0;
    }
    job.step(job.last - job.first);
    return job.finish();
}
