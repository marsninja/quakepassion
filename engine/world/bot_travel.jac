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
import from .bot_routes { NavMesh, Passage, BotRoute, AvoidReach, jump_launch }
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
    TRAVEL_FUNCBOB,
    PRESENCE_NORMAL
}
import from ..formats.botconfig { WeightDice }
import from .liquids { LiquidProbe }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

# bg_public.h DEFAULT_GRAVITY and JUMP_VELOCITY; be_ai_move.c's sv_maxbarrier
# for walking off a mover and sv_maxstep (bg_pmove.c's STEPSIZE).
glob TRAVEL_JUMP_SPEED: float = 270.0,
    TRAVEL_MAX_BARRIER: float = 32.0,
    TRAVEL_MAX_STEP: float = 18.0;

"""The gravity bots predict their jumps and falls by: DEFAULT_GRAVITY,
or the level's own (Quake's e1m8), set as a bot reads a level."""
obj TravelPhysics {
    has gravity: float = 800.0;
}

glob _travel: TravelPhysics = TravelPhysics();

def set_travel_gravity(gravity: float) {
    _travel.gravity = gravity if gravity > 0.0 else 800.0;
}

"""be_ai_move.c bot_moveresult_t for one frame. `direction` and `speed` are
EA_Move's (400 is full speed); `view_set` asks for the ideal view `yaw` and
`pitch` (Quake degrees, pitch down positive; MOVERESULT_MOVEMENTVIEWSET);
`weapon` is the weapon the movement needs (MOVERESULT_MOVEMENTWEAPON);
`waiting` that the bot waits for a mover (MOVERESULT_WAITING); `air_control`
that the bot steers through the air to its landing; `crouch` that it ducks
(EA_Crouch); `failure` that the leg
timed out and the route has to be planned again. `blocked` says something
other than the world stands in the bot's way (BotCheckBlocked): the mover
with BSP model `block_model`, or another player when that is 0; `on_top`
that the bot stands on it (MOVERESULT_ONTOPOFOBSTACLE); `in_solid` that the
bot is in no AAS area at all (RESULTTYPE_INSOLIDAREA)."""
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
        failure: bool = False,
        crouch: bool = False,
        blocked: bool = False,
        block_model: int = 0,
        on_top: bool = False,
        in_solid: bool = False;

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

"""Whether a player's box at `origin` overlaps another player's at `other`
(bg_public.h's 30 by 30 by 56 box about each origin)."""
def bodies_overlap(origin: Vec3, other: Vec3) -> bool {
    return abs(origin.x - other.x) < 30.0 and abs(origin.y - other.y) < 30.0 and abs(origin.z - other.z) < 56.0;
}

"""be_ai_move.c BotCheckBlocked: whether something other than the world
stands within 3 units of the bot along `direction`. The bot's box is traced
with its bottom raised a step and its top lowered 10 units when the
direction is not steep, against the map's movers and the boxes of the other
players at `bodies` (their origins). Sets `result.blocked` and what blocks:
the mover's BSP model, or 0 for a player."""
def check_blocked(collision: CollisionMap, origin: Vec3, direction: Vec3, bodies: list[Vec3], result: TravelResult) {
    mins = collision.hull_mins.add(Vec3());
    maxs = collision.hull_maxs.add(Vec3());
    if abs(direction.z) < 0.7 {
        mins.z += TRAVEL_MAX_STEP;
        maxs.z -= 10.0;
    }
    finish = origin.add(direction.scale(3.0));
    hit = collision.for_body(collision.eye_height, 0.0, mins, maxs).trace(origin, finish);
    if hit.start_solid {
        return;
    }
    reached = origin.lerp(finish, hit.fraction);
    for body in bodies {
        if bodies_overlap(reached, body) and not bodies_overlap(origin, body) {
            result.blocked = True;
            result.block_model = 0;
            return;
        }
    }
    if hit.fraction < 1.0 and hit.model > 0 {
        result.blocked = True;
        result.block_model = hit.model;
    }
}

