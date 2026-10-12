"""Lines of more than one thickness, for a renderer that draws them one
pixel wide: a thick line is that line again, a little to either side of
itself as the view sees it."""

import math;
import from engine.math.vec3 { Vec3 }

"""The widest a line is drawn."""
glob WIDEST_LINE: int = 4;

"""How far to either side of itself, in pixels, a line of `width` pixels is
drawn again: none for one pixel, and half a pixel apart so that a screen
with two of its own pixels to each of ours shows no gaps."""
def thick_shifts(width: int) -> list[float] {
    shifts: list[float] = [];
    half = min(max(width, 1), WIDEST_LINE) - 1;
    for step in range(1, half + 1) {
        shifts.append(float(step) * 0.5);
        shifts.append(float(step) * -0.5);
    }
    return shifts;
}

"""The way across a line as a view sees it: of length one, in the plane of
the view's `right` and `up`, and square to the line there. A line that runs
straight at the view has every way across it, so the view's right."""
def line_across(start: Vec3, finish: Vec3, right: Vec3, up: Vec3) -> Vec3 {
    along = finish.sub(start);
    over = along.dot(right);
    above = along.dot(up);
    long = math.sqrt(over * over + above * above);
    if long < 0.000001 {
        return right;
    }
    return right.scale(-above / long).add(up.scale(over / long));
}

"""How much of the world one pixel covers at a point `ahead` of the eye, in
a view `tall` pixels high: `span` world units fit an orthographic view's
height, and one in perspective opens `fov` degrees from top to bottom."""
def pixel_reach(ahead: float, tall: int, span: float, fov: float) -> float {
    rows = float(max(1, tall));
    if span > 0.0 {
        return span / rows;
    }
    return 2.0 * max(1.0, ahead) * math.tan(math.radians(fov) * 0.5) / rows;
}
