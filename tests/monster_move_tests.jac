"""Monster steps (engine/world/monster_move.jac) against results worked by
hand from Q1 sv_move.c and Q2 m_move.c: SV_movestep, SV_CheckBottom,
SV_StepDirection, SV_NewChaseDir, SV_CloseEnough and SV_MoveToGoal."""
import math;
import from engine.world.monster_move {
    MonsterBody, StepSpace, WalkMove, MoveToGoal, SlideMove, anglemod, vectoyaw
}
import from engine.world.opponent_rule { OpponentRule }
import from engine.world.liquids { LiquidProbe }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

glob STEP_MINS: Vec3 = Vec3(x=-16.0, y=-16.0, z=-24.0);
glob STEP_MAXS: Vec3 = Vec3(x=16.0, y=16.0, z=32.0);

# A box standing on a floor at z 0 has its origin 24 units and the trace's
# 1/32 above it.
glob STAND_Z: float = 24.03125;

def step_box(collision: CollisionMap, lo: Vec3, hi: Vec3) {
    collision.add_box(lo, hi, Vec3(), STEP_MINS, STEP_MAXS);
}

"""A floor at z 0 from x -2000 to `rim`."""
def step_floor(rim: float = 2000.0) -> CollisionMap {
    collision = CollisionMap();
    step_box(collision, Vec3(x=-2000.0, y=-2000.0, z=-64.0), Vec3(x=rim, y=2000.0, z=0.0));
    return collision;
}

def stepper(x: float = 0.0, y: float = 0.0, z: float = STAND_Z) -> MonsterBody {
    return MonsterBody(pos=Vec3(x=x, y=y, z=z + 22.0), grounded=True, health=100);
}

"""Turn a body to face `yaw` degrees exactly, as its steps would leave it."""
def face(body: MonsterBody, yaw: float) {
    body.yaw = math.radians(yaw);
    body.turn_to = yaw;
    body.turn_at = body.yaw;
}

"""Small solid bodies standing where steps of `dist` along `headings` end,
so exactly those headings are blocked."""
def blockers(body: MonsterBody, headings: list[float], dist: float) -> list[AABB] {
    origin = body.pos.sub(Vec3(z=body.eye_height));
    solids: list[AABB] = [];
    for heading in headings {
        yaw = math.radians(heading);
        spot = origin.add(Vec3(x=math.cos(yaw) * dist, y=math.sin(yaw) * dist));
        solids.append(
            AABB(mins=spot.sub(Vec3(x=1.0, y=1.0, z=1.0)), maxs=spot.add(Vec3(x=1.0, y=1.0, z=1.0)))
        );
    }
    return solids;
}

test "anglemod and vectoyaw give whole compass angles as the originals do" {
    assert anglemod(-90.0) == 270.0 and anglemod(450.0) == 90.0 and anglemod(360.0) == 0.0;
    assert vectoyaw(Vec3(x=1.0)) == 0.0 and vectoyaw(Vec3(y=1.0)) == 90.0;
    assert vectoyaw(Vec3(x=-1.0, y=-1.0)) == 225.0 and vectoyaw(Vec3(y=-1.0)) == 270.0;
    # Truncated to whole degrees, and 0 for no direction at all.
    assert vectoyaw(Vec3(x=100.0, y=1.0)) == 0.0 and vectoyaw(Vec3(z=5.0)) == 0.0;
}

test "walkmove takes the whole step or none of it" {
    collision = step_floor();
    # A wall whose face is at x 30.
    step_box(collision, Vec3(x=30.0, y=-200.0, z=0.0), Vec3(x=40.0, y=200.0, z=200.0));
    collision.reindex();
    space = StepSpace(collision=collision);
    body = stepper();
    # 20 units would leave the box (16 wide) 6 units into the wall.
    refused = body spawn WalkMove(space=space, yaw=0.0, dist=20.0);
    assert not refused.moved and body.pos.x == 0.0 and body.pos.y == 0.0;
    # 13 units fits, and is taken exactly.
    taken = body spawn WalkMove(space=space, yaw=0.0, dist=13.0);
    assert taken.moved and body.pos.x == 13.0 and body.pos.y == 0.0;
    assert abs(body.pos.z - 22.0 - STAND_Z) < 0.000001 and body.grounded;
    # A negative distance steps backwards (ai_back).
    back = body spawn WalkMove(space=space, yaw=0.0, dist=-5.0);
    assert back.moved and body.pos.x == 8.0;
    # Off the ground a walker does not step at all (FL_ONGROUND).
    body.grounded = False;
    airborne = body spawn WalkMove(space=space, yaw=0.0, dist=-5.0);
    assert not airborne.moved and body.pos.x == 8.0;
}

