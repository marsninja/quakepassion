"""Meshes built from shapes: boxes, tubes, cones, balls, rings, turned
profiles and extruded outlines, each laid on its own tile of the skin, so a
model's skin can paint each piece with a material of its own.

A `Shaper` gathers pieces into one mesh: points, triangles (anticlockwise
seen from outside, as the model editor keeps them) and a place on the skin
for each point. Each piece is placed by a frame: its middle, and the
directions its own x, y and z run along."""
import math;
import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh }

"""Where a piece stands: its middle and its three axes (unit length)."""
obj Frame {
    has at: Vec3 = Vec3(),
        x: Vec3 = Vec3(x=1.0),
        y: Vec3 = Vec3(y=1.0),
        z: Vec3 = Vec3(z=1.0);

    def place(local: Vec3) -> Vec3 {
        return self.at.add(self.x.scale(local.x)).add(self.y.scale(local.y)).add(self.z.scale(local.z));
    }
}

"""A frame at `at` whose z runs from `at` toward `toward`."""
def frame_along(at: Vec3, toward: Vec3) -> Frame {
    z = toward.sub(at);
    if z.length() < 1.0e-6 {
        return Frame(at=at);
    }
    z = z.normalized();
    helper = Vec3(z=1.0) if abs(z.z) < 0.9 else Vec3(x=1.0);
    x = helper.cross(z).normalized();
    y = z.cross(x).normalized();
    return Frame(at=at, x=x, y=y, z=z);
}

"""Which tile of the skin a piece is laid on, as the part of the skin's
width and height its corner and size take."""
obj Tile {
    has u: float = 0.0,
        v: float = 0.0,
        w: float = 1.0,
        h: float = 1.0;

    def uv(s: float, t: float) -> tuple[float, float] {
        # A margin keeps a piece from reading its neighbour's texels.
        m = 0.06;
        return (self.u + self.w * (m + s * (1.0 - 2.0 * m)), self.v + self.h * (m + t * (1.0 - 2.0 * m)));
    }
}

