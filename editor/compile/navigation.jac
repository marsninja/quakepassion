"""Navigation for bots, baked from a level's floors. The games' bots route
over areas and the ways between them (`engine/world/bot_routes.jac`, read
from a shipped arena's AAS file); a scene made here has no such file, so
its floors are sampled on a grid and written out as the same data: an area
for each place to stand, a way from each to its neighbours (walked when the
step between them is small, jumped up when it is a ledge, dropped off when
it is a fall), and a tree that says which area a point is in. The engine's
own router then finds routes over it."""

import math;
import struct;
import from engine.math.vec3 { Vec3 }
import from engine.world.bot_routes { NavMesh, NavArea, Passage, Exits, Enters, UNREACHED }
import from engine.formats.aas {
    Aas,
    AasArea,
    AasReach,
    TRAVEL_WALK,
    TRAVEL_BARRIERJUMP,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_TELEPORT,
    TRAVEL_JUMPPAD,
    TRAVEL_LADDER,
    TRAVEL_SWIM,
    TRAVEL_ELEVATOR,
    TFL_DEFAULT,
    AREA_GROUNDED
}

"""A place to stand: a cell of the grid, and how high its floor is."""
obj Floor {
    has column: int,
        row: int,
        z: float;
}

"""A way from one floor to another, by their places in the list of floors."""
obj Way {
    has source: int,
        target: int,
        kind: int = TRAVEL_WALK,
        model: int = 0;
}

"""A way the level's entities make, not its floors: a teleporter from where
its trigger is to where it sends, a jump pad from its trigger to where it
throws. By points in the level, and the kind of travel."""
obj Link {
    has start: Vec3,
        finish: Vec3,
        kind: int = TRAVEL_TELEPORT,
        # A lift's model in the built level (its elevator's), else nothing.
        model: int = 0;
}

"""The floor whose middle is nearest a point: on the cell the point is over,
or one beside it, the highest that is not above the point (where one would
stand there), and no further below it than `reach_down`. -1 when there is
none."""
def floor_under(floors: list[Floor], origin: Vec3, cell: float, point: Vec3, reach_down: float = 1000000.0) -> int {
    column = int(math.floor((point.x - origin.x) / cell));
    row = int(math.floor((point.y - origin.y) / cell));
    found = -1;
    best = 0.0;
    for (index, floor) in enumerate(floors) {
        if abs(floor.column - column) > 1 or abs(floor.row - row) > 1 or floor.z > point.z + 8.0
            or floor.z < point.z - reach_down {
            continue;
        }
        # Nearer cells first, then the floor nearest below.
        score = float(abs(floor.column - column) + abs(floor.row - row)) * 10000.0 + (point.z - floor.z);
        if found < 0 or score < best {
            found = index;
            best = score;
        }
    }
    return found;
}

"""The ways the entities' links make between floors: from the floor under
each link's start to the floor under its finish."""
def linked_ways(floors: list[Floor], origin: Vec3, cell: float, links: list[Link]) -> list[Way] {
    found: list[Way] = [];
    for link in links {
        source = floor_under(floors, origin, cell, link.start);
        # A ladder or a lift ends at its own height: the floor there, not the one it rose from.
        target = floor_under(floors, origin, cell, link.finish, 48.0 if link.kind in [TRAVEL_LADDER, TRAVEL_ELEVATOR] else 1000000.0);
        if source >= 0 and target >= 0 and source != target {
            found.append(Way(source=source, target=target, kind=link.kind, model=link.model));
        }
    }
    return found;
}

"""How tall a step is walked up, how high a ledge is jumped onto, and how
far a fall is dropped down (Quake III's own: 18, a 44-unit barrier jump,
and a fall a bot will take)."""
glob NAV_STEP: float = 18.0,
     NAV_JUMP: float = 44.0,
     NAV_DROP: float = 256.0;

