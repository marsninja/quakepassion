"""Read every original level's own palette and write it as the kits the
prefabs of each are raised in (`games/passion/level_kits.jac`).

For each original (`games/passion/originals.jac`) the world's faces are
summed by texture over floors (facing up), ceilings (facing down) and walls,
by area; its doors' faces give its door, its lifts' its step; its liquid,
sky and light textures are what it draws them with. Only the textures'
names are written.

    jac build scripts/passion_kits.jac --native -o .jac/qp-kits
    DYLD_LIBRARY_PATH=vendor .jac/qp-kits

QP_KITS names a few originals (`game:map`) to read instead of all;
QP_KITS_OUT another file to write."""
import os;
import time;
import from engine.math.vec3 { Vec3 }
import from engine.world.world { World }
import from engine.world.level { load_level }
import from engine.assets.content { game_directory }
import from engine.formats.bsp { Bsp, Face }
import from games.passion.originals { all_originals }

"""A polygon's area."""
def kit_face_area(face: Face) -> float {
    points = face.vertices;
    if len(points) < 3 {
        return 0.0;
    }
    total = Vec3();
    first = points[0];
    for index in range(1, len(points) - 1) {
        total = total.add(points[index].sub(first).cross(points[index + 1].sub(first)));
    }
    return total.length() * 0.5;
}

"""A level texture's name as Passion's materials are named."""
def kit_material(game: str, map: str, name: str) -> str {
    if game == "q1" {
        return "q1:" + map + "/" + name;
    }
    return game + ":" + name;
}

"""Whether a texture is never a surface a kit draws (sky, liquid, clip,
trigger, caulk and the like)."""
def kit_skipped(name: str) -> bool {
    lowered = name.lower();
    for word in ["sky", "skies/", "sfx/", "fog", "beam", "dust_", "clip", "trigger", "caulk", "nodraw", "hint", "skip", "origin", "common/", "black", "nolight"] {
        if word in lowered {
            return True;
        }
    }
    return lowered.startswith("*") or "water" in lowered or "slime" in lowered or "lava" in lowered;
}

"""The names of `weights` by weight, heaviest first."""
def kit_ranked(weights: dict[str, float]) -> list[str] {
    names: list[str] = [name for name in weights.keys()];
    for index in range(len(names)) {
        for later in range(index + 1, len(names)) {
            if weights[names[later]] > weights[names[index]] {
                held = names[index];
                names[index] = names[later];
                names[later] = held;
            }
        }
    }
    return names;
}

"""The faces of a brush model of a level."""
def kit_model_faces(bsp: Bsp, model: int) -> list[Face] {
    record = bsp.models[model];
    found: list[Face] = [];
    for index in range(max(0, record.first_face), min(len(bsp.faces), record.first_face + record.face_count)) {
        found.append(bsp.faces[index]);
    }
    return found;
}

"""The `index`th of `names` as a material, else `fallback`."""
def kit_pick(game: str, map: str, names: list[str], index: int, fallback: str) -> str {
    return kit_material(game, map, names[index]) if index < len(names) else fallback;
}

