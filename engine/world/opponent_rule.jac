"""Game-owned enemy tuning consumed by shared graph combat behavior."""

# One authored attack sequence. Times are simulation seconds from the start of
# the sequence; frames advance at 10 Hz. Ranges select which sequences a
# monster may choose at its current distance to the target.
obj AttackProfile {
    has name: str = "",
        kind: str = "ranged",
        weight: float = 1.0,
        min_range: float = 0.0,
        max_range: float = 1500.0,
        times: list[float] = [0.0],
        duration: float = 0.25,
        frames: list[str] = [],
        steps: list[float] = [],
        hold_frame: int = -1,
        burst_min: int = 1,
        burst_max: int = 1,
        repeat_start: float = -1.0,
        repeat_end: float = -1.0,
        repeat_chance: float = 0.0,
        sound: str = "",
        sound_times: list[float] = [0.0],
        extra_sound: str = "",
        extra_sound_times: list[float] = [],
        damage: int = 0,
        damage_max: int = 0,
        damages: list[int] = [],
        random_scale: float = 0.0,
        knockback: float = 0.0,
        reach: float = 64.0,
        pellets: int = 1,
        spread: float = 0.0,
        vertical_spread: float = -1.0,
        aim_spread: float = 0.0,
        aim_vertical: float = 0.0,
        aim_lag: float = 0.0,
        lock_aim: bool = False,
        rail: bool = False,
        missile_speed: float = 0.0,
        missile_effect: str = "",
        missile_yaw: list[float] = [],
        missile_count: int = 1,
        gravity: bool = False,
        splash: int = 0,
        radius: float = 0.0,
        homing: float = 0.0,
        beam_damage: int = 0,
        beam_radius: float = 0.0,
        burst_damage: int = 0,
        burst_radius: float = 0.0,
        beam_kind: str = "lightning",
        leap_speed: float = 0.0,
        leap_lift: float = 0.0,
        leap_lift_random: float = 0.0,
        leap_contact_speed: float = 400.0,
        dodge_only: bool = False,
        crouch_start: float = -1.0,
        crouch_end: float = -1.0,
        revive_at: float = -1.0;
}

obj OpponentRule {
    has model: str = "",
        script: str = "",
        skin: int = 0,
        health: int = 60,
        width: float = 16.0,
        hull_bottom: float = -24.0,
        hull_top: float = 32.0,
        movement: str = "walk",
        decoration: bool = False,
        passive: bool = False,
        inert: bool = False,
        pain_duration: float = 0.3,
        pain_interval: float = 1.0,
        pain_frames: list[str] = [],
        duck_frames: list[str] = [],
        duck_down: int = 0,
        duck_hold: int = 1,
        duck_up: int = 3,
        duck_grenade: str = "",
        crouch_frames: list[str] = [],
        crouch_times: list[float] = [],
        crouch_duration: float = 0.0,
        crouch_start: float = -1.0,
        crouch_end: float = -1.0,
        pain_variants: list[list[str]] = [],
        pain_variant_damage: list[int] = [],
        pain_variant_durations: list[float] = [],
        pain_threshold: int = 0,
        pain_chance_scale: float = 0.0,
        pain_health_reset: int = 0,
        knockdown_damage: int = 0,
        knockdown_frames: list[str] = [],
        knockdown_duration: float = 0.0,
        knockdown_hold_frame: int = -1,
        knockdown_hold_time: float = 0.0,
        blast_scale: float = 1.0,
        death_splash: int = 0,
        death_radius: float = 0.0,
        vanish_on_death: bool = False,
        idle_frames: list[str] = [],
        death_frames: list[str] = [],
        sight_sound: str = "",
        pain_sounds: list[str] = [],
        death_sound: str = "",
        idle_sound: str = "",
        successor: str = "",
        speed: float = 100.0,
        damage: int = 4,
        pellets: int = 1,
        spread: float = 0.0,
        vertical_spread: float = -1.0,
        aim_spread: float = 0.0,
        aim_vertical: float = 0.0,
        aim_lag: float = 0.0,
        lock_aim: bool = False,
        rail: bool = False,
        ranged_min: float = 0.0,
        near_chance: float = -1.0,
        mid_chance: float = -1.0,
        rest_min: float = 0.0,
        rest_random: float = 2.0,
        slides: bool = False,
        medic: bool = False,
        power_screen: int = 0,
        attack_sound: str = "",
        attack_sound_times: list[float] = [0.0],
        melee_sound: str = "",
        melee_sound_times: list[float] = [0.0],
        alternate_melee_sound_times: list[float] = [0.0],
        attack_times: list[float] = [0.0],
        attack_duration: float = 0.25,
        repeat_start: float = -1.0,
        repeat_end: float = -1.0,
        repeat_chance: float = 0.0,
        melee_repeat_start: float = -1.0,
        melee_repeat_end: float = -1.0,
        melee_repeat_chance: float = 0.0,
        burst_min: int = 1,
        burst_max: int = 1,
        hold_frame: int = -1,
        attack_frames: list[str] = [],
        run_frames: list[str] = [],
        attack_steps: list[float] = [],
        attack_range: float = 1500.0,
        stop_range: float = 180.0,
        melee: int = 0,
        melee_max: int = 0,
        melee_random_scale: float = 0.0,
        melee_knockback: float = 0.0,
        melee_times: list[float] = [],
        melee_frames: list[str] = [],
        melee_steps: list[float] = [],
        melee_duration: float = 0.0,
        alternate_melee_damage: int = -1,
        alternate_melee_max: int = -1,
        alternate_melee_times: list[float] = [],
        alternate_melee_frames: list[str] = [],
        alternate_melee_steps: list[float] = [],
        alternate_melee_duration: float = 0.0,
        melee_range: float = 64.0,
        missile_speed: float = 0.0,
        missile_yaw: list[float] = [],
        missile_effect: str = "",
        gravity: bool = False,
        splash: int = 0,
        radius: float = 0.0,
        attacks: list[AttackProfile] = [];
}

