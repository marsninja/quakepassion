"""BSP29 parser — the Quake 1 map format (Phase 2).

A BSP file is a 4-byte version (29) followed by a 15-entry lump directory
(offset+length pairs); each lump is a flat array of fixed-size records. We
parse the geometry and tree lumps the engine needs now — planes, vertices,
edges, surfedges, faces, nodes, leafs, marksurfaces, models — plus the raw
visibility (PVS) bytes and the entity text (consumed in later phases).
Textures, texinfo, lighting and clipnodes are skipped for Phase 2.

Coordinate convention is decided here, once: Quake is z-up, and so is this
engine (the camera's up is +Z), so vertices/planes/bounds are read straight
through with no swizzle — the format boundary is a pass-through.

Pure data code over a ByteReader — no OSP, no raylib. Bodies live in
impl/bsp.na.impl.jac."""

import from ..common.bytes { ByteReader }
import from engine.math.vec3 { Vec3 }


"""One lump directory entry: where a lump's bytes live in the file."""
obj BspLump {
    has offset: int,
        length: int;
}

"""A splitting plane. `ptype` is Quake's axis hint (0..5); the normal is what
matters for flat shading."""
obj Plane {
    has normal: Vec3,
        dist: float,
        ptype: int;
}

"""An edge is an unordered pair of vertex indices; faces walk edges via
surfedges, whose sign picks the winding direction."""
obj BspEdge {
    has v0: int,
        v1: int;
}

"""A polygon: a run of `num_edges` surfedges starting at `first_edge`, on
plane `plane_id` (flipped when `side` is set). texinfo/lightmap deferred."""
obj Face {
    has plane_id: int,
        side: int,
        first_edge: int,
        num_edges: int,
        texinfo_id: int,
        styles: list[int],
        lightmap_ofs: int;
}

"""A BSP tree node. `front`/`back` are child links: >=0 is a node index,
<0 encodes leaf index `-(child) - 1`."""
obj BspNode {
    has plane_id: int,
        front: int,
        back: int,
        mins: list[int],
        maxs: list[int],
        first_face: int,
        num_faces: int;
}

"""A convex leaf of the tree. `contents` < -1 is solid; `vis_ofs` indexes the
RLE PVS in visdata (-1 = no vis). marksurfaces list the leaf's faces."""
obj Leaf {
    has contents: int,
        vis_ofs: int,
        mins: list[int],
        maxs: list[int],
        first_marksurface: int,
        num_marksurfaces: int,
        ambient: list[int];
}

"""A submodel (worldspawn is model 0; doors/plats are later models)."""
obj BspModel {
    has mins: Vec3,
        maxs: Vec3,
        origin: Vec3,
        headnodes: list[int],
        visleafs: int,
        first_face: int,
        num_faces: int;
}


"""A fully parsed BSP29 map."""
obj Bsp {
    has version: int = 0,
        planes: list[Plane] = [],
        vertices: list[Vec3] = [],
        edges: list[BspEdge] = [],
        surfedges: list[int] = [],
        faces: list[Face] = [],
        nodes: list[BspNode] = [],
        leafs: list[Leaf] = [],
        marksurfaces: list[int] = [],
        models: list[BspModel] = [],
        visdata: bytes = b"",
        entities: str = "";

    """Resolve a face into its polygon: the world-space vertices in winding
    order, walking first_edge/num_edges through surfedges and edges (a
    negative surfedge traverses its edge backwards)."""
    def face_verts(face_idx: int) -> list[Vec3];
}


"""Parse a BSP29 map from its raw bytes. Returns None if the version isn't 29."""
def parse_bsp(data: bytes) -> Bsp | None;
