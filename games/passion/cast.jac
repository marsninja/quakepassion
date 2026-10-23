"""The cast: everything a level made from an essence holds besides its
architecture, read from the essence's graph.

- **Gates**: each of the essence's doors stands where it stood, across the
  whole width of the new doorway, opening upward; one that wanted keys wants
  them still, one that something else opened is opened by it (its
  targetname), a secret one opens to a shot. Lifts stand in their shafts.
- **Openers**: a key lies where the essence's lay (or where a move put it);
  a plate to step on, a button to shoot or a monster to kill stands where
  the essence's opener was done from, and fires its gate.
- **The way out**: a gate of light where the essence's was; one fired by a
  chain is shut in a cage its openers lift. An arena has none of its own:
  it is cleared, and a counter of its foes' deaths opens a gate on its
  highest ground.
- **The population**, cast afresh: each stage of the essence's progression
  gets foes from the roster of all three games (weighted to its district's
  game) as strong in all as the essence's were there, and the health,
  armour, ammunition and weapons the essence had there, each in its
  district's game's own kind (`stage_budget`)."""
import math;
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.formats.aas { TRAVEL_TELEPORT, TRAVEL_JUMPPAD }
import from engine.level.graph { LevelGraph, Place, Move, Gate, Opener, Thing, graph_places, graph_gates, graph_openers, graph_things, thing_place, opener_places, barred_places }
import from engine.level.budget { stage_budget, foe_stats, ammo_damage }
import from editor.formats.map { MapItem }
import from editor.geometry.brush { Side }
import from .random { Stream }
import from .massing { CELL, LIFT }
import from .kits { kit_of }
import from .dress { plain_box }
import from .sculpt { Sculpting, Ground, box_cells, lift_levels, LiftShaft, sculpture_grounds }

glob TELEPORT_MATERIAL: str = "q1:e1m1/*teleport",
     BUTTON_MATERIAL: str = "q1:e1m1/+0basebtn";

"""A foe of the roster: its class, the game it is from, its role."""
obj Foe {
    has kind: str,
        source: str,
        role: str = "melee";
}

glob CAST_ROSTER: list[Foe] = [
         Foe(kind="monster_army", source="q1", role="ranged"),
         Foe(kind="monster_dog", source="q1"),
         Foe(kind="monster_knight", source="q1"),
         Foe(kind="monster_enforcer", source="q1", role="ranged"),
         Foe(kind="monster_wizard", source="q1", role="fly"),
         Foe(kind="monster_ogre", source="q1", role="ranged"),
         Foe(kind="monster_demon1", source="q1"),
         Foe(kind="monster_hell_knight", source="q1", role="ranged"),
         Foe(kind="monster_shalrath", source="q1", role="ranged"),
         Foe(kind="monster_shambler", source="q1", role="ranged"),
         Foe(kind="monster_soldier_light", source="q2", role="ranged"),
         Foe(kind="monster_soldier", source="q2", role="ranged"),
         Foe(kind="monster_soldier_ss", source="q2", role="ranged"),
         Foe(kind="monster_infantry", source="q2", role="ranged"),
         Foe(kind="monster_flyer", source="q2", role="fly"),
         Foe(kind="monster_parasite", source="q2"),
         Foe(kind="monster_gunner", source="q2", role="ranged"),
         Foe(kind="monster_chick", source="q2", role="ranged"),
         Foe(kind="monster_berserk", source="q2"),
         Foe(kind="monster_floater", source="q2", role="fly"),
         Foe(kind="monster_mutant", source="q2"),
         Foe(kind="monster_brain", source="q2"),
         Foe(kind="monster_gladiator", source="q2", role="ranged"),
         Foe(kind="monster_tank", source="q2", role="ranged"),
         Foe(kind="monster_tank_commander", source="q2", role="ranged")
     ];

