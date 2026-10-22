"""Sculpted models: shapes as signed distances, joined smoothly and made a
mesh.

A model is sculpted from `Prim` nodes, each a solid with a place and turn
of its own (an ellipsoid, a tapered capsule, a rounded box, a capped
cylinder, a ring), a material, how softly it melts into what it touches
(`blend`), how lumpy its skin is (`bumps`) and whether it cuts away instead
of adding (`carve`). Their distances are joined by a smooth minimum, so a
shoulder runs into an arm and a barrel into its housing the way modelled
ones do, not as separate tubes.

The solid is made a mesh by surface nets: a grid over its bounds, a point
in every cell the surface passes through (where the surface crosses the
cell's edges, on average), and a face across every grid edge the surface
crosses. The grid is made coarser until the mesh fits the budget a model
format allows. Each point keeps its material (the solid nearest it), a
place on its material's tile (projected along the surface's facing), and
the two solids nearest it with how much each holds it, so a skinned model
can carry each point with the bones its solids ride on."""
import math;
import from engine.math.vec3 { Vec3 }
import from .field { noise3 }

"""A solid of a sculpture, placed at rest: `at` its middle (a capsule's
first end), `to` a capsule's other end, `x`, `y`, `z` its axes; `size` its
radii (an ellipsoid), half lengths (a box), radius and half length (a
cylinder, along z) or ring and tube radius (a ring about z); `r1`, `r2` a
capsule's radii at its ends; `round` a box's or cylinder's rounding; and
`owner` the bone (or part) it rides on."""
node Prim {
    has kind: str = "ellipsoid",
        material: str = "steel",
        at: Vec3 = Vec3(),
        to: Vec3 = Vec3(),
        x: Vec3 = Vec3(x=1.0),
        y: Vec3 = Vec3(y=1.0),
        z: Vec3 = Vec3(z=1.0),
        size: Vec3 = Vec3(x=0.1, y=0.1, z=0.1),
        r1: float = 0.05,
        r2: float = 0.05,
        round: float = 0.0,
        blend: float = 0.02,
        bumps: float = 0.0,
        carve: bool = False,
        owner: int = 0,
        lo: Vec3 = Vec3(),
        hi: Vec3 = Vec3();

    """Its box, grown by its blend and bumps (outside it, it adds nothing)."""
    def bound {
        reach = 0.0;
        if self.kind == "capsule" {
            reach = max(self.r1, self.r2);
            self.lo = Vec3(x=min(self.at.x, self.to.x) - reach, y=min(self.at.y, self.to.y) - reach, z=min(self.at.z, self.to.z) - reach);
            self.hi = Vec3(x=max(self.at.x, self.to.x) + reach, y=max(self.at.y, self.to.y) + reach, z=max(self.at.z, self.to.z) + reach);
        } else {
            if self.kind == "ring" {
                reach = self.size.x + self.size.y;
            } elif self.kind == "cylinder" {
                reach = math.sqrt(self.size.x * self.size.x + self.size.y * self.size.y);
            } else {
                reach = math.sqrt(self.size.x * self.size.x + self.size.y * self.size.y + self.size.z * self.size.z);
            }
            self.lo = self.at.sub(Vec3(x=reach, y=reach, z=reach));
            self.hi = self.at.add(Vec3(x=reach, y=reach, z=reach));
        }
        grow = self.blend * 2.0 + self.bumps * 2.0;
        self.lo = self.lo.sub(Vec3(x=grow, y=grow, z=grow));
        self.hi = self.hi.add(Vec3(x=grow, y=grow, z=grow));
    }

    def holds(p: Vec3) -> bool {
        return p.x >= self.lo.x and p.y >= self.lo.y and p.z >= self.lo.z and p.x <= self.hi.x and p.y <= self.hi.y and p.z <= self.hi.z;
    }

    """How far `p` is from its surface (below zero inside)."""
    def distance(p: Vec3) -> float {
        if self.kind == "capsule" {
            pa = p.sub(self.at);
            ba = self.to.sub(self.at);
            h = max(0.0, min(1.0, pa.dot(ba) / max(1.0e-9, ba.dot(ba))));
            return pa.sub(ba.scale(h)).length() - (self.r1 + (self.r2 - self.r1) * h);
        }
        d = p.sub(self.at);
        lx = d.dot(self.x);
        ly = d.dot(self.y);
        lz = d.dot(self.z);
        if self.kind == "box" {
            qx = abs(lx) - self.size.x + self.round;
            qy = abs(ly) - self.size.y + self.round;
            qz = abs(lz) - self.size.z + self.round;
            outside = math.sqrt(max(qx, 0.0) ** 2 + max(qy, 0.0) ** 2 + max(qz, 0.0) ** 2);
            return outside + min(max(qx, max(qy, qz)), 0.0) - self.round;
        }
        if self.kind == "cylinder" {
            dx = math.sqrt(lx * lx + ly * ly) - self.size.x + self.round;
            dz = abs(lz) - self.size.y + self.round;
            return min(max(dx, dz), 0.0) + math.sqrt(max(dx, 0.0) ** 2 + max(dz, 0.0) ** 2) - self.round;
        }
        if self.kind == "ring" {
            qx = math.sqrt(lx * lx + ly * ly) - self.size.x;
            return math.sqrt(qx * qx + lz * lz) - self.size.y;
        }
        # An ellipsoid (Inigo Quilez's bound).
        ex = lx / max(1.0e-6, self.size.x);
        ey = ly / max(1.0e-6, self.size.y);
        ez = lz / max(1.0e-6, self.size.z);
        k0 = math.sqrt(ex * ex + ey * ey + ez * ez);
        fx = lx / max(1.0e-9, self.size.x * self.size.x);
        fy = ly / max(1.0e-9, self.size.y * self.size.y);
        fz = lz / max(1.0e-9, self.size.z * self.size.z);
        k1 = math.sqrt(fx * fx + fy * fy + fz * fz);
        return k0 * (k0 - 1.0) / max(1.0e-9, k1);
    }
}

