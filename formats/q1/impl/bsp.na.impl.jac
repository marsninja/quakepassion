"""Implementations for the BSP29 parser. Declarations live in bsp.na.jac.

Lump indices and record sizes (BSP29, all little-endian):
  0 entities(text)  1 planes(20)   3 vertices(12)  4 visibility(raw)
  5 nodes(24)       7 faces(20)    10 leafs(28)    11 marksurfaces(2)
  12 edges(4)       13 surfedges(4) 14 models(64)
(2 textures, 6 texinfo, 8 lighting, 9 clipnodes are skipped this phase.)"""

glob BSP_VERSION: int = 29,
     LUMP_COUNT: int = 15,
     L_ENTITIES: int = 0,
     L_PLANES: int = 1,
     L_VERTICES: int = 3,
     L_VISIBILITY: int = 4,
     L_NODES: int = 5,
     L_FACES: int = 7,
     L_LEAFS: int = 10,
     L_MARKSURFACES: int = 11,
     L_EDGES: int = 12,
     L_SURFEDGES: int = 13,
     L_MODELS: int = 14;


impl Bsp.face_verts(face_idx: int) -> list[Vec3] {
    f = self.faces[face_idx];
    out: list[Vec3] = [];
    i = 0;
    while i < f.num_edges {
        se = self.surfedges[f.first_edge + i];
        if se >= 0 {
            out.append(self.vertices[self.edges[se].v0]);
        } else {
            out.append(self.vertices[self.edges[-se].v1]);
        }
        i += 1;
    }
    return out;
}


impl parse_bsp(data: bytes) -> Bsp | None {
    r = ByteReader(data=data);
    version = r.i32();
    if version != BSP_VERSION {
        return None;
    }

    lumps: list[BspLump] = [];
    n = 0;
    while n < LUMP_COUNT {
        lumps.append(BspLump(offset=r.i32(), length=r.i32()));
        n += 1;
    }

    bsp = Bsp(version=version);

    # entities (text, up to first NUL)
    el = lumps[L_ENTITIES];
    bsp.entities = ByteReader(data=r.at(el.offset, el.length)).cstr(el.length);

