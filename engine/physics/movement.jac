"""Shared fixed-step walking behavior over the collision query interface,
played by each game's own movement rules (MovementProfile)."""
import math;
import from .collision { CollisionMap }
import from ..math.vec3 { Vec3, forward_from }
import from ..world.world { Player }
import from ..world.powerups { empowered, speed_scale }

"""One game's player movement rules, chosen once for a level: Q1's
SV_ClientThink (sv_user.c) and SV_WalkMove (sv_phys.c) with QuakeC's
PlayerJump and CheckWaterJump, Q2's Pmove (qcommon/pmove.c) and Q3's
PmoveSingle (game/bg_pmove.c). The defaults are the walk monsters and bots
move by (movement_profile(""))."""
obj MovementProfile {
    # The standing top speed (sv_maxspeed, pm_maxspeed, g_speed) and gravity
    # (sv_gravity, pm->s.gravity, ps->gravity).
    has max_speed: float = 320.0,
        gravity: float = 800.0;
    # Ground friction takes `friction` times max(speed, stop_speed) a second
    # (sv_friction/sv_stopspeed, pm_friction/pm_stopspeed). Q1
    # SV_UserFriction multiplies it by sv_edgefriction when the ground ahead
    # drops away; Q1 and Q3 (PM_Friction while walking) measure the speed
    # along the ground, Q2 in full.
    has friction: float = 6.0,
        stop_speed: float = 100.0,
        edge_friction: float = 1.0,
        flat_friction: bool = False;
    # Water friction takes speed * water_friction a second: Q2/Q3
    # pm_waterfriction times the waterlevel, wading too; Q1 SV_WaterMove
    # rubs sv_friction off a swimmer only.
    has water_friction: float = 1.0,
        friction_by_depth: bool = True,
        wade_friction: bool = True;
    # Acceleration on the ground and in the air (sv_accelerate,
    # pm_accelerate, pm_airaccelerate). Q1 SV_AirAccelerate caps the wished
    # speed at 30 but pushes with the whole wish, the air control bunny
    # hopping and air strafing live on; Q2's pm_airaccelerate 0 falls back to
    # PM_Accelerate at 1, as Q3's pm_airaccelerate is.
    has accelerate: float = 10.0,
        air_accelerate: float = 1.0,
        air_speed_cap: float = 0.0;
    # Q3 PMF_TIME_KNOCKBACK: a knocked-back body skids, with no ground
    # friction, air acceleration and gravity on the ground (PM_WalkMove).
    has knockback_skid: bool = True;
    # Crouching (Q2 and Q3 PM_CheckDuck): the hull's lowered top and eye, the
    # speed cap (pm_duckspeed; Q3 g_speed * pm_duckScale, walking only) and
    # whether ducking needs the ground (Q2). Q1 has no crouch.
    has can_duck: bool = False,
        duck_speed: float = 80.0,
        duck_slows_air: bool = False,
        duck_needs_ground: bool = False,
        duck_top_drop: float = 16.0,
        duck_eye_height: float = 12.0,
        stand_eye_height: float = 26.0;
    # Q3 PM_WalkMove slows a wader to 1 - (1 - pm_swimScale) * waterlevel / 3
    # of its speed.
    has wade_slowdown: float = 0.0;
    # Swimming: the wish speed is max speed times `swim_scale` (Q1
    # SV_WaterMove 0.7, Q2 PM_WaterMove 0.5, both scaling the -60 sinking
    # drift too; Q3 caps the wish at speed * pm_swimScale), gained at
    # `swim_accelerate` (sv_accelerate, pm_wateraccelerate). Q1 adds only
    # what the swimmer's whole speed lacks. Q1 and Q2 swim with the
    # stair-stepping move, Q3 slides.
    has swim_scale: float = 0.5,
        swim_caps_wish: bool = True,
        swim_accelerate: float = 4.0,
        swim_adds_by_speed: bool = False,
        swim_steps: bool = False;
    # Jumping in the water lifts a swimmer at 100 (80 in slime, 50 in lava):
    # Q1 PlayerJump, and Q2 PM_CheckJump, which waits for the button's
    # release, the landing hold and a sink slower than 300.
    has swim_jump: bool = False,
        swim_jump_guarded: bool = False;
    # The ground: rising faster than `kickoff_speed` off its plane leaves it
    # (Q2 PM_CatagorizePosition 180, Q3 PM_GroundTrace 10). Jumps go up 270:
    # Q1 PlayerJump adds it, Q2 PM_CheckJump adds and keeps at least 270, Q3
    # sets it. Q2/Q3 jump before friction (strafe jumping keeps speed); Q2
    # PMF_TIME_LAND holds off a jump after a hard landing. Q1/Q2 walks keep
    # to the floor over a ramp's crest where Q3 kicks off.
    has kickoff_speed: float = 180.0,
        jump_speed: float = 270.0,
        jump_adds: bool = False,
        jump_at_least: bool = False,
        jump_before_friction: bool = False,
        land_hold: bool = False,
        follow_ground: bool = True;
    # Stairs: Q2/Q3 PM_StepSlideMove steps in the air too, Q1 SV_WalkMove
    # only in the water; Q3 never steps up while rising clear of the ground.
    # Q1 takes any step that lands on a floor and rubs speed off against a
    # wall the view faces (SV_WallFriction).
    has air_step: bool = False,
        wet_step: bool = False,
        rise_needs_ground: bool = False,
        prefer_step: bool = False,
        wall_friction: bool = False;
    # Water jumps: waist deep, solid `reach` ahead at `low` and open at
    # `high` springs the swimmer out at `lift` with `push` forward. Q1
    # CheckWaterJump pushes into the wall and SV_WaterJump holds it until
    # clear of the water, without gravity or stair steps; Q3
    # PM_CheckWaterJump pushes along the view, Q2 level with it.
    has water_jump_low: float = 4.0,
        water_jump_high: float = 20.0,
        water_jump_reach: float = 30.0,
        water_jump_push: float = 50.0,
        water_jump_lift: float = 350.0,
        water_jump_into_wall: bool = False,
        water_jump_pitched: bool = False,
        water_jump_holds: bool = False;
    # Q2 ladders (PM_CheckSpecialMovement, PM_AddCurrents, PM_AirMove): climb
    # at 200, drift at most 25 a side, no gravity.
    has climbs_ladders: bool = False,
        ladder_speed: float = 200.0,
        ladder_side_speed: float = 25.0;
    # Q2 currents (PM_AddCurrents): pm_waterspeed in the water (half for a
    # wader on the ground), 100 on a conveyor floor.
    has current_speed: float = 0.0,
        conveyor_speed: float = 0.0;
    # Q3 flight (PM_FlyMove): pm_flightfriction and pm_flyaccelerate.
    has flight_friction: float = 3.0,
        fly_accelerate: float = 8.0;
}

