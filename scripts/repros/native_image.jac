"""Probe encoded image bytes and raylib's by-value Image return."""
import os;
import from zipfile { ZipFile }
import from zlib { crc32 }
import from engine.render.quake { LoadImageFromMemory, UnloadImage }
with entry {
    archive = ZipFile(os.getenv("HOME", "") + "/quake-assets/baseq3/pak0.pk3");
    data = archive.read("textures/gothic_block/killblock.jpg");
    print("JPEG", len(data), int(data[0]), int(data[1]), crc32(data));
    image = LoadImageFromMemory(".jpg", data, i32(len(data)));
    print("IMAGE", int(image.width), int(image.height), int(image.format));
    UnloadImage(image);
    archive.close();
}
