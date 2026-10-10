"""Q3 bots route with botlib's travel flags and travel rocket jumps and
movers as be_ai_move.c does."""
import from engine.formats.aas {
    Aas,
    AasArea,
    AasReach,
    AREA_GROUNDED,
    AREACONTENTS_LAVA,
    TRAVEL_WALK,
    TRAVEL_SWIM,
    TRAVEL_CROUCH,
    PRESENCE_CROUCH,
    TRAVEL_TELEPORT,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_BARRIERJUMP,
    TRAVEL_ELEVATOR,
    TRAVEL_WATERJUMP,
    TRAVEL_ROCKETJUMP,
    TRAVEL_FUNCBOB,
    TFL_DEFAULT,
    TFL_ROCKETJUMP,
    TFL_LAVA
}
import from engine.world.bot_routes { avoid_spot_type, line_distance_squared, AvoidSpot, AVOID_ALWAYS, AVOID_DONTBLOCK, best_exit, AvoidReach, NavMesh, Passage, Exits, BotRoute, build_navmesh, plan_route, area_travel_time, bob_ends, UNREACHED }
import from engine.world.bot_travel {
    FollowRoute,
    TravelResult,
    travel_weapon_jump,
    travel_funcbob,
    travel_water_jump,
    goal_area_speed,
    gap_distance,
    fall_speed,
    travel_walk_off_ledge,
    finish_walk_off_ledge,
    finish_water_jump,
    air_control,
    mover_box
}
import math;
import from engine.world.liquids { LiquidProbe }
import from engine.world.combat { Opponent }
import from engine.world.world { World }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

"""A strip of areas 64 units wide along x (area i centred at x = 64 i), found
by a chain of split planes; `links` are (from, to, travel type) and
`lava` areas hold lava."""
def strip_aas(count: int, links: list[tuple[int, int, int]], lava: list[int] = []) -> Aas {
    areas: list[AasArea] = [AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3())];
    reaches: list[AasReach] = [];
    for i in range(1, count + 1) {
        center = Vec3(x=float(i) * 64.0);
        mine = [link for link in links if link[0] == i];
        areas.append(
            AasArea(
                center=center,
                mins=center.sub(Vec3(x=32.0, y=32.0, z=32.0)),
                maxs=center.add(Vec3(x=32.0, y=32.0, z=32.0)),
                flags=AREA_GROUNDED,
                contents=AREACONTENTS_LAVA if i in lava else 0,
                first_reach=len(reaches),
                reach_count=len(mine)
            )
        );
        for link in mine {
            reaches.append(
                AasReach(
                    area=link[1],
                    start=center.add(Vec3(x=16.0 if link[1] > i else -16.0)),
                    finish=Vec3(x=float(link[1]) * 64.0),
                    kind=link[2],
                    time=40 if link[2] == TRAVEL_ROCKETJUMP else 20
                )
            );
        }
    }
    # Node k splits at x = 64 k + 32: in front, the next node; behind, area k.
    normals: list[Vec3] = [Vec3(x=1.0)];
    dists: list[float] = [0.0];
    planes: list[int] = [0];
    front: list[int] = [0];
    back: list[int] = [0];
    for k in range(1, count) {
        normals.append(Vec3(x=1.0));
        dists.append(float(k) * 64.0 + 32.0);
        planes.append(k);
        front.append(k + 1 if k + 1 < count else -count);
        back.append(-k);
    }
    return Aas(normals=normals, dists=dists, node_planes=planes, front=front, back=back, areas=areas, reaches=reaches);
}

