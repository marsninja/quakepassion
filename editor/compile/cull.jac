"""Buried faces: what of each brush side the world's other brushes cover.

The live compiler draws every side of every brush whole; where brushes
meet, much of that lies inside another brush or flat against one, never
seen yet drawn, stored and lit. The cutter keeps only the pieces of a side
outside every brush that reaches it, as qbsp does: a piece lying against
another brush's side that faces it is covered, and of two brushes' sides
lying in one plane facing the same way the earlier brush's is kept. Brushes
one can see through (clip, triggers, hints) cover nothing."""
import math;
import from engine.math.vec3 { Vec3 }
import from ..geometry.brush { Side }

glob CULL_EPSILON: float = 0.01,
     CULL_CELL: float = 256.0,
     # Pieces cut between a side's pauses.
     CUT_SLICE: int = 400;

"""The two pieces of a polygon either side of a plane: [front, back], each
empty when nothing lies there. Points on the plane go to both."""
def split_polygon(points: list[Vec3], normal: Vec3, dist: float) -> list[list[Vec3]] {
    sides: list[float] = [normal.dot(point) - dist for point in points];
    front: list[Vec3] = [];
    back: list[Vec3] = [];
    count = len(points);
    for index in range(count) {
        point = points[index];
        here = sides[index];
        if here >= -CULL_EPSILON {
            front.append(point);
        }
        if here <= CULL_EPSILON {
            back.append(point);
        }
        following = sides[(index + 1) % count];
        if (here > CULL_EPSILON and following < -CULL_EPSILON) or (here < -CULL_EPSILON and following > CULL_EPSILON) {
            share = here / (here - following);
            other = points[(index + 1) % count];
            cut = point.add(other.sub(point).scale(share));
            front.append(cut);
            back.append(cut);
        }
    }
    return [front if len(front) >= 3 else [], back if len(back) >= 3 else []];
}

"""Whether a polygon has any area worth keeping."""
def polygon_kept(points: list[Vec3]) -> bool {
    if len(points) < 3 {
        return False;
    }
    total = Vec3();
    for index in range(1, len(points) - 1) {
        total = total.add(points[index].sub(points[0]).cross(points[index + 1].sub(points[0])));
    }
    return total.length() > 0.5;
}