"""The movement rules `game` plays by; "" is the monster and bot walk."""
def movement_profile(game: str) -> MovementProfile {
    if game == "q1" {
        return MovementProfile(
            friction=4.0,
            edge_friction=2.0,
            flat_friction=True,
            water_friction=4.0,
            friction_by_depth=False,
            wade_friction=False,
            air_accelerate=10.0,
            air_speed_cap=30.0,
            knockback_skid=False,
            stand_eye_height=22.0,
            swim_scale=0.7,
            swim_caps_wish=False,
            swim_accelerate=10.0,
            swim_adds_by_speed=True,
            swim_steps=True,
            swim_jump=True,
            jump_adds=True,
            wet_step=True,
            prefer_step=True,
            wall_friction=True,
            water_jump_low=8.0,
            water_jump_high=32.0,
            water_jump_reach=24.0,
            water_jump_lift=225.0,
            water_jump_into_wall=True,
            water_jump_holds=True
        );
    }
    if game == "q2" {
        return MovementProfile(
            max_speed=300.0,
            knockback_skid=False,
            can_duck=True,
            duck_speed=100.0,
            duck_slows_air=True,
            duck_needs_ground=True,
            duck_top_drop=28.0,
            duck_eye_height=-2.0,
            stand_eye_height=22.0,
            swim_caps_wish=False,
            swim_accelerate=10.0,
            swim_steps=True,
            swim_jump=True,
            swim_jump_guarded=True,
            jump_adds=True,
            jump_at_least=True,
            jump_before_friction=True,
            land_hold=True,
            air_step=True,
            climbs_ladders=True,
            current_speed=400.0,
            conveyor_speed=100.0
        );
    }
    if game == "q3" {
        return MovementProfile(
            flat_friction=True,
            can_duck=True,
            wade_slowdown=0.5,
            kickoff_speed=10.0,
            jump_before_friction=True,
            follow_ground=False,
            air_step=True,
            rise_needs_ground=True,
            water_jump_push=200.0,
            water_jump_pitched=True
        );
    }
    return MovementProfile();
}

