"""Game-level sources feed the same runtime world and renderer."""
import os;
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from .passion.generate { generate }
import from .passion.materials { load_materials }

"""Where edited entity lumps are kept: QP_OVERRIDES, else a folder beside the
settings (QP_CONFIG_DIR, else HOME)."""
def override_folder -> str {
    chosen = os.getenv("QP_OVERRIDES", "");
    if chosen {
        return chosen;
    }
    configured = os.getenv("QP_CONFIG_DIR", "");
    return (configured if configured else os.getenv("HOME", ".")) + "/.quakepassion-overrides";
}

"""The file holding a map's edited entities."""
def override_path(game: str, name: str) -> str {
    return override_folder() + "/" + game + "/" + name.replace("/", "_") + ".ent";
}

"""A map's saved entity edits ("" when it has none)."""
def saved_entities(game: str, name: str) -> str {
    path = override_path(game, name);
    if not os.path.isfile(path) {
        return "";
    }
    with open(path, "r") as file {
        return file.read();
    }
}

"""Open a level. Its entities are the map's own unless edits were saved for
it (the studio's overrides) or `entities` supplies them; `entities=""` asks
for the map as shipped."""
def open_level(
    world: World,
    directory: str,
    name: str,
    game: str,
    skill: int = 1,
    subdivisions: float = 4.0,
    entities: str | None = None
) -> Level {
    if game == "passion" {
        cache = os.environ.get(
            "QP_LIGHT_CACHE", os.path.expanduser("~/.cache/quakepassion/lighting")
        );
        return generate(world, name, load_materials(directory), cache);
    }
    lump = saved_entities(game, name) if entities is None else entities;
    return load_level(world, directory, name, game, skill, subdivisions, lump);
}
