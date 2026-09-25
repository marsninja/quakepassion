"""Q3 player bodies animated the way the original client animates them.

Legs and torso each run their own animation.cfg sequence (bg_pmove.c picks
them: PM_Footsteps, PM_CheckJump, PM_CrashLand, PM_Weapon, PM_TorsoAnimation;
cg_players.c CG_RunLerpFrame plays them), and the legs turn toward the
direction of travel while the torso and head follow the aim
(CG_PlayerAngles). `GatherModels` joins the parts through their tags every
frame; this module only decides what each part is doing."""
import math;
import from .models {
    PlayerRig,
    AnimationClip,
    LerpFrame,
    ModelResource,
    WeaponKit,
    Wears,
    Holds
}
import from ..math.vec3 { Vec3 }
import from ..math.orientation { quake_basis }

# bg_public.h animNumber_t, as animation.cfg lists them, plus the two
# reversed sequences CG_ParseAnimationFile derives.
glob ANIM_BOTH_DEATH1: int = 0,
    ANIM_TORSO_GESTURE: int = 6,
    ANIM_TORSO_ATTACK: int = 7,
    ANIM_TORSO_ATTACK2: int = 8,
    ANIM_TORSO_DROP: int = 9,
    ANIM_TORSO_RAISE: int = 10,
    ANIM_TORSO_STAND: int = 11,
    ANIM_TORSO_STAND2: int = 12,
    ANIM_LEGS_WALKCR: int = 13,
    ANIM_LEGS_WALK: int = 14,
    ANIM_LEGS_RUN: int = 15,
    ANIM_LEGS_BACK: int = 16,
    ANIM_LEGS_SWIM: int = 17,
    ANIM_LEGS_JUMP: int = 18,
    ANIM_LEGS_LAND: int = 19,
    ANIM_LEGS_JUMPB: int = 20,
    ANIM_LEGS_LANDB: int = 21,
    ANIM_LEGS_IDLE: int = 22,
    ANIM_LEGS_IDLECR: int = 23,
    ANIM_LEGS_TURN: int = 24,
    ANIM_LEGS_BACKCR: int = 25,
    ANIM_LEGS_BACKWALK: int = 26;

# bg_public.h TIMER_LAND and TIMER_GESTURE, in seconds.
glob RIG_TIMER_LAND: float = 0.13,
    RIG_TIMER_GESTURE: float = 2.294;

# cg_players.c CG_PlayerAngles movementOffsets, by movementDir.
glob RIG_MOVE_OFFSETS: list[float] = [0.0, 22.0, 45.0, -22.0, 0.0, 22.0, -45.0, -22.0];

"""animation.cfg rows as [first, count, loop, fps] (first already adjusted for
the legs, count negative for a reversed sequence) to the client's clips."""
def rig_clips(rows: list[list[float]]) -> list[AnimationClip] {
    clips: list[AnimationClip] = [];
    for row in rows {
        fps = row[3] if row[3] != 0.0 else 1.0;
        clips.append(
            AnimationClip(
                first=int(row[0]),
                count=abs(int(row[1])),
                loop=int(row[2]),
                lerp=1.0 / fps,
                reversed=row[1] < 0.0
            )
        );
    }
    if len(clips) > ANIM_LEGS_WALK {
        # CG_ParseAnimationFile: crouched and walking backwards replay forwards.
        for source in [ANIM_LEGS_WALKCR, ANIM_LEGS_WALK] {
            ahead = clips[source];
            clips.append(
                AnimationClip(
                    first=ahead.first,
                    count=ahead.count,
                    loop=ahead.loop,
                    lerp=ahead.lerp,
                    reversed=True
                )
            );
        }
    }
    return clips;
}

"""A body wearing its character's three part models."""
def dress_rig(
    clips: list[AnimationClip],
    lower: ModelResource,
    upper: ModelResource,
    head: ModelResource,
    seed: int = 1
) -> PlayerRig {
    # Scramble small seeds so the first draws differ between bodies.
    rig = PlayerRig(clips=clips, random=max(1, (seed * 1103515245 + 12345) % 2147483647));
    rig +>:Wears(role="lower"):+> lower;
    rig +>:Wears(role="upper"):+> upper;
    rig +>:Wears(role="head"):+> head;
    reset_rig(rig, 0.0);
    return rig;
}

