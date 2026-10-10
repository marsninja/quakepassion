"""Monster movement as the originals' monsters move (Q1 sv_move.c, Q2
m_move.c): once a 0.1 s frame a monster takes one whole step of that frame's
distance, or none of it.

- `WalkMove` is Q1 PF_walkmove / Q2 M_walkmove: one SV_movestep along a yaw.
- `MoveToGoal` is Q1 SV_MoveToGoal / Q2 M_MoveToGoal: keep heading at
  `ideal_yaw` while SV_StepDirection succeeds, else pick one of eight compass
  headings in SV_NewChaseDir.

Both are spawned on the monster and move it at once, as the C does. Steps are
traced against the world and against the other solid bodies of a `StepSpace`
(living monsters and the player), so bodies block each other. The engine
simulates at 120 Hz, so the caller then hands the frame's step to
`MonsterBody.stride`, which carries the drawn body from where it stood to
where the step ended over the frame's ticks; `standing` is where its box
already is for every other step."""
import math;
import from .world { Player }
import from .opponent_rule { OpponentRule }
import from .liquids { LiquidProbe }
import from ..physics.collision { CollisionMap, Trace }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

# sv_move.c / m_move.c STEPSIZE: the rise or drop one step may take.
glob STEPSIZE: float = 18.0;

# SV_NewChaseDir's DI_NODIR.
glob NO_DIRECTION: float = -1.0;

"""An angle in degrees brought into 0-360 (anglemod)."""
def anglemod(angle: float) -> float {
    turned = angle - 360.0 * math.floor(angle / 360.0);
    return 0.0 if turned >= 360.0 else turned;
}

"""Q1 PF_vectoyaw / Q2 vectoyaw: the yaw of a direction in whole degrees,
0-359, and 0 for no direction."""
def vectoyaw(direction: Vec3) -> float {
    if direction.x == 0.0 and direction.y == 0.0 {
        return 0.0;
    }
    yaw = float(int(math.atan2(direction.y, direction.x) * 180.0 / math.pi));
    return yaw + 360.0 if yaw < 0.0 else yaw;
}

