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
import from .themes { theme_named }
import from .dress { Dressing, box_brush, plain_box }
import from .experience { Experience, Encounter, CombatPosition, Reward, ComposeEncounters, HoldsPosition, Supplies, encounters, clear_sight, cover_at, link_crossfire, detail_boxes, body_clear }
import from .supplies { progression_weapon, ammo_class, supply_rule, health_after, fight_rounds }
import from .wayfinding { Wayfinding }
import from games.weapons { passion_start, PASSION_AMMO_CAPS }

obj Foe {
    has kind: str,
        source: str,
        health: int,
        cost: float,
        role: str = "melee",
        rank: int = 1,
        # What kind of foe it is, for a theme to lean toward: soldier,
        # beast, undead, arcane, strogg, q3.
        tags: list[str] = [];
}

glob CAST_ROSTER: list[Foe] = [
         Foe(kind="monster_army", source="q1", health=30, cost=1.0, role="ranged", tags=["soldier"]),
         Foe(kind="monster_dog", source="q1", health=25, cost=0.8, role="melee", tags=["beast"]),
         Foe(kind="monster_knight", source="q1", health=75, cost=1.8, role="melee", tags=["undead"]),
         Foe(kind="monster_enforcer", source="q1", health=80, cost=2.6, role="ranged", rank=2, tags=["soldier"]),
         Foe(kind="monster_wizard", source="q1", health=80, cost=2.6, role="fly", rank=2, tags=["arcane", "undead"]),
         Foe(kind="monster_ogre", source="q1", health=200, cost=5.0, role="ranged", rank=3, tags=["beast"]),
         Foe(kind="monster_demon1", source="q1", health=300, cost=6.0, role="melee", rank=3, tags=["beast"]),
         Foe(kind="monster_hell_knight", source="q1", health=250, cost=6.0, role="ranged", rank=3, tags=["undead", "arcane"]),
         Foe(kind="monster_shalrath", source="q1", health=400, cost=8.0, role="ranged", rank=4, tags=["arcane"]),
         Foe(kind="monster_shambler", source="q1", health=600, cost=12.0, role="ranged", rank=5, tags=["beast"]),
         Foe(kind="monster_soldier_light", source="q2", health=20, cost=0.8, role="ranged", tags=["strogg", "soldier"]),
         Foe(kind="monster_soldier", source="q2", health=30, cost=1.0, role="ranged", tags=["strogg", "soldier"]),
         Foe(kind="monster_soldier_ss", source="q2", health=40, cost=1.4, role="ranged", tags=["strogg", "soldier"]),
         Foe(kind="monster_infantry", source="q2", health=100, cost=2.8, role="ranged", rank=2, tags=["strogg", "soldier"]),
         Foe(kind="monster_flyer", source="q2", health=50, cost=1.6, role="fly", rank=2, tags=["strogg"]),
         Foe(kind="monster_parasite", source="q2", health=175, cost=4.0, role="melee", rank=3, tags=["strogg"]),
         Foe(kind="monster_gunner", source="q2", health=175, cost=4.5, role="ranged", rank=3, tags=["strogg"]),
         Foe(kind="monster_chick", source="q2", health=175, cost=4.5, role="ranged", rank=3, tags=["strogg"]),
         Foe(kind="monster_berserk", source="q2", health=240, cost=4.8, role="melee", rank=3, tags=["strogg"]),
         Foe(kind="monster_floater", source="q2", health=200, cost=5.0, role="fly", rank=3, tags=["strogg"]),
         Foe(kind="monster_mutant", source="q2", health=300, cost=6.0, role="melee", rank=4, tags=["strogg"]),
         Foe(kind="monster_brain", source="q2", health=300, cost=6.0, role="melee", rank=4, tags=["strogg"]),
         Foe(kind="monster_hover", source="q2", health=240, cost=6.0, role="fly", rank=4, tags=["strogg"]),
         Foe(kind="monster_gladiator", source="q2", health=400, cost=8.0, role="ranged", rank=4, tags=["strogg"]),
         Foe(kind="monster_tank", source="q2", health=750, cost=14.0, role="ranged", rank=5, tags=["strogg"]),
         Foe(kind="monster_tank_commander", source="q2", health=1000, cost=18.0, role="ranged", rank=6, tags=["strogg"]),
         Foe(kind="info_player_deathmatch", source="q3", health=60, cost=2.2, role="ranged", rank=2, tags=["q3"])
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
        placed_ammo: int = 0,
        placed_weapons: int = 0,
        lead: str = "q1",
        experience: Experience = Experience(),
        navigation: Wayfinding = Wayfinding(),
        issues: list[str] = [],
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
        supply_spots: list[list[int]] = [],
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
        encounters: dict[int, Encounter] = {},
        details: list[list[float]] = [],
        sights: dict[str, bool] = {},
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
                    if self.mass.headroom(cx, cy, cz) < 5 {
                        continue;
                    }
                    if space.flood > 0 and cz < space.z + space.flood {
                        # Nothing is left standing in a pit's liquid.
                        continue;
                    }
                    point = [(float(cx) + 0.5) * CELL, (float(cy) + 0.5) * CELL, float(cz) * LIFT + 24.0];
                    if not body_clear(point, self.details) { continue; }
                    if [cx, cy, cz] != space.stage {
                        # Pickups are triggers, so the walk kept clear of
                        # blocking actors is a good place to find supplies.
                        found.supply_spots.append([cx, cy, cz]);
                    }
                    if key in kept or key in self.mouths { continue; }
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
    def take(space: Space, perch: bool = False, away: list[float] = [], roomy: bool = False, near: list[float] = [], supply: bool = False) -> list[float] {
        land = self.ground(space);
        pool = land.supply_spots if supply else (land.perches if perch and land.perches else land.spots);
        best: list[int] = [];
        best_score = -1000000.0;
        for cell in pool {
            if cell in land.taken {
                continue;
            }
            point = [(float(cell[0]) + 0.5) * CELL, (float(cell[1]) + 0.5) * CELL, float(cell[2]) * LIFT + 24.0];
            if near and (abs(point[2] - near[2]) > 32.0 or not self.sight(near, point)) {
                continue;
            }
            spread = 512.0;
            for other in land.taken {
                gap = float(abs(other[0] - cell[0]) + abs(other[1] - cell[1])) * CELL + float(abs(other[2] - cell[2])) * LIFT;
                spread = min(spread, gap);
            }
            score = spread + self.dice.unit() * 48.0;
            if near {
                score = spread * 0.1 - abs(point[0] - near[0]) - abs(point[1] - near[1]) + self.dice.unit() * 12.0;
            }
            if away {
                score += 0.3 * (abs((float(cell[0]) + 0.5) * CELL - away[0]) + abs((float(cell[1]) + 0.5) * CELL - away[1]));
            }
            # Roomy: floor all round, so a body (or a pad a cell either side)
            # set down there touches no wall nor what dresses one. Asked after
            # the dice, so the dice fall the same whatever is asked.
            if roomy and not self.open_round(cell) {
                continue;
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

    """A real pickup on the approach floor, visible before the encounter.
    Reserve it in the same placement set as foes and objectives."""
    def pack(space: Space, encounter: Encounter, source: str, classname: str, flags: str = "0", essential: bool = True) -> Reward | None {
        point = self.take(space, near=encounter.approach, supply=True);
        if not point {
            if essential { encounter.issues.append("no approach space for " + classname); }
            return None;
        }
        rule = supply_rule(source, classname, flags);
        self.put({"classname": classname, "origin": origin_text(point[0], point[1], point[2]), "asset_game": source, "spawnflags": flags, "_room": str(space.id)});
        reward = Reward(point=point, kind=rule.kind, source=source, amount=rule.amount);
        encounter +>:Supplies:+> reward;
        return reward;
    }

    def sight(a: list[float], b: list[float]) -> bool {
        key = origin_text(a[0], a[1], a[2]) + ">" + origin_text(b[0], b[1], b[2]);
        if key not in self.sights { self.sights[key] = clear_sight(self.mass, a, b, self.details); }
        return self.sights[key];
    }

    """Choose a portal and its nearby arrival together. The arrival has a
    clear, level walk back to the pad, outside its trigger, and both are
    reserved before supplies or enemies can occupy them."""
    def portal_site(space: Space) -> list[list[float]] {
        land = self.ground(space);
        candidates = sorted(land.supply_spots, key=lambda (cell: list[int]) {
            (cell not in land.spots, min(cell[0] - space.x, space.x + space.w - cell[0] - 1,
                cell[1] - space.y, space.y + space.d - cell[1] - 1), cell[2], cell[1], cell[0]);
        });
        for cell in candidates {
            if cell in land.taken or self.cell_key(cell[0], cell[1], cell[2]) in self.mouths or not self.open_round(cell) { continue; }
            pad = [(float(cell[0]) + 0.5) * CELL, (float(cell[1]) + 0.5) * CELL, float(cell[2]) * LIFT + 24.0];
            if abs(pad[0] - self.stage_point(space)[0]) + abs(pad[1] - self.stage_point(space)[1]) < 96.0 { continue; }
            reserved = False;
            for other in land.taken {
                if abs(other[0] - cell[0]) <= 2 and abs(other[1] - cell[1]) <= 2 and abs(other[2] - cell[2]) <= 1 { reserved = True; }
            }
            if reserved { continue; }
            for distance in [3, 2] {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    arrival_cell = [cell[0] + dx * distance, cell[1] + dy * distance, cell[2]];
                    if arrival_cell not in land.supply_spots or arrival_cell in land.taken { continue; }
                    clear = True;
                    for step in range(distance + 1) {
                        x = cell[0] + dx * step;
                        y = cell[1] + dy * step;
                        point = [(float(x) + 0.5) * CELL, (float(y) + 0.5) * CELL, pad[2]];
                        if self.mass.at(x, y, cell[2]) != space.id + 1 or not self.mass.standing(x, y, cell[2])
                            or self.mass.headroom(x, y, cell[2]) < 5 or not body_clear(point, self.details)
                            or [x, y, cell[2]] in land.taken { clear = False; }
                    }
                    if not clear { continue; }
                    arrival = [(float(arrival_cell[0]) + 0.5) * CELL, (float(arrival_cell[1]) + 0.5) * CELL, pad[2]];
                    if not self.sight(pad, arrival) { continue; }
                    # Keep the whole pad clear. The arrival needs one body
                    # cell; neighbouring pickup triggers do not obstruct it.
                    for oy in [-1, 0, 1] {
                        for ox in [-1, 0, 1] { land.taken.append([cell[0] + ox, cell[1] + oy, cell[2]]); }
                    }
                    land.taken.append(arrival_cell);
                    return [pad, arrival];
                }
            }
        }
        return [];
    }

    """Choose an enemy position for its job. Ranged positions need a real
    lane to the approach; pressure approaches on the floor; ambushes use
    occlusion. Keep the quiet rooms' stages out of nearby firing lanes."""
    def take_enemy(space: Space, encounter: Encounter, role: str) -> list[float] {
        ground = self.ground(space);
        best: list[int] = [];
        best_score = -1000000.0;
        stride = max(1, len(ground.spots) // 100);
        for cell in ground.spots[::stride] {
            if cell in ground.taken { continue; }
            point = [(float(cell[0]) + 0.5) * CELL, (float(cell[1]) + 0.5) * CELL, float(cell[2]) * LIFT + 24.0];
            dx = point[0] - encounter.approach[0];
            dy = point[1] - encounter.approach[1];
            distance = math.sqrt(dx * dx + dy * dy);
            if distance < 160.0 { continue; }
            if role == "melee" and abs(point[2] - encounter.approach[2]) > 32.0 { continue; }
            seen = self.sight(point, encounter.approach);
            if role == "ranged" and encounter.pattern != "ambush" and not seen { continue; }
            leaks = False;
            for quiet in self.encounters.values() {
                if quiet.quiet and quiet.room != space.id {
                    qspace = self.spaces[quiet.room];
                    qpoint = self.stage_point(qspace);
                    gap = abs(point[0] - qpoint[0]) + abs(point[1] - qpoint[1]) + abs(point[2] - qpoint[2]);
                    if gap < 768.0 and self.sight(point, qpoint) { leaks = True; }
                }
            }
            if leaks { continue; }
            spread = 320.0;
            for other in ground.taken {
                spread = min(spread, float(abs(other[0] - cell[0]) + abs(other[1] - cell[1])) * CELL);
            }
            if spread < 56.0 { continue; }
            cover = cover_at(self.mass, point);
            score = min(640.0, distance) * 0.2 + spread + self.dice.unit() * 24.0;
            if role == "ranged" { score += float(cover) * 48.0; }
            if encounter.pattern == "overwatch" { score += max(0.0, point[2] - encounter.approach[2]) * 0.5; }
            if encounter.pattern == "ambush" and not seen { score += 180.0; }
            if encounter.pattern == "pressure" and role == "melee" { score -= distance * 0.4; }
            if encounter.pattern == "crossfire" {
                for other in [encounter->:HoldsPosition:->][?:CombatPosition] {
                    ax = other.point[0] - encounter.approach[0];
                    ay = other.point[1] - encounter.approach[1];
                    if dx * ax + dy * ay < 0.0 { score += 180.0; }
                }
            }
            if score > best_score { best_score = score; best = cell; }
        }
        if not best { return []; }
        ground.taken.append(best);
        return [(float(best[0]) + 0.5) * CELL, (float(best[1]) + 0.5) * CELL, float(best[2]) * LIFT + 24.0];
    }

    def note_foe(encounter: Encounter, foe: Foe, point: list[float]) {
        encounter.foes += 1;
        encounter.enemy_health += foe.health;
        encounter.threat += foe.cost;
        position = CombatPosition(point=point, role=foe.role, foe=foe.kind, sees_entry=self.sight(point, encounter.approach), cover=cover_at(self.mass, point));
        encounter +>:HoldsPosition:+> position;
        link_crossfire(encounter, position);
        self.made.monsters += 1;
        self.made.threat += foe.cost;
    }

    """Whether the eight cells round `cell` are floor with air above, as
    `cell` is."""
    def open_round(cell: list[int]) -> bool {
        for dy in [-1, 0, 1] {
            for dx in [-1, 0, 1] {
                x = cell[0] + dx;
                y = cell[1] + dy;
                if not self.mass.air(x, y, cell[2]) or not self.mass.air(x, y, cell[2] + 3) or self.mass.air(x, y, cell[2] - 1) {
                    return False;
                }
            }
        }
        return True;
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
            director.made.lead = district_source(space);
            director.made.start = point;
            director.put({
                "classname": "info_player_start",
                "origin": origin_text(point[0], point[1], point[2]),
                "angle": str(yaw_toward(point[0], point[1], middle[0], middle[1])),
                "_room": str(space.id),
                "_passion_kit": director.made.lead
            });
        }
        if space.role == "goal" {
            # The way out: a gate of light on the stage.
            kit = kit_of(space.district);
            floor = float(space.stage[2]) * LIFT;
            low = Vec3(x=point[0] - 32.0, y=point[1] - 32.0, z=floor);
            high = Vec3(x=point[0] + 32.0, y=point[1] + 32.0, z=floor + 8.0);
            director.put_brushed({"classname": "func_wall", "_passion": "exit"}, [plain_box(low, high, kit.trim, kit.scale)] + device_marks(point[0], point[1], floor + 8.0, kit.light, kit.scale, "exit"));
            director.put({"classname": "light", "origin": origin_text(point[0], point[1], floor + 56.0), "light": "300", "_color": "160 255 190"});
            # The way out is touched by a body's feet: from just over the
            # floor, so feet on the gate (its top at floor + 8) are inside it.
            director.made.exit_low = [point[0] - 32.0, point[1] - 32.0, floor + 2.0];
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
                director.put({"classname": "light", "origin": origin_text(point[0], point[1], point[2] + 40.0),
                    "light": "200", "_color": "255 210 80" if token == "key_gold" else "210 230 255"});
            } elif token.startswith("relay:") or token.startswith("switch:") {
                # A plate on the stage, thrown by stepping onto it: the plate
                # itself is set in the floor, the stepping is a trigger over it.
                name = token_name(token);
                director.fires[token] = name;
                floor = float(space.stage[2]) * LIFT;
                low = Vec3(x=point[0] - 24.0, y=point[1] - 24.0, z=floor);
                high = Vec3(x=point[0] + 24.0, y=point[1] + 24.0, z=floor + 4.0);
                director.put_brushed({"classname": "func_wall", "_passion": "plate"}, [plain_box(low, high, BUTTON_MATERIAL, 1.0)]);
                director.put_brushed(
                    {"classname": "trigger_once", "target": name, "message": "A relay is thrown"},
                    [plain_box(Vec3(x=low.x, y=low.y, z=floor + 4.0), Vec3(x=high.x, y=high.y, z=floor + 64.0), "trigger", 1.0)]
                );
            } elif token.startswith("guardian:") {
                name = token_name(token);
                director.fires[token] = name;
                choices = [foe for foe in CAST_ROSTER if foe.kind in CAST_GUARDIANS and foe.cost <= 12.0];
                foe = choices[director.dice.below(len(choices))];
                pick = foe.kind;
                director.put({
                    "classname": pick,
                    "origin": origin_text(point[0], point[1], point[2]),
                    "angle": str(yaw_toward(point[0], point[1], middle[0], middle[1])),
                    "target": name,
                    "spawnflags": "1",
                    "asset_game": "q2" if pick.startswith("monster_tank") or pick == "monster_gladiator" else "q1"
                });
                director.note_foe(director.encounters[space.id], foe, point);
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
        door = {"classname": "func_door", "angle": "-1", "speed": "60" if secret else "160", "wait": "-1", "lip": "8", "_mission_link": str(corridor.link)};
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
        door = {"classname": "func_door", "angle": "-1", "speed": "60" if secret else "160", "wait": "-1", "lip": "8", "_mission_link": str(corridor.link)};
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
    if corridor.needs {
        director.made.issues.append("link " + str(corridor.link) + ": a locked passage needs a physical gate");
        return;
    }
    tail = director.spaces.get(corridor.tail, None);
    head = director.spaces.get(corridor.head, None);
    if tail is None or head is None {
        return;
    }
    sites = {tail.id: director.portal_site(tail), head.id: director.portal_site(head)};
    if not sites[tail.id] or not sites[head.id] {
        director.made.issues.append("link " + str(corridor.link) + ": no clear paired portal landing");
        return;
    }
    ways = [(tail, head)] if corridor.mode == "valve" else [(tail, head), (head, tail)];
    for (source, target) in ways {
        here = sites[source.id][0];
        there = sites[target.id][1];
        name = "tele_" + str(corridor.link) + "_" + str(target.id);
        floor = here[2] - 24.0;
        director.put_brushed(
            {"classname": "func_wall", "_passion": "teleporter", "_mission_link": str(corridor.link)},
            [plain_box(Vec3(x=here[0] - 32.0, y=here[1] - 32.0, z=floor), Vec3(x=here[0] + 32.0, y=here[1] + 32.0, z=floor + 4.0), TELEPORT_MATERIAL, 1.0)]
        );
        director.put_brushed(
            {"classname": "trigger_teleport", "target": name, "_mission_link": str(corridor.link), "_room": str(source.id), "_portal_point": origin_text(here[0], here[1], here[2])},
            [plain_box(Vec3(x=here[0] - 24.0, y=here[1] - 24.0, z=floor + 4.0), Vec3(x=here[0] + 24.0, y=here[1] + 24.0, z=floor + 68.0), "trigger", 1.0)]
        );
        middle = director.middle(target);
        # A little over the floor: the arrival is clear of a pad beside it,
        # and the body drops the last few units.
        director.put({
            "classname": "info_teleport_destination",
            "targetname": name,
            "_mission_link": str(corridor.link),
            "_room": str(target.id),
            "_portal_point": origin_text(there[0], there[1], there[2]),
            "origin": origin_text(there[0], there[1], there[2] + 8.0),
            "angle": str(yaw_toward(there[0], there[1], middle[0], middle[1]))
        });
        director.put({"classname": "light", "origin": origin_text(here[0], here[1], floor + 64.0), "light": "220", "_color": "205 160 255"});
    }
}

"""Shapes as well as colour identify devices. All markings are one unit
high and, on a lift, belong to the moving model itself."""
def device_marks(x: float, y: float, z: float, material: str, scale: float, kind: str) -> list[list[Side]] {
    rectangles: list[list[float]] = [];
    if kind == "lift" {
        rectangles = [[-24.0, -24.0, -18.0, 24.0], [18.0, -24.0, 24.0, 24.0]];
    } elif kind == "jump" {
        # Three expanding bars read as a launch fan.
        rectangles = [[-7.0, -16.0, 7.0, -10.0], [-13.0, -3.0, 13.0, 3.0], [-19.0, 10.0, 19.0, 16.0]];
    } else {
        # The exit is a complete bright square frame.
        rectangles = [[-28.0, -28.0, 28.0, -22.0], [-28.0, 22.0, 28.0, 28.0],
            [-28.0, -22.0, -22.0, 22.0], [22.0, -22.0, 28.0, 22.0]];
    }
    return [box_brush(Vec3(x=x + r[0], y=y + r[1], z=z), Vec3(x=x + r[2], y=y + r[3], z=z + 1.0),
        [material for _ in range(6)], scale, [4]) for r in rectangles];
}

"""What joins two rooms one over the other: a lift's platform, risen to
the upper floor and lowered to the lower when the level begins (Quake's
func_plat); a jump pad's push up the column and onto the landing beside
the hole; a lamp in each."""
def cast_connector(director: Director3, corridor: Corridor) {
    if len(corridor.column) != 2 {
        return;
    }
    upper_id = corridor.head if corridor.lower == corridor.tail else corridor.tail;
    upper = director.spaces.get(upper_id, None);
    if upper is None {
        return;
    }
    kit = kit_of(upper.district);
    x0 = float(corridor.column[0]) * CELL;
    y0 = float(corridor.column[1]) * CELL;
    low = float(corridor.low) * LIFT;
    high = float(corridor.high) * LIFT;
    middle_x = x0 + CELL;
    middle_y = y0 + CELL;
    if corridor.connector == "lift" {
        director.put_brushed(
            {"classname": "func_plat", "height": str(int(high - low)), "speed": "200"},
            [plain_box(Vec3(x=x0 + 2.0, y=y0 + 2.0, z=high - 8.0), Vec3(x=x0 + 2.0 * CELL - 2.0, y=y0 + 2.0 * CELL - 2.0, z=high), kit.step, kit.scale)]
                + device_marks(middle_x, middle_y, high, kit.light, kit.scale, "lift")
        );
        director.put({"classname": "light", "origin": origin_text(middle_x, middle_y, low + 72.0), "light": "160"});
    } elif corridor.connector == "jumppad" and len(corridor.landing) == 2 {
        land_x = (float(corridor.landing[0]) + 1.0) * CELL;
        land_y = (float(corridor.landing[1]) + 1.0) * CELL;
        across = math.sqrt((land_x - middle_x) * (land_x - middle_x) + (land_y - middle_y) * (land_y - middle_y));
        # Pushed up the column at a steady rise; out of its top the body
        # flies on over the floor, falling, onto the landing.
        rise = 320.0;
        flight = (rise + math.sqrt(rise * rise + 2.0 * 800.0 * 24.0)) / 800.0;
        drive = max(60.0, (across - 24.0) / flight);
        speed = math.sqrt(rise * rise + drive * drive) / 10.0;
        pitch = -math.degrees(math.atan2(rise, drive));
        yaw = math.degrees(math.atan2(land_y - middle_y, land_x - middle_x));
        director.put_brushed(
            {"classname": "func_wall", "_passion": "jumppad"},
            [plain_box(Vec3(x=x0 + 8.0, y=y0 + 8.0, z=low), Vec3(x=x0 + 2.0 * CELL - 8.0, y=y0 + 2.0 * CELL - 8.0, z=low + 4.0), kit.step, kit.scale)]
                + device_marks(middle_x, middle_y, low + 4.0, kit.light, kit.scale, "jump")
        );
        # Straight up the column first (in the lower room it stands in the
        # open, so a slant there would carry the body out of the push), then,
        # in the slab where the shaft has walls, on the slant over the floor.
        director.put_brushed(
            {
                "classname": "trigger_push",
                "angles": "-90 0 0",
                "speed": str(int(rise / 10.0)),
                "_land": origin_text(land_x, land_y, high + 24.0)
            },
            [plain_box(Vec3(x=x0 + 6.0, y=y0 + 6.0, z=low + 4.0), Vec3(x=x0 + 2.0 * CELL - 6.0, y=y0 + 2.0 * CELL - 6.0, z=high - 24.0), "trigger", 1.0)]
        );
        director.put_brushed(
            {"classname": "trigger_push", "angles": str(int(pitch)) + " " + str(int(yaw)) + " 0", "speed": str(int(speed))},
            [plain_box(Vec3(x=x0 + 6.0, y=y0 + 6.0, z=high - 24.0), Vec3(x=x0 + 2.0 * CELL - 6.0, y=y0 + 2.0 * CELL - 6.0, z=high + 24.0), "trigger", 1.0)]
        );
        director.put({"classname": "light", "origin": origin_text(middle_x, middle_y, low + 64.0), "light": "220", "_color": "180 220 255"});
    } else {
        director.put({"classname": "light", "origin": origin_text(middle_x, middle_y, low + 72.0), "light": "120"});
    }
}

"""The game a district's foes are mostly drawn from."""
def district_source(space: Space) -> str {
    return kit_of(space.district).game;
}

"""A foe for a space: from its district's game mostly, others now and then,
no costlier than what is left of its budget, of a role its room suits."""
def pick_foe(director: Director3, space: Space, budget: float, rank_cap: int, wanted: str = "") -> Foe | None {
    home = district_source(space);
    theme = theme_named(director.plan.theme);
    leaning: list[str] = theme.foes if theme is not None else [];
    weights: list[float] = [];
    for foe in CAST_ROSTER {
        weight = 0.0;
        if foe.cost <= budget and foe.rank <= rank_cap and (not director.only or foe.kind in director.only) {
            weight = 3.0 if foe.source == home else 0.6;
            # The theme's foes hold the level more than others.
            if leaning {
                weight *= 3.0 if any([tag in leaning for tag in foe.tags]) else 0.4;
            }
            if foe.role == "fly" and space.h < 14 {
                weight = 0.0;
            }
            if foe.kind in CAST_GUARDIANS {
                weight *= 0.3;
            }
            if wanted {
                weight *= 4.0 if foe.role == wanted else 0.15;
            }
        }
        weights.append(weight);
    }
    if max(weights) <= 0.0 {
        return None;
    }
    return CAST_ROSTER[director.dice.weighted(weights)];
}

"""Stage weapon discoveries, distinct fights and quiet beats. Supplies
sit on the approach floor and use play's item amounts; an optional detour
never subsidises the mandatory route's forecast."""
def cast_population(director: Director3) {
    staged = encounters(director.made.experience);
    required = [encounter for encounter in staged if not encounter.optional];
    discoveries: dict[int, int] = {};
    for (tier, at) in enumerate([0, max(1, len(required) // 3), max(2, len(required) * 2 // 3)]) {
        if at < len(required) { discoveries[required[at].room] = tier; }
    }
    lead = director.made.lead;
    weapon = progression_weapon(lead, 0);
    fallback = progression_weapon(lead, 0);
    optional_weapons = [progression_weapon(source, tier) for source in ["q1", "q2", "q3"] if source != lead for tier in range(3)];
    initial = passion_start(lead);
    stock: dict[str, int] = {};
    if initial.ammo { stock[initial.ammo] = initial.rounds; }
    health = 100.0;
    total = max(1, len(staged));
    for (step, encounter) in enumerate(staged) {
        space = director.spaces[encounter.room];
        saved_health = health;
        saved_stock = dict(stock);
        encounter.health_before = health;
        if space.id in discoveries {
            offered = progression_weapon(lead, discoveries[space.id]);
            reward = director.pack(space, encounter, lead, "weapon_" + offered.key);
            if reward is not None {
                weapon = offered;
                director.made.placed_weapons += 1;
                stock[weapon.ammo] = min(PASSION_AMMO_CAPS[weapon.ammo], stock.get(weapon.ammo, 0) + weapon.pickup_ammo);
            }
        } elif encounter.optional and space.role in ["cache", "vista"] and optional_weapons {
            # A detour offers another game's capability, with its own ammo.
            offered = optional_weapons.pop(step % len(optional_weapons));
            source = offered.game;
            reward = director.pack(space, encounter, source, "weapon_" + offered.key, essential=False);
            if reward is not None {
                director.made.placed_weapons += 1;
                ammo = director.pack(space, encounter, source, ammo_class(source, offered.ammo), essential=False);
                if ammo is not None { director.made.placed_ammo += 1; }
            }
        }
        # Later discoveries can lie on a route the player has not taken.
        # The visible gun in the safe start remains viable for every fight.
        encounter.weapon = fallback.game + ":" + fallback.key;
        area = float(len(director.ground(space).spots));
        progress = float(step) / float(total);
        budget = 0.5 * director.density * (0.6 + space.tension) * (2.0 + area / 22.0) * (0.7 + 0.8 * progress);
        budget = min(14.0, budget);
        if encounter.pattern == "teach" { budget = min(3.0, budget); }
        if encounter.quiet { budget = 0.0; }
        rank_cap = 2 + int(progress * 4.0);
        spent = encounter.threat;
        guard = 0;
        while spent < budget and guard < 24 {
            guard += 1;
            wanted = "melee" if encounter.pattern == "pressure" and encounter.foes % 2 == 0 else "ranged";
            foe = pick_foe(director, space, budget - spent, rank_cap, wanted);
            if foe is None { break; }
            point = director.take_enemy(space, encounter, foe.role);
            if not point { continue; }
            director.put({
                "classname": foe.kind,
                "origin": origin_text(point[0], point[1], point[2]),
                "angle": str(yaw_toward(point[0], point[1], encounter.approach[0], encounter.approach[1])),
                "asset_game": foe.source,
                "_room": str(space.id),
                "_encounter": encounter.pattern,
                "spawnflags": "1" if encounter.pattern == "ambush" and foe.source in ["q1", "q2"] else "0"
            });
            spent += foe.cost;
            director.note_foe(encounter, foe, point);
        }
        # Supply the fight before subtracting its cost. Include guardians
        # and record the low point before a later room can replenish it.
        damage = encounter.threat * 4.5;
        if encounter.foes > 0 {
            health = min(health, 35.0);
            encounter.health_before = health;
        }
        wanted_health = 100.0 if encounter.quiet else min(100.0, max(75.0, damage + 35.0));
        names = supply_names(district_source(space));
        while health < wanted_health {
            pick = names["health"] if wanted_health - health >= 10.0 else names["small"];
            reward = director.pack(space, encounter, district_source(space), pick[0], pick[1]);
            if reward is None { break; }
            rule = supply_rule(district_source(space), pick[0], pick[1]);
            replenished = health_after(health, rule);
            encounter.health_added += replenished - health;
            health = replenished;
            director.made.placed_health += 1;
        }
        encounter.health_ready = health;
        health -= damage;
        encounter.health_after = health;
        director.made.low = min(director.made.low, health);
        encounter.ammo_needed = fight_rounds(fallback, encounter.enemy_health);
        if encounter.foes > 0 { stock[fallback.ammo] = 0; }
        wanted_ammo = max(encounter.ammo_needed, fallback.cost * 6 if space.role == "start" else 0);
        while stock.get(fallback.ammo, 0) < wanted_ammo {
            classname = ammo_class(fallback.game, fallback.ammo);
            reward = director.pack(space, encounter, fallback.game, classname);
            if reward is None { break; }
            stock[fallback.ammo] = min(PASSION_AMMO_CAPS[fallback.ammo], stock.get(fallback.ammo, 0) + reward.amount);
            director.made.placed_ammo += 1;
            if fallback.ammo == "shells" { director.made.placed_shells += 1; }
            if stock[fallback.ammo] >= PASSION_AMMO_CAPS[fallback.ammo] { break; }
        }
        encounter.ammo_ready = stock.get(fallback.ammo, 0);
        stock[fallback.ammo] = max(0, encounter.ammo_ready - encounter.ammo_needed);
        if weapon.ammo != fallback.ammo and (encounter.foes > 0 or space.id in discoveries) {
            extra = 0;
            wanted_extra = max(weapon.cost * 6, fight_rounds(weapon, encounter.enemy_health));
            while extra < wanted_extra {
                reward = director.pack(space, encounter, weapon.game, ammo_class(weapon.game, weapon.ammo), essential=False);
                if reward is None { break; }
                extra += reward.amount;
                director.made.placed_ammo += 1;
            }
        }
        if encounter.foes > 0 and (health < 25.0 or encounter.ammo_ready < encounter.ammo_needed) {
            encounter.issues.append("insufficient approach supplies");
        }
        if encounter.optional or space.role in ["cache", "recovery"] or director.dice.chance(0.2) {
            pick = names["armor"];
            if director.pack(space, encounter, district_source(space), pick[0], pick[1], essential=False) is not None {
                director.made.placed_armor += 1;
            }
        }
        if encounter.optional {
            health = saved_health;
            stock = saved_stock;
        }
        for issue in encounter.issues {
            director.made.issues.append("room " + str(space.id) + ": " + issue);
        }
    }
    director.made.health = health;
}

"""Cast an expedition."""
def cast(estate: Estate, mass: Massing, plan: Expedition, dice: Stream, density: float, only: list[str] = [], dressing: Dressing | None = None) -> Casting {
    director = Director3(estate=estate, mass=mass, plan=plan, dice=dice, density=density, only=only);
    if dressing is not None { director.details = detail_boxes(dressing.brushes); }
    for space in estate_spaces(estate) {
        director.spaces[space.id] = space;
        if space.role not in ["corridor", "window"] {
            director.by_beat[space.beat] = space;
        }
    }
    director.note_mouths();
    composition = estate spawn ComposeEncounters(mass=mass, details=director.details);
    director.made.experience = composition.experience;
    director.made.experience.expects_returns = plan.loopiness >= 0.5;
    for encounter in encounters(composition.experience) {
        director.encounters[encounter.room] = encounter;
    }
    cast_objectives(director);
    for corridor in estate_corridors(estate) {
        if corridor.teleport {
            cast_teleporter(director, corridor);
        } elif corridor.connector {
            cast_connector(director, corridor);
        } else {
            cast_doors(director, corridor);
        }
    }
    cast_population(director);
    return director.made;
}
