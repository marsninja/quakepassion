"""Shared vertex animation records. Game formats adapt to this render boundary."""
import from ..math.vec3 { Vec3 }
import from .bsp { Texture, require_range }

obj AnimationGroup {
    has first: int,
        count: int,
        intervals: list[float] = [];
}

obj ModelTag {
    has name: str,
        origin: Vec3,
        axes: list[Vec3];
}

obj TagFrame {
    has tags: list[ModelTag] = [];
}

obj AnimationFrame {
    has name: str = "",
        vertices: list[Vec3] = [],
        normals: list[Vec3] = [];
}

obj ModelStage {
    has texture: Texture = Texture(),
        frames: list[Texture] = [],
        frequency: float = 0.0,
        environment: bool = False,
        scroll_u: float = 0.0,
        scroll_v: float = 0.0,
        blend: str = "opaque";
}

def stage_frame(seconds: float, frequency: float, count: int) -> int {
    return int(max(0.0, seconds) * frequency) % count if count > 0 else 0;
}

obj AnimatedSurface {
    has name: str = "",
        frames: list[AnimationFrame] = [],
        indices: list[int] = [],
        uv: list[float] = [],
        skins: list[str] = [],
        embedded_skins: list[Texture] = [],
        frame_groups: list[AnimationGroup] = [],
        skin_groups: list[AnimationGroup] = [],
        stages: list[ModelStage] = [];
}

obj AnimatedModel {
    has surfaces: list[AnimatedSurface] = [],
        tags: list[TagFrame] = [],
        flags: int = 0;
}

def model_name(data: bytes, offset: int, size: int) -> str {
    require_range(data, offset, size);
    end = offset;
    while end < offset + size and data[end] != 0 {
        end += 1;
    }
    return data[offset:end].decode("utf-8");
}

def model_count(value: int, maximum: int, label: str, minimum: int = 1) -> int {
    if value < minimum or value > maximum {
        raise ValueError("Invalid model " + label);
    }
    return value;
}

"""Interpolate indexed positions; UVs stay per triangle corner for texture seams."""
def pose(
    surface: AnimatedSurface, first: int, second: int, blend: float
) -> list[Vec3] {
    if first < 0
        or second < 0
        or first >= len(surface.frames)
        or second >= len(surface.frames) {
        raise ValueError("Animation frame out of range");
    }
    a = surface.frames[first].vertices;
    b = surface.frames[second].vertices;
    if len(a) != len(b) {
        raise ValueError("Animation vertex count changed");
    }
    fraction = max(0.0, min(1.0, blend));
    return [
        a[i].scale(1.0 - fraction).add(b[i].scale(fraction)) for i in range(len(a))
    ];
}
