"""The yardstick: what a level is like, measured the same way for the
original games' levels and for generated ones.

A level's floors are sampled where the player's hull can stand, on a grid
over every walkable face of the world, and joined by the moves the player
can make between neighbouring places: walking (steps included), jumping up
a ledge and dropping off one. Places gather into areas, nodes of a graph
whose edges are the ways between them, and walkers flood it to find what
can be reached and by which route. Beside the traversal it measures the
level's shape (size, floor levels, how much floor lies over other floor,
headroom, sightlines), its detail (faces for the floor they serve, trim, the
textures used), its light and its population.

Measures are numbers by name (`MEASURES` lists them), so tables of them can
be kept for the original levels (`corpus.jac`) and compared."""
import math;
import from engine.world.level { Level }
import from engine.physics.collision { CollisionMap }
import from engine.formats.bsp { Bsp, Face, MapEntity }
import from engine.physics.movement { step_slide }
import from engine.math.vec3 { Vec3 }

glob YARD_CELL: float = 32.0,
     AREA_SIZE: float = 128.0,
     AREA_BAND: float = 48.0,
     STEP_HEIGHT: float = 18.0,
     JUMP_HEIGHT: float = 44.0,
     STAND_Z: float = 24.0,
     EYE_RISE: float = 22.0;

# Where in a cell a place is looked for: its middle, then a little to each side.
glob NUDGES: list[list[float]] = [
         [0.0, 0.0],
         [8.0, 0.0],
         [-8.0, 0.0],
         [0.0, 8.0],
         [0.0, -8.0],
         [8.0, 8.0],
         [-8.0, -8.0],
         [8.0, -8.0],
         [-8.0, 8.0]
     ];

# Every measure, in the order tables keep them.
glob MEASURES: list[str] = [
         "size_x",
         "size_y",
         "size_z",
         "floor_area",
         "levels",
         "stacked",
         "vrange",
         "headroom_med",
         "headroom_p90",
         "sight_med",
         "sight_p90",
         "near_med",
         "detail",
         "face_area_med",
         "trim_share",
         "textures",
         "lights_per",
         "light_spacing",
         "light_p10",
         "light_p50",
         "light_p90",
         "monsters_per",
         "items_per",
         "areas",
         "cut_share",
         "drop_share",
         "jump_share",
         "reach_share",
         "route_ratio",
         "route_climb"
     ];

"""How a texture is used in a level: the area it covers on floors, walls
and ceilings, how much of its wall area is on narrow strips (trim), how many
faces show it, and what kind of surface it is."""
obj TextureUse {
    has name: str,
        floor: float = 0.0,
        wall: float = 0.0,
        ceiling: float = 0.0,
        trim: float = 0.0,
        faces: int = 0,
        light: bool = False,
        liquid: bool = False,
        sky: bool = False;
}

"""A place the player can stand: the hull's origin there."""
obj Footing {
    has x: float,
        y: float,
        z: float,
        column: int,
        row: int,
        area: int = -1;
}

"""A patch of floor about AREA_SIZE across at one height band."""
node Ground {
    has id: int,
        x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        places: int = 0,
        reached: bool = False,
        best: float = -1.0,
        climb: float = 0.0;
}

"""A way from one area to the next: "walk", "jump" (up a ledge) or "drop"."""
edge Passway: Ground --> Ground {
    has kind: str = "walk";
}

"""Floods the area graph from where it is spawned, marking what it reaches."""
walker Spread {
    has count: int = 0;

    can spread with Ground entry {
        if here.reached {
            return;
        }
        here.reached = True;
        self.count += 1;
        visit [here->:Passway:->];
    }
}

"""A polygon's area."""
def polygon_area(points: list[Vec3]) -> float {
    if len(points) < 3 {
        return 0.0;
    }
    total = Vec3();
    for index in range(1, len(points) - 1) {
        total = total.add(points[index].sub(points[0]).cross(points[index + 1].sub(points[0])));
    }
    return total.length() * 0.5;
}

"""The value `share` of the way through sorted `values` (0 for none)."""
def percentile(values: list[float], share: float) -> float {
    if len(values) == 0 {
        return 0.0;
    }
    ordered = sorted(values);
    at = int(round(share * float(len(ordered) - 1)));
    return ordered[max(0, min(len(ordered) - 1, at))];
}

