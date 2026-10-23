"""The level atlas: one atlas of what a level lets a player do, read off
any level the engine loads, original or generated, rich enough to prove
statically that the level can be finished.

Layers, each joined to the next by edges:

- **places**: the navigation's areas (`engine/nav/compile.jac`), joined by
  `Move` edges, each a way a body goes (walked, dropped, jumped, swum,
  lifted, teleported). A move is *must* when it is sure to work (every
  jump is run through the engine's own player movement, `MovePlayer`, to
  see that it lands), or only *may* when it might happen (a jump or a fall
  off any ledge, wherever it lands): ways forward are counted from must
  moves, ways into trouble from may moves;
- **gates**: the movers that bar places until something opens them (a
  key, a button, a trigger, a shot, a death), read from the level's own
  activation atlas by the objectives the player bot plans with
  (`engine/world/objectives.jac`); each opener stands in a place;
- **things**: monsters and supplies in their places, for the budget.

`prove` searches the states a player can be in (a place and the tokens
held: keys taken, gates opened) and answers whether the way out is reached
from the start over must moves, and from every state the may moves lead
into (a softlock is a state, not in a death place, with no way out). The
budget walks the route the proof found and keeps a ledger of health,
armour and ammunition against the monsters met on it."""
import math;
import time;
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from ..formats.aas {
    Aas,
    TRAVEL_WALK,
    TRAVEL_BARRIERJUMP,
    TRAVEL_JUMP,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_SWIM,
    TRAVEL_WATERJUMP,
    TRAVEL_TELEPORT,
    TRAVEL_ELEVATOR,
    AREACONTENTS_LAVA,
    AREACONTENTS_SLIME,
    AREACONTENTS_DONOTENTER,
    AREACONTENTS_MOVER,
    AREACONTENTS_MODELNUMSHIFT,
    AREA_GROUNDED
}
import from ..physics.collision { CollisionMap }
import from ..physics.movement { MovePlayer, MovementProfile }
import from ..world.world { World, Player }
import from ..world.level { Level }
import from ..world.exits { LevelExit, HasExit }
import from ..world.objectives { Objective, mover_objectives, mover_blocked, exit_objectives }
import from ..world.doors { Door, door_parts }
import from ..world.trains { Train, HasTrain }
import from ..world.bot_routes { NavMesh, build_navmesh }
import from .compile { NavBuild, NavSpot, compile_navigation, nav_shut_shift }

"""A place: one of the navigation's areas."""
node Place {
    has area: int,
        center: Vec3 = Vec3(),
        box: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        # Where a body dies (lava, slime, a hurting volume): a fall in is
        # a death, not a softlock.
        deadly: bool = False,
        # The mover whose place it is (a door's doorway), 0 for none.
        mover: int = 0,
        way_out: bool = False,
        start: bool = False;
}

"""A way from one place to another: how it is taken, the lift it rides,
and whether it is sure (must) or only possible (may)."""
edge Move: Place --> Place {
    has kind: int,
        # The area it leads to (the edge's own end, kept so that several
        # moves to one place each keep theirs).
        to: int = 0,
        must: bool = True,
        model: int = 0;
}

"""A mover that bars its places (and a lift its ride) until a token is
held: `open:<model>`, or every key it wants."""
node Gate {
    has model: int,
        kind: str = "door",
        needs: list[str] = [];
}

edge Bars: Gate --> Place {}

"""Something a player does that gives a token: press, touch, shoot, pick
up, kill; done from the places it is `DoneFrom`."""
node Opener {
    has kind: str,
        token: str,
        point: Vec3 = Vec3();
}

edge DoneFrom: Opener --> Place {}

"""A monster or a supply standing in a place."""
node Thing {
    has classname: str,
        point: Vec3 = Vec3(),
        spawnflags: int = 0;
}

edge StandsIn: Thing --> Place {}

"""The atlas's root and what was read."""
node LevelGraph {
    has name: str = "",
        game: str = "q1",
        notes: list[str] = [],
        jumps_tried: int = 0,
        jumps_sure: int = 0,
        falls: int = 0;
}

