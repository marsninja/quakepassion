"""How moving the body sways the view and the gun, per game: the view bob,
the strafe roll and running pitch, and where the first-person weapon sits
and points.

Q1 view.c V_CalcRefdef: V_CalcBob (cl_bob 0.02, cl_bobcycle 0.6, cl_bobup
0.5) lifts the eye and the gun and pushes the gun forward, V_CalcRoll
(cl_rollangle 2, cl_rollspeed 200) rolls the view, and CalcGunAngle turns the
gun with the view but neither its roll nor the weapon punch. Q2 p_view.c
ClientEndServerFrame (bobmove, bobtime), SV_CalcViewOffset (run_pitch 0.002,
run_roll 0.005, bob_up 0.005, bob_pitch 0.002, bob_roll 0.002) and
SV_CalcGunOffset (bob and turn lag on gunangles), computed each 100 ms server
frame and lerped between them by the client. Q3 bg_pmove.c PM_Footsteps
(bobCycle), cg_view.c CG_OffsetFirstPersonView (cg_runpitch 0.002, cg_runroll
0.005, cg_bobup 0.005, cg_bobpitch 0.002, cg_bobroll 0.002) and cg_weapons.c
CG_CalculateWeaponPosition (bob, landing drop and idle drift).

Profiles keep per-tick state (the bob cycles, the Q2 server frame) that
`tick` advances as each physics tick begins, having kept the tick-start value
so a frame between ticks blends the two like the bodies around it."""
import math;
import from ..world.world { Player }
import from ..math.vec3 { Vec3, forward_from, right_from }

"""Where the eye and the gun are this frame and how each is turned, in
radians and the engine's sense (positive pitch looks up)."""
obj ViewPlacement {
    has eye: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0,
        roll: float = 0.0,
        gun: Vec3 = Vec3(),
        gun_yaw: float = 0.0,
        gun_pitch: float = 0.0,
        gun_roll: float = 0.0;
}

"""The view before the body's sway: the eye after steps and landings, the
aim, the damage and fall kick (Quake degrees, positive pitch looks down) and
the weapon punch (degrees, positive looks up), and the landing dip."""
obj ViewBase {
    has eye: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0,
        kick_pitch: float = 0.0,
        kick_roll: float = 0.0,
        punch: float = 0.0,
        dip: float = 0.0;
}

"""Degrees (Quake's sense) to radians in the engine's pitch sense."""
def:priv up_radians(degrees: float) -> float {
    return -math.radians(degrees);
}

"""The engine's pitch sense (radians, positive up) in Quake degrees."""
def:priv quake_pitch(pitch: float) -> float {
    return -math.degrees(pitch);
}

def:priv flat_speed(velocity: Vec3) -> float {
    return math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y);
}

"""Passion's view: no sway; the gun sits at the eye and turns with it."""
obj ViewSway {
    """A new level: every cycle starts over."""
    def reset() {}

    """A physics tick begins: keep what the frames between this tick and the
    next blend from, then follow the body as the last tick left it. `moving`
    is whether the player is trying to move."""
    def tick(player: Player, moving: bool, dt: float) {}

    """The body landed (Q3 PM_CrashLand starts the footstep cycle over)."""
    def landed() {}

    """Place the view `share` of the way through the last tick, at
    `clock` seconds of simulation time."""
    def place(player: Player, base: ViewBase, clock: float, share: float) -> ViewPlacement {
        yaw = base.yaw;
        pitch = base.pitch + up_radians(base.kick_pitch) + math.radians(base.punch);
        roll = math.radians(base.kick_roll);
        return ViewPlacement(
            eye=base.eye, yaw=yaw, pitch=pitch, roll=roll, gun=base.eye,
            gun_yaw=yaw, gun_pitch=pitch, gun_roll=roll
        );
    }
}