"""Weapons by game, each with how strong a pick-up it is (1 to 6)."""
glob CAST_ARMS: dict[str, dict[str, int]] = {
         "q1": {"weapon_supershotgun": 2, "weapon_nailgun": 2, "weapon_supernailgun": 3, "weapon_grenadelauncher": 3, "weapon_rocketlauncher": 4, "weapon_lightning": 5},
         "q2": {
             "weapon_shotgun": 1,
             "weapon_supershotgun": 2,
             "weapon_machinegun": 2,
             "weapon_chaingun": 3,
             "weapon_grenadelauncher": 3,
             "weapon_rocketlauncher": 4,
             "weapon_hyperblaster": 4,
             "weapon_railgun": 5,
             "weapon_bfg": 6
         },
         "q3": {
             "weapon_shotgun": 2,
             "weapon_grenadelauncher": 3,
             "weapon_rocketlauncher": 4,
             "weapon_plasmagun": 4,
             "weapon_lightning": 4,
             "weapon_railgun": 5,
             "weapon_bfg": 6
         }
     };

"""Supplies by game: health (classname, how much), armour (classname, how
much it absorbs), and each ammunition (classname, how much)."""
glob CAST_HEALTH: dict[str, tuple[str, float]] = {
         "q1": ("item_health", 25.0),
         "q2": ("item_health_large", 25.0),
         "q3": ("item_health", 25.0)
     };

glob CAST_ARMOR: dict[str, tuple[str, float]] = {
         "q1": ("item_armor1", 30.0),
         "q2": ("item_armor_combat", 30.0),
         "q3": ("item_armor_combat", 33.0)
     };

glob CAST_AMMO: dict[str, dict[str, tuple[str, float]]] = {
         "q1": {"shells": ("item_shells", 20.0), "nails": ("item_spikes", 25.0), "rockets": ("item_rockets", 5.0), "cells": ("item_cells", 6.0)},
         "q2": {
             "shells": ("ammo_shells", 10.0),
             "bullets": ("ammo_bullets", 50.0),
             "grenades": ("ammo_grenades", 5.0),
             "rockets": ("ammo_rockets", 5.0),
             "cells": ("ammo_cells", 50.0),
             "slugs": ("ammo_slugs", 10.0)
         },
         "q3": {
             "shells": ("ammo_shells", 10.0),
             "bullets": ("ammo_bullets", 50.0),
             "grenades": ("ammo_grenades", 5.0),
             "rockets": ("ammo_rockets", 5.0),
             "cells": ("ammo_cells", 30.0),
             "slugs": ("ammo_slugs", 10.0),
             "lightning": ("ammo_lightning", 60.0)
         }
     };

"""What was cast: the entities (brush entities with their brushes), the way
out's box, where the start is, and tallies."""
obj Casting {
    has items: list[MapItem] = [],
        # Solid the world keeps besides its shell: the rock a door opens
        # into (the shell is a cell thick, and outside it is nothing).
        solids: list[list[Side]] = [],
        exit_low: list[float] = [],
        exit_high: list[float] = [],
        start: list[float] = [],
        monsters: int = 0,
        doors: int = 0,
        notes: list[str] = [];

    def put(fields: dict[str, str]) {
        self.items.append(MapItem(fields=fields));
    }

    def put_brushed(fields: dict[str, str], brushes: list[list[Side]]) {
        item = MapItem(fields=fields);
        item.brushes = brushes;
        self.items.append(item);
    }
}

"""A point as a map's origin field."""
def origin_text(x: float, y: float, z: float) -> str {
    return str(int(round(x))) + " " + str(int(round(y))) + " " + str(int(round(z)));
}

"""The targetname a gate is fired by."""
def gate_name(model: int) -> str {
    return "gate" + str(model);
}

"""The key item for a key token, and the game it is from."""
def key_item(token: str) -> list[str] {
    if token == "key_silver" {
        return ["item_key1", "q1"];
    }
    if token == "key_gold" {
        return ["item_key2", "q1"];
    }
    return [token, "q2"];
}

"""The district game of the space a ground is in."""
def ground_game(made: Sculpting, ground: Ground) -> str {
    return kit_of(made.spaces[ground.space].district).game;
}

"""A key for a ground in a set of grounds taken."""
def ground_id(ground: Ground) -> int {
    return ((ground.z + 4096) * 8192 + (ground.y + 4096)) * 8192 + (ground.x + 4096);
}

