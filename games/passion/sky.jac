"""A made level's sky.

A Passion level's sky materials are its rooms' ceilings like any others, in
the proof and in collision. What they show is decided here, once a level is
open: one sky for the level, of the game its open rooms' kit comes from, and
every sky material in it shows that one.

  Quake: the material's own two scrolling layers.
  Quake II: the `env/` box its original's worldspawn names. A kit knows the
  original it was read from; a sky material is a tile that does not say.
  Quake III: the far box and clouds of the material's shader.

The worldspawn's `_sky` and `_sky_source` say which, for a generated level;
a level made otherwise (a studio scene, `sky` in its worldspawn if it likes)
takes its commonest sky material. Whatever cannot be found leaves the level
drawn as it was."""
import from engine.assets.catalog { AssetCatalog }
import from engine.formats.bsp { Texture }
import from engine.formats.numbers { atof }
import from engine.formats.q2.bsp { worldspawn_fields }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level }

"""A level's name for a texture, as a material's: without the mark a swatch
stands in with when the game's archives lack the image."""
def:priv material_of(name: str) -> str {
    return name[7:] if name.startswith("studio:") else name;
}

"""Whether a material is a sky: as the games tell, by name for Quake (`sky4`)
and Quake II (`e1u3/sky1`), by its shader for Quake III."""
def sky_material(name: str, catalog: AssetCatalog) -> bool {
    parts = name.split(":", 1);
    if len(parts) != 2 {
        return False;
    }
    last = parts[1].split("/")[-1].lower();
    if parts[0] == "q1" {
        return last.startswith("sky");
    }
    if parts[0] == "q2" {
        return "sky" in last;
    }
    return parts[0] == "q3" and catalog.source("q3").pk3.is_sky(parts[1]);
}

"""The material a level's sky comes from: what its worldspawn says, else the
sky material most of its faces are drawn with."""
def:priv chosen_material(level: Level, surfaces: list[int], fields: dict[str, str], catalog: AssetCatalog) -> str {
    said = fields.get("_sky", "");
    if said and sky_material(said, catalog) {
        return said;
    }
    counts: dict[int, int] = {};
    for face in level.bsp.faces {
        if face.texture in surfaces {
            counts[face.texture] = counts.get(face.texture, 0) + 1;
        }
    }
    best = surfaces[0];
    for t in surfaces {
        if counts.get(t, 0) > counts.get(best, 0) {
            best = t;
        }
    }
    return material_of(level.bsp.textures[best].name);
}

"""The texture whose two halves are Quake's layers: the one a material names
(in a level a Quake texture goes by its name alone), else the first there is."""
def:priv quake_layers(level: Level, surfaces: list[int], material: str) -> int {
    wanted = "q1:" + material.split("/")[-1].split(":")[-1];
    found = -1;
    for t in surfaces {
        texture = level.bsp.textures[t];
        if not texture.name.startswith("q1:") or not texture.rgba or texture.width != texture.height * 2 {
            continue;
        }
        if texture.name == wanted {
            return t;
        }
        if found < 0 {
            found = t;
        }
    }
    return found;
}

"""What a Quake II sky is: the worldspawn's own fields, else those of the
original its kit was read from, as a map would have them."""
def:priv box_fields(fields: dict[str, str], catalog: AssetCatalog) -> dict[str, str] {
    source = fields.get("_sky_source", "");
    if fields.get("sky", "") or not source {
        return fields;
    }
    try {
        return worldspawn_fields(catalog.source("q2").read("maps/" + source + ".bsp"));
    } except Exception {
        return fields;
    }
}

"""Show a level's sky materials as a sky. Raises when the archives lack what
the sky needs, with the level as it was."""
def raise_sky(level: Level, catalog: AssetCatalog) {
    surfaces = [t for t in range(len(level.bsp.textures)) if sky_material(material_of(level.bsp.textures[t].name), catalog)];
    if not surfaces {
        return;
    }
    fields: dict[str, str] = {};
    for entity in level.bsp.entities + level.source_entities {
        if entity.fields.get("classname", "") == "worldspawn" {
            fields = entity.fields;
            break;
        }
    }
    material = chosen_material(level, surfaces, fields, catalog);
    box: list[Texture] = [];
    game = material.split(":")[0];
    if game == "q1" {
        layers = quake_layers(level, surfaces, material);
        if layers < 0 {
            return;
        }
        level.sky_layer_texture = layers;
    } elif game == "q2" {
        original = box_fields(fields, catalog);
        library = catalog.source("q2");
        name = original.get("sky", "") or "unit1_";
        for suffix in ["rt", "lf", "bk", "ft", "up", "dn"] {
            path = "env/" + name + suffix + ".tga";
            box.append(Texture(name=path, encoded=library.read(path), extension=".tga"));
        }
        # SP_worldspawn CS_SKYROTATE and CS_SKYAXIS, as a Quake II level's.
        level.sky_rotate = atof(original.get("skyrotate", "0") or "0");
        axis = original.get("skyaxis", "").split();
        if len(axis) == 3 {
            level.sky_axis = Vec3(x=atof(axis[0]), y=atof(axis[1]), z=atof(axis[2]));
        }
    } else {
        parts = catalog.source("q3").pk3.sky_parts(material.split(":", 1)[1]);
        box = parts.farbox;
        level.sky_clouds = parts.clouds;
        level.cloud_height = parts.cloud_height;
    }
    # A level begun again reopens the same data.
    level.bsp.sky = box;
    level.sky_textures = surfaces;
}
