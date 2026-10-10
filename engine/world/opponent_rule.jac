"""Game-owned enemy tuning consumed by shared graph combat behavior."""
import from ..math.vec3 { Vec3 }

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
    # The refire frame's own test, beyond the roll above (Q2 m_soldier.c
    # soldier_attack1_refire1: `(skill == 3 && random() < 0.5) || range ==
    # RANGE_MELEE`). A target closer than `repeat_near` always sends the
    # sequence back; otherwise `repeat_chance` is rolled only from skill
    # `repeat_skill` up and with the target at least `repeat_from` away
    # (soldier_attack6_refire's RANGE_MID). `repeat_unseen` rolls without
    # the sight and range test the other refires make (chick_rerocket). A
    # refire not taken, with the target alive, skips ahead to `repeat_skip`
    # rather than playing on (attak110, attak216). `repeat_end` may be the
    # sequence's end: the last frame's think then decides whether it ends.
    has repeat_near: float = -1.0,
        repeat_skill: int = 0,
        repeat_from: float = 0.0,
        repeat_unseen: bool = False,
        repeat_skip: float = -1.0;
    # Sequences sharing a `rotation` are not drawn at random but taken in
    # turn, on one count kept for every monster (Q1 hknight_melee's global
    # hknight_type). A "run" `trigger` starts the sequence from the first
    # frame of the run cycle instead of the attack decision (Q1
    # hknight_run1's CheckForCharge): with the target in sight, attacks due
    # and the target no more than `max_rise` above or below. A "sight"
    # trigger starts it as the monster first sights its enemy, `trigger_chance`
    # of the time (Q2 soldier_sight's run-and-shoot). `min_skill` is the
    # lowest skill at which the sequence is used at all. `finished` is the
    # SUB_AttackFinished a sequence sets when it starts, if its own.
    has rotation: str = "",
        trigger: str = "",
        trigger_chance: float = 1.0,
        min_skill: int = 0,
        max_rise: float = -1.0,
        finished: float = -1.0;
    # The chance, frame by frame, that a hit is shrugged off while the
    # sequence shows that frame (Q2 jorg_pain: 0.005 through attak101-108 and
    # attak201-208, 0.00005 through attak109-114).
    has pain_shrugs: list[float] = [];
    # Per-frame aim of a charge's steps: how far to the left of the target
    # the monster heads (Q1 ai_charge_side's flyby, 30 units); a sideways
    # stride is a walkmove, which the target's box blocks.
    has sides: list[float] = [];
    # Played instead of `sound` half the time (Q1 knight_runatk1's sword2).
    has alternate_sound: str = "";
    # Played when a melee strike lands (Q2 infantry_smack's melee2).
    has hit_sound: str = "";
    # Where shots leave the monster: forward, right and up from its origin
    # (Q2 m_flash.c monster_flash_offset through G_ProjectSource, the QuakeC
    # launch origins). Successive shots of a sequence take successive
    # entries; a volley fires every pellet or missile of one shot from its own
    # entry (Jorg's and the Hornet's twin guns). Without any, shots leave the
    # eye. `flash` colours the muzzle-flash light (Q2 CL_ParseMuzzleFlash2,
    # Q1 EF_MUZZLEFLASH); black shows none.
    has muzzles: list[Vec3] = [],
        volley: bool = False,
        flash: Vec3 = Vec3();
}

"""A locomotion cycle: the model frames a monster plays at 10 Hz while it
moves and the distance each frame carries it (Q1 QuakeC ai_run(dist) /
ai_walk(dist) on every 0.1 s think; Q2 mframe_t `{ai_run, dist, NULL}`
entries of an mmove_t, stepped by M_MoveFrame). `steps` line up with
`frames`; negative distances step backwards, as the originals do."""
obj Gait {
    has frames: list[str] = [],
        steps: list[float] = [];
    # A frame whose think may turn the cycle back: once frame `branch` has
    # played, the next is `branch_to` with `branch_chance`, else the one after
    # (Q2 soldier_walk1_random at walk110 goes back to walk101 nine times in
    # ten, and otherwise stands through walk111-133).
    has branch: int = -1,
        branch_to: int = 0,
        branch_chance: float = 0.0;
}