test "travel tables keep to the travel flags: rocket jumps and lava only when allowed" {
    # 1 <-> 2 <-> 3 on foot, 3 -> 4 only by rocket jump from 1, and back.
    aas = strip_aas(4, [
        (1, 2, TRAVEL_WALK), (2, 1, TRAVEL_WALK), (2, 3, TRAVEL_WALK), (3, 2, TRAVEL_WALK),
        (1, 4, TRAVEL_ROCKETJUMP), (4, 3, TRAVEL_WALK)
    ], [3]);
    mesh = build_navmesh(World(), aas);
    assert mesh.locate(Vec3(x=64.0)) == 1 and mesh.locate(Vec3(x=250.0)) == 4;
    plain = mesh.times_to(4);
    assert plain[1] >= UNREACHED;
    jumping = mesh.times_to(4, TFL_DEFAULT | TFL_ROCKETJUMP);
    assert jumping[1] < UNREACHED;
    # Area 3 holds lava: no way in by default, even walking.
    assert mesh.times_to(3)[2] >= UNREACHED;
    assert mesh.times_to(3, TFL_DEFAULT | TFL_LAVA)[2] < UNREACHED;
    # A rocket jump waypoint carries its passage; walking ones only a point.
    route = plan_route(mesh, Vec3(x=64.0), Vec3(x=256.0), 32, TFL_DEFAULT | TFL_ROCKETJUMP);
    assert route.found and route.passages[0] is not None and route.passages[0].kind == TRAVEL_ROCKETJUMP;
    assert route.areas[0] == 4;
    assert area_travel_time(mesh, 1, Vec3(x=64.0), 4) == 0;
    assert area_travel_time(mesh, 1, Vec3(x=64.0), 4, TFL_DEFAULT | TFL_ROCKETJUMP) > 0;
    # While a table with other flags is built, the default one routes.
    fresh = build_navmesh(World(), aas);
    fresh.times_to(2);
    assert fresh.times_for(2, TFL_DEFAULT | TFL_ROCKETJUMP) is not None and fresh.jobs;
}

test "a rocket jump walks to its start looking down, then jumps and fires" {
    fake = strip_aas(2, [(1, 2, TRAVEL_ROCKETJUMP)]);
    mesh = build_navmesh(World(), fake);
    mesh.times_to(2, TFL_DEFAULT | TFL_ROCKETJUMP);
    passage = plan_route(mesh, Vec3(x=64.0), Vec3(x=128.0), 32, TFL_DEFAULT | TFL_ROCKETJUMP).passages[0];
    assert passage is not None;
    # Away from the start: walk there, slowing within 80 units, looking down.
    far = travel_weapon_jump(Vec3(x=0.0), passage, 0.0, 0.0, "rocketlauncher");
    assert far.view_set and far.pitch == 90.0 and far.weapon == "rocketlauncher";
    assert not far.jump and far.direction.x > 0.99 and far.speed == 400.0;
    # At the start but still looking ahead: wait for the view.
    there = travel_weapon_jump(passage.start, passage, 0.0, 0.0, "rocketlauncher");
    assert not there.jump;
    # Looking down: jump, fire and run for the far end at full speed.
    ready = travel_weapon_jump(passage.start, passage, 0.0, 89.0, "rocketlauncher");
    assert ready.jump and ready.attack and ready.speed == 800.0;
    # In the air it steers for its landing (BotAirControl).
    steer = air_control(Vec3(x=80.0, z=100.0), Vec3(x=20.0, z=300.0), Vec3(x=128.0));
    assert steer is not None and steer.air_control and steer.direction.x > 0.0;
    # The route follower hands the travel over while the jump leg lasts.
    bot = Opponent(arena=True, pos=passage.start.add(Vec3(z=26.0)), eye_height=26.0, grounded=True);
    route = BotRoute();
    route.add(passage.finish, 2, passage=passage);
    follow = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0, view_pitch=89.0);
    assert follow.result.jump and follow.result.attack and route.jumped;
    # A leg taking longer than BotReachabilityTime is given up: the route is
    # emptied, to be planned again.
    late = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=7.0, view_pitch=89.0);
    assert not late.result.failure and not route.points;
}

