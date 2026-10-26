"""Derived prefabs: the stretches of the original levels raised again from
their blueprints (`blueprint.jac`), as they are.

A region of a blueprint becomes a `Piece`: its cells, its box (a wall a
cell thick round them), and its doorways, the doors the level was cut at.
For each doorway the piece knows which way it faces, whether a passage can
leave it straight out to the box's face without running beside the piece's
own rooms, and what its door wanted: a key, or a targetname its own
buttons and triggers fire (then it is the piece's own gate, a way out of it
only), or nothing.

A `Derived` prefab raises a piece cell by cell, liquids and all, with the
original's own entities (doors, buttons, lifts, triggers, monsters, items,
lights), their names made its own and their headings turned with it. The
original's start becomes a level's start, its way out a level's slipgate."""
import math;
import from engine.math.vec3 { Vec3 }
import from .random { Stream }
import from .massing { CELL, LIFT }
import from .space { Space }
import from .kits { KITS, kit_of }
import from .cast { BUTTON_MATERIAL, origin_text }
import from .prefab { Prefab, Port, Lay, Raise, Raising }
import from .blueprint { Blueprint, Region, Cut, Thing, read_blueprint, blueprint_regions, bp_thing_cells, bp_doorways, bp_root, BP_WATER, BP_SLIME, BP_LAVA }
import from engine.level.graph { LevelGraph, Place, Move, Gate, Opener, graph_places, graph_gates, graph_openers, opener_places }

"""Entities a piece does not keep as they are: the original's starts (one
becomes a level's start), its way out (a level's slipgate), and what only
the original's episode wanted."""
glob DERIVED_DROPPED: list[str] = [
         "info_player_start",
         "info_player_coop",
         "info_player_deathmatch",
         "info_intermission",
         "trigger_changelevel",
         "func_episodegate",
         "func_bossgate",
         "trigger_setskill",
         "worldspawn"
     ];

"""A door a piece was cut at, in the blueprint's cells: its doors, the
face of the piece it opens in (0 +x, 1 +y, 2 -x, 3 -y), its span along that
face (a0..a1) and its floor and top in lifts; the cells a passage through
it cuts (the doorway and on out to the face); whether that passage stays
clear of the piece's own rooms; what its door wanted, and whether the
piece itself gives that (its own buttons, or its own key)."""
obj Doorway {
    has doors: list[int] = [],
        face: int = 0,
        a0: int = 0,
        a1: int = 0,
        floor: int = 0,
        top: int = 0,
        path: list[list[int]] = [],
        # Where a passage leaves it: the middle of the doors' outer face, in
        # the blueprint's cells.
        out_x: float = 0.0,
        out_y: float = 0.0,
        clear: bool = True,
        gate: str = "",
        owned: bool = False,
        # The piece's doorways (by number) a body reaches from this one
        # without leaving the piece, and whether it reaches its way out.
        reach: list[int] = [],
        reaches_exit: bool = False;
}

"""A region of a blueprint made ready to raise: its box in the blueprint's
cells, its doorways, whether it holds the start or the way out, the keys it
gives, and the district whose materials it takes."""
obj Piece {
    has plan: Blueprint,
        region: int,
        x0: int = 0,
        y0: int = 0,
        z0: int = 0,
        x1: int = 0,
        y1: int = 0,
        z1: int = 0,
        doorways: list[Doorway] = [],
        start: bool = False,
        way_out: bool = False,
        keys: list[str] = [],
        district: int = 0,
        title: str = "",
        # Its air, in its own cells (from its box's low corner).
        cells: list[list[int]] = [],
        # The doorways a body reaches from its start without leaving it.
        start_reach: list[int] = [],
        # Doors of the original freed in it: what opened them is not in it,
        # or nothing could reach what opened them.
        freed: set[int] = set();

    """Whether it can begin a level, stand between two others, or end one."""
    def can_begin -> bool {
        return self.start and len([number for number in self.start_reach if self.doorways[number].clear]) >= 1;
    }

    def can_end -> bool {
        return self.way_out and len([way for way in self.doorways if way.clear and way.reaches_exit]) >= 1;
    }

    def can_join -> bool {
        if self.start or self.way_out {
            return False;
        }
        for (number, way) in enumerate(self.doorways) {
            if way.clear and len([other for other in way.reach if other != number and self.doorways[other].clear]) > 0 {
                return True;
            }
        }
        return False;
    }
}

