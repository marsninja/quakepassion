"""The cast: everything an expedition puts in its spaces besides their
architecture. The player's start, what each objective is (a key on a stage,
a switch, a guardian whose death opens a way), the doors the mission's locks
become and what opens them, teleporters where a corridor could not be
routed, the exit, and the population: foes by each room's threat budget,
health, armour and shells by what the way there costs.

Foes come from a roster of all three games, weighted toward the game of
each district's kit; places to stand them on come from the massing (floor
with headroom, away from doorways and stairs), perches from floors high in
their room."""
import math;
import from engine.math.vec3 { Vec3 }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { Side }
import from .random { Stream }
import from .massing { Massing, CELL, LIFT }
import from .spaces { Space, Doorway, OPEN_HIGH }
import from .arrange { Estate, Corridor, estate_spaces, estate_corridors, CORRIDOR_HIGH }
import from .mission { Expedition, Beat, beats_of }
import from .kits { Kit, kit_of }
import from .dress { box_brush, plain_box }

obj Foe {
    has kind: str,
        source: str,
        health: int,
        cost: float,
        role: str = "melee",
        rank: int = 1;
}

glob CAST_ROSTER: list[Foe] = [
         Foe(kind="monster_army", source="q1", health=30, cost=1.0, role="ranged"),
         Foe(kind="monster_dog", source="q1", health=25, cost=0.8, role="melee"),
         Foe(kind="monster_knight", source="q1", health=75, cost=1.8, role="melee"),
         Foe(kind="monster_enforcer", source="q1", health=80, cost=2.6, role="ranged", rank=2),
         Foe(kind="monster_wizard", source="q1", health=80, cost=2.6, role="fly", rank=2),
         Foe(kind="monster_ogre", source="q1", health=200, cost=5.0, role="ranged", rank=3),
         Foe(kind="monster_demon1", source="q1", health=300, cost=6.0, role="melee", rank=3),
         Foe(kind="monster_hell_knight", source="q1", health=250, cost=6.0, role="ranged", rank=3),
         Foe(kind="monster_shalrath", source="q1", health=400, cost=8.0, role="ranged", rank=4),
         Foe(kind="monster_shambler", source="q1", health=600, cost=12.0, role="ranged", rank=5),
         Foe(kind="monster_soldier_light", source="q2", health=20, cost=0.8, role="ranged"),
         Foe(kind="monster_soldier", source="q2", health=30, cost=1.0, role="ranged"),
         Foe(kind="monster_soldier_ss", source="q2", health=40, cost=1.4, role="ranged"),
         Foe(kind="monster_infantry", source="q2", health=100, cost=2.8, role="ranged", rank=2),
         Foe(kind="monster_flyer", source="q2", health=50, cost=1.6, role="fly", rank=2),
         Foe(kind="monster_parasite", source="q2", health=175, cost=4.0, role="melee", rank=3),
         Foe(kind="monster_gunner", source="q2", health=175, cost=4.5, role="ranged", rank=3),
         Foe(kind="monster_chick", source="q2", health=175, cost=4.5, role="ranged", rank=3),
         Foe(kind="monster_berserk", source="q2", health=240, cost=4.8, role="melee", rank=3),
         Foe(kind="monster_floater", source="q2", health=200, cost=5.0, role="fly", rank=3),
         Foe(kind="monster_mutant", source="q2", health=300, cost=6.0, role="melee", rank=4),
         Foe(kind="monster_brain", source="q2", health=300, cost=6.0, role="melee", rank=4),
         Foe(kind="monster_hover", source="q2", health=240, cost=6.0, role="fly", rank=4),
         Foe(kind="monster_gladiator", source="q2", health=400, cost=8.0, role="ranged", rank=4),
         Foe(kind="monster_tank", source="q2", health=750, cost=14.0, role="ranged", rank=5),
         Foe(kind="monster_tank_commander", source="q2", health=1000, cost=18.0, role="ranged", rank=6),
         Foe(kind="info_player_deathmatch", source="q3", health=60, cost=2.2, role="ranged", rank=2)
     ];