"""Q1 V_CalcBob: the bob rises over the first cl_bobup of each cl_bobcycle
and falls over the rest, 0.3 of it steady and 0.7 swinging, in proportion to
the flat speed, held between -7 and 4 units."""
def q1_view_bob(clock: float, speed: float) -> float {
    cycle = clock - float(int(clock / 0.6)) * 0.6;
    cycle /= 0.6;
    if cycle < 0.5 {
        cycle = math.pi * cycle / 0.5;
    } else {
        cycle = math.pi + math.pi * (cycle - 0.5) / 0.5;
    }
    bob = speed * 0.02;
    bob = bob * 0.3 + bob * 0.7 * math.sin(cycle);
    return max(-7.0, min(4.0, bob));
}

"""Q1 V_CalcRoll: degrees of roll for strafing, reaching cl_rollangle at
cl_rollspeed."""
def q1_view_roll(yaw: float, velocity: Vec3) -> float {
    side = velocity.dot(right_from(yaw));
    sign = -1.0 if side < 0.0 else 1.0;
    side = abs(side);
    if side < 200.0 {
        side = side * 2.0 / 200.0;
    } else {
        side = 2.0;
    }
    return side * sign;
}

obj Q1ViewSway(ViewSway) {
    """V_CalcRefdef: the eye rises by the bob and rolls with a strafe; the
    gun rises by the bob, moves forward by 0.4 of it and sits 2 units higher
    (the viewsize 100 fudge), pointing along the aim with the damage kick's
    pitch but neither roll nor punch (CalcGunAngle, before the punch)."""
    def place(player: Player, base: ViewBase, clock: float, share: float) -> ViewPlacement {
        bob = q1_view_bob(clock, flat_speed(player.velocity));
        eye = base.eye.add(Vec3(z=bob));
        pitch = base.pitch + up_radians(base.kick_pitch);
        gun = base.eye.add(forward_from(base.yaw, base.pitch).scale(bob * 0.4)).add(
            Vec3(z=bob + 2.0)
        );
        return ViewPlacement(
            eye=eye,
            yaw=base.yaw,
            pitch=pitch + math.radians(base.punch),
            roll=math.radians(base.kick_roll + q1_view_roll(base.yaw, player.velocity)),
            gun=gun,
            gun_yaw=base.yaw,
            gun_pitch=pitch,
            gun_roll=0.0
        );
    }
}

"""Q2's view and gun offsets for one server frame (SV_CalcViewOffset's bob
and velocity angles, SV_CalcGunOffset's gunangles), in Quake degrees."""
obj Q2ViewFrame {
    has lift: float = 0.0,
        pitch: float = 0.0,
        roll: float = 0.0,
        gun_pitch: float = 0.0,
        gun_yaw: float = 0.0,
        gun_roll: float = 0.0;

    def blend(other: Q2ViewFrame, share: float) -> Q2ViewFrame {
        return Q2ViewFrame(
            lift=self.lift + (other.lift - self.lift) * share,
            pitch=self.pitch + (other.pitch - self.pitch) * share,
            roll=self.roll + (other.roll - self.roll) * share,
            gun_pitch=self.gun_pitch + (other.gun_pitch - self.gun_pitch) * share,
            gun_yaw=self.gun_yaw + (other.gun_yaw - self.gun_yaw) * share,
            gun_roll=self.gun_roll + (other.gun_roll - self.gun_roll) * share
        );
    }
}

