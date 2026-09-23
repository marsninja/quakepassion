"""Game-level sources feed the same runtime world and renderer."""
import os;
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from .passion.generate { generate }
import from .passion.materials { load_materials }

def open_level(
    world: World, directory: str, name: str, game: str, skill: int = 1
) -> Level {
    if game == "passion" {
        cache = os.environ.get(
            "QP_LIGHT_CACHE", os.path.expanduser("~/.cache/quakepassion/lighting")
        );
        return generate(world, name, load_materials(directory), cache);
    }
    return load_level(world, directory, name, game, skill);
}