"""The district of an original: the kit read off it, else its game's
first."""
def derived_district(spec: str) -> int {
    parts = spec.split(":");
    for (index, kit) in enumerate(KITS) {
        if kit.game == parts[0] and kit.source == parts[1] {
            return index;
        }
    }
    for (index, kit) in enumerate(KITS) {
        if kit.game == parts[0] {
            return index;
        }
    }
    return 0;
}

"""Everything that fires a targetname, through relays and counters."""
def derived_openers(plan: Blueprint, name: str) -> list[int] {
    found: list[int] = [];
    names = [name];
    seen: set[str] = set();
    while names {
        wanted = names.pop();
        if wanted in seen {
            continue;
        }
        seen.add(wanted);
        for (number, thing) in enumerate(plan.things) {
            if thing.fields.get("target", "") != wanted and thing.fields.get("killtarget", "") != wanted {
                continue;
            }
            if thing.classname in ["trigger_relay", "trigger_counter"] and thing.fields.get("targetname", "") {
                names.append(thing.fields["targetname"]);
            } else {
                found.append(number);
            }
        }
    }
    return found;
}

"""The key a door wants by its spawnflags (Quake's 8 gold, 16 silver), or
""."""
def derived_key(fields: dict[str, str]) -> str {
    words = fields.get("spawnflags", "0").split(".");
    flags = int(words[0]) if words[0].lstrip("-").isdigit() else 0;
    if flags & 16 {
        return "key_silver";
    }
    if flags & 8 {
        return "key_gold";
    }
    return "";
}

"""A doorway of a region through the doors of one cut."""
def derived_doorway(plan: Blueprint, region: int, doors: list[int], piece: Piece) -> Doorway {
    way = Doorway(doors=doors);
    cells: list[list[int]] = [];
    for number in doors {
        for cell in bp_thing_cells(plan, plan.things[number]) {
            cells.append(cell);
        }
    }
    if not cells {
        way.clear = False;
        return way;
    }
    dx0 = min([cell[0] for cell in cells]);
    dy0 = min([cell[1] for cell in cells]);
    dz0 = min([cell[2] for cell in cells]);
    dx1 = max([cell[0] for cell in cells]) + 1;
    dy1 = max([cell[1] for cell in cells]) + 1;
    dz1 = max([cell[2] for cell in cells]) + 1;
    way.floor = dz0;
    way.top = dz1;
    # Which side of the doors the region is on: the passage leaves the
    # other way.
    if dx1 - dx0 <= dy1 - dy0 {
        below = 0;
        above = 0;
        for y in range(dy0, dy1) {
            for z in range(dz0, dz1) {
                if plan.inside(dx0 - 1, y, z) and plan.regions[plan.index(dx0 - 1, y, z)] == region {
                    below += 1;
                }
                if plan.inside(dx1, y, z) and plan.regions[plan.index(dx1, y, z)] == region {
                    above += 1;
                }
            }
        }
        way.face = 0 if below >= above else 2;
        way.a0 = dy0;
        way.a1 = dy1;
    } else {
        below = 0;
        above = 0;
        for x in range(dx0, dx1) {
            for z in range(dz0, dz1) {
                if plan.inside(x, dy0 - 1, z) and plan.regions[plan.index(x, dy0 - 1, z)] == region {
                    below += 1;
                }
                if plan.inside(x, dy1, z) and plan.regions[plan.index(x, dy1, z)] == region {
                    above += 1;
                }
            }
        }
        way.face = 1 if below >= above else 3;
        way.a0 = dx0;
        way.a1 = dx1;
    }
    # The passage's cells are the doorway's; it leaves from the doors'
    # outer face, which must not lie beside the region's own air (a wall's
    # cell apart).
    for cell in cells {
        way.path.append(cell);
    }
    beyond_x = [dx0, dx1];
    beyond_y = [dy0, dy1];
    if way.face == 0 {
        way.out_x = float(dx1);
        way.out_y = float(dy0 + dy1) * 0.5;
        beyond_x = [dx1, dx1 + 1];
    } elif way.face == 2 {
        way.out_x = float(dx0);
        way.out_y = float(dy0 + dy1) * 0.5;
        beyond_x = [dx0 - 1, dx0];
    } elif way.face == 1 {
        way.out_x = float(dx0 + dx1) * 0.5;
        way.out_y = float(dy1);
        beyond_y = [dy1, dy1 + 1];
    } else {
        way.out_x = float(dx0 + dx1) * 0.5;
        way.out_y = float(dy0);
        beyond_y = [dy0 - 1, dy0];
    }
    for z in range(dz0, dz1) {
        for y in range(beyond_y[0], beyond_y[1]) {
            for x in range(beyond_x[0], beyond_x[1]) {
                if plan.inside(x, y, z) and plan.regions[plan.index(x, y, z)] == region {
                    way.clear = False;
                }
            }
        }
    }
    # What its door wanted, and whether the region gives it.
    fields = plan.things[doors[0]].fields;
    key = derived_key(fields);
    name = fields.get("targetname", "");
    if key {
        way.gate = key;
        way.owned = key in piece.keys;
    } elif name {
        openers = derived_openers(plan, name);
        way.gate = name;
        way.owned = len(openers) > 0 and len([number for number in openers if plan.things[number].region != region]) == 0;
    }
    return way;
}