"""Whether a texture is sky, by its name in any of the games."""
def sky_texture(name: str) -> bool {
    lowered = name.lower();
    return lowered.startswith("sky") or "/sky" in lowered or "skies/" in lowered;
}

"""Whether a texture is a liquid's, by its name in any of the games."""
def liquid_texture(name: str) -> bool {
    lowered = name.lower();
    last = lowered.split("/")[-1];
    return last.startswith("*") or "water" in last or "slime" in last or "lava" in last or "liquids/" in lowered;
}

"""Whether a face of the world gives light: Quake II's light flag, or a
texture named as a light in Quake and Quake III."""
def light_face(bsp: Bsp, face: Face) -> bool {
    if face.texinfo is not None and bsp.game == "q2" and (face.texinfo.flags & 1) != 0 {
        return True;
    }
    if face.texture < 0 or face.texture >= len(bsp.textures) {
        return False;
    }
    lowered = bsp.textures[face.texture].name.lower();
    return "light" in lowered.split("/")[-1] or face.emission;
}

"""The faces of the world model (model 0), or every face when there are no
models."""
def world_faces(bsp: Bsp) -> list[int] {
    if len(bsp.models) == 0 {
        return list(range(len(bsp.faces)));
    }
    world = bsp.models[0];
    return list(range(world.first_face, min(len(bsp.faces), world.first_face + world.face_count)));
}

"""How each texture of the world is used."""
def texture_uses(bsp: Bsp) -> list[TextureUse] {
    found: dict[int, TextureUse] = {};
    for index in world_faces(bsp) {
        face = bsp.faces[index];
        if face.hidden or face.texture < 0 or face.texture >= len(bsp.textures) or len(face.vertices) < 3 {
            continue;
        }
        if face.texture not in found {
            name = bsp.textures[face.texture].name;
            found[face.texture] = TextureUse(name=name, liquid=liquid_texture(name), sky=sky_texture(name));
        }
        use = found[face.texture];
        use.faces += 1;
        if light_face(bsp, face) {
            use.light = True;
        }
        area = face_area(face);
        normal = face.normal;
        if face.patch or not face.planar {
            use.wall += area;
            continue;
        }
        if normal.z >= 0.7 {
            use.floor += area;
        } elif normal.z <= -0.7 {
            use.ceiling += area;
        } else {
            use.wall += area;
            low_z = face.vertices[0].z;
            high_z = low_z;
            across = 0.0;
            for vertex in face.vertices {
                low_z = min(low_z, vertex.z);
                high_z = max(high_z, vertex.z);
                flat = Vec3(x=vertex.x - face.vertices[0].x, y=vertex.y - face.vertices[0].y);
                across = max(across, flat.length());
            }
            if min(high_z - low_z, across) <= 24.0 {
                use.trim += area;
            }
        }
    }
    return list(found.values());
}

"""A face's triangles as corner indices: its own, or a fan over its outline
when it keeps none (Quake's faces)."""
def face_fan(face: Face) -> list[int] {
    if len(face.indices) >= 3 {
        return face.indices;
    }
    fan: list[int] = [];
    for index in range(1, len(face.vertices) - 1) {
        fan.extend([0, index, index + 1]);
    }
    return fan;
}

"""A face's area: its polygon, or for a curved or meshed face its triangles."""
def face_area(face: Face) -> float {
    if face.planar and not face.patch {
        return polygon_area(face.vertices);
    }
    total = 0.0;
    corners = face_fan(face);
    for index in range(0, len(corners) - 2, 3) {
        a = face.vertices[corners[index]];
        b = face.vertices[corners[index + 1]];
        c = face.vertices[corners[index + 2]];
        total += b.sub(a).cross(c.sub(a)).length() * 0.5;
    }
    return total;
}

"""Where an entity is: its origin, or for a brush entity the middle of its
model."""
def entity_spot(bsp: Bsp, entity: MapEntity) -> Vec3 | None {
    model = entity.fields.get("model", "");
    if model.startswith("*") {
        try {
            index = int(model[1:]);
        } except ValueError {
            return None;
        }
        if 0 <= index < len(bsp.models) {
            record = bsp.models[index];
            return record.mins.add(record.maxs).scale(0.5);
        }
        return None;
    }
    words = entity.fields.get("origin", "").split();
    if len(words) != 3 {
        return None;
    }
    try {
        return Vec3(x=float(words[0]), y=float(words[1]), z=float(words[2]));
    } except ValueError {
        return None;
    }
}