"""Cast a level made from an essence."""
def cast_level(atlas: LevelGraph, made: Sculpting, dice: Stream) -> Casting {
    casting = Casting();
    taken: dict[int, bool] = {};
    cast_start(atlas, made, casting, taken);
    gated = cast_gates(atlas, made, casting);
    cast_openers(atlas, made, casting, taken, gated, dice.derive("openers"));
    cast_teleporters(atlas, made, casting, taken);
    cast_jump_pads(atlas, made, casting, taken);
    foes = cast_population(atlas, made, casting, taken, gated, dice.derive("population"));
    cast_exit(atlas, made, casting, foes);
    return casting;
}

"""The start, where the essence's was, facing as it faced."""
def cast_start(atlas: LevelGraph, made: Sculpting, casting: Casting, taken: dict[int, bool]) {
    for place in graph_places(atlas) {
        if not place.start {
            continue;
        }
        point = Vec3(x=place.center.x, y=place.center.y, z=place.floor + 24.0);
        ground = made.ground_at(point, place.area);
        if ground is None {
            continue;
        }
        at = made.ground_point(ground);
        casting.start = at;
        casting.put({"classname": "info_player_start", "origin": origin_text(at[0], at[1], at[2]), "angle": str(int(atlas.start_yaw))});
        taken[ground_id(ground)] = True;
        return;
    }
}

"""Rock over a door that rises (from `low` to `high`): solid the height it
rises, over its box, so it opens into rock rather than out of the world."""
def rock_over(casting: Casting, made: Sculpting, low: Vec3, high: Vec3) {
    top = high.z + (high.z - low.z) + 16.0;
    mass = made.mass;
    if mass is not None {
        # No higher than the air of a space over it: rock there would stand
        # in that room.
        start = int(math.ceil(high.z / LIFT));
        for cx in range(int(math.floor(low.x / CELL)), int(math.ceil(high.x / CELL))) {
            for cy in range(int(math.floor(low.y / CELL)), int(math.ceil(high.y / CELL))) {
                cz = start;
                while float(cz) * LIFT < top and not mass.air(cx, cy, cz) {
                    cz += 1;
                }
                top = min(top, float(cz) * LIFT);
            }
        }
    }
    if top > high.z {
        casting.solids.append(plain_box(Vec3(x=low.x, y=low.y, z=high.z), Vec3(x=high.x, y=high.y, z=top), "caulk", 1.0));
    }
}