"""The doors (by model) whose openers no place reaches in the original:
freed wherever they are raised again."""
def derived_stuck(atlas: LevelGraph) -> set[int] {
    found: set[int] = set();
    for gate in graph_gates(atlas) {
        token = "open:" + str(gate.model);
        openers = [opener for opener in graph_openers(atlas) if opener.token == token];
        if openers and len([opener for opener in openers if opener_places(opener)]) == 0 {
            found.add(gate.model);
        }
    }
    return found;
}

"""Group a piece's places by what a body walks between without leaving it:
moves through a doorway it was cut at lead out; a gate in it bars the way
unless it is freed or what opens it is done from the piece's own places.
Its doorways learn the groups they open on, and the piece its start's and
its way out's."""
def derived_groups(plan: Blueprint, piece: Piece) {
    atlas = plan.atlas;
    if atlas is None {
        return;
    }
    cut = plan.cuts;
    mine: dict[int, Place] = {};
    for place in graph_places(atlas) {
        if plan.region_at(Vec3(x=place.center.x, y=place.center.y, z=place.floor + 8.0)) == piece.region {
            mine[place.area] = place;
        }
    }
    opened: set[int] = set(piece.freed);
    # What nothing in it fires is freed when it is raised (`put_thing`).
    live = derived_live_names(plan, blueprint_regions(plan)[piece.region].things);
    for thing in plan.things {
        model = thing.fields.get("model", "");
        name = thing.fields.get("targetname", "");
        if thing.brush and model.startswith("*") and model[1:].isdigit() and name and name not in live {
            opened.add(int(model[1:]));
        }
    }
    for gate in graph_gates(atlas) {
        token = "open:" + str(gate.model);
        for opener in graph_openers(atlas) {
            if opener.token == token and len([place for place in opener_places(opener) if place.area in mine]) > 0 {
                opened.add(gate.model);
            }
        }
    }
    # The moves a body takes inside the piece, one way each.
    onward: dict[int, list[int]] = {};
    for place in mine.values() {
        found: list[int] = [];
        for move in [edge place->:Move:->] {
            if move.to not in mine or move.gate in cut {
                continue;
            }
            if move.gate != 0 and move.gate not in opened {
                continue;
            }
            found.append(move.to);
        }
        onward[place.area] = found;
    }
    # The places within two cells of each doorway.
    near: list[list[int]] = [];
    for way in piece.doorways {
        areas: list[int] = [];
        for number in way.doors {
            door = plan.things[number];
            for place in mine.values() {
                close = place.box.maxs.x >= door.low.x - 64.0 and place.box.mins.x <= door.high.x + 64.0
                    and place.box.maxs.y >= door.low.y - 64.0 and place.box.mins.y <= door.high.y + 64.0
                    and place.floor >= door.low.z - 64.0 and place.floor <= door.high.z + 32.0;
                if close and place.area not in areas {
                    areas.append(place.area);
                }
            }
        }
        near.append(areas);
    }
    for (number, way) in enumerate(piece.doorways) {
        seen = derived_flood(onward, near[number]);
        way.reach = [other for other in range(len(near)) if len([area for area in near[other] if area in seen]) > 0];
        way.reaches_exit = len([area for area in seen.keys() if mine[area].way_out]) > 0;
    }
    starts = [place.area for place in mine.values() if place.start];
    if starts {
        seen = derived_flood(onward, starts);
        piece.start_reach = [other for other in range(len(near)) if len([area for area in near[other] if area in seen]) > 0];
    }
}

