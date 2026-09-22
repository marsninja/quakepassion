"""Validated Quake II SP2 frame metadata; image decoding stays in the asset layer."""
import from ..sprite { SpriteFrame }
import from ..bsp { require_range, i32_at }
import from ..animated { model_count, model_name }

def parse_sp2(data: bytes) -> list[SpriteFrame] {
    require_range(data, 0, 12);
    if data[:4] != b"IDS2" or i32_at(data, 4) != 2 {
        raise ValueError("Expected SP2 version 2");
    }
    count = model_count(i32_at(data, 8), 256, "sprite frames");
    require_range(data, 12, count * 80);
    frames: list[SpriteFrame] = [];
    for index in range(count) {
        offset = 12 + index * 80;
        width = model_count(i32_at(data, offset), 4096, "sprite width");
        height = model_count(i32_at(data, offset + 4), 4096, "sprite height");
        x = i32_at(data, offset + 8);
        y = i32_at(data, offset + 12);
        if abs(x) > 8192 or abs(y) > 8192 {
            raise ValueError("Invalid sprite pivot");
        }
        name = model_name(data, offset + 16, 64);
        if not name or not name.lower().endswith(".pcx") {
            raise ValueError("Expected PCX sprite image");
        }
        frames.append(
            SpriteFrame(width=width, height=height, origin_x=x, origin_y=y, image=name)
        );
    }
    return frames;
}
