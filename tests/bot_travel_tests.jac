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
    TRAVEL_WATERJUMP,
    TRAVEL_ROCKETJUMP,
    TRAVEL_FUNCBOB,
    TFL_DEFAULT,
    TFL_ROCKETJUMP,
    TFL_LAVA
}
import from engine.world.bot_routes { NavMesh, Passage, Exits, BotRoute, build_navmesh, plan_route, area_travel_time, bob_ends, UNREACHED }
import from engine.world.bot_travel {
    FollowRoute,
    TravelResult,
    travel_weapon_jump,
    travel_funcbob,
    travel_water_jump,
    air_control,
    mover_box
}
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
    # A leg taking longer than BotReachabilityTime fails.
    late = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=route, eye_height=26.0, clock=7.0, view_pitch=89.0);
    assert late.result.failure;
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
    # The route follower hands the leg to the water jump until area 3.
    bot.pos = Vec3(x=150.0, z=26.0);
    bot.water_depth = 2;
    jump = BotRoute();
    jump.add(passage.finish, 3, passage=passage);
    out = bot spawn FollowRoute(mesh=mesh, collision=CollisionMap(), route=jump, eye_height=26.0, clock=0.0);
    assert out.result.view_set and len(jump.points) == 1 and out.result.direction.x > 0.0;
}
