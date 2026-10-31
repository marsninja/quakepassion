"""Game-level sources feed the same runtime world and renderer."""
import os;
import from engine.world.level { Level, load_level, prepare_level }
import from engine.world.world { World }
import from engine.world.signals { HasSignal }
import from engine.formats.bsp { Bsp }
import from .passion.generate { generate, Forge }
import from .passion.essence { essence_path }
import from .passion.sky { raise_sky }
import from engine.assets.catalog { AssetCatalog }
import from engine.level.graph { read_graph }
import from engine.level.guide { guide_level }

"""Where edited entity lumps are kept: QP_OVERRIDES, else a folder beside the
settings (QP_CONFIG_DIR, else HOME)."""
def override_folder -> str {
    chosen = os.getenv("QP_OVERRIDES", "");
    if chosen {
        return chosen;
    }
    configured = os.getenv("QP_CONFIG_DIR", "");
    return (configured if configured else os.path.expanduser("~")) + "/.quakepassion-overrides";
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

"""A level from data already built: a scene the studio compiled."""
def open_built(world: World, name: str, built: Bsp, skill: int = 1) -> Level {
    level = Level(active=True, name=name, skill=skill, bsp=built);
    prepare_level(world, level);
    world +>:HasSignal:+> level.completion;
    return level;
}

"""A made level's sky, read through the archives its forge has open, else ones
opened for it. A level whose archives lack its sky is drawn without one."""
def made_sky(level: Level, directory: str, forged: Forge | None) -> Level {
    materials = forged.materials if forged is not None else None;
    held = materials.archives() if materials is not None else None;
    catalog = held if held is not None else AssetCatalog(game="passion", directory=directory);
    try {
        raise_sky(level, catalog);
    } except Exception as error {
        print("No sky for", level.name + ":", str(error));
    }
    if held is None {
        catalog.close();
    }
    return level;
}

"""Open a level. Its entities are the map's own unless edits were saved for
it (the studio's overrides) or `entities` supplies them; `entities=""` asks
for the map as shipped. `built` is the level's data when it was made rather
than loaded."""
def open_level(
    world: World,
    directory: str,
    name: str,
    game: str,
    skill: int = 1,
    subdivisions: float = 4.0,
    entities: str | None = None,
    built: Bsp | None = None,
    forged: Forge | None = None
) -> Level {
    if built is not None {
        guide_level(world, None);
        level = open_built(world, name, built, skill);
        return made_sky(level, directory, None) if built.game == "passion" else level;
    }
    if game == "passion" {
        return made_sky(generate(world, name, directory, forged), directory, forged);
    }
    lump = saved_entities(game, name) if entities is None else entities;
    level = load_level(world, directory, name, game, skill, subdivisions, lump);
    # The level's graph, which the breadcrumb trail and the player bot plan
    # by: its essence, as Passion's corpus keeps it (reading one here would
    # take seconds).
    guide_level(world, read_graph(essence_path(game + ":" + name)));
    return level;
}
