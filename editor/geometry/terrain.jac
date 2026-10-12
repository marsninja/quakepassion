"""Terrain: a grid of heights built as brushes.

A terrain is `cols` by `rows` cells, each `cell` units square, with a height
at every corner of the grid. Each cell is built as two prisms, split along
one diagonal, standing on a flat base: two because four corners at four
heights do not lie in one plane, and each prism's top does. Sculpting
changes the heights; the brushes are then built again from them, always in
the same order, so a cell's brushes keep their place."""
import math;
import from engine.math.vec3 { Vec3 }
import from .brush { Side }
import from .csg { hull_sides }

"""Heights as a field keeps them: whole numbers where they are whole."""
def heights_text(heights: list[float]) -> str {
    words: list[str] = [];
    for value in heights {
        nearest = float(round(value));
        words.append(str(int(nearest)) if abs(value - nearest) < 0.005 else str(round(value, 2)));
    }
    return " ".join(words);
}

"""Heights from a field: (cols + 1) by (rows + 1) of them, or none when the
field does not hold that many numbers."""
def heights_from(text: str, cols: int, rows: int) -> list[float] | None {
    found: list[float] = [];
    for word in text.split() {
        try {
            found.append(float(word));
        } except ValueError {
            return None;
        }
    }
    if len(found) != (cols + 1) * (rows + 1) {
        return None;
    }
    return found;
}

"""A flat terrain's heights."""
def flat_heights(cols: int, rows: int, height: float = 0.0) -> list[float] {
    return [height for i in range((cols + 1) * (rows + 1))];
}

"""The brushes of a terrain whose low corner is at `origin` (its z is the
underside of the base): two for each cell, row by row. A corner's height is
measured up from `origin.z + base`, and is never let below the base's top.
`like` gives, brush for brush, the sides to take materials from."""
def terrain_brushes(
    origin: Vec3,
    cols: int,
    rows: int,
    cell: float,
    heights: list[float],
    base: float = 16.0,
    material: str = "",
    like: list[list[Side]] = [],
    pattern: str = ""
) -> list[list[Side]] {
    made: list[list[Side]] = [];
    if cols < 1 or rows < 1 or len(heights) != (cols + 1) * (rows + 1) {
        return made;
    }
    floor = origin.z;
    for row in range(rows) {
        for col in range(cols) {
            spots: list[Vec3] = [];
            tops: list[float] = [];
            for (dx, dy) in [(0, 0), (1, 0), (1, 1), (0, 1)] {
                spots.append(Vec3(x=origin.x + float(col + dx) * cell, y=origin.y + float(row + dy) * cell));
                tops.append(floor + base + max(0.0, heights[(row + dy) * (cols + 1) + col + dx]));
            }
            # Split along the diagonal from the cell's low corner to its far
            # one; or along the other; or one and then the other, cell by
            # cell, so ridges run either way.
            crossed = pattern == "other" or (pattern == "alt" and (row + col) % 2 == 1);
            for trio in ([[0, 1, 3], [1, 2, 3]] if crossed else [[0, 1, 2], [0, 2, 3]]) {
                corners: list[Vec3] = [];
                for index in trio {
                    corners.append(Vec3(x=spots[index].x, y=spots[index].y, z=floor));
                    corners.append(Vec3(x=spots[index].x, y=spots[index].y, z=tops[index]));
                }
                # Built again, a prism keeps the materials it had been given.
                made.append(hull_sides(corners, like[len(made)] if len(made) < len(like) else [], material));
            }
        }
    }
    return made;
}

"""Heights after a stroke of a sculpting brush centred at (x, y) in the
world, `radius` wide, falling off smoothly to its edge. `how` is "raise"
(by `amount` at the centre; negative lowers), "flatten" (toward `amount`),
"smooth" (toward the mean of each corner's neighbours, `amount` of the way)
or "noise" (a fixed roughness of up to `amount`)."""
def sculpted(
    heights: list[float],
    origin: Vec3,
    cols: int,
    rows: int,
    cell: float,
    x: float,
    y: float,
    radius: float,
    amount: float,
    how: str = "raise"
) -> list[float] {
    result = list(heights);
    if radius <= 0.0 or len(heights) != (cols + 1) * (rows + 1) {
        return result;
    }
    for row in range(rows + 1) {
        for col in range(cols + 1) {
            away = math.sqrt(
                (origin.x + float(col) * cell - x) ** 2 + (origin.y + float(row) * cell - y) ** 2
            );
            if away >= radius {
                continue;
            }
            # One at the centre, none at the edge, level at both.
            weight = 0.5 + 0.5 * math.cos(math.pi * away / radius);
            index = row * (cols + 1) + col;
            was = heights[index];
            now = was;
            if how == "raise" {
                now = was + amount * weight;
            } elif how == "flatten" {
                now = was + (amount - was) * weight;
            } elif how == "smooth" {
                total = 0.0;
                count = 0;
                for (dc, dr) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    if 0 <= col + dc and col + dc <= cols and 0 <= row + dr and row + dr <= rows {
                        total += heights[(row + dr) * (cols + 1) + col + dc];
                        count += 1;
                    }
                }
                if count > 0 {
                    now = was + (total / float(count) - was) * weight * max(0.0, min(1.0, amount));
                }
            } elif how == "erode" {
                # What stands above its lowest neighbour slumps toward it.
                lowest = was;
                for (dc, dr) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    if 0 <= col + dc and col + dc <= cols and 0 <= row + dr and row + dr <= rows {
                        lowest = min(lowest, heights[(row + dr) * (cols + 1) + col + dc]);
                    }
                }
                now = was - weight * min(abs(amount), (was - lowest) * 0.5);
            } elif how == "noise" {
                # The same roughness for the same corner, every time.
                seed = (col * 73856093) ^ (row * 19349663);
                now = was + amount * weight * (float(seed % 2001) / 1000.0 - 1.0);
            }
            result[index] = max(0.0, float(round(now)));
        }
    }
    return result;
}