"""The hulls of the level's doors (any `func_door*`): left out, so a level
is measured with its doors open. Platforms, trains and bridges stay where
they rest, since they are what carries the player."""
def mover_hulls(collision: CollisionMap, bsp: Bsp) -> list[int] {
    doors: list[int] = [];
    for entity in bsp.entities {
        model = entity.fields.get("model", "");
        if model.startswith("*") and entity.fields.get("classname", "").startswith("func_door") {
            try {
                doors.append(int(model[1:]));
            } except ValueError {
                continue;
            }
        }
    }
    found: list[int] = [];
    for (index, owner) in enumerate(collision.models) {
        if owner > 0 and owner in doors {
            found.append(index);
        }
    }
    return found;
}

"""Places the player can stand, on a grid of `cell` over the world's
walkable faces."""
def stand_places(bsp: Bsp, collision: CollisionMap, exclude: list[int], cell: float = YARD_CELL) -> list[Footing] {
    found: list[Footing] = [];
    heights: dict[int, list[float]] = {};
    for index in world_faces(bsp) {
        face = bsp.faces[index];
        if face.hidden or len(face.vertices) < 3 {
            continue;
        }
        if face.planar and not face.patch and face.normal.z < 0.7 {
            continue;
        }
        name = bsp.textures[face.texture].name if 0 <= face.texture < len(bsp.textures) else "";
        if sky_texture(name) or liquid_texture(name) {
            continue;
        }
        corners = face_fan(face);
        for tri in range(0, len(corners) - 2, 3) {
            a = face.vertices[corners[tri]];
            b = face.vertices[corners[tri + 1]];
            c = face.vertices[corners[tri + 2]];
            normal = b.sub(a).cross(c.sub(a));
            span = normal.length();
            if span < 0.01 {
                continue;
            }
            normal = normal.scale(1.0 / span);
            if abs(normal.z) < 0.7 {
                continue;
            }
            low_column = int(math.floor(min(a.x, min(b.x, c.x)) / cell));
            high_column = int(math.floor(max(a.x, max(b.x, c.x)) / cell));
            low_row = int(math.floor(min(a.y, min(b.y, c.y)) / cell));
            high_row = int(math.floor(max(a.y, max(b.y, c.y)) / cell));
            for column in range(low_column, high_column + 1) {
                for row in range(low_row, high_row + 1) {
                    x = (float(column) + 0.5) * cell;
                    y = (float(row) + 0.5) * cell;
                    weights = inside_triangle(x, y, a, b, c);
                    if weights is None {
                        continue;
                    }
                    z = a.z * weights[0] + b.z * weights[1] + c.z * weights[2];
                    key = column * 65536 + row;
                    seen = heights.get(key, []);
                    near = False;
                    for other in seen {
                        if abs(other - z) < 12.0 {
                            near = True;
                        }
                    }
                    if near {
                        continue;
                    }
                    # On a slope the hull's uphill corners dig in: lift it a
                    # little, as far as a step; beside trim or a pillar the
                    # middle of the cell may be crowded: try a little to
                    # each side, before giving up.
                    origin = Vec3(x=x, y=y, z=z + STAND_Z + 1.0);
                    fits = False;
                    for nudge in NUDGES {
                        for lift in [0.0, 4.0, 9.0, 17.0] {
                            trial = Vec3(x=x + nudge[0], y=y + nudge[1], z=origin.z + lift);
                            if not fits and not collision.trace(trial, trial, exclude).start_solid {
                                origin = trial;
                                fits = True;
                            }
                        }
                    }
                    if not fits {
                        continue;
                    }
                    # Settle onto whatever is under the hull there.
                    landed = collision.trace(origin, Vec3(x=origin.x, y=origin.y, z=origin.z - 24.0), exclude);
                    stood = landed.end.z if landed.fraction < 1.0 else origin.z;
                    seen.append(z);
                    heights[key] = seen;
                    found.append(Footing(x=origin.x, y=origin.y, z=stood, column=column, row=row));
                }
            }
        }
    }
    return found;
}