"""The tile of `index` in a skin cut into a grid of `columns` by `rows`."""
def grid_tile(index: int, columns: int, rows: int) -> Tile {
    return Tile(
        u=float(index % columns) / float(columns), v=float((index // columns) % rows) / float(rows),
        w=1.0 / float(columns), h=1.0 / float(rows)
    );
}

obj Shaper {
    has points: list[Vec3] = [],
        corners: list[int] = [],
        uvs: list[float] = [];

    def point(at: Vec3, tile: Tile, s: float, t: float) -> int {
        self.points.append(at);
        (u, v) = tile.uv(s, t);
        self.uvs.append(u);
        self.uvs.append(v);
        return len(self.points) - 1;
    }

    def triangle(a: int, b: int, c: int) {
        self.corners.extend([a, b, c]);
    }

    """Four points as two triangles, anticlockwise a, b, c, d."""
    def quad(a: int, b: int, c: int, d: int) {
        self.triangle(a, b, c);
        self.triangle(a, c, d);
    }

    def mesh -> Mesh {
        return Mesh(points=list(self.points), corners=list(self.corners), uvs=list(self.uvs));
    }

    """A box `size` (whole lengths) about the frame's middle."""
    def box(frame: Frame, size: Vec3, tile: Tile) {
        hx = size.x * 0.5;
        hy = size.y * 0.5;
        hz = size.z * 0.5;
        # Each side: its outward axis and the two that run across it.
        sides: list[tuple[Vec3, Vec3, Vec3]] = [
            (Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)), (Vec3(x=-1.0), Vec3(y=-1.0), Vec3(z=1.0)),
            (Vec3(y=1.0), Vec3(x=-1.0), Vec3(z=1.0)), (Vec3(y=-1.0), Vec3(x=1.0), Vec3(z=1.0)),
            (Vec3(z=1.0), Vec3(x=1.0), Vec3(y=1.0)), (Vec3(z=-1.0), Vec3(x=-1.0), Vec3(y=1.0))
        ];
        for (out, across, up) in sides {
            corners: list[int] = [];
            for (s, t) in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)] {
                local = Vec3(
                    x=(out.x + across.x * (s * 2.0 - 1.0) + up.x * (t * 2.0 - 1.0)) * hx,
                    y=(out.y + across.y * (s * 2.0 - 1.0) + up.y * (t * 2.0 - 1.0)) * hy,
                    z=(out.z + across.z * (s * 2.0 - 1.0) + up.z * (t * 2.0 - 1.0)) * hz
                );
                corners.append(self.point(frame.place(local), tile, s, 1.0 - t));
            }
            self.quad(corners[0], corners[1], corners[2], corners[3]);
        }
    }

    """A turned shape: a profile of (radius, height) pairs from the bottom up,
    turned about the frame's z in `segments` steps; capped at either end
    whose radius is not nothing."""
    def lathe(frame: Frame, profile: list[tuple[float, float]], segments: int, tile: Tile, squash: float = 1.0) {
        rings: list[list[int]] = [];
        count = len(profile);
        for k in range(count) {
            (radius, height) = profile[k];
            ring: list[int] = [];
            for j in range(segments + 1) {
                angle = float(j) / float(segments) * 2.0 * math.pi;
                local = Vec3(x=math.cos(angle) * radius, y=math.sin(angle) * radius * squash, z=height);
                ring.append(self.point(frame.place(local), tile, float(j) / float(segments), 1.0 - float(k) / float(max(1, count - 1))));
            }
            rings.append(ring);
        }
        for k in range(count - 1) {
            for j in range(segments) {
                self.quad(rings[k][j], rings[k][j + 1], rings[k + 1][j + 1], rings[k + 1][j]);
            }
        }
        for (end, top) in [(0, False), (count - 1, True)] {
            (radius, height) = profile[end];
            if radius <= 1.0e-4 {
                continue;
            }
            middle = self.point(frame.place(Vec3(z=height)), tile, 0.5, 0.5);
            for j in range(segments) {
                if top {
                    self.triangle(rings[end][j], rings[end][j + 1], middle);
                } else {
                    self.triangle(rings[end][j + 1], rings[end][j], middle);
                }
            }
        }
    }

    """A tube from the frame's middle along its z for `length`, from radius
    `r0` to `r1`."""
    def tube(frame: Frame, length: float, r0: float, r1: float, segments: int, tile: Tile) {
        self.lathe(frame, [(r0, 0.0), (r1, length)], segments, tile);
    }

    """A ball of radii `radii` about the frame's middle; `bumps` (a function's
    stand-in: a list of offsets by ring and segment) roughens it."""
    def ball(frame: Frame, radii: Vec3, rings: int, segments: int, tile: Tile, roughness: float = 0.0, seed: int = 0) {
        profile: list[tuple[float, float]] = [];
        for k in range(rings + 1) {
            a = math.pi * (float(k) / float(rings) - 0.5);
            profile.append((math.cos(a), math.sin(a)));
        }
        start = len(self.points);
        squashed = Frame(at=frame.at, x=frame.x.scale(radii.x), y=frame.y.scale(radii.y), z=frame.z.scale(radii.z));
        self.lathe(squashed, profile, segments, tile);
        if roughness > 0.0 {
            for i in range(start, len(self.points)) {
                offset = self.points[i].sub(frame.at);
                n = float((i * 2654435761 + seed) % 1000) / 1000.0 - 0.5;
                self.points[i] = frame.at.add(offset.scale(1.0 + n * roughness));
            }
        }
    }

    """A ring (a torus) about the frame's z: `major` its radius, `minor` its
    thickness."""
    def ring(frame: Frame, major: float, minor: float, segments: int, sides: int, tile: Tile) {
        grid: list[list[int]] = [];
        for j in range(segments + 1) {
            a = float(j) / float(segments) * 2.0 * math.pi;
            row: list[int] = [];
            for k in range(sides + 1) {
                b = float(k) / float(sides) * 2.0 * math.pi;
                radius = major + math.cos(b) * minor;
                local = Vec3(x=math.cos(a) * radius, y=math.sin(a) * radius, z=math.sin(b) * minor);
                row.append(self.point(frame.place(local), tile, float(j) / float(segments), float(k) / float(sides)));
            }
            grid.append(row);
        }
        for j in range(segments) {
            for k in range(sides) {
                self.quad(grid[j][k], grid[j + 1][k], grid[j + 1][k + 1], grid[j][k + 1]);
            }
        }
    }

    """An outline (x, y pairs, anticlockwise) extruded `depth` along the
    frame's z, about its middle."""
    def slab(frame: Frame, outline: list[tuple[float, float]], depth: float, tile: Tile) {
        count = len(outline);
        if count < 3 {
            return;
        }
        low_x = min([p[0] for p in outline]);
        high_x = max([p[0] for p in outline]);
        low_y = min([p[1] for p in outline]);
        high_y = max([p[1] for p in outline]);
        span_x = max(1.0e-4, high_x - low_x);
        span_y = max(1.0e-4, high_y - low_y);
        top: list[int] = [];
        bottom: list[int] = [];
        for (x, y) in outline {
            s = (x - low_x) / span_x;
            t = 1.0 - (y - low_y) / span_y;
            top.append(self.point(frame.place(Vec3(x=x, y=y, z=depth * 0.5)), tile, s, t));
            bottom.append(self.point(frame.place(Vec3(x=x, y=y, z=-depth * 0.5)), tile, s, t));
        }
        # The faces as fans (the outlines are kept convex enough for that).
        for k in range(1, count - 1) {
            self.triangle(top[0], top[k], top[k + 1]);
            self.triangle(bottom[0], bottom[k + 1], bottom[k]);
        }
        for k in range(count) {
            n = (k + 1) % count;
            self.quad(bottom[k], bottom[n], top[n], top[k]);
        }
    }
}