"""Where a move ends and how fast; `stepped` is how far it climbed a step
(Q3 PM_StepSlideMove's delta, the height of its EV_STEP_* event), `wall`
the upright wall a stair-stepping move ran along (Q1 SV_FlyMove's blocked
step trace)."""
obj Motion {
    has pos: Vec3,
        velocity: Vec3,
        stepped: float = 0.0,
        wall: Vec3 | None = None;
}

def clip_velocity(velocity: Vec3, normal: Vec3) -> Vec3 {
    into = velocity.dot(normal);
    return velocity.sub(normal.scale(min(0.0, into)));
}

def slide(collision: CollisionMap, pos: Vec3, velocity: Vec3, dt: float) -> Motion {
    out = Motion(pos=pos, velocity=velocity);
    remaining = dt;
    planes: list[Vec3] = [];
    for bump in range(4) {
        hit = collision.trace(out.pos, out.pos.add(out.velocity.scale(remaining)));
        if hit.start_solid {
            out.velocity = Vec3();
            return out;
        }
        out.pos = hit.end;
        if hit.fraction == 1.0 {
            break;
        }
        remaining *= 1.0 - hit.fraction;
        planes.append(hit.normal);
        if hit.normal.z == 0.0 {
            out.wall = hit.normal;
        }
        candidate = clip_velocity(out.velocity, hit.normal);
        for normal in planes {
            if candidate.dot(normal) < -0.00001 {
                crease = normal.cross(hit.normal).normalized();
                candidate = crease.scale(velocity.dot(crease));
                for other in planes {
                    if candidate.dot(other) < -0.00001 {
                        candidate = Vec3();
                    }
                }
            }
        }
        if candidate.dot(velocity) <= 0.0 {
            candidate = Vec3();
        }
        out.velocity = candidate;
    }
    return out;
}

"""A slide that climbs a stair of up to 18 units when that goes further.
Grounded bodies always may; `air_step` lets an airborne one catch a ledge
(Q2/Q3 PM_StepSlideMove), `rise_needs_ground` refuses a rising one with no
floor a step below (Q3), and `prefer_step` takes any step landing on a floor
(Q1 SV_WalkMove)."""
def step_slide(
    collision: CollisionMap,
    pos: Vec3,
    velocity: Vec3,
    dt: float,
    grounded: bool,
    air_step: bool = False,
    rise_needs_ground: bool = False,
    prefer_step: bool = False
) -> Motion {
    flat = slide(collision, pos, velocity, dt);
    flat.wall = None;
    if not grounded and not air_step {
        return flat;
    }
    # A step cannot improve an unobstructed horizontal move (including rest).
    wanted = velocity.scale(dt);
    actual = flat.pos.sub(pos);
    if abs(actual.x - wanted.x) < 0.000001 and abs(actual.y - wanted.y) < 0.000001 {
        return flat;
    }
    # Q3: "never step up when you still have up velocity", unless a floor
    # lies within a step below; walking up a ramp still climbs a stair at
    # its top.
    if rise_needs_ground and velocity.z > 0.0 {
        below = collision.trace(pos, pos.add(Vec3(z=-18.0)));
        if below.fraction == 1.0 or below.normal.z < 0.7 {
            return flat;
        }
    }
    up = collision.trace(pos, pos.add(Vec3(z=18.0)));
    if up.start_solid or up.fraction < 1.0 {
        return flat;
    }
    raised = slide(collision, up.end, velocity, dt);
    # Q1's downmove also carries the tick's fall (SV_Physics_Client adds
    # gravity on the ground too), so it finds a floor level with the start;
    # the ground probe's quarter unit stands in for it.
    down = collision.trace(
        raised.pos, raised.pos.add(Vec3(z=-18.25 if prefer_step else -18.0))
    );
    if down.start_solid or down.fraction == 1.0 or down.normal.z < 0.7 {
        return flat;
    }
    flat_delta = flat.pos.sub(pos);
    step_delta = down.end.sub(pos);
    if not prefer_step
        and step_delta.x * step_delta.x + step_delta.y * step_delta.y
            <= flat_delta.x * flat_delta.x + flat_delta.y * flat_delta.y {
        return flat;
    }
    return Motion(
        pos=down.end,
        velocity=clip_velocity(raised.velocity, down.normal),
        stepped=down.end.z - pos.z,
        wall=raised.wall
    );
}