test "a step climbs an 18 unit riser and refuses a 19 unit one" {
    for height in [18.0, 19.0] {
        collision = step_floor();
        step_box(collision, Vec3(x=40.0, y=-200.0, z=0.0), Vec3(x=400.0, y=200.0, z=height));
        collision.reindex();
        body = stepper(x=20.0);
        step = body spawn WalkMove(space=StepSpace(collision=collision), yaw=0.0, dist=30.0);
        if height == 18.0 {
            # Its box now overhangs the riser's edge by 6 units, the floor
            # under those corners one step down: a staircase.
            assert step.moved and body.pos.x == 50.0;
            assert abs(body.pos.z - 22.0 - (STAND_Z + 18.0)) < 0.000001;
        } else {
            assert not step.moved and body.pos.x == 20.0;
            assert abs(body.pos.z - 22.0 - STAND_Z) < 0.000001;
        }
    }
}

test "a monster does not step off a ledge but does walk down a stair" {
    # The floor ends at x 100 over a pit.
    pit = step_floor(100.0);
    pit.reindex();
    body = stepper();
    space = StepSpace(collision=pit);
    taken = 0;
    for attempt in range(10) {
        step = body spawn WalkMove(space=space, yaw=0.0, dist=16.0);
        if step.moved {
            taken += 1;
        }
    }
    # At x 80 its leading corners are at 96; one more step would hang them
    # over the edge (SV_CheckBottom).
    assert taken == 5 and body.pos.x == 80.0 and body.grounded;
    # Another floor one step (18) below the edge is a staircase, and taken;
    # 19 below is a ledge.
    for drop in [18.0, 19.0] {
        stair = step_floor(100.0);
        step_box(stair, Vec3(x=100.0, y=-2000.0, z=-128.0), Vec3(x=2000.0, y=2000.0, z=-drop));
        stair.reindex();
        walker_body = stepper(x=80.0);
        down = walker_body spawn WalkMove(space=StepSpace(collision=stair), yaw=0.0, dist=16.0);
        assert down.moved == (drop == 18.0) , str(drop);
        assert walker_body.pos.x == (96.0 if drop == 18.0 else 80.0);
    }
    # Wholly past the edge of a 16 unit stair it drops onto the tread below.
    stair = step_floor(100.0);
    step_box(stair, Vec3(x=100.0, y=-2000.0, z=-128.0), Vec3(x=2000.0, y=2000.0, z=-16.0));
    stair.reindex();
    walker_body = stepper(x=96.0);
    off = walker_body spawn WalkMove(space=StepSpace(collision=stair), yaw=0.0, dist=24.0);
    assert off.moved and walker_body.pos.x == 120.0;
    assert abs(walker_body.pos.z - 22.0 - (STAND_Z - 16.0)) < 0.000001;
    # The push down reaches one step below and no further: with the tread
    # a full 18 below, its floor is the trace's 1/32 out of reach.
    stair = step_floor(100.0);
    step_box(stair, Vec3(x=100.0, y=-2000.0, z=-128.0), Vec3(x=2000.0, y=2000.0, z=-18.0));
    stair.reindex();
    walker_body = stepper(x=96.0);
    off = walker_body spawn WalkMove(space=StepSpace(collision=stair), yaw=0.0, dist=24.0);
    assert not off.moved and walker_body.pos.x == 96.0;
}

test "another solid body stops a step, and one already overlapped still does" {
    collision = step_floor();
    collision.reindex();
    body = stepper();
    # A body standing 40 units ahead (16 wide): its near face is at x 24.
    other = AABB(mins=Vec3(x=24.0, y=-16.0, z=0.0), maxs=Vec3(x=56.0, y=16.0, z=56.0));
    space = StepSpace(collision=collision, solids=[other]);
    blocked = body spawn WalkMove(space=space, yaw=0.0, dist=9.0);
    assert not blocked.moved and body.pos.x == 0.0;
    # Touching faces do not overlap: 8 units brings them together.
    touching = body spawn WalkMove(space=space, yaw=0.0, dist=8.0);
    assert touching.moved and body.pos.x == 8.0;
    # Sideways past it is free.
    aside = body spawn WalkMove(space=space, yaw=90.0, dist=40.0);
    assert aside.moved and abs(body.pos.y - 40.0) < 0.000001;
    # Two bodies left overlapping (a leap or a fall can leave them so): a
    # step whose end is still inside the other starts solid and is refused,
    # as SV_movestep's trace refuses it; one that ends clear of it is taken.
    stuck = stepper();
    inside = AABB(mins=Vec3(x=-6.0, y=-16.0, z=0.0), maxs=Vec3(x=26.0, y=16.0, z=56.0));
    crowd = StepSpace(collision=collision, solids=[inside]);
    for heading in [0.0, 90.0, 180.0, 270.0] {
        short = stuck spawn WalkMove(space=crowd, yaw=heading, dist=8.0);
        assert not short.moved , str(heading);
    }
    assert stuck.pos.x == 0.0 and stuck.pos.y == 0.0;
    away = stuck spawn WalkMove(space=crowd, yaw=180.0, dist=24.0);
    assert away.moved and abs(stuck.pos.x + 24.0) < 0.000001;
}

