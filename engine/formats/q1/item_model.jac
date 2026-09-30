"""Adapt standalone Q1 brush pickup models to the common model renderer.

Q1 draws its health and ammo boxes as brush models, lit by the lightmaps
compiled into their own BSP files (R_DrawBrushModel), not by the world's
light. Each face here becomes a surface whose skin is its texture with that
lightmap already applied, as R_BuildLightMap and the surface cache would
light it: each sample scaled by its style's normal value ('m', 264/256),
doubled and clamped the way the world's lightmaps are, and filtered between
samples 16 texels apart; the palette's fullbright colours stay unlit. The
faces' images are packed into one skin (each with a one-texel border copied
from its edge, so no face samples its neighbour) and the faces into one
surface: a pickup draws in one call. The model is marked `baked_light`, so
the world's light is not applied again."""
import math;
import from .bsp { parse_bsp }
import from ..bsp { Bsp, Face, Texture }
import from ..animated { AnimatedModel, AnimatedSurface, AnimationFrame }
import from ...math.vec3 { Vec3 }

# The largest baked face image, in texels on a side, and the border each
# keeps in the packed skin.
glob ITEM_BAKE_LIMIT: int = 256,
     ITEM_BAKE_BORDER: int = 1;

"""One face's baked image and where its texture coordinates start."""
obj ItemFaceBake {
    has face: Face,
        width: int,
        height: int,
        pixels: bytearray,
        first_s: int,
        first_t: int,
        texture_width: int,
        texture_height: int,
        x: int = 0,
        y: int = 0;
}

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
    bakes: list[ItemFaceBake] = [];
    for f in range(len(bsp.faces)) {
        face = bsp.faces[f];
        count = len(face.vertices);
        if count < 3 or len(face.uv) < count * 2 {
            continue;
        }
        bakes.append(bake_item_face(bsp, face, palette));
    }
    if not bakes {
        return model;
    }
    atlas = pack_item_faces(bakes);
    surface = AnimatedSurface(name="item", embedded_skins=[atlas]);
    vertices: list[Vec3] = [];
    for bake in bakes {
        face = bake.face;
        count = len(face.vertices);
        base = len(vertices);
        vertices.extend(face.vertices);
        for triangle in range(1, count - 1) {
            # The common renderer reverses file-order triangle winding.
            for corner in [0, triangle, triangle + 1] {
                surface.indices.append(base + corner);
                s = face.uv[corner * 2] * float(bake.texture_width) - float(bake.first_s);
                t = face.uv[corner * 2 + 1] * float(bake.texture_height) - float(bake.first_t);
                surface.uv.extend(
                    [
                        (float(bake.x) + s) / float(atlas.width),
                        (float(bake.y) + t) / float(atlas.height)
                    ]
                );
            }
        }
    }
    surface.frames.append(AnimationFrame(name="static", vertices=vertices));
    model.surfaces.append(surface);
    return model;
}

"""A face's texture under its own lightmap, covering exactly its extent."""
def bake_item_face(bsp: Bsp, face: Face, palette: bytes) -> ItemFaceBake {
    texture = bsp.textures[face.texture];
    width = max(1, texture.width);
    height = max(1, texture.height);
    count = len(face.vertices);
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
    return ItemFaceBake(
        face=face,
        width=span_s,
        height=span_t,
        pixels=pixels,
        first_s=first_s,
        first_t=first_t,
        texture_width=width,
        texture_height=height
    );
}

"""Shelf-pack the baked faces into one skin, setting each bake's place (its
image's first texel, inside its border)."""
def pack_item_faces(bakes: list[ItemFaceBake]) -> Texture {
    border = ITEM_BAKE_BORDER;
    widest = max([bake.width for bake in bakes]) + 2 * border;
    area = sum([(bake.width + 2 * border) * (bake.height + 2 * border) for bake in bakes]);
    row_width = max(widest, int(math.ceil(math.sqrt(float(area)))));
    x = 0;
    y = 0;
    row_height = 0;
    # Tallest first, so each shelf wastes little height.
    order = sorted([(-bakes[i].height, i) for i in range(len(bakes))]);
    for ranked in order {
        bake = bakes[ranked[1]];
        cell_w = bake.width + 2 * border;
        cell_h = bake.height + 2 * border;
        if x + cell_w > row_width {
            x = 0;
            y += row_height;
            row_height = 0;
        }
        bake.x = x + border;
        bake.y = y + border;
        x += cell_w;
        row_height = max(row_height, cell_h);
    }
    atlas_width = row_width;
    atlas_height = y + row_height;
    atlas = bytearray(atlas_width * atlas_height * 4);
    for bake in bakes {
        for ay in range(bake.height + 2 * border) {
            sy = max(0, min(bake.height - 1, ay - border));
            for ax in range(bake.width + 2 * border) {
                sx = max(0, min(bake.width - 1, ax - border));
                src = (sy * bake.width + sx) * 4;
                dst = ((bake.y - border + ay) * atlas_width + (bake.x - border + ax)) * 4;
                atlas[dst] = bake.pixels[src];
                atlas[dst + 1] = bake.pixels[src + 1];
                atlas[dst + 2] = bake.pixels[src + 2];
                atlas[dst + 3] = bake.pixels[src + 3];
            }
        }
    }
    return Texture(name="item", width=atlas_width, height=atlas_height, pixels=bytes(atlas));
}