"""be_ai_move.c BotGapDistance: how far ahead along `direction` the floor
falls away, 0 when it does not within 100 units. The crouching player's box
is dropped onto the floor every 8 units; a landing more than a step and 8
units under the last is a gap, unless water lies 20 units under it (bots
walk into pools). With no floor within 60 units under the bot itself the
answer is 1."""
def gap_distance(collision: CollisionMap, origin: Vec3, direction: Vec3, liquids: LiquidProbe | None = None) -> float {
    box = collision.for_body(collision.eye_height, 0.0, Vec3(x=-15.0, y=-15.0, z=-24.0), Vec3(x=15.0, y=15.0, z=8.0));
    under = box.trace(origin, origin.sub(Vec3(z=60.0)));
    if under.fraction >= 1.0 {
        return 1.0;
    }
    level = under.end.z + 1.0;
    dist = 8.0;
    while dist <= 100.0 {
        start = Vec3(x=origin.x + direction.x * dist, y=origin.y + direction.y * dist, z=level + 24.0);
        drop = box.trace(start, start.sub(Vec3(z=48.0 + TRAVEL_MAX_BARRIER)));
        if not drop.start_solid {
            if drop.end.z < level - TRAVEL_MAX_STEP - 8.0 {
                if liquids is not None and liquids.kind_at(drop.end.sub(Vec3(z=20.0))) == 1 {
                    return 0.0;
                }
                return dist;
            }
            level = drop.end.z;
        }
        dist += 8.0;
    }
    return 0.0;
}

"""Where a predicted jump ends (be_aas_move.c aas_clientmove_t): the point,
the velocity there, the tenths of a second it took, and what stopped it:
the ground, a landing hard enough to hurt, or a liquid at the feet (1
water, 2 slime, 3 lava). `frames` is 30 when nothing did."""
obj JumpLanding {
    has point: Vec3 = Vec3(),
        velocity: Vec3 = Vec3(),
        frames: int = 30,
        ground: bool = False,
        hurt: bool = False,
        liquid: int = 0;
}

"""be_aas_move.c AAS_PredictClientMovement as BotWalkInDirection asks it
about a jump from the ground along `direction`: tenths of a second, three
seconds at most (PREDICTIONTIME_JUMP). The first frame takes the ground's
friction off the bot's `velocity`, jumps (270, less the frame's gravity,
plus 5 a frame "for safety") and accelerates toward the direction as in the
air (phys_airaccelerate 1, to 320); the rest fly under gravity. Each frame
sweeps the player's box, clips the velocity off what it hits and steps up
19 units onto what a wall carries (not within two frames of the jump). It
ends on the ground (AAS_OnGround, 10 units under the box), on a hit that
takes more than 632 units a second off the fall (SE_HITGROUNDDAMAGE), or
with a liquid 22 units under the origin once the bot rises at no more than
100 units a second."""
def predict_jump(
    collision: CollisionMap, origin: Vec3, velocity: Vec3, direction: Vec3, liquids: LiquidProbe | None = None
) -> JumpLanding {
    # BotWalkInDirection lifts the origin 0.5, the prediction 0.25 more.
    point = origin.add(Vec3(z=0.75));
    # The velocity a frame, as the original keeps it.
    step = velocity.scale(0.1);
    grounded = True;
    for n in range(30) {
        step.z -= _travel.gravity * 0.01;
        if n == 0 {
            speed = math.sqrt(step.x * step.x + step.y * step.y) * 10.0;
            if speed > 0.0 {
                keep = max(0.0, speed - 0.1 * max(speed, 100.0) * 6.0) / speed;
                step.x *= keep;
                step.y *= keep;
            }
            step.z = TRAVEL_JUMP_SPEED * 0.1 - _travel.gravity * 0.01 + 5.0;
            add = 320.0 - (step.x * direction.x + step.y * direction.y) * 10.0;
            if add > 0.0 {
                gain = min(32.0, add) * 0.1;
                step.x += direction.x * gain;
                step.y += direction.y * gain;
            }
        }
        left = step.add(Vec3());
        tries = 0;
        while True {
            target = point.add(left);
            hit = collision.trace(point, target);
            if hit.start_solid {
                return JumpLanding(point=point);
            }
            point = hit.end;
            if hit.fraction >= 1.0 {
                break;
            }
            stepped = False;
            if hit.normal.z == 0.0 and n > 2 {
                foot = point.sub(hit.normal.scale(0.25));
                rise = collision.trace(foot.add(Vec3(z=19.0)), foot);
                if not rise.start_solid and rise.fraction < 1.0 and rise.normal.z > 0.7 {
                    left = Vec3(x=target.x - rise.end.x, y=target.y - rise.end.y);
                    step.z = 0.0;
                    point = Vec3(x=point.x, y=point.y, z=rise.end.z);
                    stepped = True;
                }
            }
            if not stepped {
                before = step.z;
                left = left.sub(hit.normal.scale(left.dot(hit.normal)));
                step = step.sub(hit.normal.scale(step.dot(hit.normal)));
                if hit.normal.z > 0.7 {
                    grounded = True;
                }
                delta = 0.0;
                if before < 0.0 and step.z > before and not grounded {
                    delta = before;
                } elif grounded {
                    delta = step.z - before;
                }
                # "delta = delta * 10; delta = delta * delta * 0.0001".
                if delta * delta * 0.01 > 40.0 {
                    return JumpLanding(point=point, velocity=step.scale(10.0), frames=n, hurt=True);
                }
            }
            tries += 1;
            if tries > 20 {
                return JumpLanding(point=point);
            }
        }
        if step.z <= 10.0 and liquids is not None {
            kind = liquids.kind_at(point.sub(Vec3(z=22.0)));
            if kind != 0 {
                return JumpLanding(point=point, velocity=step.scale(10.0), frames=n, liquid=kind);
            }
        }
        floor = collision.trace(point, point.sub(Vec3(z=10.0)));
        grounded = not floor.start_solid and floor.fraction < 1.0 and floor.normal.z >= 0.7;
        if grounded {
            return JumpLanding(point=point, velocity=step.scale(10.0), frames=n, ground=True);
        }
    }
    return JumpLanding(point=point);
}

