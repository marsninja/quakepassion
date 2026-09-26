"""Swept queries over a pre-expanded collision BSP, independent of game formats."""
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from ..math.orientation { Basis }

node HullCell {
    has normal: Vec3 = Vec3(),
        distance: float = 0.0,
        contents: int = 0,
        planes: list[Vec3] = [],
        distances: list[float] = [],
        point_distances: list[float] = [],
        triangle: list[Vec3] = [],
        point_blocking: bool = True;
}

edge HullFront: HullCell --> HullCell {}
edge HullBack: HullCell --> HullCell {}

obj Trace {
    has fraction: float = 1.0,
        normal: Vec3 = Vec3(),
        start_solid: bool = False,
        hull: int = -1,
        model: int = -1,
        end: Vec3 = Vec3();
}

"""How a moving body's box differs from the box the hulls were expanded by
(`lo` = hull mins - body mins, `hi` = hull maxs - body maxs). Q2/Q3 brush
hulls move each plane by it, as CM_BoxTrace offsets a brush's planes by the
box corner facing them; Q1's second clip hull is already exact (`planes`
false) and only needs the wider broad phase."""
obj BodyBox {
    has lo: Vec3 = Vec3(),
        hi: Vec3 = Vec3(),
        planes: bool = True;

    """How far below and above the stored hull bounds this body's reach."""
    def reach_low() -> Vec3 {
        return Vec3(x=min(0.0, self.hi.x), y=min(0.0, self.hi.y), z=min(0.0, self.hi.z));
    }
    def reach_high() -> Vec3 {
        return Vec3(x=max(0.0, self.lo.x), y=max(0.0, self.lo.y), z=max(0.0, self.lo.z));
    }
}

"""One convex brush (its planes) or, for point traces, one patch triangle:
the narrow-phase test at a hull leaf, as a plain call rather than a walker."""
def leaf_sweep(
    cell: HullCell,
    start: Vec3,
    finish: Vec3,
    point: bool,
    top_drop: float,
    body: BodyBox | None = None
) -> Trace {
    if point and not cell.point_blocking {
        return Trace();
    }
    if point and cell.triangle {
        vertex = cell.triangle[0];
        edge1 = cell.triangle[1].sub(vertex);
        edge2 = cell.triangle[2].sub(vertex);
        direction = finish.sub(start);
        cross = direction.cross(edge2);
        determinant = edge1.dot(cross);
        if abs(determinant) < 0.000000001 {
            return Trace();
        }
        offset = start.sub(vertex);
        u = offset.dot(cross) / determinant;
        if u < 0.0 or u > 1.0 {
            return Trace();
        }
        other = offset.cross(edge1);
        v = direction.dot(other) / determinant;
        if v < 0.0 or u + v > 1.0 {
            return Trace();
        }
        fraction = edge2.dot(other) / determinant;
        if fraction < 0.0 or fraction > 1.0 {
            return Trace();
        }
        normal = edge1.cross(edge2).normalized();
        if normal.dot(direction) > 0.0 {
            normal = normal.scale(-1.0);
        }
        return Trace(fraction=fraction, normal=normal);
    }
    if cell.planes {
        enter = 0.0;
        leave = 1.0;
        normal = Vec3();
        inside = True;
        for i in range(len(cell.planes)) {
            n = cell.planes[i];
            distance = cell.point_distances[i]
                if point and cell.point_distances
                else cell.distances[i] + min(0.0, n.z) * top_drop;
            if body is not None and not point {
                distance += n.x * (body.lo.x if n.x >= 0.0 else body.hi.x)
                    + n.y * (body.lo.y if n.y >= 0.0 else body.hi.y)
                    + n.z * (body.lo.z if n.z >= 0.0 else body.hi.z);
            }
            a = n.dot(start) - distance;
            b = n.dot(finish) - distance;
            if a >= 0.0 {
                inside = False;
            }
            # A point ray lying on a brush side can still enter through
            # another plane (notably the seam between adjoining floors).
            if point and abs(a) < 0.0000001 and abs(b) < 0.0000001 {
                continue;
            }
            if a >= 0.0 and b >= 0.0 {
                return Trace();
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
                return Trace();
            }
        }
        return Trace(fraction=enter, normal=normal, start_solid=inside);
    }
    return Trace();
}

