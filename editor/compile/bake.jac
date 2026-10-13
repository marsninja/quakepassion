"""The bake's partition and visibility. A compiled scene is one leaf that
sees itself; baked, the plan of its level is cut into cells, each a leaf of
the level's tree with the faces that lie in it, and each cell is given the
cells it can see, so that only those are drawn from inside it. The form is
the one the engine's generated levels use: branches that split the plan,
leaves that are clusters, a row of bits a cluster.

Visibility is found by looking: from points a player could stand at in one
cell to such points, and to points on the faces, of another, with the
scene's fixed brushes in the way. Cells that touch always see each other,
and what one sees sees it back, so the answer errs toward drawing more."""
import math;
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Bsp, Leaf, Branch, Plane, AreaLink }
import from ..document.scene { Scene }
import from ..geometry.brush {
    Side,
    Plane3,
    brush_holds,
    brush_windings,
    clip_winding,
    clip_sides,
    box_sides,
    tidy_winding,
    winding_area,
    windings_bounds
}
import from .live { LiveLevel, material_hidden }
import from .light { BrushOccluder }

"""What a bake did: how many cells, how many pairs of them cannot see each
other, how many lines of sight were tried, and whether it ran out of its
budget of them (the pairs left over are then taken to see each other)."""
obj VisReport {
    has cells: int = 0,
        hidden: int = 0,
        pairs: int = 0,
        rays: int = 0,
        capped: bool = False,
        # A bake by planes: its leaves, the portals between them, the areas
        # its area portals divide it into, the faces it found buried in the
        # brushes, and whether the outside could be reached from within.
        leaves: int = 0,
        portals: int = 0,
        areas: int = 0,
        buried: int = 0,
        leaked: bool = False;
}

"""The cell size that asks for a bake by the brushes' own planes in place
of a grid (no grid is cut that fine)."""
glob BAKE_BY_PLANES: float = 1.0;

"""The scene's brushes that stand still and are drawn: what blocks a line
of sight for good."""
def scene_occluder(scene: Scene) -> BrushOccluder {
    occluder = BrushOccluder();
    for item in scene.items() {
        if item.classname() not in ["worldspawn", "func_group", "func_wall", "func_static"] {
            continue;
        }
        for solid in scene.solids_of(item) {
            if not material_hidden(solid.sides[0].material) {
                occluder.add(solid.sides);
            }
        }
    }
    return occluder;
}

"""Cut a rectangle of the plan into cells no wider than `cell`: a leaf when
it is small enough, else a branch across its longer way and the two halves.
Answers the branch's number, or a leaf's as -(leaf + 1)."""
def:priv cut_plan(bsp: Bsp, low: Vec3, high: Vec3, cell: float) -> int {
    wide = high.x - low.x;
    deep = high.y - low.y;
    if wide <= cell + 0.5 and deep <= cell + 0.5 {
        leaf = len(bsp.leaves);
        bsp.leaves.append(Leaf(contents=0, vis_offset=0, mins=low, maxs=high, cluster=leaf));
        return -(leaf + 1);
    }
    along_x = wide >= deep;
    span = wide if along_x else deep;
    start = low.x if along_x else low.y;
    # The middle, on a multiple of the cell's size from the low side.
    at = start + max(1.0, float(round(span * 0.5 / cell))) * cell;
    if at >= start + span - 0.5 {
        at = start + span * 0.5;
    }
    plane = len(bsp.planes);
    bsp.planes.append(Plane(normal=Vec3(x=1.0) if along_x else Vec3(y=1.0), distance=at));
    index = len(bsp.branches);
    bsp.branches.append(Branch(plane=plane, front=0, back=0));
    back = cut_plan(
        bsp, low, Vec3(x=at if along_x else high.x, y=high.y if along_x else at, z=high.z), cell
    );
    front = cut_plan(
        bsp, Vec3(x=at if along_x else low.x, y=low.y if along_x else at, z=low.z), high, cell
    );
    bsp.branches[index].front = front;
    bsp.branches[index].back = back;
    return index;
}

"""The leaf of a baked level a point is in."""
def leaf_at(bsp: Bsp, head: int, point: Vec3) -> int {
    at = head;
    for depth in range(64) {
        if at < 0 {
            return -at - 1;
        }
        branch = bsp.branches[at];
        plane = bsp.planes[branch.plane];
        at = branch.front if plane.normal.dot(point) >= plane.distance else branch.back;
    }
    return 0;
}

"""Whether a point is inside one of the brushes that block sight."""
def:priv in_solid(occluder: BrushOccluder, point: Vec3) -> bool {
    for index in range(len(occluder.brushes)) {
        a = occluder.lows[index];
        b = occluder.highs[index];
        if point.x < a.x or point.x > b.x or point.y < a.y or point.y > b.y or point.z < a.z or point.z > b.z {
            continue;
        }
        if brush_holds(occluder.brushes[index], point) {
            return True;
        }
    }
    return False;
}

"""Whether two cells' rectangles touch or overlap in the plan."""
def:priv cells_touch(first: Leaf, second: Leaf) -> bool {
    return first.mins.x <= second.maxs.x + 0.5 and second.mins.x <= first.maxs.x + 0.5
        and first.mins.y <= second.maxs.y + 0.5 and second.mins.y <= first.maxs.y + 0.5;
}

