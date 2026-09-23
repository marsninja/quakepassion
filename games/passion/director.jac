"""Encounter director: objectives, set pieces, pacing and resource economy.

Rooms receive threat budgets from their progression tension (a rising curve
with swells), their size and the expedition's density. Encounter templates
place a room's roster by role: melee on the floor, ranged on perches, fliers
under high ceilings, and trigger-spawned ambushes that answer a key pickup or a
switch. A resource simulation walks the intended route and places health,
armor and shells so expected health stays inside a target band.
"""
import from .random { Stream }
import from .mission { Expedition, Beat, beats_of }
import from .layout { Site, Room, Passage, rooms_of, passages_of, CELL, STEP }
import from .interior { Interior, landing_cells }
import from .blueprint {
    Blueprint,
    Mark,
    Volume,
    Plate,
    LampSpec,
    DoorSpec,
    room_origin,
    world_point,
    boundary_strip
}

obj Foe {
    has kind: str,
        source: str,
        health: int,
        cost: float,
        role: str = "melee",
        rank: int = 1;
}

glob ROSTER: list[Foe] = [
         Foe(kind="monster_army", source="q1", health=30, cost=1.0, role="ranged"),
         Foe(kind="monster_dog", source="q1", health=25, cost=0.8, role="melee"),
         Foe(kind="monster_knight", source="q1", health=75, cost=1.8, role="melee"),
         Foe(
             kind="monster_enforcer",
             source="q1",
             health=80,
             cost=2.6,
             role="ranged",
             rank=2
         ),
         Foe(
             kind="monster_wizard", source="q1", health=80, cost=2.6, role="fly", rank=2
         ),
         Foe(
             kind="monster_ogre",
             source="q1",
             health=200,
             cost=5.0,
             role="ranged",
             rank=3
         ),
         Foe(
             kind="monster_demon1",
             source="q1",
             health=300,
             cost=6.0,
             role="melee",
             rank=3
         ),
         Foe(
             kind="monster_hell_knight",
             source="q1",
             health=250,
             cost=6.0,
             role="ranged",
             rank=3
         ),
         Foe(
             kind="monster_shalrath",
             source="q1",
             health=400,
             cost=8.0,
             role="ranged",
             rank=4
         ),
         Foe(
             kind="monster_shambler",
             source="q1",
             health=600,
             cost=12.0,
             role="ranged",
             rank=5
         ),
         Foe(
             kind="monster_soldier_light",
             source="q2",
             health=20,
             cost=0.8,
             role="ranged"
         ),
         Foe(kind="monster_soldier", source="q2", health=30, cost=1.0, role="ranged"),
         Foe(
             kind="monster_soldier_ss", source="q2", health=40, cost=1.4, role="ranged"
         ),
         Foe(
             kind="monster_infantry",
             source="q2",
             health=100,
             cost=2.8,
             role="ranged",
             rank=2
         ),
         Foe(
             kind="monster_flyer", source="q2", health=50, cost=1.6, role="fly", rank=2
         ),
         Foe(
             kind="monster_parasite",
             source="q2",
             health=175,
             cost=4.0,
             role="melee",
             rank=3
         ),
         Foe(
             kind="monster_gunner",
             source="q2",
             health=175,
             cost=4.5,
             role="ranged",
             rank=3
         ),
         Foe(
             kind="monster_chick",
             source="q2",
             health=175,
             cost=4.5,
             role="ranged",
             rank=3
         ),
         Foe(
             kind="monster_berserk",
             source="q2",
             health=240,
             cost=4.8,
             role="melee",
             rank=3
         ),
         Foe(
             kind="monster_floater",
             source="q2",
             health=200,
             cost=5.0,
             role="fly",
             rank=3
         ),
         Foe(
             kind="monster_mutant",
             source="q2",
             health=300,
             cost=6.0,
             role="melee",
             rank=4
         ),
         Foe(
             kind="monster_brain",
             source="q2",
             health=300,
             cost=6.0,
             role="melee",
             rank=4
         ),
         Foe(
             kind="monster_hover", source="q2", health=240, cost=6.0, role="fly", rank=4
         ),
         Foe(
             kind="monster_gladiator",
             source="q2",
             health=400,
             cost=8.0,
             role="ranged",
             rank=4
         ),
         Foe(
             kind="monster_tank",
             source="q2",
             health=750,
             cost=14.0,
             role="ranged",
             rank=5
         ),
         Foe(
             kind="monster_tank_commander",
             source="q2",
             health=1000,
             cost=18.0,
             role="ranged",
             rank=6
         ),
         Foe(
             kind="info_player_deathmatch",
             source="q3",
             health=60,
             cost=2.2,
             role="ranged",
             rank=2
         )
     ];