"""The ways the floors' own heights allow between neighbouring cells (the
four beside each cell). Whether anything stands between two floors is not
known here: whoever has the level takes those ways out."""
def floor_ways(floors: list[Floor], step: float = 18.0, jump: float = 44.0, drop: float = 256.0) -> list[Way] {
    by_cell: dict[tuple[int, int], list[int]] = {};
    for (index, floor) in enumerate(floors) {
        key = (floor.column, floor.row);
        if key not in by_cell {
            by_cell[key] = [];
        }
        by_cell[key].append(index);
    }
    found: list[Way] = [];
    for (index, floor) in enumerate(floors) {
        for (across, up) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            beside = by_cell.get((floor.column + across, floor.row + up), []);
            # Of the floors of the cell beside, the one a walk or a jump reaches (the
            # highest within reach), and the highest below to drop to.
            level = -1;
            below = -1;
            for other in beside {
                rise = floors[other].z - floor.z;
                if rise <= jump and rise >= -step {
                    if level < 0 or floors[other].z > floors[level].z {
                        level = other;
                    }
                } elif rise < -step and rise >= -drop {
                    if below < 0 or floors[other].z > floors[below].z {
                        below = other;
                    }
                }
            }
            if level >= 0 {
                rise = floors[level].z - floor.z;
                found.append(Way(source=index, target=level, kind=TRAVEL_WALK if rise <= step else TRAVEL_BARRIERJUMP));
            } elif below >= 0 {
                found.append(Way(source=index, target=below, kind=TRAVEL_WALKOFFLEDGE));
            }
        }
    }
    return found;
}

"""Where a floor's cell is in the world: its middle, at the floor's height."""
def floor_middle(floor: Floor, origin: Vec3, cell: float) -> Vec3 {
    return Vec3(
        x=origin.x + (float(floor.column) + 0.5) * cell, y=origin.y + (float(floor.row) + 0.5) * cell, z=floor.z
    );
}

"""The tree's nodes for one cell: from its highest floor down, a point above
a floor is in that floor's area; under the lowest it is in none."""
def:priv stack_node(made: Aas, layers: list[tuple[float, int]]) -> int {
    child = 0;
    for (height, area) in layers {
        made.normals.append(Vec3(z=1.0));
        made.dists.append(height - 1.0);
        made.node_planes.append(len(made.normals) - 1);
        made.front.append(-area);
        made.back.append(child);
        child = len(made.node_planes) - 1;
    }
    return child;
}

"""The tree's nodes for a run of cells along one axis of the grid: halved
until one is left, which goes on to `leaf`."""
def:priv split_node(
    made: Aas, axis: int, low: int, high: int, start_at: float, cell: float, other: int,
    cells: dict[tuple[int, int], list[tuple[float, int]]], bounds: list[int], origin: Vec3
) -> int {
    if high - low <= 1 {
        if axis == 0 {
            # One column: now along the rows.
            return split_node(made, 1, bounds[2], bounds[3] + 1, origin.y, cell, low, cells, bounds, origin);
        }
        return stack_node(made, cells.get((other, low), []));
    }
    middle = (low + high) // 2;
    under = split_node(made, axis, low, middle, start_at, cell, other, cells, bounds, origin);
    over = split_node(made, axis, middle, high, start_at, cell, other, cells, bounds, origin);
    if under == 0 and over == 0 {
        return 0;
    }
    made.normals.append(Vec3(x=1.0) if axis == 0 else Vec3(y=1.0));
    made.dists.append(start_at + float(middle) * cell);
    made.node_planes.append(len(made.normals) - 1);
    made.front.append(over);
    made.back.append(under);
    return len(made.node_planes) - 1;
}