glob CAST_GUARDIANS: list[str] = [
         "monster_shambler",
         "monster_shalrath",
         "monster_tank",
         "monster_tank_commander",
         "monster_gladiator"
     ];

glob TELEPORT_MATERIAL: str = "q1:e1m1/*teleport",
     BUTTON_MATERIAL: str = "q1:e1m1/+0basebtn";

"""What was cast: the entities (brush entities with their brushes), the
exit's box, where the start is, and the tallies the director kept."""
obj Casting {
    has items: list[MapItem] = [],
        exit_low: list[float] = [],
        exit_high: list[float] = [],
        start: list[float] = [],
        monsters: int = 0,
        threat: float = 0.0,
        health: float = 100.0,
        low: float = 100.0,
        placed_health: int = 0,
        placed_armor: int = 0,
        placed_shells: int = 0,
        doors: int = 0;
}

"""A point as a map's origin field."""
def origin_text(x: float, y: float, z: float) -> str {
    return str(int(round(x))) + " " + str(int(round(y))) + " " + str(int(round(z)));
}

"""A name from a token, fit for a targetname."""
def token_name(token: str) -> str {
    return "t_" + token.replace(":", "_");
}

"""The entity class (and the game it is from) of a key token."""
def key_entity(token: str) -> list[str] {
    if token == "key_silver" {
        return ["item_key1", "q1"];
    }
    if token == "key_gold" {
        return ["item_key2", "q1"];
    }
    return [token, "q2"];
}

"""Health, armour and shells by game: classname and spawnflags."""
def supply_names(source: str) -> dict[str, list[str]] {
    if source == "q2" {
        return {
            "health": ["item_health_large", "0"],
            "small": ["item_health", "0"],
            "mega": ["item_health_mega", "0"],
            "shells": ["ammo_shells", "0"],
            "armor": ["item_armor_jacket", "0"]
        };
    }
    if source == "q3" {
        return {
            "health": ["item_health", "0"],
            "small": ["item_health_small", "0"],
            "mega": ["item_health_mega", "0"],
            "shells": ["ammo_shells", "0"],
            "armor": ["item_armor_combat", "0"]
        };
    }
    return {
        "health": ["item_health", "0"],
        "small": ["item_health", "1"],
        "mega": ["item_health", "2"],
        "shells": ["item_shells", "0"],
        "armor": ["item_armor1", "0"]
    };
}

"""Where things may stand in a space: its floor cells with headroom for a
body, off stairs and the stage, and not in a doorway's mouth."""
obj Ground3 {
    has spots: list[list[int]] = [],
        perches: list[list[int]] = [],
        taken: list[list[int]] = [];
}

"""The yaw (degrees) from one point toward another."""
def yaw_toward(x: float, y: float, to_x: float, to_y: float) -> int {
    if abs(to_x - x) < 0.01 and abs(to_y - y) < 0.01 {
        return 90;
    }
    return int(round(math.degrees(math.atan2(to_y - y, to_x - x)))) % 360;
}