glob GUARDIANS: list[str] = [
         "monster_shambler",
         "monster_shalrath",
         "monster_tank",
         "monster_tank_commander",
         "monster_gladiator"
     ];

# District -> preferred roster sources; Passion deliberately mixes games.
glob DISTRICT_SOURCES: list[list[str]] = [
         ["q1", "q1", "q2"],
         ["q1", "q1", "q3"],
         ["q2", "q2", "q1"],
         ["q2", "q2", "q3"],
         ["q3", "q1", "q2"],
         ["q3", "q2", "q1"]
     ];

glob DISTRICT_ITEMS: list[str] = ["q1", "q1", "q2", "q2", "q3", "q3"];

obj Economy {
    has health: float = 100.0,
        armor: float = 0.0,
        shells: float = 0.0,
        low: float = 100.0,
        damage: float = 0.0,
        placed_health: int = 0,
        placed_shells: int = 0,
        placed_armor: int = 0,
        monsters: int = 0,
        threat: float = 0.0;
}

obj Director {
    has plan: Expedition,
        site: Site,
        bp: Blueprint,
        stream: Stream,
        density: float = 0.5,
        economy: Economy = Economy(),
        used: dict[int, list[int]] = {};

    def room_of(beat: int) -> Room {
        return rooms_of(self.site)[beat];
    }

    def take_spot(
        room: Room, prefer_far_from: list[float], perch: bool = False
    ) -> list[float] {
        interior = self.bp.interiors[room.beat];
        taken = self.used.setdefault(room.beat, []);
        pool = interior.perches if perch and interior.perches else interior.spots;
        best = -1;
        best_score = -1.0;
        for cell in pool {
            if cell in taken {
                continue;
            }
            point = world_point(room, cell, interior, 0.0);
            spread = 1000.0;
            for other in taken {
                q = world_point(room, other, interior, 0.0);
                spread = min(spread, abs(q[0] - point[0]) + abs(q[1] - point[1]));
            }
            score = min(spread, 400.0);
            if prefer_far_from {
                score += 0.4
                    * (
                        abs(point[0] - prefer_far_from[0])
                        + abs(point[1] - prefer_far_from[1])
                    );
            }
            score += self.stream.unit() * 40.0;
            if score > best_score {
                best_score = score;
                best = cell;
            }
        }
        if best < 0 {
            return [];
        }
        taken.append(best);
        return world_point(room, best, interior, 24.0);
    }

    def mark(
        kind: str,
        point: list[float],
        source: str,
        beat: int,
        angle: float = 0.0,
        fields: dict[str, str] = {}
    ) {
        self.bp.marks.append(
            Mark(
                kind=kind,
                x=point[0],
                y=point[1],
                z=point[2],
                angle=angle,
                source=source,
                fields=dict(fields),
                beat=beat
            )
        );
    }
}

def entry_point(director: Director, room: Room) -> list[float] {
    interior = director.bp.interiors[room.beat];
    if not interior.landings {
        return [];
    }
    return world_point(room, interior.landings[0], interior, 0.0);
}

def stage_point(director: Director, room: Room, lift: float) -> list[float] {
    interior = director.bp.interiors[room.beat];
    return world_point(room, interior.stage, interior, lift);
}

def facing(from_point: list[float], to_point: list[float]) -> float {
    dx = to_point[0] - from_point[0];
    dy = to_point[1] - from_point[1];
    if abs(dx) >= abs(dy) {
        return 0.0 if dx >= 0.0 else 180.0;
    }
    return 90.0 if dy >= 0.0 else 270.0;
}

# The largest square (half-size) around a point whose footprint is flat floor
# at the given height, so plates never overhang a drop and become ledges.
def flush_half(
    bp: Blueprint, x: float, y: float, base: float, largest: float
) -> float {
    for half in [largest, 48.0, 32.0, 16.0] {
        if half > largest {
            continue;
        }
        x0 = int((x - half) / 32.0);
        x1 = int((x + half - 0.01) / 32.0);
        y0 = int((y - half) / 32.0);
        y1 = int((y + half - 0.01) / 32.0);
        flat = True;
        for cy in range(y0, y1 + 1) {
            for cx in range(x0, x1 + 1) {
                i = bp.index(cx, cy);
                if not bp.open(i) or float(bp.floor[i]) != base {
                    flat = False;
                }
            }
        }
        if flat {
            return half;
        }
    }
    return 0.0;
}

