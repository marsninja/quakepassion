"""MDL version 6, including seam coordinates and grouped skins/frames."""
import from ..animated {
    AnimatedModel,
    AnimatedSurface,
    AnimationFrame,
    AnimationGroup,
    model_count,
    model_name
}
import from ..bsp { Texture, require_range, i32_at, f32_at, vec_at }
import from ...math.vec3 { Vec3 }


def intervals(data: bytes, offset: int, count: int) -> list[float] {
    require_range(data, offset, count * 4);
    values: list[float] = [];
    previous = 0.0;
    for i in range(count) {
        value = f32_at(data, offset + i * 4);
        if value <= previous {
            raise ValueError("MDL intervals must increase");
        }
        values.append(value);
        previous = value;
    }
    return values;
}


def parse_mdl(data: bytes, palette: bytes) -> AnimatedModel {
    require_range(data, 0, 84);
    if data[:4] != b"IDPO" or i32_at(data, 4) != 6 {
        raise ValueError("Expected MDL version 6");
    }
    if len(palette) != 768 {
        raise ValueError("MDL needs a 256-color palette");
    }
    scale = vec_at(data, 8);
    origin = vec_at(data, 20);
    skins = model_count(i32_at(data, 48), 256, "skins");
    width = model_count(i32_at(data, 52), 4096, "skin width");
    height = model_count(i32_at(data, 56), 4096, "skin height");
    vertices = model_count(i32_at(data, 60), 4096, "vertices");
    triangles = model_count(i32_at(data, 64), 8192, "triangles");
    frames = model_count(i32_at(data, 68), 4096, "frames");
    surface = AnimatedSurface(name="mdl");
    p = 84;
    for skin in range(skins) {
        kind = i32_at(data, p);
        p += 4;
        group = AnimationGroup(first=len(surface.embedded_skins), count=1);
        if kind == 1 {
            group.count = model_count(i32_at(data, p), 256, "skin group");
            p += 4;
            group.intervals = intervals(data, p, group.count);
            p += group.count * 4;
        } elif kind != 0 {
            raise ValueError("Invalid MDL skin type");
        }
        for sub in range(group.count) {
            require_range(data, p, width * height);
            pixels: list[int] = [];
            for i in range(width * height) {
                color = int(data[p + i]) * 3;
                pixels.extend(
                    [
                        int(palette[color]),
                        int(palette[color + 1]),
                        int(palette[color + 2]),
                        255
                    ]
                );
            }
            name = "skin" + str(skin) + ":" + str(sub);
            surface.skins.append(name);
            surface.embedded_skins.append(
                Texture(name=name, width=width, height=height, pixels=bytes(pixels))
            );
            p += width * height;
        }
        surface.skin_groups.append(group);
    }
    coords = p;
    require_range(data, p, vertices * 12 + triangles * 16);
    p += vertices * 12;
    for i in range(triangles) {
        front = i32_at(data, p);
        for corner in range(3) {
            vertex = i32_at(data, p + 4 + corner * 4);
            if vertex < 0 or vertex >= vertices {
                raise ValueError("Invalid MDL vertex index");
            }
            coord = coords + vertex * 12;
            s = float(i32_at(data, coord + 4));
            if front == 0 and i32_at(data, coord) != 0 {
                s += float(width) * 0.5;
            }
            surface.indices.append(vertex);
            surface.uv.extend(
                [
                    (s + 0.5) / float(width),
                    (float(i32_at(data, coord + 8)) + 0.5) / float(height)
                ]
            );
        }
        p += 16;
    }
    for i in range(frames) {
        kind = i32_at(data, p);
        p += 4;
        group = AnimationGroup(first=len(surface.frames), count=1);
        if kind == 1 {
            require_range(data, p, 12);
            group.count = model_count(i32_at(data, p), 4096, "frame group");
            p += 12;
            group.intervals = intervals(data, p, group.count);
            p += group.count * 4;
        } elif kind != 0 {
            raise ValueError("Invalid MDL frame type");
        }
        for sub in range(group.count) {
            require_range(data, p, 24 + vertices * 4);
            frame = AnimationFrame(name=model_name(data, p + 8, 16));
            p += 24;
            for j in range(vertices) {
                frame.vertices.append(
                    Vec3(
                        x=float(data[p]) * scale.x + origin.x,
                        y=float(data[p + 1]) * scale.y + origin.y,
                        z=float(data[p + 2]) * scale.z + origin.z
                    )
                );
                p += 4;
            }
            surface.frames.append(frame);
        }
        surface.frame_groups.append(group);
    }
    return AnimatedModel(surfaces=[surface], flags=i32_at(data, 76));
}