"""The navigation data for floors and the ways between them. `origin` is the
grid's low corner and `cell` how wide a cell is. Area `n + 1` is floor `n`
(area 0 is nowhere, as in the games' own data)."""
def nav_data(floors: list[Floor], ways: list[Way], origin: Vec3, cell: float, tall: float = 56.0) -> Aas {
    made = Aas(areas=[AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3())]);
    # The tree's first node is its root: kept for last, when the rest is known.
    made.normals.append(Vec3(z=1.0));
    made.dists.append(0.0);
    made.node_planes = [0, 0];
    made.front = [0, 0];
    made.back = [0, 0];
    half = cell * 0.5;
    for floor in floors {
        middle = floor_middle(floor, origin, cell);
        made.areas.append(
            AasArea(
                center=Vec3(x=middle.x, y=middle.y, z=middle.z + 24.0),
                mins=Vec3(x=middle.x - half, y=middle.y - half, z=middle.z),
                maxs=Vec3(x=middle.x + half, y=middle.y + half, z=middle.z + tall),
                flags=AREA_GROUNDED
            )
        );
    }
    # A floor's ways out, one after another, as the router reads them.
    made.reaches.append(AasReach(area=0, start=Vec3(), finish=Vec3(), kind=0, time=0));
    by_source: dict[int, list[Way]] = {};
    for way in ways {
        if way.source < 0 or way.source >= len(floors) or way.target < 0 or way.target >= len(floors) {
            continue;
        }
        if way.source not in by_source {
            by_source[way.source] = [];
        }
        by_source[way.source].append(way);
    }
    for index in range(len(floors)) {
        area = made.areas[index + 1];
        area.first_reach = len(made.reaches);
        from_at = floor_middle(floors[index], origin, cell);
        for way in by_source.get(index, []) {
            to_at = floor_middle(floors[way.target], origin, cell);
            # It is left where the two cells meet, and arrived at just past that.
            between = from_at.add(to_at).scale(0.5);
            start = Vec3(x=between.x, y=between.y, z=from_at.z + 24.0);
            finish = Vec3(
                x=between.x + (to_at.x - from_at.x) * 0.125,
                y=between.y + (to_at.y - from_at.y) * 0.125,
                z=to_at.z + 24.0
            );
            time = 1;
            if way.kind in [TRAVEL_TELEPORT, TRAVEL_JUMPPAD, TRAVEL_LADDER, TRAVEL_ELEVATOR] {
                # Left from the middle of the floor the trigger is over, arrived at the far one's.
                start = Vec3(x=from_at.x, y=from_at.y, z=from_at.z + 24.0);
                finish = Vec3(x=to_at.x, y=to_at.y, z=to_at.z + 24.0);
                # A teleporter at once; a ladder or a lift by how far up or down, a jump pad by how far.
                time = 5;
                if way.kind == TRAVEL_JUMPPAD {
                    time = int(to_at.sub(from_at).length() / 4.0) + 50;
                } elif way.kind == TRAVEL_LADDER {
                    time = int(abs(to_at.z - from_at.z) / 2.0) + 10;
                } elif way.kind == TRAVEL_ELEVATOR {
                    time = int(abs(to_at.z - from_at.z) / 1.5) + 100;
                }
            } elif way.kind == TRAVEL_SWIM {
                time = 3;
            } elif way.kind == TRAVEL_BARRIERJUMP {
                time = 50;
            } elif way.kind == TRAVEL_WALKOFFLEDGE {
                # As long as the fall takes, in hundredths of a second, under the games' gravity.
                time = int(math.sqrt(2.0 * max(0.0, from_at.z - to_at.z) / 800.0) * 100.0) + 1;
            }
            made.reaches.append(
                AasReach(area=way.target + 1, start=start, finish=finish, kind=way.kind, time=time, face_num=way.model)
            );
        }
        area.reach_count = len(made.reaches) - area.first_reach;
    }
    if len(floors) == 0 {
        return made;
    }
    cells: dict[tuple[int, int], list[tuple[float, int]]] = {};
    bounds = [floors[0].column, floors[0].column, floors[0].row, floors[0].row];
    for (index, floor) in enumerate(floors) {
        key = (floor.column, floor.row);
        if key not in cells {
            cells[key] = [];
        }
        cells[key].append((floor.z, index + 1));
        bounds = [min(bounds[0], floor.column), max(bounds[1], floor.column), min(bounds[2], floor.row), max(bounds[3], floor.row)];
    }
    for key in cells.keys() {
        cells[key] = sorted(cells[key]);
    }
    top = split_node(made, 0, bounds[0], bounds[1] + 1, origin.x, cell, 0, cells, bounds, origin);
    # Round the grid, four planes past which a point is nowhere: beyond its
    # low and its high edge, across and along.
    for (axis, low_side, at) in [
        (0, True, origin.x + float(bounds[0]) * cell),
        (0, False, origin.x + float(bounds[1] + 1) * cell),
        (1, True, origin.y + float(bounds[2]) * cell),
        (1, False, origin.y + float(bounds[3] + 1) * cell)
    ] {
        made.normals.append(Vec3(x=1.0) if axis == 0 else Vec3(y=1.0));
        made.dists.append(at);
        made.node_planes.append(len(made.normals) - 1);
        made.front.append(top if low_side else 0);
        made.back.append(0 if low_side else top);
        top = len(made.node_planes) - 1;
    }
    # The root sends every point on to the tree that was built.
    made.dists[0] = -1000000.0;
    made.front[1] = top;
    made.back[1] = top;
    return made;
}

