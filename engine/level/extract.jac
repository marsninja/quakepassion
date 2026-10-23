"""Reading a level graph off a loaded level: its navigation compiled
(`engine/nav/compile.jac`), each area a place sounded against the level
(its floor, the air over it, sky, liquid), its jumps run through the
engine's own player movement (sure only if they land), the falls and leaps
off its ledges run to see where they might land, its movers as gates with
what opens each (the level's own activation graph, as the player bot reads
it), its monsters and supplies as things.

A level read as it is played needs its monsters, items and triggers
spawned, as the game spawns them: openers that are a monster's death or an
item's pickup are found from those."""
import math;
import time;
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from ..formats.aas {
    Aas,
    TRAVEL_WALK,
    TRAVEL_JUMP,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_SWIM,
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
import from ..nav.compile { NavBuild, compile_navigation, nav_shut_shift }
import from .graph { LevelGraph, Place, Move, Gate, Opener, Thing, Holds, Guards, Bars, Offers, DoneFrom, Contains, StandsIn }

"""How a level is read: `sims` runs jumps and falls through the player's
movement (what a proof needs; a bot routing a level does not)."""
obj ReadOptions {
    has sims: bool = True,
        # Things read from the level's entities (for an original not yet
        # spawned) as well as spawned openers.
        entities: bool = True;
}

"""Run a body through the engine's own player movement from a standing
`origin`, running along `direction` from `run_up` units behind it, jumping
as it passes `takeoff` (none: never), holding the run until it stands again.
Answers where it came to stand, or None (it fell away, or never landed)."""
def run_body(
    collision: CollisionMap,
    profile: MovementProfile,
    origin: Vec3,
    direction: Vec3,
    takeoff: Vec3 | None,
    run_up: float,
    tick: float = 1.0 / 120.0
) -> Vec3 | None {
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
    for count in range(int(3.0 / tick)) {
        here = body.pos.sub(Vec3(z=collision.eye_height));
        jump = False;
        if not jumped and takeoff is not None and here.sub(takeoff).dot(heading) >= 0.0 {
            jump = True;
            jumped = True;
        }
        body spawn MovePlayer(collision=collision, wish=heading, jump=jump, command=Vec3(y=1.0), command_full=400.0, profile=profile, dt=tick);
        if not body.grounded {
            left = True;
        }
        if left and body.grounded {
            return body.pos.sub(Vec3(z=collision.eye_height));
        }
        if here.z < origin.z - 1024.0 {
            return None;
        }
    }
    return None;
}

"""How fast a jump leaves the ground in a game's movement."""
def profile_jump(profile: MovementProfile) -> float {
    return profile.jump_speed if profile.jump_speed > 0.0 else 270.0;
}

"""Where a body thrown from `origin` at `velocity` comes down: swept along
its arc a twentieth of a second at a time, sliding along walls it meets,
until it lands on floor it can stand on (or has fallen 1024 units, or two
seconds pass). What might happen off a ledge, not what surely does."""
def arc_landing(collision: CollisionMap, origin: Vec3, velocity: Vec3, gravity: float) -> Vec3 | None {
    at = origin;
    moving = velocity;
    step = 0.05;
    for count in range(40) {
        next_at = at.add(moving.scale(step)).add(Vec3(z=-0.5 * gravity * step * step));
        moving = moving.add(Vec3(z=-gravity * step));
        swept = collision.trace(at, next_at);
        if swept.start_solid {
            return None;
        }
        if swept.fraction < 1.0 {
            if swept.normal.z >= 0.7 {
                return swept.end;
            }
            # Off a wall: on along it.
            into = moving.dot(swept.normal);
            moving = moving.sub(swept.normal.scale(into));
            at = swept.end;
            continue;
        }
        at = next_at;
        if at.z < origin.z - 1024.0 {
            return None;
        }
    }
    return None;
}

"""Whether area `into` walks straight into area `target`."""
def walks_into(aas: Aas, into: int, target: int) -> bool {
    info = aas.areas[into];
    for r in range(info.first_reach, info.first_reach + info.reach_count) {
        reach = aas.reaches[r];
        if reach.area == target and reach.kind in [TRAVEL_WALK, TRAVEL_SWIM] {
            return True;
        }
    }
    return False;
}

"""Read the level graph off a level as loaded."""
def read_level_graph(world: World, level: Level, build: NavBuild | None = None, options: ReadOptions | None = None) -> LevelGraph {
    if options is None {
        options = ReadOptions();
    }
    began = time.time();
    if build is None {
        build = compile_navigation(world, level);
    }
    aas = build.aas;
    mesh = build_navmesh(world, aas, level.bsp);
    atlas = LevelGraph(name=level.name, game=level.bsp.game);
    atlas.notes.append("navigation " + build.summary() + " in " + str(round(time.time() - began, 1)) + " s");
    resting = set(build.rest_areas);
    places: list[Place] = [Place(area=0)];
    for index in range(1, len(aas.areas)) {
        info = aas.areas[index];
        contents = info.contents;
        place = Place(area=index, center=info.center, box=AABB(mins=info.mins, maxs=info.maxs), resting=index in resting, flags=info.flags, contents=contents);
        place.floor = info.center.z - 24.0;
        place.deadly = contents & (AREACONTENTS_LAVA | AREACONTENTS_SLIME | AREACONTENTS_DONOTENTER) != 0;
        if contents & AREACONTENTS_MOVER != 0 {
            place.mover = contents >> AREACONTENTS_MODELNUMSHIFT;
        }
        places.append(place);
        atlas +>:Holds:+> place;
    }
    sound_places(level, places);
    collision = level.collision;
    profile = level.movement;
    began = time.time();
    jumps = 0;
    sure_jumps = 0;
    for index in range(1, len(aas.areas)) {
        info = aas.areas[index];
        for r in range(info.first_reach, info.first_reach + info.reach_count) {
            reach = aas.reaches[r];
            if reach.area <= 0 or reach.area >= len(places) {
                continue;
            }
            sure = True;
            if reach.kind == TRAVEL_JUMP and options.sims {
                jumps += 1;
                landed = run_body(collision, profile, reach.start, reach.finish.sub(reach.start), reach.start, 96.0);
                sure = False;
                if landed is not None {
                    into = mesh.locate(landed);
                    sure = into == reach.area or landed.sub(reach.finish).length() < 48.0 or (0 < into < len(aas.areas) and walks_into(aas, into, reach.area));
                }
                if sure {
                    sure_jumps += 1;
                }
            }
            places[index] +>:Move(
                kind=reach.kind,
                to=reach.area,
                must=sure,
                model=reach.face_num & 65535 if reach.kind == TRAVEL_ELEVATOR else 0,
                start=reach.start,
                finish=reach.finish,
                time=reach.time
            ):+> places[reach.area];
        }
    }
    falls = 0;
    grid = build.grid;
    if grid is not None and options.sims {
        # Off every ledge, a run and a running leap each way it is not
        # walked, wherever they land: what might happen.
        tried: dict[tuple[int, int], bool] = {};
        bit = 1;
        for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
            for spot in grid.spots {
                if not spot.ledge or spot.walks & bit != 0 or spot.area <= 0 or (spot.area, bit) in tried or spot.liquid != 0 {
                    continue;
                }
                tried[(spot.area, bit)] = True;
                way = Vec3(x=dx, y=dy);
                for leap in [0.0, profile_jump(profile)] {
                    landed = arc_landing(collision, spot.origin, way.scale(320.0).add(Vec3(z=leap)), 800.0);
                    if landed is None {
                        continue;
                    }
                    into = mesh.locate(landed);
                    if 0 < into < len(places) and into != spot.area {
                        places[spot.area] +>:Move(kind=TRAVEL_WALKOFFLEDGE, to=into, must=False, start=spot.origin, finish=landed, fall=True):+> places[into];
                        falls += 1;
                    }
                }
            }
            bit *= 2;
        }
    }
    atlas.notes.append("jumps sure " + str(sure_jumps) + "/" + str(jumps) + ", falls " + str(falls) + " in " + str(round(time.time() - began, 1)) + " s");
    read_gates(atlas, world, level, mesh, places);
    read_exits(atlas, world, level, mesh, places);
    read_things(atlas, world, level, mesh, places);
    hand_missing_keys(atlas, places);
    return atlas;
}

