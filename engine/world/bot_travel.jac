"""How a Q3 bot travels its AAS route, travel type by travel type, after
be_ai_move.c. Most passages only need the bot to head for the next waypoint
(a jump's launch is applied at its takeoff point), and a swimming bot swims
straight for it; rocket and BFG jumps, ladders, water jumps, elevators and
bobbing platforms each have their own BotTravel_* and BotFinishTravel_*
rules, followed here every frame. The result is botlib's
bot_moveresult_t: the direction and speed to move (EA_Move), a jump, an
attack and the weapon it needs, a view the movement sets, and whether the bot
is waiting for a mover."""
import math;
import from .world { Player }
import from .bot_routes { NavMesh, Passage, BotRoute }
import from .navigation { waypoint_reached }
import from ..formats.aas {
    TRAVEL_WALK,
    TRAVEL_CROUCH,
    TRAVEL_BARRIERJUMP,
    TRAVEL_JUMP,
    TRAVEL_LADDER,
    TRAVEL_WALKOFFLEDGE,
    TRAVEL_SWIM,
    TRAVEL_WATERJUMP,
    TRAVEL_TELEPORT,
    TRAVEL_ELEVATOR,
    TRAVEL_ROCKETJUMP,
    TRAVEL_BFGJUMP,
    TRAVEL_JUMPPAD,
    TRAVEL_FUNCBOB
}
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

# bg_public.h DEFAULT_GRAVITY and JUMP_VELOCITY; bg_pmove.c's step height is
# be_ai_move.c's sv_maxbarrier for walking off a mover.
glob TRAVEL_GRAVITY: float = 800.0,
    TRAVEL_JUMP_SPEED: float = 270.0,
    TRAVEL_MAX_BARRIER: float = 32.0;

"""be_ai_move.c bot_moveresult_t for one frame. `direction` and `speed` are
EA_Move's (400 is full speed); `view_set` asks for the ideal view `yaw` and
`pitch` (Quake degrees, pitch down positive; MOVERESULT_MOVEMENTVIEWSET);
`weapon` is the weapon the movement needs (MOVERESULT_MOVEMENTWEAPON);
`waiting` that the bot waits for a mover (MOVERESULT_WAITING); `air_control`
that the bot steers through the air to its landing; `failure` that the leg
timed out and the route has to be planned again."""
obj TravelResult {
    has direction: Vec3 = Vec3(),
        speed: float = 400.0,
        jump: bool = False,
        attack: bool = False,
        weapon: str = "",
        view_set: bool = False,
        yaw: float = 0.0,
        pitch: float = 0.0,
        waiting: bool = False,
        air_control: bool = False,
        failure: bool = False;

    """The share of full running speed EA_Move's speed asks for
    (BotInputToUserCommand scales 400 to a full 127 move)."""
    def speed_scale() -> float {
        return max(0.0, min(1.0, self.speed / 400.0));
    }
}

"""be_ai_move.c BotReachabilityTime: seconds a bot may spend on a passage
before giving it up."""
def reachability_time(kind: int) -> float {
    if kind in [TRAVEL_ELEVATOR, TRAVEL_JUMPPAD, TRAVEL_FUNCBOB] {
        return 10.0;
    }
    if kind in [TRAVEL_LADDER, TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP] {
        return 6.0;
    }
    if kind in [
        TRAVEL_WALK,
        TRAVEL_CROUCH,
        TRAVEL_BARRIERJUMP,
        TRAVEL_WALKOFFLEDGE,
        TRAVEL_JUMP,
        TRAVEL_SWIM,
        TRAVEL_WATERJUMP,
        TRAVEL_TELEPORT
    ] {
        return 5.0;
    }
    return 8.0;
}

"""Passages that need more than heading for their waypoint."""
def special_travel(kind: int) -> bool {
    return kind in [TRAVEL_LADDER, TRAVEL_ELEVATOR, TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP, TRAVEL_FUNCBOB, TRAVEL_WATERJUMP];
}

