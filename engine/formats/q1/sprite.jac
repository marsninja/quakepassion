"""Quake SPR sprites (spritegn.h): an IDSP version 1 header, then single or
grouped paletted frames, index 255 transparent."""
import from ..bsp { Texture, require_range, i32_at }
import from ..sprite { SpriteFrame }
import from .wad { indexed_rgba }

obj SpriteImage {
    has frame: SpriteFrame,
        image: Texture;
}

def q1_sprite_frame(data: bytes, offset: int, palette: bytes, name: str, index: int) -> SpriteImage {
    require_range(data, offset, 16);
    left = i32_at(data, offset);
    top = i32_at(data, offset + 4);
    width = i32_at(data, offset + 8);
    height = i32_at(data, offset + 12);
    if width <= 0 or height <= 0 or width > 1024 or height > 1024 {
        raise ValueError("Invalid SPR frame size");
    }
    require_range(data, offset + 16, width * height);
    pixels = indexed_rgba(data[offset + 16:offset + 16 + width * height], palette);
    # R_GetSpriteFrame: the frame spans left..left+width and top-height..top
    # around the origin; SpriteFrame counts its pivot from the image corner.
    return SpriteImage(
        frame=SpriteFrame(
            width=width,
            height=height,
            origin_x=-left,
            origin_y=height - top,
            image=name + "#" + str(index)
        ),
        image=Texture(name=name + "#" + str(index), width=width, height=height, pixels=pixels)
    );
}

"""Every frame in file order; a frame group contributes all its pictures."""
def parse_spr(data: bytes, palette: bytes, name: str = "sprite") -> list[SpriteImage] {
    require_range(data, 0, 36);
    if data[:4] != b"IDSP" or i32_at(data, 4) != 1 {
        raise ValueError("Expected SPR version 1");
    }
    if len(palette) != 768 {
        raise ValueError("SPR needs a 256-color palette");
    }
    count = i32_at(data, 24);
    if count <= 0 or count > 256 {
        raise ValueError("Invalid SPR frame count");
    }
    frames: list[SpriteImage] = [];
    offset = 36;
    for index in range(count) {
        require_range(data, offset, 4);
        kind = i32_at(data, offset);
        offset += 4;
        pictures = 1;
        if kind != 0 {
            require_range(data, offset, 4);
            pictures = i32_at(data, offset);
            if pictures <= 0 or pictures > 64 {
                raise ValueError("Invalid SPR group");
            }
            offset += 4 + pictures * 4;
        }
        for picture in range(pictures) {
            frame = q1_sprite_frame(data, offset, palette, name, len(frames));
            frames.append(frame);
            offset += 16 + frame.frame.width * frame.frame.height;
        }
    }
    return frames;
}
