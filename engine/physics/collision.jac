"""Swept queries over a pre-expanded collision BSP, independent of game formats."""
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

node HullCell {
    has normal: Vec3 = Vec3(),
        distance: float = 0.0,
        contents: int = 0,
        planes: list[Vec3] = [],
        distances: list[float] = [];
}

edge HullFront {}
edge HullBack {}

obj Trace {
    has fraction: float = 1.0,
        normal: Vec3 = Vec3(),
        start_solid: bool = False,
        end: Vec3 = Vec3();
}

walker Sweep {
    has start: Vec3,
        finish: Vec3,
        low: float = 0.0,
        high: float = 1.0,
        entry_normal: Vec3 = Vec3(),
        depth: int = 0,
        result: Trace = Trace();

    def follow(targets: list[HullCell], low: float, high: float, normal: Vec3) {
        if low > high or low >= self.result.fraction {
            return;
        }
        for cell in targets {
            query = cell spawn Sweep(
                start=self.start,
                finish=self.finish,
                low=low,
                high=high,
                entry_normal=normal,
                depth=self.depth + 1
            );
            self.result.start_solid = self.result.start_solid
                or query.result.start_solid;
            if query.result.fraction < self.result.fraction {
                self.result.fraction = query.result.fraction;
                self.result.normal = query.result.normal;
            }
        }
    }

    can intersect with HullCell entry {
        if here.planes {
            enter = 0.0;
            leave = 1.0;
            normal = Vec3();
            inside = True;
            for i in range(len(here.planes)) {
                n = here.planes[i];
                a = n.dot(self.start) - here.distances[i];
                b = n.dot(self.finish) - here.distances[i];
                if a >= 0.0 {
                    inside = False;
                }
                if a >= 0.0 and b >= 0.0 {
                    return;
                }
                if a >= 0.0 and b < 0.0 {
                    fraction = a / (a - b);
                    if fraction >= enter {
                        enter = fraction;
                        normal = n;
                    }
                } elif a < 0.0 and b >= 0.0 {
                    leave = min(leave, a / (a - b));
                }
                if enter > leave {
                    return;
                }
            }
            self.result.start_solid = inside;
            self.result.fraction = enter;
            self.result.normal = normal;
            return;
        }

        if self.depth > 256 {
            raise ValueError("Cyclic or excessively deep collision hull");
        }
        if here.contents != 0 {
            if here.contents == -2 {
                self.result.fraction = self.low;
                self.result.normal = self.entry_normal;
                self.result.start_solid = self.low == 0.0
                    and self.entry_normal.length() < 0.00001;
            }
            return;
        }
        front = [here->:HullFront:->][?:HullCell];
        back = [here->:HullBack:->][?:HullCell];
        a = here.normal.dot(self.start) - here.distance;
        b = here.normal.dot(self.finish) - here.distance;
        lo = a + (b - a) * self.low;
        hi = a + (b - a) * self.high;
        if lo >= 0.0 and hi >= 0.0 {
            self.follow(front, self.low, self.high, self.entry_normal);
        } elif lo < 0.0 and hi < 0.0 {
            self.follow(back, self.low, self.high, self.entry_normal);
        } else {
            split = max(self.low, min(self.high, a / (a - b)));
            if lo >= 0.0 {
                self.follow(front, self.low, split, self.entry_normal);
                self.follow(back, split, self.high, here.normal);
            } else {
                self.follow(back, self.low, split, self.entry_normal);
                self.follow(front, split, self.high, here.normal.scale(-1.0));
            }
        }
    }
}

node HullGroup {
    has bounds: AABB,
        indices: list[int] = [];
}

edge HullChild {}

walker FindHulls {
    has mins: Vec3,
        maxs: Vec3,
        indices: list[int] = [];

    can select with HullGroup entry {
        b = here.bounds;
        if self.maxs.x < b.mins.x
            or self.mins.x > b.maxs.x
            or self.maxs.y < b.mins.y
            or self.mins.y > b.maxs.y
            or self.maxs.z < b.mins.z
            or self.mins.z > b.maxs.z {
            return;
        }
        self.indices.extend(here.indices);
        visit [here->:HullChild:->];
    }
}