"""Casts an expedition."""
obj Director3 {
    has estate: Estate,
        mass: Massing,
        plan: Expedition,
        dice: Stream,
        density: float = 0.5,
        spaces: dict[int, Space] = {},
        by_beat: dict[int, Space] = {},
        grounds: dict[int, Ground3] = {},
        mouths: dict[int, bool] = {},
        made: Casting = Casting(),
        # Token to the name its trigger fires.
        fires: dict[str, str] = {},
        only: list[str] = [];

    def cell_key(x: int, y: int, z: int) -> int {
        return (z * self.mass.ny + y) * self.mass.nx + x;
    }

    """The mission's beat by its id."""
    def plan_beat(beat_id: int) -> Beat | None {
        for beat in beats_of(self.plan) {
            if beat.id == beat_id {
                return beat;
            }
        }
        return None;
    }

    """Note every corridor's doorways, so nothing stands in a doorway's mouth."""
    def note_mouths {
        for corridor in estate_corridors(self.estate) {
            for (door, owner) in [(corridor.out_door, corridor.tail), (corridor.in_door, corridor.head)] {
                if door is None or owner not in self.spaces {
                    continue;
                }
                space = self.spaces[owner];
                inward = [0, 0];
                if door.side == 0 {
                    inward = [-1, 0];
                } elif door.side == 1 {
                    inward = [1, 0];
                } elif door.side == 2 {
                    inward = [0, -1];
                } else {
                    inward = [0, 1];
                }
                for offset in range(-1, door.span + 1) {
                    for deep in range(0, 3) {
                        if door.side < 2 {
                            cx = (space.x + space.w - 1 if door.side == 0 else space.x) + inward[0] * deep;
                            cy = space.y + door.along + offset;
                        } else {
                            cx = space.x + door.along + offset;
                            cy = (space.y + space.d - 1 if door.side == 2 else space.y) + inward[1] * deep;
                        }
                        for up in range(-1, 2) {
                            self.mouths[self.cell_key(cx, cy, door.level + up)] = True;
                        }
                    }
                }
            }
        }
    }

    """The ground of a space, found once."""
    def ground(space: Space) -> Ground3 {
        if space.id in self.grounds {
            return self.grounds[space.id];
        }
        found = Ground3();
        kept: dict[int, bool] = {};
        for cell in space.kept {
            kept[self.cell_key(cell[0], cell[1], cell[2])] = True;
        }
        if space.stage {
            kept[self.cell_key(space.stage[0], space.stage[1], space.stage[2])] = True;
        }
        owner = space.id + 1;
        for cz in range(space.z, space.z + space.h) {
            for cy in range(space.y, space.y + space.d) {
                for cx in range(space.x, space.x + space.w) {
                    if self.mass.at(cx, cy, cz) != owner or self.mass.air(cx, cy, cz - 1) {
                        continue;
                    }
                    key = self.cell_key(cx, cy, cz);
                    if key in kept or key in self.mouths or self.mass.headroom(cx, cy, cz) < 5 {
                        continue;
                    }
                    if space.flood > 0 and cz < space.z + space.flood {
                        # Nothing is left standing in a pit's liquid.
                        continue;
                    }
                    # Room for a body: floor beside it on at least three sides.
                    near = 0;
                    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                        if self.mass.standing(cx + dx, cy + dy, cz) {
                            near += 1;
                        }
                    }
                    if near < 3 {
                        continue;
                    }
                    found.spots.append([cx, cy, cz]);
                    if cz >= space.z + 5 {
                        found.perches.append([cx, cy, cz]);
                    }
                }
            }
        }
        self.grounds[space.id] = found;
        return found;
    }

    """A free place in a space, spread from what stands there already and
    far from `away` when given; on a perch when asked and one is free."""
    def take(space: Space, perch: bool = False, away: list[float] = []) -> list[float] {
        land = self.ground(space);
        pool = land.perches if perch and land.perches else land.spots;
        best: list[int] = [];
        best_score = -1.0;
        for cell in pool {
            if cell in land.taken {
                continue;
            }
            spread = 512.0;
            for other in land.taken {
                gap = float(abs(other[0] - cell[0]) + abs(other[1] - cell[1])) * CELL + float(abs(other[2] - cell[2])) * LIFT;
                spread = min(spread, gap);
            }
            score = spread + self.dice.unit() * 48.0;
            if away {
                score += 0.3 * (abs((float(cell[0]) + 0.5) * CELL - away[0]) + abs((float(cell[1]) + 0.5) * CELL - away[1]));
            }
            if score > best_score {
                best_score = score;
                best = cell;
            }
        }
        if not best {
            return [];
        }
        land.taken.append(best);
        return [(float(best[0]) + 0.5) * CELL, (float(best[1]) + 0.5) * CELL, float(best[2]) * LIFT + 24.0];
    }

    """A space's stage as a point to stand on."""
    def stage_point(space: Space) -> list[float] {
        return [(float(space.stage[0]) + 0.5) * CELL, (float(space.stage[1]) + 0.5) * CELL, float(space.stage[2]) * LIFT + 24.0];
    }

    def middle(space: Space) -> list[float] {
        return [space.middle_x() * CELL, space.middle_y() * CELL];
    }

    def put(fields: dict[str, str]) {
        self.made.items.append(MapItem(fields=fields));
    }

    def put_brushed(fields: dict[str, str], brushes: list[list[Side]]) {
        item = MapItem(fields=fields);
        item.brushes = brushes;
        self.made.items.append(item);
    }
}