"""The places reached from `starts` by `onward` moves."""
def derived_flood(onward: dict[int, list[int]], starts: list[int]) -> dict[int, bool] {
    seen: dict[int, bool] = {};
    todo: list[int] = [];
    for area in starts {
        if area in onward and area not in seen {
            seen[area] = True;
            todo.append(area);
        }
    }
    while todo {
        area = todo.pop();
        for other in onward.get(area, []) {
            if other not in seen {
                seen[other] = True;
                todo.append(other);
            }
        }
    }
    return seen;
}

"""The pieces of a blueprint: each region with a doorway, made ready."""
def derived_pieces(plan: Blueprint) -> list[Piece] {
    found: list[Piece] = [];
    district = derived_district(plan.spec);
    for region in blueprint_regions(plan) {
        cuts: list[list[int]] = [];
        for cut in [edge region->:Cut:->] {
            cuts.append(cut.doors);
        }
        for cut in [edge region<-:Cut:<-] {
            cuts.append(cut.doors);
        }
        if not cuts {
            continue;
        }
        piece = Piece(plan=plan, region=region.number, start=region.start, way_out=region.way_out, district=district);
        piece.x0 = region.x0;
        piece.y0 = region.y0;
        piece.z0 = region.z0;
        piece.x1 = region.x1;
        piece.y1 = region.y1;
        piece.z1 = region.z1;
        for doors in cuts {
            for number in doors {
                for cell in bp_thing_cells(plan, plan.things[number]) {
                    piece.x0 = min(piece.x0, cell[0]);
                    piece.y0 = min(piece.y0, cell[1]);
                    piece.z0 = min(piece.z0, cell[2]);
                    piece.x1 = max(piece.x1, cell[0] + 1);
                    piece.y1 = max(piece.y1, cell[1] + 1);
                    piece.z1 = max(piece.z1, cell[2] + 1);
                }
            }
        }
        piece.x0 -= 1;
        piece.y0 -= 1;
        piece.z0 -= 1;
        piece.x1 += 1;
        piece.y1 += 1;
        piece.z1 += 1;
        for number in region.things {
            kind = plan.things[number].classname;
            if kind == "item_key1" and "key_silver" not in piece.keys {
                piece.keys.append("key_silver");
            } elif kind == "item_key2" and "key_gold" not in piece.keys {
                piece.keys.append("key_gold");
            }
        }
        for doors in cuts {
            piece.doorways.append(derived_doorway(plan, region.number, doors, piece));
        }
        atlas = plan.atlas;
        if atlas is not None {
            piece.freed = derived_stuck(atlas);
        }
        derived_groups(plan, piece);
        for z in range(piece.z0, piece.z1) {
            for y in range(piece.y0, piece.y1) {
                for x in range(piece.x0, piece.x1) {
                    if plan.inside(x, y, z) and plan.regions[plan.index(x, y, z)] == region.number {
                        piece.cells.append([x - piece.x0, y - piece.y0, z - piece.z0]);
                    }
                }
            }
        }
        piece.title = plan.spec.split(":")[1] + "/" + str(region.number) + (" start" if piece.start else "") + (" way out" if piece.way_out else "");
        found.append(piece);
    }
    return found;
}

