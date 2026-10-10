"""Quake III patch meshes for drawing (tr_curve.c, and tr_bsp.c's stitching).

A patch is a grid of quadratic control points. R_SubdividePatchToGrid turns
it into the grid of vertices it is drawn with: a control column is split
while the curve's midpoint lies further than r_subdivisions from the chord
of its neighbours, the approximating points are put on the curve, and rows
and columns that run straight are dropped. R_StitchAllPatches then gives
neighbouring patches of one LOD group the same vertices along the edges they
share, so no crack shows between a finely and a coarsely subdivided one.

Collision keeps its own facets from the control points
(physics/patch_collide.jac, cm_patch.c)."""
import math;
import from ...math.vec3 { Vec3 }

# tr_local.h MAX_GRID_SIZE: the most rows or columns a grid mesh holds.
glob CURVE_GRID_LIMIT: int = 65;

# tr_init.c r_subdivisions: how far, in units, a curve may lie from the
# straight line drawn in its place.
glob CURVE_SUBDIVISIONS: float = 4.0;

# What R_SubdividePatchToGrid writes in its error table for a column whose
# points all lie on the line of their neighbours.
glob CURVE_COLINEAR: float = 999.0;

"""A drawVert_t: position, texture and lightmap coordinates, colour."""
obj Vertex {
    has pos: Vec3 = Vec3(),
        s: float = 0.0,
        t: float = 0.0,
        ls: float = 0.0,
        lt: float = 0.0,
        colors: list[float] = [];
}

"""tr_curve.c LerpDrawVert: the vertex half way between two (colours as the
original's bytes, halved by a shift)."""
def lerp_vertex(a: Vertex, b: Vertex) -> Vertex {
    return Vertex(
        pos=a.pos.add(b.pos).scale(0.5),
        s=0.5 * (a.s + b.s),
        t=0.5 * (a.t + b.t),
        ls=0.5 * (a.ls + b.ls),
        lt=0.5 * (a.lt + b.lt),
        colors=[float((int(a.colors[k]) + int(b.colors[k])) >> 1) for k in range(min(len(a.colors), len(b.colors)))]
    );
}

"""A patch's vertices row by row (srfGridMesh_t) and the LOD group q3map put
it in: patches with the same origin and radius must subdivide alike."""
obj CurveGrid {
    has width: int = 0,
        height: int = 0,
        rows: list[list[Vertex]] = [],
        lod_origin: Vec3 = Vec3(),
        lod_radius: float = 0.0,
        stitched: bool = False;

    """One of the grid's four borders, in order: 0 the first row, 1 the last,
    2 the first column, 3 the last."""
    def border(side: int) -> list[Vertex] {
        if side == 0 {
            return self.rows[0];
        }
        if side == 1 {
            return self.rows[self.height - 1];
        }
        column = 0 if side == 2 else self.width - 1;
        return [row[column] for row in self.rows];
    }

    """tr_curve.c R_GridInsertColumn: a column before `column`, half way
    between its neighbours, with `point` in row `row`."""
    def insert_column(column: int, row: int, point: Vec3) {
        for j in range(self.height) {
            fresh = lerp_vertex(self.rows[j][column - 1], self.rows[j][column]);
            if j == row {
                fresh.pos = point;
            }
            self.rows[j].insert(column, fresh);
        }
        self.width += 1;
    }

    """tr_curve.c R_GridInsertRow: a row before `row`, half way between its
    neighbours, with `point` in column `column`."""
    def insert_row(row: int, column: int, point: Vec3) {
        fresh = [lerp_vertex(self.rows[row - 1][i], self.rows[row][i]) for i in range(self.width)];
        fresh[column].pos = point;
        self.rows.insert(row, fresh);
        self.height += 1;
    }
}

"""Rows and columns swapped (tr_curve.c Transpose)."""
def transposed(rows: list[list[Vertex]]) -> list[list[Vertex]] {
    return [[rows[j][i] for j in range(len(rows))] for i in range(len(rows[0]))];
}

"""How far the curve through three control points lies from their chord at
its middle (R_SubdividePatchToGrid's dist-from-line)."""
def curve_error(a: Vec3, b: Vec3, c: Vec3) -> float {
    off = a.add(b.scale(2.0)).add(c).scale(0.25).sub(a);
    chord = c.sub(a);
    line = chord.normalized() if chord.length() > 0.0 else Vec3();
    return off.sub(line.scale(off.dot(line))).length();
}