"""Put a different weapon kit in the rig's hand."""
def hold_kit(rig: PlayerRig, kit: WeaponKit | None) {
    for old in [edge rig->:Holds:->] {
        del old;
    }
    if kit is not None {
        rig +>:Holds:+> kit;
        rig.weapon = kit.key;
    } else {
        rig.weapon = "";
    }
}

"""CG_ResetPlayerEntity and CG_ClearLerpFrame: a body that has just appeared
(spawned, respawned or teleported) stands facing its view."""
def reset_rig(rig: PlayerRig, yaw: float) {
    rig.legs_anim = ANIM_LEGS_IDLE;
    rig.torso_anim = ANIM_TORSO_STAND2 if rig.weapon == "gauntlet" else ANIM_TORSO_STAND;
    rig.legs_timer = 0.0;
    rig.torso_timer = 0.0;
    rig.alive = True;
    rig.grounded = True;
    rig.airborne = 0.0;
    rig.switching = "";
    rig.backwards_jump = False;
    rig.move_dir = 0;
    rig.legs = LerpFrame(yaw=yaw);
    rig.torso = LerpFrame(yaw=yaw);
    for part in [rig.legs, rig.torso] {
        anim = rig.legs_anim if part is rig.legs else rig.torso_anim;
        part.frame_time = rig.clock;
        part.old_time = rig.clock;
        part.animation = anim;
        part.toggle = rig.legs_toggle if part is rig.legs else rig.torso_toggle;
        if anim < len(rig.clips) {
            part.start_time = rig.clock + rig.clips[anim].lerp;
            part.frame = rig.clips[anim].first;
            part.old_frame = part.frame;
        }
    }
    rig.legs_angles = Vec3(y=yaw);
    rig.torso_angles = Vec3();
    rig.head_angles = Vec3();
}

"""cg_players.c CG_RunLerpFrame: advance one part through its sequence at the
sequence's own rate. A new sequence starts from the frame being shown, so
changes blend rather than pop."""
def run_lerp_frame(
    clips: list[AnimationClip], lf: LerpFrame, anim: int, toggle: int, now: float, speed: float
) {
    if anim < 0 or anim >= len(clips) {
        return;
    }
    if anim != lf.animation or toggle != lf.toggle {
        lf.animation = anim;
        lf.toggle = toggle;
        lf.start_time = lf.frame_time + clips[anim].lerp;
    }
    clip = clips[lf.animation];
    if now >= lf.frame_time {
        lf.old_frame = lf.frame;
        lf.old_time = lf.frame_time;
        if now < lf.start_time {
            lf.frame_time = lf.start_time;
        } else {
            lf.frame_time = lf.old_time + clip.lerp;
        }
        f = int((lf.frame_time - lf.start_time) / clip.lerp + 0.001);
        f = int(float(f) * speed);
        if f >= clip.count {
            f -= clip.count;
            if clip.loop > 0 {
                f = f % clip.loop + clip.count - clip.loop;
            } else {
                f = clip.count - 1;
                # Stuck at the end, it can change sequence at once.
                lf.frame_time = now;
            }
        }
        lf.frame = clip.first + (clip.count - 1 - f if clip.reversed else f);
        if now > lf.frame_time {
            lf.frame_time = now;
        }
    }
    if lf.frame_time > now + 0.2 {
        lf.frame_time = now;
    }
    if lf.old_time > now {
        lf.old_time = now;
    }
    if lf.frame_time == lf.old_time {
        lf.backlerp = 0.0;
    } else {
        lf.backlerp = 1.0 - (now - lf.old_time) / (lf.frame_time - lf.old_time);
    }
}

"""q_math.c AngleSubtract: the difference folded into [-180, 180)."""
def angle_delta(a: float, b: float) -> float {
    value = (a - b) % 360.0;
    return value - 360.0 if value >= 180.0 else value;
}

