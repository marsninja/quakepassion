"""Quake III curved-surface collision geometry (cm_patch.c).

A patch's control grid is subdivided for collision on its own terms, never
from the rendered tessellation (CM_GeneratePatchCollide): columns and rows are
split until every approximating point is within SUBDIVIDE_DISTANCE of the true
curve, identical columns are dropped, and each grid cell becomes one facet
(a flat quad) or two (triangles). A facet is its surface plane plus border
planes around its edges, axial and edge bevels (CM_AddFacetBevels) and the
flipped surface plane that closes its back. CollisionMap.add_patch turns the
facets into hull cells and the sweep in collision.jac traces them
(CM_TraceThroughPatchCollide).

Pure geometry, like the vector math: no graph here on purpose."""
import math;
import from ..math.vec3 { Vec3 }

"""A patch plane (patchPlane_t): the points p with normal.p == dist."""
obj PatchPlane {
    has normal: Vec3,
        dist: float;
}

"""One facet (facet_t): `surface` and each of `borders` index the patch's
plane list. A border faces away from the facet unless `inward`, in which case
the facet uses it flipped. `mins`/`maxs` bound the facet's winding (the axial
bevels), or are empty when it had none."""
obj PatchFacet {
    has surface: int = -1,
        borders: list[int] = [],
        inward: list[bool] = [],
        mins: Vec3 = Vec3(),
        maxs: Vec3 = Vec3(),
        bounded: bool = False;

    """The facet's planes as (normal, dist) facing out of it: the surface plane
    first, then each border, flipped where inward. The last is the flipped
    surface plane closing the back (CM_AddFacetBevels' opposite plane)."""
    def outward(planes: list[PatchPlane]) -> list[PatchPlane] {
        faces = [planes[self.surface]];
        for k in range(len(self.borders)) {
            plane = planes[self.borders[k]];
            if self.inward[k] {
                faces.append(PatchPlane(normal=plane.normal.scale(-1.0), dist=-plane.dist));
            } else {
                faces.append(plane);
            }
        }
        return faces;
    }
}

"""cGrid_t: points[column][row] exactly on the curve once subdivided."""
obj PatchGrid {
    has points: list[list[Vec3]] = [],
        wrap_width: bool = False,
        wrap_height: bool = False;

    def width() -> int {
        return len(self.points);
    }

    def height() -> int {
        return len(self.points[0]) if self.points else 0;
    }

    """CM_SetGridWrapWidth: the left and right columns meet (a closed tube)."""
    def set_wrap_width() {
        last = self.points[self.width() - 1];
        first = self.points[0];
        for j in range(self.height()) {
            if abs(first[j].x - last[j].x) > 0.1
                or abs(first[j].y - last[j].y) > 0.1
                or abs(first[j].z - last[j].z) > 0.1 {
                self.wrap_width = False;
                return;
            }
        }
        self.wrap_width = True;
    }

    """CM_SubdivideGridColumns: collapse each approximating column that lies
    within SUBDIVIDE_DISTANCE of its linear midpoints, else split its curve
    segment in two, until all of them are close enough."""
    def subdivide_columns() {
        i = 0;
        while i < self.width() - 2 {
            # Columns i and i + 2 interpolate the curve; i + 1 approximates it.
            flat = True;
            for j in range(self.height()) {
                if patch_needs_subdivision(
                    self.points[i][j], self.points[i + 1][j], self.points[i + 2][j]
                ) {
                    flat = False;
                    break;
                }
            }
            if flat {
                self.points = self.points[:i + 1] + self.points[i + 2:];
                i += 1;
                continue;
            }
            near: list[Vec3] = [];
            middle: list[Vec3] = [];
            far: list[Vec3] = [];
            for j in range(self.height()) {
                a = self.points[i][j];
                b = self.points[i + 1][j];
                c = self.points[i + 2][j];
                # CM_Subdivide: a, out1, out2, out3, c
                out1 = a.add(b).scale(0.5);
                out3 = b.add(c).scale(0.5);
                near.append(out1);
                middle.append(out1.add(out3).scale(0.5));
                far.append(out3);
            }
            # The new approximating column i + 1 may collapse or split again.
            self.points = self.points[:i + 1] + [near, middle, far] + self.points[i + 2:];
        }
    }

    """CM_RemoveDegenerateColumns: drop a column equal to the next one."""
    def remove_degenerate_columns() {
        i = 0;
        while i < self.width() - 1 {
            same = True;
            for j in range(self.height()) {
                if not patch_points_match(self.points[i][j], self.points[i + 1][j]) {
                    same = False;
                    break;
                }
            }
            if same {
                self.points = self.points[:i + 1] + self.points[i + 2:];
            } else {
                i += 1;
            }
        }
    }

    """CM_TransposeGrid: swap rows and columns (and their wrap flags)."""
    def transpose() {
        rows: list[list[Vec3]] = [];
        for j in range(self.height()) {
            rows.append([column[j] for column in self.points]);
        }
        self.points = rows;
        wrap = self.wrap_width;
        self.wrap_width = self.wrap_height;
        self.wrap_height = wrap;
    }
}