"""A key a gate wants that nothing in the level gives (Quake II's units
carry keys from map to map): handed over at the start, so the map stands
alone; a level made from it moves the key somewhere of its own."""
def hand_missing_keys(atlas: LevelGraph, places: list[Place]) {
    given: list[str] = [opener.token for opener in [atlas->:Offers:->][?:Opener]];
    starts = [place for place in places[1:] if place.start];
    if not starts {
        return;
    }
    for gate in [atlas->:Guards:->][?:Gate] {
        for need in gate.needs {
            if need in given or not need.startswith("key") {
                continue;
            }
            given.append(need);
            opener = Opener(kind="pickup", token=need, point=starts[0].center, what=need);
            atlas +>:Offers:+> opener;
            opener +>:DoneFrom:+> starts[0];
            atlas.notes.append("key " + need + " is not in the level: handed over at the start");
        }
    }
}

"""Sound the level over each place: the air over its middle, whether the
ceiling there is sky, and the top of the liquid it stands in."""
def sound_places(level: Level, places: list[Place]) {
    collision = level.collision;
    for place in places[1:] {
        foot = Vec3(x=place.center.x, y=place.center.y, z=place.floor + 8.0);
        up = collision.trace(foot, foot.add(Vec3(z=1024.0)), [], -1.0, True);
        top = up.end.z;
        place.roof = max(0.0, top - place.floor);
        place.sky = level_sky(level, Vec3(x=foot.x, y=foot.y, z=top - 4.0));
        if place.flags & AREA_GROUNDED == 0 {
            # A place to swim: its floor is the bottom under it.
            down = collision.trace(place.center, place.center.add(Vec3(z=-1024.0)), [], -1.0, True);
            place.floor = down.end.z;
            foot = Vec3(x=place.center.x, y=place.center.y, z=place.floor + 8.0);
        }
        kind = level.liquid_at(foot);
        if kind > 0 {
            place.liquid = kind;
            z = foot.z;
            while z < top and level.liquid_at(Vec3(x=foot.x, y=foot.y, z=z)) > 0 {
                z += 4.0;
            }
            place.surface = z;
        }
    }
}