walker Sweep {
    has start: Vec3,
        finish: Vec3,
        top_drop: float = 0.0,
        point: bool = False,
        low: float = 0.0,
        high: float = 1.0,
        entry_normal: Vec3 = Vec3(),
        depth: int = 0,
        body: BodyBox | None = None,
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
                top_drop=self.top_drop,
                point=self.point,
                depth=self.depth + 1,
                body=self.body
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
        if here.planes or (self.point and here.triangle) or (self.point and not here.point_blocking) {
            leaf = leaf_sweep(here, self.start, self.finish, self.point, self.top_drop, self.body);
            if leaf.fraction < 1.0 or leaf.start_solid {
                self.result.fraction = leaf.fraction;
                self.result.normal = leaf.normal;
                self.result.start_solid = leaf.start_solid;
            }
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

edge HullChild: HullGroup --> HullGroup {}

"""Whether the segment from `start` to `finish` passes through `box` (slab
test), so a long diagonal trace does not collect every hull in its bounding
box."""
def segment_meets_box(
    start: Vec3, finish: Vec3, box: AABB, low: Vec3 = Vec3(), high: Vec3 = Vec3()
) -> bool {
    span = slab(start.x, finish.x - start.x, box.mins.x - 1.0 + low.x, box.maxs.x + 1.0 + high.x, 0.0, 1.0);
    if span[0] > span[1] {
        return False;
    }
    span = slab(start.y, finish.y - start.y, box.mins.y - 1.0 + low.y, box.maxs.y + 1.0 + high.y, span[0], span[1]);
    if span[0] > span[1] {
        return False;
    }
    span = slab(start.z, finish.z - start.z, box.mins.z - 1.0 + low.z, box.maxs.z + 1.0 + high.z, span[0], span[1]);
    return span[0] <= span[1];
}

"""Narrow the segment's [enter, leave] interval to one axis slab."""
def slab(
    origin: float, delta: float, low: float, high: float, enter: float, leave: float
) -> tuple[float, float] {
    if abs(delta) < 0.000001 {
        if origin < low or origin > high {
            return (1.0, 0.0);
        }
        return (enter, leave);
    }
    a = (low - origin) / delta;
    b = (high - origin) / delta;
    return (max(enter, min(a, b)), min(leave, max(a, b)));
}

walker FindHulls {
    has mins: Vec3,
        maxs: Vec3,
        start: Vec3 = Vec3(),
        finish: Vec3 = Vec3(),
        low: Vec3 = Vec3(),
        high: Vec3 = Vec3(),
        indices: list[int] = [];

    can select with HullGroup entry {
        b = here.bounds;
        # `low`/`high` widen the stored bounds for a larger body.
        if self.maxs.x < b.mins.x + self.low.x
            or self.mins.x > b.maxs.x + self.high.x
            or self.maxs.y < b.mins.y + self.low.y
            or self.mins.y > b.maxs.y + self.high.y
            or self.maxs.z < b.mins.z + self.low.z
            or self.mins.z > b.maxs.z + self.high.z {
            return;
        }
        if not segment_meets_box(self.start, self.finish, b, self.low, self.high) {
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

# Shared by actor hull views; consumers can observe changes without scanning
# every static brush each simulation tick.
obj CollisionRevision {
    has serial: int = 0,
        changes: dict[int, int] = {};

    def touch(index: int) {
        self.serial += 1;
        self.changes[index] = self.serial;
    }
}

"""Sweep a world-space segment against one hull placed at `offset` and optionally
turned about it. As in Q2's CM_TransformedBoxTrace, the query moves into the
model's frame and the box keeps its size; the hit normal is turned back."""
def hull_sweep(
    hull: HullCell,
    start: Vec3,
    finish: Vec3,
    offset: Vec3,
    top_drop: float = 0.0,
    point: bool = False,
    turn: Basis | None = None,
    body: BodyBox | None = None
) -> Trace {
    local_start = start.sub(offset);
    local_finish = finish.sub(offset);
    if turn is not None {
        local_start = turn.inverse(local_start);
        local_finish = turn.inverse(local_finish);
    }
    # A brush or triangle leaf is one plain test; only BSP hulls are walked.
    result = Trace();
    if hull.planes or (point and hull.triangle) or (point and not hull.point_blocking) {
        result = leaf_sweep(hull, local_start, local_finish, point, top_drop, body);
    } else {
        query = hull spawn Sweep(
            start=local_start,
            finish=local_finish,
            point=point,
            top_drop=top_drop,
            body=body
        );
        result = query.result;
    }
    if turn is not None and result.fraction < 1.0 {
        result.normal = turn.apply(result.normal);
    }
    return result;
}

obj CollisionMap {
    has revision: CollisionRevision = CollisionRevision(),
        hulls: list[HullCell] = [],
        point_hulls: list[HullCell] = [],
        offsets: list[Vec3] = [],
        turns: dict[int, Basis] = {},
        models: list[int] = [],
        disabled: set[int] = set(),
        bounds: list[AABB] = [],
        groups: list[HullGroup] = [],
        eye_height: float = 22.0,
        top_drop: float = 0.0;
    # The box `hulls` are expanded by (the standing player's), Q1's hull 2
    # for the same models, and a view's own body box when it differs.
    has hull_mins: Vec3 = Vec3(x=-16.0, y=-16.0, z=-24.0),
        hull_maxs: Vec3 = Vec3(x=16.0, y=16.0, z=32.0),
        large_hulls: list[HullCell] = [],
        body: BodyBox | None = None;
    # Brush sides a shot leaves nothing on, by hull: the sky and Q3
    # SURF_NOIMPACT take no impact at all, Q3 SURF_NOMARKS no marks.
    has no_impact: dict[int, list[Vec3]] = {},
        no_marks: dict[int, list[Vec3]] = {};

    # Share live geometry and mover offsets, but keep actor stance independent.
    # With `mins`/`maxs` the view traces that box instead of the player's.
    def for_body(
        height: float, drop: float = 0.0, mins: Vec3 | None = None, maxs: Vec3 | None = None
    ) -> CollisionMap {
        view = CollisionMap(
            revision=self.revision,
            hulls=self.hulls,
            point_hulls=self.point_hulls,
            offsets=self.offsets,
            turns=self.turns,
            models=self.models,
            disabled=self.disabled,
            bounds=self.bounds,
            groups=self.groups,
            eye_height=height,
            top_drop=drop,
            hull_mins=self.hull_mins,
            hull_maxs=self.hull_maxs,
            large_hulls=self.large_hulls,
            no_impact=self.no_impact,
            no_marks=self.no_marks
        );
        if mins is not None and maxs is not None {
            view.fit_body(mins, maxs);
        }
        return view;
    }

    """Trace a body box of `mins`..`maxs` about the origin. Brush hulls shift
    their planes for it; Q1 maps pick a clip hull by the box's width
    (SV_HullForEntity: wider than 32 units takes hull 2)."""
    def fit_body(mins: Vec3, maxs: Vec3) {
        if self.large_hulls {
            if maxs.x - mins.x > 32.0 and len(self.large_hulls) == len(self.hulls) {
                self.hulls = self.large_hulls;
                self.body = BodyBox(
                    lo=self.hull_mins.sub(Vec3(x=-32.0, y=-32.0, z=-24.0)),
                    hi=self.hull_maxs.sub(Vec3(x=32.0, y=32.0, z=64.0)),
                    planes=False
                );
            }
            return;
        }
        lo = self.hull_mins.sub(mins);
        hi = self.hull_maxs.sub(maxs);
        if lo.length() < 0.000001 and hi.length() < 0.000001 {
            self.body = None;
            return;
        }
        self.body = BodyBox(lo=lo, hi=hi);
    }

    """A cache key for what this view's traces can reach: the body box."""
    def body_key() -> str {
        body = self.body;
        if body is None {
            return "";
        }
        return str(body.lo.x) + "," + str(body.lo.z) + "," + str(body.hi.x) + "," + str(body.hi.z);
    }

    """What the surface a point trace ended on takes from a shot: 2 nothing
    (sky, SURF_NOIMPACT: g_weapon.c and fire_lead skip their impact
    events), 1 no mark (SURF_NOMARKS), 0 both."""
    def surface_class(trace: Trace) -> int {
        if trace.fraction >= 1.0 or trace.hull < 0 {
            return 0;
        }
        for normal in self.no_impact.get(trace.hull, []) {
            if normal.dot(trace.normal) > 0.99 {
                return 2;
            }
        }
        for normal in self.no_marks.get(trace.hull, []) {
            if normal.dot(trace.normal) > 0.99 {
                return 1;
            }
        }
        return 0;
    }

    def set_offset(index: int, offset: Vec3) {
        old = self.offsets[index];
        if old.x == offset.x and old.y == offset.y and old.z == offset.z { return; }
        self.offsets[index] = offset;
        self.revision.touch(index);
    }

    # Rotating brush models turn about their offset (the entity origin).
    def set_turn(index: int, turn: Basis | None) {
        if turn is None {
            if index not in self.turns { return; }
            self.turns.pop(index);
        } else {
            self.turns[index] = turn;
        }
        self.revision.touch(index);
    }

    # A rotating hull can reach any orientation: bound it by its radius.
    def allow_rotation(index: int) {
        reach = 0.0;
        box = self.bounds[index];
        offset = self.offsets[index];
        for x in [box.mins.x, box.maxs.x] {
            for y in [box.mins.y, box.maxs.y] {
                for z in [box.mins.z, box.maxs.z] {
                    reach = max(reach, Vec3(x=x, y=y, z=z).sub(offset).length());
                }
            }
        }
        extent = Vec3(x=reach, y=reach, z=reach);
        self.bounds[index] = AABB(mins=offset.sub(extent), maxs=offset.add(extent));
    }

    def set_disabled(index: int, disabled: bool) {
        if (index in self.disabled) == disabled { return; }
        if disabled { self.disabled.add(index); }
        else { self.disabled.discard(index); }
        self.revision.touch(index);
    }

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
            cell.point_distances.append(distances[i]);
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
        self.hulls[-1].triangle = [a, b, c];
    }

    def reindex() {
        self.groups = [];
        if self.hulls and len(self.bounds) == len(self.hulls) {
            self.groups.append(group_hulls(self.bounds, list(range(len(self.hulls)))));
        }
    }

    def trace(
        start: Vec3,
        finish: Vec3,
        exclude: list[int] = [],
        top_drop: float = -1.0,
        point: bool = False
    ) -> Trace {
        result = Trace(end=finish);
        indices: list[int] = [];
        body = self.body if not point else None;
        low = Vec3();
        high = Vec3();
        if body is not None {
            low = body.reach_low();
            high = body.reach_high();
        }
        if self.groups {
            candidates = self.groups[0] spawn FindHulls(
                start=start,
                finish=finish,
                low=low,
                high=high,
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
            if i in exclude or i in self.disabled {
                continue;
            }
            # Tree leaves hold small batches; reject each nonintersecting hull
            # before creating its narrow-phase walker. Bounds include mover travel.
            if len(self.bounds) == len(self.hulls) {
                bounds = self.bounds[i];
                lo = bounds.mins;
                hi = bounds.maxs;
                if body is not None {
                    lo = lo.add(low);
                    hi = hi.add(high);
                }
                if (start.x < lo.x and finish.x < lo.x)
                    or (start.x > hi.x and finish.x > hi.x)
                    or (start.y < lo.y and finish.y < lo.y)
                    or (start.y > hi.y and finish.y > hi.y)
                    or (start.z < lo.z and finish.z < lo.z)
                    or (start.z > hi.z and finish.z > hi.z)
                    or not segment_meets_box(start, finish, bounds, low, high) {
                    continue;
                }
            }
            hull = self.point_hulls[i] if point and self.point_hulls else self.hulls[i];
            query = hull_sweep(
                hull,
                start,
                finish,
                self.offsets[i],
                0.0 if point else (self.top_drop if top_drop < 0.0 else top_drop),
                point,
                self.turns.get(i, None),
                body if body is not None and body.planes else None
            );
            result.start_solid = result.start_solid or query.start_solid;
            if query.fraction < result.fraction {
                result.hull = i;
                result.model = self.models[i] if i < len(self.models) else -1;
                result.fraction = query.fraction;
                result.normal = query.normal;
            }
        }
        if result.start_solid {
            result.fraction = 0.0;
        } elif result.fraction < 1.0 and not point {
            approach = abs(finish.sub(start).dot(result.normal));
            if approach > 0.00001 {
                result.fraction = max(0.0, result.fraction - 0.03125 / approach);
            }
        }
        result.end = start.lerp(finish, result.fraction);
        return result;
    }

    def trace_point(start: Vec3, finish: Vec3, exclude: list[int] = []) -> Trace {
        return self.trace(start, finish, exclude=exclude, point=True);
    }
}
