"""Fine work on a terrain: which corners of its grid go together, which of
its cells do, and where the edge of such a group runs.

A terrain's heights stand at the corners of its grid, (cols + 1) by
(rows + 1) of them, row by row; its cells are numbered row by row too.
Corners "go together" when they are joined corner to corner along the grid
and stand within a variance of the height of the one first picked: a
terrace, a floor, the top of a ridge. Cells go together the same way, by the
mean height of their four corners."""
import from engine.math.vec3 { Vec3 }

"""The corner of the grid nearest a place: [col, row]."""
def corner_near(origin: Vec3, cols: int, rows: int, cell: float, x: float, y: float) -> list[int] {
    col = int(round((x - origin.x) / cell));
    row = int(round((y - origin.y) / cell));
    return [max(0, min(cols, col)), max(0, min(rows, row))];
}

"""The cell a place is in: [col, row], or [-1, -1] off the terrain."""
def cell_at(origin: Vec3, cols: int, rows: int, cell: float, x: float, y: float) -> list[int] {
    if x < origin.x or y < origin.y or x >= origin.x + float(cols) * cell or y >= origin.y + float(rows) * cell {
        return [-1, -1];
    }
    return [int((x - origin.x) / cell), int((y - origin.y) / cell)];
}

"""The corners that go with one: joined to it along the grid, each within
`variance` of its height. The corner itself is the first."""
def kin_corners(heights: list[float], cols: int, rows: int, col: int, row: int, variance: float = 0.0) -> list[int] {
    wide = cols + 1;
    if col < 0 or row < 0 or col > cols or row > rows or len(heights) != wide * (rows + 1) {
        return [];
    }
    first = row * wide + col;
    level = heights[first];
    found = [first];
    marked: list[bool] = [False for height in heights];
    marked[first] = True;
    turn = 0;
    while turn < len(found) {
        at = found[turn];
        turn += 1;
        c = at % wide;
        r = at // wide;
        for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            nc = c + dc;
            nr = r + dr;
            if nc < 0 or nr < 0 or nc > cols or nr > rows {
                continue;
            }
            near = nr * wide + nc;
            if not marked[near] and abs(heights[near] - level) <= variance {
                marked[near] = True;
                found.append(near);
            }
        }
    }
    return found;
}

"""The mean height of a cell's four corners."""
def cell_level(heights: list[float], cols: int, col: int, row: int) -> float {
    wide = cols + 1;
    return (heights[row * wide + col] + heights[row * wide + col + 1] + heights[(row + 1) * wide + col]
        + heights[(row + 1) * wide + col + 1]) * 0.25;
}

"""The cells that go with one: joined to it side to side, each with a mean
height within `variance` of its own. The cell itself is the first."""
def kin_cells(heights: list[float], cols: int, rows: int, col: int, row: int, variance: float = 0.0) -> list[int] {
    if col < 0 or row < 0 or col >= cols or row >= rows or len(heights) != (cols + 1) * (rows + 1) {
        return [];
    }
    first = row * cols + col;
    level = cell_level(heights, cols, col, row);
    found = [first];
    marked: list[bool] = [False for index in range(cols * rows)];
    marked[first] = True;
    turn = 0;
    while turn < len(found) {
        at = found[turn];
        turn += 1;
        c = at % cols;
        r = at // cols;
        for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            nc = c + dc;
            nr = r + dr;
            if nc < 0 or nr < 0 or nc >= cols or nr >= rows {
                continue;
            }
            near = nr * cols + nc;
            if not marked[near] and abs(cell_level(heights, cols, nc, nr) - level) <= variance {
                marked[near] = True;
                found.append(near);
            }
        }
    }
    return found;
}

"""The corners of a set of cells, each once, in order."""
def cells_corners(cols: int, rows: int, cells: list[int]) -> list[int] {
    wide = cols + 1;
    marked: list[bool] = [False for index in range(wide * (rows + 1))];
    for at in cells {
        if at < 0 or at >= cols * rows {
            continue;
        }
        c = at % cols;
        r = at // cols;
        marked[r * wide + c] = True;
        marked[r * wide + c + 1] = True;
        marked[(r + 1) * wide + c] = True;
        marked[(r + 1) * wide + c + 1] = True;
    }
    return [index for index in range(len(marked)) if marked[index]];
}

"""Heights with some corners moved up or down, none below the base."""
def corners_lifted(heights: list[float], picks: list[int], amount: float) -> list[float] {
    made = list(heights);
    for at in picks {
        if at >= 0 and at < len(made) {
            made[at] = max(0.0, made[at] + amount);
        }
    }
    return made;
}

"""The edge of a set of cells, as lines along the terrain's own surface:
every side of a cell in the set that no other cell of the set shares. For
drawing round the group before something is done to it."""
def cells_outline(
    heights: list[float], cols: int, rows: int, cells: list[int], origin: Vec3, cell: float, base: float = 16.0
) -> list[list[Vec3]] {
    lines: list[list[Vec3]] = [];
    wide = cols + 1;
    if len(heights) != wide * (rows + 1) {
        return lines;
    }
    inside: list[bool] = [False for index in range(cols * rows)];
    for at in cells {
        if at >= 0 and at < len(inside) {
            inside[at] = True;
        }
    }
    for at in range(cols * rows) {
        if not inside[at] {
            continue;
        }
        c = at % cols;
        r = at // cols;
        # Each side: the neighbour across it, and the two corners it runs between.
        for (dc, dr, c0, r0, c1, r1) in [
            (0, -1, c, r, c + 1, r), (0, 1, c, r + 1, c + 1, r + 1), (-1, 0, c, r, c, r + 1), (1, 0, c + 1, r, c + 1, r + 1)
        ] {
            nc = c + dc;
            nr = r + dr;
            if nc >= 0 and nr >= 0 and nc < cols and nr < rows and inside[nr * cols + nc] {
                continue;
            }
            lines.append(
                [
                    Vec3(
                        x=origin.x + float(c0) * cell,
                        y=origin.y + float(r0) * cell,
                        z=origin.z + base + heights[r0 * wide + c0] + 1.0
                    ),
                    Vec3(
                        x=origin.x + float(c1) * cell,
                        y=origin.y + float(r1) * cell,
                        z=origin.z + base + heights[r1 * wide + c1] + 1.0
                    )
                ]
            );
        }
    }
    return lines;
}
