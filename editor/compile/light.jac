"""Light for a scene, from its own lights.

Every entity whose class begins with `light` is a lamp. The world's faces
get a lightmap each, a sample every `luxel` units, lit through the engine's
own shading with shadows cast by the scene's brushes; the faces of doors and
other moving brushes keep their flat shade. A scene with no lights is left
as the live compiler made it, so a blockout reads before any light is
placed."""
import math;
import from engine.formats.bsp { Bsp, Face, Texture }
import from engine.math.vec3 { Vec3 }
import from engine.world.lighting { Lamp, Occluder, shade }
import from ..document.scene { Scene, Item, Solid, read_vector }
import from ..geometry.brush { Side, brush_windings, windings_bounds, ray_enters_brush, brush_holds }
import from .live { LiveLevel, material_hidden, switch_styles, brush_contents, LIQUID_BITS }
import from .cull { material_clear }
import from .spot { Cone, spot_cone }

"""Shadows cast by brushes: a sample sees a lamp when no brush stands
between them. Brushes are kept in buckets of a grid `cell` units across,
and a line of sight walks only the cells it passes through."""
obj BrushOccluder(Occluder) {
    has brushes: list[list[Side]] = [],
        lows: list[Vec3] = [],
        highs: list[Vec3] = [],
        cell: float = 128.0,
        buckets: dict[int, list[int]] = {},
        stamps: list[int] = [],
        tick: int = 0;

    def bucket_key(ix: int, iy: int, iz: int) -> int {
        return ((ix + 2048) * 4096 + (iy + 2048)) * 4096 + (iz + 2048);
    }

    def add(sides: list[Side]) {
        box = windings_bounds(brush_windings(sides));
        if box is None {
            return;
        }
        index = len(self.brushes);
        self.brushes.append(sides);
        self.lows.append(box[0]);
        self.highs.append(box[1]);
        self.stamps.append(0);
        for ix in range(int(math.floor(box[0].x / self.cell)), int(math.floor(box[1].x / self.cell)) + 1) {
            for iy in range(int(math.floor(box[0].y / self.cell)), int(math.floor(box[1].y / self.cell)) + 1) {
                for iz in range(int(math.floor(box[0].z / self.cell)), int(math.floor(box[1].z / self.cell)) + 1) {
                    key = self.bucket_key(ix, iy, iz);
                    if key not in self.buckets {
                        self.buckets[key] = [];
                    }
                    self.buckets[key].append(index);
                }
            }
        }
    }

    """Whether a point is inside any brush."""
    def holds(point: Vec3) -> bool {
        key = self.bucket_key(
            int(math.floor(point.x / self.cell)), int(math.floor(point.y / self.cell)), int(math.floor(point.z / self.cell))
        );
        for index in self.buckets.get(key, []) {
            a = self.lows[index];
            b = self.highs[index];
            if point.x < a.x or point.x > b.x or point.y < a.y or point.y > b.y or point.z < a.z or point.z > b.z {
                continue;
            }
            if brush_holds(self.brushes[index], point) {
                return True;
            }
        }
        return False;
    }

    def visibility(point: Vec3, target: Vec3) -> float {
        along = target.sub(point);
        reach = along.length();
        if reach < 0.001 {
            return 1.0;
        }
        direction = along.scale(1.0 / reach);
        self.tick += 1;
        far = 1000000000.0;
        cell = self.cell;
        ix = int(math.floor(point.x / cell));
        iy = int(math.floor(point.y / cell));
        iz = int(math.floor(point.z / cell));
        step_x = 1 if direction.x > 0.0 else -1;
        step_y = 1 if direction.y > 0.0 else -1;
        step_z = 1 if direction.z > 0.0 else -1;
        next_x = far;
        next_y = far;
        next_z = far;
        delta_x = far;
        delta_y = far;
        delta_z = far;
        if abs(direction.x) > 0.000001 {
            next_x = ((float(ix) + (1.0 if step_x > 0 else 0.0)) * cell - point.x) / direction.x;
            delta_x = cell / abs(direction.x);
        }
        if abs(direction.y) > 0.000001 {
            next_y = ((float(iy) + (1.0 if step_y > 0 else 0.0)) * cell - point.y) / direction.y;
            delta_y = cell / abs(direction.y);
        }
        if abs(direction.z) > 0.000001 {
            next_z = ((float(iz) + (1.0 if step_z > 0 else 0.0)) * cell - point.z) / direction.z;
            delta_z = cell / abs(direction.z);
        }
        travelled = 0.0;
        while travelled <= reach {
            for index in self.buckets.get(self.bucket_key(ix, iy, iz), []) {
                if self.stamps[index] == self.tick {
                    continue;
                }
                self.stamps[index] = self.tick;
                entered = ray_enters_brush(self.brushes[index], point, direction);
                if entered[1] >= 0 and entered[0] > 0.01 and entered[0] < reach - 0.5 {
                    return 0.0;
                }
            }
            if next_x <= next_y and next_x <= next_z {
                travelled = next_x;
                next_x += delta_x;
                ix += step_x;
            } elif next_y <= next_z {
                travelled = next_y;
                next_y += delta_y;
                iy += step_y;
            } else {
                travelled = next_z;
                next_z += delta_z;
                iz += step_z;
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

"""The light style of a lamp: its own `style` (Quake's animated ones, 1 to
11, or one given by hand), the one a switched light was given when the
scene was compiled (`switches`, by name), or 0."""
def lamp_style(item: Item, switches: dict[str, int]) -> int {
    name = item.fields.get("targetname", "");
    if name in switches {
        return switches[name];
    }
    words = item.fields.get("style", "0").strip();
    if words.isdigit() and 0 < int(words) < 64 {
        return int(words);
    }
    return 0;
}

"""A piece of a face of the world for light bounced between faces: a point
on the face (a unit off it), its normal and area, which cell of the face's
grid of patches it is, the direct light it has and gives back, and the
light it gathers from the others."""
obj Patch {
    has face: int,
        spot: Vec3,
        normal: Vec3,
        area: float,
        column: int,
        row: int,
        out: Vec3 = Vec3(),
        gathered: Vec3 = Vec3();
}

"""The average colour of a texture (what of the light reaching it a face
gives back), or a middle grey where its picture is not to hand."""
def texture_albedo(texture: Texture) -> Vec3 {
    data = texture.rgba;
    count = len(data) // 4;
    if count == 0 {
        return Vec3(x=0.5, y=0.5, z=0.5);
    }
    stride = max(1, count // 1024);
    total = Vec3();
    taken = 0;
    for pick in range(0, count, stride) {
        total = total.add(Vec3(x=float(data[pick * 4]), y=float(data[pick * 4 + 1]), z=float(data[pick * 4 + 2])));
        taken += 1;
    }
    return total.scale(1.0 / (255.0 * float(max(1, taken))));
}

"""Lighting a level a slice at a time. Everything the bake needs is worked
out once (`light_job`); then each face of the world is lit directly, a few
at a time, once for its steady lamps and once for each light style that
reaches it (lamps that flicker or are switched); then light is bounced once
between patches of the faces, and given off by faces whose material says
they glow; then a grid of samples through the level is lit for models to
take their light from. `finish` writes the lightmaps (a layer for each
style a face has) and lights the corners of what moves. A bake done all at
once is the same job stepped through at once."""
obj LightJob {
    has made: LiveLevel,
        lamps: list[Lamp] = [],
        dims: list[Lamp] = [],
        cones: list[Cone | None] = [],
        spotted: bool = False,
        lamp_styles: list[int] = [],
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
        total: int = 0,
        # "direct", "bounce", "grid", then "ready" for `finish`.
        phase: str = "direct",
        # Each face's samples across and down, its steady light (three
        # numbers a sample) and the light of each style that reaches it.
        dims_of: list[list[int]] = [],
        steady: list[list[float]] = [],
        styled: list[dict[int, list[float]]] = [],
        # The bounce: on unless the world's `_bounce` is 0; the patches,
        # each face's grid of them, the light faces give off, how many
        # patches have gathered and how many lines of sight it took.
        bouncing: bool = True,
        patch_size: float = 64.0,
        patches: list[Patch] = [],
        face_patches: list[list[int]] = [],
        patch_grids: list[list[int]] = [],
        emission: dict[int, Vec3] = {},
        albedo: dict[int, Vec3] = {},
        next_patch: int = 0,
        rays: int = 0,
        ray_budget: int = 300000,
        # The grid for models: its spacing, its points, the eight bytes of
        # each (Quake III's light grid) and how many are lit.
        grid_size: Vec3 = Vec3(x=64.0, y=64.0, z=128.0),
        grid_points: list[Vec3] = [],
        grid: bytearray = bytearray(),
        next_point: int = 0,
        said: float = 0.0,
        # Lamps by the cells of a grid their reach touches, and patches by
        # the cells they lie in, so a point asks only those near it.
        lamp_cell: float = 256.0,
        lamp_buckets: dict[int, list[int]] = {},
        patch_buckets: dict[int, list[int]] = {},
        bounce_reach: float = 512.0;

    def light_key(ix: int, iy: int, iz: int) -> int {
        return ((ix + 2048) * 4096 + (iy + 2048)) * 4096 + (iz + 2048);
    }

    """Put each lamp in the buckets of the cells its reach touches."""
    def bucket_lamps {
        cell = self.lamp_cell;
        for (index, lamp) in enumerate(self.lamps) {
            reach = lamp.radius;
            for ix in range(int(math.floor((lamp.origin.x - reach) / cell)), int(math.floor((lamp.origin.x + reach) / cell)) + 1) {
                for iy in range(int(math.floor((lamp.origin.y - reach) / cell)), int(math.floor((lamp.origin.y + reach) / cell)) + 1) {
                    for iz in range(int(math.floor((lamp.origin.z - reach) / cell)), int(math.floor((lamp.origin.z + reach) / cell)) + 1) {
                        key = self.light_key(ix, iy, iz);
                        if key not in self.lamp_buckets {
                            self.lamp_buckets[key] = [];
                        }
                        self.lamp_buckets[key].append(index);
                    }
                }
            }
        }
    }

    """The lamps (by index) whose reach may touch a point."""
    def lamps_near(point: Vec3) -> list[int] {
        cell = self.lamp_cell;
        return self.lamp_buckets.get(
            self.light_key(int(math.floor(point.x / cell)), int(math.floor(point.y / cell)), int(math.floor(point.z / cell))), []
        );
    }

    """The lamps of one style that light a point."""
    def lit_by(point: Vec3, style: int = 0) -> list[Lamp] {
        if not self.lamp_buckets and self.lamps {
            self.bucket_lamps();
        }
        return self.lit_among(point, style, self.lamps_near(point));
    }

    """The lamps (by index) that can reach a face at all: near enough for
    their reach and in front of it."""
    def face_lamps(index: int) -> list[int] {
        face = self.made.bsp.faces[index];
        middle = Vec3();
        for vertex in face.vertices {
            middle = middle.add(vertex);
        }
        middle = middle.scale(1.0 / float(max(1, len(face.vertices))));
        span = 0.0;
        for vertex in face.vertices {
            span = max(span, vertex.sub(middle).length());
        }
        found: list[int] = [];
        for (lamp_index, lamp) in enumerate(self.lamps) {
            if lamp.origin.sub(middle).length() >= lamp.radius + span {
                continue;
            }
            if face.normal.dot(lamp.origin) - face.plane_dist < -1.0 {
                continue;
            }
            found.append(lamp_index);
        }
        return found;
    }

    """The lamps of one style among `candidates` (indices) that light a point."""
    def lit_among(point: Vec3, style: int, candidates: list[int]) -> list[Lamp] {
        reaching: list[Lamp] = [];
        for index in candidates {
            lamp = self.lamps[index];
            if self.lamp_styles[index] != style {
                continue;
            }
            cone = self.cones[index] if self.spotted and index < len(self.cones) else None;
            if cone is None {
                reaching.append(lamp);
                continue;
            }
            share = cone.share(lamp.origin, point);
            if share == 2 {
                reaching.append(lamp);
            } elif share == 1 and index < len(self.dims) {
                reaching.append(self.dims[index]);
            }
        }
        return reaching;
    }

    """How far it has got: from 0 to 1."""
    def share -> float {
        now = 1.0;
        if self.phase == "direct" {
            now = 0.7 * float(self.next_face - self.first) / float(max(1, self.last - self.first));
        } elif self.phase == "bounce" {
            now = 0.7 + 0.2 * float(self.next_patch) / float(max(1, len(self.patches)));
        } elif self.phase == "grid" {
            now = 0.9 + 0.1 * float(self.next_point) / float(max(1, len(self.grid_points)));
        }
        self.said = max(self.said, now);
        return self.said;
    }

    def finished -> bool {
        return self.phase == "ready";
    }

    """Light up to `limit` more faces of the world (or bounce to `limit`
    times sixteen patches, or light `limit` times thirty-two points of the
    grid). True when all is lit and `finish` may write it."""
    def step(limit: int) -> bool {
        if self.phase == "direct" {
            stop = min(self.last, self.next_face + max(1, limit));
            for index in range(self.next_face, stop) {
                self.light_face(index);
            }
            self.next_face = stop;
            if self.next_face < self.last {
                return False;
            }
            self.lay_patches();
            self.phase = "bounce";
        }
        if self.phase == "bounce" {
            stop = min(len(self.patches), self.next_patch + max(1, limit) * 16);
            for index in range(self.next_patch, stop) {
                self.gather(index);
            }
            self.next_patch = stop;
            if self.next_patch < len(self.patches) {
                return False;
            }
            self.lay_grid();
            self.phase = "grid";
        }
        if self.phase == "grid" {
            stop = min(len(self.grid_points), self.next_point + max(1, limit) * 32);
            for index in range(self.next_point, stop) {
                self.light_point(index);
            }
            self.next_point = stop;
            if self.next_point < len(self.grid_points) {
                return False;
            }
            self.phase = "ready";
        }
        return True;
    }

    """Whether any of a style's lamps comes near enough a face to light it."""
    def style_near(index: int, style: int) -> bool {
        face = self.made.bsp.faces[index];
        middle = Vec3();
        for vertex in face.vertices {
            middle = middle.add(vertex);
        }
        middle = middle.scale(1.0 / float(max(1, len(face.vertices))));
        reach = 0.0;
        for vertex in face.vertices {
            reach = max(reach, vertex.sub(middle).length());
        }
        for (lamp_index, lamp) in enumerate(self.lamps) {
            if self.lamp_styles[lamp_index] == style and lamp.origin.sub(middle).length() < lamp.radius + reach {
                return True;
            }
        }
        return False;
    }

    """A sample point of a face, a little off it: column `x` of `across`
    and row `y` of `down`."""
    def sample_point(index: int, x: int, y: int, across: int, down: int) -> Vec3 {
        face = self.made.bsp.faces[index];
        u = self.frames[index - self.first][0];
        v = self.frames[index - self.first][1];
        span = self.sizes[index - self.first];
        wide = max(0.001, span[1] - span[0]);
        tall = max(0.001, span[3] - span[2]);
        start = face.vertices[0];
        corner = start.add(u.scale(span[0] - start.dot(u))).add(v.scale(span[2] - start.dot(v)));
        # Samples on the rim sit a little inside it, off the neighbouring wall.
        s = max(0.5, min(wide - 0.5, wide * float(x) / float(max(1, across - 1))));
        t = max(0.5, min(tall - 0.5, tall * float(y) / float(max(1, down - 1))));
        return corner.add(u.scale(s)).add(v.scale(t)).add(face.normal.scale(0.25));
    }

    """Light one face directly: its steady lamps, then each style's."""
    def light_face(index: int) {
        bsp = self.made.bsp;
        luxel = self.luxel;
        face = bsp.faces[index];
        span = self.sizes[index - self.first];
        u = self.frames[index - self.first][0];
        v = self.frames[index - self.first][1];
        wide = max(0.001, span[1] - span[0]);
        tall = max(0.001, span[3] - span[2]);
        across = int(math.ceil(wide / luxel)) + 1;
        down = int(math.ceil(tall / luxel)) + 1;
        face.light_width = across;
        face.light_height = down;
        face.light_uv = [];
        for vertex in face.vertices {
            face.light_uv.extend(
                [
                    (vertex.dot(u) - span[0]) / wide * float(across - 1),
                    (vertex.dot(v) - span[2]) / tall * float(down - 1)
                ]
            );
        }
        self.dims_of.append([across, down]);
        steady: list[float] = [];
        layers: dict[int, list[float]] = {};
        others = sorted(set([style for style in self.lamp_styles if style != 0]));
        near = [style for style in others if self.style_near(index, style)];
        candidates = self.face_lamps(index);
        for style in near {
            layers[style] = [];
        }
        for y in range(down) {
            for x in range(across) {
                point = self.sample_point(index, x, y, across, down);
                # Only the lamps' own light: how dark it may get is the
                # world's `_minlight` (`least`), not the shading's ambient.
                sample = shade(point, face.normal, self.lit_among(point, 0, candidates), self.occluder);
                color = sample.directed;
                steady.extend([color.x, color.y, color.z]);
                for style in near {
                    lit = shade(point, face.normal, self.lit_among(point, style, candidates), self.occluder).directed;
                    layers[style].extend([lit.x, lit.y, lit.z]);
                }
            }
        }
        self.steady.append(steady);
        # Only the styles that light it at all, the brightest three.
        kept: dict[int, list[float]] = {};
        ranked = sorted([(-sum(layers[style]), style) for style in near if max(layers[style]) > 0.004]);
        for (weight, style) in ranked[:3] {
            kept[style] = layers[style];
        }
        self.styled.append(kept);
    }

    """Cut each face of the world into patches about `patch_size` across,
    each taking the steady light its samples have (less the even ambient)
    times what its material gives back, and the light it gives off."""
    def lay_patches {
        bsp = self.made.bsp;
        if not self.bouncing {
            return;
        }
        for index in range(self.first, self.last) {
            at = index - self.first;
            face = bsp.faces[index];
            span = self.sizes[at];
            wide = max(0.001, span[1] - span[0]);
            tall = max(0.001, span[3] - span[2]);
            columns = max(1, int(math.ceil(wide / self.patch_size)));
            rows = max(1, int(math.ceil(tall / self.patch_size)));
            self.patch_grids.append([columns, rows]);
            u = self.frames[at][0];
            v = self.frames[at][1];
            start = face.vertices[0];
            corner = start.add(u.scale(span[0] - start.dot(u))).add(v.scale(span[2] - start.dot(v)));
            # The steady light of the samples in each patch, summed.
            sums: list[Vec3] = [Vec3() for cell in range(columns * rows)];
            counts: list[int] = [0 for cell in range(columns * rows)];
            across = self.dims_of[at][0];
            down = self.dims_of[at][1];
            for y in range(down) {
                for x in range(across) {
                    column = min(columns - 1, int(float(x) / float(max(1, across - 1)) * float(columns)));
                    row = min(rows - 1, int(float(y) / float(max(1, down - 1)) * float(rows)));
                    p = (y * across + x) * 3;
                    cell = row * columns + column;
                    sums[cell] = sums[cell].add(
                        Vec3(
                            x=max(0.0, self.steady[at][p]),
                            y=max(0.0, self.steady[at][p + 1]),
                            z=max(0.0, self.steady[at][p + 2])
                        )
                    );
                    counts[cell] += 1;
                }
            }
            texture = face.texture;
            if texture not in self.albedo {
                self.albedo[texture] = texture_albedo(bsp.textures[texture]) if 0 <= texture < len(bsp.textures) else Vec3(x=0.5, y=0.5, z=0.5);
            }
            reflect = self.albedo[texture];
            glow = self.emission.get(index, Vec3());
            members: list[int] = [];
            for row in range(rows) {
                for column in range(columns) {
                    cell = row * columns + column;
                    direct = sums[cell].scale(1.0 / float(max(1, counts[cell])));
                    patch = Patch(
                        face=index,
                        spot=corner.add(u.scale(wide * (float(column) + 0.5) / float(columns)))
                            .add(v.scale(tall * (float(row) + 0.5) / float(rows)))
                            .add(face.normal.scale(1.0)),
                        normal=face.normal,
                        area=wide * tall / float(columns * rows),
                        column=column,
                        row=row,
                        out=Vec3(x=direct.x * reflect.x, y=direct.y * reflect.y, z=direct.z * reflect.z).add(glow)
                    );
                    members.append(len(self.patches));
                    self.patches.append(patch);
                }
            }
            self.face_patches.append(members);
        }
    }

    """What one patch gathers of the light every other gives back or off,
    each as much as the two see of each other across the distance between
    them, where nothing stands between them."""
    def gather(index: int) {
        receiver = self.patches[index];
        total = Vec3();
        if not self.patch_buckets {
            for (patch_index, patch) in enumerate(self.patches) {
                # Only patches that give light back or off are worth asking.
                if patch.out.x + patch.out.y + patch.out.z < 0.01 {
                    continue;
                }
                key = self.light_key(
                    int(math.floor(patch.spot.x / self.bounce_reach)),
                    int(math.floor(patch.spot.y / self.bounce_reach)),
                    int(math.floor(patch.spot.z / self.bounce_reach))
                );
                if key not in self.patch_buckets {
                    self.patch_buckets[key] = [];
                }
                self.patch_buckets[key].append(patch_index);
            }
        }
        nearby: list[int] = [];
        bx = int(math.floor(receiver.spot.x / self.bounce_reach));
        by_ = int(math.floor(receiver.spot.y / self.bounce_reach));
        bz = int(math.floor(receiver.spot.z / self.bounce_reach));
        for ix in [bx - 1, bx, bx + 1] {
            for iy in [by_ - 1, by_, by_ + 1] {
                for iz in [bz - 1, bz, bz + 1] {
                    nearby.extend(self.patch_buckets.get(self.light_key(ix, iy, iz), []));
                }
            }
        }
        for other_index in nearby {
            other = self.patches[other_index];
            if other.face == receiver.face or other.out.x + other.out.y + other.out.z < 0.01 {
                continue;
            }
            delta = other.spot.sub(receiver.spot);
            reach = delta.length();
            if reach < 0.001 {
                continue;
            }
            way = delta.scale(1.0 / reach);
            facing_here = receiver.normal.dot(way);
            facing_there = -other.normal.dot(way);
            if facing_here <= 0.0 or facing_there <= 0.0 {
                continue;
            }
            # The form factor of a small patch, kept finite close up.
            factor = other.area * facing_here * facing_there / (math.pi * max(reach * reach, other.area));
            amount = other.out.scale(factor);
            if max(amount.x, max(amount.y, amount.z)) < 0.002 {
                continue;
            }
            if self.rays >= self.ray_budget {
                break;
            }
            self.rays += 1;
            if self.occluder.visibility(receiver.spot, other.spot) > 0.0 {
                total = total.add(amount);
            }
        }
        receiver.gathered = total;
    }

    """The points of the grid for models, over the world's bounds as Quake
    III lays them out (the world's `gridsize`, 64 64 128 unless it says)."""
    def lay_grid {
        bsp = self.made.bsp;
        if not bsp.models {
            return;
        }
        world = bsp.models[0];
        low = [world.mins.x, world.mins.y, world.mins.z];
        high = [world.maxs.x, world.maxs.y, world.maxs.z];
        steps = [self.grid_size.x, self.grid_size.y, self.grid_size.z];
        starts: list[float] = [];
        counts: list[int] = [];
        for axis in range(3) {
            start = steps[axis] * math.ceil(low[axis] / steps[axis]);
            end = steps[axis] * math.floor(high[axis] / steps[axis]);
            starts.append(start);
            counts.append(int((end - start) / steps[axis]) + 1);
        }
        if counts[0] <= 0 or counts[1] <= 0 or counts[2] <= 0 or counts[0] * counts[1] * counts[2] > 200000 {
            return;
        }
        for z in range(counts[2]) {
            for y in range(counts[1]) {
                for x in range(counts[0]) {
                    self.grid_points.append(
                        Vec3(x=starts[0] + float(x) * steps[0], y=starts[1] + float(y) * steps[1], z=starts[2] + float(z) * steps[2])
                    );
                }
            }
        }
        self.grid = bytearray(len(self.grid_points) * 8);
    }

    """Light one point of the grid: nothing inside a brush (a model there
    takes its light from the points around it), else what the steady lamps
    give a model there, kept at a quarter of its strength as Quake III's
    grid is, and the way the light comes from."""
    def light_point(index: int) {
        point = self.grid_points[index];
        occluder = self.occluder;
        if occluder.holds(point) {
            return;
        }
        sample = shade(point, Vec3(z=1.0), self.lit_by(point), occluder, probe=True);
        at = index * 8;
        values = [sample.ambient.x, sample.ambient.y, sample.ambient.z, sample.directed.x, sample.directed.y, sample.directed.z];
        for (place, value) in enumerate(values) {
            self.grid[at + place] = u8(int(max(1.0 if place < 3 else 0.0, min(255.0, value * 255.0 / 4.0))));
        }
        way = sample.direction;
        if way.length() < 0.00001 {
            way = Vec3(z=1.0);
        }
        down_angle = math.acos(max(-1.0, min(1.0, way.z)));
        round_angle = math.atan2(way.y, way.x);
        if round_angle < 0.0 {
            round_angle += 2.0 * math.pi;
        }
        self.grid[at + 6] = u8(int(round(down_angle / (2.0 * math.pi) * 256.0)) % 256);
        self.grid[at + 7] = u8(int(round(round_angle / (2.0 * math.pi) * 256.0)) % 256);
    }

    """The light a face's sample gathered by bouncing: the patches around it
    blended by how near each is."""
    def bounced(at: int, x: int, y: int) -> Vec3 {
        if not self.bouncing or at >= len(self.face_patches) {
            return Vec3();
        }
        columns = self.patch_grids[at][0];
        rows = self.patch_grids[at][1];
        across = self.dims_of[at][0];
        down = self.dims_of[at][1];
        fx = max(0.0, min(float(columns - 1), float(x) / float(max(1, across - 1)) * float(columns) - 0.5));
        fy = max(0.0, min(float(rows - 1), float(y) / float(max(1, down - 1)) * float(rows) - 0.5));
        x0 = int(fx);
        y0 = int(fy);
        x1 = min(columns - 1, x0 + 1);
        y1 = min(rows - 1, y0 + 1);
        tx = fx - float(x0);
        ty = fy - float(y0);
        members = self.face_patches[at];
        top = self.patches[members[y0 * columns + x0]].gathered.scale(1.0 - tx).add(self.patches[members[y0 * columns + x1]].gathered.scale(tx));
        bottom = self.patches[members[y1 * columns + x0]].gathered.scale(1.0 - tx).add(self.patches[members[y1 * columns + x1]].gathered.scale(tx));
        return top.scale(1.0 - ty).add(bottom.scale(ty));
    }

    """Write what was lit into the level: each face's lightmap (its steady
    light with what it gathered, what it gives off and the least light,
    then a layer for each style that reaches it), the grid, and the
    corners of what moves. Answers how many samples were lit."""
    def finish -> int {
        bsp = self.made.bsp;
        least = self.least;
        pixels = bytearray();
        for index in range(self.first, self.last) {
            at = index - self.first;
            face = bsp.faces[index];
            across = self.dims_of[at][0];
            down = self.dims_of[at][1];
            face.light_offset = len(pixels);
            face.colors = [];
            glow = self.emission.get(index, Vec3());
            lit_up = Vec3(x=min(1.0, glow.x * 0.5), y=min(1.0, glow.y * 0.5), z=min(1.0, glow.z * 0.5));
            steady = self.steady[at];
            for y in range(down) {
                for x in range(across) {
                    p = (y * across + x) * 3;
                    gathered = self.bounced(at, x, y);
                    for (channel, extra) in enumerate([gathered.x + lit_up.x, gathered.y + lit_up.y, gathered.z + lit_up.z]) {
                        pixels.append(u8(int(max(0.0, min(127.0, max(least, steady[p + channel] + extra) * 127.5)))));
                    }
                }
            }
            face.styles = [0];
            for (style, layer) in self.styled[at].items() {
                face.styles.append(style);
                for value in layer {
                    pixels.append(u8(int(max(0.0, min(127.0, value * 127.5)))));
                }
            }
        }
        bsp.lighting = bytes(pixels);
        bsp.light_channels = 3;
        bsp.light_grid = bytes(self.grid);
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
        styles = len([kept for kept in self.styled if kept]);
        self.made.light_notes = "patches=" + str(len(self.patches)) + " rays=" + str(self.rays) + " grid="
            + str(len(self.grid_points)) + " styled=" + str(styles) + " glowing=" + str(len(self.emission));
        if self.rays >= self.ray_budget {
            self.made.warnings.append("Light bounced only as far as " + str(self.ray_budget) + " lines of sight");
        }
        return self.total;
    }
}

"""The light each face of the world gives off: a side whose value says it
glows (Quake II's surface light, about 100 a unit of the bake's light),
in the colour of its material at its brightest."""
def:priv face_glow(scene: Scene, made: LiveLevel) -> dict[int, Vec3] {
    bsp = made.bsp;
    glowing: dict[int, Vec3] = {};
    for item in scene.items() {
        if item.classname() not in ["worldspawn", "func_group"] {
            continue;
        }
        for solid in scene.solids_of(item) {
            for side in solid.sides {
                if side.value <= 0 or side.flags & 1 == 0 {
                    continue;
                }
                for index in made.faces_of.get(solid.serial, []) {
                    face = bsp.faces[index];
                    if face.normal.dot(side.plane.normal) > 0.999 and abs(face.plane_dist - side.plane.dist) < 0.01 {
                        tint = texture_albedo(bsp.textures[face.texture]) if 0 <= face.texture < len(bsp.textures) else Vec3(x=1.0, y=1.0, z=1.0);
                        brightest = max(0.01, max(tint.x, max(tint.y, tint.z)));
                        glowing[index] = tint.scale(float(side.value) / 100.0 / brightest);
                    }
                }
            }
        }
    }
    return glowing;
}

"""The job of lighting the level a scene compiled to, or none when the
scene has no lamps and nothing glows, or it would take more than `budget`
samples (the level is then left flat, with a warning)."""
def light_job(scene: Scene, made: LiveLevel, luxel: float = 16.0, budget: int = 400000) -> LightJob | None {
    lamps: list[Lamp] = [];
    styles: list[int] = [];
    switches = switch_styles(scene.items());
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
        styles.append(lamp_style(item, switches));
    }
    bsp = made.bsp;
    glowing = face_glow(scene, made);
    if (len(lamps) == 0 and len(glowing) == 0) or len(bsp.models) == 0 {
        return None;
    }
    job = LightJob(made=made, lamps=lamps, lamp_styles=styles, least=scene_floor(scene), luxel=luxel, emission=glowing);
    # Lamps that shine one way light only what is in their cones.
    job.cones = scene_cones(scene);
    job.spotted = len([cone for cone in job.cones if cone is not None]) > 0;
    job.dims = [
        Lamp(origin=lamp.origin, color=lamp.color, radius=lamp.radius, strength=lamp.strength * 0.5) for lamp in lamps
    ] if job.spotted else [];
    for item in scene.items() {
        if item.classname() == "worldspawn" {
            job.bouncing = item.fields.get("_bounce", "1").strip() not in ["0", "0.0"];
            words = item.fields.get("gridsize", "").split();
            if len(words) == 3 {
                try {
                    job.grid_size = Vec3(x=max(8.0, float(words[0])), y=max(8.0, float(words[1])), z=max(8.0, float(words[2])));
                } except ValueError {
                    job.grid_size = Vec3(x=64.0, y=64.0, z=128.0);
                }
            }
        }
    }
    occluder = BrushOccluder();
    for item in scene.items() {
        # What moves, and what is only a volume, casts no fixed shadow.
        if item.classname() not in ["worldspawn", "func_group", "func_wall", "func_static"] {
            continue;
        }
        for solid in scene.solids_of(item) {
            # Caulked sides still stand in the way; only what one sees
            # through casts no shadow.
            if solid.sides and not material_clear(solid.sides[0].material) and brush_contents(solid.sides) & LIQUID_BITS == 0 {
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
    # Bounced light in patches no smaller than four samples, and not so
    # many that each would look at too many others.
    job.patch_size = max(64.0, luxel * 4.0);
    while float(total) * luxel * luxel / (job.patch_size * job.patch_size) > 2500.0 {
        job.patch_size *= 2.0;
    }
    return job;
}

"""Light the level a scene compiled to. Answers how many samples were lit:
none when the scene has no lamps and nothing glows, or when it would take
more than `budget` of them (the level is then left flat)."""
def bake_light(scene: Scene, made: LiveLevel, luxel: float = 16.0, budget: int = 400000) -> int {
    job = light_job(scene, made, luxel, budget);
    if job is None {
        return 0;
    }
    while not job.step(job.last - job.first + 1) {
        continue;
    }
    return job.finish();
}
