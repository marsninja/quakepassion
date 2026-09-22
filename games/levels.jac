"""Game-level sources feed the same runtime world and renderer."""
import from engine.world.level { Level, load_level }
import from engine.world.world { World }
import from .passion.generate { generate }
import from .passion.materials { load_materials }

def open_level(world: World, directory: str, name: str, game: str) -> Level {
    if game == "passion" { return generate(world, name, load_materials(directory)); }
    return load_level(world, directory, name, game);
}
