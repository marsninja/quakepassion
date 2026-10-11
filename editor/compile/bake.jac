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

"""Divide a compiled scene's level into cells and work out which see which.
`cell` is how wide a cell may be; `budget` how many lines of sight may be
tried. A level that fits one cell is left as the one leaf it was."""
def bake_cells(scene: Scene, made: LiveLevel, cell: float = 256.0, budget: int = 1500000) -> VisReport {
    outcome = VisReport();
    bsp = made.bsp;
    if len(bsp.models) == 0 or len(bsp.leaves) == 0 or cell < 16.0 {
        return outcome;
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
    if count < 2 {
        bsp.leaves[0].faces = faces;
        bsp.models[0].head = -1;
        return outcome;
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
    # Points through each cell: its middle and toward its corners, at
    # heights up through the level, where that is not in a wall.
    occluder = scene_occluder(scene);
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
    seeded = len(waiting) > 0;
    turn = 0;
    while turn < len(waiting) and outcome.rays < budget // 2 {
        (cell_from, point_from) = waiting[turn];
        turn += 1;
        origin = lattice[cell_from][point_from];
        for cell_index in beside[cell_from] {
            for (index, spot) in enumerate(lattice[cell_index]) {
                if reached[cell_index][index] {
                    continue;
                }
                outcome.rays += 1;
                if occluder.visibility(origin, spot) > 0.0 {
                    reached[cell_index][index] = True;
                    waiting.append((cell_index, index));
                }
            }
        }
    }
    flooded = seeded and turn >= len(waiting);
    eyes: list[list[Vec3]] = [];
    for index in range(count) {
        eyes.append(
            [lattice[index][place] for place in range(len(lattice[index])) if not flooded or reached[index][place]]
        );
    }
    # Which sees which.
    sees: list[list[bool]] = [[False for other in range(count)] for index in range(count)];
    for first in range(count) {
        sees[first][first] = True;
        for second in range(first + 1, count) {
            outcome.pairs += 1;
            seen = cells_touch(bsp.leaves[first], bsp.leaves[second]) or outcome.capped;
            if not seen {
                # From where one could stand in either to where one could
                # stand in, or to the faces of, the other.
                for (near, far) in [(first, second), (second, first)] {
                    if seen {
                        break;
                    }
                    targets = eyes[far] + marks[far];
                    stride = max(1, len(targets) // 48);
                    for eye in eyes[near] {
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
                    if outcome.rays > budget {
                        # Out of patience: what is left is taken to be in sight.
                        outcome.capped = True;
                        seen = True;
                    }
                }
            }
            sees[first][second] = seen;
            sees[second][first] = seen;
            if not seen {
                outcome.hidden += 1;
            }
        }
    }
    # A row of bits a cluster, after the eight bytes a level's visibility begins with.
    width = (count + 7) // 8;
    rows = bytearray(8 + count * width);
    for first in range(count) {
        for second in range(count) {
            if sees[first][second] {
                rows[8 + first * width + second // 8] |= 1 << (second % 8);
            }
        }
    }
    bsp.clusters = count;
    bsp.cluster_bytes = width;
    bsp.visibility = bytes(rows);
    return outcome;
}

"""Whether, in a baked level, one cell sees another."""
def cell_sees(bsp: Bsp, first: int, second: int) -> bool {
    if bsp.clusters <= 0 or first < 0 or second < 0 or first >= bsp.clusters or second >= bsp.clusters {
        return True;
    }
    return int(bsp.visibility[8 + first * bsp.cluster_bytes + second // 8]) & (1 << (second % 8)) != 0;
}