edge Holds: LevelGraph --> Place {}
edge Guards: LevelGraph --> Gate {}
edge Offers: LevelGraph --> Opener {}
edge Contains: LevelGraph --> Thing {}

"""The places of a atlas, by area."""
def graph_places(atlas: LevelGraph) -> list[Place] {
    return [atlas->:Holds:->][?:Place];
}

"""Run a body through the engine's own player movement: from `origin` (a
standing origin), running along `direction` at full speed, jumping when it
passes `takeoff` (none: never), holding the run until it stands again or
two seconds pass. Answers where it came to stand, or None."""
def run_body(collision: CollisionMap, profile: MovementProfile, origin: Vec3, direction: Vec3, takeoff: Vec3 | None, run_up: float) -> Vec3 | None {
    heading = Vec3(x=direction.x, y=direction.y).normalized();
    body = Player();
    begin = origin.sub(heading.scale(run_up));
    if collision.trace(begin, begin).start_solid {
        begin = origin;
    }
    body.pos = begin.add(Vec3(z=collision.eye_height));
    body.yaw = math.atan2(heading.y, heading.x);
    body.grounded = True;
    left = False;
    jumped = takeoff is None;
    for tick in range(360) {
        place = body.pos.sub(Vec3(z=collision.eye_height));
        jump = False;
        if not jumped and takeoff is not None and place.sub(takeoff).dot(heading) >= 0.0 {
            jump = True;
            jumped = True;
        }
        body spawn MovePlayer(
            collision=collision,
            wish=heading,
            jump=jump,
            command=Vec3(y=1.0),
            command_full=400.0,
            profile=profile,
            dt=1.0 / 120.0
        );
        if not body.grounded {
            left = True;
        }
        if left and body.grounded {
            return body.pos.sub(Vec3(z=collision.eye_height));
        }
        if place.z < origin.z - 1024.0 {
            return None;
        }
    }
    return None;
}

"""Read the level atlas off a level as loaded (its monsters, items and
triggers spawned): its navigation compiled, its jumps run, the falls off
its ledges run, its gates and their openers, its things."""
def read_level_graph(world: World, level: Level, build: NavBuild | None = None, falls: bool = True) -> LevelGraph {
    if build is None {
        build = compile_navigation(world, level);
    }
    aas = build.aas;
    mesh = build_navmesh(world, aas, level.bsp);
    atlas = LevelGraph(name=level.name, game=level.bsp.game);
    atlas.notes.append("navigation " + build.summary());
    places: list[Place] = [Place(area=0)];
    for index in range(1, len(aas.areas)) {
        info = aas.areas[index];
        contents = info.contents;
        place = Place(area=index, center=info.center, box=AABB(mins=info.mins, maxs=info.maxs));
        place.deadly = contents & (AREACONTENTS_LAVA | AREACONTENTS_SLIME | AREACONTENTS_DONOTENTER) != 0;
        if contents & AREACONTENTS_MOVER != 0 {
            place.mover = contents >> AREACONTENTS_MODELNUMSHIFT;
        }
        places.append(place);
        atlas +>:Holds:+> place;
    }
    collision = level.collision;
    profile = level.movement;
    began = time.time();
    # The navigation's ways: sure, but for jumps, which are run first.
    for index in range(1, len(aas.areas)) {
        info = aas.areas[index];
        for r in range(info.first_reach, info.first_reach + info.reach_count) {
            reach = aas.reaches[r];
            if reach.area <= 0 or reach.area >= len(places) {
                continue;
            }
            sure = True;
            if reach.kind == TRAVEL_JUMP {
                atlas.jumps_tried += 1;
                way = reach.finish.sub(reach.start);
                landed = run_body(collision, profile, reach.start, way, reach.start, 96.0);
                sure = False;
                if landed is not None {
                    into = mesh.locate(landed);
                    sure = into == reach.area or landed.sub(reach.finish).length() < 48.0;
                    if not sure and 0 < into < len(aas.areas) {
                        sure = landed_beside(aas, into, reach.area);
                    }
                }
                if sure {
                    atlas.jumps_sure += 1;
                }
            }
            places[index] +>:Move(kind=reach.kind, to=reach.area, must=sure, model=reach.face_num & 65535 if reach.kind == TRAVEL_ELEVATOR else 0):+> places[reach.area];
        }
    }
    atlas.notes.append("jumps run in " + str(round(time.time() - began, 1)) + " s");
    began = time.time();
    # What might happen: off every ledge, a run and a running jump each way
    # it is not walked, wherever they land.
    grid = build.grid;
    if grid is not None and falls {
        tried: dict[tuple[int, int], bool] = {};
        bit = 1;
        for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
            for spot in grid.spots {
                if not spot.ledge or spot.walks & bit != 0 or spot.area <= 0 or (spot.area, bit) in tried or spot.liquid != 0 {
                    continue;
                }
                tried[(spot.area, bit)] = True;
                way = Vec3(x=dx, y=dy);
                for takeoff in [None, spot.origin] {
                    landed = run_body(collision, profile, spot.origin, way, takeoff, 48.0);
                    if landed is None {
                        continue;
                    }
                    into = mesh.locate(landed);
                    if 0 < into < len(places) and into != spot.area {
                        places[spot.area] +>:Move(kind=TRAVEL_WALKOFFLEDGE, to=into, must=False):+> places[into];
                        atlas.falls += 1;
                    }
                }
            }
            bit *= 2;
        }
    }
    atlas.notes.append("falls run in " + str(round(time.time() - began, 1)) + " s");
    began = time.time();
    read_gates(atlas, world, level, mesh, places);
    read_things(atlas, level, mesh, places);
    atlas.notes.append("gates and things read in " + str(round(time.time() - began, 1)) + " s");
    atlas.notes.append(
        "places " + str(len(places) - 1) + " jumps sure " + str(atlas.jumps_sure) + "/" + str(atlas.jumps_tried) + " falls " + str(atlas.falls)
    );
    return atlas;
}

