"""Shared fixed-step walking behavior over the collision query interface."""
import math;
import from .collision { CollisionMap }
import from ..math.vec3 { Vec3, forward_from }
import from ..world.world { Player }
import from ..world.powerups { empowered, speed_scale }

obj Motion {
    has pos: Vec3,
        velocity: Vec3;
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

def step_slide(
    collision: CollisionMap,
    pos: Vec3,
    velocity: Vec3,
    dt: float,
    grounded: bool,
    air_step: bool = False
) -> Motion {
    flat = slide(collision, pos, velocity, dt);
    # Q2/Q3 PM_StepSlideMove also steps while falling, catching ledges; Q1
    # SV_WalkMove does not stair up while jumping. None step while rising.
    if velocity.z > 0.0 or (not grounded and not air_step) {
        return flat;
    }
    # A step cannot improve an unobstructed horizontal move (including rest).
    wanted = velocity.scale(dt);
    actual = flat.pos.sub(pos);
    if abs(actual.x - wanted.x) < 0.000001 and abs(actual.y - wanted.y) < 0.000001 {
        return flat;
    }
    up = collision.trace(pos, pos.add(Vec3(z=18.0)));
    if up.start_solid or up.fraction < 1.0 {
        return flat;
    }
    raised = slide(collision, up.end, velocity, dt);
    down = collision.trace(raised.pos, raised.pos.add(Vec3(z=-18.0)));
    if down.start_solid or down.fraction == 1.0 or down.normal.z < 0.7 {
        return flat;
    }
    flat_delta = flat.pos.sub(pos);
    step_delta = down.end.sub(pos);
    if step_delta.x * step_delta.x + step_delta.y * step_delta.y
        <= flat_delta.x * flat_delta.x + flat_delta.y * flat_delta.y {
        return flat;
    }
    return Motion(pos=down.end, velocity=clip_velocity(raised.velocity, down.normal));
}

walker MovePlayer {
    has collision: CollisionMap,
        wish: Vec3 = Vec3(),
        jump: bool = False,
        water_depth: int = 0,
        swim_wish: Vec3 = Vec3(),
        steady: bool = False,
        game: str = "",
        dt: float = 1.0 / 120.0,
        jumped: bool = False,
        water_jumped: bool = False,
        landed: float = 0.0;

    can integrate with Player entry {
        if self.dt <= 0.0 or self.dt > 0.05 {
            return;
        }
        if here.teleport_hold > 0.0 {
            here.teleport_hold = max(0.0, here.teleport_hold - self.dt);
            return;
        }
        pos = here.pos.sub(Vec3(z=self.collision.eye_height));
        haste = speed_scale(here);
        if empowered(here, "flight") and self.water_depth < 2 {
            # Q3 bg_pmove.c PM_FlyMove: view-relative thrust, flight friction 3.
            here.grounded = False;
            speed = here.velocity.length();
            if speed > 0.0 {
                here.velocity = here.velocity.scale(
                    max(0.0, speed - speed * 3.0 * self.dt) / speed
                );
            }
            if self.swim_wish.length() > 0.0 {
                wish_speed = here.walk_speed * haste;
                direction = self.swim_wish.normalized();
                add = max(0.0, wish_speed - here.velocity.dot(direction));
                here.velocity = here.velocity.add(
                    direction.scale(min(add, 8.0 * wish_speed * self.dt))
                );
            }
            moved = step_slide(self.collision, pos, here.velocity, self.dt, False);
            here.velocity = moved.velocity;
            here.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
            return;
        }
        if here.water_jump_time > 0.0 {
            self.water_jump_move(here, pos);
            return;
        }
        if self.water_depth == 2 and self.check_water_jump(here, pos) {
            self.water_jump_move(here, pos);
            return;
        }
        if self.water_depth >= 2 {
            here.grounded = False;
            here.fall_speed = 0.0;
            here.velocity = here.velocity.scale(
                max(0.0, 1.0 - float(self.water_depth) * self.dt)
            );
            desired = self.swim_wish.normalized().scale(160.0 * haste);
            if self.swim_wish.length() == 0.0 {
                desired = Vec3(z=-60.0);
            }
            direction = desired.normalized();
            add = max(0.0, desired.length() - here.velocity.dot(direction));
            here.velocity = here.velocity.add(
                direction.scale(min(add, 4.0 * desired.length() * self.dt))
            );
            moved = slide(self.collision, pos, here.velocity, self.dt);
            here.velocity = moved.velocity;
            here.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
            return;
        }
        if self.water_depth == 1 {
            here.velocity = here.velocity.scale(max(0.0, 1.0 - self.dt));
        }
        if not self.jump {
            here.jump_held = False;
        }
        here.knockback_time = max(0.0, here.knockback_time - self.dt);
        was_grounded = here.grounded;
        ground = self.collision.trace(pos, pos.add(Vec3(z=-0.25)));
        here.grounded = not ground.start_solid
            and ground.fraction < 1.0
            and ground.normal.z >= 0.7
            and here.velocity.z <= 0.0;
        if here.grounded {
            pos = ground.end;
            if not was_grounded and here.fall_speed < 0.0 {
                # The speed the body hit the ground at (Q1 jump_flag, Q2
                # oldvelocity, Q3 PM_CrashLand's previous velocity).
                self.landed = -here.fall_speed;
            }
            here.fall_speed = 0.0;
            wants_jump = self.jump and not here.jump_held and not here.crouched;
            # Q2/Q3 pmove check the jump before ground friction, so a jump on
            # landing keeps its speed (strafe jumping); Q1 applies friction in
            # SV_ClientThink before PlayerJump.
            if wants_jump and self.game in ["q2", "q3"] {
                self.take_off(here);
            } else {
                speed = here.velocity.length();
                # Q3 PM_Friction skips ground friction while knocked back.
                if speed > 0.0 and not self.steady and here.knockback_time <= 0.0 {
                    here.velocity = here.velocity.scale(
                        max(0.0, speed - max(100.0, speed) * 6.0 * self.dt) / speed
                    );
                }
                here.velocity = clip_velocity(here.velocity, ground.normal);
                if wants_jump {
                    self.take_off(here);
                }
            }
        }
        direction = Vec3(x=self.wish.x, y=self.wish.y).normalized();
        wish_speed = here.walk_speed * haste;
        if self.steady and here.grounded {
            # Monster movestep: a fixed stride with no friction or acceleration.
            here.velocity.x = direction.x * wish_speed;
            here.velocity.y = direction.y * wish_speed;
        } else {
            add = max(0.0, wish_speed - here.velocity.dot(direction));
            acceleration = 10.0 if here.grounded else 1.0;
            here.velocity = here.velocity.add(
                direction.scale(min(add, acceleration * wish_speed * self.dt))
            );
        }
        if not here.grounded {
            here.velocity.z -= 800.0 * self.dt;
            here.fall_speed = here.velocity.z;
        }
        moved = step_slide(
            self.collision,
            pos,
            here.velocity,
            self.dt,
            here.grounded,
            self.game in ["q2", "q3"]
        );
        here.velocity = moved.velocity;
        here.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
    }

    """Q1 PlayerJump / Q2 PM_CheckJump / Q3 PM_CheckJump: 270 units a second
    up, and not again until the button is released (FL_JUMPRELEASED,
    PMF_JUMP_HELD). Q2 adds to an upward velocity."""
    def take_off(body: Player) {
        body.velocity.z = max(270.0, body.velocity.z + 270.0)
            if self.game == "q2"
            else 270.0;
        body.grounded = False;
        body.jump_held = True;
        self.jumped = True;
    }

    """Q1 CheckWaterJump, Q2 PM_CheckSpecialMovement, Q3 PM_CheckWaterJump:
    waist deep, facing a wall that is solid at the waist and open above it,
    the swimmer springs out of the water."""
    def check_water_jump(body: Player, pos: Vec3) -> bool {
        ahead = Vec3(x=math.cos(body.yaw), y=math.sin(body.yaw));
        if self.game == "q1" {
            low = pos.add(Vec3(z=8.0));
            waist = self.collision.trace_point(low, low.add(ahead.scale(24.0)));
            if waist.fraction >= 1.0 or waist.start_solid {
                return False;
            }
            high = pos.add(Vec3(z=32.0));
            if self.collision.trace_point(high, high.add(ahead.scale(24.0))).fraction < 1.0 {
                return False;
            }
            push = Vec3(x=-waist.normal.x, y=-waist.normal.y).scale(50.0);
            body.velocity = Vec3(x=push.x, y=push.y, z=225.0);
        } else {
            low = pos.add(Vec3(z=4.0));
            waist = self.collision.trace_point(low, low.add(ahead.scale(30.0)));
            if waist.fraction >= 1.0 or waist.start_solid {
                return False;
            }
            high = pos.add(Vec3(z=20.0));
            if self.collision.trace_point(high, high.add(ahead.scale(30.0))).fraction < 1.0 {
                return False;
            }
            if self.game == "q3" {
                body.velocity = forward_from(body.yaw, body.pitch).scale(200.0);
            } else {
                body.velocity = ahead.scale(50.0);
            }
            body.velocity.z = 350.0;
        }
        body.water_jump_time = 2.0;
        body.grounded = False;
        body.jump_held = True;
        self.water_jumped = True;
        return True;
    }

    """Out of the water without control: Q1 SV_WaterJump holds the push until
    the body leaves the water, with no gravity while wet; Q2/Q3 fall under
    gravity and give control back once falling."""
    def water_jump_move(body: Player, pos: Vec3) {
        body.water_jump_time = max(0.0, body.water_jump_time - self.dt);
        if self.game == "q1" {
            if self.water_depth == 0 {
                body.water_jump_time = 0.0;
                body.velocity.z -= 800.0 * self.dt;
            }
        } else {
            body.velocity.z -= 800.0 * self.dt;
            if body.velocity.z < 0.0 {
                body.water_jump_time = 0.0;
            }
        }
        moved = step_slide(self.collision, pos, body.velocity, self.dt, False, True);
        # Q1 keeps pressing toward the ledge (movedir) until clear of the water.
        if self.game == "q1" and body.water_jump_time > 0.0 {
            moved.velocity.x = body.velocity.x;
            moved.velocity.y = body.velocity.y;
        }
        body.velocity = moved.velocity;
        body.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
    }
}


walker SetStance {
    has collision: CollisionMap,
        game: str,
        crouch: bool,
        dt: float;

    can update with Player entry {
        if self.dt <= 0.0 or self.game == "q1" {
            return;
        }
        origin = here.pos.sub(Vec3(z=self.collision.eye_height));
        wanted = self.crouch;
        if wanted and self.game == "q2" and not here.crouched {
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
        self.collision.top_drop = (28.0 if self.game == "q2" else 16.0)
            if wanted
            else 0.0;
        self.collision.eye_height = (-2.0 if self.game == "q2" else 12.0)
            if wanted
            else (22.0 if self.game == "q2" else 26.0);
        here.walk_speed = (100.0 if self.game == "q2" else 80.0) if wanted else 320.0;
        here.pos = origin.add(Vec3(z=self.collision.eye_height));
    }
}