"""CM_NeedsSubdivision: the quadratic curve a, b, c bows at least
SUBDIVIDE_DISTANCE (16) from its chord's midpoint."""
def patch_needs_subdivision(a: Vec3, b: Vec3, c: Vec3) -> bool {
    chord = a.add(c).scale(0.5);
    curve = a.add(b).scale(0.5).add(b.add(c).scale(0.5)).scale(0.5);
    return curve.sub(chord).length() >= 16.0;
}

"""CM_ComparePoints: equal within POINT_EPSILON on every axis."""
def patch_points_match(a: Vec3, b: Vec3) -> bool {
    return abs(a.x - b.x) <= 0.1 and abs(a.y - b.y) <= 0.1 and abs(a.z - b.z) <= 0.1;
}

"""CM_PlaneEqual: 1 if `plane` matches `normal`/`dist`, -1 if it matches them
flipped, 0 otherwise (NORMAL_EPSILON 0.0001, DIST_EPSILON 0.02)."""
def patch_plane_match(plane: PatchPlane, normal: Vec3, dist: float) -> int {
    if abs(plane.normal.x - normal.x) < 0.0001
        and abs(plane.normal.y - normal.y) < 0.0001
        and abs(plane.normal.z - normal.z) < 0.0001
        and abs(plane.dist - dist) < 0.02 {
        return 1;
    }
    if abs(plane.normal.x + normal.x) < 0.0001
        and abs(plane.normal.y + normal.y) < 0.0001
        and abs(plane.normal.z + normal.z) < 0.0001
        and abs(plane.dist + dist) < 0.02 {
        return -1;
    }
    return 0;
}

"""A point's side of a plane beyond `epsilon`: 1 front, -1 back, 0 on."""
def:priv side_of(point: Vec3, plane: PatchPlane, epsilon: float) -> int {
    d = point.dot(plane.normal) - plane.dist;
    if d > epsilon {
        return 1;
    }
    if d < -epsilon {
        return -1;
    }
    return 0;
}

"""BaseWindingForPlane: a MAX_MAP_BOUNDS square on the plane."""
def:priv base_winding(plane: PatchPlane) -> list[Vec3] {
    normal = plane.normal;
    axis = 0;
    best = -65535.0;
    for i in range(3) {
        v = abs(normal.x if i == 0 else (normal.y if i == 1 else normal.z));
        if v > best {
            axis = i;
            best = v;
        }
    }
    up = Vec3(z=1.0) if axis < 2 else Vec3(x=1.0);
    up = up.sub(normal.scale(up.dot(normal))).normalized();
    origin = normal.scale(plane.dist);
    right = up.cross(normal).scale(65535.0);
    up = up.scale(65535.0);
    return [
        origin.sub(right).add(up),
        origin.add(right).add(up),
        origin.add(right).sub(up),
        origin.sub(right).sub(up)
    ];
}

"""ChopWindingInPlace: the part of `points` in front of the plane, within
`epsilon`; empty when nothing is."""
def:priv chop_winding(points: list[Vec3], plane: PatchPlane, epsilon: float) -> list[Vec3] {
    dists: list[float] = [];
    sides: list[int] = [];
    front = 0;
    back = 0;
    for p in points {
        d = p.dot(plane.normal) - plane.dist;
        dists.append(d);
        side = 1 if d > epsilon else (-1 if d < -epsilon else 0);
        sides.append(side);
        if side == 1 {
            front += 1;
        } elif side == -1 {
            back += 1;
        }
    }
    if front == 0 {
        return [];
    }
    if back == 0 {
        return points;
    }
    n = plane.normal;
    out: list[Vec3] = [];
    for i in range(len(points)) {
        p1 = points[i];
        if sides[i] == 0 {
            out.append(p1);
            continue;
        }
        if sides[i] == 1 {
            out.append(p1);
        }
        k = (i + 1) % len(points);
        if sides[k] == 0 or sides[k] == sides[i] {
            continue;
        }
        p2 = points[k];
        t = dists[i] / (dists[i] - dists[k]);
        # Avoid round-off on axial planes, as the original does.
        out.append(
            Vec3(
                x=plane.dist
                    if n.x == 1.0
                    else (-plane.dist if n.x == -1.0 else p1.x + t * (p2.x - p1.x)),
                y=plane.dist
                    if n.y == 1.0
                    else (-plane.dist if n.y == -1.0 else p1.y + t * (p2.y - p1.y)),
                z=plane.dist
                    if n.z == 1.0
                    else (-plane.dist if n.z == -1.0 else p1.z + t * (p2.z - p1.z))
            )
        );
    }
    return out;
}