"""A body that moves by monster steps (Q1/Q2 MOVETYPE_STEP): its box, the
direction it is chasing in and the step it is part-way through."""
node MonsterBody(Player) {
    has eye_height: float = 22.0;
    # Moves with its own box (rule width and hull) rather than the player's:
    # set for monsters on their own game's maps.
    has own_hull: bool = False;
    has rule: OpponentRule = OpponentRule();
    # ideal_yaw in degrees, FL_PARTIALGROUND, AS_SLIDING and the side it
    # slides to (lefty), and the random stream SV_MoveToGoal and
    # SV_NewChaseDir draw their rand() from (0 until it is seeded).
    has ideal_yaw: float = 0.0,
        partial_ground: bool = False,
        sliding: bool = False,
        lefty: bool = False,
        step_random: int = 0;
    # The step being carried: where the body ends up (`pos` at the end of
    # the step), how long the carry has left, and where the last carried
    # tick left the body, so a move made by anything else (a lift, a knock)
    # is told apart and kept.
    has stride_to: Vec3 = Vec3(),
        stride_at: Vec3 = Vec3(),
        stride_time: float = 0.0;
    # The yaw the steps have turned the body to, in degrees (angles[YAW]),
    # and the drawn yaw the last carried tick left, in radians.
    has turn_to: float = 0.0,
        turn_at: float = 0.0;
    # Set as a walk or run cycle is entered: its first frame thinks a tick
    # later, once the systems that give a newly alerted monster its goal
    # have run.
    has step_due: bool = False;
    # The last frame of the pain or death it is playing whose step it has
    # taken, so that each frame steps once.
    has step_frame: int = -1;

    """Where the body is for every step's purposes, as a `pos`: where the
    step it is being carried through ends (SV_movestep moved it at once)."""
    def standing() -> Vec3 {
        if self.stride_time <= 0.0 {
            return self.pos;
        }
        if not self.shifted() {
            return self.stride_to;
        }
        return self.pos.add(self.stride_to.sub(self.stride_at));
    }

    """Whether something other than the carry has moved the body since the
    last carried tick."""
    def shifted() -> bool {
        return self.pos.x != self.stride_at.x
            or self.pos.y != self.stride_at.y
            or self.pos.z != self.stride_at.z;
    }

    """The body's yaw in degrees, 0-360, as its steps turn it: the yaw the
    last step left unless something else has turned the body since."""
    def facing() -> float {
        if self.yaw == self.turn_at {
            return self.turn_to;
        }
        return anglemod(math.degrees(self.yaw));
    }

    """Finish the step being carried at once, before anything that needs
    the body where it really is: its next step, a fall or a knock."""
    def settle() {
        if self.stride_time > 0.0 {
            self.pos = self.standing();
            self.stride_time = 0.0;
        }
        if self.yaw == self.turn_at {
            self.yaw = math.radians(self.turn_to);
        } else {
            self.turn_to = anglemod(math.degrees(self.yaw));
        }
        self.turn_at = self.yaw;
    }

    """Hand a frame's step to the ticks: the steps moved the body from
    `start` to where it now is, and turned it to `turn_to`; put the drawn
    body back at `start` and carry it there over `seconds`."""
    def stride(start: Vec3, seconds: float) {
        self.stride_to = self.pos;
        still = start.x == self.pos.x and start.y == self.pos.y and start.z == self.pos.z;
        if seconds <= 0.0 or (still and self.yaw == math.radians(self.turn_to)) {
            # Nothing to carry: the body is where and how the frame left it.
            self.stride_time = 0.0;
            self.yaw = math.radians(self.turn_to);
            self.turn_at = self.yaw;
            return;
        }
        self.pos = start;
        self.stride_at = Vec3(x=start.x, y=start.y, z=start.z);
        self.stride_time = seconds;
    }

    """One tick of the carry: the body covers its share of what is left of
    the step and of the turn, ending exactly on both."""
    def advance(dt: float) {
        if self.stride_time <= 0.0 or dt <= 0.0 {
            return;
        }
        left = self.stride_time - dt;
        if left <= 0.000001 {
            self.pos = self.standing();
            self.stride_time = 0.0;
            if self.yaw == self.turn_at {
                self.yaw = math.radians(self.turn_to);
                self.turn_at = self.yaw;
            }
            return;
        }
        if self.shifted() {
            # Carried or pushed by something else: the step still ends as
            # far ahead of the body as it did.
            self.stride_to = self.standing();
        }
        share = dt / self.stride_time;
        self.pos = self.pos.add(self.stride_to.sub(self.pos).scale(share));
        self.stride_at = Vec3(x=self.pos.x, y=self.pos.y, z=self.pos.z);
        self.stride_time = left;
        if self.yaw == self.turn_at {
            turn = math.radians(self.turn_to) - self.yaw;
            turn = math.atan2(math.sin(turn), math.cos(turn));
            self.yaw += turn * share;
            self.turn_at = self.yaw;
        }
    }

    """The box other bodies' steps are stopped by, where the body stands."""
    def solid_box() -> AABB {
        origin = self.standing();
        rule = self.rule;
        return AABB(
            mins=Vec3(
                x=origin.x - rule.width,
                y=origin.y - rule.width,
                z=origin.z - self.eye_height + rule.hull_bottom
            ),
            maxs=Vec3(
                x=origin.x + rule.width,
                y=origin.y + rule.width,
                z=origin.z - self.eye_height + rule.hull_top
            )
        );
    }
}

"""What one monster's steps are traced against, gathered when its frame
thinks: the collision view of its own box, the box whose corners
SV_CheckBottom tests (`mins`..`maxs` about the origin), the other solid
bodies near enough to matter (SOLID_SLIDEBOX and SOLID_BBOX: living monsters
and the player; corpses, gibs and items are not solid to a step), the
liquids, and what a flier or swimmer holds its height by."""
obj StepSpace {
    has collision: CollisionMap,
        game: str = "",
        mins: Vec3 = Vec3(x=-16.0, y=-16.0, z=-24.0),
        maxs: Vec3 = Vec3(x=16.0, y=16.0, z=32.0),
        solids: list[AABB] = [],
        liquids: LiquidProbe | None = None;
    # Q2 M_CatagorizePosition's waterlevel of the monster (0-3).
    has water_level: int = 0;
    # Whether the monster has an enemy, the height of the origin a flier
    # or swimmer rises and sinks toward (Q1 the enemy's, Q2 the
    # goalentity's) and whether that is a player (Q2: 30-40 units above a
    # client, level with anything else).
    has chasing: bool = False,
        seek_z: float = 0.0,
        seek_client: bool = True;
}