"""Cutting a compiled scene's level into cells and finding which see which,
a slice at a time: the plan is cut and the points to look from laid out at
once (`cell_job`), then the flood of what a player could reach and the
pairs of cells are looked through a budget of lines of sight at a time
(`step`), and the rows of bits written when all are (`finish`). A bake done
all at once is the same job stepped through at once."""
obj CellJob {
    has made: LiveLevel,
        outcome: VisReport = VisReport(),
        budget: int = 1500000,
        occluder: BrushOccluder = BrushOccluder(),
        count: int = 0,
        marks: list[list[Vec3]] = [],
        lattice: list[list[Vec3]] = [],
        beside: list[list[int]] = [],
        reached: list[list[bool]] = [],
        waiting: list[tuple[int, int]] = [],
        turn: int = 0,
        seeded: bool = False,
        eyes: list[list[Vec3]] = [],
        sees: list[list[bool]] = [],
        # "flood", then "pairs" (from the row `row`), then "done".
        phase: str = "done",
        row: int = 0,
        said: float = 0.0;

    def finished -> bool {
        return self.phase == "done";
    }

    """How far it has got: from 0 to 1 (the flood its first tenth). The
    flood's queue grows as it goes, so what is said never goes back."""
    def share -> float {
        now = 1.0;
        if self.phase == "flood" {
            now = 0.1 * float(self.turn) / float(max(1, len(self.waiting)));
        } elif self.phase == "pairs" {
            now = 0.1 + 0.9 * float(self.row) / float(max(1, self.count));
        }
        self.said = max(self.said, now);
        return self.said;
    }

    """Look along about `limit` more lines of sight. True when all is found."""
    def step(limit: int) -> bool {
        bsp = self.made.bsp;
        outcome = self.outcome;
        occluder = self.occluder;
        stop = outcome.rays + max(1, limit);
        if self.phase == "flood" {
            while self.turn < len(self.waiting) and outcome.rays < self.budget // 2 and outcome.rays < stop {
                (cell_from, point_from) = self.waiting[self.turn];
                self.turn += 1;
                origin = self.lattice[cell_from][point_from];
                for cell_index in self.beside[cell_from] {
                    for (index, spot) in enumerate(self.lattice[cell_index]) {
                        if self.reached[cell_index][index] {
                            continue;
                        }
                        outcome.rays += 1;
                        if occluder.visibility(origin, spot) > 0.0 {
                            self.reached[cell_index][index] = True;
                            self.waiting.append((cell_index, index));
                        }
                    }
                }
            }
            if self.turn < len(self.waiting) and outcome.rays < self.budget // 2 {
                return False;
            }
            flooded = self.seeded and self.turn >= len(self.waiting);
            self.eyes = [];
            for index in range(self.count) {
                self.eyes.append(
                    [
                        self.lattice[index][place]
                        for place in range(len(self.lattice[index]))
                        if not flooded or self.reached[index][place]
                    ]
                );
            }
            self.sees = [[False for other in range(self.count)] for index in range(self.count)];
            self.phase = "pairs";
            self.row = 0;
        }
        if self.phase == "pairs" {
            # Which sees which, a row of pairs at a time.
            while self.row < self.count and outcome.rays < stop {
                first = self.row;
                self.row += 1;
                self.sees[first][first] = True;
                for second in range(first + 1, self.count) {
                    outcome.pairs += 1;
                    seen = cells_touch(bsp.leaves[first], bsp.leaves[second]) or outcome.capped;
                    if not seen {
                        # From where one could stand in either to where one could
                        # stand in, or to the faces of, the other.
                        for (near, far) in [(first, second), (second, first)] {
                            if seen {
                                break;
                            }
                            targets = self.eyes[far] + self.marks[far];
                            stride = max(1, len(targets) // 48);
                            for eye in self.eyes[near] {
                                if seen {
                                    break;
                                }
                                for pick in range(0, len(targets), stride) {
                                    outcome.rays += 1;
                                    if occluder.visibility(eye, targets[pick]) > 0.0 {
                                        seen = True;
                                        break;
                                    }
                                }
                            }
                            if outcome.rays > self.budget {
                                # Out of patience: what is left is taken to be in sight.
                                outcome.capped = True;
                                seen = True;
                            }
                        }
                    }
                    self.sees[first][second] = seen;
                    self.sees[second][first] = seen;
                    if not seen {
                        outcome.hidden += 1;
                    }
                }
            }
            if self.row < self.count {
                return False;
            }
            self.phase = "write";
        }
        if self.phase == "write" {
            # A row of bits a cluster, after the eight bytes a level's visibility begins with.
            count = self.count;
            width = (count + 7) // 8;
            rows = bytearray(8 + count * width);
            for first in range(count) {
                for second in range(count) {
                    if self.sees[first][second] {
                        rows[8 + first * width + second // 8] |= 1 << (second % 8);
                    }
                }
            }
            bsp.clusters = count;
            bsp.cluster_bytes = width;
            bsp.visibility = bytes(rows);
            self.phase = "done";
        }
        return True;
    }
}