    # planes: normal(3f) dist(f) type(i)  — 20 bytes
    pl = lumps[L_PLANES];
    pr = ByteReader(data=r.at(pl.offset, pl.length));
    i = 0;
    while i < pl.length // 20 {
        bsp.planes.append(Plane(
            normal=Vec3(x=pr.f32(), y=pr.f32(), z=pr.f32()),
            dist=pr.f32(),
            ptype=pr.i32()
        ));
        i += 1;
    }

    # vertices: 3f — 12 bytes
    vl = lumps[L_VERTICES];
    vr = ByteReader(data=r.at(vl.offset, vl.length));
    i = 0;
    while i < vl.length // 12 {
        bsp.vertices.append(Vec3(x=vr.f32(), y=vr.f32(), z=vr.f32()));
        i += 1;
    }

    # edges: 2x u16 — 4 bytes
    egl = lumps[L_EDGES];
    egr = ByteReader(data=r.at(egl.offset, egl.length));
    i = 0;
    while i < egl.length // 4 {
        bsp.edges.append(BspEdge(v0=egr.u16(), v1=egr.u16()));
        i += 1;
    }

    # surfedges: i32 (signed) — 4 bytes
    sl = lumps[L_SURFEDGES];
    sr = ByteReader(data=r.at(sl.offset, sl.length));
    i = 0;
    while i < sl.length // 4 {
        bsp.surfedges.append(sr.i32());
        i += 1;
    }

    # faces: plane(u16) side(u16) firstedge(i32) numedges(u16) texinfo(u16)
    #        styles(4u8) lightofs(i32) — 20 bytes
    fl = lumps[L_FACES];
    fr = ByteReader(data=r.at(fl.offset, fl.length));
    i = 0;
    while i < fl.length // 20 {
        plane_id = fr.u16();
        side = fr.u16();
        first_edge = fr.i32();
        num_edges = fr.u16();
        texinfo_id = fr.u16();
        styles = [fr.u8(), fr.u8(), fr.u8(), fr.u8()];
        lightmap_ofs = fr.i32();
        bsp.faces.append(Face(
            plane_id=plane_id, side=side, first_edge=first_edge,
            num_edges=num_edges, texinfo_id=texinfo_id,
            styles=styles, lightmap_ofs=lightmap_ofs
        ));
        i += 1;
    }

    # nodes: plane(i32) children(2i16) mins(3i16) maxs(3i16)
    #        firstface(u16) numfaces(u16) — 24 bytes
    nl = lumps[L_NODES];
    nr = ByteReader(data=r.at(nl.offset, nl.length));
    i = 0;
    while i < nl.length // 24 {
        plane_id = nr.i32();
        front = nr.i16();
        back = nr.i16();
        nmins = [nr.i16(), nr.i16(), nr.i16()];
        nmaxs = [nr.i16(), nr.i16(), nr.i16()];
        first_face = nr.u16();
        num_faces = nr.u16();
        bsp.nodes.append(BspNode(
            plane_id=plane_id, front=front, back=back,
            mins=nmins, maxs=nmaxs, first_face=first_face, num_faces=num_faces
        ));
        i += 1;
    }

    # leafs: contents(i32) visofs(i32) mins(3i16) maxs(3i16)
    #        firstmark(u16) nummark(u16) ambient(4u8) — 28 bytes
    ll = lumps[L_LEAFS];
    lr = ByteReader(data=r.at(ll.offset, ll.length));
    i = 0;
    while i < ll.length // 28 {
        contents = lr.i32();
        vis_ofs = lr.i32();
        lmins = [lr.i16(), lr.i16(), lr.i16()];
        lmaxs = [lr.i16(), lr.i16(), lr.i16()];
        first_marksurface = lr.u16();
        num_marksurfaces = lr.u16();
        ambient = [lr.u8(), lr.u8(), lr.u8(), lr.u8()];
        bsp.leafs.append(Leaf(
            contents=contents, vis_ofs=vis_ofs, mins=lmins, maxs=lmaxs,
            first_marksurface=first_marksurface,
            num_marksurfaces=num_marksurfaces, ambient=ambient
        ));
        i += 1;
    }

    # marksurfaces: u16 — 2 bytes
    ml = lumps[L_MARKSURFACES];
    mr = ByteReader(data=r.at(ml.offset, ml.length));
    i = 0;
    while i < ml.length // 2 {
        bsp.marksurfaces.append(mr.u16());
        i += 1;
    }

    # models: mins(3f) maxs(3f) origin(3f) headnodes(4i) visleafs(i)
    #         firstface(i) numfaces(i) — 64 bytes
    dl = lumps[L_MODELS];
    dr = ByteReader(data=r.at(dl.offset, dl.length));
    i = 0;
    while i < dl.length // 64 {
        dmins = Vec3(x=dr.f32(), y=dr.f32(), z=dr.f32());
        dmaxs = Vec3(x=dr.f32(), y=dr.f32(), z=dr.f32());
        origin = Vec3(x=dr.f32(), y=dr.f32(), z=dr.f32());
        headnodes = [dr.i32(), dr.i32(), dr.i32(), dr.i32()];
        visleafs = dr.i32();
        first_face = dr.i32();
        num_faces = dr.i32();
        bsp.models.append(BspModel(
            mins=dmins, maxs=dmaxs, origin=origin, headnodes=headnodes,
            visleafs=visleafs, first_face=first_face, num_faces=num_faces
        ));
        i += 1;
    }

    # visibility: raw RLE PVS bytes (decoded per-leaf in pvs.na.jac)
    vsl = lumps[L_VISIBILITY];
    bsp.visdata = r.at(vsl.offset, vsl.length);

    return bsp;
}
