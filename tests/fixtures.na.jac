"""Synthetic binary fixtures for Phase 2 parser tests.

Builds PAK/BSP byte buffers in memory from records (struct.pack + concat), so
parser tests run on known-answer data with no committed binaries and no real
Quake game files. This is exactly the in-Jac fixture construction the native
length-aware bytes + struct work (jaseci #6727/#6745/#6749) unblocked.

Test support, not engine code — kept as plain functions (no impl annex)."""

import struct;


"""Encode a name into a fixed-width, NUL-padded byte field (truncating if the
name is too long), matching how PAK stores its 56-byte path entries."""
def padname(name: str, width: int) -> bytes {
    raw = name.encode("utf-8");
    if len(raw) >= width {
        return raw[0:width];
    }
    return raw + b"\x00" * (width - len(raw));
}


"""One file to embed in a synthetic pak: a logical path and its raw bytes."""
obj PakFile {
    has name: str,
        data: bytes;
}


"""Assemble a valid PAK archive buffer: a 12-byte header (PACK magic + directory
offset/length), then 64-byte directory entries, then the concatenated payloads.
Directory and payloads are laid out exactly where the header advertises."""
def build_pak(files: list[PakFile]) -> bytes {
    name_len = 56;
    entry_size = 64;
    header_size = 12;
    dir_size = len(files) * entry_size;

    directory = b"";
    payloads = b"";
    pos = header_size + dir_size;        # first payload sits after the directory
    for f in files {
        directory = directory + padname(f.name, name_len) + struct.pack("<ii", pos, len(f.data));
        payloads = payloads + f.data;
        pos = pos + len(f.data);
    }

    return b"PACK" + struct.pack("<ii", header_size, dir_size) + directory + payloads;
}


"""Assemble a tiny but valid BSP29 buffer: version 29 + a 15-lump directory,
then the lump data laid out where the directory points. One triangular face on
a +Z plane, three vertices/edges/surfedges, one node, a solid + an empty leaf,
one marksurface, one model, 1 byte of visdata, and a worldspawn entity. Lumps
we don't parse this phase (textures/texinfo/lighting/clipnodes) are empty."""
def build_bsp() -> bytes {
    ents = "{\n\"classname\" \"worldspawn\"\n}\n".encode("utf-8") + b"\x00";

    l_entities = ents;                                                  # 0
    l_planes = struct.pack("<ffffi", 0.0, 0.0, 1.0, 0.0, 2);            # 1: +Z plane
    l_textures = b"";                                                   # 2
    l_vertices = struct.pack("<fff", 0.0, 0.0, 0.0)                     # 3
        + struct.pack("<fff", 64.0, 0.0, 0.0)
        + struct.pack("<fff", 0.0, 64.0, 0.0);
    l_visibility = b"\xff";                                             # 4
    l_nodes = struct.pack("<ihhhhhhhhHH",                               # 5
        0, -1, -2, -99, -99, -99, 99, 99, 99, 0, 1);
    l_texinfo = b"";                                                    # 6
    l_faces = struct.pack("<HHiHHBBBBi",                                # 7
        0, 0, 0, 3, 0, 0, 0, 0, 0, -1);
    l_lighting = b"";                                                   # 8
    l_clipnodes = b"";                                                  # 9
    l_leafs = struct.pack("<iihhhhhhHHBBBB",                            # 10: solid
            -2, -1, -99, -99, -99, 99, 99, 99, 0, 0, 0, 0, 0, 0)
        + struct.pack("<iihhhhhhHHBBBB",                                #     empty
            -1, 0, -99, -99, -99, 99, 99, 99, 0, 1, 0, 0, 0, 0);
    l_marksurfaces = struct.pack("<H", 0);                             # 11
    l_edges = struct.pack("<HH", 0, 1)                                  # 12
        + struct.pack("<HH", 1, 2)
        + struct.pack("<HH", 2, 0);
    l_surfedges = struct.pack("<i", 0)                                  # 13
        + struct.pack("<i", 1)
        + struct.pack("<i", 2);
    l_models = struct.pack("<fffffffffiiiiiii",                         # 14
        0.0, 0.0, 0.0, 64.0, 64.0, 128.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 1, 0, 1);

    lumps = [
        l_entities, l_planes, l_textures, l_vertices, l_visibility,
        l_nodes, l_texinfo, l_faces, l_lighting, l_clipnodes,
        l_leafs, l_marksurfaces, l_edges, l_surfedges, l_models
    ];

    header_size = 4 + 15 * 8;
    directory = b"";
    data = b"";
    pos = header_size;
    for lb in lumps {
        directory = directory + struct.pack("<ii", pos, len(lb));
        data = data + lb;
        pos = pos + len(lb);
    }
    return struct.pack("<i", 29) + directory + data;
}
