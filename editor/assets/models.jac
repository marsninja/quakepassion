"""Models from the games' archives, for looking at: Quake's MDL, Quake II's
MD2 and Quake III's MD3, read by the engine's own parsers."""
import from engine.formats.animated { AnimatedModel, AnimatedSurface }
import from engine.formats.bsp { Texture }
import from engine.math.vec3 { Vec3 }
import from .materials { ArchiveMaterials }

"""A model as the viewer shows it."""
obj ModelLook {
    has game: str = "",
        name: str = "",
        model: AnimatedModel = AnimatedModel(),
        skins: list[Texture] = [],
        frames: int = 0,
        triangles: int = 0,
        vertices: int = 0;

    """What a frame is called (the first surface's name for it)."""
    def frame_name(frame: int) -> str {
        for surface in self.model.surfaces {
            if frame >= 0 and frame < len(surface.frames) and surface.frames[frame].name {
                return surface.frames[frame].name;
            }
        }
        return str(frame);
    }

    """The edges of every triangle at a frame, each once, as pairs of points."""
    def edges(frame: int) -> list[list[Vec3]] {
        found: list[list[Vec3]] = [];
        for surface in self.model.surfaces {
            if len(surface.frames) == 0 {
                continue;
            }
            points = surface.frames[max(0, min(frame, len(surface.frames) - 1))].vertices;
            seen: dict[int, bool] = {};
            count = len(points);
            for t in range(len(surface.indices) // 3) {
                for k in range(3) {
                    a = surface.indices[t * 3 + k];
                    b = surface.indices[t * 3 + (k + 1) % 3];
                    if a < 0 or b < 0 or a >= count or b >= count {
                        continue;
                    }
                    key = min(a, b) * count + max(a, b);
                    if key in seen {
                        continue;
                    }
                    seen[key] = True;
                    found.append([points[a], points[b]]);
                }
            }
        }
        return found;
    }

    """The box round the model at a frame: [low, high]."""
    def bounds(frame: int) -> list[Vec3] {
        far = 1000000.0;
        low = Vec3(x=far, y=far, z=far);
        high = Vec3(x=-far, y=-far, z=-far);
        for surface in self.model.surfaces {
            if len(surface.frames) == 0 {
                continue;
            }
            for point in surface.frames[max(0, min(frame, len(surface.frames) - 1))].vertices {
                low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
                high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
            }
        }
        if low.x > high.x {
            return [Vec3(), Vec3()];
        }
        return [low, high];
    }
}

"""Whether a file is a model this reads."""
def is_model(name: str) -> bool {
    low = name.lower();
    return low.endswith(".mdl") or low.endswith(".md2") or low.endswith(".md3");
}

"""A model from a game's archives, or none when it does not read."""
def load_model(shelf: ArchiveMaterials, game: str, name: str) -> ModelLook | None {
    try {
        asset = shelf.reader().catalog.source(game).model(name);
    } except Exception {
        return None;
    }
    shown = ModelLook(game=game, name=name, model=asset.model, skins=asset.skins);
    for surface in asset.model.surfaces {
        shown.frames = max(shown.frames, len(surface.frames));
        shown.triangles += len(surface.indices) // 3;
        if len(surface.frames) > 0 {
            shown.vertices += len(surface.frames[0].vertices);
        }
    }
    if shown.frames == 0 {
        return None;
    }
    return shown;
}
