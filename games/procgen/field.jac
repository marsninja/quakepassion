"""Fields: a picture of numbers, one a texel, that every generated texture is
built from. A field wraps at its edges, so a texture made from fields tiles:
noise is drawn on a lattice that repeats across the field, blurs and slopes
read across the edge from the other side, and patterns are laid out in
whole repeats.

Every field here is made from a seed by arithmetic alone, so the same seed
makes the same field every time, natively and interpreted."""
import math;
import from games.passion.random { mix32 }

obj Field {
    has w: int,
        h: int,
        v: list[float] = [];

    def postinit {
        if len(self.v) != self.w * self.h {
            self.v = [0.0] * (self.w * self.h);
        }
    }

    """The value at (x, y), wrapping."""
    def at(x: int, y: int) -> float {
        return self.v[(y % self.h) * self.w + (x % self.w)];
    }

    def put(x: int, y: int, value: float) {
        self.v[y * self.w + x] = value;
    }

    """The value between texels, read smoothly, wrapping."""
    def sample(x: float, y: float) -> float {
        fx = math.floor(x);
        fy = math.floor(y);
        tx = x - fx;
        ty = y - fy;
        ix = int(fx);
        iy = int(fy);
        top = self.at(ix, iy) * (1.0 - tx) + self.at(ix + 1, iy) * tx;
        bottom = self.at(ix, iy + 1) * (1.0 - tx) + self.at(ix + 1, iy + 1) * tx;
        return top * (1.0 - ty) + bottom * ty;
    }
}

"""A field of one value."""
def flat(w: int, h: int, value: float = 0.0) -> Field {
    return Field(w=w, h=h, v=[value] * (w * h));
}

"""A number from 0 to 1 for a lattice point, the same every time for the same
seed and point."""
def lattice(seed: int, x: int, y: int) -> float {
    return float(mix32(seed ^ mix32((x & 65535) | ((y & 65535) << 16)))) / 4294967296.0;
}

def:priv smooth(t: float) -> float {
    return t * t * (3.0 - 2.0 * t);
}

"""Value noise over `cx` by `cy` lattice cells that repeat across the field,
from 0 to 1."""
def value_noise(w: int, h: int, cx: int, cy: int, seed: int) -> Field {
    made = Field(w=w, h=h);
    cells_x = max(1, cx);
    cells_y = max(1, cy);
    corners: list[float] = [];
    for j in range(cells_y) {
        for i in range(cells_x) {
            corners.append(lattice(seed, i, j));
        }
    }
    for y in range(h) {
        gy = float(y) * float(cells_y) / float(h);
        j0 = int(gy);
        ty = smooth(gy - float(j0));
        j1 = (j0 + 1) % cells_y;
        row0 = j0 * cells_x;
        row1 = j1 * cells_x;
        for x in range(w) {
            gx = float(x) * float(cells_x) / float(w);
            i0 = int(gx);
            tx = smooth(gx - float(i0));
            i1 = (i0 + 1) % cells_x;
            top = corners[row0 + i0] * (1.0 - tx) + corners[row0 + i1] * tx;
            bottom = corners[row1 + i0] * (1.0 - tx) + corners[row1 + i1] * tx;
            made.v[y * w + x] = top * (1.0 - ty) + bottom * ty;
        }
    }
    return made;
}