"""Horizontal unit direction and distance from `origin` to `point`."""
def flat_toward(origin: Vec3, point: Vec3) -> tuple[Vec3, float] {
    gap = Vec3(x=point.x - origin.x, y=point.y - origin.y);
    distance = gap.length();
    if distance < 0.000001 {
        return (Vec3(), 0.0);
    }
    return (gap.scale(1.0 / distance), distance);
}

"""q_math.c AngleDifference folded to [-180, 180)."""
def angle_gap(a: float, b: float) -> float {
    value = (a - b) % 360.0;
    return value - 360.0 if value >= 180.0 else value;
}

"""Vector2Angles' yaw of a horizontal direction, in degrees."""
def yaw_of(direction: Vec3) -> float {
    return math.degrees(math.atan2(direction.y, direction.x)) % 360.0;
}

"""Vector2Angles' pitch of a direction, in Quake degrees (down positive)."""
def pitch_of(direction: Vec3) -> float {
    flat = math.sqrt(direction.x * direction.x + direction.y * direction.y);
    return -math.degrees(math.atan2(direction.z, flat));
}

"""Swimming toward `point` (BotTravel_Swim, and walking or moving in the
goal area with MFL_SWIMMING): straight at it, up or down, looking along the
way (MOVERESULT_SWIMVIEW)."""
def travel_swim(origin: Vec3, point: Vec3) -> TravelResult {
    direction = point.sub(origin).normalized();
    return TravelResult(direction=direction, speed=400.0, view_set=True, yaw=yaw_of(direction), pitch=pitch_of(direction));
}

"""BotTravel_WaterJump: swim forward for the far end looking 15 units above
it (botlib tilts the view by up to 40 more at random), and move up too once
within 40 units of it, so the pmove's water jump (PM_CheckWaterJump) lifts
the bot out once it faces the ledge at waist depth."""
def travel_water_jump(origin: Vec3, passage: Passage) -> TravelResult {
    look = passage.finish.sub(origin).add(Vec3(z=15.0));
    forward = look.normalized();
    direction = forward;
    if flat_toward(origin, passage.finish)[1] < 40.0 {
        direction = forward.add(Vec3(z=1.0)).normalized();
    }
    return TravelResult(direction=direction, speed=400.0, view_set=True, yaw=yaw_of(look), pitch=pitch_of(look));
}

"""be_ai_move.c BotAirControl: predict the fall in tenths of a second; once
it would drop below `goal`, steer for the goal from that landing point, at a
speed of 13 a unit up to 32 units off. None when the bot will not come down
to the goal's height within five seconds."""
def air_control(origin: Vec3, velocity: Vec3, goal: Vec3) -> TravelResult | None {
    point = origin.add(Vec3());
    step = velocity.scale(0.1);
    for i in range(50) {
        step.z -= TRAVEL_GRAVITY * 0.01;
        if step.z < 0.0 and point.z + step.z < goal.z {
            point = point.add(step.scale((goal.z - point.z) / step.z));
            gap = goal.sub(point);
            distance = gap.length();
            direction = gap.scale(1.0 / distance) if distance > 0.000001 else Vec3();
            return TravelResult(direction=direction, speed=13.0 * min(distance, 32.0), air_control=True);
        }
        point = point.add(step);
    }
    return None;
}

"""The world box of the mover with BSP `model` right now: its model bounds
moved by the offset its collision hulls carry (AAS_BSPModelMinsMaxsOrigin
and AAS_OriginOfMoverWithModelNum). None when the map has no such mover."""
def mover_box(mesh: NavMesh, collision: CollisionMap, model: int) -> AABB | None {
    if model not in mesh.mover_bounds {
        return None;
    }
    for i in range(len(collision.models)) {
        if collision.models[i] == model {
            bounds = mesh.mover_bounds[model];
            offset = collision.offsets[i];
            return AABB(mins=bounds.mins.add(offset), maxs=bounds.maxs.add(offset));
        }
    }
    return None;
}