"""How many ways of each kind: [walked, jumped up, dropped]."""
def ways_count(ways: list[Way]) -> list[int] {
    return [
        len([way for way in ways if way.kind == TRAVEL_WALK]),
        len([way for way in ways if way.kind == TRAVEL_BARRIERJUMP]),
        len([way for way in ways if way.kind == TRAVEL_WALKOFFLEDGE])
    ];
}

"""How long the way from one place to another is over a baked mesh, in
hundredths of a second as the router counts: 0 when they are in one area,
-1 when one of them is on no floor or there is no way."""
def route_time(mesh: NavMesh, origin: Vec3, goal: Vec3) -> int {
    from_area = mesh.locate(origin);
    goal_area = mesh.locate(goal);
    if from_area == 0 or goal_area == 0 {
        return -1;
    }
    if from_area == goal_area {
        return 0;
    }
    times = mesh.times_to(goal_area);
    return times[from_area] if times[from_area] < UNREACHED else -1;
}

"""One leg of a way over the mesh: an area left at `start` and the next
arrived in at `finish`, by a travel `kind` (walked, jumped, dropped and the
games' others), taking `time` hundredths of a second."""
obj Leg {
    has start: Vec3,
        finish: Vec3,
        kind: int,
        time: int;
}

"""Walks the way a bot would take to a goal area: from the area it is set
down in, out by the passage that leaves the least time still to go, into
the area that passage enters, and on until it stands in the goal's. `times`
is the mesh's table for the goal. `lost` is set when it cannot go on."""
walker Descend {
    has times: list[int],
        goal: int,
        allowed: int = TFL_DEFAULT,
        legs: list[Leg] = [],
        lost: bool = False;

    can leave with NavArea entry {
        if here.index == self.goal {
            disengage;
        }
        # A way never passes through more areas than there are.
        if self.times[here.index] >= UNREACHED or len(self.legs) >= len(self.times) {
            self.lost = True;
            disengage;
        }
        best: Passage | None = None;
        least = UNREACHED;
        for passage in [here->:Exits:->][?:Passage] {
            if self.times[passage.target] >= UNREACHED or passage.flags & ~self.allowed != 0 {
                continue;
            }
            left = passage.cost + self.times[passage.target];
            if left < least {
                least = left;
                best = passage;
            }
        }
        if best is None {
            self.lost = True;
            disengage;
        }
        visit best;
    }

    can cross with Passage entry {
        self.legs.append(Leg(start=here.start, finish=here.finish, kind=here.kind, time=here.cost));
        visit [here->:Enters:->];
    }
}

"""The legs of the way from one place to another over a mesh, as the games'
bots would take it: none when they are in one area, and None when one of
them is on no floor or there is no way."""
def route_legs(mesh: NavMesh, origin: Vec3, goal: Vec3) -> list[Leg] | None {
    from_area = mesh.locate(origin);
    goal_area = mesh.locate(goal);
    if from_area == 0 or goal_area == 0 {
        return None;
    }
    if from_area == goal_area {
        return [];
    }
    times = mesh.times_to(goal_area);
    if times[from_area] >= UNREACHED {
        return None;
    }
    walked = mesh.areas[from_area] spawn Descend(times=times, goal=goal_area);
    return None if walked.lost else walked.legs;
}

"""The corners of a way, to draw it by: where it begins, where each leg is
left and arrived at, and where it ends."""
def route_corners(origin: Vec3, legs: list[Leg], goal: Vec3) -> list[Vec3] {
    found = [origin];
    for leg in legs {
        found.append(leg.start);
        found.append(leg.finish);
    }
    found.append(goal);
    return found;
}

"""How many of a way's legs are of each kind: [walked, jumped up, dropped,
the games' other kinds]."""
def legs_count(legs: list[Leg]) -> list[int] {
    counts = [0, 0, 0, 0];
    for leg in legs {
        if leg.kind == TRAVEL_WALK {
            counts[0] += 1;
        } elif leg.kind == TRAVEL_BARRIERJUMP {
            counts[1] += 1;
        } elif leg.kind == TRAVEL_WALKOFFLEDGE {
            counts[2] += 1;
        } else {
            counts[3] += 1;
        }
    }
    return counts;
}