"""The start, the objectives' stages, and the exit."""
def cast_objectives(director: Director3) {
    for space in director.spaces.values() {
        if space.role in ["corridor", "window"] or not space.stage {
            continue;
        }
        point = director.stage_point(space);
        middle = director.middle(space);
        if space.role == "start" {
            director.made.start = point;
            director.put({
                "classname": "info_player_start",
                "origin": origin_text(point[0], point[1], point[2]),
                "angle": str(yaw_toward(point[0], point[1], middle[0], middle[1]))
            });
        }
        if space.role == "goal" {
            # The way out: a gate of light on the stage.
            kit = kit_of(space.district);
            floor = float(space.stage[2]) * LIFT;
            low = Vec3(x=point[0] - 32.0, y=point[1] - 32.0, z=floor);
            high = Vec3(x=point[0] + 32.0, y=point[1] + 32.0, z=floor + 8.0);
            director.put_brushed({"classname": "func_wall", "_passion": "exit"}, [plain_box(low, high, TELEPORT_MATERIAL, 1.0)]);
            director.put({"classname": "light", "origin": origin_text(point[0], point[1], floor + 56.0), "light": "300", "_color": "200 220 255"});
            director.made.exit_low = [point[0] - 32.0, point[1] - 32.0, floor + 8.0];
            director.made.exit_high = [point[0] + 32.0, point[1] + 32.0, floor + 96.0];
        }
        beat = director.plan_beat(space.beat);
        if beat is None {
            continue;
        }
        for token in beat.grants {
            if token.startswith("key_") {
                found = key_entity(token);
                director.put({"classname": found[0], "origin": origin_text(point[0], point[1], point[2]), "asset_game": found[1]});
            } elif token.startswith("relay:") or token.startswith("switch:") {
                # A plate on the stage, pressed by standing on it.
                name = token_name(token);
                director.fires[token] = name;
                floor = float(space.stage[2]) * LIFT;
                low = Vec3(x=point[0] - 24.0, y=point[1] - 24.0, z=floor);
                high = Vec3(x=point[0] + 24.0, y=point[1] + 24.0, z=floor + 8.0);
                director.put_brushed(
                    {"classname": "func_button", "angle": "-2", "target": name, "wait": "-1", "lip": "4"},
                    [plain_box(low, high, BUTTON_MATERIAL, 1.0)]
                );
            } elif token.startswith("guardian:") {
                name = token_name(token);
                director.fires[token] = name;
                pick = CAST_GUARDIANS[director.dice.below(len(CAST_GUARDIANS))];
                director.put({
                    "classname": pick,
                    "origin": origin_text(point[0], point[1], point[2]),
                    "angle": str(yaw_toward(point[0], point[1], middle[0], middle[1])),
                    "target": name,
                    "asset_game": "q2" if pick.startswith("monster_tank") or pick == "monster_gladiator" else "q1"
                });
                director.made.monsters += 1;
            } elif token.startswith("open:") {
                director.fires[token] = token_name(token);
            }
        }
    }
}

