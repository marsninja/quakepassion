"""A patch as the games would make it: the triangles the renderer's curve
code tessellates it into (tr_curve.c), and the lattice its collision is
traced against (cm_patch.c), both worked out by the engine's own code from
the patch's control points, to be drawn over the studio's prisms."""

import from engine.math.vec3 { Vec3 }
import from engine.formats.q3.curve { Vertex, subdivide_patch, CURVE_SUBDIVISIONS }
import from engine.physics.patch_collide { PatchGrid }

"""The edges of a grid of points (rows of points), each to the next along
its row and to the one below it."""
def lattice_edges(rows: list[list[Vec3]]) -> list[list[Vec3]] {
    edges: list[list[Vec3]] = [];
    for (row_index, row) in enumerate(rows) {
        for (index, point) in enumerate(row) {
            if index + 1 < len(row) {
                edges.append([point, row[index + 1]]);
            }
            if row_index + 1 < len(rows) and index < len(rows[row_index + 1]) {
                edges.append([point, rows[row_index + 1][index]]);
            }
        }
    }
    return edges;
}

"""Whether control points make a grid the games' code takes: odd sizes of
three or more, and a point for every place."""
def patch_takes(width: int, height: int, points: list[Vec3]) -> bool {
    return width >= 3 and height >= 3 and width % 2 == 1 and height % 2 == 1 and len(points) == width * height
        and width <= 129 and height <= 129;
}

"""The rows of points the renderer draws a patch with, at a subdivision
(the games' r_subdivisions; smaller is finer). Nothing for a grid the
games' code does not take."""
def render_rows(width: int, height: int, points: list[Vec3], subdivisions: float = CURVE_SUBDIVISIONS) -> list[list[Vec3]] {
    if not patch_takes(width, height, points) {
        return [];
    }
    grid = subdivide_patch(width, height, [Vertex(pos=point) for point in points], max(1.0, subdivisions));
    return [[vertex.pos for vertex in row] for row in grid.rows];
}

"""The rows of points a patch's collision is traced against: the control
grid subdivided until it lies on the curve, as cm_patch.c does before it
makes its facets. Nothing for a grid the games' code does not take."""
def collide_rows(width: int, height: int, points: list[Vec3]) -> list[list[Vec3]] {
    if not patch_takes(width, height, points) {
        return [];
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
    return [list(column) for column in grid.points];
}
