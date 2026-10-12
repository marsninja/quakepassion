"""What a pointer on a skin's picture points at: where on the skin it is,
the point whose place lies nearest, and the triangle a place lies in."""

"""Where a picture `wide` by `tall` texels is drawn in a box `room_w` by
`room_h` (its edges four in from the box's): as large as fits, in
proportion and in the middle. [x, y, w, h] within the box."""
def skin_rect(room_w: int, room_h: int, wide: int, tall: int) -> list[int] {
    inner_w = room_w - 8;
    inner_h = room_h - 8;
    if wide <= 0 or tall <= 0 or inner_w <= 0 or inner_h <= 0 {
        return [0, 0, 0, 0];
    }
    shown_w = wide;
    shown_h = tall;
    if wide * inner_h > tall * inner_w {
        shown_h = max(1, tall * inner_w // wide);
        shown_w = inner_w;
    } else {
        shown_w = max(1, wide * inner_h // tall);
        shown_h = inner_h;
    }
    return [(room_w - shown_w) // 2, (room_h - shown_h) // 2, shown_w, shown_h];
}

"""The place on the skin, [u, v] from 0 to 1, of a pixel `x`, `y` within
the box, or [] when it is off the picture."""
def skin_place(rect: list[int], x: int, y: int) -> list[float] {
    if rect[2] <= 0 or rect[3] <= 0 or x < rect[0] or y < rect[1] or x > rect[0] + rect[2] or y > rect[1] + rect[3] {
        return [];
    }
    return [float(x - rect[0]) / float(rect[2]), float(y - rect[1]) / float(rect[3])];
}

"""The point whose place on the skin is nearest `u`, `v`, no further than
`reach` (as a share of the picture), or -1."""
def place_nearest(uvs: list[float], u: float, v: float, reach: float) -> int {
    found = -1;
    least = reach * reach;
    for index in range(len(uvs) // 2) {
        across = uvs[index * 2] - u;
        down = uvs[index * 2 + 1] - v;
        away = across * across + down * down;
        if away <= least {
            least = away;
            found = index;
        }
    }
    return found;
}

"""The triangle whose places on the skin hold `u`, `v` (the last of them
when they overlap), or -1."""
def triangle_at(corners: list[int], uvs: list[float], u: float, v: float) -> int {
    found = -1;
    for index in range(len(corners) // 3) {
        spots: list[list[float]] = [];
        for k in range(3) {
            at = corners[index * 3 + k];
            if at * 2 + 1 >= len(uvs) {
                spots = [];
                break;
            }
            spots.append([uvs[at * 2], uvs[at * 2 + 1]]);
        }
        if len(spots) != 3 {
            continue;
        }
        signs: list[float] = [];
        for k in range(3) {
            a = spots[k];
            b = spots[(k + 1) % 3];
            signs.append((b[0] - a[0]) * (v - a[1]) - (b[1] - a[1]) * (u - a[0]));
        }
        if (signs[0] >= 0.0 and signs[1] >= 0.0 and signs[2] >= 0.0) or (signs[0] <= 0.0 and signs[1] <= 0.0 and signs[2] <= 0.0) {
            found = index;
        }
    }
    return found;
}
