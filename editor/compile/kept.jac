"""What a bake added to a compiled level, kept apart from the level. A level
is compiled afresh every time it is loaded, since a game played in it
writes on it; its light and its cells take far longer than the compiling
does, and are the same whenever the scene is. Kept under a mark of what the
level was built of, they are given to a level compiled from the same thing
again in place of being worked out again."""
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Bsp, Leaf, Branch, Plane, AreaLink }
import from .live { LiveLevel }
import from .bake { VisReport }

obj KeptBake {
    has mark: str = "",
        # What the level must still measure for these to fit it.
        face_count: int = 0,
        plane_base: int = 0,
        # Light: each face's lightmap size and place, where its corners lie
        # in it, and the colours of the corners of what moves.
        lit_samples: int = 0,
        lighting: bytes = b"",
        light_places: list[int] = [],
        light_uvs: list[list[float]] = [],
        colors: list[list[int]] = [],
        # Each face's light styles, the grid for models, and what the light
        # bake said of itself.
        light_styles: list[list[int]] = [],
        light_grid: bytes = b"",
        light_notes: str = "",
        warnings: list[str] = [],
        # Cells: the planes that cut the plan, the branches, each cell's
        # box and faces, and the rows of what sees what.
        vis: VisReport = VisReport(),
        cut_planes: list[float] = [],
        cut_branches: list[int] = [],
        cell_boxes: list[float] = [],
        cell_faces: list[list[int]] = [],
        clusters: int = 0,
        cluster_bytes: int = 0,
        visibility: bytes = b"",
        head: int = -1,
        vis_leaf_count: int = 0,
        # A bake by planes: each leaf's contents, cluster and area, the
        # areas' portals, and the outlines of the leaves and portals.
        leaf_marks: list[int] = [],
        areas: list[list[AreaLink]] = [],
        shapes: list[list[list[Vec3]]] = [],
        portals: list[list[Vec3]] = [],
        portal_ends: list[int] = [];
}

"""Take from a level just baked what the bake gave it. `plane_base` and
`warned` are how many planes and warnings it had when only compiled."""
def keep_bake(
    made: LiveLevel, mark: str, plane_base: int, warned: int, lit_samples: int, vis: VisReport
) -> KeptBake {
    bsp = made.bsp;
    kept = KeptBake(mark=mark, face_count=len(bsp.faces), plane_base=plane_base, lit_samples=lit_samples, vis=vis);
    kept.warnings = list(made.warnings[warned:]);
    if lit_samples > 0 {
        kept.lighting = bsp.lighting;
        kept.light_grid = bsp.light_grid;
        kept.light_notes = made.light_notes;
        for face in bsp.faces {
            kept.light_styles.append(list(face.styles));
            kept.light_places.extend([face.light_width, face.light_height, face.light_offset]);
            kept.light_uvs.append(list(face.light_uv));
            kept.colors.append(list(face.colors));
        }
    }
    if len(bsp.models) > 0 and bsp.models[0].head >= 0 {
        for plane in bsp.planes[plane_base:] {
            kept.cut_planes.extend([plane.normal.x, plane.normal.y, plane.normal.z, plane.distance]);
        }
        for branch in bsp.branches {
            kept.cut_branches.extend([branch.plane, branch.front, branch.back]);
        }
        for leaf in bsp.leaves {
            kept.cell_boxes.extend([leaf.mins.x, leaf.mins.y, leaf.mins.z, leaf.maxs.x, leaf.maxs.y, leaf.maxs.z]);
            kept.cell_faces.append(list(leaf.faces));
            kept.leaf_marks.extend([leaf.contents, leaf.cluster, leaf.area]);
        }
        kept.areas = bsp.areas;
        kept.shapes = made.shapes;
        kept.portals = made.portals;
        kept.portal_ends = made.portal_ends;
        kept.clusters = bsp.clusters;
        kept.cluster_bytes = bsp.cluster_bytes;
        kept.visibility = bsp.visibility;
        kept.head = bsp.models[0].head;
        kept.vis_leaf_count = bsp.models[0].vis_leaf_count;
    }
    return kept;
}

"""Give a level only compiled the light and cells kept from one built of the
same thing. False, with the level untouched, when they do not fit it."""
def give_bake(made: LiveLevel, kept: KeptBake) -> bool {
    bsp = made.bsp;
    if len(bsp.faces) != kept.face_count or len(bsp.planes) != kept.plane_base or len(bsp.models) == 0 {
        return False;
    }
    for warning in kept.warnings {
        made.warnings.append(warning);
    }
    if kept.lit_samples > 0 {
        world = bsp.models[0];
        last = world.first_face + world.face_count;
        for (index, face) in enumerate(bsp.faces) {
            if index >= world.first_face and index < last {
                face.light_width = kept.light_places[index * 3];
                face.light_height = kept.light_places[index * 3 + 1];
                face.light_offset = kept.light_places[index * 3 + 2];
                face.styles = list(kept.light_styles[index]) if index < len(kept.light_styles) else [0];
                face.light_uv = list(kept.light_uvs[index]);
            }
            face.colors = list(kept.colors[index]);
        }
        bsp.lighting = kept.lighting;
        bsp.light_channels = 3;
        bsp.light_grid = kept.light_grid;
        made.light_notes = kept.light_notes;
    }
    if kept.head >= 0 {
        for index in range(len(kept.cut_planes) // 4) {
            bsp.planes.append(
                Plane(
                    normal=Vec3(x=kept.cut_planes[index * 4], y=kept.cut_planes[index * 4 + 1], z=kept.cut_planes[index * 4 + 2]),
                    distance=kept.cut_planes[index * 4 + 3]
                )
            );
        }
        bsp.branches = [];
        for index in range(len(kept.cut_branches) // 3) {
            bsp.branches.append(
                Branch(
                    plane=kept.cut_branches[index * 3], front=kept.cut_branches[index * 3 + 1], back=kept.cut_branches[index * 3 + 2]
                )
            );
        }
        bsp.leaves = [];
        for index in range(len(kept.cell_faces)) {
            at = index * 6;
            bsp.leaves.append(
                Leaf(
                    contents=kept.leaf_marks[index * 3],
                    vis_offset=0,
                    mins=Vec3(x=kept.cell_boxes[at], y=kept.cell_boxes[at + 1], z=kept.cell_boxes[at + 2]),
                    maxs=Vec3(x=kept.cell_boxes[at + 3], y=kept.cell_boxes[at + 4], z=kept.cell_boxes[at + 5]),
                    cluster=kept.leaf_marks[index * 3 + 1],
                    area=kept.leaf_marks[index * 3 + 2],
                    faces=list(kept.cell_faces[index])
                )
            );
        }
        bsp.areas = [list(links) for links in kept.areas];
        if kept.areas {
            # The area portals numbered as the bake numbered them.
            number = 0;
            for entity in bsp.entities {
                if entity.fields.get("classname", "") == "func_areaportal" {
                    number += 1;
                    entity.fields["style"] = str(number);
                }
            }
        }
        made.shapes = kept.shapes;
        made.portals = kept.portals;
        made.portal_ends = kept.portal_ends;
        bsp.clusters = kept.clusters;
        bsp.cluster_bytes = kept.cluster_bytes;
        bsp.visibility = kept.visibility;
        bsp.models[0].head = kept.head;
        bsp.models[0].vis_leaf_count = kept.vis_leaf_count;
    }
    return True;
}