test "SV_StepDirection turns first and steps only once within 45 degrees one way round" {
    collision = step_floor();
    collision.reindex();
    space = StepSpace(collision=collision);
    body = stepper();
    body.step_random = 8;
    # Facing west with the goal due east and nothing in the way: the first
    # six frames only turn 20 degrees each (200 ... 300); the seventh, at
    # 320, is no longer between 45 and 315 from the heading and steps.
    face(body, 180.0);
    body.ideal_yaw = 0.0;
    turns: list[float] = [];
    for frame in range(7) {
        body spawn MoveToGoal(space=space, dist=64.0, goal=Vec3(x=1000.0, z=STAND_Z));
        turns.append(body.turn_to);
        assert body.pos.x == (64.0 if frame == 6 else 0.0) , str(frame);
    }
    assert turns == [200.0, 220.0, 240.0, 260.0, 280.0, 300.0, 320.0];
    assert body.ideal_yaw == 0.0;
    # The test is one-sided, as in sv_move.c: a monster turned 90 degrees
    # the other way (yaw 10, heading 100: delta -90) steps at once.
    other = stepper();
    other.step_random = 8;
    face(other, 10.0);
    other.ideal_yaw = 100.0;
    other spawn MoveToGoal(space=space, dist=64.0, goal=Vec3(y=1000.0, z=STAND_Z));
    assert other.turn_to == 30.0 and abs(other.pos.y - 64.0 * math.sin(math.radians(100.0))) < 0.000001;
}

test "SV_NewChaseDir picks its headings in sv_move.c's order" {
    collision = step_floor();
    collision.reindex();
    dist = 64.0;
    # The diagonal toward the goal comes first.
    body = stepper();
    body.step_random = 1;
    body.ideal_yaw = 0.0;
    space = StepSpace(collision=collision, solids=blockers(body, [0.0], dist));
    body spawn MoveToGoal(space=space, dist=dist, goal=Vec3(x=100.0, y=100.0, z=STAND_Z));
    assert body.ideal_yaw == 45.0 and body.turn_to == 20.0;
    assert abs(body.pos.x - 45.254834) < 0.00001 and abs(body.pos.y - 45.254834) < 0.00001;
    # South-west of it the "diagonal" is sv_move.c's 215, not 225.
    body = stepper();
    body.step_random = 1;
    face(body, 90.0);
    body.ideal_yaw = 90.0;
    space = StepSpace(collision=collision, solids=blockers(body, [90.0], dist));
    body spawn MoveToGoal(space=space, dist=dist, goal=Vec3(x=-100.0, y=-100.0, z=STAND_Z));
    assert body.ideal_yaw == 215.0 and body.turn_to == 110.0;
    assert abs(body.pos.x + 52.425731) < 0.00001 and abs(body.pos.y + 36.708892) < 0.00001;
    # Goal due east, heading west and blocked: east is the way back, so the
    # axis toward the goal is skipped, the old heading fails, and the search
    # round the compass takes its first open heading. Seed 1 searches from 0
    # upward: 45, too far round to step yet (yaw 160).
    body = stepper();
    body.step_random = 1;
    face(body, 180.0);
    body.ideal_yaw = 180.0;
    space = StepSpace(collision=collision, solids=blockers(body, [180.0], dist));
    body spawn MoveToGoal(space=space, dist=dist, goal=Vec3(x=100.0, z=STAND_Z));
    assert body.ideal_yaw == 45.0 and body.turn_to == 160.0;
    assert body.pos.x == 0.0 and body.pos.y == 0.0;
    # Seed 2 searches from 315 downward, and that turn (yaw 200, delta
    # -115) counts as near enough: the step is taken.
    body = stepper();
    body.step_random = 2;
    face(body, 180.0);
    body.ideal_yaw = 180.0;
    space = StepSpace(collision=collision, solids=blockers(body, [180.0], dist));
    body spawn MoveToGoal(space=space, dist=dist, goal=Vec3(x=100.0, z=STAND_Z));
    assert body.ideal_yaw == 315.0 and body.turn_to == 200.0;
    assert abs(body.pos.x - 45.254834) < 0.00001 and abs(body.pos.y + 45.254834) < 0.00001;
    # With every other heading blocked the way back is tried last. Each
    # failed heading still turned the monster 20 degrees toward it:
    # 160, 140, 135, 155, 175, 195, 215 and then 235 toward 0.
    body = stepper();
    body.step_random = 1;
    face(body, 180.0);
    body.ideal_yaw = 180.0;
    space = StepSpace(
        collision=collision,
        solids=blockers(body, [45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0], dist)
    );
    body spawn MoveToGoal(space=space, dist=dist, goal=Vec3(x=100.0, z=STAND_Z));
    assert body.ideal_yaw == 0.0 and body.turn_to == 235.0 and body.pos.x == 0.0;
    # Shut in on every side it keeps its old heading and, standing on a
    # floor, is not marked as having had the ground pulled out.
    body = stepper();
    body.step_random = 1;
    face(body, 180.0);
    body.ideal_yaw = 190.0;
    space = StepSpace(
        collision=collision,
        solids=blockers(body, [0.0, 45.0, 90.0, 135.0, 180.0, 190.0, 225.0, 270.0, 315.0], dist)
    );
    body spawn MoveToGoal(space=space, dist=dist, goal=Vec3(x=100.0, z=STAND_Z));
    assert body.ideal_yaw == 180.0 and body.pos.x == 0.0 and not body.partial_ground;
}