"""Doors and lifts. Answers the cells (x, y) they stand in, kept clear of
the population."""
def cast_gates(atlas: LevelGraph, made: Sculpting, casting: Casting) -> dict[tuple[int, int], bool] {
    gated: dict[tuple[int, int], bool] = {};
    # Doors of a double door fall on one box: one door each box.
    placed: dict[str, bool] = {};
    for gate in graph_gates(atlas) {
        # A door stands in the doorway it bars; a mover the essence stood on
        # (a floor that lowered, a bridge) is floor here.
        if gate.kind == "lift" or gate.lowers() or not barred_places(gate) {
            continue;
        }
        box = gate.box;
        low_lift = int(math.floor(box.mins.z / LIFT)) - 2;
        high_lift = int(math.ceil(box.maxs.z / LIFT));
        hits: list[Ground] = [];
        for cell in box_cells(box, 4.0) {
            for ground in made.columns.get(cell, []) {
                if low_lift <= ground.z <= high_lift and not ground.top {
                    hits.append(ground);
                    gated[cell] = True;
                }
            }
        }
        if not hits {
            continue;
        }
        # As tall as the doorway's lowest ceiling (six to nine lifts): above
        # that a body cannot reach, and a taller door would rise past the
        # rock over it.
        floor = min([ground.z for ground in hits]);
        roof = floor + max(6, min(9, min([ground.ceiling for ground in hits]) - floor));
        size = box.maxs.sub(box.mins);
        if size.x <= size.y {
            middle = (box.mins.x + box.maxs.x) * 0.5;
            half = max(4.0, size.x * 0.5);
            low = Vec3(x=middle - half, y=float(min([ground.y for ground in hits])) * CELL, z=float(floor) * LIFT);
            high = Vec3(x=middle + half, y=float(max([ground.y for ground in hits]) + 1) * CELL, z=float(roof) * LIFT);
        } else {
            middle = (box.mins.y + box.maxs.y) * 0.5;
            half = max(4.0, size.y * 0.5);
            low = Vec3(x=float(min([ground.x for ground in hits])) * CELL, y=middle - half, z=float(floor) * LIFT);
            high = Vec3(x=float(max([ground.x for ground in hits]) + 1) * CELL, y=middle + half, z=float(roof) * LIFT);
        }
        a = made.moved(low.x, low.y, low.z);
        b = made.moved(high.x, high.y, high.z);
        kit = kit_of(made.spaces[hits[0].space].district);
        secret = gate.kind == "secret";
        fields = {"classname": "func_door", "angle": "-1", "speed": "60" if secret else "160", "wait": "-1", "lip": "8"};
        keys = [need for need in gate.needs if need.startswith("key")];
        if keys {
            fields["key"] = " ".join(keys);
        }
        if ("open:" + str(gate.model)) in gate.needs {
            fields["targetname"] = gate_name(gate.model);
        }
        if secret and "targetname" not in fields {
            fields["health"] = "1";
            fields["_secret"] = "1";
        }
        key = str(int(a[0])) + "," + str(int(a[1])) + "," + str(int(a[2])) + "," + str(int(b[0])) + "," + str(int(b[1])) + "," + str(int(b[2]));
        if key in placed {
            continue;
        }
        placed[key] = True;
        casting.put_brushed(fields, [plain_box(Vec3(x=a[0], y=a[1], z=a[2]), Vec3(x=b[0], y=b[1], z=b[2]), kit.wall if secret else kit.door, kit.scale)]);
        rock_over(casting, made, Vec3(x=a[0], y=a[1], z=a[2]), Vec3(x=b[0], y=b[1], z=b[2]));
        casting.doors += 1;
    }
    for lift in made.lifts {
        cells = box_cells(lift.box, 8.0);
        if not cells {
            continue;
        }
        levels = lift_levels(lift);
        a = made.moved(float(min([cell[0] for cell in cells])) * CELL, float(min([cell[1] for cell in cells])) * CELL, float(levels[1]) * LIFT - 8.0);
        b = made.moved(float(max([cell[0] for cell in cells]) + 1) * CELL, float(max([cell[1] for cell in cells]) + 1) * CELL, float(levels[1]) * LIFT);
        owner = made.spaces[0];
        for cell in cells {
            for ground in made.columns.get(cell, []) {
                owner = made.spaces[ground.space];
            }
            gated[cell] = True;
        }
        kit = kit_of(owner.district);
        if lift.lowering {
            # The floor stands at the top, filling the shaft, lowers (all but
            # its lip) when it is touched, and rises again a few seconds
            # later: a lift both ways. Fired once and left down, it would
            # take away the ways over it, which the proof (tokens only
            # open) cannot see.
            foot = made.moved(0.0, 0.0, float(levels[0]) * LIFT - 8.0);
            fields = {"classname": "func_door", "angle": "-2", "speed": "100", "wait": "3", "lip": "8"};
            casting.put_brushed(fields, [plain_box(Vec3(x=a[0], y=a[1], z=foot[2]), Vec3(x=b[0], y=b[1], z=b[2]), kit.step, kit.scale)]);
            continue;
        }
        fields = {"classname": "func_plat", "height": str((levels[1] - levels[0]) * int(LIFT)), "speed": "150"};
        for gate in graph_gates(atlas) {
            if gate.model == lift.model and ("open:" + str(gate.model)) in gate.needs {
                fields["targetname"] = gate_name(gate.model);
            }
        }
        casting.put_brushed(fields, [plain_box(Vec3(x=a[0], y=a[1], z=a[2]), Vec3(x=b[0], y=b[1], z=b[2]), kit.step, kit.scale)]);
    }
    return gated;
}

"""The ground an opener is done from in the level: of the grounds of the
places the essence's was done from, the nearest its point that is firm
floor (off any lift or lowering floor, out of any doorway); else the
nearest ground to its point."""
def opener_ground(made: Sculpting, opener: Opener, gated: dict[tuple[int, int], bool]) -> Ground | None {
    best: Ground | None = None;
    nearest = 1.0e9;
    for place in opener_places(opener) {
        for ground in made.by_area.get(place.area, []) {
            if ground.top or (ground.x, ground.y) in gated {
                continue;
            }
            middle = Vec3(x=(float(ground.x) + 0.5) * CELL, y=(float(ground.y) + 0.5) * CELL, z=ground.base + 24.0);
            gap = middle.sub(opener.point).length();
            if gap < nearest {
                nearest = gap;
                best = ground;
            }
        }
    }
    if best is not None {
        return best;
    }
    places = opener_places(opener);
    return made.ground_at(opener.point, places[0].area if places else 0);
}