"""Whether area `into` walks straight into area `target`: a jump that lands
beside where it was aimed still gets there."""
def landed_beside(aas: Aas, into: int, target: int) -> bool {
    info = aas.areas[into];
    for r in range(info.first_reach, info.first_reach + info.reach_count) {
        reach = aas.reaches[r];
        if reach.area == target and reach.kind in [TRAVEL_WALK, TRAVEL_SWIM] {
            return True;
        }
    }
    return False;
}

"""The places an opener is done from: the place its point is in, and for a
shot or a kill every place that sees its point within 1024 units."""
def opener_places(objective: Objective, collision: CollisionMap, mesh: NavMesh, places: list[Place]) -> list[Place] {
    found: list[Place] = [];
    stand = mesh.locate(objective.point);
    if 0 < stand < len(places) {
        found.append(places[stand]);
    }
    box = objective.box;
    if box is not None {
        for place in places[1:] {
            meets = place.box.mins.x <= box.maxs.x and box.mins.x <= place.box.maxs.x and place.box.mins.y <= box.maxs.y
                and box.mins.y <= place.box.maxs.y and place.box.mins.z <= box.maxs.z and box.mins.z <= place.box.maxs.z;
            if meets and place not in found {
                found.append(place);
            }
        }
    }
    if objective.kind in ["shoot", "kill"] {
        aim = objective.aim if objective.kind == "shoot" else objective.point;
        for place in places[1:] {
            eye = place.center.add(Vec3(z=collision.eye_height));
            if eye.sub(aim).length() > 1024.0 or place in found {
                continue;
            }
            seen = collision.trace(eye, aim, [], -1.0, True);
            if seen.fraction >= 0.99 {
                found.append(place);
            }
        }
    }
    return found;
}