test "one time in four SV_MoveToGoal picks a new heading though the way is clear" {
    collision = step_floor();
    collision.reindex();
    space = StepSpace(collision=collision);
    # Seed 15000's first roll is the one in four.
    body = stepper();
    body.step_random = 15000;
    face(body, 90.0);
    body.ideal_yaw = 90.0;
    body spawn MoveToGoal(space=space, dist=16.0, goal=Vec3(x=100.0, z=STAND_Z));
    # Due east now, 70 degrees round from it: turned, not yet stepped.
    assert body.ideal_yaw == 0.0 and body.turn_to == 70.0 and body.pos.y == 0.0;
    # Seed 1's is not: it keeps going north.
    body = stepper();
    body.step_random = 1;
    face(body, 90.0);
    body.ideal_yaw = 90.0;
    body spawn MoveToGoal(space=space, dist=16.0, goal=Vec3(x=100.0, z=STAND_Z));
    assert body.ideal_yaw == 90.0 and abs(body.pos.y - 16.0) < 0.000001;
}

test "SV_CloseEnough: a step that would reach the enemy is not taken" {
    collision = step_floor();
    collision.reindex();
    space = StepSpace(collision=collision);
    # The monster's box reaches x 16; with the unit SV_LinkEdict adds to
    # each box, an enemy whose box starts within dist + 2 is close enough.
    for scenario in [(82.0, True), (83.0, False)] {
        body = stepper();
        body.step_random = 1;
        near = AABB(
            mins=Vec3(x=scenario[0], y=-16.0, z=0.0),
            maxs=Vec3(x=scenario[0] + 32.0, y=16.0, z=56.0)
        );
        body spawn MoveToGoal(
            space=space, dist=64.0, goal=Vec3(x=scenario[0] + 16.0, z=STAND_Z), near=near
        );
        if scenario[1] {
            # Not even the roll for a new heading is made.
            assert body.pos.x == 0.0 and body.step_random == 1;
        } else {
            assert body.pos.x == 64.0 and body.step_random != 1;
        }
    }
}

test "a monster whose floor is pulled out steps off and falls" {
    # Standing in mid air with nothing in reach below.
    collision = step_floor(-500.0);
    collision.reindex();
    space = StepSpace(collision=collision);
    body = stepper();
    body.step_random = 1;
    body.ideal_yaw = 0.0;
    body spawn MoveToGoal(space=space, dist=16.0, goal=Vec3(x=1000.0, z=STAND_Z));
    # No heading had a floor: it cannot move, and SV_CheckBottom fails.
    assert body.pos.x == 0.0 and body.grounded and body.partial_ground;
    assert body.ideal_yaw == 0.0;
    # FL_PARTIALGROUND: its next step goes ahead and leaves the ground.
    face(body, 0.0);
    body spawn MoveToGoal(space=space, dist=16.0, goal=Vec3(x=1000.0, z=STAND_Z));
    assert body.pos.x == 16.0 and not body.grounded;
}

