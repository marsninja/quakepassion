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
import from engine.formats.bsp { Bsp, Leaf, Branch, Plane }
import from ..document.scene { Scene }
import from ..geometry.brush { Side, brush_holds }
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
        capped: bool = False;
}

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
