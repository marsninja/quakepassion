"""The massing: the level as a grid of cells, each solid or the air of one
space (a room or a corridor), 32 units across and 16 up.

Spaces and corridors carve air into it, and may put solid back (balcony
slabs, pillars, stairs). What stands is turned into brushes by keeping only
the solid that touches air (a shell a cell thick, diagonals included, so the
world is sealed) and merging it greedily into boxes. Each shell cell belongs
to the space whose air it touches, and a box holds cells of one space only,
so each brush can take its materials from the space it faces."""
import math;
import from engine.math.vec3 { Vec3 }

glob CELL: float = 32.0,
     LIFT: float = 16.0;

"""A box of cells, `low` inclusive and `high` exclusive, with the space it
belongs to."""
obj CellBox {
    has x0: int,
        y0: int,
        z0: int,
        x1: int,
        y1: int,
        z1: int,
        owner: int = 0;

    """Its low corner in world units."""
    def low -> Vec3 {
        return Vec3(x=float(self.x0) * CELL, y=float(self.y0) * CELL, z=float(self.z0) * LIFT);
    }

    """Its high corner in world units."""
    def high -> Vec3 {
        return Vec3(x=float(self.x1) * CELL, y=float(self.y1) * CELL, z=float(self.z1) * LIFT);
    }
}