"""The point in the middle of a corridor block, at its floor."""
def block_middle(block: list[int]) -> list[float] {
    return [float(block[0] + 1) * CELL, float(block[1] + 1) * CELL, float(block[2]) * LIFT];
}

"""Doors on a corridor for what its link needs: one door for all its keys
(a `key` field), and one more for each token something else opens (a
switch, a guardian, a trigger beyond a shortcut). Doors stand on flat blocks
counted back from the head; a secret link's door is the wall itself, opened
by a shot."""
def cast_doors(director: Director3, corridor: Corridor) {
    if corridor.teleport or corridor.window or not corridor.blocks {
        return;
    }
    head = director.spaces.get(corridor.head, None);
    if head is None {
        return;
    }
    kit = kit_of(head.district);
    keys = [token for token in corridor.needs if token.startswith("key_")];
    others = [token for token in corridor.needs if not token.startswith("key_")];
    plans: list[dict[str, str]] = [];
    if keys {
        plans.append({"key": " ".join(keys)});
    }
    for token in others {
        plans.append({"targetname": director.fires.get(token, token_name(token))});
    }
    if corridor.mode == "secret" {
        plans.append({"health": "1", "_secret": "1"});
    }
    if len(corridor.blocks) == 1 and corridor.in_door is not None and corridor.out_door is not None and plans {
        # A doorway through two walls: one door in the plane between them,
        # from the lower floor to above the higher (only one fits).
        block = corridor.blocks[0];
        door_plan = plans[0];
        low_level = min(corridor.in_door.level, corridor.out_door.level);
        high_level = max(corridor.in_door.level, corridor.out_door.level);
        floor = float(low_level) * LIFT;
        roof = float(high_level + CORRIDOR_HIGH) * LIFT;
        middle = block_middle(block);
        if corridor.in_door.side < 2 {
            low = Vec3(x=middle[0] - 8.0, y=float(block[1]) * CELL, z=floor);
            high = Vec3(x=middle[0] + 8.0, y=float(block[1] + 2) * CELL, z=roof);
        } else {
            low = Vec3(x=float(block[0]) * CELL, y=middle[1] - 8.0, z=floor);
            high = Vec3(x=float(block[0] + 2) * CELL, y=middle[1] + 8.0, z=roof);
        }
        secret = "_secret" in door_plan;
        door = {"classname": "func_door", "angle": "-1", "speed": "60" if secret else "160", "wait": "-1", "lip": "8"};
        for (key, value) in door_plan.items() {
            door[key] = value;
        }
        director.put_brushed(door, [plain_box(low, high, kit.wall if secret else kit.door, kit.scale)]);
        director.made.doors += 1;
        if "targetname" in door_plan and corridor.mode == "shortcut" {
            spot = director.stage_point(head);
            director.put_brushed(
                {"classname": "trigger_once", "target": door_plan["targetname"]},
                [plain_box(Vec3(x=spot[0] - 48.0, y=spot[1] - 48.0, z=spot[2] - 24.0), Vec3(x=spot[0] + 48.0, y=spot[1] + 48.0, z=spot[2] + 40.0), "trigger", 1.0)]
            );
        }
        return;
    }
    # Flat blocks, from the head back, two apart.
    count = len(corridor.blocks);
    at = count - 1;
    for fields in plans {
        while at > 0 and corridor.blocks[at][2] != corridor.blocks[at - 1][2] {
            at -= 1;
        }
        if at <= 0 {
            break;
        }
        block = corridor.blocks[at];
        before = corridor.blocks[at - 1];
        along_x = block[0] != before[0];
        middle = block_middle(block);
        floor = middle[2];
        if along_x {
            low = Vec3(x=middle[0] - 8.0, y=float(block[1]) * CELL, z=floor);
            high = Vec3(x=middle[0] + 8.0, y=float(block[1] + 2) * CELL, z=floor + float(CORRIDOR_HIGH) * LIFT);
        } else {
            low = Vec3(x=float(block[0]) * CELL, y=middle[1] - 8.0, z=floor);
            high = Vec3(x=float(block[0] + 2) * CELL, y=middle[1] + 8.0, z=floor + float(CORRIDOR_HIGH) * LIFT);
        }
        secret = "_secret" in fields;
        material = kit.wall if secret else kit.door;
        door = {"classname": "func_door", "angle": "-1", "speed": "60" if secret else "160", "wait": "-1", "lip": "8"};
        for (key, value) in fields.items() {
            door[key] = value;
        }
        director.put_brushed(door, [plain_box(low, high, material, kit.scale)]);
        director.made.doors += 1;
        if "targetname" in fields and corridor.mode == "shortcut" {
            # Opened by walking up to it from the far side.
            inside = corridor.blocks[min(count - 1, at + 1)];
            spot = block_middle(inside);
            director.put_brushed(
                {"classname": "trigger_once", "target": fields["targetname"]},
                [plain_box(Vec3(x=spot[0] - 32.0, y=spot[1] - 32.0, z=spot[2]), Vec3(x=spot[0] + 32.0, y=spot[1] + 32.0, z=spot[2] + 64.0), "trigger", 1.0)]
            );
        }
        at -= 2;
    }
}

