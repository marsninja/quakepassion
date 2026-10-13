"""Quake 1 BSP decoding: BSP29, and BSP2, the same file with the 16-bit counts
and indices of its faces, edges, leaves, nodes and clip nodes widened to 32
bits (and leaf and node bounds to floats) for maps past BSP29's limits. Disk
indices remain explicit until graph assembly."""
import math;
import struct;
import from ...math.vec3 { Vec3 }

import from ..bsp {
    Bsp,
    Texture,
    TexInfo,
    Face,
    Plane,
    Branch,
    Leaf,
    Model,
    MapEntity,
    require_range,
    i32_at,
    u16_at,
    f32_at,
    vec_at,
    bounds_at,
    records,
    check_index,
    parse_entities,
    decode_pvs
}

"""A number rounded to single precision, as a C float holds it."""
def single(value: float) -> float {
    return float(struct.unpack("<f", struct.pack("<f", value))[0]);
}

"""A BSP29 node's or clip node's child: an unsigned 16-bit number, an index
below `count` and otherwise a leaf (nodes) or contents (clip nodes) counted
down from 65535, as QuakeSpasm's Mod_LoadNodes_S and Mod_LoadClipnodes read
them so a map may hold more than 32767. Within that many it is the signed
number Quake read."""
def bsp29_child(data: bytes, at: int, count: int) -> int {
    child = u16_at(data, at);
    return child if child < count else child - 65536;
}

def parse_textures(data: bytes) -> list[Texture] {
    count = i32_at(data, 0);
    if count < 0 or count > 4096 {
        raise ValueError("Invalid BSP texture count");
    }
    require_range(data, 4, count * 4);
    result: list[Texture] = [];
    for i in range(count) {
        start = i32_at(data, 4 + i * 4);
        if start == -1 {
            result.append(Texture());
            continue;
        }
        require_range(data, start, 40);
        end = start;
        while end < start + 16 and data[end] != 0 {
            end += 1;
        }
        width = i32_at(data, start + 16);
        height = i32_at(data, start + 20);
        if width <= 0 or height <= 0 or width > 4096 or height > 4096 {
            raise ValueError("Invalid BSP texture dimensions");
        }
        mip = i32_at(data, start + 24);
        if mip < 40 {
            raise ValueError("Invalid BSP texture pixel offset");
        }
        require_range(data, start + mip, width * height);
        result.append(
            Texture(
                name=data[start:end].decode("latin-1"),
                width=width,
                height=height,
                pixels=data[start + mip:start + mip + width * height]
            )
        );
    }
    return result;
}

"""Whether a file is a Quake 1 map this parser reads."""
def is_q1_bsp(data: bytes) -> bool {
    return len(data) >= 4 and (data[0:4] == b"BSP2" or i32_at(data, 0) == 29);
}

