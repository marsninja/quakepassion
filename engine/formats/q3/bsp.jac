"""Quake III BSP46 surfaces, quadratic patches, and cluster visibility."""
import math;
import struct;
import from ..bsp {
    FogVolume,
    FlareSurface,
    Brush,
    Bsp,
    Texture,
    Face,
    Plane,
    Branch,
    Leaf,
    Model,
    require_range,
    i32_at,
    f32_at,
    vec_at,
    records,
    check_index,
    parse_entities
}
import from ...math.vec3 { Vec3 }
import from .curve {
    Vertex,
    CurveGrid,
    subdivide_patch,
    stitch_all_patches,
    fix_all_shared_lod_errors,
    CURVE_SUBDIVISIONS
}

"""A vertex's lightmap coordinate. q3map leaves the coordinates of surfaces
it gave no lightmap (vertex-lit terrain) unset, and some are not numbers:
they are never sampled, so they read as 0."""
def lightmap_coordinate(data: bytes, p: int) -> float {
    value = float(struct.unpack("<f", data[p:p + 4])[0]);
    return value if math.isfinite(value) else 0.0;
}

def add_vertex(face: Face, v: Vertex) {
    face.vertices.append(v.pos);
    face.uv.extend([v.s, v.t]);
    # Shared renderer addresses texel centers; Q3 UVs already address the whole tile.
    face.light_uv.extend([v.ls * 128.0 - 0.5, v.lt * 128.0 - 0.5]);
    for c in v.colors {
        face.colors.append(min(255, max(0, int(c))));
    }
}

"""A patch face's grid (tr_curve.c R_SubdividePatchToGrid at `subdivisions`,
r_subdivisions). The control grid itself is kept on the face for collision
(cm_patch.c)."""
def patch_grid(
    face: Face, controls: list[Vertex], width: int, height: int, subdivisions: float = CURVE_SUBDIVISIONS
) -> CurveGrid {
    if width < 3
        or height < 3
        or width % 2 != 1
        or height % 2 != 1
        or width * height != len(controls)
        or subdivisions <= 0.0 {
        raise ValueError("Invalid quadratic patch grid");
    }
    face.patch_width = width;
    face.patch_height = height;
    face.patch_points = [c.pos for c in controls];
    return subdivide_patch(width, height, controls, subdivisions);
}

"""Give a face its grid's vertices and their normals, row by row, two
triangles a cell, and what the renderer needs to thin the grid with distance."""
def emit_grid(face: Face, grid: CurveGrid) {
    for row in grid.rows {
        for v in row {
            add_vertex(face, v);
            face.normals.append(v.normal);
        }
    }
    face.grid_width = grid.width;
    face.grid_height = grid.height;
    face.width_errors = list(grid.width_errors);
    face.height_errors = list(grid.height_errors);
    face.lod_origin = grid.lod_origin;
    face.lod_radius = grid.lod_radius;
    for y in range(grid.height - 1) {
        for x in range(grid.width - 1) {
            a = y * grid.width + x;
            b = a + grid.width;
            face.indices.extend([a, a + 1, b, a + 1, b + 1, b]);
        }
    }
}

"""Tessellate one patch on its own (no neighbours to stitch to)."""
def tessellate(
    face: Face, controls: list[Vertex], width: int, height: int, subdivisions: float = CURVE_SUBDIVISIONS
) {
    emit_grid(face, patch_grid(face, controls, width, height, subdivisions));
}

def int_vec(data: bytes, p: int) -> Vec3 {
    return Vec3(
        x=float(i32_at(data, p)),
        y=float(i32_at(data, p + 4)),
        z=float(i32_at(data, p + 8))
    );
}

