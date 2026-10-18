"""Drawing for the 2D art: shapes laid down as coverage (a field from 0 to 1,
smooth at its edges), and coverage made into pictures that look cast or cut:
raised where covered, lit from the upper left, coloured along a ramp, with
an outline and a shadow to stand off what is behind.

A stroke is a run of segments of a width; a shape is a polygon filled by
the even-odd rule, a circle, or a box. Coverage is measured at each texel's
middle from its distance to the shape's edge, which keeps edges smooth at
any size."""
import math;
import from .field { Field, blur, shade }
import from .image { Picture, Rgb, along }

"""The distance from (px, py) to the segment from (x0, y0) to (x1, y1)."""
def segment_distance(px: float, py: float, x0: float, y0: float, x1: float, y1: float) -> float {
    dx = x1 - x0;
    dy = y1 - y0;
    length2 = dx * dx + dy * dy;
    t = 0.0;
    if length2 > 1.0e-9 {
        t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / length2));
    }
    ex = px - (x0 + dx * t);
    ey = py - (y0 + dy * t);
    return math.sqrt(ex * ex + ey * ey);
}

"""Coverage of strokes: each stroke a list of points (x, y in texels), drawn
`width` texels wide with round ends, into `into` (kept where it is more)."""
def stroke(into: Field, strokes: list[list[tuple[float, float]]], width: float) {
    half = width * 0.5;
    for points in strokes {
        if not points {
            continue;
        }
        low_x = 1.0e9;
        low_y = 1.0e9;
        high_x = -1.0e9;
        high_y = -1.0e9;
        for (x, y) in points {
            low_x = min(low_x, x);
            low_y = min(low_y, y);
            high_x = max(high_x, x);
            high_y = max(high_y, y);
        }
        x0 = max(0, int(low_x - half - 1.0));
        y0 = max(0, int(low_y - half - 1.0));
        x1 = min(into.w - 1, int(high_x + half + 1.0));
        y1 = min(into.h - 1, int(high_y + half + 1.0));
        for y in range(y0, y1 + 1) {
            for x in range(x0, x1 + 1) {
                px = float(x) + 0.5;
                py = float(y) + 0.5;
                nearest = 1.0e9;
                if len(points) == 1 {
                    nearest = segment_distance(px, py, points[0][0], points[0][1], points[0][0], points[0][1]);
                }
                for k in range(len(points) - 1) {
                    nearest = min(
                        nearest,
                        segment_distance(px, py, points[k][0], points[k][1], points[k + 1][0], points[k + 1][1])
                    );
                }
                cover = max(0.0, min(1.0, half - nearest + 0.5));
                i = y * into.w + x;
                if cover > into.v[i] {
                    into.v[i] = cover;
                }
            }
        }
    }
}

"""Coverage of a polygon (even-odd), smoothed over its edge."""
def polygon(into: Field, points: list[tuple[float, float]], value: float = 1.0) {
    if len(points) < 3 {
        return;
    }
    count = len(points);
    for y in range(into.h) {
        py = float(y) + 0.5;
        for x in range(into.w) {
            px = float(x) + 0.5;
            inside = False;
            nearest = 1.0e9;
            j = count - 1;
            for i in range(count) {
                (xi, yi) = points[i];
                (xj, yj) = points[j];
                if (yi > py) != (yj > py) {
                    cross = xj + (py - yj) * (xi - xj) / (yi - yj);
                    if px < cross {
                        inside = not inside;
                    }
                }
                nearest = min(nearest, segment_distance(px, py, xi, yi, xj, yj));
                j = i;
            }
            edge_cover = min(1.0, nearest + 0.5) if inside else max(0.0, 0.5 - nearest);
            cover = edge_cover * value;
            k = y * into.w + x;
            if cover > into.v[k] {
                into.v[k] = cover;
            }
        }
    }
}

"""Coverage of a disc."""
def disc(into: Field, cx: float, cy: float, radius: float, value: float = 1.0) {
    for y in range(max(0, int(cy - radius - 2.0)), min(into.h, int(cy + radius + 2.0))) {
        for x in range(max(0, int(cx - radius - 2.0)), min(into.w, int(cx + radius + 2.0))) {
            d = math.sqrt((float(x) + 0.5 - cx) ** 2 + (float(y) + 0.5 - cy) ** 2);
            cover = max(0.0, min(1.0, radius - d + 0.5)) * value;
            i = y * into.w + x;
            if cover > into.v[i] {
                into.v[i] = cover;
            }
        }
    }
}

