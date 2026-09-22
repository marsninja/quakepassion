"""MD2 vertex animation and paletted PCX skins."""
import from ..animated {
    AnimatedModel,
    AnimatedSurface,
    AnimationFrame,
    model_name,
    model_count
}
import from ..bsp { Texture, require_range, i32_at, u16_at, s16_at, vec_at }
import from ...math.vec3 { Vec3 }


def parse_md2(data: bytes) -> AnimatedModel {
    require_range(data, 0, 68);
    if data[:4] != b"IDP2" or i32_at(data, 4) != 8 {
        raise ValueError("Expected MD2 version 8");
    }
    width = model_count(i32_at(data, 8), 4096, "skin width");
    height = model_count(i32_at(data, 12), 4096, "skin height");
    stride = i32_at(data, 16);
    skins = model_count(i32_at(data, 20), 32, "skins", 0);
    vertices = model_count(i32_at(data, 24), 2048, "vertices");
    coords = model_count(i32_at(data, 28), 8192, "texture coordinates");
    triangles = model_count(i32_at(data, 32), 4096, "triangles");
    frames = model_count(i32_at(data, 40), 512, "frames");
    end = i32_at(data, 64);
    require_range(data, 0, end);
    if end < 68 or stride < 40 + vertices * 4 {
        raise ValueError("Invalid MD2 frame extent");
    }
    body = data[:end];
    skin_offset = i32_at(data, 44);
    uv_offset = i32_at(data, 48);
    tri_offset = i32_at(data, 52);
    frame_offset = i32_at(data, 56);
    for offset in [skin_offset, uv_offset, tri_offset, frame_offset] {
        if offset < 68 {
            raise ValueError("MD2 data overlaps header");
        }
    }
    require_range(body, skin_offset, skins * 64);
    require_range(body, uv_offset, coords * 4);
    require_range(body, tri_offset, triangles * 12);
    require_range(body, frame_offset, frames * stride);
    surface = AnimatedSurface(name="md2");
    for i in range(skins) {
        surface.skins.append(model_name(body, skin_offset + i * 64, 64));
    }
    for i in range(triangles) {
        p = tri_offset + i * 12;
        for corner in range(3) {
            vertex = u16_at(body, p + corner * 2);
            uv = u16_at(body, p + 6 + corner * 2);
            if vertex >= vertices {
                raise ValueError("Invalid MD2 vertex index");
            }
            if uv >= coords {
                raise ValueError("Invalid MD2 UV index");
            }
            surface.indices.append(vertex);
            surface.uv.append(
                (float(s16_at(body, uv_offset + uv * 4)) + 0.5) / float(width)
            );
            surface.uv.append(
                (float(s16_at(body, uv_offset + uv * 4 + 2)) + 0.5) / float(height)
            );
        }
    }
    for i in range(frames) {
        p = frame_offset + i * stride;
        scale = vec_at(body, p);
        origin = vec_at(body, p + 12);
        frame = AnimationFrame(name=model_name(body, p + 24, 16));
        for j in range(vertices) {
            v = p + 40 + j * 4;
            frame.vertices.append(
                Vec3(
                    x=float(body[v]) * scale.x + origin.x,
                    y=float(body[v + 1]) * scale.y + origin.y,
                    z=float(body[v + 2]) * scale.z + origin.z
                )
            );
        }
        surface.frames.append(frame);
    }
    return AnimatedModel(surfaces=[surface]);
}


def parse_pcx(data: bytes, name: str, transparent: int = -1) -> Texture {
    require_range(data, 0, 128 + 769);
    if data[0] != 10 or data[1] != 5 or data[2] != 1 or data[3] != 8 or data[65] != 1 {
        raise ValueError("Expected 8-bit paletted PCX");
    }
    width = model_count(u16_at(data, 8) - u16_at(data, 4) + 1, 4096, "PCX width");
    height = model_count(u16_at(data, 10) - u16_at(data, 6) + 1, 4096, "PCX height");
    stride = u16_at(data, 66);
    if stride < width or stride > 8192 or data[len(data) - 769] != 12 {
        raise ValueError("Invalid PCX stride or palette");
    }
    end = len(data) - 769;
    p = 128;
    pixels: list[int] = [];
    for row in range(height) {
        line: list[int] = [];
        while len(line) < stride {
            if p >= end {
                raise ValueError("Truncated PCX scanline");
            }
            value = int(data[p]);
            p += 1;
            count = 1;
            if value & 192 == 192 {
                count = value & 63;
                if count == 0 or p >= end {
                    raise ValueError("Invalid PCX run");
                }
                value = int(data[p]);
                p += 1;
            }
            if len(line) + count > stride {
                raise ValueError("PCX run crosses scanline");
            }
            for i in range(count) {
                line.append(value);
            }
        }
        for i in range(width) {
            palette = end + 1 + line[i] * 3;
            pixels.extend(
                [
                    int(data[palette]),
                    int(data[palette + 1]),
                    int(data[palette + 2]),
                    0 if line[i] == transparent else 255
                ]
            );
        }
    }
    return Texture(name=name, width=width, height=height, pixels=bytes(pixels));
}