"""Q2 runs the view offsets in the game each 100 ms server frame and the
client lerps between the last two (CL_CalcViewValues): bobtime advances by
bobmove (1/16, 1/8 or 1/4 by speed) each frame on the ground, keeps its
rate in the air and starts over below 5 units a second; the gun lags a
turn by a fifth of the last frame's change."""
obj Q2ViewSway(ViewSway) {
    has bobtime: float = 0.0,
        bobmove: float = 0.0,
        frame_clock: float = 0.0,
        old_yaw: float = 0.0,
        old_pitch: float = 0.0,
        started: bool = False,
        last: Q2ViewFrame = Q2ViewFrame(),
        current: Q2ViewFrame = Q2ViewFrame(),
        share_was: float = 0.0;

    def reset() {
        self.bobtime = 0.0;
        self.bobmove = 0.0;
        self.frame_clock = 0.0;
        self.started = False;
        self.last = Q2ViewFrame();
        self.current = Q2ViewFrame();
        self.share_was = 0.0;
    }

    def tick(player: Player, moving: bool, dt: float) {
        self.share_was = self.frame_clock / 0.1;
        self.frame_clock += dt;
        if self.frame_clock < 0.1 - 0.000001 {
            return;
        }
        self.frame_clock = max(0.0, self.frame_clock - 0.1);
        self.share_was = 0.0;
        self.last = self.current;
        self.current = self.server_frame(player);
    }

    """ClientEndServerFrame: this frame's bob and the offsets from it."""
    def server_frame(player: Player) -> Q2ViewFrame {
        velocity = player.velocity;
        xyspeed = flat_speed(velocity);
        if xyspeed < 5.0 {
            self.bobmove = 0.0;
            self.bobtime = 0.0;
        } elif player.grounded {
            self.bobmove = 0.25 if xyspeed > 210.0 else (0.125 if xyspeed > 100.0 else 0.0625);
        }
        self.bobtime += self.bobmove;
        bobtime = self.bobtime * (4.0 if player.crouched else 1.0);
        odd = int(bobtime) % 2 == 1;
        fracsin = abs(math.sin(bobtime * math.pi));
        ducked = 6.0 if player.crouched else 1.0;
        forward = forward_from(player.yaw, player.pitch);
        right = right_from(player.yaw);
        view = Q2ViewFrame();
        # SV_CalcViewOffset: velocity and bob angles, and the bob height.
        view.pitch = velocity.dot(forward) * 0.002 + fracsin * 0.002 * xyspeed * ducked;
        swing = fracsin * 0.002 * xyspeed * ducked;
        view.roll = velocity.dot(right) * 0.005 + (-swing if odd else swing);
        view.lift = min(6.0, fracsin * xyspeed * 0.005);
        # SV_CalcGunOffset: gun angles from bobbing, inverted on odd cycles,
        # then from the view's change since the last frame.
        view.gun_roll = xyspeed * fracsin * 0.005;
        view.gun_yaw = xyspeed * fracsin * 0.01;
        if odd {
            view.gun_roll = -view.gun_roll;
            view.gun_yaw = -view.gun_yaw;
        }
        view.gun_pitch = xyspeed * fracsin * 0.005;
        yaw = math.degrees(player.yaw);
        pitch = quake_pitch(player.pitch);
        if not self.started {
            self.started = True;
            self.old_yaw = yaw;
            self.old_pitch = pitch;
        }
        turned = [self.old_pitch - pitch, self.old_yaw - yaw];
        for axis in range(2) {
            delta = turned[axis];
            while delta > 180.0 {
                delta -= 360.0;
            }
            while delta < -180.0 {
                delta += 360.0;
            }
            delta = max(-45.0, min(45.0, delta));
            if axis == 1 {
                view.gun_roll += 0.1 * delta;
                view.gun_yaw += 0.2 * delta;
            } else {
                view.gun_pitch += 0.2 * delta;
            }
        }
        self.old_yaw = yaw;
        self.old_pitch = pitch;
        return view;
    }

    """CL_CalcViewValues: the eye and angles lerped between the last two
    frames' offsets; the gun at the eye, turned with the view (kicks and
    all) plus its own gunangles (CL_AddViewWeapon)."""
    def place(player: Player, base: ViewBase, clock: float, share: float) -> ViewPlacement {
        # How far the frame shown is through the server frame in progress.
        through = self.share_was + (self.frame_clock / 0.1 - self.share_was) * share;
        view = self.last.blend(self.current, max(0.0, min(1.0, through)));
        eye = base.eye.add(Vec3(z=view.lift));
        yaw = base.yaw;
        pitch = base.pitch + up_radians(base.kick_pitch + view.pitch) + math.radians(base.punch);
        roll = math.radians(base.kick_roll + view.roll);
        return ViewPlacement(
            eye=eye,
            yaw=yaw,
            pitch=pitch,
            roll=roll,
            gun=eye,
            gun_yaw=yaw + math.radians(view.gun_yaw),
            gun_pitch=pitch + up_radians(view.gun_pitch),
            gun_roll=roll + math.radians(view.gun_roll)
        );
    }
}

