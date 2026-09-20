"""MD3 version 15 surfaces, vertex frames, shader names and attachment tags."""
import math;
import from ..animated {
    AnimatedModel,
    AnimatedSurface,
    AnimationFrame,
    ModelTag,
    TagFrame,
    model_name,
    model_count
}
import from ..bsp { require_range, i32_at, s16_at, f32_at, vec_at }
import from ...math.vec3 { Vec3 }


def parse_md3(data: bytes) -> AnimatedModel {
    require_range(data, 0, 108);
    if data[:4] != b"IDP3" or i32_at(data, 4) != 15 {
        raise ValueError("Expected MD3 version 15");
    }
    frames = model_count(i32_at(data, 76), 1024, "frames");
    tags = model_count(i32_at(data, 80), 16, "tags", 0);
    surfaces = model_count(i32_at(data, 84), 32, "surfaces", 0);
    frame_offset = i32_at(data, 92);
    tag_offset = i32_at(data, 96);
    p = i32_at(data, 100);
    end = i32_at(data, 104);
    require_range(data, 0, end);
    if end < 108 or frame_offset < 108 or tag_offset < 108 or p < 108 {
        raise ValueError("MD3 data overlaps header");
    }
    body = data[:end];
    require_range(body, frame_offset, frames * 56);
    require_range(body, tag_offset, frames * tags * 112);
    model = AnimatedModel();
    for frame in range(frames) {
        attachment = TagFrame();
        for i in range(tags) {
            t = tag_offset + (frame * tags + i) * 112;
            attachment.tags.append(
                ModelTag(
                    name=model_name(body, t, 64),
                    origin=vec_at(body, t + 64),
                    axes=[
                        vec_at(body, t + 76),
                        vec_at(body, t + 88),
                        vec_at(body, t + 100)
                    ]
                )
            );
        }
        model.tags.append(attachment);
    }
    for i in range(surfaces) {
        require_range(body, p, 108);
        if body[p:p + 4] != b"IDP3" or i32_at(body, p + 72) != frames {
            raise ValueError("Invalid MD3 surface header");
        }
        shaders = model_count(i32_at(body, p + 76), 256, "shaders", 0);
        vertices = model_count(i32_at(body, p + 80), 4096, "vertices");
        triangles = model_count(i32_at(body, p + 84), 8192, "triangles");
        size = i32_at(body, p + 104);
        if size < 108 {
            raise ValueError("Invalid MD3 surface extent");
        }
        require_range(body, p, size);
        surface_data = body[p:p + size];
        tri_offset = i32_at(surface_data, 88);
        shader_offset = i32_at(surface_data, 92);
        uv_offset = i32_at(surface_data, 96);
        vertex_offset = i32_at(surface_data, 100);
        for offset in [tri_offset, shader_offset, uv_offset, vertex_offset] {
            if offset < 108 {
                raise ValueError("MD3 table overlaps surface header");
            }
        }
        require_range(surface_data, tri_offset, triangles * 12);
        require_range(surface_data, shader_offset, shaders * 68);
        require_range(surface_data, uv_offset, vertices * 8);
        require_range(surface_data, vertex_offset, frames * vertices * 8);
        surface = AnimatedSurface(name=model_name(surface_data, 4, 64));
        for shader in range(shaders) {
            surface.skins.append(
                model_name(surface_data, shader_offset + shader * 68, 64)
            );
        }
        for corner in range(triangles * 3) {
            vertex = i32_at(surface_data, tri_offset + corner * 4);
            if vertex < 0 or vertex >= vertices {
                raise ValueError("Invalid MD3 vertex index");
            }
            surface.indices.append(vertex);
            surface.uv.extend(
                [
                    f32_at(surface_data, uv_offset + vertex * 8),
                    f32_at(surface_data, uv_offset + vertex * 8 + 4)
                ]
            );
        }
        for frame in range(frames) {
            animation = AnimationFrame(
                name=model_name(body, frame_offset + frame * 56 + 40, 16)
            );
            for vertex in range(vertices) {
                v = vertex_offset + (frame * vertices + vertex) * 8;
                latitude = float(surface_data[v + 7]) * 6.283185307179586 / 256.0;
                longitude = float(surface_data[v + 6]) * 6.283185307179586 / 256.0;
                animation.normals.append(
                    Vec3(
                        x=math.cos(latitude) * math.sin(longitude),
                        y=math.sin(latitude) * math.sin(longitude),
                        z=math.cos(longitude)
                    )
                );
                animation.vertices.append(
                    Vec3(
                        x=float(s16_at(surface_data, v)) / 64.0,
                        y=float(s16_at(surface_data, v + 2)) / 64.0,
                        z=float(s16_at(surface_data, v + 4)) / 64.0
                    )
                );
            }
            surface.frames.append(animation);
        }
        model.surfaces.append(surface);
        p += size;
    }
    return model;
}