"""cg_players.c CG_SwingAngles: once the angle strays past its tolerance it
swings back toward `destination`, faster the further off it is, and never
lags by more than the clamp. Returns the new angle and whether it still
swings; `speed` is degrees per second."""
def swing_angle(
    destination: float,
    tolerance: float,
    clamp: float,
    speed: float,
    angle: float,
    swinging: bool,
    dt: float
) -> tuple[float, bool] {
    if not swinging {
        away = angle_delta(angle, destination);
        if away > tolerance or away < -tolerance {
            swinging = True;
        }
    }
    if not swinging {
        return (angle, False);
    }
    swing = angle_delta(destination, angle);
    scale = abs(swing);
    scale = 0.5 if scale < tolerance * 0.5 else (1.0 if scale < tolerance else 2.0);
    if swing >= 0.0 {
        move = dt * scale * speed;
        if move >= swing {
            move = swing;
            swinging = False;
        }
        angle = (angle + move) % 360.0;
    } else {
        move = -dt * scale * speed;
        if move <= swing {
            move = swing;
            swinging = False;
        }
        angle = (angle + move) % 360.0;
    }
    swing = angle_delta(destination, angle);
    if swing > clamp {
        angle = (destination - (clamp - 1.0)) % 360.0;
    } elif swing < -clamp {
        angle = (destination + (clamp - 1.0)) % 360.0;
    }
    return (angle, swinging);
}

"""bg_pmove.c PM_SetMovementDir: eight directions of travel relative to the
view, from forward and right move signs."""
def movement_dir(forward: int, right: int, previous: int) -> int {
    if forward == 0 and right == 0 {
        # Stop on the diagonal rather than crooked.
        return 1 if previous == 2 else (7 if previous == 6 else previous);
    }
    if right == 0 {
        return 0 if forward > 0 else 4;
    }
    if right < 0 {
        return 1 if forward > 0 else (2 if forward == 0 else 3);
    }
    return 7 if forward > 0 else (6 if forward == 0 else 5);
}

def rig_random(rig: PlayerRig) -> float {
    rig.random = (rig.random * 48271) % 2147483647;
    return float(rig.random) / 2147483647.0;
}