"""Where a mover stands shut (a door) or at rest (a secret door), as the
navigation compiler poses it; None when it is not known."""
def shut_box(world: World, level: Level, model: int) -> AABB | None {
    for door in door_parts(world) {
        if door.model == model and door.origins {
            record = level.bsp.models[model];
            shift = door.origins[0].add(nav_shut_shift(door));
            return AABB(mins=record.mins.add(shift), maxs=record.maxs.add(shift));
        }
    }
    for train in [world->:HasTrain:->][?:Train] {
        if train.model == model {
            return train.bounds;
        }
    }
    return None;
}

"""Whether a body standing anywhere in a place would be inside a box: what
a shut door bars. A body standing on the box (a lowered bridge or a lift
door shut under it) is not inside it."""
def body_inside(place: Place, box: AABB) -> bool {
    low_z = place.box.mins.z + 4.0 - 24.0;
    high_z = place.box.maxs.z - 8.0 + 32.0;
    return place.box.mins.x - 16.0 < box.maxs.x - 1.0 and box.mins.x + 1.0 < place.box.maxs.x + 16.0
        and place.box.mins.y - 16.0 < box.maxs.y - 1.0 and box.mins.y + 1.0 < place.box.maxs.y + 16.0
        and low_z < box.maxs.z - 1.0 and box.mins.z + 1.0 < high_z;
}

"""Gates and openers: every mover that bars a player who holds nothing
(locked, opened from elsewhere, shot open, a lift held up), what opens it,
and where that is done; the way out, and what fires it when it is not
touched."""
def read_gates(atlas: LevelGraph, world: World, level: Level, mesh: NavMesh, places: list[Place]) {
    nobody = Player();
    models: list[int] = [];
    for place in places[1:] {
        if place.mover > 0 and place.mover not in models {
            models.append(place.mover);
        }
        for move in [edge place->:Move:->] {
            if move.model > 0 and move.model not in models {
                models.append(move.model);
            }
        }
    }
    for model in models {
        if not mover_blocked(world, model, nobody) {
            continue;
        }
        token = "open:" + str(model);
        gate = Gate(model=model, needs=[token]);
        atlas +>:Guards:+> gate;
        shut = shut_box(world, level, model);
        for place in places[1:] {
            if place.mover == model and (shut is None or body_inside(place, shut)) {
                gate +>:Bars:+> place;
            }
        }
        for objective in mover_objectives(world, model, nobody) {
            if objective.kind == "pickup" and objective.item is not None {
                key = objective.item.rule.kind;
                if key not in gate.needs {
                    gate.needs = [need for need in gate.needs if need != token] + [key];
                }
                opener = Opener(kind="pickup", token=key, point=objective.point);
            } else {
                opener = Opener(kind=objective.kind, token=token, point=objective.point);
            }
            atlas +>:Offers:+> opener;
            for place in opener_places(objective, level.collision, mesh, places) {
                opener +>:DoneFrom:+> place;
            }
        }
    }
    for portal in [world->:HasExit:->][?:LevelExit] {
        if not portal.volume.bounds {
            continue;
        }
        box = portal.volume.bounds[0];
        middle = box.mins.add(box.maxs).scale(0.5);
        for place in places[1:] {
            inside = place.box.mins.x <= box.maxs.x and box.mins.x <= place.box.maxs.x and place.box.mins.y <= box.maxs.y
                and box.mins.y <= place.box.maxs.y and place.box.mins.z <= box.maxs.z and box.mins.z <= place.box.maxs.z + 32.0;
            if inside {
                place.way_out = True;
            }
        }
        found = mesh.locate(middle);
        if 0 < found < len(places) {
            places[found].way_out = True;
        }
        if not portal.contact {
            for objective in exit_objectives(world, portal) {
                opener = Opener(kind=objective.kind, token="exit", point=objective.point);
                atlas +>:Offers:+> opener;
                for place in opener_places(objective, level.collision, mesh, places) {
                    opener +>:DoneFrom:+> place;
                }
            }
        }
    }
}