"""Whether the ceiling over a point is sky: a face of the leaf it is in,
drawn with a sky texture and facing down over it (Quake's sky is solid to
every hull, so only its faces say where it is)."""
def level_sky(level: Level, point: Vec3) -> bool {
    leaf = level.bsp.leaves[level.locate(point)];
    for index in leaf.faces {
        if index < 0 or index >= len(level.bsp.faces) {
            continue;
        }
        face = level.bsp.faces[index];
        if face.normal.z > -0.5 or not face.vertices or face.texture < 0 or face.texture >= len(level.bsp.textures) {
            continue;
        }
        name = level.bsp.textures[face.texture].name.lower();
        if "sky" not in name {
            continue;
        }
        low_x = min([vertex.x for vertex in face.vertices]);
        high_x = max([vertex.x for vertex in face.vertices]);
        low_y = min([vertex.y for vertex in face.vertices]);
        high_y = max([vertex.y for vertex in face.vertices]);
        if low_x <= point.x <= high_x and low_y <= point.y <= high_y {
            return True;
        }
    }
    return False;
}

"""Whether the segment from `a` to `b` passes through a box (its inside,
not only its faces): slab by slab."""
def segment_meets(a: Vec3, b: Vec3, box: AABB) -> bool {
    near = 0.0;
    far = 1.0;
    for (start, finish, low, high) in [(a.x, b.x, box.mins.x, box.maxs.x), (a.y, b.y, box.mins.y, box.maxs.y), (a.z, b.z, box.mins.z, box.maxs.z)] {
        span = finish - start;
        if abs(span) < 0.0001 {
            if start <= low or start >= high {
                return False;
            }
            continue;
        }
        t0 = (low - start) / span;
        t1 = (high - start) / span;
        if t0 > t1 {
            swap = t0;
            t0 = t1;
            t1 = swap;
        }
        near = max(near, t0);
        far = min(far, t1);
        if near >= far {
            return False;
        }
    }
    return True;
}