def group_hulls(bounds: list[AABB], indices: list[int], depth: int = 0) -> HullGroup {
    lo = Vec3(x=1.0e30, y=1.0e30, z=1.0e30);
    hi = Vec3(x=-1.0e30, y=-1.0e30, z=-1.0e30);
    for i in indices {
        b = bounds[i];
        lo = Vec3(x=min(lo.x, b.mins.x), y=min(lo.y, b.mins.y), z=min(lo.z, b.mins.z));
        hi = Vec3(x=max(hi.x, b.maxs.x), y=max(hi.y, b.maxs.y), z=max(hi.z, b.maxs.z));
    }
    group = HullGroup(bounds=AABB(mins=lo, maxs=hi));
    if len(indices) <= 8 or depth >= 32 {
        group.indices = indices;
        return group;
    }
    center_lo = Vec3(x=1.0e30, y=1.0e30, z=1.0e30);
    center_hi = Vec3(x=-1.0e30, y=-1.0e30, z=-1.0e30);
    for i in indices {
        c = bounds[i].center();
        center_lo = Vec3(
            x=min(center_lo.x, c.x), y=min(center_lo.y, c.y), z=min(center_lo.z, c.z)
        );
        center_hi = Vec3(
            x=max(center_hi.x, c.x), y=max(center_hi.y, c.y), z=max(center_hi.z, c.z)
        );
    }
    size = center_hi.sub(center_lo);
    axis = 0
        if size.x >= size.y and size.x >= size.z
        else (1 if size.y >= size.z else 2);
    ranked: list[tuple[float, int]] = [];
    for i in indices {
        center = bounds[i].center();
        value = center.x if axis == 0 else (center.y if axis == 1 else center.z);
        ranked.append((value, i));
    }
    ranked = sorted(ranked);
    middle = len(ranked) // 2;
    left = [pair[1] for pair in ranked[:middle]];
    right = [pair[1] for pair in ranked[middle:]];
    a = group_hulls(bounds, left, depth + 1);
    right_group = group_hulls(bounds, right, depth + 1);
    group +>:HullChild:+> a;
    group +>:HullChild:+> right_group;
    return group;
}