"""Monsters and supplies, each in the place it stands in; and the start."""
def read_things(atlas: LevelGraph, level: Level, mesh: NavMesh, places: list[Place]) {
    for entity in level.bsp.entities {
        name = entity.fields.get("classname", "");
        parts = entity.fields.get("origin", "").split();
        if len(parts) != 3 {
            continue;
        }
        point = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
        if name == "info_player_start" {
            found = mesh.locate(point);
            if 0 < found < len(places) {
                places[found].start = True;
            }
            continue;
        }
        if not (name.startswith("monster_") or name.startswith("item_") or name.startswith("weapon_")) {
            continue;
        }
        thing = Thing(classname=name, point=point, spawnflags=int(float(entity.fields.get("spawnflags", "0") or "0")));
        atlas +>:Contains:+> thing;
        found = mesh.locate(point);
        if 0 < found < len(places) {
            thing +>:StandsIn:+> places[found];
        }
    }
}

"""What the proof found."""
obj Proof {
    has finishes: bool = False,
        # States reached over may moves, and those with no sure way out.
        states: int = 0,
        softlocks: int = 0,
        # A few softlocked places, as [area, tokens held].
        traps: list[str] = [],
        tokens: list[str] = [],
        # Ways the search found barred (a few), as lines.
        barred: list[str] = [],
        # The sure route from the start to the way out: areas in order.
        route: list[int] = [],
        notes: list[str] = [];
}