# Definitions written against the single ranged/melee/alternate layout are
# expressed as profiles, so the engine has one attack representation.
def rule_profiles(rule: OpponentRule) -> list[AttackProfile] {
    if rule.attacks {
        return rule.attacks;
    }
    profiles: list[AttackProfile] = [];
    if rule.decoration or rule.passive or rule.inert {
        return profiles;
    }
    has_melee = rule.melee > 0 or rule.melee_random_scale > 0.0;
    if has_melee and rule.melee_times {
        profiles.append(
            AttackProfile(
                name="melee",
                kind="melee",
                max_range=rule.melee_range,
                reach=rule.melee_range,
                times=rule.melee_times,
                duration=rule.melee_duration,
                frames=rule.melee_frames,
                steps=rule.melee_steps,
                sound=rule.melee_sound,
                sound_times=rule.melee_sound_times,
                damage=rule.melee,
                damage_max=rule.melee_max,
                random_scale=rule.melee_random_scale,
                knockback=rule.melee_knockback,
                repeat_start=rule.melee_repeat_start,
                repeat_end=rule.melee_repeat_end,
                repeat_chance=rule.melee_repeat_chance
            )
        );
        if rule.alternate_melee_times {
            profiles.append(
                AttackProfile(
                    name="alternate",
                    kind="melee",
                    max_range=rule.melee_range,
                    reach=rule.melee_range,
                    times=rule.alternate_melee_times,
                    duration=rule.alternate_melee_duration,
                    frames=rule.alternate_melee_frames,
                    steps=rule.alternate_melee_steps,
                    sound=rule.melee_sound,
                    sound_times=rule.alternate_melee_sound_times,
                    damage=rule.alternate_melee_damage
                        if rule.alternate_melee_damage >= 0
                        else rule.melee,
                    damage_max=rule.alternate_melee_max
                        if rule.alternate_melee_max >= 0
                        else rule.melee_max,
                    random_scale=rule.melee_random_scale,
                    knockback=rule.melee_knockback
                )
            );
        }
    } elif has_melee {
        profiles.append(
            AttackProfile(
                name="melee",
                kind="melee",
                max_range=rule.melee_range,
                reach=rule.melee_range,
                times=rule.attack_times,
                duration=rule.attack_duration,
                frames=rule.attack_frames,
                steps=rule.attack_steps,
                sound=rule.melee_sound,
                sound_times=rule.melee_sound_times,
                damage=rule.melee,
                damage_max=rule.melee_max,
                random_scale=rule.melee_random_scale,
                knockback=rule.melee_knockback
            )
        );
    }
    if not has_melee
        or (rule.melee_times and rule.attack_range > rule.melee_range) {
        profiles.append(
            AttackProfile(
                name="ranged",
                kind="ranged",
                min_range=rule.ranged_min,
                max_range=rule.attack_range,
                times=rule.attack_times,
                duration=rule.attack_duration,
                frames=rule.attack_frames,
                steps=rule.attack_steps,
                hold_frame=rule.hold_frame,
                burst_min=rule.burst_min,
                burst_max=rule.burst_max,
                repeat_start=rule.repeat_start,
                repeat_end=rule.repeat_end,
                repeat_chance=rule.repeat_chance,
                sound=rule.attack_sound,
                sound_times=rule.attack_sound_times,
                damage=rule.damage,
                pellets=rule.pellets,
                spread=rule.spread,
                vertical_spread=rule.vertical_spread,
                aim_spread=rule.aim_spread,
                aim_vertical=rule.aim_vertical,
                aim_lag=rule.aim_lag,
                lock_aim=rule.lock_aim,
                rail=rule.rail,
                missile_speed=rule.missile_speed,
                missile_effect=rule.missile_effect,
                missile_yaw=rule.missile_yaw,
                gravity=rule.gravity,
                splash=rule.splash,
                radius=rule.radius
            )
        );
        # Q2 soldiers answer some dodges by crouching and firing (attack3).
        if rule.crouch_frames {
            profiles.append(
                AttackProfile(
                    name="crouch",
                    kind="ranged",
                    weight=0.0,
                    dodge_only=True,
                    min_range=rule.ranged_min,
                    max_range=rule.attack_range,
                    times=rule.crouch_times,
                    duration=rule.crouch_duration,
                    frames=rule.crouch_frames,
                    sound=rule.attack_sound,
                    sound_times=rule.crouch_times,
                    damage=rule.damage,
                    pellets=rule.pellets,
                    spread=rule.spread,
                    vertical_spread=rule.vertical_spread,
                    aim_spread=rule.aim_spread,
                    aim_vertical=rule.aim_vertical,
                    aim_lag=rule.aim_lag,
                    missile_speed=rule.missile_speed,
                    missile_effect=rule.missile_effect,
                    crouch_start=rule.crouch_start,
                    crouch_end=rule.crouch_end
                )
            );
        }
    }
    return profiles;
}
