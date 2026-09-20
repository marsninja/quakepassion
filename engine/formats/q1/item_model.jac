"""Adapt standalone Q1 brush pickup models to the common model renderer."""
import from .bsp { parse_bsp }
import from ..bsp { Texture }
import from ..animated { AnimatedModel, AnimatedSurface, AnimationFrame }


def parse_item_bsp(data: bytes, palette: bytes) -> AnimatedModel {
    if len(palette) != 768 {
        raise ValueError("Item BSP needs a palette");
    }
    bsp = parse_bsp(data);
    model = AnimatedModel();
    for index in range(len(bsp.textures)) {
        texture = bsp.textures[index];
        pixels: list[int] = [];
        for color in texture.pixels {
            p = int(color) * 3;
            pixels.extend(
                [int(palette[p]), int(palette[p + 1]), int(palette[p + 2]), 255]
            );
        }
        skin = Texture(
            name=texture.name,
            width=texture.width,
            height=texture.height,
            pixels=bytes(pixels)
        );
        surface = AnimatedSurface(name=texture.name, embedded_skins=[skin]);
        frame = AnimationFrame(name="static");
        for face in bsp.faces {
            if face.texture != index {
                continue;
            }
            first = len(frame.vertices);
            frame.vertices.extend(face.vertices);
            for triangle in range(1, len(face.vertices) - 1) {
                # The common renderer reverses file-order triangle winding.
                for corner in [0, triangle, triangle + 1] {
                    surface.indices.append(first + corner);
                    surface.uv.extend([face.uv[corner * 2], face.uv[corner * 2 + 1]]);
                }
            }
        }
        if surface.indices {
            surface.frames.append(frame);
            model.surfaces.append(surface);
        }
    }
    return model;
}