"""Read a Q3 BSP. `subdivisions` is r_subdivisions, the error its patches are
subdivided to."""
def parse_q3(data: bytes, subdivisions: float = CURVE_SUBDIVISIONS) -> Bsp {
    require_range(data, 0, 144);
    if data[0:4] != b"IBSP" or i32_at(data, 4) != 46 {
        raise ValueError("Expected Quake 3 BSP version 46");
    }
    lumps: list[bytes] = [];
    for i in range(17) {
        offset = i32_at(data, 8 + i * 8);
        size = i32_at(data, 12 + i * 8);
        require_range(data, offset, size);
        lumps.append(data[offset:offset + size]);
    }
    bsp = Bsp(game="q3", light_channels=3, lighting=lumps[14], visibility=lumps[16], light_grid=lumps[15]);
    bsp.entities = parse_entities(lumps[0].decode("utf-8"));
    light_count = records(bsp.lighting, 128 * 128 * 3);
    if len(bsp.visibility) > 0 {
        bsp.clusters = i32_at(bsp.visibility, 0);
        bsp.cluster_bytes = i32_at(bsp.visibility, 4);
        if bsp.clusters < 0 or bsp.cluster_bytes < (bsp.clusters + 7) // 8 {
            raise ValueError("Invalid Q3 visibility dimensions");
        }
        require_range(bsp.visibility, 8, bsp.clusters * bsp.cluster_bytes);
    }
    for i in range(records(lumps[1], 72)) {
        p = i * 72;
        end = p;
        while end < p + 64 and lumps[1][end] != 0 {
            end += 1;
        }
        bsp.textures.append(
            Texture(
                name=lumps[1][p:end].decode("utf-8"),
                flags=i32_at(lumps[1], p + 64),
                contents=i32_at(lumps[1], p + 68)
            )
        );
    }
    for i in range(records(lumps[2], 16)) {
        bsp.planes.append(
            Plane(
                normal=vec_at(lumps[2], i * 16), distance=f32_at(lumps[2], i * 16 + 12)
            )
        );
    }
    side_count = records(lumps[9], 8);
    for i in range(records(lumps[8], 12)) {
        first = i32_at(lumps[8], i * 12);
        count = i32_at(lumps[8], i * 12 + 4);
        texture = i32_at(lumps[8], i * 12 + 8);
        check_index(texture, len(bsp.textures));
        if first < 0 or count < 0 or first + count > side_count {
            raise ValueError("Invalid Q3 brush sides");
        }
        brush = Brush(contents=bsp.textures[texture].contents);
        for j in range(first, first + count) {
            plane = i32_at(lumps[9], j * 8);
            check_index(plane, len(bsp.planes));
            shader = i32_at(lumps[9], j * 8 + 4);
            check_index(shader, len(bsp.textures));
            brush.planes.append(plane);
            brush.side_flags.append(bsp.textures[shader].flags);
        }
        bsp.brushes.append(brush);
    }
    # dfog_t: shader name, brush and visible side. Fog brushes are axial, their
    # first six sides bounding -x, +x, -y, +y, -z, +z.
    for i in range(records(lumps[12], 72)) {
        p = i * 72;
        end = p;
        while end < p + 64 and lumps[12][end] != 0 {
            end += 1;
        }
        brush_index = i32_at(lumps[12], p + 64);
        side = i32_at(lumps[12], p + 68);
        check_index(brush_index, len(bsp.brushes));
        sides = bsp.brushes[brush_index].planes;
        if len(sides) < 6 {
            raise ValueError("Q3 fog brush needs six sides");
        }
        fog = FogVolume(
            shader=lumps[12][p:end].decode("utf-8"),
            mins=Vec3(
                x=-bsp.planes[sides[0]].distance,
                y=-bsp.planes[sides[2]].distance,
                z=-bsp.planes[sides[4]].distance
            ),
            maxs=Vec3(
                x=bsp.planes[sides[1]].distance,
                y=bsp.planes[sides[3]].distance,
                z=bsp.planes[sides[5]].distance
            )
        );
        if side >= 0 {
            check_index(side, len(sides));
            visible = bsp.planes[sides[side]];
            fog.has_surface = True;
            fog.inward = visible.normal.scale(-1.0);
            fog.offset = visible.distance;
        }
        bsp.fogs.append(fog);
    }
    verts: list[Vertex] = [];
    for i in range(records(lumps[10], 44)) {
        p = i * 44;
        v = Vertex(
            pos=vec_at(lumps[10], p),
            s=f32_at(lumps[10], p + 12),
            t=f32_at(lumps[10], p + 16),
            ls=lightmap_coordinate(lumps[10], p + 20),
            lt=lightmap_coordinate(lumps[10], p + 24)
        );
        for j in range(4) {
            v.colors.append(float(lumps[10][p + 40 + j]));
        }
        verts.append(v);
    }
    index_count = records(lumps[11], 4);
    # Patch faces and their grids, emitted once neighbours are stitched.
    patches: list[Face] = [];
    grids: list[CurveGrid] = [];
    for i in range(records(lumps[13], 104)) {
        p = i * 104;
        texture = i32_at(lumps[13], p);
        check_index(texture, len(bsp.textures));
        kind = i32_at(lumps[13], p + 8);
        first = i32_at(lumps[13], p + 12);
        count = i32_at(lumps[13], p + 16);
        first_index = i32_at(lumps[13], p + 20);
        count_index = i32_at(lumps[13], p + 24);
        if first < 0
            or count < 0
            or first + count > len(verts)
            or first_index < 0
            or count_index < 0
            or first_index + count_index > index_count
            or count_index % 3 != 0 {
            raise ValueError("Invalid Q3 surface ranges");
        }
        if kind < 1 or kind > 4 {
            raise ValueError("Invalid Q3 surface type");
        }
        face = Face(
            texture=texture,
            fog=i32_at(lumps[13], p + 4),
            planar=(kind == 1),
            patch=(kind == 2),
            # SURF_SKY (4) faces show the sky behind them; SURF_NODRAW (128)
            # nothing; flares (kind 4) have no geometry of their own.
            hidden=(kind == 4 or (bsp.textures[texture].flags & 132) != 0),
            normal=vec_at(lumps[13], p + 84)
        );
        light = i32_at(lumps[13], p + 28);
        if light >= 0 {
            check_index(light, light_count);
            face.light_offset = light * 128 * 128 * 3;
            face.light_width = 128;
            face.light_height = 128;
            face.styles = [0];
        }
        if kind == 4 {
            # dsurface_t lightmapOrigin, lightmapVecs[0] and lightmapVecs[2].
            bsp.flares.append(
                FlareSurface(face=i, origin=vec_at(lumps[13], p + 48), color=vec_at(lumps[13], p + 60), normal=face.normal)
            );
        }
        if kind == 2 {
            grid = patch_grid(
                face,
                verts[first:first + count],
                i32_at(lumps[13], p + 96),
                i32_at(lumps[13], p + 100),
                subdivisions
            );
            # tr_bsp.c ParseMesh: the LOD group's bounds, in lightmapVecs.
            low = vec_at(lumps[13], p + 60);
            grid.lod_origin = low.add(vec_at(lumps[13], p + 72)).scale(0.5);
            grid.lod_radius = low.sub(grid.lod_origin).length();
            patches.append(face);
            grids.append(grid);
        } elif kind != 4 {
            for j in range(first, first + count) {
                add_vertex(face, verts[j]);
            }
            for j in range(first_index, first_index + count_index, 3) {
                a = i32_at(lumps[11], j * 4);
                b = i32_at(lumps[11], (j + 1) * 4);
                c = i32_at(lumps[11], (j + 2) * 4);
                check_index(a, count);
                check_index(b, count);
                check_index(c, count);
                face.indices.extend([a, c, b]);
            }
        }
        if len(face.vertices) > 0 {
            face.plane_dist = face.normal.dot(face.vertices[0]);
        }
        # R_LoadSurfaces takes fogNum unchecked; some shipped maps (q3tourney6)
        # carry indices past their fog list, which means no fog.
        if face.fog < 0 or face.fog >= len(bsp.fogs) {
            face.fog = -1;
        }
        if kind == 4 {
            bsp.flares[-1].fog = face.fog;
        }
        bsp.faces.append(face);
    }
    # R_StitchAllPatches and R_FixSharedVertexLodError, then the grids
    # become the faces' vertices.
    stitch_all_patches(grids);
    fix_all_shared_lod_errors(grids);
    for k in range(len(patches)) {
        emit_grid(patches[k], grids[k]);
        patches[k].plane_dist = patches[k].normal.dot(patches[k].vertices[0]);
    }
    marks = records(lumps[5], 4);
    for i in range(records(lumps[4], 48)) {
        p = i * 48;
        leaf = Leaf(
            contents=0,
            vis_offset=-1,
            cluster=i32_at(lumps[4], p),
            # dleaf_t area: -1 in solid.
            area=i32_at(lumps[4], p + 4),
            mins=int_vec(lumps[4], p + 8),
            maxs=int_vec(lumps[4], p + 20)
        );
        if leaf.cluster < -1 or (bsp.clusters > 0 and leaf.cluster >= bsp.clusters) {
            raise ValueError("Invalid Q3 leaf cluster");
        }
        first = i32_at(lumps[4], p + 32);
        count = i32_at(lumps[4], p + 36);
        if first < 0 or count < 0 or first + count > marks {
            raise ValueError("Invalid Q3 leaf faces");
        }
        for j in range(first, first + count) {
            face_index = i32_at(lumps[5], j * 4);
            check_index(face_index, len(bsp.faces));
            leaf.faces.append(face_index);
        }
        bsp.leaves.append(leaf);
    }
    for i in range(records(lumps[3], 36)) {
        p = i * 36;
        plane = i32_at(lumps[3], p);
        check_index(plane, len(bsp.planes));
        bsp.branches.append(
            Branch(
                plane=plane, front=i32_at(lumps[3], p + 4), back=i32_at(lumps[3], p + 8)
            )
        );
    }
    for branch in bsp.branches {
        for child in [branch.front, branch.back] {
            if child < 0 {
                check_index(-child - 1, len(bsp.leaves));
            } else {
                check_index(child, len(bsp.branches));
            }
        }
    }
    for i in range(records(lumps[7], 40)) {
        first = i32_at(lumps[7], i * 40 + 24);
        count = i32_at(lumps[7], i * 40 + 28);
        if first < 0 or count < 0 or first + count > len(bsp.faces) {
            raise ValueError("Invalid Q3 model faces");
        }
        first_brush = i32_at(lumps[7], i * 40 + 32);
        count_brush = i32_at(lumps[7], i * 40 + 36);
        if first_brush < 0
            or count_brush < 0
            or first_brush + count_brush > len(bsp.brushes) {
            raise ValueError("Invalid Q3 model brushes");
        }
        brushes = list(range(first_brush, first_brush + count_brush));
        bsp.models.append(
            Model(
                head=0,
                first_face=first,
                face_count=count,
                vis_leaf_count=len(bsp.leaves) - 1,
                mins=vec_at(lumps[7], i * 40),
                maxs=vec_at(lumps[7], i * 40 + 12),
                brushes=brushes
            )
        );
    }
    if not bsp.models or not bsp.leaves or not bsp.branches {
        raise ValueError("Q3 BSP has no world");
    }
    return bsp;
}
