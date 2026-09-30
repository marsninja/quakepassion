"""Render interpolation between fixed physics ticks.

The simulation advances in fixed ticks (App.physics_clock, 120 a second)
while frames are drawn as fast as the display allows, so a frame usually
falls between two ticks. Drawing each body where the last tick left it makes
everything judder; instead every moving body remembers where it stood when
the tick in progress began (`TickPose`, captured at each tick boundary by
engine/world/motion.jac CaptureMotion) and a frame draws it `alpha` of the way
from there to where the tick left it (`TickBlend`), one tick behind the
simulation. The originals draw between their last two updates the same way:
Q1 CL_RelinkEntities (cl.lerpfrac), Q2 CL_AddPacketEntities (backlerp) and
Q3 CG_InterpolateEntityPosition (cg.frameInterpolation).

A body that moved further in one tick than anything can travel teleported (or
respawned) and is drawn where it is: Q1 CL_RelinkEntities assumes a
teleportation, not a motion, when an axis changed by more than 100 units."""
import math;
import from .vec3 { Vec3 }

glob TELEPORT_SPAN: float = 100.0;

"""Where a body stood, and how it faced (radians), when physics tick `tick`
began. A body made during a tick has none yet (tick -1)."""
obj TickPose {
    has pos: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0,
        tick: int = -1;

    def capture(pos: Vec3, yaw: float, pitch: float, tick: int) {
        # Copied into the pose's own vector (every body, every tick): nothing
        # then moves the pose along with the body.
        self.pos.x = pos.x;
        self.pos.y = pos.y;
        self.pos.z = pos.z;
        self.yaw = yaw;
        self.pitch = pitch;
        self.tick = tick;
    }

    """Draw the body where it is until the next tick boundary: after a move
    the simulation made between ticks (noclip flight, a teleport)."""
    def settle() {
        self.tick = -1;
    }
}

"""The moment a frame shows: `alpha` of the way through the last physics
tick run (`tick`). The default shows every body where it is."""
obj TickBlend {
    has tick: int = -1,
        alpha: float = 1.0;

    """How far from its tick-start pose to draw a body now at `now`: all the
    way unless the pose was captured when the last tick began and the body
    moved like a body rather than a teleport."""
    def share(pose: TickPose, now: Vec3) -> float {
        if pose.tick != self.tick or self.alpha >= 1.0 {
            return 1.0;
        }
        if abs(now.x - pose.pos.x) > TELEPORT_SPAN
            or abs(now.y - pose.pos.y) > TELEPORT_SPAN
            or abs(now.z - pose.pos.z) > TELEPORT_SPAN {
            return 1.0;
        }
        return max(0.0, self.alpha);
    }

    """Where to draw a body now at `now`."""
    def place(pose: TickPose, now: Vec3) -> Vec3 {
        share = self.share(pose, now);
        # A body that stood still through the tick is where it is.
        if share >= 1.0
            or (pose.pos.x == now.x and pose.pos.y == now.y and pose.pos.z == now.z) {
            return now;
        }
        return pose.pos.lerp(now, share);
    }

    """The yaw to draw a body with: the shorter way round from its tick-start
    yaw (Q1 CL_RelinkEntities, Q2 LerpAngle)."""
    def turn(pose: TickPose, now: Vec3, yaw: float) -> float {
        return lerp_radians(pose.yaw, yaw, self.share(pose, now));
    }

    def tilt(pose: TickPose, now: Vec3, pitch: float) -> float {
        return lerp_radians(pose.pitch, pitch, self.share(pose, now));
    }
}

"""`share` of the way from angle `start` to `finish` (radians), the shorter
way round."""
def lerp_radians(start: float, finish: float, share: float) -> float {
    if share >= 1.0 {
        return finish;
    }
    delta = finish - start;
    while delta > math.pi {
        delta -= 2.0 * math.pi;
    }
    while delta < -math.pi {
        delta += 2.0 * math.pi;
    }
    return start + delta * share;
}