"""Fractal noise: `octaves` layers of value noise, each with twice the cells
of the one before and `keep` of its weight, from 0 to 1."""
def fbm(w: int, h: int, cells: int, octaves: int, keep: float, seed: int) -> Field {
    total = flat(w, h);
    weight = 1.0;
    sum_weight = 0.0;
    count = max(1, cells);
    for octave in range(max(1, octaves)) {
        layer = value_noise(w, h, count, max(1, count * h // max(1, w)), mix32(seed + octave * 7919));
        for i in range(w * h) {
            total.v[i] += layer.v[i] * weight;
        }
        sum_weight += weight;
        weight *= keep;
        count *= 2;
        if count > w {
            break;
        }
    }
    for i in range(w * h) {
        total.v[i] /= sum_weight;
    }
    return total;
}

"""Cellular noise: `count` points scattered across the field, and for each
texel the distance to the nearest (`near`) and to the next nearest
(`next`), in texels, wrapping; `cell` numbers the nearest point."""
obj Cells {
    has near: Field,
        next: Field,
        cell: list[int] = [];
}

def worley(w: int, h: int, count: int, seed: int) -> Cells {
    xs: list[float] = [];
    ys: list[float] = [];
    for k in range(max(1, count)) {
        xs.append(lattice(seed, k, 1) * float(w));
        ys.append(lattice(seed, k, 2) * float(h));
    }
    near = Field(w=w, h=h);
    next = Field(w=w, h=h);
    cell: list[int] = [0] * (w * h);
    hw = float(w) * 0.5;
    hh = float(h) * 0.5;
    for y in range(h) {
        for x in range(w) {
            best = 1.0e9;
            second = 1.0e9;
            owner = 0;
            for k in range(len(xs)) {
                dx = abs(float(x) - xs[k]);
                dy = abs(float(y) - ys[k]);
                if dx > hw {
                    dx = float(w) - dx;
                }
                if dy > hh {
                    dy = float(h) - dy;
                }
                d = dx * dx + dy * dy;
                if d < best {
                    second = best;
                    best = d;
                    owner = k;
                } elif d < second {
                    second = d;
                }
            }
            near.v[y * w + x] = math.sqrt(best);
            next.v[y * w + x] = math.sqrt(second);
            cell[y * w + x] = owner;
        }
    }
    return Cells(near=near, next=next, cell=cell);
}

"""Bricks in `rows` courses of `cols`, every other course set over by half a
brick: `height` is 1 on a brick's face falling to 0 in the mortar over
`mortar` texels; `brick` numbers each texel's brick (-1 in the mortar)."""
obj Courses {
    has height: Field,
        brick: list[int] = [];
}

def bricks(w: int, h: int, rows: int, cols: int, mortar: float, bevel: float, shift: float = 0.5) -> Courses {
    height = Field(w=w, h=h);
    brick: list[int] = [-1] * (w * h);
    tall = float(h) / float(max(1, rows));
    wide = float(w) / float(max(1, cols));
    for y in range(h) {
        row = int(float(y) / tall);
        in_y = float(y) + 0.5 - float(row) * tall;
        offset = (float(row % 2) * shift) * wide;
        for x in range(w) {
            px = (float(x) + 0.5 - offset) % float(w);
            col = int(px / wide);
            in_x = px - float(col) * wide;
            rim = min(min(in_x, wide - in_x), min(in_y, tall - in_y));
            if rim <= mortar * 0.5 {
                height.v[y * w + x] = 0.0;
            } else {
                height.v[y * w + x] = min(1.0, (rim - mortar * 0.5) / max(0.5, bevel));
                brick[y * w + x] = row * max(1, cols) + col % max(1, cols);
            }
        }
    }
    return Courses(height=height, brick=brick);
}

"""Panels: a grid of `nx` by `ny` plates, each raised over a bevel `bevel`
texels wide with a seam `seam` texels wide between them. Like bricks, but
square on and with every course in line."""
def panels(w: int, h: int, nx: int, ny: int, seam: float, bevel: float) -> Courses {
    return bricks(w, h, ny, nx, seam, bevel, 0.0);
}

"""Round bumps on a grid of `nx` by `ny`, each `radius` texels across, rising
to 1 at their middles; inset from the grid's corners by `inset` of a
cell."""
def rivets(w: int, h: int, nx: int, ny: int, radius: float, inset: float = 0.5) -> Field {
    made = Field(w=w, h=h);
    cw = float(w) / float(max(1, nx));
    ch = float(h) / float(max(1, ny));
    for y in range(h) {
        cy = (float(y) + 0.5) % ch;
        dy = cy - ch * inset;
        for x in range(w) {
            cx = (float(x) + 0.5) % cw;
            dx = cx - cw * inset;
            d = math.sqrt(dx * dx + dy * dy) / max(0.5, radius);
            if d < 1.0 {
                made.v[y * w + x] = math.sqrt(1.0 - d * d);
            }
        }
    }
    return made;
}

"""Stripes across the field: `count` of them along x (`across` False: along
y), a smooth wave from 0 to 1."""
def stripes(w: int, h: int, count: int, across: bool = True) -> Field {
    made = Field(w=w, h=h);
    for y in range(h) {
        for x in range(w) {
            along = float(x) / float(w) if across else float(y) / float(h);
            made.v[y * w + x] = 0.5 + 0.5 * math.sin(along * float(count) * 2.0 * math.pi);
        }
    }
    return made;
}

"""Each texel moved by the two fields `dx` and `dy` (each from 0 to 1, read
about their middle) times `amount` texels."""
def warp(source: Field, dx: Field, dy: Field, amount: float) -> Field {
    made = Field(w=source.w, h=source.h);
    for y in range(source.h) {
        for x in range(source.w) {
            i = y * source.w + x;
            made.v[i] = source.sample(
                float(x) + (dx.v[i] - 0.5) * amount, float(y) + (dy.v[i] - 0.5) * amount
            );
        }
    }
    return made;
}

"""The field softened: each texel the mean of the square `radius` texels
about it, wrapping (two passes, one each way)."""
def blur(source: Field, radius: int) -> Field {
    if radius <= 0 {
        return source;
    }
    w = source.w;
    h = source.h;
    across = Field(w=w, h=h);
    span = float(radius * 2 + 1);
    for y in range(h) {
        total = 0.0;
        for k in range(-radius, radius + 1) {
            total += source.at(k, y);
        }
        for x in range(w) {
            across.v[y * w + x] = total / span;
            total += source.at(x + radius + 1, y) - source.at(x - radius + w, y);
        }
    }
    made = Field(w=w, h=h);
    for x in range(w) {
        total = 0.0;
        for k in range(-radius, radius + 1) {
            total += across.at(x, k);
        }
        for y in range(h) {
            made.v[y * w + x] = total / span;
            total += across.at(x, y + radius + 1) - across.at(x, y - radius + h);
        }
    }
    return made;
}

"""Light on a height field from above and to the left, as the games' artists
lit their textures: 0.5 where the field is level, more on slopes facing the
light, less on those facing away. `depth` is how steep a step of 1 is."""
def shade(height: Field, depth: float) -> Field {
    made = Field(w=height.w, h=height.h);
    # The light comes from up and to the left, a little above the surface.
    lx = -0.55;
    ly = -0.55;
    lz = 0.63;
    for y in range(height.h) {
        for x in range(height.w) {
            sx = (height.at(x + 1, y) - height.at(x - 1 + height.w, y)) * depth;
            sy = (height.at(x, y + 1) - height.at(x, y - 1 + height.h)) * depth;
            nx = -sx;
            ny = -sy;
            length = math.sqrt(nx * nx + ny * ny + 1.0);
            lit = (nx * lx + ny * ly + lz) / length;
            made.v[y * height.w + x] = max(0.0, min(1.0, 0.5 + (lit - lz) * 0.9));
        }
    }
    return made;
}

"""Where the field bends inward: high in the creases between raised parts,
where dirt gathers."""
def creases(height: Field, radius: int) -> Field {
    soft = blur(height, radius);
    made = Field(w=height.w, h=height.h);
    for i in range(len(height.v)) {
        made.v[i] = max(0.0, min(1.0, (soft.v[i] - height.v[i]) * 4.0 + 0.0));
    }
    return made;
}

"""The field stretched to run from 0 to 1."""
def normalized(source: Field) -> Field {
    low = 1.0e9;
    high = -1.0e9;
    for value in source.v {
        low = min(low, value);
        high = max(high, value);
    }
    span = high - low;
    if span <= 1.0e-9 {
        return flat(source.w, source.h, 0.5);
    }
    return Field(w=source.w, h=source.h, v=[(value - low) / span for value in source.v]);
}

"""The field's values from `low` to `high` stretched to 0 to 1, clamped."""
def levels(source: Field, low: float, high: float) -> Field {
    span = max(1.0e-6, high - low);
    return Field(w=source.w, h=source.h, v=[max(0.0, min(1.0, (value - low) / span)) for value in source.v]);
}

"""Two fields mixed: `mode` add, multiply, max, min, screen, or mix (by
`amount`)."""
def combine(a: Field, b: Field, mode: str, amount: float = 0.5) -> Field {
    made = Field(w=a.w, h=a.h);
    for i in range(len(a.v)) {
        x = a.v[i];
        y = b.v[i % len(b.v)];
        if mode == "add" {
            made.v[i] = x + y * amount;
        } elif mode == "multiply" {
            made.v[i] = x * (1.0 - amount + y * amount);
        } elif mode == "max" {
            made.v[i] = max(x, y);
        } elif mode == "min" {
            made.v[i] = min(x, y);
        } elif mode == "screen" {
            made.v[i] = 1.0 - (1.0 - x) * (1.0 - y * amount);
        } else {
            made.v[i] = x * (1.0 - amount) + y * amount;
        }
    }
    return made;
}

"""Long thin marks along one direction (scratches, grain, streaks of rust
running down): noise stretched `stretch` times along y."""
def streaks(w: int, h: int, cells: int, stretch: int, seed: int) -> Field {
    return value_noise(w, h, max(1, cells), max(1, cells // max(1, stretch)), seed);
}

"""A number from 0 to 1 for a point of a three-dimensional lattice."""
def lattice3(seed: int, x: int, y: int, z: int) -> float {
    return float(mix32(seed ^ mix32((x & 1023) | ((y & 1023) << 10) | ((z & 1023) << 20)))) / 4294967296.0;
}

"""Value noise in three dimensions, from 0 to 1: what a sky is painted from,
read along the direction each texel of the sky box looks, so the box's sides
meet without a seam."""
def noise3(x: float, y: float, z: float, seed: int) -> float {
    fx = math.floor(x);
    fy = math.floor(y);
    fz = math.floor(z);
    ix = int(fx);
    iy = int(fy);
    iz = int(fz);
    tx = smooth(x - fx);
    ty = smooth(y - fy);
    tz = smooth(z - fz);
    c000 = lattice3(seed, ix, iy, iz);
    c100 = lattice3(seed, ix + 1, iy, iz);
    c010 = lattice3(seed, ix, iy + 1, iz);
    c110 = lattice3(seed, ix + 1, iy + 1, iz);
    c001 = lattice3(seed, ix, iy, iz + 1);
    c101 = lattice3(seed, ix + 1, iy, iz + 1);
    c011 = lattice3(seed, ix, iy + 1, iz + 1);
    c111 = lattice3(seed, ix + 1, iy + 1, iz + 1);
    a = c000 + (c100 - c000) * tx;
    b = c010 + (c110 - c010) * tx;
    c = c001 + (c101 - c001) * tx;
    d = c011 + (c111 - c011) * tx;
    e = a + (b - a) * ty;
    f = c + (d - c) * ty;
    return e + (f - e) * tz;
}

"""Fractal noise in three dimensions, from 0 to 1."""
def fbm3(x: float, y: float, z: float, octaves: int, keep: float, seed: int) -> float {
    total = 0.0;
    weight = 1.0;
    sum_weight = 0.0;
    scale = 1.0;
    for octave in range(max(1, octaves)) {
        total += noise3(x * scale + 100.0, y * scale + 100.0, z * scale + 100.0, mix32(seed + octave * 7919)) * weight;
        sum_weight += weight;
        weight *= keep;
        scale *= 2.0;
    }
    return total / sum_weight;
}