"""One original's kit, as a Jac list of its strings."""
def kit_line(spec: str) -> str {
    parts = spec.split(":");
    game = parts[0];
    map = parts[1];
    world = World();
    level = load_level(world, game_directory(game), map, game, 1);
    bsp = level.bsp;
    floors: dict[str, float] = {};
    walls: dict[str, float] = {};
    ceilings: dict[str, float] = {};
    lights: dict[str, float] = {};
    liquids: dict[str, float] = {};
    skies: dict[str, float] = {};
    for face in kit_model_faces(bsp, 0) {
        if face.texture < 0 or face.texture >= len(bsp.textures) {
            continue;
        }
        name = bsp.textures[face.texture].name;
        lowered = name.lower();
        area = kit_face_area(face);
        if "sky" in lowered {
            skies[name] = skies.get(name, 0.0) + area;
            continue;
        }
        wet = bsp.textures[face.texture].contents & 56;
        if wet or lowered.startswith("*") or "water" in lowered or "wter" in lowered or "slime" in lowered or "lava" in lowered or "liquid" in lowered {
            liquids[name] = liquids.get(name, 0.0) + area;
            continue;
        }
        if kit_skipped(name) {
            continue;
        }
        if "light" in lowered or "lite" in lowered {
            lights[name] = lights.get(name, 0.0) + area;
            continue;
        }
        if face.normal.z > 0.7 {
            floors[name] = floors.get(name, 0.0) + area;
        } elif face.normal.z < -0.7 {
            ceilings[name] = ceilings.get(name, 0.0) + area;
        } else {
            walls[name] = walls.get(name, 0.0) + area;
        }
    }
    doors: dict[str, float] = {};
    steps: dict[str, float] = {};
    for entity in bsp.entities {
        kind = entity.fields.get("classname", "");
        model = entity.fields.get("model", "");
        if not model.startswith("*") or not model[1:].isdigit() or int(model[1:]) >= len(bsp.models) {
            continue;
        }
        if kind not in ["func_door", "func_plat", "func_train"] {
            continue;
        }
        for face in kit_model_faces(bsp, int(model[1:])) {
            if face.texture < 0 or face.texture >= len(bsp.textures) {
                continue;
            }
            name = bsp.textures[face.texture].name;
            if kit_skipped(name) {
                continue;
            }
            area = kit_face_area(face);
            if kind == "func_door" {
                doors[name] = doors.get(name, 0.0) + area;
            } else {
                steps[name] = steps.get(name, 0.0) + area;
            }
        }
    }
    wall_names = kit_ranked(walls);
    floor_names = kit_ranked(floors);
    ceiling_names = kit_ranked(ceilings);
    light_names = kit_ranked(lights);
    door_names = kit_ranked(doors);
    step_names = kit_ranked(steps);
    liquid_names = kit_ranked(liquids);
    sky_names = kit_ranked(skies);
    wall = kit_pick(game, map, wall_names, 0, "");
    floor = kit_pick(game, map, floor_names, 0, wall);
    ceiling = kit_pick(game, map, ceiling_names, 0, wall);
    values = [
        game,
        map,
        floor,
        wall,
        ceiling,
        kit_pick(game, map, wall_names, 1, wall),
        kit_pick(game, map, wall_names, 2, wall),
        kit_pick(game, map, wall_names, 3, wall),
        kit_pick(game, map, wall_names, 4, wall),
        kit_pick(game, map, light_names, 0, wall),
        kit_pick(game, map, door_names, 0, wall),
        kit_pick(game, map, step_names, 0, floor),
        kit_pick(game, map, sky_names, 0, ""),
        kit_pick(game, map, liquid_names, 0, ""),
        "|".join([kit_material(game, map, name) for name in wall_names[1:4]]),
        "|".join([kit_material(game, map, name) for name in floor_names[1:3]]),
        "|".join([kit_material(game, map, name) for name in ceiling_names[1:3]])
    ];
    return "         [" + ", ".join(["\"" + value.replace("\\", "/").replace("\"", "") + "\"" for value in values]) + "]";
}

with entry {
    wanted = (os.getenv("QP_KITS") or "").split();
    specs = wanted if wanted else all_originals();
    out = os.getenv("QP_KITS_OUT") or "games/passion/level_kits.jac";
    lines: list[str] = [];
    for spec in specs {
        began = time.time();
        try {
            lines.append(kit_line(spec));
        } except Exception as error {
            print("kit " + spec + " failed: " + str(error));
            continue;
        }
        print("kit " + spec + " in " + str(round(time.time() - began, 1)) + " s");
    }
    head = [
        "\"\"\"The palettes of the original levels, read off them by",
        "`scripts/passion_kits.jac`: for each, its game and map, then its floor,",
        "wall, ceiling, trim, support, lower, accent, light, door, step, sky and",
        "liquid textures, and its other walls, floors and ceilings (each a list",
        "joined by |). Only texture names.\"\"\"",
        "glob LEVEL_KITS: list[list[str]] = ["
    ];
    with open(out, "w") as handle {
        handle.write("\n".join(head) + "\n" + ",\n".join(lines) + "\n     ];\n");
    }
    print("wrote " + str(len(lines)) + " kits to " + out);
}