"""The winding of `facet`'s surface plane cut by its borders (flipped to keep
the facet side), skipping borders equal to the surface plane when `skip_own`
(CM_AddFacetBevels) and failing on an unresolved border (CM_ValidateFacet).
Empty when nothing is left."""
def:priv facet_winding(facet: PatchFacet, planes: list[PatchPlane], skip_own: bool) -> list[Vec3] {
    w = base_winding(planes[facet.surface]);
    for j in range(len(facet.borders)) {
        if not w {
            break;
        }
        border = facet.borders[j];
        if border == -1 {
            return [];
        }
        if skip_own and border == facet.surface {
            continue;
        }
        plane = planes[border];
        if not facet.inward[j] {
            plane = PatchPlane(normal=plane.normal.scale(-1.0), dist=-plane.dist);
        }
        w = chop_winding(w, plane, 0.1);
    }
    return w;
}

"""patchCollide_t with the plane and facet builders of cm_patch.c."""
obj PatchCollide {
    has mins: Vec3 = Vec3(),
        maxs: Vec3 = Vec3(),
        planes: list[PatchPlane] = [],
        facets: list[PatchFacet] = [];

    """CM_FindPlane: the plane through a, b, c (normal out of their clockwise
    order), reusing a same-facing plane all three lie on within
    PLANE_TRI_EPSILON; -1 for a degenerate triangle."""
    def find_plane(a: Vec3, b: Vec3, c: Vec3) -> int {
        # CM_PlaneFromPoints
        normal = c.sub(a).cross(b.sub(a));
        length = normal.length();
        if length == 0.0 {
            return -1;
        }
        normal = normal.scale(1.0 / length);
        for i in range(len(self.planes)) {
            plane = self.planes[i];
            if normal.dot(plane.normal) < 0.0 {
                continue;
            }
            if abs(a.dot(plane.normal) - plane.dist) > 0.1
                or abs(b.dot(plane.normal) - plane.dist) > 0.1
                or abs(c.dot(plane.normal) - plane.dist) > 0.1 {
                continue;
            }
            return i;
        }
        return self.add_plane(PatchPlane(normal=normal, dist=a.dot(normal)));
    }

    """CM_FindPlane2: an equal plane either way round, else a new one, and
    whether the one found is flipped."""
    def find_plane2(plane: PatchPlane) -> tuple[int, bool] {
        for i in range(len(self.planes)) {
            same = patch_plane_match(self.planes[i], plane.normal, plane.dist);
            if same != 0 {
                return (i, same == -1);
            }
        }
        return (self.add_plane(plane), False);
    }

    def add_plane(plane: PatchPlane) -> int {
        if len(self.planes) == 2048 {
            raise ValueError("MAX_PATCH_PLANES");
        }
        self.planes.append(plane);
        return len(self.planes) - 1;
    }

    """CM_GridPlane: a cell triangle's plane, else its partner's."""
    def grid_plane(grid_planes: list[list[list[int]]], i: int, j: int, tri: int) -> int {
        p = grid_planes[i][j][tri];
        if p != -1 {
            return p;
        }
        return grid_planes[i][j][1 - tri];
    }

    """CM_EdgePlaneNum: the plane standing on cell edge `k` (0 top, 1 right,
    2 bottom, 3 left, 4/5 the diagonal out of triangle 0/1), perpendicular to
    the surface beside it."""
    def edge_plane(
        grid: PatchGrid, grid_planes: list[list[list[int]]], i: int, j: int, k: int
    ) -> int {
        pts = grid.points;
        p1 = Vec3();
        p2 = Vec3();
        tri = 0;
        reverse = False;
        if k == 0 {
            p1 = pts[i][j];
            p2 = pts[i + 1][j];
        } elif k == 2 {
            p1 = pts[i][j + 1];
            p2 = pts[i + 1][j + 1];
            tri = 1;
            reverse = True;
        } elif k == 3 {
            p1 = pts[i][j];
            p2 = pts[i][j + 1];
            tri = 1;
            reverse = True;
        } elif k == 1 {
            p1 = pts[i + 1][j];
            p2 = pts[i + 1][j + 1];
        } elif k == 4 {
            p1 = pts[i + 1][j + 1];
            p2 = pts[i][j];
        } elif k == 5 {
            p1 = pts[i][j];
            p2 = pts[i + 1][j + 1];
            tri = 1;
        } else {
            raise ValueError("CM_EdgePlaneNum: bad k");
        }
        p = self.grid_plane(grid_planes, i, j, tri);
        if p == -1 {
            # "should never happen": the original then reads past its planes.
            return -1;
        }
        up = p1.add(self.planes[p].normal.scale(4.0));
        if reverse {
            return self.find_plane(p2, p1, up);
        }
        return self.find_plane(p1, p2, up);
    }

    """CM_SetBorderInward: which way each border faces from the facet's
    corners (`which` -1 the whole cell, 0/1 its triangles); a border the
    corners lie on is dropped (-1), which fails the facet."""
    def set_border_inward(facet: PatchFacet, grid: PatchGrid, i: int, j: int, which: int) {
        pts = grid.points;
        corners: list[Vec3] = [];
        if which == -1 {
            corners = [pts[i][j], pts[i + 1][j], pts[i + 1][j + 1], pts[i][j + 1]];
        } elif which == 0 {
            corners = [pts[i][j], pts[i + 1][j], pts[i + 1][j + 1]];
        } elif which == 1 {
            corners = [pts[i + 1][j + 1], pts[i][j + 1], pts[i][j]];
        } else {
            raise ValueError("CM_SetBorderInward: bad parameter");
        }
        facet.inward = [False for k in range(len(facet.borders))];
        for k in range(len(facet.borders)) {
            front = 0;
            back = 0;
            border = facet.borders[k];
            for point in corners {
                # CM_PointOnPlaneSide: a missing plane counts as on it.
                side = 0 if border == -1 else side_of(point, self.planes[border], 0.1);
                if side == 1 {
                    front += 1;
                }
                if side == -1 {
                    back += 1;
                }
            }
            if front > 0 and back == 0 {
                facet.inward[k] = True;
            } elif back > 0 and front == 0 {
                facet.inward[k] = False;
            } elif front == 0 and back == 0 {
                # A flat side border.
                facet.borders[k] = -1;
            } else {
                # A bisecting border.
                facet.inward[k] = False;
            }
        }
    }

    """CM_ValidateFacet: the borders bound a winding of sane size."""
    def validate_facet(facet: PatchFacet) -> bool {
        if facet.surface == -1 {
            return False;
        }
        w = facet_winding(facet, self.planes, False);
        if not w {
            return False;
        }
        bounds = winding_bounds(w);
        for axis in range(3) {
            lo = bounds[0].x if axis == 0 else (bounds[0].y if axis == 1 else bounds[0].z);
            hi = bounds[1].x if axis == 0 else (bounds[1].y if axis == 1 else bounds[1].z);
            if hi - lo > 65535.0 or lo >= 65535.0 or hi <= -65535.0 {
                return False;
            }
        }
        return True;
    }

    """Add bevel `plane` to the facet's borders unless it is the surface
    plane or already a border (either way round). A `slanted` edge bevel must also
    keep part of the facet's `winding` behind it."""
    def add_bevel(
        facet: PatchFacet, plane: PatchPlane, slanted: bool, winding: list[Vec3]
    ) -> bool {
        if patch_plane_match(self.planes[facet.surface], plane.normal, plane.dist) != 0 {
            return False;
        }
        for border in facet.borders {
            if patch_plane_match(self.planes[border], plane.normal, plane.dist) != 0 {
                return False;
            }
        }
        found = self.find_plane2(plane);
        index = found[0];
        inward = found[1];
        if slanted {
            # An edge bevel must leave some of the facet behind it.
            kept = self.planes[index];
            if not inward {
                kept = PatchPlane(normal=kept.normal.scale(-1.0), dist=-kept.dist);
            }
            if not chop_winding(winding, kept, 0.1) {
                return False;
            }
        }
        facet.borders.append(index);
        facet.inward.append(inward);
        return True;
    }

    """CM_AddFacetBevels: axial planes bounding the facet's winding, the
    slanted axial planes along its non-axial edges, then the flipped surface
    plane closing its back."""
    def add_facet_bevels(facet: PatchFacet) {
        w = facet_winding(facet, self.planes, True);
        if not w {
            return;
        }
        bounds = winding_bounds(w);
        facet.mins = bounds[0];
        facet.maxs = bounds[1];
        facet.bounded = True;
        for axis in range(3) {
            for sign in [-1.0, 1.0] {
                normal = Vec3(
                    x=sign if axis == 0 else 0.0,
                    y=sign if axis == 1 else 0.0,
                    z=sign if axis == 2 else 0.0
                );
                side = bounds[1] if sign > 0.0 else bounds[0];
                dist = normal.dot(side);
                self.add_bevel(facet, PatchPlane(normal=normal, dist=dist), False, w);
            }
        }
        for j in range(len(w)) {
            along = w[j].sub(w[(j + 1) % len(w)]);
            length = along.length();
            if length < 0.5 {
                # A degenerate edge.
                continue;
            }
            along = snap_patch_vector(along.scale(1.0 / length));
            if abs(along.x) == 1.0 or abs(along.y) == 1.0 or abs(along.z) == 1.0 {
                # Only non-axial edges.
                continue;
            }
            for axis in range(3) {
                for sign in [-1.0, 1.0] {
                    toward = Vec3(
                        x=sign if axis == 0 else 0.0,
                        y=sign if axis == 1 else 0.0,
                        z=sign if axis == 2 else 0.0
                    );
                    normal = along.cross(toward);
                    size = normal.length();
                    if size < 0.5 {
                        continue;
                    }
                    normal = normal.scale(1.0 / size);
                    dist = w[j].dot(normal);
                    # A proper edge bevel has the whole winding behind it.
                    behind = True;
                    for point in w {
                        if point.dot(normal) - dist > 0.1 {
                            behind = False;
                            break;
                        }
                    }
                    if behind {
                        self.add_bevel(facet, PatchPlane(normal=normal, dist=dist), True, w);
                    }
                }
            }
        }
        # The opposite plane.
        facet.borders.append(facet.surface);
        facet.inward.append(True);
    }

    """Keep a facet the borders close (CM_ValidateFacet), with its bevels."""
    def keep_facet(facet: PatchFacet) {
        if not self.validate_facet(facet) {
            return;
        }
        self.add_facet_bevels(facet);
        if len(self.facets) == 1024 {
            raise ValueError("MAX_FACETS");
        }
        self.facets.append(facet);
    }

    """CM_PatchCollideFromGrid: a plane per cell triangle (shared where
    coplanar), then per cell one quad facet or two triangle facets whose
    borders are the neighbouring cells' planes, or planes standing on the
    edge where there is no neighbour or it is coplanar (noAdjust)."""
    def from_grid(grid: PatchGrid) {
        width = grid.width();
        height = grid.height();
        pts = grid.points;
        grid_planes: list[list[list[int]]] = [];
        for i in range(width - 1) {
            column: list[list[int]] = [];
            for j in range(height - 1) {
                column.append(
                    [
                        self.find_plane(pts[i][j], pts[i + 1][j], pts[i + 1][j + 1]),
                        self.find_plane(pts[i + 1][j + 1], pts[i][j + 1], pts[i][j])
                    ]
                );
            }
            grid_planes.append(column);
        }
        for i in range(width - 1) {
            for j in range(height - 1) {
                cell = grid_planes[i][j];
                # A missing or coplanar (noAdjust) neighbour takes a plane
                # standing on the edge instead.
                top = -1;
                if j > 0 {
                    top = grid_planes[i][j - 1][1];
                } elif grid.wrap_height {
                    top = grid_planes[i][height - 2][1];
                }
                if top == -1 or top == cell[0] {
                    top = self.edge_plane(grid, grid_planes, i, j, 0);
                }
                bottom = -1;
                if j < height - 2 {
                    bottom = grid_planes[i][j + 1][0];
                } elif grid.wrap_height {
                    bottom = grid_planes[i][0][0];
                }
                if bottom == -1 or bottom == cell[1] {
                    bottom = self.edge_plane(grid, grid_planes, i, j, 2);
                }
                left = -1;
                if i > 0 {
                    left = grid_planes[i - 1][j][0];
                } elif grid.wrap_width {
                    left = grid_planes[width - 2][j][0];
                }
                if left == -1 or left == cell[1] {
                    left = self.edge_plane(grid, grid_planes, i, j, 3);
                }
                right = -1;
                if i < width - 2 {
                    right = grid_planes[i + 1][j][1];
                } elif grid.wrap_width {
                    right = grid_planes[0][j][1];
                }
                if right == -1 or right == cell[0] {
                    right = self.edge_plane(grid, grid_planes, i, j, 1);
                }
                if cell[0] == cell[1] {
                    if cell[0] == -1 {
                        # Degenerate.
                        continue;
                    }
                    facet = PatchFacet(
                        surface=cell[0],
                        borders=[top, right, bottom, left]
                    );
                    self.set_border_inward(facet, grid, i, j, -1);
                    self.keep_facet(facet);
                    continue;
                }
                # Two separate triangles.
                diagonal = cell[1];
                if diagonal == -1 {
                    diagonal = bottom;
                    if diagonal == -1 {
                        diagonal = self.edge_plane(grid, grid_planes, i, j, 4);
                    }
                }
                first = PatchFacet(
                    surface=cell[0],
                    borders=[top, right, diagonal]
                );
                self.set_border_inward(first, grid, i, j, 0);
                self.keep_facet(first);
                diagonal = cell[0];
                if diagonal == -1 {
                    diagonal = top;
                    if diagonal == -1 {
                        diagonal = self.edge_plane(grid, grid_planes, i, j, 5);
                    }
                }
                second = PatchFacet(
                    surface=cell[1],
                    borders=[bottom, left, diagonal]
                );
                self.set_border_inward(second, grid, i, j, 1);
                self.keep_facet(second);
            }
        }
    }
}