test "bobbing platforms are waited for, boarded, ridden and left" {
    # be_aas_reach.c packs the ends into the edge number: 100 and -300.
    ends = bob_ends((2 << 16) | 9, (100 << 16) | (-300 & 65535));
    assert ends == (1, 100.0, -300.0);
    aas = strip_aas(2, [(1, 2, TRAVEL_FUNCBOB)]);
    mesh = build_navmesh(World(), aas);
    passage = [mesh.areas[1]->:Exits:->][?:Passage][0];
    passage.model = 9;
    passage.axis = 2;
    passage.near = 0.0;
    passage.far = 200.0;
    passage.start = Vec3(x=64.0);
    passage.finish = Vec3(x=400.0, z=200.0);
    # A platform 64 units square, 16 thick, centred on x=128 at rest.
    mesh.mover_bounds[9] = AABB(mins=Vec3(x=96.0, y=-32.0, z=-8.0), maxs=Vec3(x=160.0, y=32.0, z=8.0));
    collision = CollisionMap();
    collision.add_box(Vec3(x=96.0, y=-32.0, z=-8.0), Vec3(x=160.0, y=32.0, z=8.0), Vec3(z=100.0), Vec3(), Vec3());
    collision.models.append(9);
    # Its broad phase covers its whole bob, as load_rotators makes it.
    collision.bounds[0] = AABB(mins=Vec3(x=96.0, y=-32.0, z=-8.0), maxs=Vec3(x=160.0, y=32.0, z=208.0));
    collision.reindex();
    box = mover_box(mesh, collision, 9);
    assert box is not None and box.mins.z == 92.0;
    # Up at 100 (not at its near end): wait at the passage's start.
    waiting = travel_funcbob(mesh, collision, Vec3(x=0.0), True, passage);
    assert waiting.waiting and waiting.direction.x > 0.99;
    # Down at its near end: step onto its middle.
    collision.set_offset(0, Vec3());
    boarding = travel_funcbob(mesh, collision, Vec3(x=64.0, z=8.0), True, passage);
    assert not boarding.waiting and boarding.direction.x > 0.99;
    # On it: stand on its middle until it has carried the bot to the far end.
    riding = travel_funcbob(mesh, collision, Vec3(x=128.0, z=8.25), True, passage);
    assert riding.speed == 0.0;
    collision.set_offset(0, Vec3(z=200.0));
    leaving = travel_funcbob(mesh, collision, Vec3(x=128.0, z=208.25), True, passage);
    assert leaving.direction.x > 0.99 and leaving.speed == 400.0;
}

test "a swimming bot swims straight for its waypoint and water jumps out" {
    aas = strip_aas(3, [(1, 2, TRAVEL_SWIM), (2, 3, TRAVEL_WATERJUMP)]);
    mesh = build_navmesh(World(), aas);
    mesh.times_to(3);
    # A water jump is a passage of its own to follow, not a launch.
    route = plan_route(mesh, Vec3(x=64.0), Vec3(x=192.0), 32);
    assert route.found and len(route.points) == 3 and route.launches[1].z == 0.0;
    passage = route.passages[1];
    assert passage is not None and passage.kind == TRAVEL_WATERJUMP and route.areas[1] == 3;
    # Waist deep (MFL_SWIMMING): straight at the point, up too, looking there.
    bot = Opponent(arena=True, pos=Vec3(x=64.0, z=-74.0), eye_height=26.0, water_depth=2);
    swim = BotRoute();
    swim.add(Vec3(x=124.0, z=-20.0), 2, passage=route.passages[0]);
    follow = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=swim, eye_height=26.0, clock=0.0);
    heading = follow.result.direction;
    assert abs(heading.x - 0.6) < 0.001 and abs(heading.z - 0.8) < 0.001;
    assert follow.result.view_set and abs(follow.result.pitch + 53.13) < 0.01;
    # Out of the water the same leg is walked on the level.
    bot.water_depth = 0;
    walk = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=swim, eye_height=26.0, clock=0.0);
    assert walk.result.direction.z == 0.0 and walk.result.direction.x > 0.99 and not walk.result.view_set;
    # BotTravel_WaterJump: forward for the far end looking above it, and up
    # as well once within 40 units of it.
    far = travel_water_jump(Vec3(x=passage.finish.x - 100.0, z=passage.finish.z), passage);
    assert far.view_set and far.pitch < 0.0 and far.direction.x > 0.98;
    near = travel_water_jump(Vec3(x=passage.finish.x - 30.0, z=passage.finish.z), passage);
    assert near.direction.z > 0.7 and near.direction.x > 0.3;
    # The view is 15 units over the far end, give or take 40 by crandom().
    level = Vec3(x=passage.finish.x - 100.0, z=passage.finish.z);
    assert abs(travel_water_jump(level, passage).pitch + math.degrees(math.atan2(15.0, 100.0))) < 0.001;
    assert abs(travel_water_jump(level, passage, 1.0).pitch + math.degrees(math.atan2(55.0, 100.0))) < 0.001;
    assert abs(travel_water_jump(level, passage, -1.0).pitch - math.degrees(math.atan2(25.0, 100.0))) < 0.001;
    # EA_MoveForward: it swims the way it looks now, whatever it wants.
    aside = travel_water_jump(level, passage, 0.0, Vec3(y=1.0));
    assert aside.direction.y > 0.99 and abs(aside.yaw) < 0.001;
    # BotFinishTravel_WaterJump: clear of the surface with its feet still
    # wet, on for the far end aiming 70 units over it; dry, no move at all.
    rising = finish_water_jump(level, passage, True, [0.0, 0.0, 0.0]);
    assert rising.view_set and rising.speed == 400.0 and abs(rising.direction.z - 70.0 / math.sqrt(14900.0)) < 0.001;
    assert finish_water_jump(level, passage, False, [0.0, 0.0, 0.0]).speed == 0.0;
    # The route follower hands the leg to the water jump until area 3.
    bot.pos = Vec3(x=150.0, z=26.0);
    bot.water_depth = 2;
    jump = BotRoute();
    jump.add(passage.finish, 3, passage=passage);
    out = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=jump, eye_height=26.0, clock=0.0);
    assert out.result.view_set and len(jump.points) == 1 and out.result.direction.x > 0.0;
}