"""A teleporter pair for a link no corridor could carry: a pad and its
trigger in each space it leads from, a destination in each it leads to
(only the one way for a one-way link)."""
def cast_teleporter(director: Director3, corridor: Corridor) {
    tail = director.spaces.get(corridor.tail, None);
    head = director.spaces.get(corridor.head, None);
    if tail is None or head is None {
        return;
    }
    ways = [(tail, head)] if corridor.mode == "valve" else [(tail, head), (head, tail)];
    for (source, target) in ways {
        here = director.take(source);
        there = director.take(target);
        if not here or not there {
            continue;
        }
        name = "tele_" + str(corridor.link) + "_" + str(target.id);
        floor = here[2] - 24.0;
        director.put_brushed(
            {"classname": "func_wall", "_passion": "teleporter"},
            [plain_box(Vec3(x=here[0] - 32.0, y=here[1] - 32.0, z=floor), Vec3(x=here[0] + 32.0, y=here[1] + 32.0, z=floor + 4.0), TELEPORT_MATERIAL, 1.0)]
        );
        director.put_brushed(
            {"classname": "trigger_teleport", "target": name},
            [plain_box(Vec3(x=here[0] - 24.0, y=here[1] - 24.0, z=floor + 4.0), Vec3(x=here[0] + 24.0, y=here[1] + 24.0, z=floor + 68.0), "trigger", 1.0)]
        );
        middle = director.middle(target);
        director.put({
            "classname": "info_teleport_destination",
            "targetname": name,
            "origin": origin_text(there[0], there[1], there[2]),
            "angle": str(yaw_toward(there[0], there[1], middle[0], middle[1]))
        });
        director.put({"classname": "light", "origin": origin_text(here[0], here[1], floor + 64.0), "light": "180", "_color": "180 200 255"});
    }
}

"""The game a district's foes are mostly drawn from."""
def district_source(space: Space) -> str {
    return kit_of(space.district).game;
}

"""A foe for a space: from its district's game mostly, others now and then,
no costlier than what is left of its budget, of a role its room suits."""
def pick_foe(director: Director3, space: Space, budget: float, rank_cap: int) -> Foe | None {
    home = district_source(space);
    weights: list[float] = [];
    for foe in CAST_ROSTER {
        weight = 0.0;
        if foe.cost <= budget and foe.rank <= rank_cap and (not director.only or foe.kind in director.only) {
            weight = 3.0 if foe.source == home else 0.6;
            if foe.role == "fly" and space.h < 14 {
                weight = 0.0;
            }
            if foe.kind in CAST_GUARDIANS {
                weight *= 0.3;
            }
        }
        weights.append(weight);
    }
    if max(weights) <= 0.0 {
        return None;
    }
    return CAST_ROSTER[director.dice.weighted(weights)];
}