"""Openers: each where the essence's was done from, firing its gate (a key
gives its key; the way out's openers lift the cage over the way out)."""
def cast_openers(atlas: LevelGraph, made: Sculpting, casting: Casting, taken: dict[int, bool], gated: dict[tuple[int, int], bool], dice: Stream) {
    lowering = set([lift.model for lift in made.lifts if lift.lowering]);
    for opener in graph_openers(atlas) {
        ground = opener_ground(made, opener, gated);
        if ground is None {
            casting.notes.append("opener " + opener.kind + " " + opener.token + " has no ground");
            continue;
        }
        taken[ground_id(ground)] = True;
        at = made.ground_point(ground);
        floor = at[2] - 24.0;
        target = "exit_gate" if opener.token == "exit" else (gate_name(int(opener.token[5:])) if opener.token.startswith("open:") else "");
        # A floor that lowers works by itself (it is touched); nothing fires it.
        if opener.token.startswith("open:") and int(opener.token[5:]) in lowering {
            continue;
        }
        kit = kit_of(made.spaces[ground.space].district);
        if opener.token.startswith("key") {
            found = key_item(opener.token);
            casting.put({"classname": found[0], "origin": origin_text(at[0], at[1], at[2]), "asset_game": found[1]});
        } elif opener.kind in ["press", "touch"] {
            # A plate set in the floor, thrown by stepping onto it.
            casting.put_brushed(
                {"classname": "func_wall", "_passion": "plate"},
                [plain_box(Vec3(x=at[0] - 24.0, y=at[1] - 24.0, z=floor), Vec3(x=at[0] + 24.0, y=at[1] + 24.0, z=floor + 4.0), BUTTON_MATERIAL, 1.0)]
            );
            casting.put_brushed(
                {"classname": "trigger_once", "target": target},
                [plain_box(Vec3(x=at[0] - 24.0, y=at[1] - 24.0, z=floor + 4.0), Vec3(x=at[0] + 24.0, y=at[1] + 24.0, z=floor + 64.0), "trigger", 1.0)]
            );
        } elif opener.kind == "shoot" {
            # A button on a short column, fired by a shot.
            casting.put_brushed(
                {"classname": "func_wall", "_passion": "column"},
                [plain_box(Vec3(x=at[0] - 12.0, y=at[1] - 12.0, z=floor), Vec3(x=at[0] + 12.0, y=at[1] + 12.0, z=floor + 40.0), kit.support, kit.scale)]
            );
            casting.put_brushed(
                {"classname": "func_button", "angle": "-2", "health": "1", "wait": "-1", "target": target},
                [plain_box(Vec3(x=at[0] - 10.0, y=at[1] - 10.0, z=floor + 40.0), Vec3(x=at[0] + 10.0, y=at[1] + 10.0, z=floor + 48.0), BUTTON_MATERIAL, 1.0)]
            );
        } elif opener.kind == "kill" {
            foe = CAST_ROSTER[dice.below(len(CAST_ROSTER))];
            casting.put({"classname": foe.kind, "origin": origin_text(at[0], at[1], at[2]), "target": target, "asset_game": foe.source});
            casting.monsters += 1;
        } else {
            # An item whose pickup fires the gate.
            pick = CAST_HEALTH[kit.game];
            casting.put({"classname": pick[0], "origin": origin_text(at[0], at[1], at[2]), "target": target, "asset_game": kit.game});
        }
    }
}

