"""Adapt standalone Q1 brush pickup models to the common model renderer.

Q1 draws its health and ammo boxes as brush models, lit by the lightmaps
compiled into their own BSP files (R_DrawBrushModel), not by the world's
light. Each face here becomes a surface whose skin is its texture with that
lightmap already applied, as R_BuildLightMap and the surface cache would
light it: each sample scaled by its style's normal value ('m', 264/256),
doubled and clamped the way the world's lightmaps are, and filtered between
samples 16 texels apart; the palette's fullbright colours stay unlit. The
model is marked `baked_light`, so the world's light is not applied again."""
import math;
import from .bsp { parse_bsp }
import from ..bsp { Bsp, Face, Texture }
import from ..animated { AnimatedModel, AnimatedSurface, AnimationFrame }

# The largest baked face image, in texels on a side.
glob ITEM_BAKE_LIMIT: int = 256;

"""The lightmap level (0 to 255, style values applied) at texture position
(s, t) of `face`, filtered between its samples."""
def item_light_at(bsp: Bsp, face: Face, s: float, t: float) -> float {
    if face.light_offset < 0 or not face.styles {
        return 0.0;
    }
    x = max(0.0, min(float(face.light_width - 1), (s - float(face.light_s * 16)) / 16.0));
    y = max(0.0, min(float(face.light_height - 1), (t - float(face.light_t * 16)) / 16.0));
    x0 = int(x);
    y0 = int(y);
    x1 = min(face.light_width - 1, x0 + 1);
    y1 = min(face.light_height - 1, y0 + 1);
    fx = x - float(x0);
    fy = y - float(y0);
    layer = face.light_width * face.light_height;
    total = 0.0;
    for k in range(len(face.styles)) {
        base = face.light_offset + k * layer;
        a = float(bsp.lighting[base + y0 * face.light_width + x0]);
        b = float(bsp.lighting[base + y0 * face.light_width + x1]);
        c = float(bsp.lighting[base + y1 * face.light_width + x0]);
        d = float(bsp.lighting[base + y1 * face.light_width + x1]);
        top = a + (b - a) * fx;
        bottom = c + (d - c) * fx;
        total += (top + (bottom - top) * fy) * 264.0 / 256.0;
    }
    return total;
}

def parse_item_bsp(data: bytes, palette: bytes) -> AnimatedModel {
    if len(palette) != 768 {
        raise ValueError("Item BSP needs a palette");
    }
    bsp = parse_bsp(data);
    model = AnimatedModel(baked_light=True);
    for f in range(len(bsp.faces)) {
        face = bsp.faces[f];
        count = len(face.vertices);
        if count < 3 or len(face.uv) < count * 2 {
            continue;
        }
        texture = bsp.textures[face.texture];
        width = max(1, texture.width);
        height = max(1, texture.height);
        # The face's extent in texels: its baked image covers exactly it.
        low_s = 1.0e30;
        high_s = -1.0e30;
        low_t = 1.0e30;
        high_t = -1.0e30;
        for corner in range(count) {
            s = face.uv[corner * 2] * float(width);
            t = face.uv[corner * 2 + 1] * float(height);
            low_s = min(low_s, s);
            high_s = max(high_s, s);
            low_t = min(low_t, t);
            high_t = max(high_t, t);
        }
        first_s = int(math.floor(low_s));
        first_t = int(math.floor(low_t));
        span_s = max(1, min(ITEM_BAKE_LIMIT, int(math.ceil(high_s)) - first_s));
        span_t = max(1, min(ITEM_BAKE_LIMIT, int(math.ceil(high_t)) - first_t));
        pixels = bytearray(span_s * span_t * 4);
        unlit = face.tiled or not bsp.lighting;
        for y in range(span_t) {
            t = first_t + y;
            for x in range(span_s) {
                s = first_s + x;
                index = int(texture.pixels[(t % height) * width + (s % width)]) if texture.pixels else 0;
                shade = 1.0;
                if not unlit and index < 224 {
                    shade = min(1.0, item_light_at(bsp, face, float(s) + 0.5, float(t) + 0.5) * 2.0 / 255.0);
                }
                p = (y * span_s + x) * 4;
                pixels[p] = int(float(palette[index * 3]) * shade);
                pixels[p + 1] = int(float(palette[index * 3 + 1]) * shade);
                pixels[p + 2] = int(float(palette[index * 3 + 2]) * shade);
                pixels[p + 3] = 255;
            }
        }
        name = texture.name + "#" + str(f);
        skin = Texture(name=name, width=span_s, height=span_t, pixels=bytes(pixels));
        surface = AnimatedSurface(name=name, embedded_skins=[skin]);
        frame = AnimationFrame(name="static", vertices=list(face.vertices));
        for triangle in range(1, count - 1) {
            # The common renderer reverses file-order triangle winding.
            for corner in [0, triangle, triangle + 1] {
                surface.indices.append(corner);
                surface.uv.extend(
                    [
                        (face.uv[corner * 2] * float(width) - float(first_s)) / float(span_s),
                        (face.uv[corner * 2 + 1] * float(height) - float(first_t)) / float(span_t)
                    ]
                );
            }
        }
        surface.frames.append(frame);
        model.surfaces.append(surface);
    }
    return model;
}