"""Foes in every room by its threat budget (tension, size, the
expedition's density), on perches when they fight from afar; and supplies
by what the fights cost, walking the rooms in the order they are reached."""
def cast_population(director: Director3) {
    rooms = [space for space in director.spaces.values() if space.role not in ["corridor", "window", "start"]];
    order: list[float] = [float(space.order if space.order >= 0 else 999) for space in rooms];
    ranked: list[int] = [];
    for index in range(len(rooms)) {
        at = len(ranked);
        while at > 0 and order[ranked[at - 1]] > order[index] {
            at -= 1;
        }
        ranked.insert(at, index);
    }
    health = 100.0;
    total = max(1, len(rooms));
    for (step, index) in enumerate(ranked) {
        space = rooms[index];
        area = float(len(director.ground(space).spots));
        progress = float(step) / float(total);
        budget = 0.5 * director.density * (0.6 + space.tension) * (2.0 + area / 22.0) * (0.7 + 0.8 * progress);
        if space.role in ["cache"] {
            budget *= 0.3;
        }
        rank_cap = 2 + int(progress * 4.0);
        spent = 0.0;
        focus = director.middle(space);
        guard = 0;
        while spent < budget and guard < 24 {
            guard += 1;
            foe = pick_foe(director, space, budget - spent + 0.6, rank_cap);
            if foe is None {
                break;
            }
            point = director.take(space, foe.role == "ranged" and director.dice.chance(0.6));
            if not point {
                break;
            }
            director.put({
                "classname": foe.kind,
                "origin": origin_text(point[0], point[1], point[2]),
                "angle": str(yaw_toward(point[0], point[1], focus[0], focus[1])),
                "asset_game": foe.source
            });
            spent += foe.cost;
            director.made.monsters += 1;
            director.made.threat += foe.cost;
            health -= foe.cost * 4.5;
        }
        # Supplies: keep the expected health above a floor, shells for the
        # fights, armour now and then.
        names = supply_names(district_source(space));
        while health < 70.0 {
            point = director.take(space);
            if not point {
                break;
            }
            big = health < 40.0;
            pick = names["health"] if big else names["small"];
            fields = {"classname": pick[0], "origin": origin_text(point[0], point[1], point[2]), "asset_game": district_source(space)};
            if pick[1] != "0" {
                fields["spawnflags"] = pick[1];
            }
            director.put(fields);
            health += 25.0 if big else 15.0;
            director.made.placed_health += 1;
        }
        director.made.low = min(director.made.low, health);
        if spent > 0.0 {
            point = director.take(space);
            if point {
                pick = names["shells"];
                director.put({"classname": pick[0], "origin": origin_text(point[0], point[1], point[2]), "asset_game": district_source(space)});
                director.made.placed_shells += 1;
            }
        }
        if director.dice.chance(0.18) {
            point = director.take(space, True);
            if point {
                pick = names["armor"];
                director.put({"classname": pick[0], "origin": origin_text(point[0], point[1], point[2]), "asset_game": district_source(space)});
                director.made.placed_armor += 1;
            }
        }
    }
    director.made.health = health;
}

"""Cast an expedition."""
def cast(estate: Estate, mass: Massing, plan: Expedition, dice: Stream, density: float, only: list[str] = []) -> Casting {
    director = Director3(estate=estate, mass=mass, plan=plan, dice=dice, density=density, only=only);
    for space in estate_spaces(estate) {
        director.spaces[space.id] = space;
        if space.role not in ["corridor", "window"] {
            director.by_beat[space.beat] = space;
        }
    }
    director.note_mouths();
    cast_objectives(director);
    for corridor in estate_corridors(estate) {
        if corridor.teleport {
            cast_teleporter(director, corridor);
        } else {
            cast_doors(director, corridor);
        }
    }
    cast_population(director);
    return director.made;
}