"""be_ai_move.c BotMoveInGoalArea's speed: in its goal's area a bot slows
over the last 100 units (4 a unit) and stops within 2.5."""
def goal_area_speed(distance: float) -> float {
    speed = 4.0 * min(distance, 100.0);
    return 0.0 if speed < 10.0 else speed;
}

"""Swimming toward `point` (BotTravel_Swim, and walking or moving in the
goal area with MFL_SWIMMING): straight at it, up or down, looking along the
way (MOVERESULT_SWIMVIEW)."""
def travel_swim(origin: Vec3, point: Vec3) -> TravelResult {
    direction = point.sub(origin).normalized();
    return TravelResult(direction=direction, speed=400.0, view_set=True, yaw=yaw_of(direction), pitch=pitch_of(direction));
}

"""The forward vector of a view of `yaw` and `pitch` (Quake degrees, pitch
down positive)."""
def view_forward(yaw: float, pitch: float) -> Vec3 {
    level = math.cos(math.radians(pitch));
    return Vec3(x=math.cos(math.radians(yaw)) * level, y=math.sin(math.radians(yaw)) * level, z=-math.sin(math.radians(pitch)));
}

"""BotTravel_WaterJump: look 15 units above the far end, give or take up to
40 at random (`roll`, a crandom() in -1..1), and swim forward
(EA_MoveForward): along the view the bot has now (`view`), which turns
toward the one it wants; without one, along the wanted view. Within 40 units
of the far end it moves up too (EA_MoveUp), so the pmove's water jump
(PM_CheckWaterJump) lifts the bot out once it faces the ledge at waist
depth."""
def travel_water_jump(origin: Vec3, passage: Passage, roll: float = 0.0, view: Vec3 | None = None) -> TravelResult {
    look = passage.finish.sub(origin).add(Vec3(z=15.0 + roll * 40.0));
    forward = view if view is not None else look.normalized();
    direction = forward;
    if flat_toward(origin, passage.finish)[1] < 40.0 {
        direction = forward.add(Vec3(z=1.0)).normalized();
    }
    return TravelResult(direction=direction, speed=400.0, view_set=True, yaw=yaw_of(look), pitch=pitch_of(look));
}

