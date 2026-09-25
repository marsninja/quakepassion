"""Shared map records and validated binary readers for all Quake adapters."""
import math;
import struct;
import from ..math.vec3 { Vec3 }
import from ..math.orientation { Basis }

obj Texture {
    has name: str = "missing",
        width: int = 16,
        height: int = 16,
        pixels: bytes = b"",
        rgba: bytes = b"",
        encoded: bytes = b"",
        extension: str = "",
        contents: int = 0,
        flags: int = 0,
        alpha_test: int = 0,
        additive: bool = False,
        two_sided: bool = False;
}

obj TexInfo {
    has s: Vec3,
        t: Vec3,
        soff: float,
        toff: float,
        texture: int,
        flags: int;
}

obj Face {
    has emission: bool = False,
        moving_light: bool = False;
    has motion: Vec3 = Vec3(),
        turn: Basis | None = None,
        pivot: Vec3 = Vec3(),
        vertices: list[Vec3] = [],
        uv: list[float] = [],
        light_uv: list[float] = [],
        indices: list[int] = [],
        colors: list[int] = [],
        planar: bool = True,
        patch: bool = False,
        alpha_test: int = 0,
        additive: bool = False,
        two_sided: bool = False,
        hidden: bool = False,
        texture: int = 0,
        light_offset: int = -1,
        light_width: int = 0,
        light_height: int = 0,
        light_s: int = 0,
        light_t: int = 0,
        styles: list[int] = [],
        normal: Vec3 = Vec3(),
        plane_dist: float = 0.0,
        warp: bool = False,
        flowing: bool = False,
        opacity: float = 1.0,
        frame: int = 0,
        fog: int = -1,
        fog_only: bool = False;
}

obj Plane {
    has normal: Vec3,
        distance: float;
}

obj Branch {
    has plane: int,
        front: int,
        back: int;
}

obj Leaf {
    has contents: int,
        vis_offset: int,
        mins: Vec3,
        maxs: Vec3,
        cluster: int = -1,
        faces: list[int] = [],
        brushes: list[int] = [],
        ambient: list[int] = [];
}

obj Model {
    has head: int,
        first_face: int,
        face_count: int,
        vis_leaf_count: int = 0,
        player_hull: int = -1,
        brushes: list[int] = [],
        mins: Vec3 = Vec3(),
        maxs: Vec3 = Vec3();
}

obj MapEntity {
    has fields: dict[str, str] = {};
}

obj Brush {
    has planes: list[int] = [],
        contents: int = 0;
}

"""A Q3 fog volume (dfog_t): an axial brush, and the plane of its visible side
when it has one, with the normal pointing into the fog (tr_bsp.c R_LoadFogs)."""
obj FogVolume {
    has shader: str = "",
        mins: Vec3 = Vec3(),
        maxs: Vec3 = Vec3(),
        has_surface: bool = False,
        inward: Vec3 = Vec3(),
        offset: float = 0.0,
        color: Vec3 = Vec3(),
        depth: float = 1.0;
}

obj Bsp {
    has game: str = "q1",
        light_channels: int = 1,
        clusters: int = 0,
        cluster_bytes: int = 0,
        sky: list[Texture] = [],
        textures: list[Texture] = [],
        texture_next: dict[int, int] = {},
        planes: list[Plane] = [],
        branches: list[Branch] = [],
        clipnodes: list[Branch] = [],
        brushes: list[Brush] = [],
        leaves: list[Leaf] = [],
        faces: list[Face] = [],
        models: list[Model] = [],
        entities: list[MapEntity] = [],
        lighting: bytes = b"",
        visibility: bytes = b"",
        fogs: list[FogVolume] = [];
}

def require_range(data: bytes, offset: int, size: int) {
    if offset < 0 or size < 0 or offset > len(data) or size > len(data) - offset {
        raise ValueError("BSP byte range outside its lump");
    }
}

def i32_at(data: bytes, p: int) -> int {
    require_range(data, p, 4);
    return int(struct.unpack("<i", data[p:p + 4])[0]);
}