"""Coverage of a box, its corners rounded by `round` texels."""
def box(into: Field, x0: float, y0: float, x1: float, y1: float, rounded: float = 0.0, value: float = 1.0) {
    for y in range(max(0, int(y0 - 1.0)), min(into.h, int(y1 + 1.0))) {
        for x in range(max(0, int(x0 - 1.0)), min(into.w, int(x1 + 1.0))) {
            px = float(x) + 0.5;
            py = float(y) + 0.5;
            qx = max(x0 + rounded - px, max(0.0, px - (x1 - rounded)));
            qy = max(y0 + rounded - py, max(0.0, py - (y1 - rounded)));
            outside = math.sqrt(max(0.0, qx) ** 2 + max(0.0, qy) ** 2) - rounded;
            inner = min(min(px - x0, x1 - px), min(py - y0, y1 - py));
            d = outside if outside > 0.0 else -inner;
            cover = max(0.0, min(1.0, 0.5 - d)) * value;
            i = y * into.w + x;
            if cover > into.v[i] {
                into.v[i] = cover;
            }
        }
    }
}

"""Coverage taken away where `cut` covers."""
def carved(source: Field, cut: Field) -> Field {
    return Field(w=source.w, h=source.h, v=[max(0.0, source.v[i] - cut.v[i]) for i in range(len(source.v))]);
}

"""How something drawn should look: its colours from shadow to highlight,
its outline's colour, and how deep it stands."""
obj Look {
    has ramp: list[Rgb],
        outline: Rgb = Rgb(r=0.06, g=0.05, b=0.04),
        depth: float = 3.0,
        outline_width: int = 1,
        shadow: bool = True,
        # How far the cast is rounded over, in texels: below zero, by the
        # picture's size; nothing for text, whose strokes lie close.
        soft: int = -1;
}

"""A picture of what `mask` covers, raised, lit, coloured by `look`, with an
outline and a drop shadow; clear where nothing is."""
def cast(mask: Field, look: Look) -> Picture {
    w = mask.w;
    h = mask.h;
    # Rounded for its light, except a small picture, whose strokes are only
    # a texel or two apart and would run together.
    radius = look.soft if look.soft >= 0 else (min(w, h) // 32 if min(w, h) >= 64 else 0);
    rounded = blur(mask, radius) if radius > 0 else mask;
    light = shade(rounded, look.depth);
    made = Picture(w=w, h=h, a=[0.0] * (w * h));
    spread = Field(w=w, h=h, v=list(mask.v));
    for step in range(look.outline_width) {
        grown = Field(w=w, h=h);
        for y in range(h) {
            for x in range(w) {
                best = 0.0;
                for dy in range(-1, 2) {
                    for dx in range(-1, 2) {
                        xx = x + dx;
                        yy = y + dy;
                        if xx >= 0 and yy >= 0 and xx < w and yy < h {
                            best = max(best, spread.v[yy * w + xx]);
                        }
                    }
                }
                grown.v[y * w + x] = best;
            }
        }
        spread = grown;
    }
    for y in range(h) {
        for x in range(w) {
            i = y * w + x;
            body = mask.v[i];
            rim = spread.v[i];
            shadow_cover = 0.0;
            if look.shadow and x >= 1 and y >= 1 {
                shadow_cover = spread.v[(y - 1) * w + (x - 1)] * 0.6;
            }
            colour = along(look.ramp, max(0.0, min(1.0, light.v[i] * 0.8 + mask.v[i] * 0.2 + (rounded.v[i] - 0.5) * 0.3)));
            if body > 0.0 {
                mixed = look.outline.mixed(colour, body);
                made.put(i, mixed);
                made.a[i] = max(body, rim);
            } elif rim > 0.0 {
                made.put(i, look.outline);
                made.a[i] = rim;
            } elif shadow_cover > 0.0 {
                made.put(i, Rgb());
                made.a[i] = shadow_cover;
            }
        }
    }
    return made;
}

"""`top` laid over `under` by its coverage."""
def laid_over(under: Picture, top: Picture) -> Picture {
    made = Picture(w=under.w, h=under.h, a=list(under.a));
    for i in range(under.w * under.h) {
        t = top.a[i];
        made.r[i] = under.r[i] + (top.r[i] - under.r[i]) * t;
        made.g[i] = under.g[i] + (top.g[i] - under.g[i]) * t;
        made.b[i] = under.b[i] + (top.b[i] - under.b[i]) * t;
        made.a[i] = max(under.a[i], t);
    }
    return made;
}
