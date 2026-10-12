"""Small pictures of brushes for a list: their edges as lines, seen from
above one corner, drawn into a picture of four bytes a texel. Nothing here
knows of the window."""

import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, brush_windings }

"""The edges of brushes: each side's outline, corner to corner."""
def sketch_edges(brushes: list[list[Side]]) -> list[tuple[Vec3, Vec3]] {
    found: list[tuple[Vec3, Vec3]] = [];
    for sides in brushes {
        for outline in brush_windings(sides) {
            count = len(outline);
            if count < 3 {
                continue;
            }
            for at in range(count) {
                found.append((outline[at], outline[(at + 1) % count]));
            }
        }
    }
    return found;
}

"""Where a point of the world falls in a view from above one corner: x and
y run down to the right and to the left, and height goes up the picture."""
def seen_from_corner(point: Vec3) -> tuple[float, float] {
    return ((point.x - point.y) * 0.866, (point.x + point.y) * 0.5 - point.z);
}

"""A line of texels from one place to another (both ends in)."""
def line_texels(x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]] {
    found: list[tuple[int, int]] = [];
    across = abs(x1 - x0);
    down = abs(y1 - y0);
    step_x = 1 if x1 >= x0 else -1;
    step_y = 1 if y1 >= y0 else -1;
    x = x0;
    y = y0;
    if across >= down {
        owed = across // 2;
        for turn in range(across + 1) {
            found.append((x, y));
            owed -= down;
            if owed < 0 {
                y += step_y;
                owed += across;
            }
            x += step_x;
        }
    } else {
        owed = down // 2;
        for turn in range(down + 1) {
            found.append((x, y));
            owed -= across;
            if owed < 0 {
                x += step_x;
                owed += down;
            }
            y += step_y;
        }
    }
    return found;
}

"""A picture of edges seen from above one corner, fitted to `width` by
`height` with a margin, in one colour on nothing (texels not drawn are
clear). Four bytes a texel."""
def sketch(edges: list[tuple[Vec3, Vec3]], width: int, height: int, red: int, green: int, blue: int) -> bytes {
    made = bytearray(max(0, width) * max(0, height) * 4);
    if len(edges) == 0 or width < 8 or height < 8 {
        return bytes(made);
    }
    ends: list[tuple[float, float]] = [];
    for (start, finish) in edges {
        ends.append(seen_from_corner(start));
        ends.append(seen_from_corner(finish));
    }
    low_x = ends[0][0];
    high_x = ends[0][0];
    low_y = ends[0][1];
    high_y = ends[0][1];
    for (x, y) in ends {
        low_x = min(low_x, x);
        high_x = max(high_x, x);
        low_y = min(low_y, y);
        high_y = max(high_y, y);
    }
    margin = 4;
    scale = min(
        float(width - 2 * margin) / max(1.0, high_x - low_x), float(height - 2 * margin) / max(1.0, high_y - low_y)
    );
    # In the middle of the picture, whichever way it has room to spare.
    left = (float(width) - (high_x - low_x) * scale) / 2.0;
    top = (float(height) - (high_y - low_y) * scale) / 2.0;
    for at in range(0, len(ends), 2) {
        from_x = int(left + (ends[at][0] - low_x) * scale);
        from_y = int(top + (ends[at][1] - low_y) * scale);
        to_x = int(left + (ends[at + 1][0] - low_x) * scale);
        to_y = int(top + (ends[at + 1][1] - low_y) * scale);
        for (px, py) in line_texels(from_x, from_y, to_x, to_y) {
            if px >= 0 and px < width and py >= 0 and py < height {
                spot = (py * width + px) * 4;
                made[spot] = u8(red);
                made[spot + 1] = u8(green);
                made[spot + 2] = u8(blue);
                made[spot + 3] = u8(255);
            }
        }
    }
    return bytes(made);
}