"""Q3 PM_Footsteps: bobCycle runs 256 units a stride, 0.4 a millisecond
running (0.5 crouched), only on the ground and only while trying to move,
starting over once the body stops."""
obj Q3ViewSway(ViewSway) {
    has cycle: float = 0.0,
        cycle_was: float = 0.0;

    def reset() {
        self.cycle = 0.0;
        self.cycle_was = 0.0;
    }

    def tick(player: Player, moving: bool, dt: float) {
        self.cycle_was = self.cycle;
        if not player.grounded {
            return;
        }
        if not moving {
            if flat_speed(player.velocity) < 5.0 {
                self.cycle = 0.0;
                self.cycle_was = 0.0;
            }
            return;
        }
        rate = 0.5 if player.crouched else 0.4;
        self.cycle = (self.cycle + rate * dt * 1000.0) % 256.0;
    }

    def landed() {
        self.cycle = 0.0;
        self.cycle_was = 0.0;
    }

    """CG_OffsetFirstPersonView and CG_CalculateWeaponPosition."""
    def place(player: Player, base: ViewBase, clock: float, share: float) -> ViewPlacement {
        cycle = self.cycle;
        if cycle < self.cycle_was {
            cycle += 256.0;
        }
        cycle = (self.cycle_was + (cycle - self.cycle_was) * share) % 256.0;
        odd = cycle >= 128.0;
        fracsin = abs(math.sin((cycle % 128.0) / 127.0 * math.pi));
        velocity = player.velocity;
        xyspeed = flat_speed(velocity);
        forward = forward_from(player.yaw, player.pitch);
        right = right_from(player.yaw);
        # Velocity angles, then the bob, visible even at low speeds.
        view_pitch = velocity.dot(forward) * 0.002;
        view_roll = velocity.dot(right) * 0.005;
        speed = max(200.0, xyspeed);
        ducked = 3.0 if player.crouched else 1.0;
        view_pitch += fracsin * 0.002 * speed * ducked;
        swing = fracsin * 0.002 * speed * ducked;
        view_roll += -swing if odd else swing;
        eye = base.eye.add(Vec3(z=min(6.0, fracsin * xyspeed * 0.005)));
        yaw = base.yaw;
        pitch = base.pitch + up_radians(base.kick_pitch + view_pitch) + math.radians(base.punch);
        roll = math.radians(base.kick_roll + view_roll);
        # The gun: bob angles (inverted on odd strides), a quarter of the
        # landing dip more, and the idle drift.
        scale = -xyspeed if odd else xyspeed;
        drift = (xyspeed + 40.0) * math.sin(clock) * 0.01;
        return ViewPlacement(
            eye=eye,
            yaw=yaw,
            pitch=pitch,
            roll=roll,
            gun=eye.sub(Vec3(z=base.dip * 0.25)),
            gun_yaw=yaw + math.radians(scale * fracsin * 0.01 + drift),
            gun_pitch=pitch + up_radians(xyspeed * fracsin * 0.005 + drift),
            gun_roll=roll + math.radians(scale * fracsin * 0.005 + drift)
        );
    }
}

"""The sway profile for a game."""
def view_sway_for(game: str) -> ViewSway {
    if game == "q1" {
        return Q1ViewSway();
    }
    if game == "q2" {
        return Q2ViewSway();
    }
    if game == "q3" {
        return Q3ViewSway();
    }
    return ViewSway();
}