"""Heights with every corner inside a rectangle of the world lifted by
`amount` (lowered, when it is negative), and those within `falloff` of the
rectangle by less the farther they are from it."""
def lifted(
    heights: list[float],
    origin: Vec3,
    cols: int,
    rows: int,
    cell: float,
    low: Vec3,
    high: Vec3,
    amount: float,
    falloff: float = 0.0
) -> list[float] {
    result = list(heights);
    if len(heights) != (cols + 1) * (rows + 1) {
        return result;
    }
    for row in range(rows + 1) {
        for col in range(cols + 1) {
            x = origin.x + float(col) * cell;
            y = origin.y + float(row) * cell;
            # How far outside the rectangle the corner is.
            out_x = max(0.0, max(low.x - x, x - high.x));
            out_y = max(0.0, max(low.y - y, y - high.y));
            away = math.sqrt(out_x * out_x + out_y * out_y);
            share = 1.0;
            if away > 0.001 {
                share = 1.0 - away / falloff if falloff > 0.0 and away < falloff else 0.0;
            }
            if share > 0.0 {
                index = row * (cols + 1) + col;
                result[index] = max(0.0, float(round(heights[index] + amount * share)));
            }
        }
    }
    return result;
}

"""Heights as a plain grey image (a PGM, the text kind): a row of the image
a row of corners, north at the top, the tallest corner white."""
def heights_image(heights: list[float], cols: int, rows: int) -> str {
    tallest = 1.0;
    for value in heights {
        tallest = max(tallest, value);
    }
    lines = ["P2", str(cols + 1) + " " + str(rows + 1), "255"];
    for row in range(rows, -1, -1) {
        lines.append(
            " ".join([str(int(round(heights[row * (cols + 1) + col] / tallest * 255.0))) for col in range(cols + 1)])
        );
    }
    return "\n".join(lines) + "\n";
}

"""Heights from a grey image of either PGM kind, white being `tallest`
units up: (columns, rows, heights), or none when it is not such an image."""
def image_heights(data: bytes, tallest: float = 256.0) -> tuple[int, int, list[float]] | None {
    if len(data) < 7 or data[0] != 80 or (data[1] != 50 and data[1] != 53) {
        return None;
    }
    binary = data[1] == 53;
    # Three numbers after the mark: width, height and the brightest value.
    numbers: list[int] = [];
    at = 2;
    while len(numbers) < 3 and at < len(data) {
        if data[at] == 35 {
            while at < len(data) and data[at] != 10 {
                at += 1;
            }
            continue;
        }
        if data[at] < 48 or data[at] > 57 {
            at += 1;
            continue;
        }
        value = 0;
        while at < len(data) and data[at] >= 48 and data[at] <= 57 {
            value = value * 10 + (data[at] - 48);
            at += 1;
        }
        numbers.append(value);
    }
    if len(numbers) < 3 or numbers[0] < 2 or numbers[1] < 2 or numbers[2] < 1 {
        return None;
    }
    wide = numbers[0];
    tall = numbers[1];
    values: list[int] = [];
    if binary {
        at += 1;
        if len(data) - at < wide * tall {
            return None;
        }
        for i in range(wide * tall) {
            values.append(data[at + i]);
        }
    } else {
        while len(values) < wide * tall and at < len(data) {
            if data[at] < 48 or data[at] > 57 {
                at += 1;
                continue;
            }
            value = 0;
            while at < len(data) and data[at] >= 48 and data[at] <= 57 {
                value = value * 10 + (data[at] - 48);
                at += 1;
            }
            values.append(value);
        }
        if len(values) < wide * tall {
            return None;
        }
    }
    heights: list[float] = [0.0 for i in range(wide * tall)];
    for row in range(tall) {
        for col in range(wide) {
            # The image's top row is the terrain's far one.
            heights[(tall - 1 - row) * wide + col] = float(
                round(float(values[row * wide + col]) / float(numbers[2]) * tallest)
            );
        }
    }
    return (wide - 1, tall - 1, heights);
}

"""How far outside a rectangle a lift falls away to nothing, from a word: so
many units, or with a `%` after it that share of the rectangle's shorter
side. Nothing, and what is no number, is no falloff."""
def falloff_of(word: str, wide: float, deep: float) -> float {
    text = word.strip();
    share = text.endswith("%");
    if share {
        text = text[:-1];
    }
    try {
        amount = float(text);
    } except ValueError {
        return 0.0;
    }
    if amount <= 0.0 {
        return 0.0;
    }
    return amount * min(abs(wide), abs(deep)) / 100.0 if share else amount;
}
