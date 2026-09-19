#!/usr/bin/env python3
"""Run the native graphical smoke test against local assets, without bundling them."""
import argparse
import os
from pathlib import Path
import shutil
import struct
import subprocess
import zlib


def check_image(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    assert struct.unpack_from(">II", data, 16) == (1280, 720), path
    offset, compressed = 8, bytearray()
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        if data[offset + 4:offset + 8] == b"IDAT":
            compressed.extend(data[offset + 8:offset + 8 + length])
        offset += length + 12
    # Blank clears compress into very few distinct scanline/filter bytes.
    assert len(set(zlib.decompress(compressed))) > 32, f"Blank image: {path}"


def read_png(path):
    """Decode raylib's 8-bit RGB/RGBA PNGs for exact pixel comparisons."""
    data = Path(path).read_bytes()
    width, height, depth, kind = struct.unpack_from(">IIBB", data, 16)
    channels = {2: 3, 6: 4}[kind]
    assert depth == 8
    compressed = bytearray()
    offset = 8
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        if data[offset + 4:offset + 8] == b"IDAT":
            compressed.extend(data[offset + 8:offset + 8 + length])
        offset += length + 12
    raw = zlib.decompress(compressed)
    pixels = bytearray()
    stride = width * channels
    previous = bytearray(stride)
    for y in range(height):
        offset = y * (stride + 1)
        filter_type = raw[offset]
        row = bytearray(raw[offset + 1:offset + 1 + stride])
        for i in range(stride):
            left = row[i - channels] if i >= channels else 0
            above = previous[i]
            upper_left = previous[i - channels] if i >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                estimate = left + above - upper_left
                distances = [abs(estimate - v) for v in (left, above, upper_left)]
                predictor = (left, above, upper_left)[distances.index(min(distances))]
            else:
                raise ValueError(f"Unknown PNG filter: {filter_type}")
            row[i] = (row[i] + predictor) & 255
        pixels.extend(row)
        previous = row
    return width, height, channels, pixels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("maps", nargs="*", default=["e1m1", "start", "e1m2", "e2m1", "e3m1", "e4m1"])
    parser.add_argument("--binary", default="qp")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    binary = (root / args.binary).resolve()
    output = root / ".jac/screenshots"
    for name in args.maps:
        assert name and all(c.isalnum() or c in "_-" for c in name), "Use a map basename"
        destination = output / name
        destination.mkdir(parents=True, exist_ok=True)
        env = {**os.environ, "QP_SMOKE": "1", "QP_MAP": name}
        env.pop("QP_GRAYBOX", None)
        images = ["pvs", "all", "turn", "moved_pvs", "moved_all"]
        for suffix in images:
            (root / f"qp_quake_{suffix}.png").unlink(missing_ok=True)
        proc = subprocess.run([str(binary)], cwd=root, env=env, capture_output=True, text=True, timeout=90)
        (destination / "run.log").write_text(proc.stdout + proc.stderr)
        assert proc.returncode == 0, f"{name} failed; see {destination / 'run.log'}"
        for suffix in images:
            source = root / f"qp_quake_{suffix}.png"
            check_image(source)
            shutil.copyfile(source, destination / f"{suffix}.png")
        for prefix in ["", "moved_"]:
            left = destination / f"{prefix}pvs.png"
            right = destination / f"{prefix}all.png"
            changed = 0
            if left.read_bytes() != right.read_bytes():
                w, h, channels, a = read_png(left)
                _, _, _, b = read_png(right)
                changed = sum(a[i:i + channels] != b[i:i + channels] for i in range(0, len(a), channels))
            # Coplanar edge ties can vary by a handful of pixels when batching
            # changes. Reject any difference large enough to hide map geometry.
            assert changed <= 16, f"{name}: {changed} PVS pixel differences at {prefix or 'spawn'}"
            print(f"  {name} {prefix or 'spawn'}: {changed} / 921600 pixels differ", flush=True)
        assert (destination / "pvs.png").read_bytes() != (destination / "turn.png").read_bytes(), f"{name}: camera turn had no effect"
        assert (destination / "pvs.png").read_bytes() != (destination / "moved_pvs.png").read_bytes(), f"{name}: flight had no effect"
        print(name + ": textured frames, camera movement, and PVS on/off comparison passed", flush=True)
        for line in proc.stdout.splitlines():
            if line.startswith(("PVS ", "ALL ", "MOVED ")):
                print("  " + line, flush=True)


if __name__ == "__main__":
    main()