"""A roll of 0..`sides`-1 from the monster's step stream (the originals'
rand())."""
def:priv step_rand(body: MonsterBody, sides: int) -> int {
    if body.step_random <= 0 {
        body.step_random = 1;
    }
    body.step_random = (body.step_random * 48271) % 2147483647;
    return min(sides - 1, int(float(body.step_random) / 2147483647.0 * float(sides)));
}

"""Whether a box of `mins`..`maxs` about `origin` overlaps `solid`."""
def box_meets(origin: Vec3, mins: Vec3, maxs: Vec3, solid: AABB) -> bool {
    return origin.x + maxs.x > solid.mins.x
        and origin.x + mins.x < solid.maxs.x
        and origin.y + maxs.y > solid.mins.y
        and origin.y + mins.y < solid.maxs.y
        and origin.z + maxs.z > solid.mins.z
        and origin.z + mins.z < solid.maxs.z;
}

"""Whether a box of `mins`..`maxs` swept from `start` to `finish` meets
`solid` (a slab test of the segment against the box grown by the mover's)."""
def:priv sweep_meets(start: Vec3, finish: Vec3, mins: Vec3, maxs: Vec3, solid: AABB) -> bool {
    enter = 0.0;
    leave = 1.0;
    lows = [solid.mins.x - maxs.x, solid.mins.y - maxs.y, solid.mins.z - maxs.z];
    highs = [solid.maxs.x - mins.x, solid.maxs.y - mins.y, solid.maxs.z - mins.z];
    starts = [start.x, start.y, start.z];
    deltas = [finish.x - start.x, finish.y - start.y, finish.z - start.z];
    for axis in range(3) {
        if abs(deltas[axis]) < 0.000001 {
            if starts[axis] <= lows[axis] or starts[axis] >= highs[axis] {
                return False;
            }
            continue;
        }
        a = (lows[axis] - starts[axis]) / deltas[axis];
        b = (highs[axis] - starts[axis]) / deltas[axis];
        enter = max(enter, min(a, b));
        leave = min(leave, max(a, b));
        if enter >= leave {
            return False;
        }
    }
    return True;
}

"""SV_Move for a step's push down: the monster's box dropped from `start` to
`finish` against the world and the solid bodies. A trace that starts inside
something runs on out of it, as SV_RecursiveHullCheck and CM_BoxTrace do
(`start_solid`, and `all_solid` if it never gets out)."""
def:priv drop_trace(space: StepSpace, body: MonsterBody, start: Vec3, finish: Vec3) -> Trace {
    trace = space.collision.trace(start, finish, escape=True);
    rule = body.rule;
    for solid in space.solids {
        if start.x + rule.width <= solid.mins.x
            or start.x - rule.width >= solid.maxs.x
            or start.y + rule.width <= solid.mins.y
            or start.y - rule.width >= solid.maxs.y {
            continue;
        }
        if start.z + rule.hull_bottom < solid.maxs.z and start.z + rule.hull_top > solid.mins.z {
            trace.start_solid = True;
            if finish.z + rule.hull_top > solid.mins.z {
                trace.all_solid = True;
            }
            continue;
        }
        # Dropping onto the body: the mover's feet meet its top.
        rest = solid.maxs.z - rule.hull_bottom + 0.03125;
        if start.z >= rest and rest > finish.z {
            fraction = (start.z - rest) / (start.z - finish.z);
            if fraction < trace.fraction {
                trace.fraction = fraction;
                trace.normal = Vec3(z=1.0);
                trace.end = Vec3(x=start.x, y=start.y, z=rest);
            }
        }
    }
    return trace;
}

"""Whether the point one unit up from the feet of a box at `origin` is in
liquid (Q2 SV_movestep's test point against MASK_WATER)."""
def:priv feet_wet(space: StepSpace, origin: Vec3) -> bool {
    liquids = space.liquids;
    if liquids is None {
        return False;
    }
    return liquids.kind_at(origin.add(Vec3(z=space.mins.z + 1.0))) > 0;
}