"""BotFinishTravel_WaterJump, for a bot that has left the water's surface
with its feet still in it (`wet`): on for the far end, aiming 70 units above
it with up to 10 units of random error each way (`rolls`, three crandom()s),
looking where it goes. Out of the water altogether it makes no move."""
def finish_water_jump(origin: Vec3, passage: Passage, wet: bool, rolls: list[float]) -> TravelResult {
    if not wet {
        return TravelResult(speed=0.0);
    }
    aim = passage.finish.sub(origin).add(Vec3(x=rolls[0] * 10.0, y=rolls[1] * 10.0, z=70.0 + rolls[2] * 10.0));
    direction = aim.normalized();
    return TravelResult(direction=direction, speed=400.0, view_set=True, yaw=yaw_of(direction), pitch=pitch_of(direction));
}

"""be_ai_move.c BotAirControl: predict the fall in tenths of a second; once
it would drop below `goal`, steer for the goal from that landing point, at a
speed of 13 a unit up to 32 units off. None when the bot will not come down
to the goal's height within five seconds."""
def air_control(origin: Vec3, velocity: Vec3, goal: Vec3) -> TravelResult | None {
    point = origin.add(Vec3());
    step = velocity.scale(0.1);
    for i in range(50) {
        step.z -= _travel.gravity * 0.01;
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

"""be_aas_move.c AAS_HorizontalVelocityForJump for a fall (no jump): the
horizontal speed that carries a body dropping from `start` to `finish`, or
None when `finish` is higher or the speed would be over phys_maxvelocity
(320)."""
def fall_speed(start: Vec3, finish: Vec3) -> float | None {
    drop = start.z - finish.z;
    if drop < 0.0 {
        return None;
    }
    falling = math.sqrt(drop / (0.5 * _travel.gravity));
    if falling == 0.0 {
        return None;
    }
    speed = flat_toward(start, finish)[1] / falling;
    return speed if speed <= 320.0 else None;
}

"""BotTravel_WalkOffLedge on the ground. Further than 48 units from the
ledge the bot walks for the passage's start, at full speed, or slowing over
the last 64 units when the drop is straight down (its two ends within 20
units of each other level). Within 48 units it heads for the far end: at
100 when the drop is straight down, otherwise at the speed that carries the
fall there (full speed when there is none)."""
def travel_walk_off_ledge(origin: Vec3, passage: Passage) -> TravelResult {
    across = flat_toward(passage.start, passage.finish)[1];
    to_start = flat_toward(origin, passage.start);
    if to_start[1] < 48.0 {
        carried = fall_speed(passage.start, passage.finish);
        speed = 100.0 if across < 20.0 else (carried if carried is not None else 400.0);
        return TravelResult(direction=flat_toward(origin, passage.finish)[0], speed=speed);
    }
    speed = 400.0 - (256.0 - 4.0 * min(to_start[1], 64.0)) if across < 20.0 else 400.0;
    return TravelResult(direction=to_start[0], speed=speed);
}

"""BotFinishTravel_WalkOffLedge in the air: steer for a point 16 units past
the far end along the bot's way there (BotAirControl), or straight for the
far end when the fall will not bring it down to that height."""
def finish_walk_off_ledge(origin: Vec3, velocity: Vec3, passage: Passage) -> TravelResult {
    toward = flat_toward(origin, passage.finish);
    landing = passage.finish.add(toward[0].scale(16.0)) if toward[1] > 16.0 else passage.finish;
    steer = air_control(origin, velocity, landing);
    if steer is not None {
        return steer;
    }
    return TravelResult(direction=toward[0], speed=400.0, air_control=True);
}

"""BotFinishTravel_JumpPad: thrown by the pad, the bot steers for the
passage's far end (BotAirControl), or straight for it when its fall will not
bring it down to that height."""
def finish_jump_pad(origin: Vec3, velocity: Vec3, passage: Passage) -> TravelResult {
    steer = air_control(origin, velocity, passage.finish);
    if steer is not None {
        return steer;
    }
    return TravelResult(direction=flat_toward(origin, passage.finish)[0], speed=400.0, air_control=True);
}

"""A bot in the air on its way down to a jump pad it has not touched: in
BotMoveToGoal's air half it is still on the way it came, which ends at the
pad, so it steers for the pad's start (BotAirControl)."""
def approach_jump_pad(origin: Vec3, velocity: Vec3, passage: Passage) -> TravelResult {
    steer = air_control(origin, velocity, passage.start);
    if steer is not None {
        return steer;
    }
    return TravelResult(direction=flat_toward(origin, passage.start)[0], speed=400.0, air_control=True);
}

"""BotMoveToGoal's "special handling of jump pads" for a bot in the air:
whether it has been in `area` over its last two think times, by the areas
on the line back along its velocity (AAS_TraceAreas)."""
def came_through(mesh: NavMesh, origin: Vec3, velocity: Vec3, area: int) -> bool {
    for i in range(17) {
        if mesh.aas.area_at(origin.sub(velocity.scale(0.2 * float(i) / 16.0))) == area {
            return True;
        }
    }
    return False;
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

# How far a brush grown by the player's box (and a unit more) reaches round
# it: an origin inside the grown box touches the brush. Below and beside,
# and above.
glob BODY_REACH_BELOW: Vec3 = Vec3(x=17.0, y=17.0, z=33.0),
    BODY_REACH_ABOVE: Vec3 = Vec3(x=17.0, y=17.0, z=25.0);

"""`count` flat directions evenly round, the first along x."""
def compass(count: int) -> list[Vec3] {
    return [
        Vec3(x=math.cos(float(k) * 2.0 * math.pi / float(count)), y=math.sin(float(k) * 2.0 * math.pi / float(count)))
        for k in range(count)
    ];
}

"""Whether `origin` is over the flat footprint `lo`..`hi`."""
def over_footprint(origin: Vec3, lo: Vec3, hi: Vec3) -> bool {
    return origin.x > lo.x and origin.x < hi.x and origin.y > lo.y and origin.y < hi.y;
}

"""Of `ways` (flat directions), the one that leaves the flat box `lo`..`hi`
soonest by a clear way (room traced out to at most `cap`), else the one with
the most room; None when there are no ways."""
def soonest_out(collision: CollisionMap, origin: Vec3, lo: Vec3, hi: Vec3, ways: list[Vec3], cap: float) -> Vec3 | None {
    best: Vec3 | None = None;
    best_score = 1.0e9;
    for way in ways {
        out = 1.0e9;
        if way.x > 0.001 {
            out = min(out, (hi.x - origin.x) / way.x);
        } elif way.x < -0.001 {
            out = min(out, (lo.x - origin.x) / way.x);
        }
        if way.y > 0.001 {
            out = min(out, (hi.y - origin.y) / way.y);
        } elif way.y < -0.001 {
            out = min(out, (lo.y - origin.y) / way.y);
        }
        reach = min(out, cap) + 8.0;
        room = collision.trace(origin, origin.add(way.scale(reach))).fraction * reach;
        score = out if room >= out else 10000.0 - room;
        if score < best_score {
            best_score = score;
            best = way;
        }
    }
    return best;
}

"""The way out from under a mover's footprint (grown by the player's box):
of eight ways, the one that leaves it soonest with clear room to do so,
else the one with the most room; straight away from its middle when
there is no collision to ask."""
def out_of_footprint(origin: Vec3, box: AABB, passage: Passage, collision: CollisionMap | None) -> Vec3 {
    away = flat_toward(mover_bottom_center(box, passage), origin)[0];
    if collision is None {
        return away;
    }
    way = soonest_out(collision, origin, box.mins.sub(BODY_REACH_BELOW), box.maxs.add(BODY_REACH_ABOVE), compass(8), 300.0);
    return way if way is not None else away;
}

"""The approach to a mover shared by BotTravel_Elevator and
BotTravel_FuncBobbing while the bot is not on it. Near the far end, walk
there; while the mover is away (`ready` false), wait at the passage's
start; otherwise step onto the middle of the mover, or first to the start
when that is nearer."""
def board_mover(origin: Vec3, passage: Passage, box: AABB, ready: bool, collision: CollisionMap | None = None) -> TravelResult {
    near_end = passage.finish.sub(origin);
    if near_end.length() < 64.0 {
        return TravelResult(direction=near_end.normalized(), speed=6.0 * min(near_end.length(), 60.0));
    }
    to_start = flat_toward(origin, passage.start);
    if not ready {
        # Waiting, clear of where it comes down: a body under its edge
        # stops it and sends it back up (plat_crush).
        if over_footprint(origin, box.mins.sub(BODY_REACH_BELOW), box.maxs.add(BODY_REACH_ABOVE)) {
            return TravelResult(direction=out_of_footprint(origin, box, passage, collision), speed=200.0, waiting=True);
        }
        # A margin past that, held still: stepping back in turns it back.
        margin = Vec3(x=24.0, y=24.0);
        if over_footprint(origin, box.mins.sub(margin), box.maxs.add(margin)) {
            return TravelResult(speed=0.0, waiting=True);
        }
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
    # On its middle, waiting to be carried there.
    return TravelResult(speed=0.0, waiting=True);
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
    return board_mover(origin, passage, box, box.maxs.z < passage.start.z, collision);
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
    return board_mover(origin, passage, box, abs(where - passage.near) <= 16.0, collision);
}

"""One frame of BotMoveToGoal along an AAS route for a bot at eye `bot.pos`.
Waypoints are done on reaching them or on entering their target area; a
special passage is done on entering its target area and runs its own travel
until then. A jump's launch is applied from the ground at its takeoff (the
returned `launch`). Each passage set out on goes on the bot's avoid list
(`avoid`). A passage the bot has spent longer on than BotReachabilityTime
allows is given up and the route emptied, to be planned again from where the
bot is; it fails only when no way is found then."""
walker FollowRoute {
    has mesh: NavMesh,
        collision: CollisionMap,
        route: BotRoute,
        eye_height: float,
        clock: float,
        view_yaw: float = 0.0,
        view_pitch: float = 0.0,
        dt: float = 0.0,
        bodies: list[Vec3] = [],
        dice: WeightDice | None = None,
        ducked: bool = False,
        liquids: LiquidProbe | None = None,
        avoid: AvoidReach | None = None,
        result: TravelResult = TravelResult(),
        launch: Vec3 | None = None;

    """BotMoveToGoal's first test, for a bot on the ground on top of
    something that is not the world (BotOnTopOfEntity, 3 units under it). A
    plat or bobbing platform with reachabilities carries it. On another
    mover with no reachability area under the bot, or on another player, the
    bot is blocked on top of an obstacle and makes no move of its own."""
    def on_obstacle(origin: Vec3, standing: int) -> bool {
        floor = self.collision.trace(origin, origin.sub(Vec3(z=3.0)));
        if not floor.start_solid and floor.fraction < 1.0 and floor.model > 0 {
            if floor.model in self.mesh.mover_bounds
                or (standing > 0 and self.mesh.aas.areas[standing].reach_count > 0) {
                return False;
            }
            self.result = TravelResult(speed=0.0, blocked=True, block_model=floor.model, on_top=True);
            return True;
        }
        for body in self.bodies {
            rise = origin.z - body.z;
            if abs(origin.x - body.x) < 30.0 and abs(origin.y - body.y) < 30.0 and rise >= 56.0 and rise <= 59.0 {
                self.result = TravelResult(speed=0.0, blocked=True, on_top=True);
                return True;
            }
        }
        return False;
    }

    """Whether the bot ducks on this leg. BotTravel_Crouch ducks all along
    a crouch reachability; BotTravel_Walk within 20 units of a walk into an
    area only the crouching box fits (no PRESENCE_NORMAL). A ducked player
    also stays ducked while there is no room to stand (bg_pmove.c
    PM_CheckDuck), which `ducked` and the standing box at `origin` tell."""
    def ducks(origin: Vec3) -> bool {
        route = self.route;
        passage = route.passages[0] if route.passages else None;
        if passage is not None {
            if passage.kind == TRAVEL_CROUCH {
                return True;
            }
            if passage.kind == TRAVEL_WALK
                and self.mesh.aas.areas[passage.target].presence & PRESENCE_NORMAL == 0
                and min(flat_toward(origin, passage.start)[1], flat_toward(origin, passage.finish)[1]) < 20.0 {
                return True;
            }
        }
        return self.ducked and self.collision.for_body(self.eye_height, 0.0).trace(origin, origin).start_solid;
    }

    """A leg's own move with BotCheckBlocked along it: a blocked leg runs
    out ten times as fast ("ms->reachability_time -= 10 * ms->thinktime"),
    and a bot standing in an area without reachabilities also checks what
    is under it (checkbottom)."""
    def heading(move: TravelResult, origin: Vec3, standing: int) {
        self.result = move;
        move.crouch = move.crouch or self.ducks(origin);
        check_blocked(self.collision, origin, move.direction, self.bodies, move);
        if not move.blocked and (standing == 0 or self.mesh.aas.areas[standing].reach_count == 0) {
            floor = self.collision.trace(origin, origin.sub(Vec3(z=3.0)));
            if not floor.start_solid and floor.fraction < 1.0 and floor.model > 0 {
                move.blocked = True;
                move.block_model = floor.model;
                move.on_top = True;
            }
        }
        if move.blocked {
            self.route.leg_started -= 10.0 * self.dt;
        }
    }

    """be_ai_move.c's crandom(), from the bot's own dice (0 without them)."""
    def crandom() -> float {
        dice = self.dice;
        return dice.random() * 2.0 - 1.0 if dice is not None else 0.0;
    }

    """Whether the waypoint ahead is a jump's takeoff."""
    def at_takeoff() -> bool {
        route = self.route;
        passage = route.passages[0] if route.passages else None;
        return passage is not None
            and passage.kind in [TRAVEL_JUMP, TRAVEL_BARRIERJUMP]
            and bool(route.launches)
            and route.launches[0].z > 0.0;
    }

    """A jump's takeoff counts as reached within 24 units of the jump's
    start (BotTravel_Jump's "if (dist1 < 24) EA_Jump"), a barrier jump's
    within 9 (BotTravel_BarrierJump's "if (dist < 9)")."""
    def jump_due(origin: Vec3) -> bool {
        if not self.at_takeoff() {
            return False;
        }
        route = self.route;
        passage = route.passages[0];
        reach = 9.0 if passage is not None and passage.kind == TRAVEL_BARRIERJUMP else 24.0;
        return flat_toward(origin, route.points[0])[1] < reach and abs(route.points[0].z - origin.z) < 28.0;
    }

    can travel with Player entry {
        route = self.route;
        origin = here.pos.sub(Vec3(z=self.eye_height));
        standing = self.mesh.locate(origin);
        if here.grounded {
            if self.on_obstacle(origin, standing) {
                return;
            }
            # "if ( !ms->areanum )": stuck in solid.
            if standing == 0 {
                self.result = TravelResult(failure=True, blocked=True, in_solid=True);
                return;
            }
        }
        while route.points {
            passage = route.passages[0] if route.passages else None;
            # A teleporter's way is done when the bot comes out of it, not on
            # coming near its edge: short of the trigger, nothing carries it.
            if passage is not None and (special_travel(passage.kind) or passage.kind == TRAVEL_TELEPORT) {
                if standing != route.areas[0] {
                    break;
                }
            } elif self.at_takeoff() {
                if not self.jump_due(origin) {
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
                # BotTravel_Jump jumps up to 24 units short of the start:
                # the launch is the one that lands from where the bot is.
                if passage is not None {
                    self.launch = jump_launch(origin, passage.finish);
                }
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
        # "set a timeout for this reachability" and "add the reachability to
        # the reachabilities to avoid for a while".
        avoid = self.avoid;
        if passage is not None and avoid is not None and not route.noted {
            route.noted = True;
            avoid.add(passage, self.clock);
        }
        # "if the goal area changed or the reachability timed out": the bot
        # needs a new reachability, so its way is chosen again from here.
        if self.clock - route.leg_started > reachability_time(kind) {
            route.abandon();
            self.result = TravelResult(speed=0.0);
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
            # On the ground or swimming the water jump itself; in the air
            # its finish (BotMoveToGoal's two halves).
            if here.grounded or here.water_depth >= 2 {
                self.result = travel_water_jump(
                    origin, passage, self.crandom(), view_forward(self.view_yaw, self.view_pitch)
                );
            } else {
                self.result = finish_water_jump(
                    origin, passage, here.water_depth >= 1, [self.crandom(), self.crandom(), self.crandom()]
                );
            }
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
            swim = travel_swim(origin, route.points[0]);
            if passage is None {
                swim.speed = goal_area_speed(route.points[0].sub(origin).length());
            }
            self.heading(swim, origin, standing);
            return;
        }
        if passage is not None and passage.kind == TRAVEL_JUMPPAD {
            if here.grounded {
                # Thrown and down short of the far end: "the area changed",
                # so its way is chosen again.
                if route.jumped and standing != passage.source {
                    route.abandon();
                    self.result = TravelResult(speed=0.0);
                    return;
                }
                # BotTravel_JumpPad: "first walk straight to the
                # reachability start".
                self.heading(
                    TravelResult(direction=flat_toward(origin, passage.start)[0], speed=400.0), origin, standing
                );
                return;
            }
            # The pad's passage is the one a bot in the air finishes once it
            # has come through the pad's own area.
            if not route.jumped and came_through(self.mesh, origin, here.velocity, passage.source) {
                route.jumped = True;
            }
            if route.jumped {
                self.heading(finish_jump_pad(origin, here.velocity, passage), origin, standing);
            } else {
                self.heading(approach_jump_pad(origin, here.velocity, passage), origin, standing);
            }
            return;
        }
        if passage is not None and passage.kind == TRAVEL_WALKOFFLEDGE {
            if here.grounded {
                self.heading(travel_walk_off_ledge(origin, passage), origin, standing);
            } else {
                self.heading(finish_walk_off_ledge(origin, here.velocity, passage), origin, standing);
            }
            return;
        }
        # BotTravel_Walk: "first walk straight to the reachability start",
        # and on to its end from within 10 units of that. The straight line
        # from anywhere in an area to the far end can leave both areas (off
        # a walkway's corner); by the start it cannot.
        aim = route.points[0];
        if passage is not None and passage.kind == TRAVEL_WALK and route.areas[0] == passage.target and not route.begun {
            if flat_toward(origin, passage.start)[1] < 10.0 {
                route.begun = True;
            } else {
                aim = passage.start;
            }
        }
        toward = flat_toward(origin, aim);
        speed = 400.0;
        if passage is None {
            # The last leg is in the goal's own area (BotMoveInGoalArea).
            speed = goal_area_speed(toward[1]);
        } elif passage.kind == TRAVEL_TELEPORT and toward[1] < 30.0 {
            # BotTravel_Teleport: half speed for the last 30 units.
            speed = 200.0;
        } elif passage.kind == TRAVEL_WALK and here.grounded {
            # BotTravel_Walk: slower up to a gap ahead (looked for at the
            # bots' think rate).
            if self.clock - route.gap_checked >= 0.1 {
                route.gap_checked = self.clock;
                route.gap = gap_distance(self.collision, origin, toward[0], self.liquids);
            }
            if route.gap > 0.0 {
                speed = 400.0 - (360.0 - 2.0 * route.gap);
            }
        } elif passage.kind == TRAVEL_BARRIERJUMP and self.at_takeoff() {
            # BotTravel_BarrierJump: slowing up to the barrier.
            speed = 6.0 * min(toward[1], 60.0);
        }
        self.heading(TravelResult(direction=toward[0], speed=speed), origin, standing);
    }
}