"""The job of cutting a compiled scene's level into cells no wider than
`cell` and finding which see which, with `budget` lines of sight to try.
The plan is cut and the points laid out now; a level that fits one cell is
left as the one leaf it was, and its job is already done."""
def cell_job(scene: Scene, made: LiveLevel, cell: float = 256.0, budget: int = 1500000) -> CellJob {
    if cell == BAKE_BY_PLANES {
        return plane_job(scene, made, budget * 2);
    }
    job = CellJob(made=made, budget=budget);
    outcome = job.outcome;
    bsp = made.bsp;
    if len(bsp.models) == 0 or len(bsp.leaves) == 0 or cell < 16.0 {
        return job;
    }
    room = bsp.leaves[0];
    low = room.mins;
    high = room.maxs;
    # No more cells than a row of bits and a morning's patience allow.
    size = cell;
    while ((high.x - low.x) / size + 1.0) * ((high.y - low.y) / size + 1.0) > 400.0 {
        size *= 2.0;
    }
    faces = list(room.faces);
    bsp.leaves = [];
    bsp.branches = [];
    head = cut_plan(bsp, low, high, size);
    count = len(bsp.leaves);
    outcome.cells = count;
    job.count = count;
    if count < 2 {
        bsp.leaves[0].faces = faces;
        bsp.models[0].head = -1;
        return job;
    }
    bsp.models[0].head = head;
    bsp.models[0].vis_leaf_count = count - 1;
    # Each face to the cell its middle is in, and a point just off it to be seen by.
    marks: list[list[Vec3]] = [[] for index in range(count)];
    for index in faces {
        face = bsp.faces[index];
        if len(face.vertices) == 0 {
            continue;
        }
        middle = Vec3();
        for corner in face.vertices {
            middle = middle.add(corner);
        }
        middle = middle.scale(1.0 / float(len(face.vertices)));
        home = leaf_at(bsp, head, middle);
        bsp.leaves[home].faces.append(index);
        marks[home].append(middle.add(face.normal.scale(2.0)));
        for corner in face.vertices {
            # Its corners too, drawn a little toward its middle and off it.
            marks[home].append(corner.add(middle.sub(corner).scale(0.1)).add(face.normal.scale(2.0)));
        }
    }
    job.marks = marks;
    # Points through each cell: its middle and toward its corners, at
    # heights up through the level, where that is not in a wall.
    occluder = scene_occluder(scene);
    job.occluder = occluder;
    lattice: list[list[Vec3]] = [];
    levels: list[float] = [];
    height = low.z + 40.0;
    rise = max(64.0, (high.z - low.z - 80.0) / 9.0);
    while height < high.z - 32.0 and len(levels) < 10 {
        levels.append(height);
        height += rise;
    }
    if len(levels) == 0 {
        levels.append((low.z + high.z) * 0.5);
    }
    for leaf in bsp.leaves {
        through: list[Vec3] = [];
        for (share_x, share_y) in [(0.5, 0.5), (0.2, 0.2), (0.8, 0.2), (0.2, 0.8), (0.8, 0.8)] {
            for level in levels {
                spot = Vec3(
                    x=leaf.mins.x + (leaf.maxs.x - leaf.mins.x) * share_x,
                    y=leaf.mins.y + (leaf.maxs.y - leaf.mins.y) * share_y,
                    z=level
                );
                if not in_solid(occluder, spot) {
                    through.append(spot);
                }
            }
        }
        lattice.append(through);
    }
    job.lattice = lattice;
    # Of those, the ones a player could come to: reached from where the
    # scene's entities stand, point to point in plain sight, through cells
    # that touch. What lies under the floor, outside the walls or in a
    # sealed room nothing stands in is not among them. A scene with no
    # entity to start from, or a flood that outruns its budget, counts
    # every point.
    beside: list[list[int]] = [];
    for first in range(count) {
        beside.append([second for second in range(count) if cells_touch(bsp.leaves[first], bsp.leaves[second])]);
    }
    job.beside = beside;
    reached: list[list[bool]] = [[False for spot in lattice[index]] for index in range(count)];
    waiting: list[tuple[int, int]] = [];
    for item in scene.items() {
        stands = item.origin();
        if stands is None {
            continue;
        }
        home = leaf_at(bsp, head, stands);
        for cell_index in beside[home] {
            for (index, spot) in enumerate(lattice[cell_index]) {
                if not reached[cell_index][index] {
                    outcome.rays += 1;
                    if occluder.visibility(stands.add(Vec3(z=8.0)), spot) > 0.0 {
                        reached[cell_index][index] = True;
                        waiting.append((cell_index, index));
                    }
                }
            }
        }
    }
    job.reached = reached;
    job.waiting = waiting;
    job.seeded = len(waiting) > 0;
    job.phase = "flood";
    return job;
}

"""Divide a compiled scene's level into cells and work out which see which.
`cell` is how wide a cell may be; `budget` how many lines of sight may be
tried. A level that fits one cell is left as the one leaf it was."""
def bake_cells(scene: Scene, made: LiveLevel, cell: float = 256.0, budget: int = 1500000) -> VisReport {
    job = cell_job(scene, made, cell, budget);
    while not job.step(budget * 4) {
        continue;
    }
    return job.outcome;
}