obj StepPool(LiquidProbe) {
    has surface: float = 0.0;

    def kind_at(point: Vec3) -> int {
        return 1 if point.z < self.surface else 0;
    }
}

test "fliers rise and sink 8 units a step toward 30 to 40 above their enemy" {
    open_air = CollisionMap();
    flier_rule = OpponentRule(movement="fly", yaw_speed=10.0);
    for scenario in [(100.0, -8.0), (35.0, 0.0), (10.0, 8.0), (-50.0, 8.0)] {
        body = MonsterBody(pos=Vec3(z=scenario[0] + 22.0), health=100, rule=flier_rule);
        space = StepSpace(collision=open_air, game="q1", chasing=True, seek_z=0.0);
        step = body spawn WalkMove(space=space, yaw=0.0, dist=16.0);
        assert step.moved and body.pos.x == 16.0;
        assert body.pos.z - 22.0 - scenario[0] == scenario[1] , str(scenario[0]);
    }
    # With no enemy it keeps its height.
    body = MonsterBody(pos=Vec3(z=122.0), health=100, rule=flier_rule);
    body spawn WalkMove(space=StepSpace(collision=open_air, game="q1"), yaw=0.0, dist=16.0);
    assert body.pos.x == 16.0 and body.pos.z == 122.0;
    # Blocked on the way down, it tries again level.
    floored = step_floor();
    floored.reindex();
    body = MonsterBody(pos=Vec3(z=STAND_Z + 4.0 + 22.0), health=100, rule=flier_rule);
    low = StepSpace(collision=floored, game="q1", chasing=True, seek_z=-200.0);
    step = body spawn WalkMove(space=low, yaw=0.0, dist=16.0);
    assert step.moved and body.pos.x == 16.0 and body.pos.z == STAND_Z + 4.0 + 22.0;
    # Another body in the way stops it both times.
    low.solids = [AABB(mins=Vec3(x=40.0, y=-16.0, z=0.0), maxs=Vec3(x=72.0, y=16.0, z=200.0))];
    step = body spawn WalkMove(space=low, yaw=0.0, dist=16.0);
    assert not step.moved and body.pos.x == 16.0;
    # A flier already inside another body is not held by it (a trace that
    # starts solid runs its whole length).
    low.solids = [AABB(mins=Vec3(x=20.0, y=-16.0, z=0.0), maxs=Vec3(x=52.0, y=16.0, z=200.0))];
    step = body spawn WalkMove(space=low, yaw=0.0, dist=16.0);
    assert step.moved and body.pos.x == 32.0;
    # Q2 comes level with a goal that is not a player, to the unit.
    body = MonsterBody(pos=Vec3(z=5.0 + 22.0), health=100, rule=flier_rule);
    spot = StepSpace(collision=open_air, game="q2", chasing=True, seek_z=0.0, seek_client=False);
    body spawn WalkMove(space=spot, yaw=0.0, dist=16.0);
    assert body.pos.z == 22.0;
    body = MonsterBody(pos=Vec3(z=20.0 + 22.0), health=100, rule=flier_rule);
    body spawn WalkMove(space=spot, yaw=0.0, dist=16.0);
    assert body.pos.z == 12.0 + 22.0;
}

