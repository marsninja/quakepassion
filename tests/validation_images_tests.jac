"""Golden PNG scanlines exercise validation independently of game assets."""
import struct;
import tempfile;
import zlib;
import from pathlib { Path }
import from scripts.png_checks { PngImage, read_png, check_image, different_pixels }

def png_chunk(kind: bytes, payload: bytes) -> bytes {
    return struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload));
}

def png_data(width: int, height: int, kind: int, scanlines: bytes) -> bytes {
    header = struct.pack(">IIBBBBB", width, height, 8, kind, 0, 0, 0);
    return b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(scanlines))
        + png_chunk(b"IEND", b"");
}

test "PNG filters reconstruct golden RGB and RGBA rows" {
    rgb_rows = [
        b"\x00\x0a\x14\x1e\x28\x32\x3c\x00\x46\x50\x5a\x64\x6e\x78",
        b"\x01\x0a\x14\x1e\x1e\x1e\x1e\x01\x46\x50\x5a\x1e\x1e\x1e",
        b"\x02\x0a\x14\x1e\x28\x32\x3c\x02\x3c\x3c\x3c\x3c\x3c\x3c",
        b"\x03\x0a\x14\x1e\x23\x28\x2d\x03\x41\x46\x4b\x2d\x2d\x2d",
        b"\x04\x0a\x14\x1e\x1e\x1e\x1e\x04\x3c\x3c\x3c\x1e\x1e\x1e"
    ];
    rgba_rows = [
        b"\x00\x0a\x14\x1e\x28\x00\x32\x3c\x46\x50",
        b"\x01\x0a\x14\x1e\x28\x01\x32\x3c\x46\x50",
        b"\x02\x0a\x14\x1e\x28\x02\x28\x28\x28\x28",
        b"\x03\x0a\x14\x1e\x28\x03\x2d\x32\x37\x3c",
        b"\x04\x0a\x14\x1e\x28\x04\x28\x28\x28\x28"
    ];
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "fixture.png";
        for row in rgb_rows {
            path.write_bytes(png_data(2, 2, 2, row));
            decoded = read_png(path);
            assert decoded.pixels
                == b"\x0a\x14\x1e\x28\x32\x3c\x46\x50\x5a\x64\x6e\x78";
            assert (decoded.width, decoded.height, decoded.channels) == (2, 2, 3);
        }
        for row in rgba_rows {
            path.write_bytes(png_data(1, 2, 6, row));
            decoded = read_png(path);
            assert decoded.pixels == b"\x0a\x14\x1e\x28\x32\x3c\x46\x50";
            assert decoded.channels == 4;
        }
    }
}

test "image comparisons count changed pixels rather than changed channels" {
    a = PngImage(
        width=2, height=1, channels=4, pixels=b"\x00\x00\x00\xff\x00\x00\x00\xff"
    );
    b = PngImage(
        width=2, height=1, channels=4, pixels=b"\x01\x02\x03\xff\x00\x00\x00\xff"
    );
    assert different_pixels(a, a) == 0;
    assert different_pixels(a, b) == 1;
    b.pixels = b"\x01\x02\x03\xff\x00\x00\x00\x00";
    assert different_pixels(a, b) == 2;
}

test "blank screenshots are rejected" {
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "blank.png";
        path.write_bytes(png_data(1280, 720, 2, bytes((1280 * 3 + 1) * 720)));
        caught = False;
        try {
            check_image(path);
        } except AssertionError {
            caught = True;
        }
        assert caught;
    }
}

test "unsupported PNG filters are rejected" {
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "bad.png";
        path.write_bytes(png_data(1, 1, 2, b"\x05\x01\x02\x03"));
        caught = False;
        try {
            read_png(path);
        } except ValueError {
            caught = True;
        }
        assert caught;
    }
}