"""The pieces of several originals (`game:map` each)."""
def derived_library(specs: list[str], notes: list[str]) -> list[Piece] {
    found: list[Piece] = [];
    for spec in specs {
        plan = read_blueprint(spec);
        pieces = derived_pieces(plan);
        for piece in pieces {
            ways = ", ".join([("clear " if way.clear else "shut ") + (way.gate if way.gate else "plain") + (" own" if way.owned else "") + " face " + str(way.face) + " span " + str(way.a0) + ".." + str(way.a1) + " lifts " + str(way.floor) + ".." + str(way.top) + " out " + str(way.out_x) + "," + str(way.out_y) for way in piece.doorways]);
            roles = ("begins " if piece.can_begin() else "") + ("joins " if piece.can_join() else "") + ("ends " if piece.can_end() else "");
            reach = " ".join([str(way.reach) + ("+exit" if way.reaches_exit else "") for way in piece.doorways]);
            notes.append("piece " + piece.title + ": " + str(piece.x1 - piece.x0) + "x" + str(piece.y1 - piece.y0) + "x" + str(piece.z1 - piece.z0) + " cells, " + (roles if roles else "unused ") + "start reaches " + str(piece.start_reach) + ", doorways reach " + reach + ", doorways " + ways);
        }
        found.extend(pieces);
    }
    return found;
}

"""The targetnames something in a stretch still fires (`things` its
entities' indices), each with how many of its things fire it: what its
buttons, triggers, monsters and pickups fire, and on through its own
relays and counters once those are fired."""
def derived_live_names(plan: Blueprint, things: list[int]) -> dict[str, int] {
    live: dict[str, int] = {};
    relays: list[Thing] = [];
    for number in things {
        thing = plan.things[number];
        if thing.classname in ["trigger_relay", "trigger_counter"] {
            relays.append(thing);
            continue;
        }
        for key in ["target", "killtarget"] {
            name = thing.fields.get(key, "");
            if name {
                live[name] = live.get(name, 0) + 1;
            }
        }
    }
    changed = True;
    while changed {
        changed = False;
        for relay in relays {
            name = relay.fields.get("targetname", "");
            target = relay.fields.get("target", "");
            if name in live and target and target not in live {
                live[target] = 1;
                changed = True;
            }
        }
    }
    return live;
}