"""One fixed step of a body's own movement: flight, a water jump, swimming,
climbing a ladder or walking, as its profile's game moves (Q1 SV_ClientThink
and SV_Physics_Client, Q2 Pmove, Q3 PmoveSingle). `wish` is the level
walking direction and `swim_wish` the view-relative one, `upmove` the
jump/crouch axis (Q2 cmd.upmove) and `current` the water current at the
feet (Immersion.current)."""
walker MovePlayer {
    has collision: CollisionMap,
        wish: Vec3 = Vec3(),
        jump: bool = False,
        water_depth: int = 0,
        swim_wish: Vec3 = Vec3(),
        upmove: float = 0.0,
        current: Vec3 = Vec3(),
        steady: bool = False,
        profile: MovementProfile = MovementProfile(),
        dt: float = 1.0 / 120.0,
        jumped: bool = False,
        water_jumped: bool = False,
        climbing: bool = False,
        landed: float = 0.0,
        stepped: float = 0.0;

    can integrate with Player entry {
        if self.dt <= 0.0 or self.dt > 0.05 {
            return;
        }
        if here.teleport_hold > 0.0 {
            here.teleport_hold = max(0.0, here.teleport_hold - self.dt);
            return;
        }
        pos = here.pos.sub(Vec3(z=self.collision.eye_height));
        # Q2 Pmove drops pm_time each move; PMF_TIME_LAND ends with it.
        here.land_time = max(0.0, here.land_time - self.dt);
        # Q1 FL_JUMPRELEASED, Q2/Q3 PMF_JUMP_HELD clear with the button up.
        if not self.jump {
            here.jump_held = False;
        }
        haste = speed_scale(here);
        # Q3 PmoveSingle: flight comes before water jumps and swimming.
        if empowered(here, "flight") {
            self.fly(here, pos, haste);
            return;
        }
        if here.water_jump_time > 0.0 {
            self.water_jump_move(here, pos);
            return;
        }
        # Q2 PM_CheckSpecialMovement waits out pm_time before looking for a
        # ladder or a water jump.
        self.climbing = here.land_time <= 0.0 and self.on_ladder(here, pos);
        if self.water_depth == 2
            and here.land_time <= 0.0
            and self.check_water_jump(here, pos) {
            self.water_jump_move(here, pos);
            return;
        }
        if self.water_depth >= 2 {
            self.climbing = False;
            self.swim(here, pos, haste);
            return;
        }
        self.walk(here, pos, haste);
    }

    """Walking, falling and climbing (Q1 SV_AirMove, Q2 PM_AirMove, Q3
    PM_WalkMove/PM_AirMove) with the ground check and jump before them."""
    def walk(body: Player, pos: Vec3, haste: float) {
        rules = self.profile;
        body.knockback_time = max(0.0, body.knockback_time - self.dt);
        was_grounded = body.grounded;
        ground = self.collision.trace(pos, pos.add(Vec3(z=-0.25)));
        # Only rising off the ground (a jump or a kick) leaves it, measured
        # away from the plane so walking up a ramp stays on it.
        rising = body.velocity.dot(ground.normal) > rules.kickoff_speed;
        body.grounded = not ground.start_solid
            and ground.fraction < 1.0
            and ground.normal.z >= 0.7
            and not (body.velocity.z > 0.0 and rising);
        if body.grounded {
            # A climber keeps its height (Q2 only records the ground entity).
            if not self.climbing {
                pos = ground.end;
            }
            if not was_grounded and body.fall_speed < 0.0 {
                # The speed the body hit the ground at (Q1 jump_flag, Q2
                # oldvelocity, Q3 PM_CrashLand's previous velocity).
                self.landed = -body.fall_speed;
                # Q2 PM_CatagorizePosition: landing faster than 200 units a
                # second holds off the next jump for 18 (over 400: 25)
                # pm_time units of 8 ms.
                if rules.land_hold and body.fall_speed < -200.0 {
                    body.land_time = 0.2 if body.fall_speed < -400.0 else 0.144;
                }
            }
            body.fall_speed = 0.0;
        }
        # Q2 PM_CheckJump refuses while PMF_TIME_LAND is set.
        wants_jump = body.grounded
            and self.jump
            and not body.jump_held
            and not body.crouched
            and body.land_time <= 0.0;
        # Q2/Q3 pmove check the jump before friction, so a jump on landing
        # keeps its speed (strafe jumping); Q1 SV_ClientThink rubs and
        # accelerates before PlayerPreThink's PlayerJump.
        if wants_jump and rules.jump_before_friction {
            self.take_off(body);
        }
        self.apply_friction(body, pos, body.grounded, False);
        if body.grounded and not self.climbing {
            # Q2/Q3 PM_ClipVelocity against the ground both ways: the walk
            # follows the slope down a ramp instead of hopping off it.
            body.velocity = body.velocity.sub(
                ground.normal.scale(body.velocity.dot(ground.normal))
            );
        }
        speed = body.walk_speed * haste;
        direction = Vec3(x=self.wish.x, y=self.wish.y).normalized();
        wish = direction.scale(speed);
        if self.climbing {
            wish = self.ladder_wish(body, wish);
        }
        # Q2 PM_AddCurrents: water currents at the feet, conveyor floors.
        if self.water_depth > 0 and rules.current_speed > 0.0 {
            push = rules.current_speed;
            if self.water_depth == 1 and body.grounded {
                push *= 0.5;
            }
            wish = wish.add(self.current.scale(push));
        }
        belt = ground.conveyor;
        if body.grounded and rules.conveyor_speed > 0.0 and belt is not None {
            wish = wish.add(belt.scale(rules.conveyor_speed));
        }
        wish_speed = min(wish.length(), speed);
        wish_direction = wish.normalized();
        if rules.can_duck and body.crouched and (body.grounded or rules.duck_slows_air) {
            wish_speed = min(wish_speed, rules.duck_speed * haste);
        }
        if rules.wade_slowdown > 0.0 and self.water_depth > 0 and body.grounded {
            wish_speed = min(
                wish_speed,
                speed * (1.0 - rules.wade_slowdown * float(self.water_depth) / 3.0)
            );
        }
        skidding = rules.knockback_skid and body.knockback_time > 0.0;
        if self.steady and body.grounded {
            # Monster movestep: a fixed stride with no friction or acceleration.
            body.velocity.x = direction.x * speed;
            body.velocity.y = direction.y * speed;
        } elif self.climbing {
            # Q2 PM_AirMove on a ladder: no gravity; with no climb wished the
            # vertical speed settles by gravity's worth each second.
            self.accelerate(body, wish_direction, wish_speed, rules.accelerate);
            if wish.z == 0.0 {
                settle = rules.gravity * self.dt;
                body.velocity.z = max(0.0, body.velocity.z - settle)
                    if body.velocity.z > 0.0
                    else min(0.0, body.velocity.z + settle);
            }
        } elif body.grounded {
            # Q2 PM_AirMove keeps a walker's vertical speed through the push
            # (a current's lift included); Q3 skids under gravity.
            rise = body.velocity.z;
            self.accelerate(
                body,
                wish_direction,
                wish_speed,
                rules.air_accelerate if skidding else rules.accelerate
            );
            body.velocity.z = rise - (rules.gravity * self.dt if skidding else 0.0);
        } else {
            self.accelerate(
                body, wish_direction, wish_speed, rules.air_accelerate, rules.air_speed_cap
            );
        }
        if wants_jump and not rules.jump_before_friction {
            self.take_off(body);
        }
        if not body.grounded {
            if not self.climbing {
                body.velocity.z -= rules.gravity * self.dt;
            }
            body.fall_speed = body.velocity.z;
        }
        moved = step_slide(
            self.collision,
            pos,
            body.velocity,
            self.dt,
            body.grounded,
            rules.air_step or (rules.wet_step and self.water_depth > 0),
            rules.rise_needs_ground,
            rules.prefer_step
        );
        if rules.wall_friction {
            self.rub_wall(body, moved);
        }
        if body.grounded and rules.follow_ground and not self.climbing {
            moved = self.follow_ground(pos, moved);
        }
        body.velocity = moved.velocity;
        body.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
        # The view eases up the step (ViewFeedback.step) rather than jumping.
        self.stepped = moved.stepped;
    }

    """Q1 SV_WaterMove, Q2 PM_WaterMove, Q3 PM_WaterMove: view-relative
    swimming, sinking at 60 with no input, without gravity."""
    def swim(body: Player, pos: Vec3, haste: float) {
        rules = self.profile;
        body.grounded = False;
        body.fall_speed = 0.0;
        # Q1 PlayerJump / Q2 PM_CheckJump: "swimming, not jumping".
        if rules.swim_jump
            and self.jump
            and not (
                rules.swim_jump_guarded
                and (body.jump_held or body.land_time > 0.0 or body.velocity.z <= -300.0)
            ) {
            body.velocity.z = 80.0
                if body.liquid_kind == 2
                else (50.0 if body.liquid_kind == 3 else 100.0);
        }
        self.apply_friction(body, pos, False, True);
        speed = body.walk_speed * haste;
        wish = Vec3(z=-60.0);
        if self.swim_wish.length() > 0.0 {
            wish = self.swim_wish.normalized().scale(speed);
        }
        if rules.current_speed > 0.0 {
            wish = wish.add(self.current.scale(rules.current_speed));
        }
        wish_speed = wish.length();
        direction = wish.normalized();
        if rules.swim_caps_wish {
            wish_speed = min(wish_speed, speed * rules.swim_scale);
        } else {
            wish_speed = min(wish_speed, speed) * rules.swim_scale;
        }
        if rules.swim_adds_by_speed {
            # Q1 measures what is lacking against the whole speed.
            lacking = wish_speed - body.velocity.length();
            if wish_speed > 0.0 and lacking > 0.0 {
                body.velocity = body.velocity.add(
                    direction.scale(
                        min(lacking, rules.swim_accelerate * wish_speed * self.dt)
                    )
                );
            }
        } else {
            self.accelerate(body, direction, wish_speed, rules.swim_accelerate);
        }
        moved = step_slide(
            self.collision,
            pos,
            body.velocity,
            self.dt,
            False,
            True,
            rules.rise_needs_ground,
            rules.prefer_step
        )
            if rules.swim_steps
            else slide(self.collision, pos, body.velocity, self.dt);
        body.velocity = moved.velocity;
        body.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
        self.stepped = moved.stepped;
    }

    """Q3 bg_pmove.c PM_FlyMove: view-relative thrust at pm_flyaccelerate,
    slowed by pm_flightfriction on top of any water's."""
    def fly(body: Player, pos: Vec3, haste: float) {
        rules = self.profile;
        body.grounded = False;
        self.apply_friction(body, pos, False, False, True);
        if self.swim_wish.length() > 0.0 {
            self.accelerate(
                body,
                self.swim_wish.normalized(),
                body.walk_speed * haste,
                rules.fly_accelerate
            );
        }
        moved = step_slide(
            self.collision,
            pos,
            body.velocity,
            self.dt,
            False,
            rules.air_step,
            rules.rise_needs_ground,
            rules.prefer_step
        );
        body.velocity = moved.velocity;
        body.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
    }

    """Q1 SV_UserFriction/SV_WaterMove, Q2 and Q3 PM_Friction: the ground's
    friction (doubled at a Q1 drop-off, none for a Q3 skid, a ladder's in
    Q2), the water's, and flight's, taken off the speed together."""
    def apply_friction(
        body: Player, pos: Vec3, grounded: bool, swimming: bool, flying: bool = False
    ) {
        rules = self.profile;
        velocity = body.velocity;
        flat = rules.flat_friction and grounded;
        speed = Vec3(x=velocity.x, y=velocity.y).length() if flat else velocity.length();
        if speed < 1.0 {
            # Q2/Q3 PM_Friction: stop sliding, still free to sink.
            body.velocity.x = 0.0;
            body.velocity.y = 0.0;
            return;
        }
        drop = 0.0;
        if (grounded or self.climbing)
            and not self.steady
            and not (rules.knockback_skid and body.knockback_time > 0.0) {
            friction = rules.friction;
            if rules.edge_friction != 1.0 and self.at_edge(pos, velocity) {
                friction *= rules.edge_friction;
            }
            drop += max(speed, rules.stop_speed) * friction * self.dt;
        }
        if self.water_depth > 0 and not self.climbing and (swimming or rules.wade_friction) {
            depth = float(self.water_depth) if rules.friction_by_depth else 1.0;
            drop += speed * rules.water_friction * depth * self.dt;
        }
        if flying {
            drop += speed * rules.flight_friction * self.dt;
        }
        body.velocity = velocity.scale(max(0.0, speed - drop) / speed);
    }

    """Q1 SV_UserFriction: the leading edge is over a drop-off when nothing
    lies within 34 units below the feet 16 units ahead."""
    def at_edge(pos: Vec3, velocity: Vec3) -> bool {
        heading = Vec3(x=velocity.x, y=velocity.y).normalized();
        start = pos.add(heading.scale(16.0)).add(Vec3(z=self.collision.hull_mins.z));
        return self.collision.trace_point(start, start.sub(Vec3(z=34.0))).fraction == 1.0;
    }

    """PM_Accelerate / SV_Accelerate: gain up to accel * wish_speed a second
    along `direction` toward `wish_speed`; Q1 SV_AirAccelerate aims only at
    `cap` of it."""
    def accelerate(
        body: Player, direction: Vec3, wish_speed: float, accel: float, cap: float = 0.0
    ) {
        target = min(wish_speed, cap) if cap > 0.0 else wish_speed;
        add = target - body.velocity.dot(direction);
        if add <= 0.0 {
            return;
        }
        body.velocity = body.velocity.add(
            direction.scale(min(add, accel * wish_speed * self.dt))
        );
    }

    """Q2 PM_CheckSpecialMovement: a ladder brush within a unit of the body,
    level with the view's heading."""
    def on_ladder(body: Player, pos: Vec3) -> bool {
        if not self.profile.climbs_ladders {
            return False;
        }
        ahead = Vec3(x=math.cos(body.yaw), y=math.sin(body.yaw));
        hit = self.collision.trace(pos, pos.add(ahead));
        return hit.fraction < 1.0 and hit.climbable;
    }

    """Q2 PM_AddCurrents on a ladder: pressing forward while looking 15
    degrees up or down climbs, as jump and crouch do; sideways drift is
    held to 25 a side. A body already moving faster vertically than the
    climb keeps its wish."""
    def ladder_wish(body: Player, wish: Vec3) -> Vec3 {
        rules = self.profile;
        if abs(body.velocity.z) > rules.ladder_speed {
            return wish;
        }
        forward = self.wish.dot(Vec3(x=math.cos(body.yaw), y=math.sin(body.yaw))) > 0.01;
        tilt = math.radians(15.0);
        climb = 0.0;
        if forward and body.pitch >= tilt {
            climb = rules.ladder_speed;
        } elif forward and body.pitch <= -tilt {
            climb = -rules.ladder_speed;
        } elif self.upmove > 0.0 {
            climb = rules.ladder_speed;
        } elif self.upmove < 0.0 {
            climb = -rules.ladder_speed;
        }
        side = rules.ladder_side_speed;
        return Vec3(
            x=max(-side, min(side, wish.x)), y=max(-side, min(side, wish.y)), z=climb
        );
    }

    """Q1 SV_WallFriction: a stepping move along a wall the view faces
    keeps only (1 + facing + 0.5) of its speed, down to half head on."""
    def rub_wall(body: Player, moved: Motion) {
        wall = moved.wall;
        if wall is None {
            return;
        }
        facing = wall.dot(forward_from(body.yaw, body.pitch)) + 0.5;
        if facing >= 0.0 {
            return;
        }
        side = moved.velocity.sub(wall.scale(wall.dot(moved.velocity)));
        moved.velocity.x = side.x * (1.0 + facing);
        moved.velocity.y = side.y * (1.0 + facing);
    }

    """Q2 PM_StepSlideMove traces a walk back down onto the floor, so the
    body stays on the ground over the crest of a ramp or onto a slope below
    rather than lifting off it for a hop. Only the gap a walkable slope can
    open over this move is closed; ledges and stairs are still fallen from.
    The velocity follows the floor it lands on, as the ramp's climb would
    otherwise carry on past the crest."""
    def follow_ground(start: Vec3, moved: Motion) -> Motion {
        run = Vec3(x=moved.pos.x - start.x, y=moved.pos.y - start.y).length();
        if run <= 0.0 {
            return moved;
        }
        # Floors are walkable up to 0.7 (about 45.6 degrees): tan = 1.02.
        drop = self.collision.trace(moved.pos, moved.pos.add(Vec3(z=-(run * 1.02 + 0.25))));
        if drop.start_solid or drop.fraction == 1.0 or drop.normal.z < 0.7 {
            return moved;
        }
        moved.pos = drop.end;
        moved.velocity = moved.velocity.sub(drop.normal.scale(moved.velocity.dot(drop.normal)));
        return moved;
    }

    """Q1 PlayerJump / Q2 PM_CheckJump / Q3 PM_CheckJump: 270 units a second
    up (Q1 added to the vertical speed, Q2 added but at least 270), and not
    again until the button is released (FL_JUMPRELEASED, PMF_JUMP_HELD)."""
    def take_off(body: Player) {
        rules = self.profile;
        rise = rules.jump_speed;
        if rules.jump_adds {
            rise = body.velocity.z + rules.jump_speed;
            if rules.jump_at_least {
                rise = max(rules.jump_speed, rise);
            }
        }
        body.velocity.z = rise;
        body.grounded = False;
        body.jump_held = True;
        self.jumped = True;
    }

    """Q1 CheckWaterJump, Q2 PM_CheckSpecialMovement, Q3 PM_CheckWaterJump:
    waist deep, facing a wall that is solid at the waist and open above it,
    the swimmer springs out of the water."""
    def check_water_jump(body: Player, pos: Vec3) -> bool {
        rules = self.profile;
        ahead = Vec3(x=math.cos(body.yaw), y=math.sin(body.yaw));
        low = pos.add(Vec3(z=rules.water_jump_low));
        waist = self.collision.trace_point(low, low.add(ahead.scale(rules.water_jump_reach)));
        if waist.fraction >= 1.0 or waist.start_solid {
            return False;
        }
        high = pos.add(Vec3(z=rules.water_jump_high));
        if self.collision.trace_point(high, high.add(ahead.scale(rules.water_jump_reach))).fraction
            < 1.0 {
            return False;
        }
        if rules.water_jump_into_wall {
            body.velocity = Vec3(x=-waist.normal.x, y=-waist.normal.y).scale(
                rules.water_jump_push
            );
        } elif rules.water_jump_pitched {
            body.velocity = forward_from(body.yaw, body.pitch).scale(rules.water_jump_push);
        } else {
            body.velocity = ahead.scale(rules.water_jump_push);
        }
        body.velocity.z = rules.water_jump_lift;
        body.water_jump_time = 2.0;
        body.grounded = False;
        body.jump_held = True;
        self.water_jumped = True;
        return True;
    }

    """Out of the water without control: Q1 SV_WaterJump holds the push until
    the body leaves the water, with no gravity while wet and no stair steps;
    Q2/Q3 fall under gravity and give control back once falling."""
    def water_jump_move(body: Player, pos: Vec3) {
        rules = self.profile;
        body.water_jump_time = max(0.0, body.water_jump_time - self.dt);
        if rules.water_jump_holds {
            if self.water_depth == 0 {
                body.water_jump_time = 0.0;
                body.velocity.z -= rules.gravity * self.dt;
            }
        } else {
            body.velocity.z -= rules.gravity * self.dt;
            if body.velocity.z < 0.0 {
                body.water_jump_time = 0.0;
            }
        }
        moved = step_slide(
            self.collision,
            pos,
            body.velocity,
            self.dt,
            False,
            not rules.water_jump_holds,
            rules.rise_needs_ground
        );
        # Q1 keeps pressing toward the ledge (movedir) until clear of the water.
        if rules.water_jump_holds and body.water_jump_time > 0.0 {
            moved.velocity.x = body.velocity.x;
            moved.velocity.y = body.velocity.y;
        }
        body.velocity = moved.velocity;
        body.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
    }
}


