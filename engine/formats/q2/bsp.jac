"""Quake II BSP38 and WAL decoding."""
import math;
import from ..bsp {
    Brush,
    Bsp,
    Texture,
    TexInfo,
    Face,
    Plane,
    Branch,
    Leaf,
    Model,
    require_range,
    i32_at,
    u16_at,
    s16_at,
    f32_at,
    vec_at,
    bounds_at,
    records,
    check_index,
    parse_entities
}
import from ...math.vec3 { Vec3 }

def texture_names(data: bytes) -> list[str] {
    require_range(data, 0, 160);
    if data[0:4] != b"IBSP" or i32_at(data, 4) != 38 {
        raise ValueError("Expected Quake 2 BSP version 38");
    }
    offset = i32_at(data, 48);
    size = i32_at(data, 52);
    require_range(data, offset, size);
    result: list[str] = [];
    for i in range(records(data[offset:offset + size], 76)) {
        p = offset + i * 76 + 40;
        end = p;
        while end < p + 32 and data[end] != 0 {
            end += 1;
        }
        result.append(data[p:end].decode("utf-8"));
    }
    return result;
}

def parse_wal(data: bytes, name: str) -> Texture {
    require_range(data, 0, 100);
    w = i32_at(data, 32);
    h = i32_at(data, 36);
    offset = i32_at(data, 40);
    if w <= 0 or h <= 0 or w > 4096 or h > 4096 or offset < 100 {
        raise ValueError("Invalid WAL dimensions or offset");
    }
    require_range(data, offset, w * h);
    return Texture(name=name, width=w, height=h, pixels=data[offset:offset + w * h]);
}