"""Prove a level atlas: the way out reached from the start over sure
moves, collecting tokens; and from every state the possible moves lead
into, the way out still reached over sure moves (a death place is no
softlock: the level begins again). Tokens are taken where their openers
are done; a gate's places are entered only with all it needs, a lift ridden
only once it is opened."""
def prove(atlas: LevelGraph, leave_out: list[str] = []) -> Proof {
    proof = Proof();
    places = graph_places(atlas);
    count = max([place.area for place in places] + [0]) + 1;
    by_area: list[Place | None] = [None for _ in range(count)];
    for place in places {
        by_area[place.area] = place;
    }
    tokens: list[str] = [];
    for opener in [atlas->:Offers:->][?:Opener] {
        if opener.token not in tokens {
            tokens.append(opener.token);
        }
    }
    for gate in [atlas->:Guards:->][?:Gate] {
        for need in gate.needs {
            if need not in tokens {
                tokens.append(need);
            }
        }
    }
    proof.tokens = tokens;
    # What each place gives, needs, and is.
    gives = [0 for _ in range(count)];
    needs = [0 for _ in range(count)];
    lift_needs: dict[int, int] = {};
    for opener in [atlas->:Offers:->][?:Opener] {
        if opener.kind + ":" + opener.token in leave_out or opener.token in leave_out {
            continue;
        }
        bit = 1 << tokens.index(opener.token);
        for place in [opener->:DoneFrom:->][?:Place] {
            gives[place.area] |= bit;
        }
    }
    for gate in [atlas->:Guards:->][?:Gate] {
        mask = 0;
        for need in gate.needs {
            mask |= 1 << tokens.index(need);
        }
        lift_needs[gate.model] = mask;
        for place in [gate->:Bars:->][?:Place] {
            needs[place.area] |= mask;
        }
    }
    exit_bit = (1 << tokens.index("exit")) if "exit" in tokens else 0;
    sure: list[list[list[int]]] = [[] for _ in range(count)];
    maybe: list[list[list[int]]] = [[] for _ in range(count)];
    for place in places {
        for move in [edge place->:Move:->] {
            if move.to <= 0 or move.to >= count {
                continue;
            }
            gate_mask = lift_needs.get(move.model, 0) if move.kind == TRAVEL_ELEVATOR else 0;
            step = [move.to, gate_mask | needs[move.to]];
            maybe[place.area].append(step);
            if move.must {
                sure[place.area].append(step);
            }
        }
    }
    starts = [place.area for place in places if place.start];
    exits = [place.area for place in places if place.way_out];
    if not starts or not exits {
        proof.notes.append("no start" if not starts else "no way out");
        return proof;
    }
    start = starts[0];
    # Every state the possible moves reach.
    first = start * (1 << len(tokens)) + gives[start];
    seen: dict[int, bool] = {first: True};
    todo = [first];
    span = 1 << len(tokens);
    while todo {
        state = todo.pop();
        area = state // span;
        held = state % span;
        for step in maybe[area] {
            if step[1] & held != step[1] {
                if len(proof.barred) < 12 {
                    wanted = ", ".join([tokens[index] for index in range(len(tokens)) if step[1] & ~held & (1 << index)]);
                    line = str(area) + " -> " + str(step[0]) + " wants " + wanted;
                    if line not in proof.barred {
                        proof.barred.append(line);
                    }
                }
                continue;
            }
            after = step[0] * span + (held | gives[step[0]]);
            if after not in seen {
                seen[after] = True;
                todo.append(after);
            }
        }
    }
    proof.states = len(seen);
    # Good states: the way out reached over sure moves. Larger holdings
    # first, since tokens only grow.
    masks: list[int] = [];
    for state in seen.keys() {
        held = state % span;
        if held in masks {
            continue;
        }
        at = len(masks);
        while at > 0 and bits_of(masks[at - 1]) < bits_of(held) {
            at -= 1;
        }
        masks.insert(at, held);
    }
    good: dict[int, bool] = {};
    for held in masks {
        # Seeds: the way out (with what fires it, when it is fired), and
        # places a sure move leaves for a good state holding more.
        frontier: list[int] = [];
        for area in range(count) {
            if by_area[area] is None {
                continue;
            }
            if area in exits and (exit_bit == 0 or held & exit_bit != 0) {
                frontier.append(area);
                continue;
            }
            for step in sure[area] {
                gained = held | gives[step[0]];
                if step[1] & held == step[1] and gained != held and (step[0] * span + gained) in good {
                    frontier.append(area);
                    break;
                }
            }
        }
        reached: dict[int, bool] = {};
        for area in frontier {
            reached[area] = True;
        }
        # Backwards over sure moves taken with these tokens and gaining none.
        backward: list[list[int]] = [[] for _ in range(count)];
        for area in range(count) {
            for step in sure[area] {
                if step[1] & held == step[1] and gives[step[0]] | held == held {
                    backward[step[0]].append(area);
                }
            }
        }
        while frontier {
            area = frontier.pop();
            for before in backward[area] {
                if before not in reached {
                    reached[before] = True;
                    frontier.append(before);
                }
            }
        }
        for area in reached.keys() {
            good[area * span + held] = True;
        }
    }
    proof.finishes = first in good;
    for state in seen.keys() {
        area = state // span;
        place = by_area[area];
        if state in good or place is None or place.deadly {
            continue;
        }
        proof.softlocks += 1;
        if len(proof.traps) < 6 {
            held = state % span;
            proof.traps.append(
                str(area) + " at " + str(int(place.center.x)) + "," + str(int(place.center.y)) + "," + str(int(place.center.z)) + " holding ["
                    + ", ".join([tokens[index] for index in range(len(tokens)) if held & (1 << index)]) + "]"
            );
        }
    }
    if proof.finishes {
        proof.route = sure_route(sure, gives, start, first % span, span, exits, exit_bit);
    }
    return proof;
}

"""How many tokens a holding has."""
def bits_of(mask: int) -> int {
    count = 0;
    while mask > 0 {
        count += mask & 1;
        mask = mask >> 1;
    }
    return count;
}