test "a passage taken five times running is avoided for six seconds, and a timed-out leg is planned again" {
    # Two ways from 1 to 3: straight (quick) and round by 2.
    aas = strip_aas(3, [(1, 3, TRAVEL_WALK), (1, 2, TRAVEL_WALK), (2, 3, TRAVEL_WALK)]);
    mesh = build_navmesh(World(), aas);
    mesh.times_to(3);
    exits = [mesh.areas[1]->:Exits:->][?:Passage];
    direct = [passage for passage in exits if passage.target == 3][0];
    round_way = [passage for passage in exits if passage.target == 2][0];
    avoid = AvoidReach();
    # BotAddToAvoidReach: each use within six seconds of the last is a try.
    for attempt in range(4) {
        avoid.add(direct, 1.0 + float(attempt) * 5.0);
        assert avoid.tries == attempt + 1 and not avoid.avoids(direct, 1.0 + float(attempt) * 5.0);
    }
    # Another passage does not take the single slot while its time runs.
    avoid.add(round_way, 17.0);
    assert avoid.passage is direct and avoid.tries == 4;
    avoid.add(direct, 21.0);
    assert avoid.tries == 5 and avoid.avoids(direct, 21.0) and avoid.avoids(direct, 27.0) and not avoid.avoids(direct, 27.5);
    # BotGetReachabilityToGoal: the bot's way out of its area passes it over.
    usual = plan_route(mesh, Vec3(x=64.0), Vec3(x=192.0));
    assert usual.found and usual.areas[0] == 3;
    detour = plan_route(mesh, Vec3(x=64.0), Vec3(x=192.0), avoid=avoid, now=22.0);
    assert detour.found and detour.areas[0] == 2;
    # BotResetLastAvoidReach forgets a try; BotResetAvoidReach all of it.
    avoid.reset_last();
    assert avoid.tries == 4 and not avoid.avoids(direct, 22.0);
    avoid.add(direct, 30.0);
    assert avoid.tries == 1;
    avoid.reset();
    assert avoid.passage is None and avoid.tries == 0;
    # Following a route: the leg set out on is added once; past its
    # BotReachabilityTime the route is emptied to be planned again, without
    # a failure.
    bot = Opponent(arena=True, health=100, pos=Vec3(x=64.0, z=26.0), eye_height=26.0, grounded=True);
    route = plan_route(mesh, Vec3(x=64.0), Vec3(x=192.0));
    first = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=40.0, avoid=avoid);
    assert avoid.passage is direct and avoid.tries == 1 and route.noted and first.result.direction.x > 0.9;
    bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=41.0, avoid=avoid);
    assert avoid.tries == 1;
    late = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=45.5, avoid=avoid);
    assert not late.result.failure and late.result.speed == 0.0 and not route.points and not route.areas;
}

test "a bot slows into its goal and onto a teleporter" {
    # BotMoveInGoalArea: 4 a unit over the last 100 units, nothing within 2.5.
    assert goal_area_speed(300.0) == 400.0 and goal_area_speed(50.0) == 200.0 and goal_area_speed(2.0) == 0.0;
    aas = strip_aas(2, [(1, 2, TRAVEL_TELEPORT)]);
    mesh = build_navmesh(World(), aas);
    mesh.times_to(2);
    bot = Opponent(arena=True, health=100, pos=Vec3(x=0.0, z=26.0), eye_height=26.0, grounded=True);
    # BotTravel_Teleport: full speed to within 30 units of the reach's
    # start (x = 80 here), then half.
    route = plan_route(mesh, Vec3(x=0.0), Vec3(x=128.0));
    far = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert route.passages[0] is not None and far.result.speed == 400.0;
    bot.pos = Vec3(x=60.0, z=26.0);
    near = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert near.result.speed == 200.0;
    # The last leg, in the goal's area, at BotMoveInGoalArea's speed.
    last = BotRoute();
    last.add(Vec3(x=120.0), 0);
    bot.pos = Vec3(x=70.0, z=26.0);
    closing = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=last, eye_height=26.0, clock=0.0);
    assert closing.result.speed == 200.0 and closing.result.direction.x > 0.99;
}