"""Q1 SV_CheckBottom / Q2 M_CheckBottom: false if any part of the bottom of
the monster's box is off an edge that is not a staircase. With every corner
over solid it is on the ground; otherwise the floor under the middle must be
within two steps and the floor under each corner within one step of that."""
def:priv check_bottom(space: StepSpace, body: MonsterBody) -> bool {
    view = space.collision;
    origin = body.pos.sub(Vec3(z=body.eye_height));
    mins = origin.add(space.mins);
    maxs = origin.add(space.maxs);
    easy = True;
    for x in [mins.x, maxs.x] {
        for y in [mins.y, maxs.y] {
            corner = Vec3(x=x, y=y, z=mins.z - 1.0);
            if easy and not view.trace_point(corner, corner).start_solid {
                easy = False;
            }
        }
    }
    if easy {
        return True;
    }
    start = Vec3(x=(mins.x + maxs.x) * 0.5, y=(mins.y + maxs.y) * 0.5, z=mins.z);
    stop = start.sub(Vec3(z=2.0 * STEPSIZE));
    middle = view.trace(start, stop, point=True, escape=True);
    if middle.fraction == 1.0 {
        return False;
    }
    for x in [mins.x, maxs.x] {
        for y in [mins.y, maxs.y] {
            under = view.trace(
                Vec3(x=x, y=y, z=start.z), Vec3(x=x, y=y, z=stop.z), point=True, escape=True
            );
            # (A hair's allowance, for a floor exactly one step down.)
            if under.fraction == 1.0 or middle.end.z - under.end.z > STEPSIZE + 0.001 {
                return False;
            }
        }
    }
    return True;
}

"""Q1/Q2 SV_movestep: try one step of `move` from where the monster stands.
The move is adjusted for slopes and stairs, but if it is not possible no
move is done and false is returned.

Fliers and swimmers (FL_FLY, FL_SWIM) try the move with 8 units of rise or
fall toward their height over the enemy, then without; Q1 swimmers never
leave the water, Q2 fliers never enter it and Q2 swimmers never leave it.
Walkers are pushed down from a step above the wished place onto the floor
within a step below, refuse to walk off an edge (SV_CheckBottom) and, in Q2,
into water; one whose floor was pulled out (FL_PARTIALGROUND) steps out and
falls."""
def:priv movestep(space: StepSpace, body: MonsterBody, move: Vec3) -> bool {
    lift = Vec3(z=body.eye_height);
    oldorg = body.pos.sub(lift);
    view = space.collision;
    rule = body.rule;
    quake2 = space.game == "q2";
    box_mins = Vec3(x=-rule.width, y=-rule.width, z=rule.hull_bottom);
    box_maxs = Vec3(x=rule.width, y=rule.width, z=rule.hull_top);
    if rule.movement == "fly" or rule.movement == "swim" {
        swims = rule.movement == "swim";
        # Try one move with vertical motion, then one without.
        for attempt in range(2) {
            neworg = oldorg.add(move);
            if attempt == 0 and space.chasing {
                dz = oldorg.z - space.seek_z;
                if not quake2 or space.seek_client {
                    if dz > 40.0 {
                        neworg.z -= 8.0;
                    }
                    if dz < 30.0 and not (quake2 and swims and space.water_level < 2) {
                        neworg.z += 8.0;
                    }
                } elif dz > 8.0 {
                    neworg.z -= 8.0;
                } elif dz > 0.0 {
                    neworg.z -= dz;
                } elif dz < -8.0 {
                    neworg.z += 8.0;
                } else {
                    # m_move.c adds the (negative) difference here too.
                    neworg.z += dz;
                }
            }
            trace = view.trace(oldorg, neworg, escape=True);
            blocked = trace.fraction < 1.0;
            for solid in space.solids {
                if not blocked and sweep_meets(oldorg, neworg, box_mins, box_maxs, solid) {
                    blocked = True;
                }
            }
            if quake2 and space.liquids is not None {
                # Fly monsters don't enter water voluntarily, and swim
                # monsters don't exit it.
                if not swims and space.water_level == 0 and feet_wet(space, trace.end) {
                    return False;
                }
                if swims and space.water_level < 2 and not feet_wet(space, trace.end) {
                    return False;
                }
            }
            if not blocked {
                liquids = space.liquids;
                if not quake2 and swims and liquids is not None and liquids.kind_at(trace.end) == 0 {
                    # Swim monster left water.
                    return False;
                }
                body.pos = trace.end.add(lift);
                return True;
            }
            if not space.chasing {
                break;
            }
        }
        return False;
    }
    # Push down from a step height above the wished position.
    neworg = oldorg.add(move);
    neworg.z += STEPSIZE;
    end = neworg.sub(Vec3(z=2.0 * STEPSIZE));
    trace = drop_trace(space, body, neworg, end);
    if trace.all_solid {
        return False;
    }
    if trace.start_solid {
        neworg.z -= STEPSIZE;
        trace = drop_trace(space, body, neworg, end);
        if trace.all_solid or trace.start_solid {
            return False;
        }
    }
    # Q2: don't go in to water.
    if quake2 and space.water_level == 0 and feet_wet(space, trace.end) {
        return False;
    }
    if trace.fraction == 1.0 {
        # If the monster had the ground pulled out, go ahead and fall.
        if body.partial_ground {
            body.pos = body.pos.add(move);
            body.grounded = False;
            return True;
        }
        # Walked off an edge.
        return False;
    }
    # Check point traces down for dangling corners.
    body.pos = trace.end.add(lift);
    if not check_bottom(space, body) {
        if body.partial_ground {
            # The floor was mostly pulled out from underneath it and it is
            # trying to correct.
            return True;
        }
        body.pos = oldorg.add(lift);
        return False;
    }
    body.partial_ground = False;
    body.grounded = True;
    return True;
}