def parse_bsp(data: bytes) -> Bsp {
    require_range(data, 0, 124);
    if not is_q1_bsp(data) {
        raise ValueError("Expected Quake 1 BSP version 29 or BSP2");
    }
    # BSP2 widens these records; everything else is BSP29's.
    wide = data[0:4] == b"BSP2";
    face_size = 28 if wide else 20;
    edge_size = 8 if wide else 4;
    mark_size = 4 if wide else 2;
    leaf_size = 44 if wide else 28;
    node_size = 44 if wide else 24;
    clip_size = 12 if wide else 8;
    lumps: list[bytes] = [];
    for i in range(15) {
        offset = i32_at(data, 4 + i * 8);
        size = i32_at(data, 8 + i * 8);
        require_range(data, offset, size);
        lumps.append(data[offset:offset + size]);
    }
    bsp = Bsp(lighting=lumps[8], visibility=lumps[4]);
    # Quake's text is bytes: its high half is the conchars' bronze letters.
    bsp.entities = parse_entities(lumps[0].decode("latin-1"));
    bsp.textures = parse_textures(lumps[2]);
    for i in range(records(lumps[1], 20)) {
        bsp.planes.append(
            Plane(
                normal=vec_at(lumps[1], i * 20), distance=f32_at(lumps[1], i * 20 + 12)
            )
        );
    }
    vertices: list[Vec3] = [];
    for i in range(records(lumps[3], 12)) {
        vertices.append(vec_at(lumps[3], i * 12));
    }
    texinfo: list[TexInfo] = [];
    for i in range(records(lumps[6], 40)) {
        p = i * 40;
        texture = i32_at(lumps[6], p + 32);
        check_index(texture, len(bsp.textures));
        texinfo.append(
            TexInfo(
                s=vec_at(lumps[6], p),
                t=vec_at(lumps[6], p + 16),
                soff=f32_at(lumps[6], p + 12),
                toff=f32_at(lumps[6], p + 28),
                texture=texture,
                flags=i32_at(lumps[6], p + 36)
            )
        );
    }
    edge_count = records(lumps[12], edge_size);
    surf_count = records(lumps[13], 4);
    for i in range(records(lumps[7], face_size)) {
        p = i * face_size;
        # dface_t, or dface2_t: plane, side, first edge, edge count, texinfo,
        # four styles, light offset.
        plane = i32_at(lumps[7], p) if wide else u16_at(lumps[7], p);
        check_index(plane, len(bsp.planes));
        side = i32_at(lumps[7], p + 4) if wide else u16_at(lumps[7], p + 2);
        first = i32_at(lumps[7], p + 8) if wide else i32_at(lumps[7], p + 4);
        count = i32_at(lumps[7], p + 12) if wide else u16_at(lumps[7], p + 8);
        ti = i32_at(lumps[7], p + 16) if wide else u16_at(lumps[7], p + 10);
        check_index(ti, len(texinfo));
        styles_at = p + (20 if wide else 12);
        if count < 3 or first < 0 or first + count > surf_count {
            raise ValueError("Invalid BSP face edge range");
        }
        info = texinfo[ti];
        face_texture = bsp.textures[info.texture];
        # Textures named '*' are liquids: water, slime, lava and teleporters.
        # Mod_LoadFaces: sky and liquid ('*') surfaces are SURF_DRAWTILED.
        face = Face(
            texture=info.texture,
            warp=bsp.textures[info.texture].name.startswith("*"),
            texinfo=info,
            tiled=face_texture.name.startswith("*") or face_texture.name.startswith("sky"),
            light_offset=i32_at(lumps[7], styles_at + 4),
            normal=bsp.planes[plane].normal,
            plane_dist=bsp.planes[plane].distance
        );
        if side != 0 {
            face.normal = face.normal.scale(-1.0);
            face.plane_dist = -face.plane_dist;
        }
        for j in range(4) {
            style = int(lumps[7][styles_at + j]);
            if style != 255 {
                face.styles.append(style);
            }
        }
        min_s = 1.0e30;
        max_s = -1.0e30;
        min_t = 1.0e30;
        max_t = -1.0e30;
        for j in range(count) {
            se = i32_at(lumps[13], (first + j) * 4);
            ei = abs(se);
            check_index(ei, edge_count);
            ep = ei * edge_size;
            if se < 0 {
                ep += edge_size // 2;
            }
            vi = i32_at(lumps[12], ep) if wide else u16_at(lumps[12], ep);
            check_index(vi, len(vertices));
            v = vertices[vi];
            face.vertices.append(v);
            s = v.dot(info.s) + info.soff;
            t = v.dot(info.t) + info.toff;
            face.uv.append(s / float(face_texture.width));
            face.uv.append(t / float(face_texture.height));
            # CalcSurfaceExtents keeps each coordinate in a float: the sum is
            # rounded to single precision before the extents are taken. The
            # light compilers did the same, so a face's lightmap is the size
            # they wrote only with that rounding; without it a coordinate a
            # hair past a 16-unit line adds a texel the lump does not hold.
            extent_s = single(s);
            extent_t = single(t);
            min_s = min(min_s, extent_s);
            max_s = max(max_s, extent_s);
            min_t = min(min_t, extent_t);
            max_t = max(max_t, extent_t);
        }
        face.light_s = int(math.floor(min_s / 16.0));
        face.light_t = int(math.floor(min_t / 16.0));
        face.light_width = int(math.ceil(max_s / 16.0)) - face.light_s + 1;
        face.light_height = int(math.ceil(max_t / 16.0)) - face.light_t + 1;
        if face.light_offset >= 0 {
            require_range(
                bsp.lighting,
                face.light_offset,
                face.light_width * face.light_height * len(face.styles)
            );
        }
        for j in range(count) {
            face.light_uv.append(
                face.uv[j * 2] * float(face_texture.width) / 16.0 - float(face.light_s)
            );
            face.light_uv.append(
                face.uv[j * 2 + 1] * float(face_texture.height) / 16.0
                    - float(face.light_t)
            );
        }
        bsp.faces.append(face);
    }
    mark_count = records(lumps[11], mark_size);
    for i in range(records(lumps[10], leaf_size)) {
        p = i * leaf_size;
        # dleaf_t, or dleaf2_t with float bounds and 32-bit mark ranges.
        ambient_at = p + (40 if wide else 24);
        leaf = Leaf(
            contents=i32_at(lumps[10], p),
            vis_offset=i32_at(lumps[10], p + 4),
            mins=vec_at(lumps[10], p + 8) if wide else bounds_at(lumps[10], p + 8),
            maxs=vec_at(lumps[10], p + 20) if wide else bounds_at(lumps[10], p + 14),
            # ambient_level[4]: water, sky, slime, lava.
            ambient=[
                int(lumps[10][ambient_at]),
                int(lumps[10][ambient_at + 1]),
                int(lumps[10][ambient_at + 2]),
                int(lumps[10][ambient_at + 3])
            ]
        );
        first = i32_at(lumps[10], p + 32) if wide else u16_at(lumps[10], p + 20);
        count = i32_at(lumps[10], p + 36) if wide else u16_at(lumps[10], p + 22);
        if first < 0 or count < 0 or first + count > mark_count {
            raise ValueError("Invalid BSP leaf face range");
        }
        for j in range(count) {
            fi = i32_at(lumps[11], (first + j) * 4)
                if wide
                else u16_at(lumps[11], (first + j) * 2);
            check_index(fi, len(bsp.faces));
            leaf.faces.append(fi);
        }
        # Standalone brush assets can contain a zero offset with no VIS lump.
        # There is no visibility stream to address; expose all leaves instead.
        if not bsp.visibility and leaf.vis_offset == 0 { leaf.vis_offset = -1; }
        if leaf.vis_offset < -1
            or leaf.vis_offset >= len(bsp.visibility)
            and leaf.vis_offset != -1 {
            raise ValueError("Invalid BSP visibility offset");
        }
        bsp.leaves.append(leaf);
    }
    node_count = records(lumps[5], node_size);
    for i in range(node_count) {
        p = i * node_size;
        plane = i32_at(lumps[5], p);
        check_index(plane, len(bsp.planes));
        # dnode_t firstface and numfaces: the faces on this node's plane.
        first = i32_at(lumps[5], p + 36) if wide else u16_at(lumps[5], p + 20);
        count = i32_at(lumps[5], p + 40) if wide else u16_at(lumps[5], p + 22);
        if first < 0 or count < 0 or first + count > len(bsp.faces) {
            raise ValueError("Invalid BSP node face range");
        }
        bsp.branches.append(
            Branch(
                plane=plane,
                front=i32_at(lumps[5], p + 4) if wide else bsp29_child(lumps[5], p + 4, node_count),
                back=i32_at(lumps[5], p + 8) if wide else bsp29_child(lumps[5], p + 6, node_count),
                first_face=first,
                face_count=count
            )
        );
    }
    for b in bsp.branches {
        for child in [b.front, b.back] {
            if child < 0 {
                check_index(-child - 1, len(bsp.leaves));
            } else {
                check_index(child, len(bsp.branches));
            }
        }
    }
    clip_count = records(lumps[9], clip_size);
    for i in range(clip_count) {
        p = i * clip_size;
        plane = i32_at(lumps[9], p);
        check_index(plane, len(bsp.planes));
        bsp.clipnodes.append(
            Branch(
                plane=plane,
                front=i32_at(lumps[9], p + 4) if wide else bsp29_child(lumps[9], p + 4, clip_count),
                back=i32_at(lumps[9], p + 8) if wide else bsp29_child(lumps[9], p + 6, clip_count)
            )
        );
    }
    for clip in bsp.clipnodes {
        for child in [clip.front, clip.back] {
            if child >= 0 {
                check_index(child, len(bsp.clipnodes));
            } elif child < -6 {
                raise ValueError("Invalid Q1 collision contents");
            }
        }
    }
    for i in range(records(lumps[14], 64)) {
        p = i * 64;
        head = i32_at(lumps[14], p + 36);
        check_index(head, len(bsp.branches));
        player_hull = i32_at(lumps[14], p + 40);
        if player_hull >= 0 {
            check_index(player_hull, len(bsp.clipnodes));
        } elif player_hull < -6 {
            raise ValueError("Invalid Q1 player hull");
        }
        # Hull 2: the 64x64x88 box of shamblers, ogres and fiends.
        large_hull = i32_at(lumps[14], p + 44);
        if large_hull >= 0 {
            check_index(large_hull, len(bsp.clipnodes));
        } elif large_hull < -6 {
            raise ValueError("Invalid Q1 large hull");
        }
        first = i32_at(lumps[14], p + 56);
        count = i32_at(lumps[14], p + 60);
        if first < 0 or count < 0 or first + count > len(bsp.faces) {
            raise ValueError("Invalid BSP model faces");
        }
        vis_count = i32_at(lumps[14], p + 52);
        if vis_count < 0 or vis_count >= len(bsp.leaves) {
            raise ValueError("Invalid BSP model visibility leaf count");
        }
        bsp.models.append(
            Model(
                mins=vec_at(lumps[14], p),
                maxs=vec_at(lumps[14], p + 12),
                head=head,
                player_hull=player_hull,
                large_hull=large_hull,
                first_face=first,
                face_count=count,
                vis_leaf_count=vis_count
            )
        );
    }
    if not bsp.models or not bsp.leaves {
        raise ValueError("BSP has no world model");
    }
    return bsp;
}