test "a route never turns straight back into the area it just left" {
    # From 2 the quick way to 4 is back through 1 (a short cut 1 -> 4); the
    # route that came from 1 takes the long way by 3 instead.
    aas = strip_aas(4, [(1, 2, TRAVEL_WALK), (2, 1, TRAVEL_WALK), (2, 3, TRAVEL_WALK), (3, 4, TRAVEL_WALK), (1, 4, TRAVEL_WALK)]);
    mesh = build_navmesh(World(), aas);
    times = mesh.times_to(4);
    exits = [mesh.areas[1]->:Exits:->][?:Passage];
    short_cut = [passage for passage in exits if passage.target == 4][0];
    # Make the short cut dear from area 1 itself, so a route from 1 sets
    # out by 2, where going back to 1 would then look best.
    short_cut.time = 100000;
    back = [passage for passage in [mesh.areas[2]->:Exits:->][?:Passage] if passage.target == 1][0];
    onward = [passage for passage in [mesh.areas[2]->:Exits:->][?:Passage] if passage.target == 3][0];
    assert best_exit(mesh, 2, Vec3(x=128.0), times, TFL_DEFAULT) is back;
    assert best_exit(mesh, 2, Vec3(x=128.0), times, TFL_DEFAULT, None, 0.0, 1) is onward;
    route = plan_route(mesh, Vec3(x=64.0), Vec3(x=256.0));
    assert route.found and [area for area in route.areas if area > 0] == [2, 3, 4];
}

test "a bot walks off a ledge at the speed that lands it, and steers for the landing in the air" {
    aas = strip_aas(2, [(1, 2, TRAVEL_WALKOFFLEDGE)]);
    mesh = build_navmesh(World(), aas);
    passage = [mesh.areas[1]->:Exits:->][?:Passage][0];
    passage.start = Vec3(x=80.0);
    passage.finish = Vec3(x=128.0, z=-100.0);
    # AAS_HorizontalVelocityForJump for a fall of 100 units: half a second.
    assert abs(fall_speed(passage.start, passage.finish) - 96.0) < 0.001;
    assert fall_speed(passage.start, Vec3(x=128.0, z=10.0)) is None and fall_speed(passage.start, Vec3(x=900.0, z=-100.0)) is None;
    # Far from the ledge: for its start at full speed. Within 48 units: for
    # the far end, at the speed that carries the fall.
    far = travel_walk_off_ledge(Vec3(x=0.0), passage);
    assert far.speed == 400.0 and far.direction.x > 0.99;
    near = travel_walk_off_ledge(Vec3(x=60.0), passage);
    assert abs(near.speed - 96.0) < 0.001 and near.direction.x > 0.99;
    # A drop straight down: slowing over the last 64 units, then 100.
    passage.finish = Vec3(x=90.0, z=-100.0);
    assert travel_walk_off_ledge(Vec3(x=30.0), passage).speed == 344.0;
    assert travel_walk_off_ledge(Vec3(x=60.0), passage).speed == 100.0;
    # In the air: BotAirControl for 16 units past the far end.
    passage.finish = Vec3(x=128.0, z=-100.0);
    falling = finish_walk_off_ledge(Vec3(x=90.0, z=-10.0), Vec3(x=100.0, z=-50.0), passage);
    assert falling.air_control and falling.direction.x > 0.9;
    # The route follower hands a ledge leg to them.
    bot = Opponent(arena=True, health=100, pos=Vec3(x=60.0, z=26.0), eye_height=26.0, grounded=True);
    route = BotRoute();
    route.add(passage.start, 0, passage=passage);
    route.add(passage.finish, 2, passage=passage);
    follow = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert abs(follow.result.speed - 96.0) < 0.001;
}