"""WindingBounds: [mins, maxs] of a winding."""
def:priv winding_bounds(points: list[Vec3]) -> list[Vec3] {
    lo = Vec3(x=65535.0, y=65535.0, z=65535.0);
    hi = Vec3(x=-65535.0, y=-65535.0, z=-65535.0);
    for p in points {
        lo = Vec3(x=min(lo.x, p.x), y=min(lo.y, p.y), z=min(lo.z, p.z));
        hi = Vec3(x=max(hi.x, p.x), y=max(hi.y, p.y), z=max(hi.z, p.z));
    }
    return [lo, hi];
}

"""CM_SnapVector: a direction within NORMAL_EPSILON of an axis becomes it."""
def:priv snap_patch_vector(v: Vec3) -> Vec3 {
    for axis in range(3) {
        c = v.x if axis == 0 else (v.y if axis == 1 else v.z);
        for sign in [1.0, -1.0] {
            if abs(c - sign) < 0.0001 {
                return Vec3(
                    x=sign if axis == 0 else 0.0,
                    y=sign if axis == 1 else 0.0,
                    z=sign if axis == 2 else 0.0
                );
            }
        }
    }
    return v;
}

"""CM_GeneratePatchCollide: facets for a `width` x `height` quadratic patch
whose control `points` are packed as concatenated rows."""
def generate_patch_collide(width: int, height: int, points: list[Vec3]) -> PatchCollide {
    if width <= 2 or height <= 2 or len(points) != width * height {
        raise ValueError("CM_GeneratePatchFacets: bad parameters");
    }
    if width % 2 == 0 or height % 2 == 0 {
        raise ValueError(
            "CM_GeneratePatchFacets: even sizes are invalid for quadratic meshes"
        );
    }
    if width > 129 or height > 129 {
        raise ValueError("CM_GeneratePatchFacets: source is > MAX_GRID_SIZE");
    }
    grid = PatchGrid();
    for i in range(width) {
        grid.points.append([points[j * width + i] for j in range(height)]);
    }
    grid.set_wrap_width();
    grid.subdivide_columns();
    grid.remove_degenerate_columns();
    grid.transpose();
    grid.set_wrap_width();
    grid.subdivide_columns();
    grid.remove_degenerate_columns();
    # The grid points now lie exactly on the curve; the approximate surface
    # through them is what traces collide with.
    collide = PatchCollide();
    corners: list[Vec3] = [];
    for column in grid.points {
        corners.extend(column);
    }
    bounds = winding_bounds(corners);
    collide.from_grid(grid);
    # Expanded by one unit for epsilon purposes.
    collide.mins = bounds[0].sub(Vec3(x=1.0, y=1.0, z=1.0));
    collide.maxs = bounds[1].add(Vec3(x=1.0, y=1.0, z=1.0));
    return collide;
}
