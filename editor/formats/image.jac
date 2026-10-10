"""How big an image file is, read from its first bytes: PNG, TGA and JPEG,
the kinds Quake III keeps its textures in and the kinds a project brings
its own in."""

"""An image's width and height from its file's bytes, by its kind (".png",
".tga", ".jpg"), or (0, 0) when it does not read as one."""
def image_size(data: bytes, extension: str) -> tuple[int, int] {
    kind = extension.lower();
    if kind == ".png" {
        # Eight bytes of signature, a chunk's length and name, then both sizes, high byte first.
        if len(data) < 24 or data[1] != 80 or data[2] != 78 or data[3] != 71 {
            return (0, 0);
        }
        return (
            (data[16] << 24) | (data[17] << 16) | (data[18] << 8) | data[19],
            (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23]
        );
    }
    if kind == ".tga" {
        if len(data) < 18 {
            return (0, 0);
        }
        return (data[12] | (data[13] << 8), data[14] | (data[15] << 8));
    }
    if kind == ".jpg" or kind == ".jpeg" {
        if len(data) < 4 or data[0] != 255 or data[1] != 216 {
            return (0, 0);
        }
        at = 2;
        while at + 9 < len(data) {
            if data[at] != 255 {
                at += 1;
                continue;
            }
            code = data[at + 1];
            if code == 255 {
                at += 1;
                continue;
            }
            # A frame header says the size: every start-of-frame but the
            # tables that share its range.
            if code >= 192 and code <= 207 and code != 196 and code != 200 and code != 204 {
                return ((data[at + 7] << 8) | data[at + 8], (data[at + 5] << 8) | data[at + 6]);
            }
            if code >= 208 and code <= 217 {
                at += 2;
                continue;
            }
            at += 2 + ((data[at + 2] << 8) | data[at + 3]);
        }
        return (0, 0);
    }
    return (0, 0);
}

"""The kind of image a file name says it is: ".png", ".tga" or ".jpg", or
"" when it is none of them."""
def image_kind(name: str) -> str {
    low = name.lower();
    if low.endswith(".png") {
        return ".png";
    }
    if low.endswith(".tga") {
        return ".tga";
    }
    if low.endswith(".jpg") or low.endswith(".jpeg") {
        return ".jpg";
    }
    return "";
}
