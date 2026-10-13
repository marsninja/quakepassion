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
        portals: list[list[Vec3]] = [],
        portal_ends: list[int] = [];
}

"""Compiles a scene: keeps the level being built and the textures in use."""
obj LiveCompiler {
    has materials: Materials,
        result: LiveLevel = LiveLevel(bsp=Bsp(game="passion")),
        texture_index: dict[str, int] = {},
        low: Vec3 = Vec3(x=-256.0, y=-256.0, z=-256.0),
        high: Vec3 = Vec3(x=256.0, y=256.0, z=256.0);

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
        bsp = self.result.bsp;
        outlines = brush_windings(solid.sides);
        brush = Brush(contents=0 if volume else 1);
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
            # The renderer's faces wind the other way from a map's.
            corners = [outline[len(outline) - 1 - i] for i in range(len(outline))];
            face = Face(vertices=corners, normal=normal, plane_dist=side.plane.dist, texture=texture);
            for i in range(1, len(corners) - 1) {
                face.indices.extend([0, i, i + 1]);
            }
            # Full light from above, less on the sides (east and west a
            # little more than north and south), least from below.
            shade = int(205.0 + 50.0 * max(0.0, normal.z) + 15.0 * abs(normal.x) - 35.0 * max(0.0, -normal.z));
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
def compile_scene(scene: Scene, materials: Materials) -> LiveLevel {
    compiler = LiveCompiler(materials=materials);
    result = compiler.result;
    bsp = result.bsp;
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
                compiler.add(solid, world_model);
            }
        } elif item.classname() == "func_group" {
            # A group is a way of holding the world's brushes, not a thing
            # in the level.
            for solid in scene.solids_of(item) {
                compiler.add(solid, world_model);
            }
        } else {
            others.append(item);
        }
    }
    compiler.end_model(world_model);
    bsp.entities.append(MapEntity(fields=world_fields));
    starts = 0;
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
    return result;
}
