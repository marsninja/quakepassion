"""Shared fixed-step walking behavior over the collision query interface."""
import from .collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..world.world { Player }

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
    collision: CollisionMap, pos: Vec3, velocity: Vec3, dt: float, grounded: bool
) -> Motion {
    flat = slide(collision, pos, velocity, dt);
    if not grounded or velocity.z > 0.0 {
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
        dt: float = 1.0 / 120.0;

    can integrate with Player entry {
        if self.dt <= 0.0 or self.dt > 0.05 {
            return;
        }
        if here.teleport_hold > 0.0 {
            here.teleport_hold = max(0.0, here.teleport_hold - self.dt);
            return;
        }
        pos = here.pos.sub(Vec3(z=self.collision.eye_height));
        if self.water_depth >= 2 {
            here.grounded = False;
            here.velocity = here.velocity.scale(
                max(0.0, 1.0 - float(self.water_depth) * self.dt)
            );
            desired = self.swim_wish.normalized().scale(160.0);
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
        ground = self.collision.trace(pos, pos.add(Vec3(z=-0.25)));
        here.grounded = not ground.start_solid
            and ground.fraction < 1.0
            and ground.normal.z >= 0.7
            and here.velocity.z <= 0.0;
        if here.grounded {
            pos = ground.end;
            speed = here.velocity.length();
            if speed > 0.0 {
                here.velocity = here.velocity.scale(
                    max(0.0, speed - max(100.0, speed) * 6.0 * self.dt) / speed
                );
            }
            here.velocity = clip_velocity(here.velocity, ground.normal);
            if self.jump {
                here.velocity.z = 270.0;
                here.grounded = False;
            }
        }
        direction = Vec3(x=self.wish.x, y=self.wish.y).normalized();
        add = max(0.0, 320.0 - here.velocity.dot(direction));
        acceleration = 10.0 if here.grounded else 1.0;
        here.velocity = here.velocity.add(
            direction.scale(min(add, acceleration * 320.0 * self.dt))
        );
        if not here.grounded {
            here.velocity.z -= 800.0 * self.dt;
        }
        moved = step_slide(self.collision, pos, here.velocity, self.dt, here.grounded);
        here.velocity = moved.velocity;
        here.pos = moved.pos.add(Vec3(z=self.collision.eye_height));
    }
}
