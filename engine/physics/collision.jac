"""Swept queries over a pre-expanded collision BSP, independent of game formats."""
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

node HullCell {
    has normal: Vec3 = Vec3(),
        distance: float = 0.0,
        contents: int = 0;
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
    size = hi.sub(lo);
    axis = 0
        if size.x >= size.y and size.x >= size.z
        else (1 if size.y >= size.z else 2);
    mid = lo.add(hi).scale(0.5);
    split = mid.x if axis == 0 else (mid.y if axis == 1 else mid.z);
    left: list[int] = [];
    right: list[int] = [];
    for i in indices {
        center = bounds[i].center();
        value = center.x if axis == 0 else (center.y if axis == 1 else center.z);
        if value < split {
            left.append(i);
        } else {
            right.append(i);
        }
    }
    if not left or not right {
        group.indices = indices;
        return group;
    }
    a = group_hulls(bounds, left, depth + 1);
    right_group = group_hulls(bounds, right, depth + 1);
    group +>:HullChild:+> a;
    group +>:HullChild:+> right_group;
    return group;
}

obj CollisionMap {
    has hulls: list[HullCell] = [],
        offsets: list[Vec3] = [],
        bounds: list[AABB] = [],
        groups: list[HullGroup] = [],
        eye_height: float = 22.0;

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
        cell = HullCell(contents=-2);
        empty = HullCell(contents=-1);
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
            next_cell = HullCell(normal=n, distance=distance);
            next_cell +>:HullFront:+> empty;
            next_cell +>:HullBack:+> cell;
            cell = next_cell;
        }
        self.hulls.append(cell);
        self.offsets.append(offset);
        self.bounds.append(AABB(mins=lo.add(offset), maxs=hi.add(offset)));
    }

    def reindex() {
        self.groups = [];
        if self.hulls and len(self.bounds) == len(self.hulls) {
            self.groups.append(group_hulls(self.bounds, list(range(len(self.hulls)))));
        }
    }

    def trace(start: Vec3, finish: Vec3) -> Trace {
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
