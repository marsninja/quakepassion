"""Decode raylib PNG captures and compare their actual pixels."""
import struct;
import zlib;
import from pathlib { Path }

obj PngImage {
    has width: int,
        height: int,
        channels: int,
        pixels: bytes;
}

def read_png(path: Path) -> PngImage {
    data = path.read_bytes();
    assert len(data) >= 33 and data[:8] == b"\x89PNG\r\n\x1a\n" , str(path);
    (width, height, depth, kind) = struct.unpack_from(">IIBB", data, 16);
    assert depth == 8 and kind in [2, 6] , "Expected 8-bit RGB/RGBA PNG";
    assert data[28] == 0 , "Interlaced PNG is not supported";
    channels = 3 if kind == 2 else 4;
    compressed = bytearray();
    offset = 8;
    while offset < len(data) {
        assert offset + 12 <= len(data) , "Truncated PNG chunk";
        length = int(struct.unpack_from(">I", data, offset)[0]);
        assert offset + length + 12 <= len(data) , "Truncated PNG payload";
        if data[offset + 4:offset + 8] == b"IDAT" {
            compressed.extend(data[offset + 8:offset + 8 + length]);
        }
        offset += length + 12;
    }
    raw = zlib.decompress(compressed);
    stride = int(width) * channels;
    assert len(raw) == int(height) * (stride + 1) , "Invalid PNG scanline size";
    pixels = bytearray();
    previous = bytearray(stride);
    for y in range(int(height)) {
        offset = y * (stride + 1);
        filter_type = raw[offset];
        row = bytearray(raw[offset + 1:offset + 1 + stride]);
        for i in range(stride) {
            left = row[i - channels] if i >= channels else 0;
            above = previous[i];
            upper_left = previous[i - channels] if i >= channels else 0;
            predictor = 0;
            if filter_type == 0 {
                predictor = 0;
            } elif filter_type == 1 {
                predictor = left;
            } elif filter_type == 2 {
                predictor = above;
            } elif filter_type == 3 {
                predictor = (left + above) // 2;
            } elif filter_type == 4 {
                estimate = left + above - upper_left;
                distances = [
                    abs(estimate - left),
                    abs(estimate - above),
                    abs(estimate - upper_left)
                ];
                predictor = [left, above, upper_left][distances.index(min(distances))];
            } else {
                raise ValueError(f"Unknown PNG filter: {filter_type}");
            }
            row[i] = (row[i] + predictor) & 255;
        }
        pixels.extend(row);
        previous = row;
    }
    return PngImage(
        width=int(width), height=int(height), channels=channels, pixels=bytes(pixels)
    );
}

def check_image(path: Path) -> PngImage {
    decoded = read_png(path);
    assert decoded.width == 1280 and decoded.height == 720 , str(path);
    colors: set[bytes] = set();
    for i in range(0, len(decoded.pixels), decoded.channels) {
        colors.add(decoded.pixels[i:i + 3]);
        if len(colors) > 64 {
            return decoded;
        }
    }
    raise AssertionError(f"Blank or nearly uniform image: {path}");
}

def different_pixels(left: PngImage, right: PngImage) -> int {
    assert (left.width, left.height, left.channels)
        == (right.width, right.height, right.channels) , "Image dimensions or channels differ";
    if left.pixels == right.pixels {
        return 0;
    }
    changed = 0;
    for i in range(0, len(left.pixels), left.channels) {
        if left.pixels[i:i + left.channels] != right.pixels[i:i + left.channels] {
            changed += 1;
        }
    }
    return changed;
}