"""Where a mover stands shut (a door), at its top (a lift) or at rest (a
secret door), as the navigation compiler poses it; None when not known."""
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
a shut door bars. A body standing on the box (a lift's top, a lowered
bridge) is not inside it."""
def body_inside(place: Place, box: AABB) -> bool {
    low_z = place.box.mins.z + 4.0 - 24.0;
    high_z = place.box.maxs.z - 8.0 + 32.0;
    return place.box.mins.x - 16.0 < box.maxs.x - 1.0 and box.mins.x + 1.0 < place.box.maxs.x + 16.0
        and place.box.mins.y - 16.0 < box.maxs.y - 1.0 and box.mins.y + 1.0 < place.box.maxs.y + 16.0
        and low_z < box.maxs.z - 1.0 and box.mins.z + 1.0 < high_z;
}

"""The places an opener is done from: the place its point is in, every
place its volume meets (a trigger to stand in, a button to walk into), and
for a shot or a kill every place that sees it within 1024 units."""
def opener_places_of(objective: Objective, collision: CollisionMap, mesh: NavMesh, places: list[Place]) -> list[Place] {
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
            if place in found or eye.sub(aim).length() > 1024.0 {
                continue;
            }
            seen = collision.trace(eye, aim, [], -1.0, True);
            if seen.fraction >= 0.99 or seen.end.sub(aim).length() < 24.0 {
                found.append(place);
            }
        }
    }
    return found;
}

"""What an objective is done to: a button, a trigger, a key's or another
item's classname, a monster's."""
def objective_what(objective: Objective) -> str {
    item = objective.item;
    if item is not None {
        return item.rule.kind if item.rule.kind.startswith("key") else "item";
    }
    body = objective.body;
    if body is not None {
        return "monster";
    }
    if objective.door is not None {
        return "button";
    }
    if objective.train is not None {
        return "secret";
    }
    return "trigger";
}

"""Gates: every mover in the level (door, secret door, lift), the places it
bars when shut, and, for one that bars a player holding nothing (locked,
opened from elsewhere, shot open, a lift held up), its openers."""
def read_gates(atlas: LevelGraph, world: World, level: Level, mesh: NavMesh, places: list[Place]) {
    nobody = Player();
    models: list[int] = [];
    kinds: dict[int, str] = {};
    travels: dict[int, float] = {};
    motions: dict[int, Vec3] = {};
    for door in door_parts(world) {
        if door.kind == "button" or door.model <= 0 {
            continue;
        }
        if door.model not in models {
            models.append(door.model);
            kinds[door.model] = "lift" if door.kind == "platform" else "door";
            travels[door.model] = -door.rest.z if door.kind == "platform" else 0.0;
            motions[door.model] = door.travel;
        }
    }
    for train in [world->:HasTrain:->][?:Train] {
        if train.kind == "secret" and train.model not in models {
            models.append(train.model);
            kinds[train.model] = "secret";
        }
    }
    for model in models {
        box = shut_box(world, level, model);
        if box is None {
            continue;
        }
        gate = Gate(model=model, kind=kinds[model], box=box, travel=travels.get(model, 0.0), motion=motions.get(model, Vec3()));
        atlas +>:Guards:+> gate;
        # The places a body would be inside it shut: its doorway. (A mover
        # stood on, a lift or a floor that lowers, bars nothing.)
        if gate.kind != "lift" {
            for place in places[1:] {
                if place.mover == model and body_inside(place, box) {
                    gate +>:Bars:+> place;
                }
            }
        }
        if not mover_blocked(world, model, nobody) {
            continue;
        }
        token = "open:" + str(model);
        gate.needs = [token];
        # A way that passes through it shut (into or out of a place it does
        # not bar) wants it open too.
        swept = AABB(mins=box.mins.sub(Vec3(x=16.0, y=16.0, z=32.0)), maxs=box.maxs.add(Vec3(x=16.0, y=16.0, z=24.0)));
        for place in places[1:] {
            for move in [edge place->:Move:->] {
                if move.gate == 0 and segment_meets(move.start, move.finish, swept) {
                    move.gate = model;
                }
            }
        }
        for objective in mover_objectives(world, model, nobody) {
            what = objective_what(objective);
            given = token;
            if objective.kind == "pickup" and what.startswith("key") {
                given = what;
                gate.needs = [need for need in gate.needs if need != token];
                if what not in gate.needs {
                    gate.needs.append(what);
                }
            }
            opener = Opener(kind=objective.kind, token=given, point=objective.point, what=what);
            atlas +>:Offers:+> opener;
            for place in opener_places_of(objective, level.collision, mesh, places) {
                opener +>:DoneFrom:+> place;
            }
        }
    }
}

"""The ways out: the places their volumes meet, and what fires one that is
fired rather than touched. A level with none is an arena."""
def read_exits(atlas: LevelGraph, world: World, level: Level, mesh: NavMesh, places: list[Place]) {
    portals = [world->:HasExit:->][?:LevelExit];
    found_any = False;
    for portal in portals {
        if not portal.volume.bounds {
            continue;
        }
        box = portal.volume.bounds[0];
        for place in places[1:] {
            meets = place.box.mins.x <= box.maxs.x + 16.0 and box.mins.x - 16.0 <= place.box.maxs.x and place.box.mins.y <= box.maxs.y + 16.0
                and box.mins.y - 16.0 <= place.box.maxs.y and place.box.mins.z <= box.maxs.z + 24.0 and box.mins.z - 32.0 <= place.box.maxs.z;
            if meets {
                place.way_out = True;
                found_any = True;
            }
        }
        if not portal.contact {
            for objective in exit_objectives(world, portal) {
                opener = Opener(kind=objective.kind, token="exit", point=objective.point, what=objective_what(objective));
                atlas +>:Offers:+> opener;
                for place in opener_places_of(objective, level.collision, mesh, places) {
                    opener +>:DoneFrom:+> place;
                }
            }
        }
    }
    atlas.arena = not found_any;
}

"""The start, and the monsters and supplies, each in the place it stands
in: from the level's entities as the game would spawn them (the skill the
level was loaded at)."""
def read_things(atlas: LevelGraph, world: World, level: Level, mesh: NavMesh, places: list[Place]) {
    starts: list[list[float]] = [];
    for entity in level.bsp.entities {
        name = entity.fields.get("classname", "");
        parts = entity.fields.get("origin", "").split();
        if len(parts) != 3 {
            continue;
        }
        point = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
        yaw = float(entity.fields.get("angle", "0") or "0");
        if name in ["info_player_start", "info_player_deathmatch"] {
            # The start a level is entered at without a name (Quake II's
            # units name the others), else the first.
            named = 1.0 if entity.fields.get("targetname", "") else 0.0;
            rank = named + (2.0 if name == "info_player_deathmatch" else 0.0);
            starts.append([rank, point.x, point.y, point.z, yaw]);
            continue;
        }
        wanted = name.startswith("monster_") or name.startswith("item_") or name.startswith("weapon_") or name.startswith("ammo_")
            or name.startswith("key_");
        if not wanted {
            continue;
        }
        thing = Thing(
            classname=name,
            game=entity.fields.get("asset_game", level.bsp.game) if level.bsp.game == "passion" else level.bsp.game,
            point=point,
            spawnflags=int(float(entity.fields.get("spawnflags", "0") or "0")),
            yaw=yaw
        );
        atlas +>:Contains:+> thing;
        found = mesh.locate(point.add(Vec3(z=8.0)));
        if 0 < found < len(places) {
            thing +>:StandsIn:+> places[found];
        }
    }
    if starts {
        best = starts[0];
        for start in starts {
            if start[0] < best[0] {
                best = start;
            }
        }
        atlas.start_yaw = best[4];
        found = mesh.locate(Vec3(x=best[1], y=best[2], z=best[3]));
        if 0 < found < len(places) {
            places[found].start = True;
        }
    }
}