test "a bot slows up to a barrier and jumps it within 9 units" {
    aas = strip_aas(2, [(1, 2, TRAVEL_BARRIERJUMP)]);
    mesh = build_navmesh(World(), aas);
    mesh.times_to(2);
    bot = Opponent(arena=True, health=100, pos=Vec3(x=40.0, z=26.0), eye_height=26.0, grounded=True);
    route = plan_route(mesh, Vec3(x=40.0), Vec3(x=128.0));
    assert route.found and route.launches[0].z > 0.0;
    # 40 units from the reach's start (x = 80): 6 a unit.
    far = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert far.result.speed == 240.0 and far.launch is None;
    # 10 units off: not yet (a waypoint's usual 12 units do not count).
    bot.pos = Vec3(x=70.0, z=26.0);
    close = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert close.launch is None and close.result.speed == 60.0;
    # Within 9: the jump, launched to land from where the bot is.
    bot.pos = Vec3(x=72.0, z=26.0);
    jump = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    launched = jump.launch;
    assert launched is not None and launched.z == 270.0 and launched.x > 0.0;
}

test "a bot ducks into an area only the crouching box fits, along a crouch reachability, and under a low ceiling" {
    aas = strip_aas(3, [(1, 2, TRAVEL_WALK), (2, 3, TRAVEL_CROUCH)]);
    aas.areas[2].presence = PRESENCE_CROUCH;
    mesh = build_navmesh(World(), aas);
    mesh.times_to(3);
    bot = Opponent(arena=True, health=100, pos=Vec3(x=20.0, z=26.0), eye_height=26.0, grounded=True);
    route = plan_route(mesh, Vec3(x=20.0), Vec3(x=192.0));
    # BotTravel_Walk: not yet 60 units from the reach (x = 80), ducking
    # within 20.
    far = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert not far.result.crouch;
    bot.pos = Vec3(x=65.0, z=26.0);
    near = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert near.result.crouch and near.result.direction.x > 0.99;
    # BotTravel_Crouch: all along the crouch reachability.
    bot.pos = Vec3(x=130.0, z=26.0);
    along = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert route.passages[0] is not None and route.passages[0].kind == TRAVEL_CROUCH and along.result.crouch;
    # PM_CheckDuck: a ducked bot under a ceiling 40 units up stays ducked;
    # one standing in the open does not start to.
    low = CollisionMap();
    low.add_box(Vec3(x=-500.0, y=-500.0, z=20.0), Vec3(x=500.0, y=500.0, z=60.0), Vec3(), Vec3(x=-15.0, y=-15.0, z=-24.0), Vec3(x=15.0, y=15.0, z=32.0));
    low.reindex();
    open_route = BotRoute();
    open_route.add(Vec3(x=400.0), 0);
    bot.pos = Vec3(x=300.0, z=26.0);
    under = bot spawn FollowRoute(mesh=mesh, collision=low.for_body(26.0, 16.0), route=open_route, eye_height=26.0, clock=0.0, ducked=True);
    assert under.result.crouch;
    clear = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=open_route, eye_height=26.0, clock=0.0, ducked=True);
    assert not clear.result.crouch;
}

"""Water wherever it is asked."""
obj Flooded(LiquidProbe) {
    def kind_at(point: Vec3) -> int {
        return 1;
    }
}

