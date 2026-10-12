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

# Where a patch's control points' places on its material are drawn in a
# box: the material's picture and every place fitted in, in proportion.

"""The span of texels shown: [s low, t low, s high, t high], round the
picture (`wide` by `tall` texels from the origin) and every place (two
numbers a point), with a sixteenth more on every side."""
def place_frame(places: list[float], wide: float, tall: float) -> list[float] {
    low_s = 0.0;
    low_t = 0.0;
    high_s = max(1.0, wide);
    high_t = max(1.0, tall);
    for index in range(len(places) // 2) {
        low_s = min(low_s, places[index * 2]);
        high_s = max(high_s, places[index * 2]);
        low_t = min(low_t, places[index * 2 + 1]);
        high_t = max(high_t, places[index * 2 + 1]);
    }
    rim = max(high_s - low_s, high_t - low_t) / 16.0;
    return [low_s - rim, low_t - rim, high_s + rim, high_t + rim];
}

"""How a span of texels is drawn in a box `w` by `h` pixels: [left, top,
pixels a texel], in proportion and in the middle."""
def frame_fit(frame: list[float], w: int, h: int) -> list[float] {
    across = max(0.001, frame[2] - frame[0]);
    down = max(0.001, frame[3] - frame[1]);
    unit = min(float(max(1, w)) / across, float(max(1, h)) / down);
    return [(float(w) - across * unit) * 0.5, (float(h) - down * unit) * 0.5, unit];
}

"""A place's pixel in the box, from the frame and its fit."""
def place_pixel(frame: list[float], fit: list[float], s: float, t: float) -> list[int] {
    return [int(fit[0] + (s - frame[0]) * fit[2]), int(fit[1] + (t - frame[1]) * fit[2])];
}

"""The place a pixel of the box stands for."""
def pixel_place(frame: list[float], fit: list[float], x: int, y: int) -> list[float] {
    return [frame[0] + (float(x) - fit[0]) / fit[2], frame[1] + (float(y) - fit[1]) / fit[2]];
}

"""The point whose place is drawn nearest a pixel, within `reach` pixels, or -1."""
def place_at_pixel(frame: list[float], fit: list[float], places: list[float], x: int, y: int, reach: int = 7) -> int {
    found = -1;
    least = reach * reach + 1;
    for index in range(len(places) // 2) {
        at = place_pixel(frame, fit, places[index * 2], places[index * 2 + 1]);
        away = (at[0] - x) * (at[0] - x) + (at[1] - y) * (at[1] - y);
        if away < least {
            least = away;
            found = index;
        }
    }
    return found;
}