"""tr_curve.c R_SubdividePatchToGrid: the grid a `width` x `height` patch of
control `points` draws with. `subdivisions` is r_subdivisions."""
def subdivide_patch(width: int, height: int, points: list[Vertex], subdivisions: float = CURVE_SUBDIVISIONS) -> CurveGrid {
    rows = [[points[j * width + i] for i in range(width)] for j in range(height)];
    errors: list[list[float]] = [];
    for direction in range(2) {
        table = [0.0] * CURVE_GRID_LIMIT;
        j = 0;
        while j + 2 < width {
            # Check the subdivided midpoints against the control points.
            longest = 0.0;
            for i in range(height) {
                longest = max(longest, curve_error(rows[i][j].pos, rows[i][j + 1].pos, rows[i][j + 2].pos));
            }
            if longest < 0.1 {
                # Every point is on the line: the column goes later.
                table[j + 1] = CURVE_COLINEAR;
                j += 2;
                continue;
            }
            if width + 2 > CURVE_GRID_LIMIT or longest <= subdivisions {
                table[j + 1] = 1.0 / longest;
                j += 2;
                continue;
            }
            table[j + 2] = 1.0 / longest;
            # Insert two columns and replace the peak, then check this set
            # again: it may need more.
            width += 2;
            for i in range(height) {
                before = lerp_vertex(rows[i][j], rows[i][j + 1]);
                after = lerp_vertex(rows[i][j + 1], rows[i][j + 2]);
                rows[i][j + 1] = lerp_vertex(before, after);
                rows[i].insert(j + 1, before);
                rows[i].insert(j + 3, after);
            }
        }
        errors.append(table);
        rows = transposed(rows);
        swap = width;
        width = height;
        height = swap;
    }
    # PutPointsOnCurve: the approximating points onto the curve.
    for i in range(width) {
        for j in range(1, height, 2) {
            rows[j][i] = lerp_vertex(lerp_vertex(rows[j][i], rows[j + 1][i]), lerp_vertex(rows[j][i], rows[j - 1][i]));
        }
    }
    for j in range(height) {
        for i in range(1, width, 2) {
            rows[j][i] = lerp_vertex(lerp_vertex(rows[j][i], rows[j][i + 1]), lerp_vertex(rows[j][i], rows[j][i - 1]));
        }
    }
    # Cull the rows and columns that are colinear.
    i = 1;
    while i < width - 1 {
        if errors[0][i] == CURVE_COLINEAR {
            for row in rows {
                row.pop(i);
            }
            errors[0].pop(i);
            width -= 1;
        }
        i += 1;
    }
    i = 1;
    while i < height - 1 {
        if errors[1][i] == CURVE_COLINEAR {
            rows.pop(i);
            errors[1].pop(i);
            height -= 1;
        }
        i += 1;
    }
    return CurveGrid(width=width, height=height, rows=rows);
}

"""Whether two points are within `slack` on every axis."""
def points_meet(a: Vec3, b: Vec3, slack: float) -> bool {
    return abs(a.x - b.x) <= slack and abs(a.y - b.y) <= slack and abs(a.z - b.z) <= slack;
}

"""tr_bsp.c R_MergedWidthPoints and R_MergedHeightPoints: whether two of a
border's inner points coincide."""
def merged_points(rim: list[Vertex]) -> bool {
    for i in range(1, len(rim) - 1) {
        for j in range(i + 1, len(rim) - 1) {
            if points_meet(rim[i].pos, rim[j].pos, 0.1) {
                return True;
            }
        }
    }
    return False;
}

"""tr_bsp.c R_StitchPatches: where `first` has a vertex between two that are
neighbours on a border of `second`, give `second` that vertex too (one
column or row a call). True when it did."""
def stitch_patches(first: CurveGrid, second: CurveGrid) -> bool {
    for backwards in [False, True] {
        for side in range(4) {
            rim = first.border(side);
            if merged_points(rim) {
                continue;
            }
            count = len(rim);
            step = -2 if backwards else 2;
            k = count - 1 if backwards else 0;
            while (backwards and k > 1) or (not backwards and k < count - 2) {
                near = rim[k].pos;
                far = rim[k + step].pos;
                middle = rim[k + step // 2].pos;
                for other in range(4) {
                    across = other < 2;
                    if (second.width if across else second.height) >= CURVE_GRID_LIMIT {
                        continue;
                    }
                    facing = second.border(other);
                    for l in range(len(facing) - 1) {
                        if not points_meet(near, facing[l].pos, 0.1) or not points_meet(far, facing[l + 1].pos, 0.1) {
                            continue;
                        }
                        if points_meet(facing[l].pos, facing[l + 1].pos, 0.01) {
                            continue;
                        }
                        # A crack at the highest detail: close it.
                        if across {
                            second.insert_column(l + 1, second.height - 1 if other == 1 else 0, middle);
                        } else {
                            second.insert_row(l + 1, second.width - 1 if other == 3 else 0, middle);
                        }
                        second.stitched = False;
                        return True;
                    }
                }
                k += step;
            }
        }
    }
    return False;
}

"""tr_bsp.c R_StitchAllPatches: stitch every grid against the grids of its
LOD group (itself included) until none changes. Returns the stitches made."""
def stitch_all_patches(grids: list[CurveGrid]) -> int {
    groups: dict[str, list[CurveGrid]] = {};
    for grid in grids {
        key = str(grid.lod_radius) + ":" + str(grid.lod_origin.x) + ":" + str(grid.lod_origin.y) + ":" + str(grid.lod_origin.z);
        if key not in groups {
            groups[key] = [];
        }
        groups[key].append(grid);
    }
    stitches = 0;
    for members in groups.values() {
        busy = True;
        while busy {
            busy = False;
            for grid in members {
                if grid.stitched {
                    continue;
                }
                grid.stitched = True;
                busy = True;
                for other in members {
                    while stitch_patches(grid, other) {
                        stitches += 1;
                    }
                }
            }
        }
    }
    return stitches;
}
