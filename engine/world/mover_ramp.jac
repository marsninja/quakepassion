"""Quake II's accelerated moves (g_func.c Think_AccelMove): a mover whose
accel or decel differs from its speed thinks every 0.1 s frame, ramping its
per-frame distance up by `accel` from rest and down by `decel` into its stop.
Q2 func_plat always ramps (accel and decel 5 by default); doors and
func_water only when their accel or decel is authored. Rotating doors and
trains keep a constant speed, as in the original. Distances here are units
per 0.1 s frame, as in moveinfo_t."""
import math;

"""moveinfo_t's acceleration state for one mover."""
obj MoverRamp {
    has accel: float,
        decel: float,
        current_speed: float = 0.0,
        next_speed: float = 0.0,
        move_speed: float = 0.0,
        decel_distance: float = 0.0,
        # The direction this ramp was planned for (0 at rest) and the time
        # left in the current 0.1 s frame.
        heading: int = 0,
        frame_left: float = 0.0;
}

glob RAMP_FRAME: float = 0.1;

"""SP_func_plat / SP_func_door / SP_func_water: the ramp a Q2 mover's
`accel` and `decel` ask for, or None for a constant-speed move. Plats scale
the authored values by 0.1 and default to 5; doors default to their speed,
which makes the move constant (Move_Calc's check). The same 0.1 scaling
turns a door's authored values into per-frame units."""
def q2_mover_ramp(kind: str, fields: dict[str, str], speed: float) -> MoverRamp | None {
    accel = float(fields.get("accel", "0"));
    decel = float(fields.get("decel", "0"));
    if kind == "func_plat" {
        return MoverRamp(
            accel=accel * 0.1 if accel != 0.0 else 5.0,
            decel=decel * 0.1 if decel != 0.0 else 5.0
        );
    }
    if kind not in ["func_door", "func_water"] {
        return None;
    }
    if accel == 0.0 {
        accel = speed;
    }
    if decel == 0.0 {
        decel = speed;
    }
    if accel == speed and decel == speed {
        return None;
    }
    return MoverRamp(accel=accel * 0.1, decel=decel * 0.1);
}

"""AccelerationDistance: how far a ramp at `rate` takes to reach `target`."""
def acceleration_distance(target: float, rate: float) -> float {
    return target * ((target / rate) + 1.0) / 2.0;
}

"""plat_CalcAcceleratedMove: the top speed this move can reach and where
deceleration must begin."""
def calc_accelerated_move(ramp: MoverRamp, speed: float, remaining: float) {
    ramp.move_speed = speed;
    if remaining < ramp.accel {
        ramp.current_speed = remaining;
        return;
    }
    accel_dist = acceleration_distance(speed, ramp.accel);
    decel_dist = acceleration_distance(speed, ramp.decel);
    if remaining - accel_dist - decel_dist < 0.0 {
        f = (ramp.accel + ramp.decel) / (ramp.accel * ramp.decel);
        ramp.move_speed = (-2.0 + math.sqrt(4.0 - 4.0 * f * (-2.0 * remaining))) / (2.0 * f);
        decel_dist = acceleration_distance(ramp.move_speed, ramp.decel);
    }
    ramp.decel_distance = decel_dist;
}

"""plat_Accelerate: the per-frame distance for the coming frame."""
def accelerate(ramp: MoverRamp, speed: float, remaining: float) {
    # Decelerating.
    if remaining <= ramp.decel_distance {
        if remaining < ramp.decel_distance {
            if ramp.next_speed != 0.0 {
                ramp.current_speed = ramp.next_speed;
                ramp.next_speed = 0.0;
                return;
            }
            if ramp.current_speed > ramp.decel {
                ramp.current_speed -= ramp.decel;
            }
        }
        return;
    }
    # At full speed and due to start decelerating during this frame.
    if ramp.current_speed == ramp.move_speed
        and remaining - ramp.current_speed < ramp.decel_distance {
        p1_distance = remaining - ramp.decel_distance;
        p2_distance = ramp.move_speed * (1.0 - (p1_distance / ramp.move_speed));
        distance = p1_distance + p2_distance;
        ramp.current_speed = ramp.move_speed;
        ramp.next_speed = ramp.move_speed - ramp.decel * (p2_distance / distance);
        return;
    }
    # Accelerating.
    if ramp.current_speed < speed {
        old_speed = ramp.current_speed;
        ramp.current_speed = min(speed, ramp.current_speed + ramp.accel);
        if remaining - ramp.current_speed >= ramp.decel_distance {
            return;
        }
        # Crossing into deceleration within this frame: average the speeds.
        p1_distance = remaining - ramp.decel_distance;
        p1_speed = (old_speed + ramp.move_speed) / 2.0;
        p2_distance = ramp.move_speed * (1.0 - (p1_distance / p1_speed));
        distance = p1_distance + p2_distance;
        ramp.current_speed = (p1_speed * (p1_distance / distance))
            + (ramp.move_speed * (p2_distance / distance));
        ramp.next_speed = ramp.move_speed - ramp.decel * (p2_distance / distance);
    }
}

"""Think_AccelMove, once per frame: plan from rest, pick the next frame's
distance, and finish the move exactly when it fits in one frame (Move_Final)."""
def accel_think(ramp: MoverRamp, speed: float, remaining: float) {
    if ramp.current_speed == 0.0 {
        calc_accelerated_move(ramp, speed, remaining);
    }
    accelerate(ramp, speed, remaining);
    if remaining <= ramp.current_speed {
        ramp.current_speed = remaining;
    }
}

"""Units the mover travels this tick, heading `direction` (1 or -1) with
`remaining` units to go at top speed `speed` units a second. A new heading
starts a move from rest (Move_Calc), whose first think comes a frame later."""
def ramp_step(ramp: MoverRamp, direction: int, remaining: float, speed: float, dt: float) -> float {
    if ramp.heading != direction {
        ramp.heading = direction;
        ramp.current_speed = 0.0;
        ramp.next_speed = 0.0;
        ramp.frame_left = RAMP_FRAME;
    }
    travel = 0.0;
    left = dt;
    while left > 0.0000001 {
        if ramp.frame_left <= 0.0000001 {
            ramp.frame_left += RAMP_FRAME;
            accel_think(ramp, speed * RAMP_FRAME, max(0.0, remaining - travel));
        }
        span = min(left, ramp.frame_left);
        travel += ramp.current_speed / RAMP_FRAME * span;
        ramp.frame_left -= span;
        left -= span;
    }
    return min(travel, remaining);
}

"""A mover at rest: the next move plans from standstill."""
def ramp_rest(ramp: MoverRamp) {
    ramp.heading = 0;
    ramp.current_speed = 0.0;
    ramp.next_speed = 0.0;
}