test "swimmers stay in the water and Q2 fliers and walkers stay out of it" {
    open_air = CollisionMap();
    pool = StepPool();
    # A Q1 fish 4 units under the surface with its enemy on the bank above:
    # the step up would leave the water, and SV_movestep refuses it outright.
    fish = MonsterBody(
        pos=Vec3(z=-4.0 + 22.0), health=100, rule=OpponentRule(movement="swim", yaw_speed=10.0)
    );
    water = StepSpace(collision=open_air, game="q1", liquids=pool, chasing=True, seek_z=100.0);
    step = fish spawn WalkMove(space=water, yaw=0.0, dist=12.0);
    assert not step.moved and fish.pos.x == 0.0;
    # Deeper down it rises its 8 units.
    fish.pos = Vec3(z=-40.0 + 22.0);
    step = fish spawn WalkMove(space=water, yaw=0.0, dist=12.0);
    assert step.moved and fish.pos.x == 12.0 and fish.pos.z == -32.0 + 22.0;
    # A Q2 flier over the water will not go down into it.
    flier = MonsterBody(
        pos=Vec3(z=30.0 + 22.0), health=100, rule=OpponentRule(movement="fly", yaw_speed=10.0)
    );
    over = StepSpace(collision=open_air, game="q2", liquids=pool, chasing=True, seek_z=-200.0);
    step = flier spawn WalkMove(space=over, yaw=0.0, dist=12.0);
    assert not step.moved and flier.pos.z == 30.0 + 22.0;
    # A Q2 walker on a dry floor will not step where its feet would be wet.
    collision = step_floor();
    collision.reindex();
    puddle = StepPool(surface=5.0);
    soldier = stepper();
    dry = StepSpace(collision=collision, game="q2", liquids=puddle);
    step = soldier spawn WalkMove(space=dry, yaw=0.0, dist=12.0);
    assert not step.moved and soldier.pos.x == 0.0;
    # Already in it (waterlevel 1), or in Q1, it wades on.
    dry.water_level = 1;
    step = soldier spawn WalkMove(space=dry, yaw=0.0, dist=12.0);
    assert step.moved and soldier.pos.x == 12.0;
    q1 = StepSpace(collision=collision, game="q1", liquids=puddle);
    step = soldier spawn WalkMove(space=q1, yaw=0.0, dist=12.0);
    assert step.moved and soldier.pos.x == 24.0;
}

test "ai_run_slide strafes to its side and changes sides when blocked" {
    collision = step_floor();
    collision.reindex();
    body = stepper();
    # Enemy due east: lefty steps north (yaw + 90), otherwise south.
    body.lefty = True;
    body spawn SlideMove(space=StepSpace(collision=collision), yaw=0.0, dist=8.0);
    assert abs(body.pos.y - 8.0) < 0.000001 and body.lefty and body.ideal_yaw == 0.0;
    # Blocked to the north it changes sides and steps south instead.
    wall = AABB(mins=Vec3(x=-100.0, y=30.0, z=0.0), maxs=Vec3(x=100.0, y=40.0, z=200.0));
    body spawn SlideMove(space=StepSpace(collision=collision, solids=[wall]), yaw=0.0, dist=8.0);
    assert abs(body.pos.y) < 0.000001 and not body.lefty;
}

test "a frame's step is carried over its ticks and ends exactly where it ended" {
    body = stepper();
    start = body.pos;
    # The frame's step moved the body 20 units and turned it to 40 degrees.
    body.pos = Vec3(x=20.0, y=5.0, z=start.z + 18.0);
    body.turn_to = 40.0;
    body.stride(start, 0.1);
    assert body.pos.x == 0.0 and body.yaw == 0.0;
    # Other steps already find it where the step ends.
    assert body.standing().x == 20.0 and body.solid_box().mins.x == 4.0;
    for tick in range(6) {
        body.advance(1.0 / 120.0);
    }
    assert abs(body.pos.x - 10.0) < 0.000001 and abs(math.degrees(body.yaw) - 20.0) < 0.000001;
    # A lift carries it 5 units up part-way: the step still ends as far
    # ahead of it.
    body.pos = body.pos.add(Vec3(z=5.0));
    assert body.standing().x == 20.0 and abs(body.standing().z - (start.z + 23.0)) < 0.000001;
    for tick in range(6) {
        body.advance(1.0 / 120.0);
    }
    assert body.stride_time == 0.0;
    assert abs(body.pos.x - 20.0) < 0.000001 and abs(body.pos.y - 5.0) < 0.000001;
    assert abs(body.pos.z - (start.z + 23.0)) < 0.000001;
    assert body.yaw == math.radians(40.0) and body.facing() == 40.0;
    # Left alone, the body ends on the step's end to the bit.
    begun = body.pos;
    body.pos = Vec3(x=33.3, y=7.7, z=start.z);
    body.stride(begun, 0.1);
    for tick in range(12) {
        body.advance(1.0 / 120.0);
    }
    assert body.stride_time == 0.0 and body.pos.x == 33.3 and body.pos.y == 7.7;
    # Settling finishes a step at once, exactly.
    begun = body.pos;
    body.pos = Vec3(x=41.1, y=7.7, z=start.z);
    body.stride(begun, 0.1);
    body.advance(1.0 / 120.0);
    body.settle();
    assert body.pos.x == 41.1 and body.stride_time == 0.0;
}