def u16_at(data: bytes, p: int) -> int {
    require_range(data, p, 2);
    return int(struct.unpack("<H", data[p:p + 2])[0]);
}

def s16_at(data: bytes, p: int) -> int {
    require_range(data, p, 2);
    return int(struct.unpack("<h", data[p:p + 2])[0]);
}

def f32_at(data: bytes, p: int) -> float {
    require_range(data, p, 4);
    v = float(struct.unpack("<f", data[p:p + 4])[0]);
    if not math.isfinite(v) {
        raise ValueError("Non-finite BSP coordinate");
    }
    return v;
}

def vec_at(data: bytes, p: int) -> Vec3 {
    return Vec3(x=f32_at(data, p), y=f32_at(data, p + 4), z=f32_at(data, p + 8));
}

def bounds_at(data: bytes, p: int) -> Vec3 {
    return Vec3(
        x=float(s16_at(data, p)),
        y=float(s16_at(data, p + 2)),
        z=float(s16_at(data, p + 4))
    );
}

def records(data: bytes, size: int) -> int {
    if len(data) % size != 0 {
        raise ValueError("Partial BSP record");
    }
    return len(data) // size;
}

def check_index(index: int, count: int) {
    if index < 0 or index >= count {
        raise ValueError("Invalid BSP table index");
    }
}

def parse_entities(text: str) -> list[MapEntity] {
    result: list[MapEntity] = [];
    current = MapEntity();
    opened = False;
    key = "";
    have_key = False;
    i = 0;
    while i < len(text) {
        c = text[i];
        if c == "\x00" {
            break;
        }
        if c == " " or c == "\n" or c == "\r" or c == "\t" {
            i += 1;
            continue;
        }
        if c == "/" and i + 1 < len(text) and text[i + 1] == "/" {
            while i < len(text) and text[i] != "\n" {
                i += 1;
            }
            continue;
        }
        if c == "{" {
            if opened {
                raise ValueError("Nested BSP entity");
            }
            current = MapEntity();
            opened = True;
            i += 1;
            continue;
        }
        if c == "}" {
            if not opened or have_key {
                raise ValueError("Incomplete BSP entity");
            }
            result.append(current);
            opened = False;
            i += 1;
            continue;
        }
        if c != "\"" or not opened {
            raise ValueError("Expected quoted BSP entity field");
        }
        i += 1;
        value = "";
        while i < len(text) and text[i] != "\"" {
            value += text[i];
            i += 1;
        }
        if i >= len(text) {
            raise ValueError("Unterminated BSP entity string");
        }
        i += 1;
        if have_key {
            # ED_NewString (Q1/Q2) and G_NewString (Q3) turn a message's
            # "\n" into a line break at spawn.
            if key == "message" {
                value = value.replace("\\n", "\n");
            }
            current.fields[key] = value;
            have_key = False;
        } else {
            key = value;
            have_key = True;
        }
    }
    if opened {
        raise ValueError("Unterminated BSP entity");
    }
    return result;
}

"""Decode one BSP leaf's potentially-visible set; bit 0 denotes leaf 1."""
def decode_pvs(data: bytes, offset: int, leaf_count: int) -> list[int] {
    result: list[int] = [];
    if offset == -1 {
        for i in range(1, leaf_count) {
            result.append(i);
        }
        return result;
    }
    p = offset;
    leaf = 1;
    while leaf < leaf_count {
        require_range(data, p, 1);
        bits = int(data[p]);
        p += 1;
        if bits == 0 {
            require_range(data, p, 1);
            run = int(data[p]);
            p += 1;
            if run == 0 {
                raise ValueError("Zero-length BSP visibility run");
            }
            leaf += run * 8;
        } else {
            for bit in range(8) {
                if leaf < leaf_count and bits & (1 << bit) != 0 {
                    result.append(leaf);
                }
                leaf += 1;
            }
        }
    }
    return result;
}
