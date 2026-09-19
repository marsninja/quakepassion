"""Quake 1 BSP29 decoding. Disk indices remain explicit until graph assembly."""
import math;
import struct;
import from ...math.vec3 { Vec3 }

obj Texture {
    has name: str = "missing",
        width: int = 16,
        height: int = 16,
        pixels: bytes = b"",
        encoded: bytes = b"",
        extension: str = "",
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
    has vertices: list[Vec3] = [],
        uv: list[float] = [],
        light_uv: list[float] = [],
        indices: list[int] = [],
        colors: list[int] = [],
        planar: bool = True,
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
        plane_dist: float = 0.0;
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
        faces: list[int] = [];
}

obj Model {
    has head: int,
        first_face: int,
        face_count: int,
        vis_leaf_count: int = 0;
}

obj MapEntity {
    has fields: dict[str, str] = {};
}

obj Bsp {
    has game: str = "q1",
        light_channels: int = 1,
        clusters: int = 0,
        cluster_bytes: int = 0,
        sky: list[Texture] = [],
        textures: list[Texture] = [],
        planes: list[Plane] = [],
        branches: list[Branch] = [],
        leaves: list[Leaf] = [],
        faces: list[Face] = [],
        models: list[Model] = [],
        entities: list[MapEntity] = [],
        lighting: bytes = b"",
        visibility: bytes = b"";
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
            if text[i] == "\\" and i + 1 < len(text) and text[i + 1] == "\"" {
                i += 1;
            }
            value += text[i];
            i += 1;
        }
        if i >= len(text) {
            raise ValueError("Unterminated BSP entity string");
        }
        i += 1;
        if have_key {
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

def parse_textures(data: bytes) -> list[Texture] {
    count = i32_at(data, 0);
    if count < 0 or count > 4096 {
        raise ValueError("Invalid BSP texture count");
    }
    require_range(data, 4, count * 4);
    result: list[Texture] = [];
    for i in range(count) {
        start = i32_at(data, 4 + i * 4);
        if start == -1 {
            result.append(Texture());
            continue;
        }
        require_range(data, start, 40);
        end = start;
        while end < start + 16 and data[end] != 0 {
            end += 1;
        }
        width = i32_at(data, start + 16);
        height = i32_at(data, start + 20);
        if width <= 0 or height <= 0 or width > 4096 or height > 4096 {
            raise ValueError("Invalid BSP texture dimensions");
        }
        mip = i32_at(data, start + 24);
        if mip < 40 {
            raise ValueError("Invalid BSP texture pixel offset");
        }
        require_range(data, start + mip, width * height);
        result.append(
            Texture(
                name=data[start:end].decode("utf-8"),
                width=width,
                height=height,
                pixels=data[start + mip:start + mip + width * height]
            )
        );
    }
    return result;
}

def parse_bsp(data: bytes) -> Bsp {
    require_range(data, 0, 124);
    if i32_at(data, 0) != 29 {
        raise ValueError("Expected Quake 1 BSP version 29");
    }
    lumps: list[bytes] = [];
    for i in range(15) {
        offset = i32_at(data, 4 + i * 8);
        size = i32_at(data, 8 + i * 8);
        require_range(data, offset, size);
        lumps.append(data[offset:offset + size]);
    }
    bsp = Bsp(lighting=lumps[8], visibility=lumps[4]);
    bsp.entities = parse_entities(lumps[0].decode("utf-8"));
    bsp.textures = parse_textures(lumps[2]);
    for i in range(records(lumps[1], 20)) {
        bsp.planes.append(
            Plane(
                normal=vec_at(lumps[1], i * 20), distance=f32_at(lumps[1], i * 20 + 12)
            )
        );
    }
    vertices: list[Vec3] = [];
    for i in range(records(lumps[3], 12)) {
        vertices.append(vec_at(lumps[3], i * 12));
    }
    texinfo: list[TexInfo] = [];
    for i in range(records(lumps[6], 40)) {
        p = i * 40;
        texture = i32_at(lumps[6], p + 32);
        check_index(texture, len(bsp.textures));
        texinfo.append(
            TexInfo(
                s=vec_at(lumps[6], p),
                t=vec_at(lumps[6], p + 16),
                soff=f32_at(lumps[6], p + 12),
                toff=f32_at(lumps[6], p + 28),
                texture=texture,
                flags=i32_at(lumps[6], p + 36)
            )
        );
    }
    edge_count = records(lumps[12], 4);
    surf_count = records(lumps[13], 4);
    for i in range(records(lumps[7], 20)) {
        p = i * 20;
        plane = u16_at(lumps[7], p);
        check_index(plane, len(bsp.planes));
        side = u16_at(lumps[7], p + 2);
        first = i32_at(lumps[7], p + 4);
        count = u16_at(lumps[7], p + 8);
        ti = u16_at(lumps[7], p + 10);
        check_index(ti, len(texinfo));
        if count < 3 or first < 0 or first + count > surf_count {
            raise ValueError("Invalid BSP face edge range");
        }
        info = texinfo[ti];
        face_texture = bsp.textures[info.texture];
        face = Face(
            texture=info.texture,
            light_offset=i32_at(lumps[7], p + 16),
            normal=bsp.planes[plane].normal,
            plane_dist=bsp.planes[plane].distance
        );
        if side != 0 {
            face.normal = face.normal.scale(-1.0);
            face.plane_dist = -face.plane_dist;
        }
        for j in range(4) {
            style = int(lumps[7][p + 12 + j]);
            if style != 255 {
                face.styles.append(style);
            }
        }
        min_s = 1.0e30;
        max_s = -1.0e30;
        min_t = 1.0e30;
        max_t = -1.0e30;
        for j in range(count) {
            se = i32_at(lumps[13], (first + j) * 4);
            ei = abs(se);
            check_index(ei, edge_count);
            ep = ei * 4;
            if se < 0 {
                ep += 2;
            }
            vi = u16_at(lumps[12], ep);
            check_index(vi, len(vertices));
            v = vertices[vi];
            face.vertices.append(v);
            s = v.dot(info.s) + info.soff;
            t = v.dot(info.t) + info.toff;
            face.uv.append(s / float(face_texture.width));
            face.uv.append(t / float(face_texture.height));
            min_s = min(min_s, s);
            max_s = max(max_s, s);
            min_t = min(min_t, t);
            max_t = max(max_t, t);
        }
        face.light_s = int(math.floor(min_s / 16.0));
        face.light_t = int(math.floor(min_t / 16.0));
        face.light_width = int(math.ceil(max_s / 16.0)) - face.light_s + 1;
        face.light_height = int(math.ceil(max_t / 16.0)) - face.light_t + 1;
        if face.light_offset >= 0 {
            require_range(
                bsp.lighting,
                face.light_offset,
                face.light_width * face.light_height * len(face.styles)
            );
        }
        for j in range(count) {
            face.light_uv.append(
                face.uv[j * 2] * float(face_texture.width) / 16.0 - float(face.light_s)
            );
            face.light_uv.append(
                face.uv[j * 2 + 1] * float(face_texture.height) / 16.0
                    - float(face.light_t)
            );
        }
        bsp.faces.append(face);
    }
    mark_count = records(lumps[11], 2);
    for i in range(records(lumps[10], 28)) {
        p = i * 28;
        leaf = Leaf(
            contents=i32_at(lumps[10], p),
            vis_offset=i32_at(lumps[10], p + 4),
            mins=bounds_at(lumps[10], p + 8),
            maxs=bounds_at(lumps[10], p + 14)
        );
        first = u16_at(lumps[10], p + 20);
        count = u16_at(lumps[10], p + 22);
        if first + count > mark_count {
            raise ValueError("Invalid BSP leaf face range");
        }
        for j in range(count) {
            fi = u16_at(lumps[11], (first + j) * 2);
            check_index(fi, len(bsp.faces));
            leaf.faces.append(fi);
        }
        if leaf.vis_offset < -1
            or leaf.vis_offset >= len(bsp.visibility)
            and leaf.vis_offset != -1 {
            raise ValueError("Invalid BSP visibility offset");
        }
        bsp.leaves.append(leaf);
    }
    for i in range(records(lumps[5], 24)) {
        p = i * 24;
        plane = i32_at(lumps[5], p);
        check_index(plane, len(bsp.planes));
        bsp.branches.append(
            Branch(
                plane=plane, front=s16_at(lumps[5], p + 4), back=s16_at(lumps[5], p + 6)
            )
        );
    }
    for b in bsp.branches {
        for child in [b.front, b.back] {
            if child < 0 {
                check_index(-child - 1, len(bsp.leaves));
            } else {
                check_index(child, len(bsp.branches));
            }
        }
    }
    for i in range(records(lumps[14], 64)) {
        p = i * 64;
        head = i32_at(lumps[14], p + 36);
        check_index(head, len(bsp.branches));
        first = i32_at(lumps[14], p + 56);
        count = i32_at(lumps[14], p + 60);
        if first < 0 or count < 0 or first + count > len(bsp.faces) {
            raise ValueError("Invalid BSP model faces");
        }
        vis_count = i32_at(lumps[14], p + 52);
        if vis_count < 0 or vis_count >= len(bsp.leaves) {
            raise ValueError("Invalid BSP model visibility leaf count");
        }
        bsp.models.append(
            Model(
                head=head, first_face=first, face_count=count, vis_leaf_count=vis_count
            )
        );
    }
    if not bsp.models or not bsp.leaves {
        raise ValueError("BSP has no world model");
    }
    return bsp;
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