obj CollisionMap {
    has hulls: list[HullCell] = [],
        offsets: list[Vec3] = [],
        models: list[int] = [],
        bounds: list[AABB] = [],
        groups: list[HullGroup] = [],
        eye_height: float = 22.0;

    def add_box(lo: Vec3, hi: Vec3, offset: Vec3, mins: Vec3, maxs: Vec3) {
        self.add_brush(
            [
                Vec3(x=1.0),
                Vec3(x=-1.0),
                Vec3(y=1.0),
                Vec3(y=-1.0),
                Vec3(z=1.0),
                Vec3(z=-1.0)
            ],
            [hi.x, -lo.x, hi.y, -lo.y, hi.z, -lo.z],
            mins,
            maxs,
            offset
        );
    }

    def add_brush(
        normals: list[Vec3],
        distances: list[float],
        mins: Vec3,
        maxs: Vec3,
        offset: Vec3
    ) {
        if len(normals) < 4 or len(normals) != len(distances) {
            raise ValueError("Invalid convex collision brush");
        }
        cell = HullCell();
        lo = Vec3(x=-1.0e30, y=-1.0e30, z=-1.0e30);
        hi = Vec3(x=1.0e30, y=1.0e30, z=1.0e30);
        for i in range(len(normals)) {
            n = normals[i];
            if abs(n.length() - 1.0) > 0.01 {
                raise ValueError("Invalid collision plane normal");
            }
            corner = Vec3(
                x=mins.x if n.x >= 0.0 else maxs.x,
                y=mins.y if n.y >= 0.0 else maxs.y,
                z=mins.z if n.z >= 0.0 else maxs.z
            );
            distance = distances[i] - n.dot(corner);
            if n.x == 1.0 and n.y == 0.0 and n.z == 0.0 {
                hi.x = min(hi.x, distance);
            }
            if n.x == -1.0 and n.y == 0.0 and n.z == 0.0 {
                lo.x = max(lo.x, -distance);
            }
            if n.y == 1.0 and n.x == 0.0 and n.z == 0.0 {
                hi.y = min(hi.y, distance);
            }
            if n.y == -1.0 and n.x == 0.0 and n.z == 0.0 {
                lo.y = max(lo.y, -distance);
            }
            if n.z == 1.0 and n.x == 0.0 and n.y == 0.0 {
                hi.z = min(hi.z, distance);
            }
            if n.z == -1.0 and n.x == 0.0 and n.y == 0.0 {
                lo.z = max(lo.z, -distance);
            }
            cell.planes.append(n);
            cell.distances.append(distance);
        }
        self.hulls.append(cell);
        self.offsets.append(offset);
        self.bounds.append(AABB(mins=lo.add(offset), maxs=hi.add(offset)));
    }

    # Triangle/box separating axes form the exact expanded triangle hull.
    # Axial planes also give the spatial tree tight, finite bounds.
    def add_triangle(a: Vec3, b: Vec3, c: Vec3, mins: Vec3, maxs: Vec3, offset: Vec3) {
        surface = b.sub(a).cross(c.sub(a));
        if surface.length() < 0.000001 {
            return;
        }
        axes = [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)];
        candidates = [surface];
        candidates.extend(axes);
        for side in [b.sub(a), c.sub(b), a.sub(c)] {
            for axis in axes {
                candidates.append(side.cross(axis));
            }
        }
        normals: list[Vec3] = [];
        distances: list[float] = [];
        for candidate in candidates {
            if candidate.length() < 0.000001 {
                continue;
            }
            unit = candidate.normalized();
            for n in [unit, unit.scale(-1.0)] {
                duplicate = False;
                for prior in normals {
                    if prior.sub(n).length() < 0.000001 {
                        duplicate = True;
                        break;
                    }
                }
                if duplicate {
                    continue;
                }
                normals.append(n);
                distances.append(max(a.dot(n), max(b.dot(n), c.dot(n))));
            }
        }
        self.add_brush(normals, distances, mins, maxs, offset);
    }

    def reindex() {
        self.groups = [];
        if self.hulls and len(self.bounds) == len(self.hulls) {
            self.groups.append(group_hulls(self.bounds, list(range(len(self.hulls)))));
        }
    }

    def trace(start: Vec3, finish: Vec3, exclude: list[int] = []) -> Trace {
        result = Trace(end=finish);
        indices: list[int] = [];
        if self.groups {
            candidates = self.groups[0] spawn FindHulls(
                mins=Vec3(
                    x=min(start.x, finish.x),
                    y=min(start.y, finish.y),
                    z=min(start.z, finish.z)
                ),
                maxs=Vec3(
                    x=max(start.x, finish.x),
                    y=max(start.y, finish.y),
                    z=max(start.z, finish.z)
                )
            );
            indices = candidates.indices;
        } else {
            indices = list(range(len(self.hulls)));
        }
        for i in indices {
            if i in exclude {
                continue;
            }
            offset = self.offsets[i];
            query = self.hulls[i] spawn Sweep(
                start=start.sub(offset), finish=finish.sub(offset)
            );
            result.start_solid = result.start_solid or query.result.start_solid;
            if query.result.fraction < result.fraction {
                result.fraction = query.result.fraction;
                result.normal = query.result.normal;
            }
        }
        if result.start_solid {
            result.fraction = 0.0;
        } elif result.fraction < 1.0 {
            approach = abs(finish.sub(start).dot(result.normal));
            if approach > 0.00001 {
                result.fraction = max(0.0, result.fraction - 0.03125 / approach);
            }
        }
        result.end = start.lerp(finish, result.fraction);
        return result;
    }
}