test "a walking bot slows up to a gap ahead, but not to water" {
    # A floor that ends at x = 50, with nothing beyond.
    collision = CollisionMap();
    collision.add_box(Vec3(x=-500.0, y=-500.0, z=-64.0), Vec3(x=50.0, y=500.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    gap = gap_distance(collision, Vec3(), Vec3(x=1.0));
    assert gap >= 48.0 and gap <= 64.0;
    assert gap_distance(collision, Vec3(), Vec3(x=-1.0)) == 0.0;
    # A pool under the edge is no gap; no floor under the bot at all is 1.
    assert gap_distance(collision, Vec3(), Vec3(x=1.0), Flooded()) == 0.0;
    assert gap_distance(collision, Vec3(x=300.0), Vec3(x=1.0)) == 1.0;
    # BotTravel_Walk: 400 - (360 - 2 * dist) on a walk leg.
    mesh = build_navmesh(World(), strip_aas(2, [(1, 2, TRAVEL_WALK)]));
    mesh.times_to(2);
    bot = Opponent(arena=True, health=100, pos=Vec3(z=26.0), eye_height=26.0, grounded=True);
    route = plan_route(mesh, Vec3(), Vec3(x=128.0));
    walk = bot spawn FollowRoute(mesh=mesh, collision=collision, route=route, eye_height=26.0, clock=0.0);
    assert walk.result.speed == 40.0 + 2.0 * gap and route.gap == gap;
    wade = bot spawn FollowRoute(mesh=mesh, collision=collision, route=plan_route(mesh, Vec3(), Vec3(x=128.0)), eye_height=26.0, clock=0.0, liquids=Flooded());
    assert wade.result.speed == 400.0;
}

test "a bot's way keeps clear of live grenades" {
    # Two ways from 1 to 3: straight, and round by 2.
    aas = strip_aas(3, [(1, 3, TRAVEL_WALK), (1, 2, TRAVEL_WALK), (2, 3, TRAVEL_WALK)]);
    mesh = build_navmesh(World(), aas);
    mesh.times_to(3);
    exits = [mesh.areas[1]->:Exits:->][?:Passage];
    direct = [passage for passage in exits if passage.target == 3][0];
    round_way = [passage for passage in exits if passage.target == 2][0];
    # The round way leaves to the side, clear of the straight one.
    round_way.start = Vec3(x=64.0, y=400.0);
    round_way.finish = Vec3(x=128.0, y=400.0);
    onward = [mesh.areas[2]->:Exits:->][?:Passage][0];
    onward.start = Vec3(x=140.0, y=400.0);
    onward.finish = Vec3(x=192.0, y=400.0);
    # DistanceFromLineSquared: to the stretch, or to its nearer end.
    assert line_distance_squared(Vec3(x=50.0, y=30.0), Vec3(), Vec3(x=100.0)) == 900.0;
    assert line_distance_squared(Vec3(x=130.0, y=40.0), Vec3(), Vec3(x=100.0)) == 2500.0;
    # A grenade on the straight passage: BotAvoidSpots finds the walk runs
    # within its 160 units; the side way does not.
    grenade = [AvoidSpot(origin=Vec3(x=150.0), radius=160.0)];
    assert avoid_spot_type(Vec3(x=64.0), direct, grenade) == AVOID_ALWAYS;
    assert avoid_spot_type(Vec3(x=64.0, y=300.0), round_way, [AvoidSpot(origin=Vec3(x=150.0, y=-200.0), radius=160.0)]) == 0;
    assert avoid_spot_type(Vec3(x=64.0), direct, [AvoidSpot(origin=Vec3(x=150.0), radius=160.0, kind=AVOID_DONTBLOCK)]) == AVOID_DONTBLOCK;
    # A grenade far behind the bot's back is none of its way's business.
    assert avoid_spot_type(Vec3(x=64.0), direct, [AvoidSpot(origin=Vec3(x=-400.0), radius=160.0)]) == 0;
    # BotGetReachabilityToGoal passes the straight passage over.
    usual = plan_route(mesh, Vec3(x=64.0), Vec3(x=192.0));
    assert usual.found and usual.areas[0] == 3;
    far_grenade = [AvoidSpot(origin=Vec3(x=150.0, y=-150.0), radius=160.0)];
    assert avoid_spot_type(Vec3(x=64.0), direct, far_grenade) == AVOID_ALWAYS;
    assert avoid_spot_type(Vec3(x=64.0), round_way, far_grenade) == 0;
    detour = plan_route(mesh, Vec3(x=64.0), Vec3(x=192.0), spots=far_grenade);
    assert detour.found and detour.areas[0] == 2;
}

test "a walk goes by the reachability's start, then on to its end" {
    mesh = build_navmesh(World(), strip_aas(2, [(1, 2, TRAVEL_WALK)]));
    mesh.times_to(2);
    # From the side of area 1 the far end (x = 128) lies ahead and to the
    # right; the bot makes for the start (x = 80, y = 0) first.
    bot = Opponent(arena=True, health=100, pos=Vec3(x=80.0, y=30.0, z=26.0), eye_height=26.0, grounded=True);
    route = plan_route(mesh, Vec3(x=80.0, y=30.0), Vec3(x=128.0));
    first = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert first.result.direction.y < -0.99 and not route.begun;
    # Within 10 units of the start: on for the far end, and no turning back.
    bot.pos = Vec3(x=80.0, y=6.0, z=26.0);
    on = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert on.result.direction.x > 0.99 and route.begun;
    bot.pos = Vec3(x=92.0, y=6.0, z=26.0);
    still = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=0.0);
    assert still.result.direction.x > 0.98;
}