"""What a frame of a pain or death does besides show: the think of a Q2
mframe_t, the body of a Q1 frame function. It happens as the sequence enters
`frame`."""
obj FrameEvent {
    has frame: int = 0,
        # A sound; of several, one by `weights` (even odds without any).
        sounds: list[str] = [],
        weights: list[float] = [],
        # Death: a shot with the weapon of the attack sequence named, from
        # `muzzle` (forward, right and up of the origin) along the body's
        # facing turned up by `aim_pitch` and right by `aim_yaw` degrees (Q2
        # soldier_fire's flashes 5 and 6, InfantryMachineGun's aimangles).
        # `held`, a burst weapon keeps the body on the frame while the
        # burst leaves (soldier_fire's AI_HOLD_FRAME).
        fire: str = "",
        muzzle: Vec3 = Vec3(),
        aim_pitch: float = 0.0,
        aim_yaw: float = 0.0,
        held: bool = False;
}

"""One sequence a monster plays when it is hurt or killed: its model frames
at 10 Hz (a run of Q1 QuakeC frame functions, a Q2 mmove_t) and how the
original's pain or die function comes to pick it."""
obj Reaction {
    has name: str = "",
        frames: list[str] = [],
        # The distance each frame carries the monster along its facing,
        # negative backwards (Q1 ai_painforward and ai_forward against ai_pain
        # and ai_back; Q2 `{ai_move, dist}`), scaled like the gaits.
        steps: list[float] = [],
        # The sound the original plays with this sequence. Without one the
        # rule's own pain or death sound plays.
        sound: str = "",
        # A sequence is drawn, by `weight`, from those whose damage bracket
        # holds the hit (`max_damage` -1 has no upper end); `chance` is then
        # how often it plays at all (Q2 jorg_pain's pain3, 3 times in 10).
        weight: float = 1.0,
        min_damage: int = 0,
        max_damage: int = -1,
        chance: float = 1.0,
        # Drawn only while the monster's health is in this bracket (Q2
        # insane_pain's cry for under 25, 50 or 75 health, or more).
        min_health: int = 0,
        max_health: int = -1,
        # Pain: its sound is cried even when its frames do not play, the
        # original crying before its Nightmare test.
        cries: bool = False,
        # Pain: taken instead of any other while the monster is thrown upward
        # faster than 100 units a second (Q2 soldier_move_pain4,
        # gladiator_move_pain_air). `nightmare` sequences play on Nightmare
        # too, where a Q2 monster otherwise skips its pain frames.
        airborne: bool = False,
        nightmare: bool = False,
        # Pain: the seconds before the monster may flinch again, when not the
        # rule's `pain_interval` (Q1 army_pain's pain_finished of 0.6 or 1.1).
        interval: float = -1.0,
        # Death: taken instead of any other for a hit landing within 4 units
        # of eye height (Q2 soldier_die's head shot).
        head_shot: bool = False,
        # What its frames do as they are entered (tank_footstep, makron_taunt).
        events: list[FrameEvent] = [],
        # A sequence that lies on `hold_frame` for `hold_time` seconds before
        # playing on (Q1 zombie_paine11's nextthink + 5).
        hold_frame: int = -1,
        hold_time: float = 0.0,
        # Death: the frame whose function stops the body blocking (Q1
        # `self.solid = SOLID_NOT`, the third frame of most deaths); a
        # knockdown is passable from this frame until it gets up.
        unsolid_frame: int = 0,
        # Death: the corpse is thrown as it dies, up to `toss_side` either
        # way along x and y and upward by `toss_up` plus up to
        # `toss_up_random` (Q1 wiz_death1).
        toss_side: float = 0.0,
        toss_up: float = 0.0,
        toss_up_random: float = 0.0,
        # Death: the frame whose function drops the carried item (Q1
        # DropBackpack on the third), so a monster that gibs instead drops
        # nothing. Zero drops it at once, as Q2 monster_death_use does.
        drop_frame: int = 0;
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
        good_guy: bool = False,
        inert: bool = False,
        # A body with no authored pain sequences flinches for `pain_duration`
        # on its model's first pain family. `pain_interval` is the wait
        # before the next flinch (Q1 pain_finished, Q2 pain_debounce_time);
        # zero is a monster that never checks it (Q1 dog_pain, fish_pain).
        pain_duration: float = 0.3,
        pain_interval: float = 1.0,
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
        # The sequences the monster's pain and die functions choose among.
        pains: list[Reaction] = [],
        deaths: list[Reaction] = [],
        pain_threshold: int = 0,
        pain_chance_scale: float = 0.0,
        # A hit of at most `pain_shrug_damage` is shrugged off
        # `pain_shrug_chance` of the time, before pain is due at all (Q2
        # tank_pain: 30 and 0.8).
        pain_shrug_damage: int = 0,
        pain_shrug_chance: float = 0.0,
        # When the rule's pain sound plays without a flinch: "hit" on every
        # hit that hurts (Q1 Wiz_Pain, sham_pain), "due" whenever pain is
        # due, before the flinch roll (Q1 demon1_pain, hknight_pain).
        pain_cry: str = "",
        # With more than this many seconds gone since pain was last due, a
        # hit flinches without the roll (Q1 hknight_pain: 5).
        pain_sure_after: float = -1.0,
        # Attack sequences that pain does not interrupt on Hard and above
        # (Q2 tank_pain, supertank_pain).
        pain_immune: list[str] = [],
        pain_health_reset: int = 0,
        # A hit of `knockdown_damage` or more lays the monster out on its
        # `knockdown` sequence (Q1 zombie_paine), where nothing hurts it.
        knockdown_damage: int = 0,
        knockdown: Reaction = Reaction(),
        # A hit taken while it flinches starts no new pain but arms this
        # wait, and a hit taken while the wait runs knocks it down (Q1
        # zombie_pain's inpain and pain_finished = time + 3).
        knockdown_rehit: float = 0.0,
        # demon1_pain: no pain in mid-leap (self.touch == Demon_JumpTouch),
        # and pain_finished is set as soon as pain is due, before the flinch
        # roll, so a hit shrugged off spends the wait too.
        leap_painless: bool = False,
        pain_due_wait: bool = False,
        blast_scale: float = 1.0,
        death_splash: int = 0,
        death_radius: float = 0.0,
        vanish_on_death: bool = False,
        explodes: bool = False,
        idle_frames: list[str] = [],
        # The box a corpse is left with once its death sequence ends (Q2
        # *_dead: -16 -16 -24 to 16 16 -8 for most).
        dead_width: float = 16.0,
        dead_bottom: float = -24.0,
        dead_top: float = -8.0,
        sight_sound: str = "",
        # Played instead of `sight_sound` half the time (Q2 soldier_sight).
        sight_alternate: str = "",
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
        # A second sound of the ranged sequence (Q2 infantry_cock_gun) and
        # the sound of a melee strike that lands.
        extra_sound: str = "",
        extra_sound_times: list[float] = [],
        melee_hit_sound: str = "",
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
        # The alerted run cycle and the unalerted walk (patrols, Q2 walkers
        # without a goal). Q2 M_MoveFrame scales every distance by the
        # model's monsterinfo.scale (MODEL_SCALE in m_*.h). `speed` is only
        # the pace of bodies with no frame tables (Q3 bots run at g_speed).
        run: Gait = Gait(),
        walk: Gait = Gait(),
        # Walk cycles taken instead of `walk`: each time the monster sets off
        # walking it picks `walk` or one of these, all equally likely (Q2
        # soldier_walk: walk1 or walk2, half the time each).
        other_walks: list[Gait] = [],
        step_scale: float = 1.0,
        # How far, in degrees, the monster turns toward its ideal yaw each
        # 0.1 s frame (Q1 PF_changeyaw / Q2 M_ChangeYaw by `yaw_speed`):
        # walkmonster_start gives 20, flymonster_start and swimmonster_start
        # 10, unless the spawn function set its own (Q1 boss_awake's 20).
        yaw_speed: float = 20.0,
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
        muzzles: list[Vec3] = [],
        crouch_muzzles: list[Vec3] = [],
        flash: Vec3 = Vec3(),
        attacks: list[AttackProfile] = [];
    # Further sounds a scripted encounter plays by path (Chthon's out1.wav).
    has sounds: list[str] = [];
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
                hit_sound=rule.melee_hit_sound,
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
                extra_sound=rule.extra_sound,
                extra_sound_times=rule.extra_sound_times,
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
                radius=rule.radius,
                muzzles=rule.muzzles,
                flash=rule.flash
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
                    crouch_end=rule.crouch_end,
                    muzzles=rule.crouch_muzzles,
                    flash=rule.flash
                )
            );
        }
    }
    return profiles;
}