"""Crouching and standing (Q2/Q3 PM_CheckDuck): the hull's top drops and the
eye lowers while crouched, standing again only where there is room. The
body's top speed is its game's standing one; MovePlayer caps a crouch."""
walker SetStance {
    has collision: CollisionMap,
        profile: MovementProfile,
        crouch: bool,
        dt: float;

    can update with Player entry {
        if self.dt <= 0.0 {
            return;
        }
        rules = self.profile;
        here.walk_speed = rules.max_speed;
        if not rules.can_duck {
            return;
        }
        origin = here.pos.sub(Vec3(z=self.collision.eye_height));
        wanted = self.crouch;
        if wanted and rules.duck_needs_ground and not here.crouched {
            ground = self.collision.trace(origin, origin.add(Vec3(z=-0.25)));
            wanted = not ground.start_solid
                and ground.fraction < 1.0
                and ground.normal.z >= 0.7;
        }
        if not wanted and here.crouched {
            if self.collision.trace(origin, origin, top_drop=0.0).start_solid {
                return;
            }
        }
        here.crouched = wanted;
        self.collision.top_drop = rules.duck_top_drop if wanted else 0.0;
        self.collision.eye_height = rules.duck_eye_height
            if wanted
            else rules.stand_eye_height;
        here.pos = origin.add(Vec3(z=self.collision.eye_height));
    }
}