"""be_ai_move.c BotOnMover: whether the bot at `origin` stands on the mover
with BSP `model`: within its bounds (16 units of slack) and with that model
the first thing under its feet."""
def on_mover(collision: CollisionMap, box: AABB, model: int, origin: Vec3) -> bool {
    if origin.x > box.maxs.x + 16.0
        or origin.x < box.mins.x - 16.0
        or origin.y > box.maxs.y + 16.0
        or origin.y < box.mins.y - 16.0 {
        return False;
    }
    floor = collision.trace(origin, origin.sub(Vec3(z=48.0)));
    return not floor.start_solid and floor.fraction < 1.0 and floor.model == model;
}

"""be_ai_move.c MoverBottomCenter: the middle of the mover's top at the
height of the passage's start."""
def mover_bottom_center(box: AABB, passage: Passage) -> Vec3 {
    return Vec3(x=(box.mins.x + box.maxs.x) * 0.5, y=(box.mins.y + box.maxs.y) * 0.5, z=passage.start.z);
}

"""The centre of a bobbing platform along its bobbing axis right now."""
def bob_position(box: AABB, axis: int) -> float {
    if axis == 0 {
        return (box.mins.x + box.maxs.x) * 0.5;
    }
    if axis == 1 {
        return (box.mins.y + box.maxs.y) * 0.5;
    }
    return (box.mins.z + box.maxs.z) * 0.5;
}

"""Step toward a point, slowing within reach of it: EA_Move's speed is
`rate` a unit of distance up to `cap` units away (the "400 - (400 - n *
dist)" of be_ai_move.c)."""
def approach(origin: Vec3, point: Vec3, rate: float, cap: float) -> TravelResult {
    toward = flat_toward(origin, point);
    return TravelResult(direction=toward[0], speed=rate * min(toward[1], cap));
}

"""BotTravel_RocketJump / BotTravel_BFGJump on the ground: walk to the
passage's start looking straight down, and once there with the view down
(within 5 degrees) jump, fire and run for the far end."""
def travel_weapon_jump(origin: Vec3, passage: Passage, view_yaw: float, view_pitch: float, weapon: str) -> TravelResult {
    toward = flat_toward(origin, passage.start);
    result = TravelResult(weapon=weapon, view_set=True, pitch=90.0);
    result.yaw = yaw_of(toward[0]) if toward[1] > 0.000001 else view_yaw;
    if toward[1] < 5.0
        and abs(angle_gap(result.pitch, view_pitch)) < 5.0
        and abs(angle_gap(result.yaw, view_yaw)) < 5.0 {
        run = flat_toward(origin, passage.finish);
        result.direction = run[0];
        result.speed = 800.0;
        result.jump = True;
        result.attack = True;
        result.yaw = yaw_of(run[0]) if run[1] > 0.000001 else result.yaw;
        return result;
    }
    result.direction = toward[0];
    result.speed = 5.0 * min(toward[1], 80.0);
    return result;
}

"""BotFinishTravel_WeaponJump: through the air, steer for the landing."""
def finish_weapon_jump(origin: Vec3, velocity: Vec3, passage: Passage) -> TravelResult {
    steer = air_control(origin, velocity, passage.finish);
    if steer is not None {
        return steer;
    }
    toward = flat_toward(origin, passage.finish);
    return TravelResult(direction=toward[0], speed=400.0, air_control=True);
}

"""BotTravel_Ladder: face up (or down) the ladder toward the far end and
move forward."""
def travel_ladder(origin: Vec3, passage: Passage) -> TravelResult {
    gap = passage.finish.sub(origin);
    direction = gap.normalized();
    look = Vec3(x=direction.x, y=direction.y, z=3.0 * direction.z);
    flat = math.sqrt(look.x * look.x + look.y * look.y);
    return TravelResult(
        direction=direction,
        speed=400.0,
        view_set=True,
        yaw=yaw_of(look),
        pitch=-math.degrees(math.atan2(look.z, flat))
    );
}