"""Q1 PF_changeyaw / Q2 M_ChangeYaw: turn toward `ideal_yaw` by the
monster's yaw speed, the short way round."""
def:priv turn_ideal(body: MonsterBody) {
    current = anglemod(body.turn_to);
    ideal = body.ideal_yaw;
    if current == ideal {
        return;
    }
    move = ideal - current;
    speed = body.rule.yaw_speed;
    if ideal > current {
        if move >= 180.0 {
            move -= 360.0;
        }
    } elif move <= -180.0 {
        move += 360.0;
    }
    if move > 0.0 {
        move = min(move, speed);
    } else {
        move = max(move, -speed);
    }
    body.turn_to = anglemod(current + move);
}

"""SV_StepDirection: turn to the movement direction, and walk the distance
if facing it. True if the step was possible, taken or not (a monster not
yet turned to within 45 degrees stays where it is)."""
def:priv step_direction(space: StepSpace, body: MonsterBody, yaw: float, dist: float) -> bool {
    body.ideal_yaw = yaw;
    turn_ideal(body);
    heading = math.radians(yaw);
    move = Vec3(x=math.cos(heading) * dist, y=math.sin(heading) * dist);
    before = body.pos;
    if movestep(space, body, move) {
        delta = body.turn_to - body.ideal_yaw;
        if delta > 45.0 and delta < 315.0 {
            # Not turned far enough, so don't take the step.
            body.pos = before;
        }
        return True;
    }
    return False;
}

"""SV_NewChaseDir: pick the heading to chase `goal` (an origin) in. The
diagonal toward it first, then the two axes (the longer first, or swapped at
random), then the old heading, then every compass heading one way round or
the other, and last the way back; `ideal_yaw` is left on the first that
SV_StepDirection can step along. A monster that cannot move at all and is
not standing on anything has had its floor pulled out (SV_FixCheckBottom)."""
def:priv new_chase_dir(space: StepSpace, body: MonsterBody, goal: Vec3, dist: float) {
    origin = body.pos.sub(Vec3(z=body.eye_height));
    olddir = anglemod(float(int(body.ideal_yaw / 45.0)) * 45.0);
    turnaround = anglemod(olddir - 180.0);
    deltax = goal.x - origin.x;
    deltay = goal.y - origin.y;
    first = NO_DIRECTION;
    if deltax > 10.0 {
        first = 0.0;
    } elif deltax < -10.0 {
        first = 180.0;
    }
    second = NO_DIRECTION;
    if deltay < -10.0 {
        second = 270.0;
    } elif deltay > 10.0 {
        second = 90.0;
    }
    # Try the direct route.
    if first != NO_DIRECTION and second != NO_DIRECTION {
        tdir = 0.0;
        if first == 0.0 {
            tdir = 45.0 if second == 90.0 else 315.0;
        } else {
            # sv_move.c has 215 here, not 225.
            tdir = 135.0 if second == 90.0 else 215.0;
        }
        if tdir != turnaround and step_direction(space, body, tdir, dist) {
            return;
        }
    }
    # Try other directions.
    if step_rand(body, 4) & 1 != 0 or abs(deltay) > abs(deltax) {
        swap = first;
        first = second;
        second = swap;
    }
    if first != NO_DIRECTION and first != turnaround and step_direction(space, body, first, dist) {
        return;
    }
    if second != NO_DIRECTION and second != turnaround and step_direction(space, body, second, dist) {
        return;
    }
    # There is no direct path to the goal, so pick another direction.
    if step_direction(space, body, olddir, dist) {
        return;
    }
    # Randomly determine the direction of the search.
    headings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];
    if step_rand(body, 2) == 0 {
        headings = [315.0, 270.0, 225.0, 180.0, 135.0, 90.0, 45.0, 0.0];
    }
    for tdir in headings {
        if tdir != turnaround and step_direction(space, body, tdir, dist) {
            return;
        }
    }
    if step_direction(space, body, turnaround, dist) {
        return;
    }
    # Can't move.
    body.ideal_yaw = olddir;
    # If a bridge was pulled out from underneath a monster, it may not have
    # a valid standing position at all.
    if not check_bottom(space, body) {
        body.partial_ground = True;
    }
}

