"""How the view reacts to the body: damage flashes and kicks, liquid tints,
the item pickup flash, landing dips, weapon punch and the death view.

Q1 view.c: V_ParseDamage (cshift_damage, v_dmg_roll/pitch), V_SetContentsColor,
V_BonusFlash_f, V_CalcRefdef's dead roll. Q2 p_view.c: P_DamageFeedback
(damage_blend/alpha, kick angles), SV_CalcBlend, P_FallingDamage's fall kick,
the dead view. Q3 cg_view.c: CG_DamageFeedback / CG_DamageBlendBlob, the
landing change and CG_OffsetFirstPersonView's dead view. Each game also eases
the eye up a step instead of jumping it there (Q1 V_CalcRefdef's oldz, Q2
cl.predicted_step, Q3 cg.stepChange). `place` puts it together with the
game's sway (view_sway.jac) into where the eye and the gun are this frame."""
import math;
import from ..world.world { Player }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from .view_sway { ViewSway, ViewBase, ViewPlacement, view_sway_for }

"""One full-screen colour layer, composed in order as V_CalcBlend does."""
obj ScreenTint {
    has r: int, g: int, b: int, a: int;
}

obj ViewFeedback {
    has game: str = "",
        damage_color: Vec3 = Vec3(),
        damage_level: float = 0.0,
        kick_pitch: float = 0.0,
        kick_roll: float = 0.0,
        kick_time: float = 0.0,
        bonus: float = 0.0,
        fall_pitch: float = 0.0,
        fall_time: float = 0.0,
        land_drop: float = 0.0,
        land_time: float = 0.0,
        blob_x: float = 0.0,
        blob_y: float = 0.0,
        blob_value: float = 0.0,
        blob_time: float = 0.0,
        flashes: int = 0,
        flash_time: float = 0.0,
        step_z: float = 0.0,
        step_ready: bool = False,
        step_change: float = 0.0,
        step_time: float = 0.0,
        step_was: float = 0.0,
        carried: float = 0.0,
        carried_was: float = 0.0,
        duck_change: float = 0.0,
        duck_time: float = 0.0,
        duck_was: float = 0.0,
        sway: ViewSway = ViewSway();

    def reset(game: str) {
        self.game = game;
        self.sway = view_sway_for(game);
        self.step_was = 0.0;
        self.carried = 0.0;
        self.carried_was = 0.0;
        self.duck_time = 0.0;
        self.duck_was = 0.0;
        self.damage_level = 0.0;
        self.kick_time = 0.0;
        self.bonus = 0.0;
        self.fall_time = 0.0;
        self.land_time = 0.0;
        self.blob_time = 0.0;
        self.flash_time = 0.0;
        self.step_ready = False;
        self.step_time = 0.0;
    }

    """Turn the hits the player took since the last frame into a flash and
    a kick, and clear them."""
    def take_damage(player: Player) {
        blood = float(player.damage_blood);
        armor = float(player.damage_armor);
        source = player.damage_from;
        player.damage_blood = 0;
        player.damage_armor = 0;
        player.damage_from = None;
        if blood + armor <= 0.0 {
            return;
        }
        # Q2 P_DamageFeedback STAT_FLASHES: 1 after a hit to health, 2 after
        # armor took one, shown for a server frame.
        self.flashes = (1 if blood > 0.0 else 0) | (2 if armor > 0.0 else 0);
        self.flash_time = 0.1;
        ahead = forward_from(player.yaw, 0.0);
        side = right_from(player.yaw);
        toward = Vec3();
        if source is not None {
            toward = source.sub(player.pos).normalized();
        }
        if self.game == "q1" {
            count = max(10.0, blood * 0.5 + armor * 0.5);
            self.damage_level = min(150.0, max(0.0, self.damage_level) + 3.0 * count);
            if armor > blood {
                self.damage_color = Vec3(x=200.0, y=100.0, z=100.0);
            } elif armor > 0.0 {
                self.damage_color = Vec3(x=220.0, y=50.0, z=50.0);
            } else {
                self.damage_color = Vec3(x=255.0, y=0.0, z=0.0);
            }
            # v_kickroll / v_kickpitch 0.6, v_kicktime 0.5.
            self.kick_roll = count * toward.dot(side) * 0.6;
            self.kick_pitch = count * toward.dot(ahead) * 0.6;
            self.kick_time = 0.5;
        } elif self.game == "q2" {
            total = blood + armor;
            count = max(10.0, total);
            self.damage_level = max(0.2, min(0.6, max(0.0, self.damage_level) + count * 0.01));
            self.damage_color = Vec3(x=1.0, y=0.0, z=0.0).scale(blood / total).add(
                Vec3(x=1.0, y=1.0, z=1.0).scale(armor / total)
            );
            if player.health > 0 and source is not None {
                kick = min(50.0, max(count * 0.5, total * 100.0 / float(max(1, player.health))));
                self.kick_roll = kick * toward.dot(side) * 0.3;
                self.kick_pitch = -kick * toward.dot(ahead) * 0.3;
                self.kick_time = 0.5;
            }
        } elif self.game == "q3" {
            scale = 1.0 if player.health < 40 else 40.0 / float(player.health);
            kick = max(5.0, min(10.0, (blood + armor) * scale));
            if source is None {
                self.blob_x = 0.0;
                self.blob_y = 0.0;
                self.kick_roll = 0.0;
                self.kick_pitch = -kick;
            } else {
                front = toward.dot(ahead);
                left = -toward.dot(side);
                up = toward.z;
                flat = max(0.1, math.sqrt(front * front + left * left));
                self.kick_roll = kick * left;
                self.kick_pitch = -kick * front;
                self.blob_x = max(-1.0, min(1.0, -left / max(0.1, front)));
                self.blob_y = max(-1.0, min(1.0, up / flat));
            }
            self.blob_value = kick;
            self.blob_time = 0.5;
            self.kick_time = 0.5;
        }
    }

    """The player fired a weapon kicking the view this way (Q2 kick_origin
    and kick_angles; the others kick by the weapon punch alone)."""
    def recoil(back: float, shake: float, twist: list[float]) {
        self.sway.recoil(back, shake, twist);
    }

    """V_BonusFlash_f / Q2 bonus_alpha: a gold flash on picking something up."""
    def pickup() {
        if self.game == "q1" {
            self.bonus = 50.0;
        } elif self.game == "q2" {
            self.bonus = 0.25;
        }
    }

    """Q2 fall_value (pitch, fading over 0.3 s) or Q3 landChange (a dip)."""
    def landing(kick: float, drop: float) {
        self.sway.landed();
        if kick > 0.0 {
            self.fall_pitch = kick;
            self.fall_time = 0.3;
        }
        if drop > 0.0 {
            self.land_drop = drop;
            self.land_time = 0.3;
        }
    }

    def advance(dt: float) {
        if self.game == "q1" {
            self.damage_level = max(0.0, self.damage_level - 150.0 * dt);
            self.bonus = max(0.0, self.bonus - 100.0 * dt);
        } else {
            self.damage_level = max(0.0, self.damage_level - 0.6 * dt);
            self.bonus = max(0.0, self.bonus - 1.0 * dt);
        }
        self.kick_time = max(0.0, self.kick_time - dt);
        self.fall_time = max(0.0, self.fall_time - dt);
        self.land_time = max(0.0, self.land_time - dt);
        self.blob_time = max(0.0, self.blob_time - dt);
        self.flash_time = max(0.0, self.flash_time - dt);
    }

    """A physics tick begins: keep the step offset the frames until the next
    tick blend from, let the step ease on and move the sway along with the
    body. Steps are events of the simulation, so their easing runs on its
    ticks and is drawn between them like the body it offsets."""
    def tick(player: Player, moving: bool, dt: float) {
        self.step_was = self.step_offset();
        self.carried_was = self.carried;
        self.duck_was = self.duck_offset();
        self.duck_time = max(0.0, self.duck_time - dt);
        self.step_time = max(0.0, self.step_time - dt);
        self.sway.tick(player, moving, dt);
    }

    """A step up the body just climbed, in units. Q2 CL_PredictMovement keeps
    one of 8 to 20 units (63 < step < 160 in eighths) and lowers the view by it
    over 100 ms. Q3 CG_StepEvent rounds it to an EV_STEP_4, 8, 12 or 16, adds
    what is left of the last one (at most 32) and lowers the view over 200 ms.
    Q1 needs no event: `climb` watches the eye itself."""
    def step(rise: float) {
        if self.game == "q2" {
            if rise > 7.875 and rise < 20.0 {
                self.step_change = rise;
                self.step_time = 0.1;
            }
        } elif self.game == "q3" {
            if rise <= 2.0 {
                return;
            }
            size = 4.0
                if rise < 7.0
                else (8.0 if rise < 11.0 else (12.0 if rise < 15.0 else 16.0));
            left = self.step_change * self.step_time / 0.2;
            self.step_change = min(32.0, left + size);
            self.step_time = 0.2;
        }
    }

    """A mover (a plat, door, train or rotator) carried the body `rise` units.
    Q1's V_CalcRefdef eases that like a step too, so a lift faster than 80
    units a second leaves the eye 12 behind for the whole ride and a step off
    its top (forward held against the shaft wall steps up to 18 units onto
    the landing before the lift arrives) then jumps the eye in one frame. The
    eye rides the lift rigidly instead, keeping the 12 for the steps: `climb`
    eases the body's height less all it has been carried, which moves between
    ticks with the body. Q2 and Q3 ease step events alone, so the ride never
    touches them."""
    def ride(rise: float) {
        if self.game == "q1" {
            self.carried += rise;
        }
    }

    """Units the eye sits below the body's eye this frame while it catches up
    with a step. Q1 V_CalcRefdef ("smooth out stair step ups"): on the ground
    and rising, the view follows at 80 units a second but never more than 12
    behind, so a stair or a platform's lip eases in; anything else puts it
    straight back on the body (`z` is the body as drawn this frame). Q2 and
    Q3 lower it by the last `step` as that fades, `share` of the way through
    the last physics tick."""
    def climb(z: float, grounded: bool, dt: float, share: float = 1.0) -> float {
        if self.game == "q1" {
            footing = z - (self.carried_was + (self.carried - self.carried_was) * share);
            if self.step_ready and grounded and footing > self.step_z {
                self.step_z = max(footing - 12.0, min(footing, self.step_z + 80.0 * dt));
            } else {
                self.step_z = footing;
            }
            self.step_ready = True;
            return footing - self.step_z;
        }
        return self.step_was + (self.step_offset() - self.step_was) * share;
    }

    """The eye height changed by `change` as the body crouched or stood. Q3
    CG_OffsetFirstPersonView eases it over DUCK_TIME (100 ms) from where it
    was; Q2's client lerps the view offset over the 100 ms server frame."""
    def duck(change: float) {
        if self.game in ["q2", "q3"] {
            self.duck_change = change;
            self.duck_time = 0.1;
        }
    }

    """Units below the body's eye that the crouch or stand being eased puts the
    view, as the last tick left it (negative while crouching: the eye is still
    above the lowered body eye)."""
    def duck_offset() -> float {
        if self.duck_time <= 0.0 {
            return 0.0;
        }
        return self.duck_change * self.duck_time / 0.1;
    }

    """Q2 and Q3: how far below the body the eye sits as the last tick left
    it, the last step fading over 100 or 200 ms."""
    def step_offset() -> float {
        if self.game not in ["q2", "q3"] or self.step_time <= 0.0 {
            return 0.0;
        }
        return self.step_change * self.step_time / (0.1 if self.game == "q2" else 0.2);
    }

    """STAT_FLASHES while the last hit's frame lasts."""
    def status_flashes() -> int {
        return self.flashes if self.flash_time > 0.0 else 0;
    }

    """How far the kick has come: Q1/Q2 fade it out over half a second; Q3
    deflects for 100 ms and returns over 400 ms."""
    def kick_share() -> float {
        if self.kick_time <= 0.0 {
            return 0.0;
        }
        if self.game == "q3" {
            elapsed = 0.5 - self.kick_time;
            if elapsed < 0.1 {
                return elapsed / 0.1;
            }
            return max(0.0, 1.0 - (elapsed - 0.1) / 0.4);
        }
        return self.kick_time / 0.5;
    }

    """Degrees to add to the view pitch (Quake's sense: positive looks down)."""
    def pitch() -> float {
        return self.kick_share() * self.kick_pitch + self.fall_pitch * self.fall_time / 0.3;
    }

    def roll() -> float {
        return self.kick_share() * self.kick_roll;
    }

    """Units the eye sinks: Q2 SV_CalcViewOffset lowers it by 0.4 of the
    fall kick as that fades; Q3's landing dip deflects over 150 ms and
    returns over 150 more."""
    def eye_drop() -> float {
        if self.game == "q2" {
            return self.fall_pitch * 0.4 * self.fall_time / 0.3;
        }
        if self.land_time <= 0.0 {
            return 0.0;
        }
        elapsed = 0.3 - self.land_time;
        share = elapsed / 0.15 if elapsed < 0.15 else max(0.0, 1.0 - (elapsed - 0.15) / 0.15);
        return self.land_drop * share;
    }

    """Where the eye and the gun are this frame. `body` is the body's eye as
    drawn this frame (between ticks, engine/math/interpolation.jac), `share`
    how far through the last tick that is, `clock` the simulation time shown
    and `punch` the weapon punch in degrees (positive looks up). The eye is
    eased up steps and dipped by landings, then the game's sway bobs and rolls
    it and places the gun; the dead view replaces it all, and an intermission
    camera takes none of it (Q2 ClientEndServerFrame and Q3
    CG_OffsetFirstPersonView skip it), Q1 swaying it gently instead
    (V_CalcIntermissionRefdef's V_AddIdle at v_idlescale 1)."""
    def place(
        player: Player,
        body: Vec3,
        grounded: bool,
        frame_dt: float,
        clock: float,
        share: float,
        punch: float,
        eye_height: float,
        dead: bool = False,
        intermission: bool = False
    ) -> ViewPlacement {
        if intermission {
            yaw = player.yaw;
            pitch = player.pitch;
            roll = 0.0;
            if self.game == "q1" {
                # v_iroll_cycle 0.5 / level 0.1, v_ipitch 1 / 0.3, v_iyaw 2 / 0.3.
                roll = math.radians(math.sin(clock * 0.5) * 0.1);
                pitch -= math.radians(math.sin(clock) * 0.3);
                yaw += math.radians(math.sin(clock * 2.0) * 0.3);
            }
            return ViewPlacement(
                eye=body, yaw=yaw, pitch=pitch, roll=roll, gun=body,
                gun_yaw=yaw, gun_pitch=pitch, gun_roll=roll
            );
        }
        dip = self.eye_drop();
        sink = dip
            + self.climb(body.z, grounded, frame_dt, share)
            + self.duck_was
            + (self.duck_offset() - self.duck_was) * share;
        if dead {
            fallen = death_view(player, self.game, eye_height);
            eye = body.sub(Vec3(z=fallen[0]));
            pitch = math.radians(fallen[1]);
            roll = math.radians(fallen[2]);
            return ViewPlacement(
                eye=eye, yaw=fallen[3], pitch=pitch, roll=roll, gun=eye,
                gun_yaw=fallen[3], gun_pitch=pitch, gun_roll=roll
            );
        }
        return self.sway.place(
            player,
            ViewBase(
                eye=body.sub(Vec3(z=sink)),
                yaw=player.yaw,
                pitch=player.pitch,
                kick_pitch=self.pitch(),
                kick_roll=self.roll(),
                punch=punch,
                dip=dip
            ),
            clock,
            share
        );
    }

    """The colour layers over the view, in V_CalcBlend order: the liquid the
    eye is in, then damage, then the pickup flash."""
    def tints(liquid: int, submerged: bool) -> list[ScreenTint] {
        layers: list[ScreenTint] = [];
        if self.game == "q1" {
            if submerged and liquid == 1 {
                layers.append(ScreenTint(r=130, g=80, b=50, a=128));
            } elif submerged and liquid == 2 {
                layers.append(ScreenTint(r=0, g=25, b=5, a=150));
            } elif submerged and liquid == 3 {
                layers.append(ScreenTint(r=255, g=80, b=0, a=150));
            }
            if self.damage_level > 0.0 {
                layers.append(
                    ScreenTint(
                        r=int(self.damage_color.x),
                        g=int(self.damage_color.y),
                        b=int(self.damage_color.z),
                        a=int(min(255.0, self.damage_level))
                    )
                );
            }
            if self.bonus > 0.0 {
                layers.append(ScreenTint(r=215, g=186, b=69, a=int(self.bonus)));
            }
        } elif self.game == "q2" {
            if submerged and liquid == 3 {
                layers.append(ScreenTint(r=255, g=77, b=0, a=153));
            } elif submerged and liquid == 2 {
                layers.append(ScreenTint(r=0, g=25, b=13, a=153));
            } elif submerged and liquid == 1 {
                layers.append(ScreenTint(r=128, g=77, b=51, a=102));
            }
            if self.damage_level > 0.0 {
                layers.append(
                    ScreenTint(
                        r=int(255.0 * self.damage_color.x),
                        g=int(255.0 * self.damage_color.y),
                        b=int(255.0 * self.damage_color.z),
                        a=int(255.0 * self.damage_level)
                    )
                );
            }
            if self.bonus > 0.0 {
                layers.append(ScreenTint(r=217, g=179, b=77, a=int(255.0 * self.bonus)));
            }
        }
        return layers;
    }

    """CG_DamageBlendBlob: the blood sprite's offset (damageX, damageY in
    units of 8 at 8 units ahead), its radius there and its opacity; empty
    when not showing."""
    def blob() -> list[float] {
        if self.game != "q3" or self.blob_time <= 0.0 or self.blob_value <= 0.0 {
            return [];
        }
        fade = self.blob_time / 0.5;
        return [self.blob_x, self.blob_y, self.blob_value * 3.0, fade * 200.0 / 255.0];
    }
}

"""The dead view: Q1 rolls 80 degrees with the eye 8 below the origin; Q2
rolls 40, looks 15 degrees up toward the killer from 8 above the origin; Q3
the same from 16 below (DEAD_VIEWHEIGHT). Returns [drop, pitch, roll, yaw]."""
def death_view(player: Player, game: str, eye_height: float) -> list[float] {
    yaw = player.yaw;
    killer = player.killer;
    if game in ["q2", "q3"] and killer is not None and killer is not player {
        toward = killer.pos.sub(player.pos);
        if abs(toward.x) + abs(toward.y) > 0.001 {
            yaw = math.atan2(toward.y, toward.x);
        }
    }
    if game == "q1" {
        return [eye_height + 8.0, 0.0, 80.0, yaw];
    }
    if game == "q2" {
        return [eye_height - 8.0, 15.0, 40.0, yaw];
    }
    return [eye_height + 16.0, 15.0, 40.0, yaw];
}