def parse_q2(data: bytes, textures: list[Texture]) -> Bsp {
    require_range(data, 0, 160);
    if data[0:4] != b"IBSP" or i32_at(data, 4) != 38 {
        raise ValueError("Expected Quake 2 BSP version 38");
    }
    lumps: list[bytes] = [];
    for i in range(19) {
        offset = i32_at(data, 8 + i * 8);
        size = i32_at(data, 12 + i * 8);
        require_range(data, offset, size);
        lumps.append(data[offset:offset + size]);
    }
    bsp = Bsp(game="q2", light_channels=3, lighting=lumps[7], visibility=lumps[3]);
    bsp.entities = parse_entities(lumps[0].decode("utf-8"));
    bsp.textures = textures;
    if len(bsp.visibility) > 0 {
        bsp.clusters = i32_at(bsp.visibility, 0);
        require_range(bsp.visibility, 4, bsp.clusters * 8);
    }
    for i in range(records(lumps[1], 20)) {
        bsp.planes.append(
            Plane(
                normal=vec_at(lumps[1], i * 20), distance=f32_at(lumps[1], i * 20 + 12)
            )
        );
    }
    vertices: list[Vec3] = [];
    for i in range(records(lumps[2], 12)) {
        vertices.append(vec_at(lumps[2], i * 12));
    }
    texinfo: list[TexInfo] = [];
    for i in range(records(lumps[5], 76)) {
        p = i * 76;
        texture = i;
        check_index(texture, len(bsp.textures));
        texinfo.append(
            TexInfo(
                s=vec_at(lumps[5], p),
                t=vec_at(lumps[5], p + 16),
                soff=f32_at(lumps[5], p + 12),
                toff=f32_at(lumps[5], p + 28),
                texture=texture,
                flags=i32_at(lumps[5], p + 32)
            )
        );
        # nexttexinfo chains animated textures (-1 ends the chain).
        following = i32_at(lumps[5], p + 72);
        if following > 0 and following * 76 < len(lumps[5]) {
            bsp.texture_next[i] = following;
        }
    }
    edge_count = records(lumps[11], 4);
    surf_count = records(lumps[12], 4);
    for i in range(records(lumps[6], 20)) {
        p = i * 20;
        plane = u16_at(lumps[6], p);
        check_index(plane, len(bsp.planes));
        side = u16_at(lumps[6], p + 2);
        first = i32_at(lumps[6], p + 4);
        count = u16_at(lumps[6], p + 8);
        ti = u16_at(lumps[6], p + 10);
        check_index(ti, len(texinfo));
        if count < 3 or first < 0 or first + count > surf_count {
            raise ValueError("Invalid BSP face edge range");
        }
        info = texinfo[ti];
        face_texture = bsp.textures[info.texture];
        # q_shared.h SURF_WARP (8), SURF_TRANS33 (16), SURF_TRANS66 (32) and
        # SURF_FLOWING (64).
        face = Face(
            texture=info.texture,
            warp=(info.flags & 8) != 0,
            flowing=(info.flags & 64) != 0,
            opacity=0.33 if (info.flags & 16) != 0 else (0.66 if (info.flags & 32) != 0 else 1.0),
            hidden=(info.flags & 132) != 0,
            light_offset=i32_at(lumps[6], p + 16),
            normal=bsp.planes[plane].normal,
            plane_dist=bsp.planes[plane].distance
        );
        if side != 0 {
            face.normal = face.normal.scale(-1.0);
            face.plane_dist = -face.plane_dist;
        }
        for j in range(4) {
            style = int(lumps[6][p + 12 + j]);
            if style != 255 {
                face.styles.append(style);
            }
        }
        min_s = 1.0e30;
        max_s = -1.0e30;
        min_t = 1.0e30;
        max_t = -1.0e30;
        for j in range(count) {
            se = i32_at(lumps[12], (first + j) * 4);
            ei = abs(se);
            check_index(ei, edge_count);
            ep = ei * 4;
            if se < 0 {
                ep += 2;
            }
            vi = u16_at(lumps[11], ep);
            check_index(vi, len(vertices));
            v = vertices[vi];
            face.vertices.append(v);
            s = v.dot(info.s) + info.soff;
            t = v.dot(info.t) + info.toff;
            face.uv.append(s / float(face_texture.width));
            face.uv.append(t / float(face_texture.height));
            min_s = min(min_s, s);
            max_s = max(max_s, s);
            min_t = min(min_t, t);
            max_t = max(max_t, t);
        }
        face.light_s = int(math.floor(min_s / 16.0));
        face.light_t = int(math.floor(min_t / 16.0));
        face.light_width = int(math.ceil(max_s / 16.0)) - face.light_s + 1;
        face.light_height = int(math.ceil(max_t / 16.0)) - face.light_t + 1;
        if face.light_offset >= 0 {
            require_range(
                bsp.lighting,
                face.light_offset,
                face.light_width * face.light_height * len(face.styles) * 3
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
    side_count = records(lumps[15], 4);
    for i in range(records(lumps[14], 12)) {
        first = i32_at(lumps[14], i * 12);
        count = i32_at(lumps[14], i * 12 + 4);
        if first < 0 or count < 0 or first + count > side_count {
            raise ValueError("Invalid Q2 brush sides");
        }
        brush = Brush(contents=i32_at(lumps[14], i * 12 + 8));
        for j in range(first, first + count) {
            plane = u16_at(lumps[15], j * 4);
            check_index(plane, len(bsp.planes));
            brush.planes.append(plane);
            # dbrushside_t texinfo is a signed short; bevels have none.
            side_texinfo = u16_at(lumps[15], j * 4 + 2);
            brush.side_flags.append(
                texinfo[side_texinfo].flags if side_texinfo < len(texinfo) else 0
            );
        }
        bsp.brushes.append(brush);
    }
    brush_marks = records(lumps[10], 2);
    mark_count = records(lumps[9], 2);
    for i in range(records(lumps[8], 28)) {
        p = i * 28;
        leaf = Leaf(
            contents=i32_at(lumps[8], p),
            vis_offset=-1,
            cluster=s16_at(lumps[8], p + 4),
            mins=bounds_at(lumps[8], p + 8),
            maxs=bounds_at(lumps[8], p + 14)
        );
        first = u16_at(lumps[8], p + 20);
        count = u16_at(lumps[8], p + 22);
        if first + count > mark_count {
            raise ValueError("Invalid BSP leaf face range");
        }
        for j in range(count) {
            fi = u16_at(lumps[9], (first + j) * 2);
            check_index(fi, len(bsp.faces));
            leaf.faces.append(fi);
        }
        if leaf.vis_offset < -1
            or leaf.vis_offset >= len(bsp.visibility)
            and leaf.vis_offset != -1 {
            raise ValueError("Invalid BSP visibility offset");
        }
        first_brush = u16_at(lumps[8], p + 24);
        count_brush = u16_at(lumps[8], p + 26);
        if first_brush + count_brush > brush_marks {
            raise ValueError("Invalid Q2 leaf brushes");
        }
        for j in range(first_brush, first_brush + count_brush) {
            index = u16_at(lumps[10], j * 2);
            check_index(index, len(bsp.brushes));
            leaf.brushes.append(index);
        }
        bsp.leaves.append(leaf);
    }
    for i in range(records(lumps[4], 28)) {
        p = i * 28;
        plane = i32_at(lumps[4], p);
        check_index(plane, len(bsp.planes));
        bsp.branches.append(
            Branch(
                plane=plane, front=i32_at(lumps[4], p + 4), back=i32_at(lumps[4], p + 8)
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
    for i in range(records(lumps[13], 48)) {
        p = i * 48;
        head = i32_at(lumps[13], p + 36);
        if head < 0 {
            check_index(-head - 1, len(bsp.leaves));
        } else {
            check_index(head, len(bsp.branches));
        }
        first = i32_at(lumps[13], p + 40);
        count = i32_at(lumps[13], p + 44);
        if first < 0 or count < 0 or first + count > len(bsp.faces) {
            raise ValueError("Invalid BSP model faces");
        }
        vis_count = len(bsp.leaves) - 1;
        if vis_count < 0 or vis_count >= len(bsp.leaves) {
            raise ValueError("Invalid BSP model visibility leaf count");
        }
        bsp.models.append(
            Model(
                mins=vec_at(lumps[13], p),
                maxs=vec_at(lumps[13], p + 12),
                head=head,
                first_face=first,
                face_count=count,
                vis_leaf_count=vis_count
            )
        );
    }
    if not bsp.models or not bsp.leaves {
        raise ValueError("BSP has no world model");
    }
    for model in bsp.models {
        pending = [model.head];
        visited: set[int] = set();
        brushes: set[int] = set();
        while pending {
            index = pending.pop();
            if index in visited {
                continue;
            }
            visited.add(index);
            if index < 0 {
                for brush in bsp.leaves[-index - 1].brushes {
                    brushes.add(brush);
                }
            } else {
                pending.append(bsp.branches[index].front);
                pending.append(bsp.branches[index].back);
            }
        }
        model.brushes = sorted(brushes);
    }
    return bsp;
}