"""A stretch of an original, raised again as it was."""
node Derived(Prefab) {
    has piece: Piece | None = None,
        role: str = "middle";

    can choose with Lay entry {
        piece = self.piece;
        if piece is None {
            return;
        }
        dice = visitor.dice_for(self);
        self.title = piece.title;
        self.source = piece.plan.spec;
        self.district = piece.district;
        self.long = piece.x1 - piece.x0;
        self.wide = piece.y1 - piece.y0;
        self.low = 0;
        self.high = piece.z1 - piece.z0;
        self.cells = piece.cells;
        ins: list[Port] = [];
        outs: list[Port] = [];
        for (number, way) in enumerate(piece.doorways) {
            if not way.clear {
                continue;
            }
            offset = piece.y0 if way.face % 2 == 0 else piece.x0;
            along = float(way.a0 + way.a1) * 0.5 - float(offset);
            point = [way.out_x - float(piece.x0), way.out_y - float(piece.y0)];
            # Any doorway is a way in: one its own gate shut becomes its
            # entrance (its puzzle a side to it), as the proof allows.
            if self.role != "end" or way.reaches_exit {
                ins.append(Port(face=way.face, along=along, floor=way.floor - piece.z0, wide=way.a1 - way.a0, high=way.top - way.floor, number=number, point=point, groups=way.reach));
            }
            gate = "";
            if way.owned {
                gate = way.gate if way.gate.startswith("key_") else "pf" + str(self.number) + "_" + way.gate;
            }
            if self.role != "start" or number in piece.start_reach {
                outs.append(Port(face=way.face, along=along, floor=way.floor - piece.z0, wide=way.a1 - way.a0, high=way.top - way.floor, gate=gate, number=number, point=point, groups=way.reach));
            }
        }
        if self.role != "start" and ins {
            self.enter = ins[dice.below(len(ins))];
            # Laid by whichever way in fits (`Lay`); the rest are ways out.
            self.ways_in = ins;
            self.ways = [] if self.role == "end" else outs;
        } else {
            self.enter = Port(number=-1);
        }
        self.leaves = [] if self.role == "end" else [port for port in outs if port.number != self.enter.number];
        visitor.place(self);
    }

    can rise with Raise entry {
        piece = self.piece;
        if piece is None {
            return;
        }
        build = visitor.build;
        build.begin(self);
        plan = piece.plan;
        space = build.space(0, 0, 0, self.long, self.wide, self.high, piece.district);
        for z in range(piece.z0, piece.z1) {
            for y in range(piece.y0, piece.y1) {
                for x in range(piece.x0, piece.x1) {
                    if not plan.inside(x, y, z) {
                        continue;
                    }
                    index = plan.index(x, y, z);
                    if plan.regions[index] != piece.region {
                        continue;
                    }
                    lx = x - piece.x0;
                    ly = y - piece.y0;
                    lz = z - piece.z0;
                    build.widen(space, lx, ly, lz, lx + 1, ly + 1, lz + 1);
                    code = plan.codes[index];
                    if code == BP_WATER or code == BP_SLIME or code == BP_LAVA {
                        build.liquid(lx, ly, lz, code);
                    }
                }
            }
        }
        # The passages through the doorways used, out to the box's face.
        used: list[int] = [];
        if self.enter.number >= 0 {
            used.append(self.enter.number);
        }
        for port in self.taken {
            used.append(port.number);
        }
        for number in used {
            for cell in piece.doorways[number].path {
                lx = cell[0] - piece.x0;
                ly = cell[1] - piece.y0;
                lz = cell[2] - piece.z0;
                build.widen(space, lx, ly, lz, lx + 1, ly + 1, lz + 1);
            }
        }
        region = blueprint_regions(plan)[piece.region];
        names: set[str] = set();
        for number in region.things {
            name = plan.things[number].fields.get("targetname", "");
            if name {
                names.add(name);
            }
        }
        live = derived_live_names(plan, region.things);
        for number in region.things {
            self.put_thing(build, plan.things[number], names, live, space);
        }
    }

    """Put one of the original's entities down where it stood in the piece,
    its names its own, its heading turned with the piece."""
    def put_thing(build: Raising, thing: Thing, names: set[str], live: dict[str, int], space: Space) {
        piece = self.piece;
        if piece is None {
            return;
        }
        plan = piece.plan;
        kind = thing.classname;
        kit = kit_of(piece.district);
        ox = float(plan.ox + piece.x0);
        oy = float(plan.oy + piece.y0);
        oz = float(plan.oz + piece.z0);
        px = thing.point.x / CELL - ox;
        py = thing.point.y / CELL - oy;
        pz = thing.point.z / LIFT - oz;
        if kind == "info_player_start" and self.role == "start" {
            angle = thing.fields.get("angle", "0");
            build.start(px, py, int(round(pz - 1.5)), float(angle) if angle.lstrip("-").replace(".", "").isdigit() else 0.0);
            return;
        }
        if kind == "trigger_changelevel" and self.role == "end" {
            build.way_out(px, py, int(round(thing.low.z / LIFT - oz)));
            return;
        }
        if kind in DERIVED_DROPPED {
            return;
        }
        # A teleporter whose destination is in another piece goes nowhere.
        if kind == "trigger_teleport" and thing.fields.get("target", "") not in names {
            return;
        }
        fields = dict(thing.fields);
        fields.pop("model", None);
        fields.pop("origin", None);
        # What only another stretch fired: a door or lift opens to a touch,
        # a bridge drawn out by it is drawn out already, a counter counts
        # what is left of its inputs.
        name = fields.get("targetname", "");
        model = thing.fields.get("model", "");
        freed = model.startswith("*") and model[1:].isdigit() and int(model[1:]) in piece.freed;
        if name and (name not in live or (freed and kind in ["func_door", "func_plat"])) {
            if kind in ["trigger_counter", "trigger_relay"] {
                return;
            }
            fields.pop("targetname", None);
            if kind == "func_door" {
                words = fields.get("spawnflags", "0").split(".");
                flags = int(words[0]) if words[0].isdigit() else 0;
                # A bridge drawn out, or a slab that is a floor until it is
                # fired, stays where it shuts: a wall, there for good. A door
                # across a doorway opens to a touch.
                slab = thing.high.z - thing.low.z < 40.0;
                if flags & 1 or slab {
                    fields = {"classname": "func_wall"};
                    kind = "func_wall";
                } else {
                    fields["spawnflags"] = str(flags);
                }
            }
        } elif kind == "trigger_counter" and name {
            inputs = live.get(name, 0);
            wanted = fields.get("count", "2");
            if wanted.isdigit() and inputs < int(wanted) {
                fields["count"] = str(max(1, inputs));
            }
        }
        for key in ["target", "targetname", "killtarget"] {
            if fields.get(key, "") {
                fields[key] = build.name(fields[key]);
            }
        }
        # A Quake key door (spawnflags 8 gold, 16 silver) says its key as
        # Passion's doors do.
        if kind == "func_door" and derived_key(fields) {
            fields["key"] = derived_key(fields);
        }
        angle = fields.get("angle", "");
        if angle and angle not in ["-1", "-2"] and angle.lstrip("-").replace(".", "").isdigit() {
            fields["angle"] = str(build.heading(float(angle)));
        }
        turned = fields.get("angles", "").split();
        if len(turned) == 3 {
            turned[1] = str(build.heading(float(turned[1])));
            fields["angles"] = " ".join(turned);
        }
        if kind.startswith("monster_") or kind.startswith("item_") or kind.startswith("weapon_") {
            fields["asset_game"] = plan.game;
        }
        if kind.startswith("monster_") {
            build.casting.monsters += 1;
        }
        # At 32 units a cell a wall can stand a cell thicker than the
        # original's: what stands in it gets its cell back (a button a
        # niche, a monster or a pickup the air it stands in).
        if kind == "func_button" {
            x0 = int(math.floor((thing.low.x + 1.0) / CELL - ox));
            y0 = int(math.floor((thing.low.y + 1.0) / CELL - oy));
            z0 = int(math.floor((thing.low.z + 1.0) / LIFT - oz));
            x1 = int(math.ceil((thing.high.x - 1.0) / CELL - ox));
            y1 = int(math.ceil((thing.high.y - 1.0) / CELL - oy));
            z1 = int(math.ceil((thing.high.z - 1.0) / LIFT - oz));
            build.widen(space, x0, y0, z0, x1, y1, z1);
        } elif not thing.brush and (kind.startswith("monster_") or kind.startswith("item_") or kind.startswith("weapon_")) {
            cx = int(math.floor(px));
            cy = int(math.floor(py));
            cz = int(math.floor(pz));
            build.widen(space, cx, cy, cz - 1, cx + 1, cy + 1, cz + 3);
        }
        if not thing.brush {
            at = build.units(px, py, pz);
            fields["origin"] = origin_text(at.x, at.y, at.z);
            build.casting.put(fields);
            return;
        }
        material = kit.wall;
        if kind.startswith("trigger_") {
            material = "trigger";
        } elif kind == "func_button" {
            material = BUTTON_MATERIAL;
        } elif kind in ["func_door", "func_door_secret"] {
            material = kit.door if kind == "func_door" else kit.wall;
            build.casting.doors += 1;
            # Rock round it as far as it is big, for it to open into.
            reach = min(8.0, max(thing.high.x - thing.low.x, thing.high.y - thing.low.y, thing.high.z - thing.low.z) / CELL + 0.5);
            build.rock_round(
                thing.low.x / CELL - ox - reach, thing.low.y / CELL - oy - reach, thing.low.z / LIFT - oz - reach * 2.0,
                thing.high.x / CELL - ox + reach, thing.high.y / CELL - oy + reach, thing.high.z / LIFT - oz + reach * 2.0
            );
        } elif kind in ["func_plat", "func_train"] {
            material = kit.step;
        }
        build.put_box(
            fields,
            thing.low.x / CELL - ox, thing.low.y / CELL - oy, thing.low.z / LIFT - oz,
            thing.high.x / CELL - ox, thing.high.y / CELL - oy, thing.high.z / LIFT - oz,
            material
        );
    }
}