"""SV_CloseEnough: the monster's box is within `dist` of `goal` (absmin and
absmax, which SV_LinkEdict keeps a unit beyond each box)."""
def:priv close_enough(body: MonsterBody, goal: AABB, dist: float) -> bool {
    box = body.solid_box();
    return goal.mins.x - 1.0 <= box.maxs.x + 1.0 + dist
        and goal.maxs.x + 1.0 >= box.mins.x - 1.0 - dist
        and goal.mins.y - 1.0 <= box.maxs.y + 1.0 + dist
        and goal.maxs.y + 1.0 >= box.mins.y - 1.0 - dist
        and goal.mins.z - 1.0 <= box.maxs.z + 1.0 + dist
        and goal.maxs.z + 1.0 >= box.mins.z - 1.0 - dist;
}

"""Whether the monster may step at all: on the ground, flying or swimming
(FL_ONGROUND | FL_FLY | FL_SWIM)."""
def:priv can_step(body: MonsterBody) -> bool {
    return body.grounded or body.rule.movement == "fly" or body.rule.movement == "swim";
}

"""Q1 PF_walkmove / Q2 M_walkmove: one step of `dist` along `yaw` (degrees),
all of it or none (`moved`). Q1 ai_forward, ai_back, ai_pain and
ai_painforward, Q2 ai_move, and the strides of ai_charge and ai_run_slide
are this."""
walker WalkMove {
    has space: StepSpace,
        yaw: float,
        dist: float,
        moved: bool = False;

    can walk with MonsterBody entry {
        if not can_step(here) {
            return;
        }
        heading = math.radians(self.yaw);
        self.moved = movestep(
            self.space,
            here,
            Vec3(x=math.cos(heading) * self.dist, y=math.sin(heading) * self.dist)
        );
    }
}

"""Q1/Q2 ai_run_slide: strafe sideways, but stay at about the same range.
Turn toward the enemy (`yaw`, degrees) and step `dist` square to it, to the
side the monster is sliding; blocked, change sides and step the other way."""
walker SlideMove {
    has space: StepSpace,
        yaw: float,
        dist: float;

    """walkmove(yaw, dist)."""
    def sidestep(body: MonsterBody, yaw: float) -> bool {
        if not can_step(body) {
            return False;
        }
        heading = math.radians(yaw);
        return movestep(
            self.space,
            body,
            Vec3(x=math.cos(heading) * self.dist, y=math.sin(heading) * self.dist)
        );
    }

    can strafe with MonsterBody entry {
        here.ideal_yaw = self.yaw;
        turn_ideal(here);
        offset = 90.0 if here.lefty else -90.0;
        if self.sidestep(here, here.ideal_yaw + offset) {
            return;
        }
        here.lefty = not here.lefty;
        self.sidestep(here, here.ideal_yaw - offset);
    }
}

"""Q1 SV_MoveToGoal / Q2 M_MoveToGoal: one frame's step of `dist` toward
`goal` (the goalentity's origin). Nothing if the step would reach `near`,
the box of the enemy; else along `ideal_yaw`, or, one time in four and
whenever that way is blocked, along a new chase direction."""
walker MoveToGoal {
    has space: StepSpace,
        dist: float,
        goal: Vec3,
        near: AABB | None = None;

    can chase with MonsterBody entry {
        if not can_step(here) {
            return;
        }
        # If the next step hits the enemy, return immediately.
        box = self.near;
        if box is not None and close_enough(here, box, self.dist) {
            return;
        }
        # Bump around...
        if step_rand(here, 4) == 1
            or not step_direction(self.space, here, here.ideal_yaw, self.dist) {
            new_chase_dir(self.space, here, self.goal, self.dist);
        }
    }
}