"""Pose a rig for one step of its owner's play: bg_pmove.c's legs and torso
animation choices from movement and weapon use, cg_players.c's angles, and the
lerp frames. Sound cues (cg_event.c) are collected in `sounds` for the owner:
"jump", "land", "fall_medium", "fall_far", "step", "splash", "gasp",
"death1".."death3" and "pain25".."pain100"."""
walker PoseRig {
    has dt: float,
        grounded: bool = True,
        velocity: Vec3 = Vec3(),
        wish: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0,
        water_depth: int = 0,
        crouched: bool = False,
        walking: bool = False,
        alive: bool = True,
        health: int = 100,
        hurt: bool = False,
        switching: str = "",
        ready: bool = True,
        shots: int = -1,
        gesture: bool = False,
        haste: bool = False,
        gibbed: bool = False,
        sounds: list[str] = [];

    can pose with PlayerRig entry {
        rig = here;
        dt = max(0.0, self.dt);
        rig.clock += dt;
        now = rig.clock;
        rig.legs_timer = max(0.0, rig.legs_timer - dt);
        rig.torso_timer = max(0.0, rig.torso_timer - dt);
        view_yaw = math.degrees(self.yaw) % 360.0;
        # Quake pitch is positive looking down.
        view_pitch = -math.degrees(self.pitch);
        if self.alive and not rig.alive {
            reset_rig(rig, view_yaw);
        }
        if not self.alive {
            view_pitch = 0.0;
            if rig.alive {
                # g_combat.c player_die cycles the three deaths.
                rig.alive = False;
                choice = (rig.deaths + int(rig_random(rig) * 3.0)) % 3;
                rig.deaths += 1;
                death = ANIM_BOTH_DEATH1 + choice * 2;
                self.start_legs(rig, death, True);
                self.start_torso(rig, death);
                rig.firing = False;
                # A gibbed body (EV_GIB_PLAYER) makes no death cry.
                if not self.gibbed {
                    self.sounds.append("death" + str(choice + 1));
                }
            }
        } else {
            self.animate_legs(rig);
            self.animate_torso(rig);
            if self.hurt and now - rig.pain_time >= 0.5 {
                # CG_PainEvent: at most two pain sounds a second, and a twitch.
                rig.pain_time = now;
                rig.pain_left = not rig.pain_left;
                tier = 25 if self.health < 25 else (50 if self.health < 50 else (75 if self.health < 75 else 100));
                self.sounds.append("pain" + str(tier));
            }
        }
        self.spin_barrel(rig);
        self.turn_parts(rig, view_yaw, view_pitch);
        speed = 1.5 if self.haste else 1.0;
        legs_anim = rig.legs_anim;
        if rig.legs.yawing and rig.legs_anim == ANIM_LEGS_IDLE {
            # CG_PlayerAnimation: shuffle the feet while the legs catch up.
            legs_anim = ANIM_LEGS_TURN;
        }
        run_lerp_frame(rig.clips, rig.legs, legs_anim, rig.legs_toggle, now, speed);
        run_lerp_frame(rig.clips, rig.torso, rig.torso_anim, rig.torso_toggle, now, speed);
    }

    """PM_StartLegsAnim (blocked by a running legs timer unless forced)."""
    def start_legs(rig: PlayerRig, anim: int, force: bool = False) {
        if force {
            rig.legs_timer = 0.0;
        }
        if rig.legs_timer > 0.0 {
            return;
        }
        rig.legs_anim = anim;
        rig.legs_toggle += 1;
    }

    """PM_ContinueLegsAnim."""
    def continue_legs(rig: PlayerRig, anim: int) {
        if rig.legs_anim != anim {
            self.start_legs(rig, anim);
        }
    }

    def start_torso(rig: PlayerRig, anim: int) {
        rig.torso_anim = anim;
        rig.torso_toggle += 1;
    }

    """PM_ContinueTorsoAnim."""
    def continue_torso(rig: PlayerRig, anim: int) {
        if rig.torso_anim != anim and rig.torso_timer <= 0.0 {
            self.start_torso(rig, anim);
        }
    }

    """PM_CheckJump, PM_GroundTraceMissed, PM_CrashLand and PM_Footsteps."""
    def animate_legs(rig: PlayerRig) {
        facing = Vec3(x=math.cos(self.yaw), y=math.sin(self.yaw));
        forward_move = self.wish.x * facing.x + self.wish.y * facing.y;
        right_move = self.wish.x * facing.y - self.wish.y * facing.x;
        forward = 1 if forward_move > 0.38 else (-1 if forward_move < -0.38 else 0);
        right = 1 if right_move > 0.38 else (-1 if right_move < -0.38 else 0);
        rig.move_dir = movement_dir(forward, right, rig.move_dir);
        backwards = forward < 0;
        was_grounded = rig.grounded;
        rig.grounded = self.grounded;
        underwater = self.water_depth >= 3;
        if rig.underwater and not underwater {
            self.sounds.append("gasp");
        }
        rig.underwater = underwater;
        if not self.grounded {
            rig.airborne += self.dt;
            rig.fall_speed = -self.velocity.z;
            if was_grounded and self.velocity.z > 0.0 and self.water_depth < 2 {
                # Leaving the ground upward is a jump (or a jump pad launch).
                rig.backwards_jump = backwards;
                self.start_legs(rig, ANIM_LEGS_JUMPB if backwards else ANIM_LEGS_JUMP, True);
                self.sounds.append("jump");
            } elif rig.airborne > 0.1
                and self.velocity.z < -100.0
                and rig.legs_anim not in [ANIM_LEGS_JUMP, ANIM_LEGS_JUMPB, ANIM_LEGS_SWIM] {
                # Walking off a ledge falls in the jump pose.
                rig.backwards_jump = backwards;
                self.start_legs(rig, ANIM_LEGS_JUMPB if backwards else ANIM_LEGS_JUMP, True);
            }
            if self.water_depth > 1 {
                self.continue_legs(rig, ANIM_LEGS_SWIM);
            }
            return;
        }
        if not was_grounded and rig.airborne > 0.1 {
            self.start_legs(rig, ANIM_LEGS_LANDB if rig.backwards_jump else ANIM_LEGS_LAND, True);
            rig.legs_timer = RIG_TIMER_LAND;
            delta = rig.fall_speed * rig.fall_speed * 0.0001;
            if self.water_depth == 2 {
                delta *= 0.25;
            } elif self.water_depth == 1 {
                delta *= 0.5;
            }
            if self.water_depth < 3 and delta >= 1.0 {
                self.sounds.append(
                    "fall_far" if delta > 60.0 else ("fall_medium" if delta > 40.0 else ("land" if delta > 7.0 else "step"))
                );
            }
            rig.step_cycle = 0.0;
        }
        rig.airborne = 0.0;
        moving = forward != 0 or right != 0;
        horizontal = math.sqrt(self.velocity.x * self.velocity.x + self.velocity.y * self.velocity.y);
        if not moving {
            if horizontal < 5.0 {
                rig.step_cycle = 0.0;
                self.continue_legs(rig, ANIM_LEGS_IDLECR if self.crouched else ANIM_LEGS_IDLE);
            }
            return;
        }
        bob = 0.4;
        footstep = False;
        if self.crouched {
            bob = 0.5;
            self.continue_legs(rig, ANIM_LEGS_BACKCR if backwards else ANIM_LEGS_WALKCR);
        } elif self.walking {
            bob = 0.3;
            self.continue_legs(rig, ANIM_LEGS_BACKWALK if backwards else ANIM_LEGS_WALK);
        } else {
            footstep = True;
            self.continue_legs(rig, ANIM_LEGS_BACK if backwards else ANIM_LEGS_RUN);
        }
        # The bob cycle crosses a step every 128 of its 256 units.
        before = rig.step_cycle;
        rig.step_cycle = (before + bob * self.dt * 1000.0) % 256.0;
        if (int(before + 64.0) ^ int(rig.step_cycle + 64.0)) & 128 != 0 {
            if self.water_depth == 0 {
                if footstep {
                    self.sounds.append("step");
                }
            } elif self.water_depth == 1 {
                self.sounds.append("splash");
            }
        }
    }

    """PM_Weapon and PM_TorsoAnimation: drop and raise on a switch, an attack
    sequence per shot, standing again once the weapon is ready."""
    def animate_torso(rig: PlayerRig) {
        stand = ANIM_TORSO_STAND2 if rig.weapon == "gauntlet" else ANIM_TORSO_STAND;
        if self.switching != rig.switching {
            rig.switching = self.switching;
            if self.switching == "drop" {
                self.start_torso(rig, ANIM_TORSO_DROP);
            } elif self.switching == "raise" {
                self.start_torso(rig, ANIM_TORSO_RAISE);
            } else {
                self.start_torso(rig, stand);
            }
        }
        fired = self.shots >= 0 and self.shots != rig.seen_shots;
        if self.shots >= 0 {
            rig.seen_shots = self.shots;
        }
        if fired and not self.switching {
            self.start_torso(rig, ANIM_TORSO_ATTACK2 if rig.weapon == "gauntlet" else ANIM_TORSO_ATTACK);
            rig.flash_time = rig.clock;
            rig.flash_roll = (rig_random(rig) * 2.0 - 1.0) * 10.0;
        }
        if self.gesture and rig.torso_timer <= 0.0 {
            self.start_torso(rig, ANIM_TORSO_GESTURE);
            rig.torso_timer = RIG_TIMER_GESTURE;
        }
        if self.ready and not fired and not self.switching {
            self.continue_torso(rig, stand);
        }
        # EF_FIRING: the trigger is held while shots keep coming.
        rig.firing = rig.clock - rig.flash_time < 0.2;
    }

    """cg_weapons.c CG_MachinegunSpinAngle: barrels spin while firing and
    coast to a stop over a second."""
    def spin_barrel(rig: PlayerRig) {
        delta = rig.clock - rig.barrel_time;
        angle = rig.barrel_angle;
        if rig.barrel_spinning {
            angle += delta * 900.0;
        } else {
            coast = min(delta, 1.0) * 1000.0;
            angle += coast * 0.5 * (0.9 + (1000.0 - coast) / 1000.0);
        }
        if rig.barrel_spinning != rig.firing {
            rig.barrel_time = rig.clock;
            rig.barrel_angle = angle % 360.0;
            rig.barrel_spinning = rig.firing;
        }
        rig.barrel_roll = angle % 360.0;
    }

    """cg_players.c CG_PlayerAngles: the head looks exactly along the view;
    the legs point toward the direction of travel and the torso a quarter of
    that, each swinging to catch up; the torso shows three quarters of the
    pitch; the legs lean into their motion; a hit twitches the torso."""
    def turn_parts(rig: PlayerRig, view_yaw: float, view_pitch: float) {
        dt = self.dt;
        if rig.legs_anim != ANIM_LEGS_IDLE or rig.torso_anim not in [ANIM_TORSO_STAND, ANIM_TORSO_STAND2] {
            # Anything but standing still keeps every part pointed the same way.
            rig.torso.yawing = True;
            rig.torso.pitching = True;
            rig.legs.yawing = True;
        }
        offset = RIG_MOVE_OFFSETS[rig.move_dir] if rig.alive else 0.0;
        swung = swing_angle(view_yaw + 0.25 * offset, 25.0, 90.0, 300.0, rig.torso.yaw, rig.torso.yawing, dt);
        rig.torso.yaw = swung[0];
        rig.torso.yawing = swung[1];
        swung = swing_angle(view_yaw + offset, 40.0, 90.0, 300.0, rig.legs.yaw, rig.legs.yawing, dt);
        rig.legs.yaw = swung[0];
        rig.legs.yawing = swung[1];
        pitch = view_pitch - 360.0 if view_pitch > 180.0 else view_pitch;
        swung = swing_angle(pitch * 0.75, 15.0, 30.0, 100.0, rig.torso.pitch, rig.torso.pitching, dt);
        rig.torso.pitch = swung[0];
        rig.torso.pitching = swung[1];
        legs = Vec3(y=rig.legs.yaw);
        torso = Vec3(x=rig.torso.pitch, y=rig.torso.yaw);
        head = Vec3(x=view_pitch, y=view_yaw);
        speed = self.velocity.length();
        if speed > 0.001 and rig.alive {
            heading = self.velocity.scale(1.0 / speed);
            axes = quake_basis(legs);
            legs.z -= speed * 0.05 * heading.dot(axes.left);
            legs.x += speed * 0.05 * heading.dot(axes.forward);
        }
        since = rig.clock - rig.pain_time;
        if since < 0.2 {
            twitch = 20.0 * (1.0 - since / 0.2);
            torso.z += twitch if rig.pain_left else -twitch;
        }
        # Pull the angles back out of the hierarchical chain.
        rig.legs_angles = legs;
        rig.torso_angles = Vec3(
            x=angle_delta(torso.x, legs.x), y=angle_delta(torso.y, legs.y), z=angle_delta(torso.z, legs.z)
        );
        rig.head_angles = Vec3(
            x=angle_delta(head.x, torso.x), y=angle_delta(head.y, torso.y), z=angle_delta(head.z, torso.z)
        );
    }
}