def key_item(token: str) -> list[str] {
    if token == "key_silver" {
        return ["item_key1", "q1"];
    }
    if token == "key_gold" {
        return ["item_key2", "q1"];
    }
    return [token, "q2"];
}

def door_names_for(bp: Blueprint, token: str) -> list[str] {
    return [
        door.name
        for door in bp.doors
        if token in door.keys and door.name
    ];
}

# ---------------------------------------------------------------------------
# Objectives and set pieces
# ---------------------------------------------------------------------------

def stage_objectives(director: Director) {
    bp = director.bp;
    for room in rooms_of(director.site) {
        center = stage_point(director, room, 24.0);
        doorway = entry_point(director, room);
        if room.kind == "start" {
            angle = facing(center, doorway) if doorway else 0.0;
            if doorway {
                # Face away from the wall toward the first exit.
                angle = facing(center, doorway);
            }
            director.mark("info_player_start", center, "q1", room.beat, angle);
        }
        for token in room.grants {
            if token.startswith("key_") {
                item = key_item(token);
                director.mark(
                    item[0],
                    center,
                    item[1],
                    room.beat,
                    0.0,
                    {"target": "ambush_" + str(room.beat)}
                );
                bp.lamps.append(
                    LampSpec(
                        x=center[0],
                        y=center[1],
                        z=center[2] + 72.0,
                        color=10 if token in ["key_gold", "key_red_key"] else 11,
                        strength=1.2,
                        radius=300.0
                    )
                );
            } elif token.startswith("switch:") or token.startswith("relay:") {
                names = door_names_for(bp, token);
                base = stage_point(director, room, 0.0);
                half = flush_half(bp, base[0], base[1], base[2], 32.0);
                if names and half > 0.0 {
                    # Sunk almost flush so it never becomes an unclimbable lip.
                    bp.volumes.append(
                        Volume(
                            low=[base[0] - half, base[1] - half, base[2] - 6.0],
                            high=[base[0] + half, base[1] + half, base[2] + 2.0],
                            kind="button",
                            target=names[0]
                        )
                    );
                    bp.lamps.append(
                        LampSpec(
                            x=base[0],
                            y=base[1],
                            z=base[2] + 96.0,
                            color=12,
                            strength=1.3,
                            radius=320.0
                        )
                    );
                } elif names {
                    # No flat footprint for a plate: a touch trigger still throws it.
                    bp.volumes.append(
                        Volume(
                            low=[base[0] - 32.0, base[1] - 32.0, base[2]],
                            high=[base[0] + 32.0, base[1] + 32.0, base[2] + 72.0],
                            kind="once",
                            target=names[0]
                        )
                    );
                }
            } elif token.startswith("guardian:") {
                names = door_names_for(bp, token);
                boss = GUARDIANS[director.stream.below(len(GUARDIANS))];
                source = "q1"
                    if boss in ["monster_shambler", "monster_shalrath"]
                    else "q2";
                fields: dict[str, str] = {};
                if names {
                    fields["target"] = names[0];
                }
                director.mark(
                    boss,
                    center,
                    source,
                    room.beat,
                    facing(center, doorway) if doorway else 0.0,
                    fields
                );
                director.economy.threat += 15.0;
                director.economy.monsters += 1;
                bp.lamps.append(
                    LampSpec(
                        x=center[0],
                        y=center[1],
                        z=center[2] + 160.0,
                        color=13,
                        strength=1.1,
                        radius=520.0
                    )
                );
            }
        }
        if room.kind == "goal" {
            base = stage_point(director, room, 0.0);
            bp.volumes.append(
                Volume(
                    low=[base[0] - 72.0, base[1] - 72.0, base[2]],
                    high=[base[0] + 72.0, base[1] + 72.0, base[2] + 96.0],
                    kind="exit"
                )
            );
            half = flush_half(bp, base[0], base[1], base[2], 64.0);
            if half > 0.0 {
                bp.plates.append(
                    Plate(
                        low=[base[0] - half, base[1] - half, base[2]],
                        high=[base[0] + half, base[1] + half, base[2] + 2.0],
                        material=-1
                    )
                );
            }
            bp.lamps.append(
                LampSpec(
                    x=base[0],
                    y=base[1],
                    z=base[2] + 120.0,
                    color=14,
                    strength=1.4,
                    radius=420.0
                )
            );
        }
    }
    for passage in passages_of(director.site) {
        if passage.mode == "shortcut" and not passage.teleport {
            shortcut_trigger(director, passage);
        }
        if passage.mode == "secret" and not passage.teleport {
            secret_switch(director, passage);
        }
        if passage.teleport {
            teleporter(director, passage);
        }
    }
}