"""Cuts brush sides against the brushes around them."""
obj FaceCutter {
    has brushes: list[list[Side]] = [],
        lows: list[Vec3] = [],
        highs: list[Vec3] = [],
        buckets: dict[int, list[int]] = {};

    def cutter_key(ix: int, iy: int, iz: int) -> int {
        return ((ix + 2048) * 4096 + (iy + 2048)) * 4096 + (iz + 2048);
    }

    """Add a brush that covers what lies inside it (its index is the order
    added). `outlines` are its sides' windings."""
    def add(sides: list[Side], outlines: list[list[Vec3]]) -> int {
        index = len(self.brushes);
        far = 1000000.0;
        low = Vec3(x=far, y=far, z=far);
        high = Vec3(x=-far, y=-far, z=-far);
        for outline in outlines {
            for point in outline {
                low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
                high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
            }
        }
        self.brushes.append(sides);
        self.lows.append(low);
        self.highs.append(high);
        if low.x > high.x {
            return index;
        }
        for ix in range(int(math.floor(low.x / CULL_CELL)), int(math.floor(high.x / CULL_CELL)) + 1) {
            for iy in range(int(math.floor(low.y / CULL_CELL)), int(math.floor(high.y / CULL_CELL)) + 1) {
                for iz in range(int(math.floor(low.z / CULL_CELL)), int(math.floor(high.z / CULL_CELL)) + 1) {
                    key = self.cutter_key(ix, iy, iz);
                    if key not in self.buckets {
                        self.buckets[key] = [];
                    }
                    self.buckets[key].append(index);
                }
            }
        }
        return index;
    }

    """The brushes whose bounds reach a polygon's (touching counts)."""
    def near(points: list[Vec3], owner: int) -> list[int] {
        far = 1000000.0;
        low = Vec3(x=far, y=far, z=far);
        high = Vec3(x=-far, y=-far, z=-far);
        for point in points {
            low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
            high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
        }
        found: list[int] = [];
        seen: dict[int, bool] = {};
        for ix in range(int(math.floor((low.x - 1.0) / CULL_CELL)), int(math.floor((high.x + 1.0) / CULL_CELL)) + 1) {
            for iy in range(int(math.floor((low.y - 1.0) / CULL_CELL)), int(math.floor((high.y + 1.0) / CULL_CELL)) + 1) {
                for iz in range(int(math.floor((low.z - 1.0) / CULL_CELL)), int(math.floor((high.z + 1.0) / CULL_CELL)) + 1) {
                    for index in self.buckets.get(self.cutter_key(ix, iy, iz), []) {
                        if index == owner or index in seen {
                            continue;
                        }
                        seen[index] = True;
                        a = self.lows[index];
                        b = self.highs[index];
                        if a.x > high.x + CULL_EPSILON or b.x < low.x - CULL_EPSILON or a.y > high.y + CULL_EPSILON
                            or b.y < low.y - CULL_EPSILON or a.z > high.z + CULL_EPSILON or b.z < low.z - CULL_EPSILON {
                            continue;
                        }
                        found.append(index);
                    }
                }
            }
        }
        return found;
    }

    """The pieces of a polygon outside brush `other`, for a side of brush
    `owner` lying in the plane (`normal`, `dist`)."""
    def outside_of(points: list[Vec3], normal: Vec3, dist: float, owner: int, other: int) -> list[list[Vec3]] {
        outside: list[list[Vec3]] = [];
        remaining = points;
        for side in self.brushes[other] {
            plane = side.plane;
            along = normal.dot(plane.normal);
            if along > 0.9999 and abs(dist - plane.dist) < CULL_EPSILON {
                # In the same plane, facing the same way: the earlier brush's
                # side is the one kept.
                if other < owner {
                    continue;
                }
                outside.append(remaining);
                return outside;
            }
            if along < -0.9999 and abs(dist + plane.dist) < CULL_EPSILON {
                # Flat against a side that faces it: covered there.
                continue;
            }
            halves = split_polygon(remaining, plane.normal, plane.dist);
            if halves[0] and polygon_kept(halves[0]) {
                if not halves[1] {
                    outside.append(remaining);
                    return outside;
                }
                outside.append(halves[0]);
            }
            if not halves[1] {
                return outside;
            }
            remaining = halves[1];
        }
        # What is left lies inside the other brush.
        return outside;
    }

    """The pieces of brush `owner`'s side (its winding `outline`) that no
    other brush covers."""
    def pieces(owner: int, outline: list[Vec3], normal: Vec3, dist: float) -> list[list[Vec3]] {
        found: list[list[Vec3]] = [];
        for label in self.piece_steps(owner, outline, normal, dist, found) {
            continue;
        }
        return found;
    }

    """`pieces` a step at a time, into `found`: it pauses every so many
    pieces cut, for a side that many brushes cover."""
    def piece_steps(owner: int, outline: list[Vec3], normal: Vec3, dist: float, found: list[list[Vec3]]) -> Iterator[str] {
        kept: list[list[Vec3]] = [outline];
        work = 0;
        for other in self.near(outline, owner) {
            cut: list[list[Vec3]] = [];
            for piece in kept {
                for part in self.outside_of(piece, normal, dist, owner, other) {
                    if polygon_kept(part) {
                        cut.append(part);
                    }
                }
            }
            kept = cut;
            if not kept {
                break;
            }
            work += len(kept);
            if work >= CUT_SLICE {
                work = 0;
                yield "cut";
            }
        }
        found.extend(kept);
    }
}

"""Whether brushes of a material can be seen through (and so cover
nothing): clip, triggers, hints and the like."""
def material_clear(name: str) -> bool {
    last = name.lower().split("/")[-1].split(":")[-1];
    return last in ["clip", "playerclip", "monsterclip", "skip", "trigger", "hint", "origin", "areaportal"];
}