"""The file a rig's sound cue plays (cg_players.c cg_customSoundNames from
the character's voice, cg_main.c footsteps by its footstep type)."""
def rig_sound(rig: PlayerRig, cue: str) -> str {
    voice = rig.voice;
    if cue.startswith("pain") {
        return voice + cue + "_1.wav";
    }
    if cue.startswith("death") {
        return voice + cue + ".wav";
    }
    if cue == "jump" {
        return voice + "jump1.wav";
    }
    if cue == "fall_medium" {
        return voice + "pain100_1.wav";
    }
    if cue == "fall_far" {
        return voice + "fall1.wav";
    }
    if cue == "gasp" {
        return voice + "gasp.wav";
    }
    if cue == "land" {
        return "sound/player/land1.wav";
    }
    if cue == "step" or cue == "splash" {
        kind = rig.footsteps if cue == "step" else "splash";
        return "sound/player/footsteps/" + kind + str(1 + int(rig_random(rig) * 4.0) % 4) + ".wav";
    }
    return "";
}

"""Every file `rig_sound` can return for this rig."""
def rig_sound_paths(rig: PlayerRig) -> list[str] {
    paths: list[str] = [];
    for tier in ["25", "50", "75", "100"] {
        paths.append(rig.voice + "pain" + tier + "_1.wav");
    }
    for index in ["1", "2", "3"] {
        paths.append(rig.voice + "death" + index + ".wav");
    }
    for name in ["jump1.wav", "fall1.wav", "gasp.wav"] {
        paths.append(rig.voice + name);
    }
    paths.append("sound/player/land1.wav");
    for kind in [rig.footsteps, "splash"] {
        for index in ["1", "2", "3", "4"] {
            paths.append("sound/player/footsteps/" + kind + index + ".wav");
        }
    }
    return paths;
}