# Walking up to a shortcut from its far side opens it for good.
def shortcut_trigger(director: Director, passage: Passage) {
    room = director.room_of(passage.head);
    interior = director.bp.interiors[room.beat];
    cells = landing_cells(interior, passage.head_socket);
    bounds = cell_bounds(room, interior, cells);
    director.bp.volumes.append(
        Volume(
            low=[bounds[0], bounds[1], bounds[2]],
            high=[bounds[3], bounds[4], bounds[2] + 96.0],
            kind="once",
            target="short_" + str(passage.link)
        )
    );
}

def cell_bounds(room: Room, interior: Interior, cells: list[int]) -> list[float] {
    origin = room_origin(room);
    low_x = 1000000.0;
    low_y = 1000000.0;
    high_x = -1000000.0;
    high_y = -1000000.0;
    floor = -1000000.0;
    for cell in cells {
        x = float(origin[0] + cell % interior.width) * 32.0;
        y = float(origin[1] + cell // interior.width) * 32.0;
        low_x = min(low_x, x);
        low_y = min(low_y, y);
        high_x = max(high_x, x + 32.0);
        high_y = max(high_y, y + 32.0);
        floor = max(floor, float(room.z + interior.floor[cell]));
    }
    return [low_x, low_y, floor, high_x, high_y];
}

# A shootable panel beside a secret door's mouth, in the tail room.
def secret_switch(director: Director, passage: Passage) {
    room = director.room_of(passage.tail);
    sl = boundary_strip(room, passage.tail_socket);
    first = sl.cells[0];
    last = sl.cells[-1];
    floor = float(room.z + passage.tail_socket.offset);
    z0 = floor + 72.0;
    low: list[float] = [];
    high: list[float] = [];
    side = passage.tail_socket.side;
    if side == 0 {
        wall = float(first[0]) * 32.0;
        y = float(last[1] + 1) * 32.0;
        low = [wall - 6.0, y + 8.0, z0];
        high = [wall + 2.0, y + 24.0, z0 + 16.0];
    } elif side == 1 {
        wall = float(first[0] + 1) * 32.0;
        y = float(last[1] + 1) * 32.0;
        low = [wall - 2.0, y + 8.0, z0];
        high = [wall + 6.0, y + 24.0, z0 + 16.0];
    } elif side == 2 {
        wall = float(first[1]) * 32.0;
        x = float(last[0] + 1) * 32.0;
        low = [x + 8.0, wall - 6.0, z0];
        high = [x + 24.0, wall + 2.0, z0 + 16.0];
    } else {
        wall = float(first[1] + 1) * 32.0;
        x = float(last[0] + 1) * 32.0;
        low = [x + 8.0, wall - 2.0, z0];
        high = [x + 24.0, wall + 6.0, z0 + 16.0];
    }
    director.bp.volumes.append(
        Volume(
            low=low, high=high, kind="shootable", target="secret_" + str(passage.link)
        )
    );
}

def teleporter(director: Director, passage: Passage) {
    tail = director.room_of(passage.tail);
    head = director.room_of(passage.head);
    sources: list[Room] = [tail];
    targets: list[Room] = [head];
    if passage.mode != "valve" {
        sources.append(head);
        targets.append(tail);
    }
    for end in range(len(sources)) {
        source = sources[end];
        target = targets[end];
        pad = director.take_spot(source, []);
        arrive = director.take_spot(target, []);
        if not pad or not arrive {
            continue;
        }
        name = "tele_" + str(passage.link) + "_" + str(end);
        z = pad[2] - 24.0;
        director.bp.volumes.append(
            Volume(
                low=[pad[0] - 32.0, pad[1] - 32.0, z],
                high=[pad[0] + 32.0, pad[1] + 32.0, z + 64.0],
                kind="teleport",
                target=name
            )
        );
        half = flush_half(director.bp, pad[0], pad[1], z, 32.0);
        if half > 0.0 {
            director.bp.plates.append(
                Plate(
                    low=[pad[0] - half, pad[1] - half, z],
                    high=[pad[0] + half, pad[1] + half, z + 2.0],
                    material=-2
                )
            );
        }
        director.mark(
            "info_notnull", arrive, "q1", target.beat, 0.0, {"targetname": name}
        );
        director.bp.lamps.append(
            LampSpec(
                x=pad[0], y=pad[1], z=z + 96.0, color=11, strength=1.0, radius=260.0
            )
        );
    }
}

# ---------------------------------------------------------------------------
# Encounters
# ---------------------------------------------------------------------------

def budget_for(director: Director, room: Room, total_order: int) -> float {
    if room.kind in ["start", "goal", "recovery", "cache", "vista"] {
        return 0.0 if room.kind != "vista" else 1.5 * director.density;
    }
    size_factor = [0.45, 0.8, 1.05, 1.5][min(3, room.size)];
    ramp = 0.7 + 0.6 * float(room.order) / float(max(1, total_order));
    return director.density * (2.0 + 14.0 * room.tension) * size_factor * ramp;
}

def pick_foe(
    director: Director, sources: list[str], remaining: float, role: str, max_rank: int
) -> Foe | None {
    options: list[Foe] = [];
    weights: list[float] = [];
    for foe in ROSTER {
        if foe.cost > remaining or foe.rank > max_rank {
            continue;
        }
        if role and foe.role != role {
            continue;
        }
        weight = 0.0;
        for k in range(len(sources)) {
            if foe.source == sources[k] {
                weight += [1.0, 0.5, 0.25][k];
            }
        }
        if weight <= 0.0 {
            continue;
        }
        options.append(foe);
        weights.append(weight * (0.6 + foe.cost / 6.0));
    }
    if not options {
        return None;
    }
    return options[director.stream.weighted(weights)];
}

def populate(director: Director) {
    rooms = rooms_of(director.site);
    total_order = 0;
    for room in rooms {
        total_order = max(total_order, room.order);
    }
    for room in rooms {
        budget = budget_for(director, room, total_order);
        if budget <= 0.4 {
            continue;
        }
        sources = DISTRICT_SOURCES[room.district % len(DISTRICT_SOURCES)];
        doorway = entry_point(director, room);
        max_rank = 1
            + int(
                room.tension * 4.5
                    + float(room.order) / float(max(1, total_order)) * 1.5
            );
        template = "patrol";
        interior = director.bp.interiors[room.beat];
        roll = director.stream.unit();
        if room.kind in ["arena", "guardian"] and budget > 6.0 {
            template = "arena";
        } elif interior.perches and roll < 0.55 {
            template = "snipers";
        } elif roll < 0.75 and budget > 4.0 {
            template = "horde";
        }
        remaining = budget;
        count = 0;
        limit = 3 + room.size * 2;
        while remaining > 0.7 and count < limit {
            role = "";
            perch = False;
            if template == "snipers" and count < len(interior.perches) {
                role = "ranged";
                perch = True;
            } elif template == "horde" {
                role = "melee" if director.stream.chance(0.6) else "";
                max_rank = min(max_rank, 3);
            }
            if room.ceiling < 224 and role == "" and director.stream.chance(0.5) {
                role = "melee";
            }
            foe = pick_foe(director, sources, remaining, role, max_rank);
            if foe is None {
                foe = pick_foe(director, sources, remaining, "", max_rank);
            }
            if foe is None {
                break;
            }
            if foe.role == "fly" and room.ceiling < 224 {
                remaining -= 0.5;
                continue;
            }
            point = director.take_spot(room, doorway, perch);
            if not point {
                break;
            }
            angle = facing(point, doorway)
                if doorway
                else director.stream.uniform(0.0, 360.0);
            director.mark(foe.kind, point, foe.source, room.beat, angle);
            remaining -= foe.cost;
            count += 1;
            director.economy.threat += foe.cost;
            director.economy.monsters += 1;
            director.economy.damage += float(foe.health)
                * (0.07 if foe.role == "melee" else 0.1);
        }
        # Key and switch rooms answer the objective with a trigger-spawned ambush.
        if room.kind in ["key", "switch"] and room.tension > 0.35 {
            names = ["ambush_" + str(room.beat)];
            if room.kind == "switch" {
                names = [];
                for token in room.grants {
                    names.extend(door_names_for(director.bp, token));
                }
            }
            if names {
                ambush = 1 + int(room.tension * 3.0);
                for k in range(ambush) {
                    foe = pick_foe(director, ["q2"], 5.0, "", 3);
                    point = director.take_spot(room, [], False);
                    if foe is None or not point {
                        break;
                    }
                    director.mark(
                        foe.kind,
                        point,
                        "q2",
                        room.beat,
                        director.stream.uniform(0.0, 360.0),
                        {"spawnflags": "2", "targetname": names[0]}
                    );
                    director.economy.monsters += 1;
                    director.economy.damage += float(foe.health) * 0.08;
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Resource economy along the intended route
# ---------------------------------------------------------------------------

def item_names(source: str) -> dict[str, list[str]] {
    if source == "q2" {
        return {
            "health": ["item_health_large", "0"],
            "small": ["item_health", "0"],
            "mega": ["item_health_mega", "0"],
            "shells": ["ammo_shells", "0"],
            "armor": ["item_armor_jacket", "0"],
            "heavy_armor": ["item_armor_combat", "0"]
        };
    }
    if source == "q3" {
        return {
            "health": ["item_health", "0"],
            "small": ["item_health_small", "0"],
            "mega": ["item_health_mega", "0"],
            "shells": ["ammo_shells", "0"],
            "armor": ["item_armor_combat", "0"],
            "heavy_armor": ["item_armor_body", "0"]
        };
    }
    return {
        "health": ["item_health", "0"],
        "small": ["item_health", "1"],
        "mega": ["item_health", "2"],
        "shells": ["item_shells", "0"],
        "armor": ["item_armor1", "0"],
        "heavy_armor": ["item_armor2", "0"]
    };
}

def drop_item(director: Director, room: Room, what: str) -> bool {
    source = DISTRICT_ITEMS[room.district % len(DISTRICT_ITEMS)];
    names = item_names(source);
    point = director.take_spot(room, []);
    if not point {
        return False;
    }
    fields: dict[str, str] = {};
    if names[what][1] != "0" {
        fields["spawnflags"] = names[what][1];
    }
    director.mark(names[what][0], point, source, room.beat, 0.0, fields);
    return True;
}

def supply(director: Director) {
    rooms = rooms_of(director.site);
    by_beat: dict[int, float] = {};
    for mark in director.bp.marks {
        if mark.kind.startswith("monster_") or mark.kind == "info_player_deathmatch" {
            if mark.fields.get("spawnflags", "0") == "2" {
                by_beat[mark.beat] = by_beat.get(mark.beat, 0.0) + 12.0;
            } else {
                by_beat[mark.beat] = by_beat.get(mark.beat, 0.0) + 1.0;
            }
        }
    }
    economy = director.economy;
    economy.health = 100.0;
    economy.shells = 0.0;
    economy.armor = 0.0;
    route = list(director.plan.route);
    for room in rooms {
        if room.optional and room.beat not in route {
            route.append(room.beat);
        }
    }
    for beat in route {
        room = rooms[beat];
        fights = by_beat.get(beat, 0.0);
        # Expected damage scales with threat already present in the room.
        incoming = 0.0;
        for mark in director.bp.marks {
            if mark.beat != beat {
                continue;
            }
            for foe in ROSTER {
                if foe.kind == mark.kind {
                    incoming += float(foe.health)
                        * (0.07 if foe.role == "melee" else 0.1);
                }
            }
        }
        absorbed = min(economy.armor, incoming * 0.5);
        economy.armor -= absorbed;
        economy.health -= incoming - absorbed;
        economy.shells = max(0.0, economy.shells - incoming * 0.12);
        economy.low = min(economy.low, economy.health);
        if room.kind == "cache" {
            drop_item(director, room, "mega");
            drop_item(
                director,
                room,
                "heavy_armor" if director.stream.chance(0.5) else "shells"
            );
            economy.health = min(200.0, economy.health + 100.0);
            economy.placed_health += 1;
            continue;
        }
        if room.kind == "recovery" {
            drop_item(director, room, "health");
            drop_item(director, room, "shells");
            economy.health = min(100.0, economy.health + 25.0);
            economy.shells += 20.0;
            economy.placed_health += 1;
            economy.placed_shells += 1;
        }
        while economy.health < 55.0 {
            if not drop_item(director, room, "health") {
                break;
            }
            economy.health = min(100.0, economy.health + 25.0);
            economy.placed_health += 1;
        }
        if economy.shells < 10.0 and fights > 0.0 {
            if drop_item(director, room, "shells") {
                economy.shells += 20.0;
                economy.placed_shells += 1;
            }
        }
        if room.tension > 0.7
            and economy.armor < 20.0
            and director.stream.chance(0.5) {
            if drop_item(director, room, "armor") {
                economy.armor = 100.0;
                economy.placed_armor += 1;
            }
        }
    }
}

def room_lamps(director: Director) {
    for room in rooms_of(director.site) {
        interior = director.bp.interiors[room.beat];
        for cell in interior.lamps {
            point = world_point(room, cell, interior, 0.0);
            ceiling = float(room.z + interior.ceiling[cell]);
            director.bp.lamps.append(
                LampSpec(
                    x=point[0],
                    y=point[1],
                    z=ceiling - 40.0,
                    color=room.district,
                    strength=0.6 if room.kind == "cache" else 1.0,
                    radius=780.0 if room.size >= 2 else 700.0,
                    fixture=ceiling
                )
            );
        }
    }
}

# Arena lockdowns: entering the arena's heart slams its free entrances shut,
# Quake II reinforcements teleport in, and the doors reopen on a timer.
def lockdowns(director: Director) {
    bp = director.bp;
    arenas = [
        room
        for room in rooms_of(director.site)
        if room.kind in ["arena", "hub"] and room.size >= 3 and room.tension >= 0.5
    ];
    limit = 1 + (1 if director.density > 0.6 else 0);
    made = 0;
    for room in arenas {
        if made >= limit {
            break;
        }
        name = "lock_" + str(room.beat);
        taken: list[int] = [];
        for door in bp.doors {
            taken.extend(door.cells);
        }
        sealed = 0;
        for passage in passages_of(director.site) {
            if passage.teleport or passage.window {
                continue;
            }
            socket = passage.tail_socket
                if passage.tail == room.beat
                else passage.head_socket;
            if passage.tail != room.beat and passage.head != room.beat {
                continue;
            }
            sl = boundary_strip(room, socket);
            cells = [bp.index(cell[0], cell[1]) for cell in sl.cells];
            if [
                cell
                for cell in cells
                if cell in taken
            ] {
                continue;
            }
            bp.doors.append(
                DoorSpec(
                    cells=cells,
                    floor=max([bp.floor[cell] for cell in cells]),
                    ceiling=min([bp.ceiling[cell] for cell in cells]),
                    kind="lockdown",
                    name=name,
                    material=room.district,
                    across_x=sl.across_x,
                    link=passage.link,
                    start_open=True,
                    hold=16.0 + 4.0 * float(room.size)
                )
            );
            sealed += 1;
        }
        if sealed == 0 {
            continue;
        }
        base = stage_point(director, room, 0.0);
        bp.volumes.append(
            Volume(
                low=[base[0] - 96.0, base[1] - 96.0, base[2]],
                high=[base[0] + 96.0, base[1] + 96.0, base[2] + 96.0],
                kind="once",
                target=name
            )
        );
        reinforcements = 2 + int(room.tension * 3.0);
        for k in range(reinforcements) {
            foe = pick_foe(director, ["q2"], 6.0, "", 4);
            point = director.take_spot(room, base, False);
            if foe is None or not point {
                break;
            }
            director.mark(
                foe.kind,
                point,
                "q2",
                room.beat,
                facing(point, base),
                {"spawnflags": "2", "targetname": name}
            );
            director.economy.monsters += 1;
            director.economy.damage += float(foe.health) * 0.08;
        }
        bp.lamps.append(
            LampSpec(
                x=base[0],
                y=base[1],
                z=base[2] + 200.0,
                color=13,
                strength=0.8,
                radius=640.0
            )
        );
        made += 1;
    }
}

def direct(
    plan: Expedition, site: Site, bp: Blueprint, stream: Stream, density: float
) -> Economy {
    director = Director(plan=plan, site=site, bp=bp, stream=stream, density=density);
    stage_objectives(director);
    populate(director);
    lockdowns(director);
    supply(director);
    room_lamps(director);
    return director.economy;
}