"""The approach to a mover shared by BotTravel_Elevator and
BotTravel_FuncBobbing while the bot is not on it. Near the far end, walk
there; while the mover is away (`ready` false), wait at the passage's
start; otherwise step onto the middle of the mover, or first to the start
when that is nearer."""
def board_mover(origin: Vec3, passage: Passage, box: AABB, ready: bool) -> TravelResult {
    near_end = passage.finish.sub(origin);
    if near_end.length() < 64.0 {
        return TravelResult(direction=near_end.normalized(), speed=6.0 * min(near_end.length(), 60.0));
    }
    to_start = flat_toward(origin, passage.start);
    if not ready {
        result = TravelResult(direction=to_start[0], speed=6.0 * min(to_start[1], 60.0), waiting=True);
        if result.speed <= 5.0 {
            result.direction = Vec3();
            result.speed = 0.0;
        }
        return result;
    }
    to_center = flat_toward(origin, mover_bottom_center(box, passage));
    if to_start[1] < 20.0 or to_center[1] < to_start[1] or to_start[0].dot(to_center[0]) < 0.0 {
        return TravelResult(direction=to_center[0], speed=6.0 * min(to_center[1], 60.0));
    }
    return TravelResult(direction=to_start[0], speed=6.0 * min(to_start[1], 60.0));
}

"""On the mover, BotTravel_Elevator and BotTravel_FuncBobbing: once it has
carried the bot to the far end (`arrived`) walk off toward the passage's
end; until then stand on its middle."""
def ride_mover(origin: Vec3, passage: Passage, box: AABB, arrived: bool) -> TravelResult {
    if arrived {
        toward = flat_toward(origin, passage.finish);
        return TravelResult(direction=toward[0], speed=400.0);
    }
    to_center = flat_toward(origin, mover_bottom_center(box, passage));
    if to_center[1] > 10.0 {
        return TravelResult(direction=to_center[0], speed=4.0 * min(to_center[1], 100.0));
    }
    return TravelResult(speed=0.0);
}

"""BotTravel_Elevator on the ground and BotFinishTravel_Elevator in the air.
A plat is ready to board when its top is below the passage's start
(MoverDown); a bot on it waits until it is within a step of the far end."""
def travel_elevator(mesh: NavMesh, collision: CollisionMap, origin: Vec3, grounded: bool, passage: Passage) -> TravelResult {
    box = mover_box(mesh, collision, passage.model);
    if box is None {
        return TravelResult(failure=True);
    }
    if not grounded {
        bottom = mover_bottom_center(box, passage).sub(origin);
        top = passage.finish.sub(origin);
        aim = bottom if abs(bottom.z) < abs(top.z) else top;
        return TravelResult(direction=aim.normalized(), speed=300.0);
    }
    if on_mover(collision, box, passage.model, origin) {
        return ride_mover(origin, passage, box, abs(origin.z - passage.finish.z) < TRAVEL_MAX_BARRIER);
    }
    return board_mover(origin, passage, box, box.maxs.z < passage.start.z);
}

"""BotTravel_FuncBobbing on the ground and BotFinishTravel_FuncBobbing in
the air. The platform is at this passage's near end when its centre is
within 16 units of it, and has carried the bot across within 24 units of the
far end (BotFuncBobStartEnd)."""
def travel_funcbob(mesh: NavMesh, collision: CollisionMap, origin: Vec3, grounded: bool, passage: Passage) -> TravelResult {
    box = mover_box(mesh, collision, passage.model);
    if box is None {
        return TravelResult(failure=True);
    }
    where = bob_position(box, passage.axis);
    if not grounded {
        if abs(where - passage.far) < 16.0 {
            toward = flat_toward(origin, passage.finish);
            return TravelResult(direction=toward[0], speed=6.0 * min(toward[1], 60.0));
        }
        to_center = flat_toward(origin, mover_bottom_center(box, passage));
        if to_center[1] > 5.0 {
            return TravelResult(direction=to_center[0], speed=4.0 * min(to_center[1], 100.0));
        }
        return TravelResult(speed=0.0);
    }
    if on_mover(collision, box, passage.model, origin) {
        return ride_mover(origin, passage, box, abs(where - passage.far) < 24.0);
    }
    return board_mover(origin, passage, box, abs(where - passage.near) <= 16.0);
}