"""The weights of (x, y) between a triangle's corners seen from above, or
none when it lies outside."""
def inside_triangle(x: float, y: float, a: Vec3, b: Vec3, c: Vec3) -> list[float] | None {
    det = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y);
    if abs(det) < 0.0001 {
        return None;
    }
    first = ((b.y - c.y) * (x - c.x) + (c.x - b.x) * (y - c.y)) / det;
    second = ((c.y - a.y) * (x - c.x) + (a.x - c.x) * (y - c.y)) / det;
    third = 1.0 - first - second;
    if first < -0.001 or second < -0.001 or third < -0.001 {
        return None;
    }
    return [first, second, third];
}

"""Whether walking from one place toward another gets there, by the
engine's own stepping slide (walls slid along, steps climbed), each tick
settled onto the floor; a tick that leaves no floor within a step below is
a fall, not a walk."""
def walk_reaches(collision: CollisionMap, start: Footing, finish: Footing) -> bool {
    pos = Vec3(x=start.x, y=start.y, z=start.z);
    for tick in range(6) {
        gap = Vec3(x=finish.x - pos.x, y=finish.y - pos.y);
        distance = gap.length();
        if distance < 2.0 {
            break;
        }
        speed = min(320.0, distance / 0.05);
        motion = step_slide(collision, pos, gap.scale(speed / distance), 0.05, True);
        fall = collision.trace(motion.pos, motion.pos.add(Vec3(z=-(STEP_HEIGHT + 2.0))));
        if fall.start_solid or fall.fraction >= 1.0 {
            return False;
        }
        pos = fall.end;
    }
    return Vec3(x=finish.x - pos.x, y=finish.y - pos.y).length() < 4.0 and abs(pos.z - finish.z) <= 6.0;
}

"""The move from one place to a neighbouring one, or "" when there is none:
"walk" (level or a step), "jump" (up a ledge) or "drop"."""
def move_between(collision: CollisionMap, exclude: list[int], start: Footing, finish: Footing) -> str {
    rise = finish.z - start.z;
    if abs(rise) <= STEP_HEIGHT {
        return "walk" if walk_reaches(collision, start, finish) else "";
    }
    if rise < 0.0 {
        over = Vec3(x=finish.x, y=finish.y, z=start.z + 1.0);
        out = collision.trace(Vec3(x=start.x, y=start.y, z=start.z + 1.0), over, exclude);
        if out.fraction < 1.0 or out.start_solid {
            return "";
        }
        down = collision.trace(over, Vec3(x=finish.x, y=finish.y, z=finish.z + 1.0), exclude);
        return "drop" if down.fraction >= 1.0 and not down.start_solid else "";
    }
    if rise <= JUMP_HEIGHT {
        high = Vec3(x=start.x, y=start.y, z=finish.z + 4.0);
        up = collision.trace(Vec3(x=start.x, y=start.y, z=start.z + 1.0), high, exclude);
        if up.fraction < 1.0 or up.start_solid {
            return "";
        }
        across = collision.trace(high, Vec3(x=finish.x, y=finish.y, z=finish.z + 4.0), exclude);
        return "jump" if across.fraction >= 1.0 and not across.start_solid else "";
    }
    return "";
}

"""The traversal of a level: its places, the areas they make and the moves
counted between places."""
obj Walkover {
    has places: list[Footing] = [],
        areas: list[Ground] = [],
        walks: int = 0,
        jumps: int = 0,
        drops: int = 0,
        cell: float = YARD_CELL;

    """The place nearest a point, or -1 (only places within `reach`)."""
    def nearest(point: Vec3, reach: float = 96.0) -> int {
        best = -1;
        best_distance = reach;
        for (index, place) in enumerate(self.places) {
            distance = Vec3(x=place.x - point.x, y=place.y - point.y, z=(place.z - point.z) * 2.0).length();
            if distance < best_distance {
                best = index;
                best_distance = distance;
            }
        }
        return best;
    }
}