"""Axes turned by roll (about x), pitch (about y) and yaw (about z),
degrees, from `x`, `y`, `z`."""
def turned_axes(x: Vec3, y: Vec3, z: Vec3, roll: float, pitch: float, yaw: float) -> list[Vec3] {
    r = math.radians(roll);
    p = math.radians(pitch);
    w = math.radians(yaw);
    made: list[Vec3] = [];
    for local in [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)] {
        a = Vec3(x=local.x, y=local.y * math.cos(r) - local.z * math.sin(r), z=local.y * math.sin(r) + local.z * math.cos(r));
        b = Vec3(x=a.x * math.cos(p) + a.z * math.sin(p), y=a.y, z=-a.x * math.sin(p) + a.z * math.cos(p));
        c = Vec3(x=b.x * math.cos(w) - b.y * math.sin(w), y=b.x * math.sin(w) + b.y * math.cos(w), z=b.z);
        made.append(x.scale(c.x).add(y.scale(c.y)).add(z.scale(c.z)));
    }
    return made;
}

"""The smooth minimum of two distances: `k` how wide the fillet between
them is."""
def smooth_min(a: float, b: float, k: float) -> float {
    if k <= 1.0e-6 {
        return min(a, b);
    }
    h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

"""What a sculpture comes to as a mesh: points, triangles (three point
numbers each), each point's material, its place on its material's tile
(s, t from 0 to 1), its facing, and the two solids that hold it most with
their shares."""
obj SculptMesh {
    has points: list[Vec3] = [],
        corners: list[int] = [],
        materials: list[str] = [],
        tiles: list[float] = [],
        facings: list[Vec3] = [],
        holders: list[int] = [],
        shares: list[float] = [];
}

"""A sculpture: its solids, and the grid it is sampled on."""
obj Sculpture {
    has prims: list[Prim] = [],
        seed: int = 1;

    """How far `p` is from the whole (below zero inside)."""
    def distance(p: Vec3) -> float {
        d = 1.0e9;
        for prim in self.prims {
            if prim.carve or not prim.holds(p) {
                continue;
            }
            solid = prim.distance(p);
            if prim.bumps > 0.0 {
                solid += prim.bumps * (noise3(p.x * 9.0, p.y * 9.0, p.z * 9.0, self.seed) - 0.5) * 2.0;
            }
            d = smooth_min(d, solid, prim.blend);
        }
        for prim in self.prims {
            if prim.carve and prim.holds(p) {
                d = max(d, -prim.distance(p));
            }
        }
        return d;
    }

    """The facing of the surface at `p` (the distance's gradient)."""
    def facing(p: Vec3, step: float) -> Vec3 {
        gx = self.distance(p.add(Vec3(x=step))) - self.distance(p.sub(Vec3(x=step)));
        gy = self.distance(p.add(Vec3(y=step))) - self.distance(p.sub(Vec3(y=step)));
        gz = self.distance(p.add(Vec3(z=step))) - self.distance(p.sub(Vec3(z=step)));
        length = math.sqrt(gx * gx + gy * gy + gz * gz);
        if length < 1.0e-9 {
            return Vec3(z=1.0);
        }
        return Vec3(x=gx / length, y=gy / length, z=gz / length);
    }

    """The sculpture as a mesh of at most `budget` points, sampled
    `cells` cells along its longest side (fewer when that is too many)."""
    def mesh(budget: int, cells: int = 44) -> SculptMesh {
        for prim in self.prims {
            prim.bound();
        }
        lo = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
        hi = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
        for prim in self.prims {
            if not prim.carve {
                lo = Vec3(x=min(lo.x, prim.lo.x), y=min(lo.y, prim.lo.y), z=min(lo.z, prim.lo.z));
                hi = Vec3(x=max(hi.x, prim.hi.x), y=max(hi.y, prim.hi.y), z=max(hi.z, prim.hi.z));
            }
        }
        count = cells;
        made = SculptMesh();
        span = hi.sub(lo);
        while count >= 8 {
            # Nothing thinner than most of a cell, or the net loses it (a
            # blade, a dog's leg broken into pieces).
            self.thicken(max(span.x, max(span.y, span.z)) / float(count) * 0.8);
            made = self.nets(lo, hi, count);
            if len(made.points) <= budget {
                break;
            }
            count = int(float(count) * 0.85);
        }
        return made;
    }

    """Every solid at least `least` thick (radius, half length) every way."""
    def thicken(least: float) {
        for prim in self.prims {
            if prim.carve {
                continue;
            }
            if prim.kind == "capsule" {
                prim.r1 = max(prim.r1, least);
                prim.r2 = max(prim.r2, least * 0.75);
            } elif prim.kind == "ring" {
                prim.size = Vec3(x=prim.size.x, y=max(prim.size.y, least * 0.75), z=prim.size.z);
            } elif prim.kind == "cylinder" {
                prim.size = Vec3(x=max(prim.size.x, least), y=max(prim.size.y, least), z=prim.size.z);
            } else {
                prim.size = Vec3(x=max(prim.size.x, least), y=max(prim.size.y, least), z=max(prim.size.z, least));
            }
        }
    }

    """Surface nets over the box `lo`..`hi`, `count` cells along its longest
    side."""
    def nets(lo: Vec3, hi: Vec3, count: int) -> SculptMesh {
        span = hi.sub(lo);
        cell = max(span.x, max(span.y, span.z)) / float(count);
        nx = max(2, int(span.x / cell) + 2);
        ny = max(2, int(span.y / cell) + 2);
        nz = max(2, int(span.z / cell) + 2);
        origin = lo.sub(Vec3(x=cell * 0.5, y=cell * 0.5, z=cell * 0.5));
        # The distance at every grid corner.
        values: list[float] = [0.0] * ((nx + 1) * (ny + 1) * (nz + 1));
        for k in range(nz + 1) {
            for j in range(ny + 1) {
                for i in range(nx + 1) {
                    values[(k * (ny + 1) + j) * (nx + 1) + i] = self.distance(Vec3(x=origin.x + float(i) * cell, y=origin.y + float(j) * cell, z=origin.z + float(k) * cell));
                }
            }
        }
        made = SculptMesh();
        cell_point: list[int] = [-1] * (nx * ny * nz);
        corner_steps = [(0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0), (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1)];
        edges = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)];
        for k in range(nz) {
            for j in range(ny) {
                for i in range(nx) {
                    inside = 0;
                    corner_values: list[float] = [];
                    for (di, dj, dk) in corner_steps {
                        value = values[((k + dk) * (ny + 1) + j + dj) * (nx + 1) + i + di];
                        corner_values.append(value);
                        if value < 0.0 {
                            inside += 1;
                        }
                    }
                    if inside == 0 or inside == 8 {
                        continue;
                    }
                    sx = 0.0;
                    sy = 0.0;
                    sz = 0.0;
                    crossings = 0;
                    for (a, b) in edges {
                        va = corner_values[a];
                        vb = corner_values[b];
                        if (va < 0.0) != (vb < 0.0) {
                            t = va / (va - vb);
                            (ai, aj, ak) = corner_steps[a];
                            (bi, bj, bk) = corner_steps[b];
                            sx += float(ai) + (float(bi) - float(ai)) * t;
                            sy += float(aj) + (float(bj) - float(aj)) * t;
                            sz += float(ak) + (float(bk) - float(ak)) * t;
                            crossings += 1;
                        }
                    }
                    point = Vec3(
                        x=origin.x + (float(i) + sx / float(crossings)) * cell,
                        y=origin.y + (float(j) + sy / float(crossings)) * cell,
                        z=origin.z + (float(k) + sz / float(crossings)) * cell
                    );
                    cell_point[(k * ny + j) * nx + i] = len(made.points);
                    made.points.append(point);
                }
            }
        }
        # A face across each grid edge the surface crosses, joining the four
        # cells round it.
        for k in range(1, nz) {
            for j in range(1, ny) {
                for i in range(nx) {
                    self.face(made, values, cell_point, nx, ny, i, j, k, 0);
                }
            }
        }
        for k in range(1, nz) {
            for j in range(ny) {
                for i in range(1, nx) {
                    self.face(made, values, cell_point, nx, ny, i, j, k, 1);
                }
            }
        }
        for k in range(nz) {
            for j in range(1, ny) {
                for i in range(1, nx) {
                    self.face(made, values, cell_point, nx, ny, i, j, k, 2);
                }
            }
        }
        self.dress(made, cell);
        return made;
    }

    """The quad across the grid edge from corner (i, j, k) along `axis` (0 x,
    1 y, 2 z), if the surface crosses it, wound to face outward."""
    def face(made: SculptMesh, values: list[float], cell_point: list[int], nx: int, ny: int, i: int, j: int, k: int, axis: int) {
        a = values[(k * (ny + 1) + j) * (nx + 1) + i];
        b = 0.0;
        cells: list[int] = [];
        if axis == 0 {
            b = values[(k * (ny + 1) + j) * (nx + 1) + i + 1];
            cells = [(k - 1) * ny * nx + (j - 1) * nx + i, (k - 1) * ny * nx + j * nx + i, k * ny * nx + j * nx + i, k * ny * nx + (j - 1) * nx + i];
        } elif axis == 1 {
            b = values[(k * (ny + 1) + j + 1) * (nx + 1) + i];
            cells = [(k - 1) * ny * nx + j * nx + i - 1, k * ny * nx + j * nx + i - 1, k * ny * nx + j * nx + i, (k - 1) * ny * nx + j * nx + i];
        } else {
            b = values[((k + 1) * (ny + 1) + j) * (nx + 1) + i];
            cells = [k * ny * nx + (j - 1) * nx + i - 1, k * ny * nx + (j - 1) * nx + i, k * ny * nx + j * nx + i, k * ny * nx + j * nx + i - 1];
        }
        if (a < 0.0) == (b < 0.0) {
            return;
        }
        quad: list[int] = [];
        for c in cells {
            if c < 0 or c >= len(cell_point) or cell_point[c] < 0 {
                return;
            }
            quad.append(cell_point[c]);
        }
        if a >= 0.0 {
            quad = [quad[0], quad[3], quad[2], quad[1]];
        }
        made.corners.extend([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]);
    }

    """Each point's facing, material, tile place and holders; triangles
    turned to face out where the grid's winding was wrong."""
    def dress(made: SculptMesh, cell: float) {
        lo = Vec3(x=1.0e9, y=1.0e9, z=1.0e9);
        hi = Vec3(x=-1.0e9, y=-1.0e9, z=-1.0e9);
        for p in made.points {
            lo = Vec3(x=min(lo.x, p.x), y=min(lo.y, p.y), z=min(lo.z, p.z));
            hi = Vec3(x=max(hi.x, p.x), y=max(hi.y, p.y), z=max(hi.z, p.z));
        }
        span = hi.sub(lo);
        for p in made.points {
            facing = self.facing(p, cell * 0.5);
            made.facings.append(facing);
            best = -1;
            best_d = 1.0e9;
            second = -1;
            second_d = 1.0e9;
            for (n, prim) in enumerate(self.prims) {
                if prim.carve {
                    continue;
                }
                d = prim.distance(p);
                if d < best_d {
                    second = best;
                    second_d = best_d;
                    best = n;
                    best_d = d;
                } elif d < second_d {
                    second = n;
                    second_d = d;
                }
            }
            made.materials.append(self.prims[best].material if best >= 0 else "steel");
            # Each holder's share falls off with how much farther it is.
            soft = max(cell, 0.02 * max(span.x, max(span.y, span.z)));
            w2 = math.exp(-(second_d - best_d) / soft) if second >= 0 else 0.0;
            made.holders.extend([max(0, best), max(0, second)]);
            made.shares.extend([1.0 / (1.0 + w2), w2 / (1.0 + w2)]);
            # A place on the tile, projected along its strongest facing.
            ax = abs(facing.x);
            ay = abs(facing.y);
            az = abs(facing.z);
            u = 0.0;
            v = 0.0;
            if ax >= ay and ax >= az {
                u = (p.y - lo.y) / max(1.0e-6, span.y);
                v = (p.z - lo.z) / max(1.0e-6, span.z);
            } elif ay >= az {
                u = (p.x - lo.x) / max(1.0e-6, span.x);
                v = (p.z - lo.z) / max(1.0e-6, span.z);
            } else {
                u = (p.x - lo.x) / max(1.0e-6, span.x);
                v = (p.y - lo.y) / max(1.0e-6, span.y);
            }
            made.tiles.extend([0.04 + u * 0.92, 0.04 + (1.0 - v) * 0.92]);
        }
        for f in range(len(made.corners) // 3) {
            a = made.points[made.corners[f * 3]];
            b = made.points[made.corners[f * 3 + 1]];
            c = made.points[made.corners[f * 3 + 2]];
            normal = b.sub(a).cross(c.sub(a));
            out = made.facings[made.corners[f * 3]].add(made.facings[made.corners[f * 3 + 1]]).add(made.facings[made.corners[f * 3 + 2]]);
            if normal.dot(out) < 0.0 {
                keep = made.corners[f * 3 + 1];
                made.corners[f * 3 + 1] = made.corners[f * 3 + 2];
                made.corners[f * 3 + 2] = keep;
            }
        }
    }
}