"""Teleporters where the essence's took a body: a trigger and a pad where
it stepped in, a destination where it came out."""
def cast_teleporters(atlas: LevelGraph, made: Sculpting, casting: Casting, taken: dict[int, bool]) {
    done: dict[str, bool] = {};
    number = 0;
    for place in graph_places(atlas) {
        for move in [edge place->:Move:->] {
            if move.kind != TRAVEL_TELEPORT {
                continue;
            }
            key = str(place.area) + ">" + str(int(move.finish.x // 64.0)) + "," + str(int(move.finish.y // 64.0));
            if key in done {
                continue;
            }
            done[key] = True;
            here = made.ground_at(move.start, place.area);
            there = made.ground_at(move.finish, move.to);
            if here is None or there is None {
                continue;
            }
            taken[ground_id(here)] = True;
            taken[ground_id(there)] = True;
            number += 1;
            name = "tele" + str(number);
            at = made.ground_point(here);
            floor = at[2] - 24.0;
            casting.put_brushed(
                {"classname": "func_wall", "_passion": "teleporter"},
                [plain_box(Vec3(x=at[0] - 24.0, y=at[1] - 24.0, z=floor), Vec3(x=at[0] + 24.0, y=at[1] + 24.0, z=floor + 4.0), TELEPORT_MATERIAL, 1.0)]
            );
            casting.put_brushed(
                {"classname": "trigger_teleport", "target": name},
                [plain_box(Vec3(x=at[0] - 20.0, y=at[1] - 20.0, z=floor + 4.0), Vec3(x=at[0] + 20.0, y=at[1] + 20.0, z=floor + 68.0), "trigger", 1.0)]
            );
            arrive = made.ground_point(there);
            casting.put({"classname": "info_teleport_destination", "targetname": name, "origin": origin_text(arrive[0], arrive[1], arrive[2] + 8.0), "angle": "0"});
            casting.put({"classname": "light", "origin": origin_text(at[0], at[1], floor + 64.0), "light": "180", "_color": "180 200 255"});
        }
    }
}

"""Jump pads where the essence threw a body: a pad and a push where it was
thrown from, aimed (as Quake III aims its pads) to top out over where it
came down."""
def cast_jump_pads(atlas: LevelGraph, made: Sculpting, casting: Casting, taken: dict[int, bool]) {
    done: dict[int, bool] = {};
    number = 0;
    for place in graph_places(atlas) {
        for move in [edge place->:Move:->] {
            if move.kind != TRAVEL_JUMPPAD or place.area in done {
                continue;
            }
            done[place.area] = True;
            here = made.ground_at(move.start, place.area);
            there = made.ground_at(move.finish, move.to);
            if here is None or there is None {
                continue;
            }
            taken[ground_id(here)] = True;
            number += 1;
            name = "pad" + str(number);
            at = made.ground_point(here);
            floor = at[2] - 24.0;
            arrive = made.ground_point(there);
            casting.put_brushed(
                {"classname": "func_wall", "_passion": "jumppad"},
                [plain_box(Vec3(x=at[0] - 24.0, y=at[1] - 24.0, z=floor), Vec3(x=at[0] + 24.0, y=at[1] + 24.0, z=floor + 4.0), BUTTON_MATERIAL, 1.0)]
            );
            casting.put_brushed(
                {"classname": "trigger_push", "target": name},
                [plain_box(Vec3(x=at[0] - 24.0, y=at[1] - 24.0, z=floor + 4.0), Vec3(x=at[0] + 24.0, y=at[1] + 24.0, z=floor + 40.0), "trigger", 1.0)]
            );
            top = max(at[2], arrive[2]) + 96.0;
            casting.put({"classname": "info_notnull", "targetname": name, "origin": origin_text(arrive[0], arrive[1], top)});
        }
    }
}

"""Grounds a thing may stand on: floor with a body's room over it, out of
liquid, off lifts, reached, away from doors and what is cast already."""
def standing_grounds(made: Sculpting, gated: dict[tuple[int, int], bool], taken: dict[int, bool]) -> list[Ground] {
    found: list[Ground] = [];
    for ground in sculpture_grounds(made.sculpture) {
        if ground.liquid > 0 or ground.top or ground.reach < 0 or ground.ceiling - ground.z < 5 or ground_id(ground) in taken {
            continue;
        }
        near_gate = False;
        for dx in [-1, 0, 1] {
            for dy in [-1, 0, 1] {
                if (ground.x + dx, ground.y + dy) in gated {
                    near_gate = True;
                }
            }
        }
        if not near_gate {
            found.append(ground);
        }
    }
    return found;
}

"""Of `pool`, the ground furthest from everything chosen so far (with a
little chance in it), taken."""
def spread_pick(pool: list[Ground], chosen: list[Ground], taken: dict[int, bool], dice: Stream) -> Ground | None {
    best: Ground | None = None;
    best_score = -1.0;
    for ground in pool {
        if ground_id(ground) in taken {
            continue;
        }
        gap = 24.0;
        for other in chosen {
            gap = min(gap, float(abs(other.x - ground.x) + abs(other.y - ground.y)) + 0.25 * float(abs(other.z - ground.z)));
        }
        score = gap + dice.unit() * 2.0 + 0.1 * float(min(ground.open, 6));
        if score > best_score {
            best_score = score;
            best = ground;
        }
    }
    if best is not None {
        taken[ground_id(best)] = True;
        chosen.append(best);
    }
    return best;
}

"""The population, stage by stage to the essence's budget: foes as strong
in all as the essence's were in the stage (none much stronger than its
strongest), its health, armour and ammunition (as the damage it does) in
the district's game's own kinds, and a weapon for each it had, as strong a
pick-up in the district's game. Answers how many foes were cast (an
arena's gate counts them)."""
def cast_population(atlas: LevelGraph, made: Sculpting, casting: Casting, taken: dict[int, bool], gated: dict[tuple[int, int], bool], dice: Stream) -> int {
    budget = stage_budget(atlas);
    strongest: dict[int, float] = {};
    arms: dict[int, list[int]] = {};
    for thing in graph_things(atlas) {
        standing = thing_place(thing);
        if standing is None or standing.stage < 0 {
            continue;
        }
        if thing.classname.startswith("monster_") {
            strongest[standing.stage] = max(strongest.get(standing.stage, 0.0), foe_stats(thing.game, thing.classname)[0]);
        } elif thing.classname.startswith("weapon_") {
            arms.setdefault(standing.stage, []).append(CAST_ARMS.get(thing.game, {}).get(thing.classname, 2));
        }
    }
    pool = standing_grounds(made, gated, taken);
    by_stage: dict[int, list[Ground]] = {};
    for ground in pool {
        by_stage.setdefault(ground.stage, []).append(ground);
    }
    foes = 0;
    for stage in sorted(budget.keys()) {
        row = budget[stage];
        grounds = by_stage.get(stage, []);
        if not grounds {
            grounds = pool;
        }
        if not grounds {
            continue;
        }
        chosen: list[Ground] = [];
        spent = 0.0;
        cap = max(60.0, strongest.get(stage, 100.0) * 1.3);
        guard = 0;
        while spent < row[0] * 0.95 and guard < 64 {
            guard += 1;
            ground = spread_pick(grounds, chosen, taken, dice);
            if ground is None {
                break;
            }
            game = ground_game(made, ground);
            weights: list[float] = [];
            for foe in CAST_ROSTER {
                health = foe_stats(foe.source, foe.kind)[0];
                weight = 0.0;
                if health <= cap and health <= row[0] - spent + 40.0 {
                    weight = 3.0 if foe.source == game else 0.7;
                    if foe.role == "fly" and ground.ceiling - ground.z < 12 {
                        weight = 0.0;
                    }
                }
                weights.append(weight);
            }
            if max(weights) <= 0.0 {
                break;
            }
            foe = CAST_ROSTER[dice.weighted(weights)];
            at = made.ground_point(ground);
            fields = {"classname": foe.kind, "origin": origin_text(at[0], at[1], at[2]), "angle": str(dice.below(8) * 45), "asset_game": foe.source};
            if atlas.arena {
                fields["target"] = "arena_clear";
            }
            casting.put(fields);
            spent += foe_stats(foe.source, foe.kind)[0];
            casting.monsters += 1;
            foes += 1;
        }
        health = row[1];
        while health > 10.0 {
            ground = spread_pick(grounds, chosen, taken, dice);
            if ground is None {
                break;
            }
            game = ground_game(made, ground);
            pick = CAST_HEALTH[game];
            at = made.ground_point(ground);
            casting.put({"classname": pick[0], "origin": origin_text(at[0], at[1], at[2]), "asset_game": game});
            health -= pick[1];
        }
        armor = row[2];
        while armor > 15.0 {
            ground = spread_pick(grounds, chosen, taken, dice);
            if ground is None {
                break;
            }
            game = ground_game(made, ground);
            plate = CAST_ARMOR[game];
            at = made.ground_point(ground);
            casting.put({"classname": plate[0], "origin": origin_text(at[0], at[1], at[2]), "asset_game": game});
            armor -= plate[1];
        }
        damage = row[3];
        while damage > 40.0 {
            ground = spread_pick(grounds, chosen, taken, dice);
            if ground is None {
                break;
            }
            game = ground_game(made, ground);
            kinds = CAST_AMMO[game];
            names = sorted(kinds.keys());
            kind = names[dice.below(len(names))];
            ammo = kinds[kind];
            at = made.ground_point(ground);
            casting.put({"classname": ammo[0], "origin": origin_text(at[0], at[1], at[2]), "asset_game": game});
            damage -= ammo[1] * ammo_damage(kind);
        }
        for strength in arms.get(stage, []) {
            ground = spread_pick(grounds, chosen, taken, dice);
            if ground is None {
                break;
            }
            game = ground_game(made, ground);
            best = "";
            for (name, value) in CAST_ARMS[game].items() {
                if not best or abs(value - strength) < abs(CAST_ARMS[game][best] - strength) {
                    best = name;
                }
            }
            at = made.ground_point(ground);
            casting.put({"classname": best, "origin": origin_text(at[0], at[1], at[2]), "asset_game": game});
        }
    }
    return foes;
}

"""The way out: a gate of light where the essence's was (the ground of its
way-out places furthest along the way), caged when the essence fired its
way out by a chain. An arena's stands on its highest ground, caged until
every foe is dead."""
def cast_exit(atlas: LevelGraph, made: Sculpting, casting: Casting, foes: int) {
    target: Ground | None = None;
    if not atlas.arena {
        for place in graph_places(atlas) {
            if not place.way_out {
                continue;
            }
            for ground in made.by_area.get(place.area, []) {
                if target is None or ground.reach > target.reach {
                    target = ground;
                }
            }
        }
    }
    shut = atlas.arena or "exit" in [opener.token for opener in graph_openers(atlas)];
    if target is None {
        for ground in sculpture_grounds(made.sculpture) {
            if ground.reach < 0 or ground.liquid > 0 or ground.top {
                continue;
            }
            if target is None or ground.z > target.z or (ground.z == target.z and ground.reach > target.reach) {
                target = ground;
            }
        }
    }
    if target is None {
        return;
    }
    at = made.ground_point(target);
    floor = at[2] - 24.0;
    kit = kit_of(made.spaces[target.space].district);
    casting.put_brushed(
        {"classname": "func_wall", "_passion": "exit"},
        [plain_box(Vec3(x=at[0] - 32.0, y=at[1] - 32.0, z=floor), Vec3(x=at[0] + 32.0, y=at[1] + 32.0, z=floor + 8.0), TELEPORT_MATERIAL, 1.0)]
    );
    casting.put({"classname": "light", "origin": origin_text(at[0], at[1], floor + 56.0), "light": "300", "_color": "200 220 255"});
    casting.exit_low = [at[0] - 32.0, at[1] - 32.0, floor + 2.0];
    casting.exit_high = [at[0] + 32.0, at[1] + 32.0, floor + 96.0];
    if shut {
        cage_low = Vec3(x=at[0] - 40.0, y=at[1] - 40.0, z=floor + 8.0);
        cage_high = Vec3(x=at[0] + 40.0, y=at[1] + 40.0, z=floor + 104.0);
        casting.put_brushed(
            {"classname": "func_door", "angle": "-1", "speed": "120", "wait": "-1", "lip": "8", "targetname": "exit_gate"},
            [plain_box(cage_low, cage_high, kit.door, kit.scale)]
        );
        rock_over(casting, made, cage_low, Vec3(x=cage_high.x, y=cage_high.y, z=max(cage_high.z, float(target.ceiling - made.offset[2]) * LIFT)));
        if atlas.arena and foes > 0 {
            casting.put({"classname": "trigger_counter", "targetname": "arena_clear", "count": str(foes), "target": "exit_gate", "message": "The way out is open"});
        }
    }
}