"""Sample a level's places, join neighbours by moves, gather them into
areas joined by ways."""
def traverse(bsp: Bsp, collision: CollisionMap, cell: float = YARD_CELL) -> Walkover {
    exclude = mover_hulls(collision, bsp);
    # Doors and platforms out of the way while the level is measured.
    opened: list[int] = [];
    for hull in exclude {
        if hull not in collision.disabled {
            collision.set_disabled(hull, True);
            opened.append(hull);
        }
    }
    found = Walkover(places=stand_places(bsp, collision, exclude, cell), cell=cell);
    by_column: dict[int, list[int]] = {};
    for (index, place) in enumerate(found.places) {
        key = place.column * 65536 + place.row;
        here_list = by_column.get(key, []);
        here_list.append(index);
        by_column[key] = here_list;
    }
    # Moves between neighbouring places, each counted once a direction.
    moves: list[list[int]] = [];
    kinds: list[str] = [];
    for (index, place) in enumerate(found.places) {
        for step_x in [-1, 0, 1] {
            for step_y in [-1, 0, 1] {
                if step_x == 0 and step_y == 0 {
                    continue;
                }
                key = (place.column + step_x) * 65536 + (place.row + step_y);
                for other in by_column.get(key, []) {
                    kind = move_between(collision, exclude, place, found.places[other]);
                    if not kind {
                        continue;
                    }
                    if kind == "walk" {
                        found.walks += 1;
                    } elif kind == "jump" {
                        found.jumps += 1;
                    } else {
                        found.drops += 1;
                    }
                    moves.append([index, other]);
                    kinds.append(kind);
                }
            }
        }
    }
    # Areas: the places of one bin (AREA_SIZE across, AREA_BAND up) that walk
    # to each other, so no area spans a wall.
    bins: list[str] = [];
    for place in found.places {
        bins.append(
            str(int(math.floor(place.x / AREA_SIZE))) + "," + str(int(math.floor(place.y / AREA_SIZE))) + ","
                + str(int(math.floor(place.z / AREA_BAND)))
        );
    }
    parent = list(range(len(found.places)));
    for (number, move) in enumerate(moves) {
        if kinds[number] != "walk" or bins[move[0]] != bins[move[1]] {
            continue;
        }
        first_root = move[0];
        while parent[first_root] != first_root {
            first_root = parent[first_root];
        }
        second_root = move[1];
        while parent[second_root] != second_root {
            second_root = parent[second_root];
        }
        if first_root != second_root {
            parent[max(first_root, second_root)] = min(first_root, second_root);
        }
    }
    area_of: dict[int, int] = {};
    sums: list[list[float]] = [];
    for (index, place) in enumerate(found.places) {
        root_index = index;
        while parent[root_index] != root_index {
            root_index = parent[root_index];
        }
        if root_index not in area_of {
            area_of[root_index] = len(sums);
            sums.append([0.0, 0.0, 0.0, 0.0]);
        }
        place.area = area_of[root_index];
        total = sums[place.area];
        total[0] += place.x;
        total[1] += place.y;
        total[2] += place.z;
        total[3] += 1.0;
    }
    for (index, total) in enumerate(sums) {
        count = max(1.0, total[3]);
        found.areas.append(Ground(id=index, x=total[0] / count, y=total[1] / count, z=total[2] / count, places=int(total[3])));
    }
    # Ways between areas, the best move between each two kept.
    linked: dict[int, str] = {};
    for (number, move) in enumerate(moves) {
        tail_area = found.places[move[0]].area;
        head_area = found.places[move[1]].area;
        if tail_area == head_area {
            continue;
        }
        kind = kinds[number];
        pair = tail_area * 1000003 + head_area;
        before = linked.get(pair, "");
        if before == "" or (before != "walk" and kind == "walk") or (before == "drop" and kind == "jump") {
            linked[pair] = kind;
        }
    }
    for (pair, kind) in linked.items() {
        tail = found.areas[pair // 1000003];
        head = found.areas[pair % 1000003];
        tail +>:Passway(kind=kind):+> head;
    }
    for hull in opened {
        collision.set_disabled(hull, False);
    }
    link_teleporters(bsp, found);
    return found;
}

"""Ways for teleporters: from the area where a `trigger_teleport` stands to
the area of the destination it names (`info_teleport_destination`, or any
entity of that name)."""
def link_teleporters(bsp: Bsp, walk: Walkover) {
    named: dict[str, Vec3] = {};
    for entity in bsp.entities {
        name = entity.fields.get("targetname", "");
        if name and entity.fields.get("classname", "") != "trigger_teleport" {
            spot = entity_spot(bsp, entity);
            if spot is not None {
                named[name] = spot;
            }
        }
    }
    for entity in bsp.entities {
        if entity.fields.get("classname", "") != "trigger_teleport" {
            continue;
        }
        target = entity.fields.get("target", "");
        spot = entity_spot(bsp, entity);
        if spot is None or target not in named {
            continue;
        }
        source = walk.nearest(spot, 128.0);
        arrival = walk.nearest(named[target], 128.0);
        if source < 0 or arrival < 0 {
            continue;
        }
        tail = walk.areas[walk.places[source].area];
        head = walk.areas[walk.places[arrival].area];
        if tail.id != head.id {
            tail +>:Passway(kind="teleport"):+> head;
        }
    }
}

"""The share of areas whose loss would cut the area graph (as undirected):
high for corridors strung end to end, low for levels that loop."""
def cut_share(areas: list[Ground]) -> float {
    count = len(areas);
    if count < 3 {
        return 0.0;
    }
    neighbours: list[list[int]] = [[] for _ in range(count)];
    for area in areas {
        for peer in [area->:Passway:->][?:Ground] {
            if peer.id not in neighbours[area.id] {
                neighbours[area.id].append(peer.id);
            }
            if area.id not in neighbours[peer.id] {
                neighbours[peer.id].append(area.id);
            }
        }
    }
    order = [-1 for _ in range(count)];
    low = [0 for _ in range(count)];
    parent = [-1 for _ in range(count)];
    cut = [False for _ in range(count)];
    counter = 0;
    for first_id in range(count) {
        if order[first_id] >= 0 {
            continue;
        }
        children = 0;
        stack: list[list[int]] = [[first_id, 0]];
        order[first_id] = counter;
        low[first_id] = counter;
        counter += 1;
        while stack {
            top = stack[-1];
            node_id = top[0];
            if top[1] < len(neighbours[node_id]) {
                other = neighbours[node_id][top[1]];
                top[1] += 1;
                if order[other] < 0 {
                    parent[other] = node_id;
                    if node_id == first_id {
                        children += 1;
                    }
                    order[other] = counter;
                    low[other] = counter;
                    counter += 1;
                    stack.append([other, 0]);
                } elif other != parent[node_id] {
                    low[node_id] = min(low[node_id], order[other]);
                }
            } else {
                stack.pop();
                above = parent[node_id];
                if above >= 0 {
                    low[above] = min(low[above], low[node_id]);
                    if above != first_id and low[node_id] >= order[above] {
                        cut[above] = True;
                    }
                }
            }
        }
        if children > 1 {
            cut[first_id] = True;
        }
    }
    return float(len([flag for flag in cut if flag])) / float(count);
}

"""The shortest way through the area graph from one area to another (by the
distance between area middles): its length and how much it climbs, or none."""
def area_route(areas: list[Ground], start: int, finish: int) -> list[float] | None {
    count = len(areas);
    if start < 0 or finish < 0 or start >= count or finish >= count {
        return None;
    }
    best = [-1.0 for _ in range(count)];
    climb = [0.0 for _ in range(count)];
    done = [False for _ in range(count)];
    best[start] = 0.0;
    frontier: list[int] = [start];
    while frontier {
        pick = 0;
        for index in range(1, len(frontier)) {
            if best[frontier[index]] < best[frontier[pick]] {
                pick = index;
            }
        }
        current = frontier.pop(pick);
        if done[current] {
            continue;
        }
        done[current] = True;
        if current == finish {
            return [best[current], climb[current]];
        }
        here_area = areas[current];
        for other in [here_area->:Passway:->][?:Ground] {
            if done[other.id] {
                continue;
            }
            gap = Vec3(x=other.x - here_area.x, y=other.y - here_area.y, z=other.z - here_area.z).length();
            total = best[current] + gap;
            if best[other.id] < 0.0 or total < best[other.id] {
                best[other.id] = total;
                climb[other.id] = climb[current] + max(0.0, other.z - here_area.z);
                frontier.append(other.id);
            }
        }
    }
    return None;
}

"""The areas along the shortest way through the area graph from one area
to another, in order (empty when there is none)."""
def area_path(areas: list[Ground], start: int, finish: int) -> list[int] {
    count = len(areas);
    if start < 0 or finish < 0 or start >= count or finish >= count {
        return [];
    }
    best = [-1.0 for _ in range(count)];
    came = [-1 for _ in range(count)];
    done = [False for _ in range(count)];
    best[start] = 0.0;
    frontier: list[int] = [start];
    while frontier {
        pick = 0;
        for index in range(1, len(frontier)) {
            if best[frontier[index]] < best[frontier[pick]] {
                pick = index;
            }
        }
        current = frontier.pop(pick);
        if done[current] {
            continue;
        }
        done[current] = True;
        if current == finish {
            path: list[int] = [finish];
            while path[-1] != start {
                path.append(came[path[-1]]);
            }
            path.reverse();
            return path;
        }
        here_area = areas[current];
        for other in [here_area->:Passway:->][?:Ground] {
            if done[other.id] {
                continue;
            }
            gap = Vec3(x=other.x - here_area.x, y=other.y - here_area.y, z=other.z - here_area.z).length();
            total = best[current] + gap;
            if best[other.id] < 0.0 or total < best[other.id] {
                best[other.id] = total;
                came[other.id] = current;
                frontier.append(other.id);
            }
        }
    }
    return [];
}

"""Where a level is entered: its first player start."""
def level_start(bsp: Bsp) -> Vec3 | None {
    for entity in bsp.entities {
        name = entity.fields.get("classname", "");
        if name in ["info_player_start", "info_player_deathmatch"] {
            return entity_spot(bsp, entity);
        }
    }
    return None;
}

"""Where a level is left: the trigger that changes level (Quake's own, or in
Quake II the trigger that fires a target_changelevel)."""
def level_exit(bsp: Bsp) -> Vec3 | None {
    changers: list[str] = [];
    for entity in bsp.entities {
        name = entity.fields.get("classname", "");
        if name == "trigger_changelevel" {
            return entity_spot(bsp, entity);
        }
        if name == "target_changelevel" {
            changers.append(entity.fields.get("targetname", ""));
        }
    }
    for entity in bsp.entities {
        if entity.fields.get("classname", "").startswith("trigger_") and entity.fields.get("target", "") in changers
            and entity.fields.get("target", "") != "" {
            return entity_spot(bsp, entity);
        }
    }
    return None;
}

"""Everything the yardstick measures of a level, by name."""
def measure_level(level: Level) -> dict[str, float] {
    return measure_parts(level.bsp, level.collision);
}

def measure_parts(bsp: Bsp, collision: CollisionMap, cell: float = YARD_CELL) -> dict[str, float] {
    found: dict[str, float] = {};
    for name in MEASURES {
        found[name] = 0.0;
    }
    walk = traverse(bsp, collision, cell);
    places = walk.places;
    if len(places) == 0 {
        return found;
    }
    exclude = mover_hulls(collision, bsp);
    xs = [place.x for place in places];
    ys = [place.y for place in places];
    zs = [place.z - STAND_Z for place in places];
    found["size_x"] = percentile(xs, 0.98) - percentile(xs, 0.02);
    found["size_y"] = percentile(ys, 0.98) - percentile(ys, 0.02);
    found["size_z"] = percentile(zs, 0.98) - percentile(zs, 0.02);
    floor_area = float(len(places)) * cell * cell;
    found["floor_area"] = floor_area;
    unit = floor_area / 65536.0;
    # Floor levels: height bands of 64 units that hold at least a twentieth
    # of the floor.
    bands: dict[int, int] = {};
    for z in zs {
        band = int(math.floor(z / 64.0));
        bands[band] = bands.get(band, 0) + 1;
    }
    found["levels"] = float(len([band for band in bands.values() if band * 20 >= len(places)]));
    found["vrange"] = percentile(zs, 0.9) - percentile(zs, 0.1);
    columns: dict[int, int] = {};
    for place in places {
        key = place.column * 65536 + place.row;
        columns[key] = columns.get(key, 0) + 1;
    }
    found["stacked"] = float(len([place for place in places if columns[place.column * 65536 + place.row] > 1]))
        / float(len(places));
    # Headroom and sightlines from a spread of places.
    stride = max(1, len(places) // 1500);
    headroom: list[float] = [];
    sights: list[float] = [];
    nearest: list[float] = [];
    for index in range(0, len(places), stride) {
        place = places[index];
        foot = place.z - STAND_Z;
        up = collision.trace_point(
            Vec3(x=place.x, y=place.y, z=foot + 2.0), Vec3(x=place.x, y=place.y, z=foot + 2048.0), exclude
        );
        headroom.append(up.end.z - foot);
        eye = Vec3(x=place.x, y=place.y, z=place.z + EYE_RISE);
        closest = 4096.0;
        for turn in range(8) {
            angle = float(turn) * math.pi / 4.0;
            far = Vec3(x=eye.x + 4096.0 * math.cos(angle), y=eye.y + 4096.0 * math.sin(angle), z=eye.z);
            look = collision.trace_point(eye, far, exclude);
            reach = look.end.sub(eye).length();
            sights.append(reach);
            closest = min(closest, reach);
        }
        nearest.append(closest);
    }
    found["headroom_med"] = percentile(headroom, 0.5);
    found["headroom_p90"] = percentile(headroom, 0.9);
    found["sight_med"] = percentile(sights, 0.5);
    found["sight_p90"] = percentile(sights, 0.9);
    found["near_med"] = percentile(nearest, 0.5);
    # Detail: the faces drawn for the floor they serve, their sizes, trim,
    # and how many textures.
    uses = texture_uses(bsp);
    drawn = 0;
    wall_area = 0.0;
    trim_area = 0.0;
    for use in uses {
        if use.sky {
            continue;
        }
        drawn += use.faces;
        wall_area += use.wall;
        trim_area += use.trim;
    }
    areas: list[float] = [];
    for index in world_faces(bsp) {
        face = bsp.faces[index];
        if not face.hidden and len(face.vertices) >= 3 {
            areas.append(face_area(face));
        }
    }
    found["detail"] = float(drawn) / max(1.0, unit);
    found["face_area_med"] = percentile(areas, 0.5);
    found["trim_share"] = trim_area / max(1.0, wall_area);
    found["textures"] = float(len([use for use in uses if not use.sky]));
    # Light: lamps for the floor and how far apart, and the lightmaps' levels.
    lamps: list[Vec3] = [];
    monsters = 0;
    items = 0;
    for entity in bsp.entities {
        name = entity.fields.get("classname", "");
        if name.startswith("light") {
            spot = entity_spot(bsp, entity);
            if spot is not None {
                lamps.append(spot);
            }
        } elif name.startswith("monster_") {
            monsters += 1;
        } elif name.startswith("item_") or name.startswith("weapon_") or name.startswith("ammo_") {
            items += 1;
        }
    }
    found["lights_per"] = float(len(lamps)) / max(1.0, unit);
    gaps: list[float] = [];
    for (index, lamp) in enumerate(lamps[:600]) {
        closest = -1.0;
        for (other_index, other) in enumerate(lamps) {
            if other_index != index {
                gap = lamp.sub(other).length();
                if closest < 0.0 or gap < closest {
                    closest = gap;
                }
            }
        }
        if closest >= 0.0 {
            gaps.append(closest);
        }
    }
    found["light_spacing"] = percentile(gaps, 0.5);
    levels: list[float] = [];
    lighting = bsp.lighting;
    step = max(1, len(lighting) // 20000);
    for index in range(0, len(lighting), step) {
        levels.append(float(lighting[index]));
    }
    found["light_p10"] = percentile(levels, 0.1);
    found["light_p50"] = percentile(levels, 0.5);
    found["light_p90"] = percentile(levels, 0.9);
    found["monsters_per"] = float(monsters) / max(1.0, unit);
    found["items_per"] = float(items) / max(1.0, unit);
    # Walkover.
    found["areas"] = float(len(walk.areas));
    found["cut_share"] = cut_share(walk.areas);
    moves = max(1, walk.walks + walk.jumps + walk.drops);
    found["drop_share"] = float(walk.drops) / float(moves);
    found["jump_share"] = float(walk.jumps) / float(moves);
    found["reach_share"] = -1.0;
    found["route_ratio"] = -1.0;
    found["route_climb"] = -1.0;
    start = level_start(bsp);
    if start is not None {
        first = walk.nearest(start);
        if first >= 0 {
            origin = walk.areas[places[first].area];
            flood = origin spawn Spread();
            found["reach_share"] = float(flood.count) / float(max(1, len(walk.areas)));
            finish = level_exit(bsp);
            if finish is not None {
                last = walk.nearest(finish, 256.0);
                if last >= 0 {
                    route = area_route(walk.areas, places[first].area, places[last].area);
                    if route is not None {
                        straight = Vec3(x=finish.x - start.x, y=finish.y - start.y, z=finish.z - start.z).length();
                        found["route_ratio"] = route[0] / max(64.0, straight);
                        found["route_climb"] = route[1];
                    }
                }
            }
        }
    }
    return found;
}