"""The shortest sure route from the start to the way out, tokens gathered
on the way (breadth first over states): the areas in order."""
def sure_route(sure: list[list[list[int]]], gives: list[int], start: int, held: int, span: int, exits: list[int], exit_bit: int) -> list[int] {
    first = start * span + held;
    came: dict[int, int] = {first: -1};
    todo = [first];
    at = 0;
    goal = -1;
    while at < len(todo) and goal < 0 {
        state = todo[at];
        at += 1;
        area = state // span;
        mask = state % span;
        if area in exits and (exit_bit == 0 or mask & exit_bit != 0) {
            goal = state;
            break;
        }
        for step in sure[area] {
            if step[1] & mask != step[1] {
                continue;
            }
            after = step[0] * span + (mask | gives[step[0]]);
            if after not in came {
                came[after] = state;
                todo.append(after);
            }
        }
    }
    route: list[int] = [];
    while goal >= 0 {
        route.insert(0, goal // span);
        goal = came[goal];
    }
    return route;
}

"""A monster's health and the damage a second it deals a player it is
fighting (Quake's; others by their game's nearest kin)."""
glob BUDGET_MONSTERS: dict[str, list[float]] = {
         "monster_army": [30.0, 6.0],
         "monster_dog": [25.0, 8.0],
         "monster_knight": [75.0, 8.0],
         "monster_enforcer": [80.0, 8.0],
         "monster_wizard": [80.0, 6.0],
         "monster_zombie": [60.0, 5.0],
         "monster_fish": [25.0, 6.0],
         "monster_ogre": [200.0, 14.0],
         "monster_demon1": [300.0, 20.0],
         "monster_hell_knight": [250.0, 14.0],
         "monster_shalrath": [400.0, 12.0],
         "monster_tarbaby": [80.0, 10.0],
         "monster_shambler": [600.0, 30.0]
     };

"""A weapon for the budget: the ammunition it spends, the damage a unit of
it does, the damage a second it deals."""
obj Arm {
    has ammo: str = "",
        per: float = 0.0,
        rate: float = 0.0;
}

"""Quake's weapons, the axe first."""
glob BUDGET_WEAPONS: dict[str, Arm] = {
         "axe": Arm(rate=40.0),
         "shotgun": Arm(ammo="shells", per=24.0, rate=48.0),
         "weapon_supershotgun": Arm(ammo="shells", per=28.0, rate=80.0),
         "weapon_nailgun": Arm(ammo="nails", per=9.0, rate=90.0),
         "weapon_supernailgun": Arm(ammo="nails", per=9.0, rate=180.0),
         "weapon_grenadelauncher": Arm(ammo="rockets", per=100.0, rate=160.0),
         "weapon_rocketlauncher": Arm(ammo="rockets", per=100.0, rate=125.0),
         "weapon_lightning": Arm(ammo="cells", per=30.0, rate=300.0)
     };

"""What a supply gives, as [kind, amount] pairs: health, armour (as
`armor:<ratio>`), ammunition, or a weapon (`weapon:<classname>`, amount 1)."""
def budget_supply(name: str, spawnflags: int) -> list[tuple[str, float]] {
    big = spawnflags & 1 != 0;
    if name == "item_health" {
        return [("health", 15.0 if spawnflags & 1 else (100.0 if spawnflags & 2 else 25.0))];
    }
    if name == "item_armor1" {
        return [("armor:0.3", 100.0)];
    }
    if name == "item_armor2" {
        return [("armor:0.6", 150.0)];
    }
    if name == "item_armorInv" {
        return [("armor:0.8", 200.0)];
    }
    if name == "item_shells" {
        return [("shells", 40.0 if big else 20.0)];
    }
    if name == "item_spikes" {
        return [("nails", 50.0 if big else 25.0)];
    }
    if name == "item_rockets" {
        return [("rockets", 10.0 if big else 5.0)];
    }
    if name == "item_cells" {
        return [("cells", 12.0 if big else 6.0)];
    }
    if name == "weapon_supershotgun" {
        return [("weapon:" + name, 1.0), ("shells", 5.0)];
    }
    if name in ["weapon_nailgun", "weapon_supernailgun"] {
        return [("weapon:" + name, 1.0), ("nails", 30.0)];
    }
    if name in ["weapon_grenadelauncher", "weapon_rocketlauncher"] {
        return [("weapon:" + name, 1.0), ("rockets", 5.0)];
    }
    if name == "weapon_lightning" {
        return [("weapon:" + name, 1.0), ("cells", 15.0)];
    }
    return [];
}

"""The budget along a route: the ledger of what the player holds."""
obj Budget {
    has health: float = 100.0,
        armor: float = 0.0,
        ratio: float = 0.0,
        ammo: dict[str, float] = {"shells": 25.0, "nails": 0.0, "rockets": 0.0, "cells": 0.0},
        weapons: list[str] = ["axe", "shotgun"],
        lowest: float = 100.0,
        fights: int = 0,
        axed: int = 0,
        # The fight the ledger fell lowest after, and a line per event.
        worst: str = "",
        lines: list[str] = [];
}

"""Walk the sure route and keep the ledger: supplies in the places it
passes taken, each monster fought when the route first comes where it
stands or sees it within 640 units. A fight is won with the best weapon
that has ammunition (the axe at worst): it costs the monster's health in
ammunition, and its damage a second for as long as killing it takes
(twice that with the axe), armour taking its share."""
def budget(atlas: LevelGraph, route: list[int], collision: CollisionMap) -> Budget {
    ledger = Budget();
    places = graph_places(atlas);
    by_area: dict[int, Place] = {};
    for place in places {
        by_area[place.area] = place;
    }
    taken: list[Thing] = [];
    for area in route {
        place = by_area.get(area, None);
        if place is None {
            continue;
        }
        eye = place.center.add(Vec3(z=collision.eye_height));
        for thing in [atlas->:Contains:->][?:Thing] {
            if thing in taken {
                continue;
            }
            stands = [placed.area for placed in [thing->:StandsIn:->][?:Place]];
            if thing.classname.startswith("monster_") {
                near = area in stands;
                if not near and eye.sub(thing.point).length() < 640.0 {
                    near = collision.trace(eye, thing.point, [], -1.0, True).fraction >= 0.99;
                }
                if not near {
                    continue;
                }
                taken.append(thing);
                fight(ledger, thing.classname);
            } elif area in stands {
                taken.append(thing);
                for (kind, amount) in budget_supply(thing.classname, thing.spawnflags) {
                    if kind == "health" {
                        cap = 250.0 if amount >= 100.0 else 100.0;
                        if ledger.health < cap {
                            ledger.health = min(cap, ledger.health + amount);
                        }
                    } elif kind.startswith("armor:") {
                        ratio = float(kind[6:]);
                        if amount * ratio > ledger.armor * ledger.ratio {
                            ledger.armor = amount;
                            ledger.ratio = ratio;
                        }
                    } elif kind.startswith("weapon:") {
                        if kind[7:] not in ledger.weapons {
                            ledger.weapons.append(kind[7:]);
                        }
                    } else {
                        ledger.ammo[kind] = ledger.ammo.get(kind, 0.0) + amount;
                    }
                }
                ledger.lines.append("take " + thing.classname + " health " + str(int(ledger.health)) + " armor " + str(int(ledger.armor)));
            }
        }
    }
    return ledger;
}

"""One fight in the ledger."""
def fight(ledger: Budget, name: str) {
    stats = BUDGET_MONSTERS.get(name, [100.0, 10.0]);
    hp = stats[0];
    best = "axe";
    for weapon in ledger.weapons {
        arm = BUDGET_WEAPONS.get(weapon, Arm());
        if arm.ammo and ledger.ammo.get(arm.ammo, 0.0) * arm.per >= hp and arm.rate > BUDGET_WEAPONS[best].rate {
            best = weapon;
        }
    }
    arm = BUDGET_WEAPONS[best];
    seconds = hp / arm.rate;
    damage = stats[1] * seconds * (2.0 if best == "axe" else 1.0);
    if best == "axe" {
        ledger.axed += 1;
    } else {
        ledger.ammo[arm.ammo] = ledger.ammo[arm.ammo] - hp / arm.per;
    }
    saved = min(ledger.armor, damage * ledger.ratio);
    ledger.armor -= saved;
    ledger.health -= damage - saved;
    ledger.fights += 1;
    if ledger.health < ledger.lowest {
        ledger.lowest = ledger.health;
        ledger.worst = name;
    }
    ledger.lines.append(
        "fight " + name + " with " + best + " health " + str(int(ledger.health)) + " armor " + str(int(ledger.armor)) + " shells "
            + str(int(ledger.ammo.get("shells", 0.0)))
    );
}