"""Whether, in a baked level, one cell sees another."""
def cell_sees(bsp: Bsp, first: int, second: int) -> bool {
    if bsp.clusters <= 0 or first < 0 or second < 0 or first >= bsp.clusters or second >= bsp.clusters {
        return True;
    }
    return int(bsp.visibility[8 + first * bsp.cluster_bytes + second // 8]) & (1 << (second % 8)) != 0;
}

"""How far a point must lie from a plane for the plane to cut what it is in."""
glob CUT_SLACK: float = 0.1;

"""Part of a brush in a region still being cut: its sides with their
outlines, and what it is to the bake: 0 fills space, 1 only cuts it (a
hint), 2 is an area portal (numbered `portal`)."""
obj Piece {
    has sides: list[Side],
        shape: list[list[Vec3]] = [],
        kind: int = 0,
        portal: int = 0;
}

"""A region of space still to be cut: the planes around it with their
outlines, the parts of brushes in it, and where its number goes once it has
one: into the branch above it (-1 for the whole) on one side of it."""
obj Region {
    has sides: list[Side],
        shape: list[list[Vec3]] = [],
        pieces: list[Piece] = [],
        above: int = -1,
        front: bool = False;
}

"""A leaf of the partition as the bake floods it: filled by a brush
(`solid`), inside an area portal (`portal`, its number), at the edge of the
space cut (`outer`), come to from where entities stand (`reached`), filled
as outside the level (`filled`), and the cluster and area it is given."""
node BakeLeaf {
    has index: int,
        solid: bool = False,
        portal: int = 0,
        outer: bool = False,
        reached: bool = False,
        filled: bool = False,
        cluster: int = -1,
        area: int = 0;
}

"""Two leaves meet at a portal: `portal` is its number in the bake's list,
`to` the leaf it leads into, `side` 0 when that is the way the portal faces
and 1 when it is the other way."""
edge Opening: BakeLeaf --> BakeLeaf {
    has portal: int = 0,
        to: int = 0,
        side: int = 0;
}

"""Every leaf a player could come to from where it starts: through portals,
never into a brush."""
walker ReachLeaves {
    can spread with BakeLeaf entry {
        if here.reached or here.solid {
            return;
        }
        here.reached = True;
        visit [here->:Opening:->];
    }
}

"""An area: the leaves that reach each other without crossing an area
portal."""
walker AreaFlood {
    has area: int;

    can spread with BakeLeaf entry {
        if here.area != 0 or here.cluster < 0 or here.portal != 0 {
            return;
        }
        here.area = self.area;
        visit [here->:Opening:->];
    }
}

"""What one cluster sees: the leaves beside it, and beyond them each leaf
whose portal a line from the cluster's own portals reaches with no brush in
the way. Once `limit` lines are spent, whatever the flood reaches is taken
to be in sight."""
walker SightFlood {
    has occluder: BrushOccluder,
        eyes: list[Vec3],
        marks: list[list[Vec3]],
        leaves: list[BakeLeaf],
        seen: list[bool],
        source: int,
        rays: int = 0,
        limit: int = 0;

    can look with BakeLeaf entry {
        onward: list[BakeLeaf] = [];
        for way in [edge here->:Opening:->] {
            if self.seen[way.to] or self.leaves[way.to].cluster < 0 {
                continue;
            }
            clear = here.index == self.source or self.rays > self.limit;
            for mark in self.marks[way.portal * 2 + way.side] {
                if clear {
                    break;
                }
                for eye in self.eyes {
                    self.rays += 1;
                    if self.occluder.visibility(eye, mark) > 0.0 {
                        clear = True;
                        break;
                    }
                }
            }
            if clear {
                self.seen[way.to] = True;
                onward.append(self.leaves[way.to]);
            }
        }
        visit onward;
    }
}

"""What a brush is to a bake by planes: 0 fills space and blocks sight, 1
only cuts it (a hint), -1 is nothing to it (clip, triggers, liquids)."""
def:priv plane_kind(sides: list[Side]) -> int {
    names = [side.material.lower().split("/")[-1].split(":")[-1] for side in sides];
    if "hint" in names {
        return 1;
    }
    first = sides[0].material.lower() if sides else "";
    if first.startswith("*") or "water" in first or "slime" in first or "lava" in first {
        return -1;
    }
    passing = ["clip", "playerclip", "monsterclip", "trigger", "origin", "skip", "areaportal", "hint", "fog", "mist"];
    for name in names {
        if name not in passing {
            return 0;
        }
    }
    return -1;
}

"""Sides without the ones the others cut away, with the outline of each."""
def:priv trimmed(sides: list[Side]) -> tuple[list[Side], list[list[Vec3]]] {
    shape = brush_windings(sides);
    kept: list[Side] = [];
    outlines: list[list[Vec3]] = [];
    for index in range(len(sides)) {
        if shape[index] {
            kept.append(sides[index]);
            outlines.append(shape[index]);
        }
    }
    return (kept, outlines);
}

"""Whether outlines reach behind a plane, and in front of it."""
def:priv reaches(shape: list[list[Vec3]], plane: Plane3) -> tuple[bool, bool] {
    behind = False;
    ahead = False;
    for outline in shape {
        for point in outline {
            reach = plane.side(point);
            if reach < -CUT_SLACK {
                behind = True;
            } elif reach > CUT_SLACK {
                ahead = True;
            }
        }
    }
    return (behind, ahead);
}

"""Points on a portal to look from or at: its middle, and its corners drawn
toward the middle by each share given."""
def:priv portal_points(points: list[Vec3], shares: list[float]) -> list[Vec3] {
    middle = Vec3();
    for point in points {
        middle = middle.add(point);
    }
    middle = middle.scale(1.0 / float(max(1, len(points))));
    found: list[Vec3] = [middle];
    for share in shares {
        for point in points {
            found.append(point.add(middle.sub(point).scale(share)));
        }
    }
    return found;
}

"""A bake by the brushes' own planes, a slice at a time. Space is cut by the
planes of the world's brushes (and of hints and area portals) until no
plane cuts a leaf any more, so that each leaf is either inside a brush or
empty; leaves that meet are joined by portals; empty leaves no entity can
come to are filled when the level does not leak; area portals divide the
rest into areas; each face goes to the leaves it lies in, and one that lies
only in brushes is left out (the union of the brushes buries it); and each
empty leaf, a cluster, is given the clusters it can see through the
portals."""
obj PlaneJob(CellJob) {
    has scene: Scene | None = None,
        low: Vec3 = Vec3(),
        high: Vec3 = Vec3(),
        head: int = -1,
        regions: list[Region] = [],
        faces: list[int] = [],
        shapes: list[list[list[Vec3]]] = [],
        bounds: list[list[Side]] = [],
        cells: list[BakeLeaf] = [],
        portals: list[list[Vec3]] = [],
        normals: list[Vec3] = [],
        ends: list[int] = [],
        clusters: list[int] = [],
        rows: bytearray = bytearray(),
        cut: int = 0;

    """How far it has got: the cutting its first fifth (it does not know
    how much there is to cut), the looking the rest."""
    def share -> float {
        now = 1.0;
        if self.phase == "split" {
            now = 0.2 * float(self.cut) / float(self.cut + len(self.regions) * 4 + 40);
        } elif self.phase == "sight" {
            now = 0.2 + 0.8 * float(self.row) / float(max(1, self.count));
        }
        self.said = max(self.said, now);
        return self.said;
    }

    """Cut about `limit` pieces of brushes, or look along about `limit`
    lines of sight, more. True when all is done."""
    def step(limit: int) -> bool {
        outcome = self.outcome;
        if self.phase == "split" {
            work = 0;
            while self.regions and work < max(1, limit) {
                work += self.split_next();
            }
            if self.regions {
                return False;
            }
            self.join();
            self.phase = "sight";
            self.row = 0;
        }
        if self.phase == "sight" {
            stop = outcome.rays + max(1, limit);
            while self.row < self.count and outcome.rays < stop {
                self.look_from(self.row);
                self.row += 1;
            }
            if self.row < self.count {
                return False;
            }
            self.phase = "write";
        }
        if self.phase == "write" {
            self.write();
            self.phase = "done";
        }
        return True;
    }

    """Put a number where a region's goes: a branch's, or a leaf's as
    -(leaf + 1)."""
    def attach(region: Region, number: int) {
        if region.above < 0 {
            self.head = number;
        } elif region.front {
            self.made.bsp.branches[region.above].front = number;
        } else {
            self.made.bsp.branches[region.above].back = number;
        }
    }

    """The plane to cut a region by: one of its pieces' that cuts it,
    across the axes before any other, splitting the fewest pieces and
    leaving the halves even. None when no plane cuts it."""
    def choose(region: Region) -> Plane3 | None {
        known: set[str] = set();
        straight: list[Plane3] = [];
        slanted: list[Plane3] = [];
        for piece in region.pieces {
            for side in piece.sides {
                plane = side.plane;
                normal = plane.normal;
                key = str(round(normal.x, 3)) + " " + str(round(normal.y, 3)) + " " + str(round(normal.z, 3)) + " " + str(round(plane.dist, 2));
                if key in known {
                    continue;
                }
                known.add(key);
                known.add(str(round(-normal.x, 3)) + " " + str(round(-normal.y, 3)) + " " + str(round(-normal.z, 3)) + " " + str(round(-plane.dist, 2)));
                (behind, ahead) = reaches(region.shape, plane);
                if not behind or not ahead {
                    continue;
                }
                if abs(normal.x) > 0.999 or abs(normal.y) > 0.999 or abs(normal.z) > 0.999 {
                    straight.append(plane);
                } else {
                    slanted.append(plane);
                }
            }
        }
        tried = straight if straight else slanted;
        if not tried {
            return None;
        }
        stride = max(1, len(tried) // 24);
        best: Plane3 | None = None;
        best_score = 0;
        for pick in range(0, len(tried), stride) {
            plane = tried[pick];
            splits = 0;
            fronts = 0;
            backs = 0;
            for piece in region.pieces {
                (behind, ahead) = reaches(piece.shape, plane);
                if behind and ahead {
                    splits += 1;
                } elif ahead {
                    fronts += 1;
                } elif behind {
                    backs += 1;
                }
            }
            score = splits * 4 + abs(fronts - backs);
            if best is None or score < best_score {
                best = plane;
                best_score = score;
            }
        }
        return best;
    }

    """Cut the next region in two, or make it a leaf. Answers how much
    work that was."""
    def split_next -> int {
        region = self.regions.pop();
        self.cut += 1;
        plane = self.choose(region);
        if plane is None {
            self.make_leaf(region);
            return 1 + len(region.pieces);
        }
        bsp = self.made.bsp;
        index = len(bsp.branches);
        bsp.planes.append(Plane(normal=plane.normal, distance=plane.dist));
        bsp.branches.append(Branch(plane=len(bsp.planes) - 1, front=0, back=0));
        self.attach(region, index);
        (back_sides, front_sides) = clip_sides(region.sides, plane);
        (back_kept, back_shape) = trimmed(back_sides);
        (front_kept, front_shape) = trimmed(front_sides);
        back = Region(sides=back_kept, shape=back_shape, above=index, front=False);
        front = Region(sides=front_kept, shape=front_shape, above=index, front=True);
        for piece in region.pieces {
            (behind, ahead) = reaches(piece.shape, plane);
            if behind and ahead {
                (piece_back, piece_front) = clip_sides(piece.sides, plane);
                (kept, shape) = trimmed(piece_back);
                if len(kept) >= 4 {
                    back.pieces.append(Piece(sides=kept, shape=shape, kind=piece.kind, portal=piece.portal));
                }
                (kept, shape) = trimmed(piece_front);
                if len(kept) >= 4 {
                    front.pieces.append(Piece(sides=kept, shape=shape, kind=piece.kind, portal=piece.portal));
                }
            } elif ahead {
                front.pieces.append(piece);
            } elif behind {
                back.pieces.append(piece);
            }
        }
        self.regions.append(back);
        self.regions.append(front);
        return 1 + len(region.pieces);
    }

    """A region no plane cuts any more is a leaf: solid when a brush's piece
    fills it (no plane of a piece cuts it, so a piece in it is all of it)."""
    def make_leaf(region: Region) {
        bsp = self.made.bsp;
        number = len(bsp.leaves);
        solid = False;
        portal = 0;
        for piece in region.pieces {
            if piece.kind == 0 {
                solid = True;
            } elif piece.kind == 2 and portal == 0 {
                portal = piece.portal;
            }
        }
        box = windings_bounds(region.shape);
        low = box[0] if box is not None else self.low;
        high = box[1] if box is not None else self.high;
        bsp.leaves.append(Leaf(contents=1 if solid else 0, vis_offset=0, mins=low, maxs=high, cluster=-1));
        self.shapes.append(region.shape);
        self.bounds.append(region.sides);
        outer = low.x <= self.low.x + 1.0 or low.y <= self.low.y + 1.0 or low.z <= self.low.z + 1.0
            or high.x >= self.high.x - 1.0 or high.y >= self.high.y - 1.0 or high.z >= self.high.z - 1.0;
        self.cells.append(BakeLeaf(index=number, solid=solid, portal=portal if not solid else 0, outer=outer));
        self.attach(region, -(number + 1));
    }

    """The leaves a face's outline lies in: cut by each plane it crosses,
    and sent, where it lies on a plane, to the side it faces."""
    def face_leaves(points: list[Vec3], facing: Vec3) -> list[int] {
        bsp = self.made.bsp;
        found: list[int] = [];
        waiting: list[tuple[int, list[Vec3]]] = [(self.head, points)];
        while waiting {
            (at, part) = waiting.pop();
            if at < 0 {
                found.append(-at - 1);
                continue;
            }
            branch = bsp.branches[at];
            cutting = Plane3(normal=bsp.planes[branch.plane].normal, dist=bsp.planes[branch.plane].distance);
            (behind, ahead) = reaches([part], cutting);
            if not behind and not ahead {
                waiting.append((branch.front if facing.dot(cutting.normal) > 0.0 else branch.back, part));
            } elif not behind {
                waiting.append((branch.front, part));
            } elif not ahead {
                waiting.append((branch.back, part));
            } else {
                ahead_part = clip_winding(part, cutting.flipped());
                behind_part = clip_winding(part, cutting);
                if ahead_part {
                    waiting.append((branch.front, ahead_part));
                }
                if behind_part {
                    waiting.append((branch.back, behind_part));
                }
            }
        }
        return found;
    }

    """Once all is cut: the portals and the graph of leaves they join, the
    outside filled, the clusters and areas numbered, and the faces put in
    the leaves they lie in."""
    def join {
        bsp = self.made.bsp;
        outcome = self.outcome;
        count = len(self.cells);
        # Portals: where two empty leaves meet, the face of one cut down by
        # the other's planes.
        for first in range(count) {
            if self.cells[first].solid {
                continue;
            }
            a = bsp.leaves[first];
            for second in range(first + 1, count) {
                b = bsp.leaves[second];
                if self.cells[second].solid or a.mins.x > b.maxs.x + 0.5 or b.mins.x > a.maxs.x + 0.5
                    or a.mins.y > b.maxs.y + 0.5 or b.mins.y > a.maxs.y + 0.5
                    or a.mins.z > b.maxs.z + 0.5 or b.mins.z > a.maxs.z + 0.5 {
                    continue;
                }
                for (place, outline) in enumerate(self.shapes[first]) {
                    plane = self.bounds[first][place].plane;
                    facing = False;
                    for side in self.bounds[second] {
                        if side.plane.normal.dot(plane.normal) < -0.999 and abs(side.plane.dist + plane.dist) < CUT_SLACK {
                            facing = True;
                        }
                    }
                    if not facing {
                        continue;
                    }
                    points = outline;
                    for side in self.bounds[second] {
                        if points {
                            points = clip_winding(points, side.plane);
                        }
                    }
                    points = tidy_winding(points);
                    if points and winding_area(points) > 1.0 {
                        number = len(self.portals);
                        self.portals.append(points);
                        # It faces out of the first leaf, into the second.
                        self.normals.append(plane.normal);
                        self.ends.extend([first, second]);
                        self.cells[first] +>:Opening:portal=number, to=second, side=0:+> self.cells[second];
                        self.cells[second] +>:Opening:portal=number, to=first, side=1:+> self.cells[first];
                    }
                    break;
                }
            }
        }
        outcome.leaves = count;
        outcome.portals = len(self.portals);
        # What a player could come to from where the entities stand; the
        # rest is outside, and filled, unless the outside is come to too.
        seeded = False;
        scene = self.scene;
        for item in (scene.items() if scene is not None else []) {
            stands = item.origin();
            if stands is None or count == 0 {
                continue;
            }
            home = leaf_at(bsp, self.head, stands);
            if not self.cells[home].solid {
                seeded = True;
                self.cells[home] spawn ReachLeaves();
            }
        }
        for cell in self.cells {
            if cell.reached and cell.outer {
                outcome.leaked = True;
            }
        }
        if outcome.leaked {
            self.made.warnings.append("The bake leaks: the space outside the level is reached from inside it, so none of it is filled");
        }
        for cell in self.cells {
            cell.filled = seeded and not outcome.leaked and not cell.solid and not cell.reached;
            if not cell.solid and not cell.filled {
                cell.cluster = len(self.clusters);
                self.clusters.append(cell.index);
            }
        }
        self.count = len(self.clusters);
        outcome.cells = self.count;
        # Areas, where there are area portals to divide them.
        numbers = [cell.portal for cell in self.cells if cell.cluster >= 0 and cell.portal > 0];
        if numbers {
            area = 0;
            for cell in self.cells {
                if cell.cluster >= 0 and cell.portal == 0 and cell.area == 0 {
                    area += 1;
                    cell spawn AreaFlood(area=area);
                }
            }
            sides_of: dict[int, list[int]] = {};
            for cell in self.cells {
                if cell.cluster < 0 or cell.portal == 0 {
                    continue;
                }
                met = sides_of.get(cell.portal, []);
                for way in [edge cell->:Opening:->] {
                    beyond = self.cells[way.to];
                    if beyond.area > 0 and beyond.portal == 0 and beyond.area not in met {
                        met.append(beyond.area);
                    }
                }
                sides_of[cell.portal] = met;
            }
            links: list[list[AreaLink]] = [[] for index in range(area + 1)];
            bsp.areas = links;
            for number in sorted(sides_of.keys()) {
                met = sides_of[number];
                if len(met) != 2 {
                    self.made.warnings.append(
                        "Area portal " + str(number) + " stands between " + str(len(met)) + " areas, not two"
                    );
                }
                if len(met) >= 2 {
                    links[met[0]].append(AreaLink(portal=number, area=met[1]));
                    links[met[1]].append(AreaLink(portal=number, area=met[0]));
                }
            }
            for cell in self.cells {
                if cell.cluster >= 0 and cell.portal > 0 {
                    met = sides_of.get(cell.portal, []);
                    cell.area = met[0] if met else 1;
                }
            }
            outcome.areas = area;
            number = 0;
            for entity in bsp.entities {
                if entity.fields.get("classname", "") == "func_areaportal" {
                    number += 1;
                    entity.fields["style"] = str(number);
                }
            }
        }
        for cell in self.cells {
            record = bsp.leaves[cell.index];
            record.contents = 1 if cell.solid or cell.filled else 0;
            record.cluster = cell.cluster;
            record.area = cell.area;
        }
        # Each face to the empty leaves it lies in; one in none is buried.
        for index in self.faces {
            face = bsp.faces[index];
            if len(face.vertices) < 3 {
                continue;
            }
            placed = False;
            for spot in self.face_leaves(list(face.vertices), face.normal) {
                if self.cells[spot].cluster >= 0 and index not in bsp.leaves[spot].faces {
                    bsp.leaves[spot].faces.append(index);
                    placed = True;
                }
            }
            if not placed {
                outcome.buried += 1;
            }
        }
        # Points on each portal to be seen at, a unit into the leaf on
        # either side of it (a line along a portal's own plane would only
        # graze the brushes beside it), the way it faces first.
        self.marks = [];
        for (number, points) in enumerate(self.portals) {
            normal = self.normals[number];
            spots = portal_points(points, [0.2]);
            self.marks.append([spot.add(normal) for spot in spots]);
            self.marks.append([spot.sub(normal) for spot in spots]);
        }
        width = (self.count + 7) // 8;
        self.rows = bytearray(8 + self.count * width);
    }

    """What one cluster sees, flooded through the portals from its own."""
    def look_from(cluster: int) {
        outcome = self.outcome;
        home = self.cells[self.clusters[cluster]];
        eyes: list[Vec3] = [];
        for way in [edge home->:Opening:->] {
            # A unit into the cluster looked from.
            inward = self.normals[way.portal].scale(-1.0 if way.side == 0 else 1.0);
            for spot in portal_points(self.portals[way.portal], [0.2, 0.6]) {
                eyes.append(spot.add(inward));
            }
        }
        if len(eyes) > 32 {
            stride = len(eyes) / 32.0;
            eyes = [eyes[int(float(pick) * stride)] for pick in range(32)];
        }
        seen = [False for cell in self.cells];
        seen[home.index] = True;
        left = self.budget - outcome.rays;
        flood = SightFlood(
            occluder=self.occluder, eyes=eyes, marks=self.marks, leaves=self.cells, seen=seen, source=home.index,
            limit=left if left > 0 else -1
        );
        home spawn flood;
        outcome.rays += flood.rays;
        if outcome.rays > self.budget {
            outcome.capped = True;
        }
        width = (self.count + 7) // 8;
        for cell in self.cells {
            if seen[cell.index] and cell.cluster >= 0 {
                other = cell.cluster;
                # What one sees sees it back.
                self.rows[8 + cluster * width + other // 8] |= 1 << (other % 8);
                self.rows[8 + other * width + cluster // 8] |= 1 << (cluster % 8);
            }
        }
        outcome.pairs += self.count - 1;
    }

    def write {
        bsp = self.made.bsp;
        outcome = self.outcome;
        count = self.count;
        width = (count + 7) // 8;
        for first in range(count) {
            for second in range(first + 1, count) {
                if int(self.rows[8 + first * width + second // 8]) & (1 << (second % 8)) == 0 {
                    outcome.hidden += 1;
                }
            }
        }
        bsp.clusters = count;
        bsp.cluster_bytes = width;
        bsp.visibility = bytes(self.rows);
        bsp.models[0].head = self.head;
        bsp.models[0].vis_leaf_count = len(bsp.leaves) - 1;
        self.made.shapes = self.shapes;
        self.made.portals = self.portals;
        self.made.portal_ends = self.ends;
    }
}

"""The job of a bake by the brushes' own planes, with `budget` lines of
sight to try. The brushes and the space to cut are gathered now."""
def plane_job(scene: Scene, made: LiveLevel, budget: int = 3000000) -> PlaneJob {
    job = PlaneJob(made=made, budget=budget, scene=scene);
    bsp = made.bsp;
    if len(bsp.models) == 0 or len(bsp.leaves) == 0 {
        return job;
    }
    room = bsp.leaves[0];
    job.low = room.mins;
    job.high = room.maxs;
    job.faces = list(room.faces);
    bsp.leaves = [];
    bsp.branches = [];
    occluder = BrushOccluder();
    pieces: list[Piece] = [];
    number = 0;
    for item in scene.items() {
        name = item.classname();
        if name == "func_areaportal" {
            number += 1;
            for solid in scene.solids_of(item) {
                (kept, shape) = trimmed(solid.sides);
                if len(kept) >= 4 {
                    pieces.append(Piece(sides=kept, shape=shape, kind=2, portal=number));
                }
            }
            continue;
        }
        if name not in ["worldspawn", "func_group"] {
            continue;
        }
        for solid in scene.solids_of(item) {
            kind = plane_kind(solid.sides);
            if kind < 0 {
                continue;
            }
            (kept, shape) = trimmed(solid.sides);
            if len(kept) < 4 {
                continue;
            }
            if kind == 0 {
                occluder.add(solid.sides);
            }
            pieces.append(Piece(sides=kept, shape=shape, kind=kind));
        }
    }
    job.occluder = occluder;
    (around, outline) = trimmed(box_sides(job.low, job.high));
    job.regions = [Region(sides=around, shape=outline, pieces=pieces)];
    job.phase = "split";
    return job;
}

"""Bake a compiled scene's level by its brushes' own planes, all at once."""
def bake_planes(scene: Scene, made: LiveLevel, budget: int = 3000000) -> VisReport {
    job = plane_job(scene, made, budget);
    while not job.step(budget * 4) {
        continue;
    }
    return job.outcome;
}

"""A number as a portal file writes it: whole numbers without a point."""
def:priv portal_number(value: float) -> str {
    whole = round(value);
    if abs(value - float(whole)) < 0.001 {
        return str(int(whole));
    }
    return str(round(value, 3));
}

"""A bake by planes' portals as a compiler's portal file (PRT1, as Quake's
and Quake II's compilers write it for vis and editors to read): the number
of clusters, of portals, then each portal's corners and the two clusters it
joins. Empty for a level not baked by planes."""
def portal_file_text(made: LiveLevel) -> str {
    bsp = made.bsp;
    rows: list[str] = [];
    for (number, points) in enumerate(made.portals) {
        if number * 2 + 1 >= len(made.portal_ends) {
            break;
        }
        first = bsp.leaves[made.portal_ends[number * 2]].cluster;
        second = bsp.leaves[made.portal_ends[number * 2 + 1]].cluster;
        if first < 0 or second < 0 or first == second {
            continue;
        }
        corners = " ".join(
            ["(" + portal_number(point.x) + " " + portal_number(point.y) + " " + portal_number(point.z) + ")" for point in points]
        );
        rows.append(str(len(points)) + " " + str(first) + " " + str(second) + " " + corners);
    }
    if not made.portals {
        return "";
    }
    return "PRT1\n" + str(bsp.clusters) + "\n" + str(len(rows)) + "\n" + "\n".join(rows) + "\n";
}

"""The portals a compiler's portal file holds, each as its corners: any
PRT1 file (Quake III's has a count of faces more before its portals, and a
flag after each portal's clusters). None when the text is not one."""
def portal_file_windings(text: str) -> list[list[Vec3]] | None {
    lines = text.replace("\r", "").split("\n");
    if not lines or not lines[0].strip().startswith("PRT") {
        return None;
    }
    found: list[list[Vec3]] = [];
    for line in lines[1:] {
        if "(" not in line {
            continue;
        }
        points: list[Vec3] = [];
        for part in line.split("(")[1:] {
            numbers = part.split(")")[0].split();
            if len(numbers) != 3 {
                return None;
            }
            try {
                points.append(Vec3(x=float(numbers[0]), y=float(numbers[1]), z=float(numbers[2])));
            } except ValueError {
                return None;
            }
        }
        if len(points) >= 3 {
            found.append(points);
        }
    }
    return found;
}
