"""Shared vertex animation records. Game formats adapt to this render boundary."""
import math;
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

"""A Q3 shader wave (tr_shader.c ParseWaveForm): func(phase + time * freq)
scaled by amplitude around base."""
obj ShaderWave {
    has func: str = "sin",
        base: float = 0.0,
        amplitude: float = 0.0,
        phase: float = 0.0,
        frequency: float = 0.0;

    def at(seconds: float) -> float {
        x = self.phase + seconds * self.frequency;
        f = x - float(int(x)) if x >= 0.0 else x - float(int(x) - 1);
        value = 0.0;
        if self.func == "sin" {
            value = math.sin(f * 2.0 * math.pi);
        } elif self.func == "triangle" {
            value = 4.0 * f if f < 0.25 else (2.0 - 4.0 * f if f < 0.75 else 4.0 * f - 4.0);
        } elif self.func == "square" {
            value = 1.0 if f < 0.5 else -1.0;
        } elif self.func == "sawtooth" {
            value = f;
        } elif self.func == "inversesawtooth" {
            value = 1.0 - f;
        } elif self.func == "noise" {
            value = math.sin(x * 12.9898) * 0.5 + math.sin(x * 78.233) * 0.5;
        }
        return self.base + value * self.amplitude;
    }

    """The wave with its phase shifted, as deforms spread it over position."""
    def shifted(seconds: float, offset: float) -> float {
        moved = ShaderWave(func=self.func, base=self.base, amplitude=self.amplitude, phase=self.phase + offset, frequency=self.frequency);
        return moved.at(seconds);
    }
}

"""One tcMod: scroll (a, b), scale (a, b), rotate (a degrees/s), turb and
stretch (their wave)."""
obj TexMod {
    has kind: str,
        a: float = 0.0,
        b: float = 0.0,
        wave: ShaderWave = ShaderWave();
}

"""A surface-wide deformVertexes: wave and move sway vertices along the normal
or a vector by a wave spread over position, bulge ripples along the texture's
s, and autosprite/autosprite2 turn quads to face the viewer."""
obj Deform {
    has kind: str,
        spread: float = 0.0,
        wave: ShaderWave = ShaderWave(),
        vector: Vec3 = Vec3(),
        width: float = 0.0,
        height: float = 0.0,
        speed: float = 0.0;
}

obj ModelStage {
    has texture: Texture = Texture(),
        frames: list[Texture] = [],
        frequency: float = 0.0,
        environment: bool = False,
        scroll_u: float = 0.0,
        scroll_v: float = 0.0,
        blend: str = "opaque",
        lightmap: bool = False,
        white: bool = False,
        blend_source: str = "",
        blend_destination: str = "",
        rgb: str = "identity",
        rgb_wave: ShaderWave = ShaderWave(),
        rgb_const: list[float] = [1.0, 1.0, 1.0],
        alpha: str = "identity",
        alpha_wave: ShaderWave = ShaderWave(),
        alpha_const: float = 1.0,
        mods: list[TexMod] = [],
        alpha_test: int = 0,
        depth_write: bool = False;
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
