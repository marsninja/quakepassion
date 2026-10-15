"""The live tier: a document's brushes as a level, at once.

Every brush becomes its faces and its collision planes, exactly as drawn: no
hidden faces are removed, the whole world is one leaf that sees itself, and
light is a flat shade by the way a face looks. It is what the level view
shows while a scene is edited and what Play runs before a bake. The level is
a "passion" one, so it plays by the rules generated expeditions do and may
hold any game's entities."""
import from engine.formats.bsp { Bsp, Face, Brush, Plane, Leaf, Model, MapEntity, Texture }
import from engine.math.vec3 { Vec3 }
import from ..document.scene { Scene, Item, Solid }
import from ..geometry.brush { Side, brush_windings }
import from .cull { FaceCutter, material_clear }

"""Where a material's image comes from."""
obj Materials {
    def texture(name: str) -> Texture abst;
}

"""Materials as flat swatches: a colour from the name, with a line every 64
units and a fainter one every 16, so a blockout reads its own scale and no
game's archives are needed."""
obj SwatchMaterials(Materials) {
    def texture(name: str) -> Texture {
        return swatch_texture(name);
    }
}

"""A swatch for a material name."""
def swatch_texture(name: str) -> Texture {
    seed = 7;
    for letter in name {
        seed = (seed * 31 + ord(letter)) % 1000003;
    }
    # Muted, so entities and selection read over it.
    red = 70 + seed % 90;
    green = 70 + (seed // 97) % 90;
    blue = 70 + (seed // 9409) % 90;
    if not name {
        red = 120;
        green = 120;
        blue = 120;
    }
    size = 64;
    pixels = bytearray(size * size * 4);
    for y in range(size) {
        for x in range(size) {
            shade = 100;
            if x == 0 or y == 0 {
                shade = 60;
            } elif x % 16 == 0 or y % 16 == 0 {
                shade = 88;
            }
            at = (y * size + x) * 4;
            pixels[at] = u8(red * shade // 100);
            pixels[at + 1] = u8(green * shade // 100);
            pixels[at + 2] = u8(blue * shade // 100);
            pixels[at + 3] = u8(255);
        }
    }
    return Texture(name="studio:" + name, width=size, height=size, rgba=bytes(pixels));
}

"""Materials that make a brush's face collide without being drawn, or do
neither (a trigger's volume)."""
def material_hidden(name: str) -> bool {
    last = name.lower().split("/")[-1].split(":")[-1];
    return last in ["clip", "playerclip", "monsterclip", "caulk", "nodraw", "skip", "trigger", "hint", "origin", "areaportal"];
}

# Quake II's contents: lava 8, slime 16, water 32.
glob LIQUID_BITS: int = 56;

"""What a brush is made of: what its sides say (a map's contents field),
else a liquid by its material's name (Quake's `*` textures, and those named
for water, slime or lava: lava 8, slime 16, water 32), else solid (1)."""
def brush_contents(sides: list[Side]) -> int {
    said = 0;
    for side in sides {
        said = said | side.contents;
    }
    if said & LIQUID_BITS != 0 {
        return said & LIQUID_BITS;
    }
    if said != 0 {
        return said;
    }
    if sides and liquid_material(sides[0].material) {
        lowered = sides[0].material.lower();
        if "lava" in lowered {
            return 8;
        }
        return 16 if "slime" in lowered else 32;
    }
    return 1;
}

"""The light style each switched light takes, by its name: as Quake's
light tool gives them, from 32 up (to 62) in the order the names first
come, for lights with a `targetname` and no style of their own."""
def switch_styles(items: list[Item]) -> dict[str, int] {
    styles: dict[str, int] = {};
    for item in items {
        name = item.fields.get("targetname", "");
        style = item.fields.get("style", "0").strip();
        if not item.classname().startswith("light") or not name or name in styles {
            continue;
        }
        if style.isdigit() and int(style) > 0 {
            continue;
        }
        if 32 + len(styles) <= 62 {
            styles[name] = 32 + len(styles);
        }
    }
    return styles;
}

"""What a scene compiled to, with which faces came from which brush (for the
level view to light up a selection)."""
obj LiveLevel {
    has bsp: Bsp,
        # Brush serial to the faces it made.
        faces_of: dict[int, list[int]] = {},
        brushes: int = 0,
        warnings: list[str] = [],
        # A bake by planes: each leaf's outline, the portals between leaves,
        # and the two leaves each portal joins.
        shapes: list[list[list[Vec3]]] = [],
        # What the light bake did beyond the lightmaps: its patches, lines
        # of sight, grid points, faces with styles and faces that glow.
        light_notes: str = "",
        portals: list[list[Vec3]] = [],
        portal_ends: list[int] = [];
}

"""Compiles a scene: keeps the level being built and the textures in use."""
obj LiveCompiler {
    has materials: Materials,
        result: LiveLevel = LiveLevel(bsp=Bsp(game="passion")),
        texture_index: dict[str, int] = {},
        low: Vec3 = Vec3(x=-256.0, y=-256.0, z=-256.0),
        high: Vec3 = Vec3(x=256.0, y=256.0, z=256.0),
        # When set, the world's brush sides are cut against the brushes
        # around them and only what shows is drawn (brush serial to its
        # index in the cutter).
        cutter: FaceCutter | None = None,
        cut_index: dict[int, int] = {};

    def texture(name: str) -> int {
        if name not in self.texture_index {
            bsp = self.result.bsp;
            self.texture_index[name] = len(bsp.textures);
            bsp.textures.append(self.materials.texture(name));
        }
        return self.texture_index[name];
    }

    """Add a brush to a model: its planes for collision, and a face for each
    side that has an outline and a material that draws. `volume` brushes
    (triggers) collide with nothing and draw nothing."""
    def add(solid: Solid, model: int, volume: bool = False) {
        for label in self.add_steps(solid, model, volume) {
            continue;
        }
    }

    """`add` a step at a time: it pauses while a side many brushes cover is
    cut."""
    def add_steps(solid: Solid, model: int, volume: bool = False) -> Iterator[str] {
        bsp = self.result.bsp;
        outlines = brush_windings(solid.sides);
        brush = Brush(contents=0 if volume else brush_contents(solid.sides));
        made: list[int] = [];
        record = bsp.models[model];
        for (index, side) in enumerate(solid.sides) {
            brush.planes.append(len(bsp.planes));
            bsp.planes.append(Plane(normal=side.plane.normal, distance=side.plane.dist));
            outline = outlines[index];
            for point in outline {
                self.low = Vec3(x=min(self.low.x, point.x), y=min(self.low.y, point.y), z=min(self.low.z, point.z));
                self.high = Vec3(x=max(self.high.x, point.x), y=max(self.high.y, point.y), z=max(self.high.z, point.z));
                record.mins = Vec3(x=min(record.mins.x, point.x), y=min(record.mins.y, point.y), z=min(record.mins.z, point.z));
                record.maxs = Vec3(x=max(record.maxs.x, point.x), y=max(record.maxs.y, point.y), z=max(record.maxs.z, point.z));
            }
            if volume or len(outline) < 3 or material_hidden(side.material) {
                continue;
            }
            texture = self.texture(side.material);
            image = bsp.textures[texture];
            normal = side.plane.normal;
            pieces = [outline];
            cutter = self.cutter;
            if cutter is not None and model == 0 and solid.serial in self.cut_index {
                pieces = [];
                yield from cutter.piece_steps(self.cut_index[solid.serial], outline, normal, side.plane.dist, pieces);
            }
            # Full light from above, less on the sides (east and west a
            # little more than north and south), least from below.
            shade = int(205.0 + 50.0 * max(0.0, normal.z) + 15.0 * abs(normal.x) - 35.0 * max(0.0, -normal.z));
            for piece in pieces {
                # The renderer's faces wind the other way from a map's.
                corners = [piece[len(piece) - 1 - i] for i in range(len(piece))];
                face = Face(vertices=corners, normal=normal, plane_dist=side.plane.dist, texture=texture);
                if brush.contents & LIQUID_BITS != 0 {
                    # A liquid's surface ripples and is seen from below too.
                    face.warp = True;
                    face.two_sided = True;
                }
                for i in range(1, len(corners) - 1) {
                    face.indices.extend([0, i, i + 1]);
                }
                for corner in corners {
                    texel = side.mapping.texel(corner);
                    face.uv.extend([texel[0] / float(max(1, image.width)), texel[1] / float(max(1, image.height))]);
                    face.colors.extend([shade, shade, shade, 255]);
                }
                made.append(len(bsp.faces));
                bsp.leaves[0].faces.append(len(bsp.faces));
                bsp.faces.append(face);
                record.face_count += 1;
            }
        }
        record.brushes.append(len(bsp.brushes));
        bsp.brushes.append(brush);
        self.result.faces_of[solid.serial] = made;
        self.result.brushes += 1;
    }

    def begin_model -> int {
        bsp = self.result.bsp;
        far = 1000000.0;
        bsp.models.append(
            Model(
                head=0 if bsp.models else -1,
                first_face=len(bsp.faces),
                face_count=0,
                mins=Vec3(x=far, y=far, z=far),
                maxs=Vec3(x=-far, y=-far, z=-far)
            )
        );
        return len(bsp.models) - 1;
    }

    """A model with no brushes has no bounds of its own."""
    def end_model(model: int) {
        record = self.result.bsp.models[model];
        if record.mins.x > record.maxs.x {
            record.mins = Vec3();
            record.maxs = Vec3();
        }
    }
}

"""Compile a scene to a level's data. The world's brushes are model 0; each
other entity that owns brushes gets a model of its own and a `model` field
naming it."""
def compile_scene(scene: Scene, materials: Materials, cut: bool = False) -> LiveLevel {
    into = Compiling();
    for label in compile_steps(scene, materials, cut, into) {
        continue;
    }
    compiler = into.compiler;
    if compiler is None {
        raise ValueError("The scene was not compiled");
    }
    return compiler.result;
}

"""A scene's compile as it goes: the compiler, its level so far in its
`result`, and how many brushes it has taken of how many."""
obj Compiling {
    has compiler: LiveCompiler | None = None,
        done: int = 0,
        total: int = 0;
}

glob COMPILE_SLICE: int = 12;

"""`compile_scene` a slice at a time: it pauses every few brushes cut or
compiled, and leaves the compiler (and its level) in `into`."""
def compile_steps(scene: Scene, materials: Materials, cut: bool, into: Compiling) -> Iterator[str] {
    compiler = LiveCompiler(materials=materials);
    into.compiler = compiler;
    into.total = len(scene.solids()) * (2 if cut else 1);
    result = compiler.result;
    bsp = result.bsp;
    if cut {
        # The world's brushes that cover what lies in them: every brush of
        # the world and its groups but those one sees through.
        cutter = FaceCutter();
        for item in scene.items() {
            if item.classname() not in ["worldspawn", "func_group"] {
                continue;
            }
            for solid in scene.solids_of(item) {
                # What one sees through (clip, triggers, liquids) covers nothing.
                if solid.sides and not material_clear(solid.sides[0].material) and brush_contents(solid.sides) & LIQUID_BITS == 0 {
                    compiler.cut_index[solid.serial] = cutter.add(solid.sides, brush_windings(solid.sides));
                }
                into.done += 1;
                if into.done % COMPILE_SLICE == 0 {
                    yield "cut";
                }
            }
        }
        compiler.cutter = cutter;
    }
    bsp.leaves.append(Leaf(contents=0, vis_offset=0, mins=Vec3(), maxs=Vec3(), cluster=0));
    world_model = compiler.begin_model();
    world_fields: dict[str, str] = {"classname": "worldspawn"};
    others: list[Item] = [];
    for item in scene.items() {
        if item.classname() == "worldspawn" {
            for (key, value) in item.fields.items() {
                world_fields[key] = value;
            }
            for solid in scene.solids_of(item) {
                yield from compiler.add_steps(solid, world_model);
                into.done += 1;
                if into.done % COMPILE_SLICE == 0 {
                    yield "compile";
                }
            }
        } elif item.classname() == "func_group" {
            # A group is a way of holding the world's brushes, not a thing
            # in the level.
            for solid in scene.solids_of(item) {
                yield from compiler.add_steps(solid, world_model);
                into.done += 1;
                if into.done % COMPILE_SLICE == 0 {
                    yield "compile";
                }
            }
        } else {
            others.append(item);
        }
    }
    compiler.end_model(world_model);
    bsp.entities.append(MapEntity(fields=world_fields));
    starts = 0;
    switches = switch_styles(scene.items());
    for item in others {
        fields: dict[str, str] = dict(item.fields);
        solids = scene.solids_of(item);
        if solids {
            model = compiler.begin_model();
            # Triggers, and an area portal's brushes (a bake reads them from
            # the scene), are not there to be bumped into or seen.
            volume = item.classname().startswith("trigger_") or item.classname() == "func_areaportal";
            for solid in solids {
                compiler.add(solid, model, volume);
            }
            compiler.end_model(model);
            fields["model"] = "*" + str(model);
        } elif fields.get("model", "").startswith("*") {
            # A brush entity without its brushes has nothing to show.
            result.warnings.append(item.title() + " names a map model the scene does not have");
            fields.pop("model", None);
        }
        if item.classname().startswith("light") and item.fields.get("targetname", "") in switches {
            # A light something switches has a style of its own to switch.
            fields["style"] = str(switches[item.fields.get("targetname", "")]);
        }
        if item.classname() == "info_player_start" {
            starts += 1;
        }
        bsp.entities.append(MapEntity(fields=fields));
    }
    if starts == 0 {
        result.warnings.append("The scene has no info_player_start");
    }
    if len(bsp.models) < 2 {
        # Lighting takes faces from models[1] onward as moving: keep one.
        compiler.end_model(compiler.begin_model());
    }
    room = Vec3(x=64.0, y=64.0, z=64.0);
    bsp.leaves[0].mins = compiler.low.sub(room);
    bsp.leaves[0].maxs = compiler.high.add(room);
    bsp.models[0].vis_leaf_count = 0;
    # One cluster that sees itself: an eight byte header, then a row of bits
    # for each cluster, as the level reads a generated level's visibility.
    bsp.clusters = 1;
    bsp.cluster_bytes = 1;
    bsp.visibility = bytes([0, 0, 0, 0, 0, 0, 0, 0, 1]);
    yield "compiled";
}

"""What changed between two compiles of a scene where only brushes of the
world moved or changed shape: the faces whose corners, texture coordinates
or colours differ, and the brushes whose planes do."""
obj LiveChanges {
    has faces: list[int] = [],
        brushes: list[int] = [];
}

def:priv same_point(first: Vec3, second: Vec3) -> bool {
    return abs(first.x - second.x) < 0.0001 and abs(first.y - second.y) < 0.0001 and abs(first.z - second.z) < 0.0001;
}

"""Whether a material is a liquid's, which the level reads its water from."""
def:priv liquid_material(name: str) -> bool {
    lowered = name.lower();
    return lowered.split("/")[-1].split(":")[-1].startswith("*") or "water" in lowered or "slime" in lowered or "lava" in lowered;
}

"""The faces and brushes of the world that changed from one compile of a
scene (`old`) to the next (`new`), for a level that can be brought in line
in place. None when anything else changed: the entities, the materials,
the count of faces, brushes, planes or models, a face's count of corners
or its material, a brush of another model, or a liquid."""
def level_changes(old: Bsp, new: Bsp) -> LiveChanges | None {
    if len(old.faces) != len(new.faces) or len(old.brushes) != len(new.brushes) or len(old.planes) != len(new.planes)
        or len(old.models) != len(new.models) or len(old.textures) != len(new.textures)
        or len(old.entities) != len(new.entities) or len(old.models) == 0 {
        return None;
    }
    for (index, entity) in enumerate(old.entities) {
        if entity.fields != new.entities[index].fields {
            return None;
        }
    }
    for (index, texture) in enumerate(old.textures) {
        if texture.name != new.textures[index].name {
            return None;
        }
    }
    for (index, model) in enumerate(old.models) {
        other = new.models[index];
        if model.first_face != other.first_face or model.face_count != other.face_count or model.brushes != other.brushes {
            return None;
        }
    }
    world = old.models[0];
    found = LiveChanges();
    for index in range(len(old.faces)) {
        was = old.faces[index];
        now = new.faces[index];
        if was.texture != now.texture or len(was.vertices) != len(now.vertices) {
            return None;
        }
        moved = not same_point(was.normal, now.normal) or was.uv != now.uv or was.colors != now.colors;
        for corner in range(len(was.vertices)) {
            if not moved and not same_point(was.vertices[corner], now.vertices[corner]) {
                moved = True;
            }
        }
        if not moved {
            continue;
        }
        if index < world.first_face or index >= world.first_face + world.face_count
            or (0 <= was.texture < len(old.textures) and liquid_material(old.textures[was.texture].name)) {
            return None;
        }
        found.faces.append(index);
    }
    for index in range(len(old.brushes)) {
        before = old.brushes[index];
        after = new.brushes[index];
        if before.contents != after.contents or before.planes != after.planes {
            return None;
        }
        moved = False;
        for plane in before.planes {
            if not same_point(old.planes[plane].normal, new.planes[plane].normal)
                or abs(old.planes[plane].distance - new.planes[plane].distance) > 0.0001 {
                moved = True;
            }
        }
        if moved {
            if index not in world.brushes {
                return None;
            }
            found.brushes.append(index);
        }
    }
    return found;
}

"""Bring a compiled level in line with the next compile of its scene, where
`level_changes` found only these: the changed faces and planes taken from
it, and the bounds of the world and its leaf."""
def take_changes(old: Bsp, new: Bsp, changes: LiveChanges) {
    for index in changes.faces {
        old.faces[index] = new.faces[index];
    }
    for index in changes.brushes {
        for plane in old.brushes[index].planes {
            old.planes[plane] = new.planes[plane];
        }
    }
    for (index, model) in enumerate(old.models) {
        model.mins = new.models[index].mins;
        model.maxs = new.models[index].maxs;
    }
    if old.leaves and new.leaves {
        old.leaves[0].mins = new.leaves[0].mins;
        old.leaves[0].maxs = new.leaves[0].maxs;
    }
}
