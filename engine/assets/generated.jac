"""Generated assets: textures, sounds, models and music made by code
(games/procgen) instead of read from a game's archives.

The setting `qp_generated` turns them on from the next level load. What the
generator makes for a content pack is baked into one archive in a folder of
its own (a `.pak` for Quake and Quake II, a `.pk3` for Quake III, as the
games' readers take nothing loose over an archive), and that folder is laid
over the top of the pack's search path, so every name it holds is read from
it and every name it does not still comes from the game's own data.

Quake keeps its wall textures inside each map, not as files of their own, so
the generator keeps a Quake texture as `miptex/<name>.mip` (the texture as a
map holds it) and a map's textures are swapped for those, by name, as the map
is read."""
import os;
import from .pak { PakArchive }
import from ..formats.bsp { Texture, i32_at }

"""Whether generated assets are being played, set from `qp_generated` as each
level loads."""
obj GeneratedState {
    has on: bool = False;
}

glob _generated: GeneratedState = GeneratedState();

def generated_on -> bool {
    return _generated.on;
}

def set_generated(on: bool) {
    _generated.on = on;
}

"""Where everything generated is kept: QP_GENERATED_DIR, else
~/.quakepassion-generated."""
def generated_root -> str {
    configured = os.getenv("QP_GENERATED_DIR", "");
    if configured {
        return configured.rstrip("/");
    }
    return os.path.expanduser("~") + "/.quakepassion-generated";
}

"""The folder a content pack's generated archive is kept in."""
def generated_folder(pack_id: str) -> str {
    return generated_root() + "/" + pack_id;
}

"""The archive's file name in that folder: last by name, so it is opened
after (and read before) anything else in a search path."""
def generated_archive_name(game: str) -> str {
    return "zzzz-generated." + ("pk3" if game == "q3" else "pak");
}

"""A search path with the pack's generated folder laid over it, when
generated assets are on and the folder is there."""
def with_generated(path: str, pack_id: str) -> str {
    if not _generated.on {
        return path;
    }
    folder = generated_folder(pack_id);
    if not os.path.isdir(folder) {
        return path;
    }
    return path + ";" + folder;
}

"""Whether a folder of a search path is a generated one."""
def is_generated_folder(folder: str) -> bool {
    return folder.startswith(generated_root() + "/");
}

"""Where the generator keeps a Quake texture named `name`."""
def miptex_path(name: str) -> str {
    return "miptex/" + name.lower() + ".mip";
}

"""A map's textures with those the archives hold a generated texture for
(of the same size) swapped in."""
def generated_miptex(textures: list[Texture], paks: list[PakArchive]) -> list[Texture] {
    if not _generated.on {
        return textures;
    }
    made: list[Texture] = [];
    for texture in textures {
        swapped = texture;
        if texture.name and texture.pixels {
            path = miptex_path(texture.name);
            for pak in reversed(paks) {
                if pak.has_file(path) {
                    data = pak.read_file(path);
                    if len(data) >= 40 {
                        width = i32_at(data, 16);
                        height = i32_at(data, 20);
                        offset = i32_at(data, 24);
                        if width == texture.width and height == texture.height and offset >= 40
                            and len(data) >= offset + width * height {
                            swapped = Texture(
                                name=texture.name,
                                width=width,
                                height=height,
                                pixels=data[offset:offset + width * height]
                            );
                        }
                    }
                    break;
                }
            }
        }
        made.append(swapped);
    }
    return made;
}
