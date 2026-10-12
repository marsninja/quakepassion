import from editor.formats.image { image_size, image_kind }

test "an image's size is read from the head of its file" {
    png = bytes([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 1, 0, 0, 0, 0, 128, 8, 6, 0, 0, 0]);
    assert image_size(png, ".png") == (256, 128);
    tga = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 2, 24, 0, 1, 2, 3]);
    assert image_size(tga, ".tga") == (64, 512);
    # A JPEG: start of image, an application block to skip, then the frame header.
    jpg = bytes(
        [255, 216, 255, 224, 0, 6, 74, 70, 73, 70, 255, 219, 0, 4, 1, 2, 255, 192, 0, 17, 8, 0, 200, 1, 44, 3, 1, 34, 0, 2, 17, 1, 3, 17, 1]
    );
    assert image_size(jpg, ".jpg") == (300, 200) and image_size(jpg, ".JPEG") == (300, 200);
    assert image_size(b"junk", ".png") == (0, 0) and image_size(b"", ".tga") == (0, 0);
    assert image_size(bytes([255, 216, 255, 217]), ".jpg") == (0, 0) and image_size(png, ".bmp") == (0, 0);
    # A BMP: its sizes low byte first, the height below nothing when its rows run from the top.
    bmp = bytes([66, 77] + [0] * 16 + [64, 1, 0, 0, 240, 0, 0, 0] + [0] * 8);
    assert image_size(bmp, ".bmp") == (320, 240);
    top_down = bytes([66, 77] + [0] * 16 + [64, 0, 0, 0, 224, 255, 255, 255] + [0] * 8);
    assert image_size(top_down, ".BMP") == (64, 32) and image_size(b"BM", ".bmp") == (0, 0);
    # A PCX: the corners of its picture, inclusive.
    pcx = bytes([10, 5, 1, 8, 0, 0, 0, 0, 63, 0, 31, 0, 0, 0]);
    assert image_size(pcx, ".pcx") == (64, 32) and image_size(bmp, ".pcx") == (0, 0);
}

test "a file's name says what kind of image it is" {
    assert image_kind("textures/base_wall/concrete.TGA") == ".tga" and image_kind("wall.jpeg") == ".jpg";
    assert image_kind("crate.png") == ".png" and image_kind("metal1_1.wal") == "" and image_kind("readme") == "";
    assert image_kind("old/Sign.BMP") == ".bmp" and image_kind("skin.pcx") == ".pcx";
}