"""How high the water a point is in comes (the top of the highest of the
liquids' boxes holding it), or far below anything when it is in none."""
def:priv water_top(waters: list[list[Vec3]], point: Vec3) -> float {
    top = -1000000.0;
    for box in waters {
        # In it, or on its top (a liquid the studio builds is stood on, as a floor is).
        if point.x >= box[0].x and point.x <= box[1].x and point.y >= box[0].y and point.y <= box[1].y
            and point.z >= box[0].z and point.z <= box[1].z + 8.5 {
            top = max(top, box[1].z);
        }
    }
    return top;
}

"""The ways water opens: two floors beside each other where one is under
water (`waters`, the liquids' boxes as [low, high]) are swum between, both
ways, when the higher of them is no further above the water than a player
climbs out (`climb`); deep water's floors are joined to the shore so."""
def swim_ways(floors: list[Floor], origin: Vec3, cell: float, waters: list[list[Vec3]], climb: float = 24.0) -> list[Way] {
    found: list[Way] = [];
    if len(waters) == 0 {
        return found;
    }
    tops = [water_top(waters, floor_middle(floor, origin, cell).add(Vec3(z=8.0))) for floor in floors];
    by_cell: dict[tuple[int, int], list[int]] = {};
    for (index, floor) in enumerate(floors) {
        key = (floor.column, floor.row);
        if key not in by_cell {
            by_cell[key] = [];
        }
        by_cell[key].append(index);
    }
    for (index, floor) in enumerate(floors) {
        for (across, up) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            for other in by_cell.get((floor.column + across, floor.row + up), []) {
                surface = max(tops[index], tops[other]);
                if surface < -999999.0 {
                    continue;
                }
                if max(floor.z, floors[other].z) <= surface + climb {
                    found.append(Way(source=index, target=other, kind=TRAVEL_SWIM));
                }
            }
        }
    }
    return found;
}

"""A navigation's data as an arena's file: Quake III's AAS (version 5, its
header hidden as be_aas_file.c hides it), with the lumps a router reads:
the tree's planes and nodes, the areas with their settings, and the ways
between them. The others (faces, edges, portals, clusters) are empty."""
def aas_bytes(aas: Aas) -> bytes {
    planes = bytearray();
    for (index, normal) in enumerate(aas.normals) {
        planes.extend(struct.pack("<ffffi", normal.x, normal.y, normal.z, aas.dists[index] if index < len(aas.dists) else 0.0, 0));
    }
    nodes = bytearray();
    for index in range(len(aas.node_planes)) {
        nodes.extend(struct.pack("<iii", aas.node_planes[index], aas.front[index], aas.back[index]));
    }
    areas = bytearray();
    settings = bytearray();
    for (index, area) in enumerate(aas.areas) {
        areas.extend(
            struct.pack(
                "<iiifffffffff", index, 0, 0, area.mins.x, area.mins.y, area.mins.z, area.maxs.x, area.maxs.y, area.maxs.z,
                area.center.x, area.center.y, area.center.z
            )
        );
        settings.extend(struct.pack("<iiiiiii", area.contents, area.flags, area.presence, 0, 0, area.reach_count, area.first_reach));
    }
    reaches = bytearray();
    for reach in aas.reaches {
        reaches.extend(
            struct.pack(
                "<iiiffffffiHH", reach.area, reach.face_num, reach.edge_num, reach.start.x, reach.start.y, reach.start.z,
                reach.finish.x, reach.finish.y, reach.finish.z, reach.kind, reach.time & 65535, 0
            )
        );
    }
    lumps: list[bytes] = [b"" for index in range(14)];
    lumps[2] = bytes(planes);
    lumps[7] = bytes(areas);
    lumps[8] = bytes(settings);
    lumps[9] = bytes(reaches);
    lumps[10] = bytes(nodes);
    header = bytearray(struct.pack("<ii", aas.checksum, 0)[:4]);
    at = 8 + 4 + 14 * 8;
    for piece in lumps {
        header.extend(struct.pack("<ii", at, len(piece)));
        at += len(piece);
    }
    # be_aas_file.c AAS_DData: each header byte after the version XORed with its offset times 119.
    for k in range(len(header)) {
        header[k] = header[k] ^ ((k * 119) & 255);
    }
    made = bytearray(b"EAAS") + bytearray(struct.pack("<i", 5)) + header;
    for piece in lumps {
        made.extend(piece);
    }
    return bytes(made);
}