"""The grid. `owner` holds for each cell 0 (solid) or the number of the
space whose air it is (space id + 1)."""
obj Massing {
    has nx: int,
        ny: int,
        nz: int,
        owner: list[int] = [];

    def postinit {
        if len(self.owner) != self.nx * self.ny * self.nz {
            self.owner = [0 for _ in range(self.nx * self.ny * self.nz)];
        }
    }

    def inside(x: int, y: int, z: int) -> bool {
        return 0 <= x < self.nx and 0 <= y < self.ny and 0 <= z < self.nz;
    }

    def at(x: int, y: int, z: int) -> int {
        if not self.inside(x, y, z) {
            return 0;
        }
        return self.owner[(z * self.ny + y) * self.nx + x];
    }

    def air(x: int, y: int, z: int) -> bool {
        return self.at(x, y, z) > 0;
    }

    def put(x: int, y: int, z: int, value: int) {
        if self.inside(x, y, z) {
            self.owner[(z * self.ny + y) * self.nx + x] = value;
        }
    }

    """Make a box of cells the air of space `space` (an id, or -1 to make it
    solid again). Bounds are clipped to the grid."""
    def carve(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, space: int) {
        value = space + 1 if space >= 0 else 0;
        for z in range(max(0, z0), min(self.nz, z1)) {
            for y in range(max(0, y0), min(self.ny, y1)) {
                base = (z * self.ny + y) * self.nx;
                for x in range(max(0, x0), min(self.nx, x1)) {
                    self.owner[base + x] = value;
                }
            }
        }
    }

    """Solid again (a slab, a pillar, a step)."""
    def fill(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) {
        self.carve(x0, y0, z0, x1, y1, z1, -1);
    }

    """Whether a box of cells is all solid (nothing carved there yet)."""
    def solid_box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) -> bool {
        if x0 < 0 or y0 < 0 or z0 < 0 or x1 > self.nx or y1 > self.ny or z1 > self.nz {
            return False;
        }
        for z in range(z0, z1) {
            for y in range(y0, y1) {
                base = (z * self.ny + y) * self.nx;
                for x in range(x0, x1) {
                    if self.owner[base + x] > 0 {
                        return False;
                    }
                }
            }
        }
        return True;
    }

    """The space a solid cell faces: the owner of the air beside it (sides
    first, then above and below, then the diagonals), or 0 when it touches
    no air."""
    def facing(x: int, y: int, z: int) -> int {
        for (dx, dy, dz) in [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)] {
            seen = self.at(x + dx, y + dy, z + dz);
            if seen > 0 {
                return seen;
            }
        }
        for dz in [-1, 0, 1] {
            for dy in [-1, 0, 1] {
                for dx in [-1, 0, 1] {
                    seen = self.at(x + dx, y + dy, z + dz);
                    if seen > 0 {
                        return seen;
                    }
                }
            }
        }
        return 0;
    }

    """The solid that touches air, merged into boxes, each of one space."""
    def shell -> list[CellBox] {
        count = self.nx * self.ny * self.nz;
        mark = [0 for _ in range(count)];
        # Every solid cell beside air (diagonals too) is shell: grown out from
        # the air, the solid a face away taking that air's space first.
        for pass_index in range(2) {
            for z in range(self.nz) {
                for y in range(self.ny) {
                    for x in range(self.nx) {
                        space = self.owner[(z * self.ny + y) * self.nx + x];
                        if space == 0 {
                            continue;
                        }
                        for dz in [-1, 0, 1] {
                            for dy in [-1, 0, 1] {
                                for dx in [-1, 0, 1] {
                                    face = abs(dx) + abs(dy) + abs(dz) == 1;
                                    if face != (pass_index == 0) {
                                        continue;
                                    }
                                    cx = x + dx;
                                    cy = y + dy;
                                    cz = z + dz;
                                    if cx < 0 or cy < 0 or cz < 0 or cx >= self.nx or cy >= self.ny or cz >= self.nz {
                                        continue;
                                    }
                                    index = (cz * self.ny + cy) * self.nx + cx;
                                    if self.owner[index] == 0 and mark[index] == 0 {
                                        mark[index] = space;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        boxes: list[CellBox] = [];
        for z in range(self.nz) {
            for y in range(self.ny) {
                for x in range(self.nx) {
                    index = (z * self.ny + y) * self.nx + x;
                    space = mark[index];
                    if space <= 0 {
                        continue;
                    }
                    # Grow along x, then y, then z while every cell matches.
                    x1 = x + 1;
                    while x1 < self.nx and mark[(z * self.ny + y) * self.nx + x1] == space {
                        x1 += 1;
                    }
                    y1 = y + 1;
                    growing = True;
                    while growing and y1 < self.ny {
                        for cx in range(x, x1) {
                            if mark[(z * self.ny + y1) * self.nx + cx] != space {
                                growing = False;
                            }
                        }
                        if growing {
                            y1 += 1;
                        }
                    }
                    z1 = z + 1;
                    growing = True;
                    while growing and z1 < self.nz {
                        for cy in range(y, y1) {
                            for cx in range(x, x1) {
                                if mark[(z1 * self.ny + cy) * self.nx + cx] != space {
                                    growing = False;
                                }
                            }
                        }
                        if growing {
                            z1 += 1;
                        }
                    }
                    for cz in range(z, z1) {
                        for cy in range(y, y1) {
                            for cx in range(x, x1) {
                                mark[(cz * self.ny + cy) * self.nx + cx] = 0;
                            }
                        }
                    }
                    boxes.append(CellBox(x0=x, y0=y, z0=z, x1=x1, y1=y1, z1=z1, owner=space - 1));
                }
            }
        }
        return boxes;
    }

    """How many cells of air are open straight above a cell (headroom in
    cells), counting from the cell itself."""
    def headroom(x: int, y: int, z: int) -> int {
        count = 0;
        while self.air(x, y, z + count) {
            count += 1;
        }
        return count;
    }

    """Whether a cell is floor to stand on: air with solid under it."""
    def standing(x: int, y: int, z: int) -> bool {
        return self.air(x, y, z) and not self.air(x, y, z - 1);
    }
}

"""A cell's middle in world units, standing on its floor."""
def cell_floor(x: int, y: int, z: int) -> Vec3 {
    return Vec3(x=(float(x) + 0.5) * CELL, y=(float(y) + 0.5) * CELL, z=float(z) * LIFT);
}

"""Floor reachable from a cell by walking: standing cells with room for a
body (four lifts), joined to their four neighbours when those are at most a
lift higher (a step) or any height lower (a drop). Answers the reached
cells' indices."""
def floor_reached(mass: Massing, x: int, y: int, z: int, links: list[list[int]] = []) -> dict[int, bool] {
    reached: dict[int, bool] = {};
    # Extra ways (teleporters): from one cell to another, [x0, y0, z0, x1, y1, z1].
    jumps: dict[int, list[int]] = {};
    for link in links {
        jumps[(link[2] * mass.ny + link[1]) * mass.nx + link[0]] = [link[3], link[4], link[5]];
    }
    todo: list[list[int]] = [[x, y, z]];
    while todo {
        cell = todo.pop();
        cx = cell[0];
        cy = cell[1];
        cz = cell[2];
        index = (cz * mass.ny + cy) * mass.nx + cx;
        if index in reached or not mass.standing(cx, cy, cz) or mass.headroom(cx, cy, cz) < 4 {
            continue;
        }
        reached[index] = True;
        if index in jumps {
            todo.append(jumps[index]);
        }
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            nx = cx + dx;
            ny = cy + dy;
            if mass.standing(nx, ny, cz + 1) and mass.headroom(cx, cy, cz) >= 5 {
                todo.append([nx, ny, cz + 1]);
            }
            # Level, or down until a floor (only through air).
            fall = cz;
            while fall > 0 and mass.air(nx, ny, fall) and not mass.standing(nx, ny, fall) {
                fall -= 1;
            }
            if mass.standing(nx, ny, fall) {
                todo.append([nx, ny, fall]);
            }
        }
    }
    return reached;
}