"""One frame of BotMoveToGoal along an AAS route for a bot at eye `bot.pos`.
Waypoints are done on reaching them or on entering their target area; a
special passage is done on entering its target area and runs its own travel
until then. A jump's launch is applied from the ground at its takeoff (the
returned `launch`). A passage the bot has spent longer on than
BotReachabilityTime allows fails, so the route is planned again."""
walker FollowRoute {
    has mesh: NavMesh,
        collision: CollisionMap,
        route: BotRoute,
        eye_height: float,
        clock: float,
        view_yaw: float = 0.0,
        view_pitch: float = 0.0,
        result: TravelResult = TravelResult(),
        launch: Vec3 | None = None;

    can travel with Player entry {
        route = self.route;
        origin = here.pos.sub(Vec3(z=self.eye_height));
        standing = self.mesh.locate(origin);
        while route.points {
            passage = route.passages[0] if route.passages else None;
            if passage is not None and special_travel(passage.kind) {
                if standing != route.areas[0] {
                    break;
                }
            } elif not (
                waypoint_reached(route.points[0], origin, True)
                    or (route.areas[0] > 0 and standing == route.areas[0])
            ) {
                break;
            }
            if route.launches and route.launches[0].z > 0.0 {
                if not here.grounded {
                    break;
                }
                self.launch = route.launches[0];
            }
            route.advance(self.clock);
            if self.launch is not None {
                break;
            }
        }
        if not route.points {
            self.result = TravelResult(speed=0.0);
            return;
        }
        if route.leg_started < 0.0 {
            route.leg_started = self.clock;
        }
        passage = route.passages[0] if route.passages else None;
        kind = passage.kind if passage is not None else TRAVEL_WALK;
        if self.clock - route.leg_started > reachability_time(kind) {
            self.result = TravelResult(failure=True);
            return;
        }
        if passage is not None and passage.kind in [TRAVEL_ROCKETJUMP, TRAVEL_BFGJUMP] {
            weapon = "rocketlauncher" if passage.kind == TRAVEL_ROCKETJUMP else "bfg";
            if here.grounded {
                self.result = travel_weapon_jump(origin, passage, self.view_yaw, self.view_pitch, weapon);
                if self.result.jump {
                    route.jumped = True;
                }
            } elif route.jumped {
                self.result = finish_weapon_jump(origin, here.velocity, passage);
            } else {
                self.result = TravelResult(speed=0.0);
            }
            return;
        }
        if passage is not None and passage.kind == TRAVEL_LADDER {
            self.result = travel_ladder(origin, passage);
            return;
        }
        if passage is not None and passage.kind == TRAVEL_WATERJUMP {
            self.result = travel_water_jump(origin, passage);
            return;
        }
        if passage is not None and passage.kind in [TRAVEL_ELEVATOR, TRAVEL_FUNCBOB] {
            if passage.kind == TRAVEL_ELEVATOR {
                self.result = travel_elevator(self.mesh, self.collision, origin, here.grounded, passage);
            } else {
                self.result = travel_funcbob(self.mesh, self.collision, origin, here.grounded, passage);
            }
            # A bot riding the mover keeps its passage (the special elevator
            # case of BotMoveToGoal gives it five more seconds).
            box = mover_box(self.mesh, self.collision, passage.model);
            if box is not None and on_mover(self.collision, box, passage.model, origin) {
                route.leg_started = max(route.leg_started, self.clock - reachability_time(passage.kind) + 5.0);
            }
            return;
        }
        # MFL_SWIMMING: the bot swims (AAS_Swimming, its waist in liquid).
        if here.water_depth >= 2 {
            self.result = travel_swim(origin, route.points[0]);
            return;
        }
        toward = flat_toward(origin, route.points[0]);
        self.result = TravelResult(direction=toward[0], speed=400.0);
    }
}
