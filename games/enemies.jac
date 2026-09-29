"""Campaign enemy definitions; behavioral special cases remain explicit work."""
import from engine.world.opponent_rule { OpponentRule, AttackProfile, Gait }
import from engine.math.vec3 { Vec3 }

# Muzzle-flash light colours: Q1 EF_MUZZLEFLASH (the engine's orange flash)
# and Q2 CL_ParseMuzzleFlash2's per-weapon dlight colours.
glob Q1_FLASH: Vec3 = Vec3(x=1.0, y=0.65, z=0.25);
glob Q2_GUN_FLASH: Vec3 = Vec3(x=1.0, y=1.0, z=0.0);
glob Q2_ROCKET_FLASH: Vec3 = Vec3(x=1.0, y=0.5, z=0.2);
glob Q2_GRENADE_FLASH: Vec3 = Vec3(x=1.0, y=0.5, z=0.0);
glob Q2_RAIL_FLASH: Vec3 = Vec3(x=0.5, y=0.5, z=1.0);
glob Q2_BFG_FLASH: Vec3 = Vec3(x=0.5, y=1.0, z=0.5);

# Q2 model frames use two digit numbering within each family.
def two(number: int) -> str {
    return ("0" + str(number)) if number < 10 else str(number);
}

def enemy_rule(game: str, kind: str, flags: int = 0) -> OpponentRule | None {
    # Exploding barrels: Q1 misc.qc barrel_explode (160 radius damage) and Q2
    # g_misc.c barrel_explode (150 plus 40 radius). They take any damage.
    if game == "q1" and kind in ["misc_explobox", "misc_explobox2"] {
        return OpponentRule(
            model="maps/b_explob.bsp" if kind == "misc_explobox" else "maps/b_exbox2.bsp",
            health=20,
            inert=True,
            speed=0.0,
            death_splash=160,
            death_radius=200.0,
            vanish_on_death=True,
            death_sound="sound/weapons/r_exp3.wav"
        );
    }
    # g_turret.c SP_turret_driver: an infantry body with 100 health that
    # stands its ground, never attacks by itself and neither flinches, sights
    # nor dodges; its turret does the shooting.
    if game == "q2" and kind == "turret_driver" {
        driver = enemy_rule(game, "monster_infantry");
        if driver is None {
            return None;
        }
        driver.health = 100;
        driver.movement = "none";
        driver.passive = True;
        driver.pain_frames = [];
        driver.pain_sounds = [];
        driver.sight_sound = "";
        driver.duck_frames = [];
        return driver;
    }
    if game == "q2" and kind == "misc_explobox" {
        return OpponentRule(
            # SP_misc_explobox: -16 -16 0 to 16 16 40.
            hull_bottom=0.0,
            hull_top=40.0,
            model="models/objects/barrels/tris.md2",
            health=10,
            inert=True,
            speed=0.0,
            death_splash=150,
            death_radius=190.0,
            vanish_on_death=True,
            death_sound="sound/weapons/rocklx1a.wav"
        );
    }
    if game == "q1" {
        if kind == "monster_boss" {
            # boss.qc: a 256-wide box from 24 below its origin to 256 above;
            # boss_awake sets its health (1 on Easy, else 3).
            return OpponentRule(
                model="progs/boss.mdl",
                script="chthon",
                health=3,
                speed=0.0,
                width=128.0,
                hull_bottom=-24.0,
                hull_top=256.0,
                sight_sound="sound/boss1/sight1.wav",
                pain_sounds=["sound/boss1/pain.wav"],
                death_sound="sound/boss1/death.wav",
                attack_sound="sound/boss1/throw.wav",
                sounds=["sound/boss1/out1.wav"]
            );
        }
        if kind == "monster_hell_knight" {
            return OpponentRule(
                sight_sound="sound/hknight/sight1.wav",
                pain_sounds=["sound/hknight/pain1.wav"],
                death_sound="sound/hknight/death1.wav",
                idle_sound="sound/hknight/idle.wav",
                model="progs/hknight.mdl",
                # hellknight.qc hknight_run1-8 ai_run, hknight_walk1-20 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 9)],
                    steps=[20.0, 25.0, 18.0, 16.0, 14.0, 25.0, 21.0, 13.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 21)],
                    steps=[2.0, 5.0, 5.0, 4.0, 4.0, 2.0, 2.0, 3.0, 3.0, 4.0, 3.0, 4.0, 6.0, 2.0, 2.0, 4.0, 3.0, 3.0, 3.0, 2.0]
                ),
                health=250,
                attacks=[
                    # th_missile hknight_magicc1-11: six spikes from magicc6,
                    # each 6 degrees further round (hknight_shot(-2..3)).
                    AttackProfile(
                        name="magic",
                        kind="ranged",
                        times=[0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                        duration=1.1,
                        frames=["magicc" + str(i) for i in range(1, 12)],
                        sound="sound/hknight/attack1.wav",
                        sound_times=[0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                        damage=9,
                        missile_speed=300.0,
                        missile_effect="q1_knightspike",
                        missile_yaw=[-12.0, -6.0, 0.0, 6.0, 12.0, 18.0],
                        # hknight_shot: the box centre, 20 ahead.
                        muzzles=[Vec3(x=20.0, z=8.0)],
                        aim_vertical=0.05
                    ),
                    # th_melee hknight_melee: in melee range (CheckAttack's
                    # RANGE_MELEE, 120) the slice, the smash and the wide
                    # attack in turn (the global hknight_type), each slash1
                    # at its start and ai_melee hits within 60.
                    AttackProfile(
                        name="slice",
                        kind="melee",
                        rotation="hknight_type",
                        max_range=120.0,
                        reach=60.0,
                        times=[0.4, 0.5, 0.6, 0.7, 0.8],
                        duration=1.0,
                        frames=["slice" + str(i) for i in range(1, 11)],
                        steps=[9.0, 6.0, 13.0, 4.0, 7.0, 15.0, 8.0, 2.0, 0.0, 3.0],
                        sound="sound/hknight/slash1.wav",
                        random_scale=3.0
                    ),
                    AttackProfile(
                        name="smash",
                        kind="melee",
                        rotation="hknight_type",
                        max_range=120.0,
                        reach=60.0,
                        times=[0.4, 0.5, 0.6, 0.7, 0.8],
                        duration=1.1,
                        frames=["smash" + str(i) for i in range(1, 12)],
                        steps=[1.0, 13.0, 9.0, 11.0, 10.0, 7.0, 12.0, 2.0, 3.0, 0.0, 0.0],
                        sound="sound/hknight/slash1.wav",
                        random_scale=3.0
                    ),
                    AttackProfile(
                        name="watk",
                        kind="melee",
                        rotation="hknight_type",
                        max_range=120.0,
                        reach=60.0,
                        times=[0.3, 0.4, 0.5, 0.9, 1.0, 1.1, 1.6, 1.7, 1.8],
                        duration=2.2,
                        frames=["w_attack" + str(i) for i in range(1, 23)],
                        steps=[
                            2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 4.0, 5.0, 3.0, 2.0,
                            2.0, 0.0, 0.0, 0.0, 1.0, 1.0, 3.0, 4.0, 6.0, 7.0, 3.0
                        ],
                        sound="sound/hknight/slash1.wav",
                        random_scale=3.0
                    ),
                    # CheckForCharge from hknight_run1: a visible target at
                    # least 80 away and within 20 in height, once attacks
                    # are due, draws the charge (hknight_char_a1-16) with
                    # SUB_AttackFinished(2); ai_melee hits on char_a6-11.
                    AttackProfile(
                        name="charge",
                        kind="melee",
                        trigger="run",
                        min_range=80.0,
                        max_range=100000.0,
                        max_rise=20.0,
                        finished=2.0,
                        reach=60.0,
                        times=[0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                        duration=1.6,
                        frames=["char_a" + str(i) for i in range(1, 17)],
                        steps=[
                            20.0, 25.0, 18.0, 16.0, 14.0, 20.0, 21.0, 13.0,
                            20.0, 20.0, 18.0, 16.0, 14.0, 25.0, 21.0, 13.0
                        ],
                        random_scale=3.0
                    )
                ]
            );
        }
        if kind == "monster_army" {
            return OpponentRule(
                sight_sound="sound/soldier/sight1.wav",
                pain_sounds=["sound/soldier/pain1.wav", "sound/soldier/pain2.wav"],
                death_sound="sound/soldier/death1.wav",
                attack_sound="sound/soldier/sattck1.wav",
                attack_sound_times=[0.4],
                idle_sound="sound/soldier/idle.wav",
                model="progs/soldier.mdl",
                # grunt.qc army_run1-8 ai_run, army_walk1-24 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 9)],
                    steps=[11.0, 15.0, 10.0, 10.0, 8.0, 15.0, 10.0, 8.0]
                ),
                walk=Gait(
                    frames=["prowl_" + str(i) for i in range(1, 25)],
                    steps=[1.0, 1.0, 1.0, 1.0, 2.0, 3.0, 4.0, 4.0, 2.0, 2.0, 2.0, 1.0, 0.0, 1.0, 1.0, 1.0, 3.0, 3.0, 3.0, 3.0, 2.0, 1.0, 1.0, 1.0]
                ),
                health=30,
                attack_times=[0.4],
                attack_duration=0.9,
                attack_frames=[
                    "shoot1",
                    "shoot2",
                    "shoot3",
                    "shoot4",
                    "shoot5",
                    "shoot6",
                    "shoot7",
                    "shoot8",
                    "shoot9"
                ],
                pellets=4,
                spread=0.1,
                aim_lag=0.2,
                # FireBullets: 10 ahead at 0.7 of the box's height.
                muzzles=[Vec3(x=10.0, z=20.8)],
                flash=Q1_FLASH,
                near_chance=0.4,
                mid_chance=0.05,
                rest_min=1.0,
                rest_random=1.0
            );
        }
        if kind == "monster_dog" {
            # rottweiler.qc: DogCheckAttack bites in melee range and otherwise
            # leaps (CheckDogJump, 80 to 150 units) at 300 forward and 200 up.
            return OpponentRule(
                width=32.0,
                hull_bottom=-24.0,
                hull_top=40.0,
                sight_sound="sound/dog/dsight.wav",
                pain_sounds=["sound/dog/dpain1.wav"],
                death_sound="sound/dog/ddeath.wav",
                idle_sound="sound/dog/idle.wav",
                model="progs/dog.mdl",
                # rottweiler.qc dog_run1-12 ai_run, dog_walk1-8 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 13)],
                    steps=[16.0, 32.0, 32.0, 20.0, 64.0, 32.0, 16.0, 32.0, 32.0, 20.0, 64.0, 32.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 9)],
                    steps=[8.0 for i in range(8)]
                ),
                health=25,
                near_chance=1.0,
                rest_random=0.0,
                stop_range=48.0,
                attacks=[
                    AttackProfile(
                        name="bite",
                        kind="melee",
                        max_range=100.0,
                        reach=100.0,
                        times=[0.3],
                        duration=0.8,
                        frames=["attack" + str(i) for i in range(1, 9)],
                        steps=[10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0],
                        sound="sound/dog/dattack1.wav",
                        sound_times=[0.3],
                        damage=12,
                        random_scale=8.0
                    ),
                    AttackProfile(
                        name="leap",
                        kind="leap",
                        min_range=100.0,
                        max_range=150.0,
                        times=[0.1],
                        duration=0.9,
                        frames=["leap" + str(i) for i in range(1, 10)],
                        damage=10,
                        damage_max=20,
                        leap_speed=300.0,
                        leap_lift=200.0,
                        leap_contact_speed=300.0
                    )
                ]
            );
        }
        if kind == "monster_knight" {
            return OpponentRule(
                sight_sound="sound/knight/ksight.wav",
                pain_sounds=["sound/knight/khurt.wav"],
                death_sound="sound/knight/kdeath.wav",
                idle_sound="sound/knight/idle.wav",
                model="progs/knight.mdl",
                # knight.qc knight_run1-8 ai_run, knight_walk1-14 ai_walk.
                run=Gait(
                    frames=["runb" + str(i) for i in range(1, 9)],
                    steps=[16.0, 20.0, 13.0, 7.0, 16.0, 20.0, 14.0, 6.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 15)],
                    steps=[3.0, 2.0, 3.0, 4.0, 3.0, 3.0, 3.0, 4.0, 3.0, 3.0, 2.0, 3.0, 4.0, 3.0]
                ),
                health=75,
                stop_range=40.0,
                # th_melee knight_attack: in melee range (CheckAttack's
                # RANGE_MELEE, 120) a standing swing when closer than 80,
                # otherwise the running attack.
                attacks=[
                    # knight_atk1-10: ai_charge steps, ai_melee on atk6-8.
                    AttackProfile(
                        name="swing",
                        kind="melee",
                        max_range=80.0,
                        reach=60.0,
                        times=[0.5, 0.6, 0.7],
                        duration=1.0,
                        frames=["attackb" + str(i) for i in range(1, 11)],
                        steps=[0.0, 7.0, 4.0, 0.0, 3.0, 4.0, 1.0, 3.0, 1.0, 5.0],
                        sound="sound/knight/sword1.wav",
                        random_scale=3.0
                    ),
                    # knight_runatk1-11: ai_charge(20), then 20-unit strides
                    # at a point 30 left of the target (ai_charge_side) that
                    # bring it up alongside, ai_melee_side on runatk5-9, and
                    # ai_charge(10).
                    AttackProfile(
                        name="runattack",
                        kind="melee",
                        min_range=80.0,
                        max_range=120.0,
                        reach=60.0,
                        times=[0.4, 0.5, 0.6, 0.7, 0.8],
                        duration=1.1,
                        frames=["runattack" + str(i) for i in range(1, 12)],
                        steps=[
                            20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0,
                            20.0, 10.0
                        ],
                        sides=[0.0, 30.0, 30.0, 30.0, 30.0, 30.0, 30.0, 30.0, 30.0, 30.0, 0.0],
                        sound="sound/knight/sword1.wav",
                        alternate_sound="sound/knight/sword2.wav",
                        random_scale=3.0
                    )
                ]
            );
        }
        if kind == "monster_enforcer" {
            return OpponentRule(
                sight_sound="sound/enforcer/sight1.wav",
                pain_sounds=["sound/enforcer/pain1.wav", "sound/enforcer/pain2.wav"],
                death_sound="sound/enforcer/death1.wav",
                idle_sound="sound/enforcer/idle1.wav",
                model="progs/enforcer.mdl",
                # enforcer.qc enf_run1-8 ai_run, enf_walk1-16 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 9)],
                    steps=[18.0, 14.0, 7.0, 12.0, 14.0, 14.0, 7.0, 11.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 17)],
                    steps=[2.0, 4.0, 4.0, 3.0, 1.0, 2.0, 2.0, 1.0, 2.0, 4.0, 4.0, 1.0, 2.0, 3.0, 4.0, 2.0]
                ),
                attack_sound="sound/enforcer/enfire.wav",
                attack_sound_times=[0.5, 0.9],
                attack_times=[0.5, 0.9],
                attack_duration=1.4,
                attack_frames=[
                    "attack1",
                    "attack2",
                    "attack3",
                    "attack4",
                    "attack5",
                    "attack6",
                    "attack7",
                    "attack8",
                    "attack5",
                    "attack6",
                    "attack7",
                    "attack8",
                    "attack9",
                    "attack10"
                ],
                health=80,
                damage=15,
                missile_speed=600.0,
                missile_effect="q1_laser",
                # enforcer_fire: v_forward * 30 + v_right * 8.5 + '0 0 16'.
                muzzles=[Vec3(x=30.0, y=8.5, z=16.0)],
                flash=Q1_FLASH
            );
        }
        if kind in ["monster_ogre", "monster_ogre_marksman"] {
            return OpponentRule(
                # VEC_HULL2_MIN/MAX.
                width=32.0,
                hull_bottom=-24.0,
                hull_top=64.0,
                sight_sound="sound/ogre/ogwake.wav",
                pain_sounds=["sound/ogre/ogpain1.wav"],
                death_sound="sound/ogre/ogdth.wav",
                idle_sound="sound/ogre/ogidle.wav",
                model="progs/ogre.mdl",
                # ogre.qc ogre_run1-8 ai_run, ogre_walk1-16 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 9)],
                    steps=[9.0, 12.0, 8.0, 22.0, 16.0, 4.0, 13.0, 24.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 17)],
                    steps=[3.0, 2.0, 2.0, 2.0, 2.0, 5.0, 3.0, 2.0, 3.0, 1.0, 2.0, 3.0, 3.0, 3.0, 3.0, 4.0]
                ),
                attack_sound="sound/weapons/grenade.wav",
                attack_sound_times=[0.3],
                melee_sound="sound/ogre/ogsawatk.wav",
                health=200,
                damage=0,
                melee=0,
                melee_random_scale=4.0,
                melee_range=100.0,
                melee_times=[0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                melee_duration=1.4,
                melee_frames=["swing" + str(i) for i in range(1, 15)],
                alternate_melee_times=[0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                alternate_melee_duration=1.4,
                alternate_melee_frames=["smash" + str(i) for i in range(1, 15)],
                alternate_melee_steps=[
                    6.0,
                    0.0,
                    0.0,
                    1.0,
                    4.0,
                    14.0,
                    14.0,
                    20.0,
                    23.0,
                    10.0,
                    12.0,
                    0.0,
                    4.0,
                    12.0
                ],
                melee_steps=[
                    11.0,
                    1.0,
                    4.0,
                    13.0,
                    19.0,
                    10.0,
                    10.0,
                    10.0,
                    10.0,
                    10.0,
                    10.0,
                    3.0,
                    8.0,
                    9.0
                ],
                attack_times=[0.3],
                attack_duration=0.7,
                attack_frames=[
                    "shoot1",
                    "shoot2",
                    "shoot2",
                    "shoot3",
                    "shoot4",
                    "shoot5",
                    "shoot6"
                ],
                missile_speed=600.0,
                missile_effect="q1_grenade",
                gravity=True,
                splash=40,
                radius=80.0,
                # OgreFireGrenade: from the origin.
                muzzles=[Vec3()],
                flash=Q1_FLASH,
                near_chance=0.1,
                mid_chance=0.05,
                rest_min=1.0,
                rest_random=2.0
            );
        }
        if kind == "monster_oldone" {
            return OpponentRule(
                model="progs/oldone.mdl",
                script="shub",
                health=40000,
                width=160.0,
                movement="none",
                speed=0.0,
                idle_frames=["old" + str(i) for i in range(1, 47)],
                death_frames=["shake" + str(i) for i in range(1, 21)],
                sight_sound="sound/boss2/sight.wav",
                pain_sounds=["sound/boss2/pop2.wav"],
                death_sound="sound/boss2/death.wav"
            );
        }
        if kind == "monster_wizard" {
            return OpponentRule(
                hull_bottom=-24.0,
                hull_top=40.0,
                model="progs/wizard.mdl",
                # scrag.qc wiz_run1-14 ai_run, wiz_walk1-8 ai_walk.
                run=Gait(
                    frames=["fly" + str(i) for i in range(1, 15)],
                    steps=[16.0 for i in range(14)]
                ),
                walk=Gait(
                    frames=["hover" + str(i) for i in range(1, 9)],
                    steps=[8.0 for i in range(8)]
                ),
                health=80,
                movement="fly",
                slides=True,
                near_chance=0.6,
                mid_chance=0.2,
                rest_min=2.0,
                rest_random=0.0,
                idle_frames=["hover" + str(i) for i in range(1, 9)],
                pain_frames=["pain" + str(i) for i in range(1, 5)],
                pain_duration=0.4,
                pain_interval=0.4,
                pain_chance_scale=70.0,
                sight_sound="sound/wizard/wsight.wav",
                pain_sounds=["sound/wizard/wpain.wav"],
                death_sound="sound/wizard/wdeath.wav",
                attacks=[
                    AttackProfile(
                        name="spikes",
                        kind="ranged",
                        max_range=1000.0,
                        times=[0.3, 0.8],
                        duration=1.0,
                        frames=[
                            "magatt1",
                            "magatt2",
                            "magatt3",
                            "magatt4",
                            "magatt5",
                            "magatt6",
                            "magatt5",
                            "magatt4",
                            "magatt3",
                            "magatt2"
                        ],
                        sound="sound/wizard/wattack.wav",
                        sound_times=[0.0, 0.3, 0.8],
                        damage=9,
                        missile_speed=600.0,
                        missile_effect="q1_wizspike",
                        # Wiz_StartFast: '0 0 30' + v_forward * 14 and
                        # v_right * -14 for the first spike, 14 the second.
                        muzzles=[
                            Vec3(x=14.0, y=-14.0, z=30.0), Vec3(x=14.0, y=14.0, z=30.0)
                        ],
                        flash=Q1_FLASH
                    )
                ]
            );
        }
        if kind == "monster_demon1" {
            return OpponentRule(
                hull_bottom=-24.0,
                hull_top=64.0,
                model="progs/demon.mdl",
                # fiend.qc demon1_run1-6 ai_run, demon1_walk1-8 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 7)],
                    steps=[20.0, 15.0, 36.0, 20.0, 15.0, 36.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 9)],
                    steps=[8.0, 6.0, 6.0, 7.0, 4.0, 6.0, 10.0, 10.0]
                ),
                health=300,
                width=32.0,
                near_chance=1.0,
                rest_random=0.0,
                stop_range=60.0,
                pain_frames=["pain" + str(i) for i in range(1, 7)],
                pain_duration=0.6,
                pain_interval=1.0,
                pain_chance_scale=200.0,
                sight_sound="sound/demon/sight2.wav",
                pain_sounds=["sound/demon/dpain1.wav"],
                death_sound="sound/demon/ddeath.wav",
                attacks=[
                    AttackProfile(
                        name="claws",
                        kind="melee",
                        max_range=100.0,
                        reach=100.0,
                        times=[0.4, 1.0],
                        duration=1.5,
                        frames=["attacka" + str(i) for i in range(1, 16)],
                        steps=[
                            4.0,
                            0.0,
                            0.0,
                            1.0,
                            14.0,
                            1.0,
                            6.0,
                            8.0,
                            4.0,
                            2.0,
                            12.0,
                            5.0,
                            8.0,
                            4.0,
                            4.0
                        ],
                        sound="sound/demon/dhit2.wav",
                        sound_times=[0.4, 1.0],
                        damage=10,
                        damage_max=15
                    ),
                    AttackProfile(
                        name="leap",
                        kind="leap",
                        min_range=100.0,
                        max_range=300.0,
                        times=[0.3],
                        duration=1.2,
                        frames=["leap" + str(i) for i in range(1, 13)],
                        sound="sound/demon/djump.wav",
                        sound_times=[0.0],
                        damage=40,
                        damage_max=50,
                        leap_speed=600.0,
                        leap_lift=250.0
                    )
                ]
            );
        }
        if kind == "monster_shambler" {
            return OpponentRule(
                hull_bottom=-24.0,
                hull_top=64.0,
                model="progs/shambler.mdl",
                # shambler.qc sham_run1-6 ai_run, sham_walk1-12 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 7)],
                    steps=[20.0, 24.0, 20.0, 20.0, 24.0, 20.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 13)],
                    steps=[10.0, 9.0, 9.0, 5.0, 6.0, 12.0, 8.0, 3.0, 13.0, 9.0, 7.0, 7.0]
                ),
                health=600,
                width=32.0,
                near_chance=1.0,
                mid_chance=1.0,
                rest_min=2.0,
                rest_random=2.0,
                stop_range=64.0,
                blast_scale=0.5,
                pain_frames=["pain" + str(i) for i in range(1, 7)],
                pain_duration=0.6,
                pain_interval=2.0,
                pain_chance_scale=400.0,
                sight_sound="sound/shambler/ssight.wav",
                pain_sounds=["sound/shambler/shurt2.wav"],
                death_sound="sound/shambler/sdeath.wav",
                attacks=[
                    AttackProfile(
                        name="smash",
                        kind="melee",
                        weight=0.4,
                        max_range=100.0,
                        reach=100.0,
                        times=[0.9],
                        duration=1.2,
                        frames=["smash" + str(i) for i in range(1, 13)],
                        steps=[2.0, 6.0, 6.0, 5.0, 4.0, 1.0, 0.0, 0.0, 0.0, 0.0, 5.0, 4.0],
                        sound="sound/shambler/melee1.wav",
                        sound_times=[0.0],
                        extra_sound="sound/shambler/smack.wav",
                        extra_sound_times=[0.9],
                        random_scale=40.0
                    ),
                    AttackProfile(
                        name="swingr",
                        kind="melee",
                        weight=0.3,
                        max_range=100.0,
                        reach=100.0,
                        times=[0.6],
                        duration=0.9,
                        frames=["swingr" + str(i) for i in range(1, 10)],
                        steps=[1.0, 8.0, 14.0, 7.0, 3.0, 6.0, 16.0, 3.0, 1.0],
                        sound="sound/shambler/melee1.wav",
                        sound_times=[0.0],
                        extra_sound="sound/shambler/smack.wav",
                        extra_sound_times=[0.6],
                        random_scale=20.0
                    ),
                    AttackProfile(
                        name="swingl",
                        kind="melee",
                        weight=0.3,
                        max_range=100.0,
                        reach=100.0,
                        times=[0.6],
                        duration=0.9,
                        frames=["swingl" + str(i) for i in range(1, 10)],
                        steps=[5.0, 3.0, 7.0, 3.0, 7.0, 9.0, 15.0, 4.0, 8.0],
                        sound="sound/shambler/melee2.wav",
                        sound_times=[0.0],
                        extra_sound="sound/shambler/smack.wav",
                        extra_sound_times=[0.6],
                        random_scale=20.0
                    ),
                    AttackProfile(
                        name="lightning",
                        kind="beam",
                        beam_kind="lightning",
                        max_range=600.0,
                        reach=600.0,
                        times=[0.7, 0.8, 0.9],
                        duration=1.2,
                        frames=[
                            "magic1",
                            "magic2",
                            "magic3",
                            "magic3",
                            "magic3",
                            "magic4",
                            "magic5",
                            "magic6",
                            "magic9",
                            "magic10",
                            "magic11",
                            "magic12"
                        ],
                        sound="sound/shambler/sattck1.wav",
                        sound_times=[0.0],
                        extra_sound="sound/shambler/sboom.wav",
                        extra_sound_times=[0.7],
                        damage=10,
                        flash=Q1_FLASH
                    )
                ]
            );
        }
        if kind == "monster_zombie" {
            if flags & 1 {
                return OpponentRule(
                    model="progs/zombie.mdl",
                    health=60,
                    movement="none",
                    decoration=True,
                    speed=0.0,
                    idle_frames=["cruc_" + str(i) for i in range(1, 7)]
                );
            }
            return OpponentRule(
                model="progs/zombie.mdl",
                # zombie.qc zombie_run1-18 ai_run, zombie_walk1-19 ai_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 19)],
                    steps=[1.0, 1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 4.0, 2.0, 0.0, 0.0, 0.0, 2.0, 4.0, 6.0, 7.0, 3.0, 8.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 20)],
                    steps=[0.0, 2.0, 3.0, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
                ),
                health=60,
                stop_range=64.0,
                idle_frames=["stand" + str(i) for i in range(1, 16)],
                pain_threshold=9,
                pain_health_reset=60,
                pain_interval=0.5,
                pain_variants=[
                    ["paina" + str(i) for i in range(1, 13)],
                    ["painb" + str(i) for i in range(1, 29)],
                    ["painc" + str(i) for i in range(1, 19)],
                    ["paind" + str(i) for i in range(1, 14)]
                ],
                pain_variant_durations=[1.2, 2.8, 1.8, 1.3],
                knockdown_damage=25,
                knockdown_frames=["paine" + str(i) for i in range(1, 31)],
                knockdown_duration=8.0,
                knockdown_hold_frame=10,
                knockdown_hold_time=5.0,
                vanish_on_death=True,
                sight_sound="sound/zombie/z_idle.wav",
                pain_sounds=["sound/zombie/z_pain.wav", "sound/zombie/z_pain1.wav"],
                death_sound="sound/zombie/z_gib.wav",
                attacks=[
                    AttackProfile(
                        name="throw_a",
                        kind="ranged",
                        weight=0.3,
                        max_range=1000.0,
                        times=[1.2],
                        duration=1.3,
                        frames=["atta" + str(i) for i in range(1, 14)],
                        sound="sound/zombie/z_shot1.wav",
                        sound_times=[1.2],
                        damage=10,
                        missile_speed=600.0,
                        missile_effect="q1_zombiegib",
                        # ZombieFireGrenade(st): st_x ahead, st_y right,
                        # st_z - 24 up.
                        muzzles=[Vec3(x=-10.0, y=-22.0, z=6.0)],
                        gravity=True
                    ),
                    AttackProfile(
                        name="throw_b",
                        kind="ranged",
                        weight=0.3,
                        max_range=1000.0,
                        times=[1.3],
                        duration=1.4,
                        frames=["attb" + str(i) for i in range(1, 14)] + ["attb13"],
                        sound="sound/zombie/z_shot1.wav",
                        sound_times=[1.3],
                        damage=10,
                        missile_speed=600.0,
                        missile_effect="q1_zombiegib",
                        muzzles=[Vec3(x=-10.0, y=-24.0, z=5.0)],
                        gravity=True
                    ),
                    AttackProfile(
                        name="throw_c",
                        kind="ranged",
                        weight=0.4,
                        max_range=1000.0,
                        times=[1.1],
                        duration=1.2,
                        frames=["attc" + str(i) for i in range(1, 13)],
                        sound="sound/zombie/z_shot1.wav",
                        sound_times=[1.1],
                        damage=10,
                        missile_speed=600.0,
                        missile_effect="q1_zombiegib",
                        muzzles=[Vec3(x=-12.0, y=-19.0, z=5.0)],
                        gravity=True
                    )
                ]
            );
        }
        if kind == "monster_shalrath" {
            return OpponentRule(
                hull_bottom=-24.0,
                hull_top=64.0,
                model="progs/shalrath.mdl",
                # vore.qc shal_run1-12 ai_run and shal_walk1-12 ai_walk (frames walk2-12, walk1).
                run=Gait(
                    frames=["walk" + str(i) for i in range(2, 13)] + ["walk1"],
                    steps=[6.0, 4.0, 0.0, 0.0, 0.0, 0.0, 5.0, 6.0, 5.0, 0.0, 4.0, 5.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(2, 13)] + ["walk1"],
                    steps=[6.0, 4.0, 0.0, 0.0, 0.0, 0.0, 5.0, 6.0, 5.0, 0.0, 4.0, 5.0]
                ),
                health=400,
                width=32.0,
                stop_range=120.0,
                idle_frames=["walk1"],
                pain_frames=["pain" + str(i) for i in range(1, 6)],
                pain_duration=0.5,
                pain_interval=3.0,
                sight_sound="sound/shalrath/sight.wav",
                pain_sounds=["sound/shalrath/pain.wav"],
                death_sound="sound/shalrath/death.wav",
                attacks=[
                    AttackProfile(
                        name="pod",
                        kind="ranged",
                        max_range=1000.0,
                        times=[0.8],
                        duration=1.1,
                        frames=["attack" + str(i) for i in range(1, 12)],
                        sound="sound/shalrath/attack.wav",
                        sound_times=[0.0],
                        extra_sound="sound/shalrath/attack2.wav",
                        extra_sound_times=[0.8],
                        damage=0,
                        splash=40,
                        radius=80.0,
                        missile_speed=400.0,
                        missile_effect="q1_vorepod",
                        # ShalMissile: '0 0 10' above the origin.
                        muzzles=[Vec3(z=10.0)],
                        flash=Q1_FLASH,
                        homing=250.0
                    )
                ]
            );
        }
        if kind == "monster_tarbaby" {
            return OpponentRule(
                model="progs/tarbaby.mdl",
                # spawn.qc tbaby_run1-25: ten ai_face frames, then ai_run(2); tbaby_walk1-25 likewise.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 26)],
                    steps=[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 26)],
                    steps=[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0]
                ),
                health=80,
                near_chance=1.0,
                rest_random=0.0,
                stop_range=48.0,
                idle_frames=["walk1"],
                pain_threshold=1000000,
                death_splash=120,
                death_radius=240.0,
                vanish_on_death=True,
                sight_sound="sound/blob/sight1.wav",
                death_sound="sound/blob/death1.wav",
                attacks=[
                    AttackProfile(
                        name="bounce",
                        kind="leap",
                        max_range=1000.0,
                        times=[0.4],
                        duration=1.0,
                        frames=["jump" + str(i) for i in range(1, 7)]
                            + ["fly1", "fly2", "fly3", "fly4"],
                        sound="sound/blob/land1.wav",
                        sound_times=[0.4],
                        damage=10,
                        damage_max=20,
                        leap_speed=600.0,
                        leap_lift=200.0,
                        leap_lift_random=150.0
                    )
                ]
            );
        }
        if kind == "monster_fish" {
            return OpponentRule(
                hull_bottom=-24.0,
                hull_top=24.0,
                model="progs/fish.mdl",
                # rotfish.qc f_run1-9 ai_run over the odd swim frames, f_walk1-18 ai_walk.
                run=Gait(
                    frames=["swim" + str(i) for i in range(1, 19, 2)],
                    steps=[12.0 for i in range(9)]
                ),
                walk=Gait(
                    frames=["swim" + str(i) for i in range(1, 19)],
                    steps=[8.0 for i in range(18)]
                ),
                health=25,
                movement="swim",
                stop_range=40.0,
                idle_frames=["swim" + str(i) for i in range(1, 19)],
                pain_frames=["pain" + str(i) for i in range(1, 10)],
                pain_duration=0.9,
                pain_interval=0.5,
                death_frames=["death" + str(i) for i in range(1, 22)],
                sight_sound="sound/fish/idle.wav",
                death_sound="sound/fish/death.wav",
                attacks=[
                    AttackProfile(
                        name="bite",
                        kind="melee",
                        max_range=60.0,
                        reach=60.0,
                        times=[0.2, 0.8, 1.4],
                        duration=1.8,
                        frames=["attack" + str(i) for i in range(1, 19)],
                        steps=[
                            10.0,
                            10.0,
                            0.0,
                            10.0,
                            10.0,
                            10.0,
                            10.0,
                            10.0,
                            0.0,
                            10.0,
                            10.0,
                            10.0,
                            10.0,
                            10.0,
                            0.0,
                            10.0,
                            10.0,
                            10.0
                        ],
                        sound="sound/fish/bite.wav",
                        sound_times=[0.2, 0.8, 1.4],
                        random_scale=2.0
                    )
                ]
            );
        }
    } elif game == "q2" {
        if kind == "monster_gunner" {
            return OpponentRule(
                model="models/monsters/gunner/tris.md2",
                # m_gunner.c gunner_move_run / gunner_move_walk, MODEL_SCALE 1.15.
                run=Gait(
                    frames=["run" + two(i) for i in range(1, 9)],
                    steps=[26.0, 9.0, 9.0, 9.0, 15.0, 10.0, 13.0, 6.0]
                ),
                walk=Gait(
                    frames=["walk" + two(i) for i in range(7, 20)],
                    steps=[0.0, 3.0, 4.0, 5.0, 7.0, 2.0, 6.0, 4.0, 2.0, 7.0, 5.0, 7.0, 4.0]
                ),
                step_scale=1.15,
                duck_frames=["duck" + two(i) for i in range(1, 9)],
                duck_down=0,
                duck_hold=2,
                duck_up=6,
                duck_grenade="grenades",
                health=175,
                idle_frames=["stand" + two(i) for i in range(1, 31)],
                pain_variants=[
                    ["pain30" + str(i) for i in range(1, 6)],
                    ["pain20" + str(i) for i in range(1, 9)],
                    ["pain1" + two(i) for i in range(1, 19)]
                ],
                pain_variant_damage=[10, 25],
                pain_variant_durations=[0.5, 0.8, 1.8],
                pain_interval=3.0,
                death_frames=["death" + two(i) for i in range(1, 12)],
                sight_sound="sound/gunner/sight1.wav",
                pain_sounds=["sound/gunner/gunpain2.wav", "sound/gunner/gunpain1.wav"],
                death_sound="sound/gunner/death1.wav",
                attacks=[
                    AttackProfile(
                        name="chaingun",
                        kind="ranged",
                        weight=0.5,
                        max_range=1000.0,
                        times=[0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4],
                        duration=2.2,
                        frames=["attak2" + two(i) for i in range(9, 31)],
                        repeat_start=0.7,
                        repeat_end=1.5,
                        repeat_chance=0.5,
                        sound="sound/gunner/gunatck2.wav",
                        sound_times=[0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4],
                        extra_sound="sound/gunner/gunatck1.wav",
                        extra_sound_times=[0.6],
                        damage=3,
                        spread=300.0 / 8192.0,
                        vertical_spread=500.0 / 8192.0,
                        aim_lag=0.2,
                        # GunnerFire: MZ2_GUNNER_MACHINEGUN_1 to 8, scaled 1.15.
                        muzzles=[
                            Vec3(x=34.615, y=4.485, z=22.54),
                            Vec3(x=33.465, y=2.875, z=23.805),
                            Vec3(x=32.43, y=2.875, z=25.53),
                            Vec3(x=32.43, y=4.14, z=25.3),
                            Vec3(x=30.935, y=2.3, z=26.91),
                            Vec3(x=30.475, y=0.69, z=23.92),
                            Vec3(x=30.935, y=0.575, z=24.725),
                            Vec3(x=33.35, y=2.76, z=22.425)
                        ],
                        flash=Q2_GUN_FLASH
                    ),
                    AttackProfile(
                        name="grenades",
                        kind="ranged",
                        weight=0.5,
                        min_range=80.0,
                        max_range=1000.0,
                        times=[0.4, 0.7, 1.0, 1.3],
                        duration=2.1,
                        frames=["attak1" + two(i) for i in range(1, 22)],
                        sound="sound/gunner/gunatck3.wav",
                        sound_times=[0.4, 0.7, 1.0, 1.3],
                        damage=50,
                        splash=50,
                        radius=90.0,
                        missile_speed=600.0,
                        missile_effect="q2_grenade",
                        gravity=True,
                        muzzles=[Vec3(x=5.29, y=-19.32, z=8.395)],
                        flash=Q2_GRENADE_FLASH
                    )
                ]
            );
        }
        if kind == "monster_flyer" {
            return OpponentRule(
                model="models/monsters/flyer/tris.md2",
                # m_flyer.c flyer_move_run / flyer_move_walk.
                run=Gait(
                    frames=["stand" + two(i) for i in range(1, 46)],
                    steps=[10.0 for i in range(45)]
                ),
                walk=Gait(
                    frames=["stand" + two(i) for i in range(1, 46)],
                    steps=[5.0 for i in range(45)]
                ),
                health=50,
                movement="fly",
                slides=True,
                idle_frames=["stand" + two(i) for i in range(1, 46)],
                pain_variants=[
                    ["pain1" + two(i) for i in range(1, 10)],
                    ["pain20" + str(i) for i in range(1, 5)],
                    ["pain30" + str(i) for i in range(1, 5)]
                ],
                pain_variant_durations=[0.9, 0.4, 0.4],
                pain_interval=3.0,
                vanish_on_death=True,
                sight_sound="sound/flyer/flysght1.wav",
                pain_sounds=["sound/flyer/flypain1.wav", "sound/flyer/flypain2.wav"],
                death_sound="sound/flyer/flydeth1.wav",
                attacks=[
                    AttackProfile(
                        name="blades",
                        kind="melee",
                        max_range=80.0,
                        reach=80.0,
                        times=[0.8, 1.3],
                        duration=2.1,
                        frames=["attak1" + two(i) for i in range(1, 22)],
                        repeat_start=0.6,
                        repeat_end=1.8,
                        repeat_chance=0.8,
                        sound="sound/flyer/flyatck1.wav",
                        sound_times=[0.0],
                        extra_sound="sound/flyer/flyatck2.wav",
                        extra_sound_times=[0.8, 1.3],
                        damage=5
                    ),
                    AttackProfile(
                        name="blasters",
                        kind="ranged",
                        max_range=1000.0,
                        times=[0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                        duration=1.7,
                        frames=["attak2" + two(i) for i in range(1, 18)],
                        sound="sound/flyer/flyatck3.wav",
                        sound_times=[0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                        damage=1,
                        missile_speed=1000.0,
                        missile_effect="q2_bolt",
                        # flyer_fireleft / flyer_fireright in turn.
                        muzzles=[Vec3(x=12.1, y=13.4, z=-14.5), Vec3(x=12.1, y=-7.4, z=-14.5)],
                        flash=Q2_GUN_FLASH
                    )
                ]
            );
        }
        if kind == "monster_floater" {
            return OpponentRule(
                model="models/monsters/float/tris.md2",
                # m_float.c floater_move_run / floater_move_walk.
                run=Gait(
                    frames=["stand1" + two(i) for i in range(1, 53)],
                    steps=[13.0 for i in range(52)]
                ),
                walk=Gait(
                    frames=["stand1" + two(i) for i in range(1, 53)],
                    steps=[5.0 for i in range(52)]
                ),
                health=200,
                width=24.0,
                movement="fly",
                slides=True,
                idle_frames=["stand1" + two(i) for i in range(1, 53)],
                pain_variants=[
                    ["pain10" + str(i) for i in range(1, 8)],
                    ["pain20" + str(i) for i in range(1, 9)]
                ],
                pain_variant_durations=[0.7, 0.8],
                pain_interval=3.0,
                vanish_on_death=True,
                sight_sound="sound/floater/fltsght1.wav",
                pain_sounds=["sound/floater/fltpain1.wav", "sound/floater/fltpain2.wav"],
                death_sound="sound/floater/fltdeth1.wav",
                attacks=[
                    AttackProfile(
                        name="wham",
                        kind="melee",
                        weight=0.5,
                        max_range=80.0,
                        reach=80.0,
                        times=[1.1],
                        duration=2.5,
                        frames=["attak2" + two(i) for i in range(1, 26)],
                        sound="sound/floater/fltatck3.wav",
                        sound_times=[1.1],
                        damage=5,
                        damage_max=10,
                        knockback=-50.0
                    ),
                    AttackProfile(
                        name="zap",
                        kind="melee",
                        weight=0.5,
                        max_range=80.0,
                        reach=80.0,
                        times=[0.8],
                        duration=3.4,
                        frames=["attak3" + two(i) for i in range(1, 35)],
                        sound="sound/floater/fltatck2.wav",
                        sound_times=[0.8],
                        damage=5,
                        damage_max=10,
                        knockback=-10.0
                    ),
                    AttackProfile(
                        name="blaster",
                        kind="ranged",
                        max_range=1000.0,
                        times=[0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
                        duration=1.4,
                        frames=["attak1" + two(i) for i in range(1, 15)],
                        sound="sound/floater/fltatck1.wav",
                        sound_times=[0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
                        damage=1,
                        missile_speed=1000.0,
                        missile_effect="q2_bolt",
                        muzzles=[Vec3(x=32.5, y=-0.8, z=10.0)],
                        flash=Q2_GUN_FLASH
                    )
                ]
            );
        }
        if kind == "monster_hover" {
            return OpponentRule(
                model="models/monsters/hover/tris.md2",
                # m_hover.c hover_move_run / hover_move_walk.
                run=Gait(
                    frames=["forwrd" + two(i) for i in range(1, 36)],
                    steps=[10.0 for i in range(35)]
                ),
                walk=Gait(
                    frames=["forwrd" + two(i) for i in range(1, 36)],
                    steps=[4.0 for i in range(35)]
                ),
                health=240,
                width=24.0,
                movement="fly",
                slides=True,
                idle_frames=["stand" + two(i) for i in range(1, 31)],
                pain_variants=[
                    ["pain2" + two(i) for i in range(1, 13)],
                    ["pain1" + two(i) for i in range(1, 29)]
                ],
                pain_variant_damage=[25],
                pain_variant_durations=[1.2, 2.8],
                pain_interval=3.0,
                death_frames=["death1" + two(i) for i in range(1, 12)],
                sight_sound="sound/hover/hovsght1.wav",
                pain_sounds=["sound/hover/hovpain1.wav", "sound/hover/hovpain2.wav"],
                death_sound="sound/hover/hovdeth1.wav",
                attacks=[
                    AttackProfile(
                        name="blaster",
                        kind="ranged",
                        max_range=1000.0,
                        times=[0.3, 0.4],
                        duration=0.8,
                        frames=["attak1" + two(i) for i in range(1, 9)],
                        repeat_start=0.3,
                        repeat_end=0.6,
                        repeat_chance=0.6,
                        sound="sound/hover/hovatck1.wav",
                        sound_times=[0.3, 0.4],
                        damage=1,
                        missile_speed=1000.0,
                        missile_effect="q2_bolt",
                        muzzles=[Vec3(x=32.5, y=-0.8, z=10.0)],
                        flash=Q2_GUN_FLASH
                    )
                ]
            );
        }
        if kind == "monster_mutant" {
            return OpponentRule(
                hull_bottom=-24.0,
                hull_top=48.0,
                model="models/monsters/mutant/tris.md2",
                # m_mutant.c mutant_move_run / mutant_move_walk.
                run=Gait(
                    frames=["run" + two(i) for i in range(3, 9)],
                    steps=[40.0, 40.0, 24.0, 5.0, 17.0, 10.0]
                ),
                walk=Gait(
                    frames=["walk" + two(i) for i in range(5, 17)],
                    steps=[3.0, 1.0, 5.0, 10.0, 13.0, 10.0, 0.0, 5.0, 6.0, 16.0, 15.0, 6.0]
                ),
                health=300,
                width=32.0,
                stop_range=60.0,
                idle_frames=["stand1" + two(i) for i in range(1, 52)],
                pain_variants=[
                    ["pain10" + str(i) for i in range(1, 6)],
                    ["pain20" + str(i) for i in range(1, 7)],
                    ["pain3" + two(i) for i in range(1, 12)]
                ],
                pain_variant_durations=[0.5, 0.6, 1.1],
                pain_interval=3.0,
                death_frames=["death10" + str(i) for i in range(1, 10)],
                sight_sound="sound/mutant/mutsght1.wav",
                pain_sounds=["sound/mutant/mutpain1.wav", "sound/mutant/mutpain2.wav"],
                death_sound="sound/mutant/mutdeth1.wav",
                attacks=[
                    AttackProfile(
                        name="claws",
                        kind="melee",
                        max_range=80.0,
                        reach=80.0,
                        times=[0.2, 0.5],
                        duration=0.7,
                        frames=["attack" + two(i) for i in range(9, 16)],
                        repeat_start=0.0,
                        repeat_end=0.65,
                        repeat_chance=1.0,
                        sound="sound/mutant/mutatck1.wav",
                        sound_times=[0.2, 0.5],
                        damage=10,
                        damage_max=14,
                        knockback=100.0
                    ),
                    AttackProfile(
                        name="leap",
                        kind="leap",
                        min_range=100.0,
                        max_range=300.0,
                        times=[0.2],
                        duration=0.8,
                        frames=["attack" + two(i) for i in range(1, 9)],
                        sound="sound/mutant/mutsght1.wav",
                        sound_times=[0.0],
                        damage=40,
                        damage_max=50,
                        leap_speed=600.0,
                        leap_lift=250.0
                    )
                ]
            );
        }
        if kind == "monster_parasite" {
            return OpponentRule(
                hull_bottom=-24.0,
                hull_top=24.0,
                model="models/monsters/parasite/tris.md2",
                # m_parasite.c parasite_move_run / parasite_move_walk.
                run=Gait(
                    frames=["run" + two(i) for i in range(3, 10)],
                    steps=[30.0, 30.0, 22.0, 19.0, 24.0, 28.0, 25.0]
                ),
                walk=Gait(
                    frames=["run" + two(i) for i in range(3, 10)],
                    steps=[30.0, 30.0, 22.0, 19.0, 24.0, 28.0, 25.0]
                ),
                health=175,
                stop_range=120.0,
                idle_frames=["stand" + two(i) for i in range(1, 18)],
                pain_frames=["pain1" + two(i) for i in range(1, 12)],
                pain_duration=1.1,
                pain_interval=3.0,
                death_frames=["death10" + str(i) for i in range(1, 8)],
                sight_sound="sound/parasite/parsght1.wav",
                pain_sounds=["sound/parasite/parpain1.wav", "sound/parasite/parpain2.wav"],
                death_sound="sound/parasite/pardeth1.wav",
                attacks=[
                    AttackProfile(
                        name="drain",
                        kind="beam",
                        beam_kind="drain",
                        max_range=256.0,
                        reach=256.0,
                        times=[0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2],
                        duration=1.8,
                        frames=["drain" + two(i) for i in range(1, 19)],
                        steps=[
                            0.0,
                            0.0,
                            15.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            -2.0,
                            -2.0,
                            -3.0,
                            -2.0,
                            0.0,
                            -1.0,
                            0.0,
                            -2.0,
                            -2.0,
                            -3.0,
                            0.0
                        ],
                        sound="sound/parasite/paratck1.wav",
                        sound_times=[0.0],
                        extra_sound="sound/parasite/paratck4.wav",
                        extra_sound_times=[1.3],
                        damages=[5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
                    )
                ]
            );
        }
        if kind == "monster_brain" {
            return OpponentRule(
                power_screen=100,
                model="models/monsters/brain/tris.md2",
                # m_brain.c brain_move_run / brain_move_walk1.
                run=Gait(
                    frames=["walk1" + two(i) for i in range(1, 12)],
                    steps=[9.0, 2.0, 3.0, 3.0, 1.0, 0.0, 0.0, 10.0, -4.0, -1.0, 2.0]
                ),
                walk=Gait(
                    frames=["walk1" + two(i) for i in range(1, 12)],
                    steps=[7.0, 2.0, 3.0, 3.0, 1.0, 0.0, 0.0, 9.0, -4.0, -1.0, 2.0]
                ),
                duck_frames=["duck" + two(i) for i in range(1, 9)],
                duck_down=1,
                duck_hold=2,
                duck_up=4,
                health=300,
                stop_range=60.0,
                idle_frames=["stand" + two(i) for i in range(1, 31)],
                pain_variants=[
                    ["pain1" + two(i) for i in range(1, 22)],
                    ["pain20" + str(i) for i in range(1, 9)],
                    ["pain30" + str(i) for i in range(1, 7)]
                ],
                pain_variant_durations=[2.1, 0.8, 0.6],
                pain_interval=3.0,
                death_frames=["death1" + two(i) for i in range(1, 19)],
                sight_sound="sound/brain/brnsght1.wav",
                pain_sounds=["sound/brain/brnpain1.wav", "sound/brain/brnpain2.wav"],
                death_sound="sound/brain/brndeth1.wav",
                attacks=[
                    AttackProfile(
                        name="claws",
                        kind="melee",
                        weight=0.5,
                        max_range=80.0,
                        reach=80.0,
                        times=[0.7, 1.1],
                        duration=1.8,
                        frames=["attak1" + two(i) for i in range(1, 19)],
                        steps=[
                            8.0,
                            3.0,
                            5.0,
                            0.0,
                            -3.0,
                            0.0,
                            -5.0,
                            -7.0,
                            0.0,
                            6.0,
                            1.0,
                            2.0,
                            -3.0,
                            6.0,
                            -1.0,
                            -3.0,
                            2.0,
                            -11.0
                        ],
                        sound="sound/brain/melee1.wav",
                        sound_times=[0.4],
                        extra_sound="sound/brain/melee3.wav",
                        extra_sound_times=[0.7, 1.1],
                        damage=15,
                        damage_max=19,
                        knockback=40.0
                    ),
                    AttackProfile(
                        name="tentacles",
                        kind="melee",
                        weight=0.5,
                        max_range=80.0,
                        reach=80.0,
                        times=[0.6],
                        duration=1.7,
                        frames=["attak2" + two(i) for i in range(1, 18)],
                        steps=[
                            5.0,
                            -4.0,
                            -4.0,
                            -3.0,
                            0.0,
                            0.0,
                            13.0,
                            0.0,
                            2.0,
                            0.0,
                            -9.0,
                            0.0,
                            4.0,
                            3.0,
                            2.0,
                            -3.0,
                            -6.0
                        ],
                        sound="sound/brain/brnatck1.wav",
                        sound_times=[0.4],
                        extra_sound="sound/brain/brnatck3.wav",
                        extra_sound_times=[0.6],
                        damage=10,
                        damage_max=14,
                        knockback=-600.0
                    )
                ]
            );
        }
        if kind == "monster_medic" {
            return OpponentRule(
                model="models/monsters/medic/tris.md2",
                # m_medic.c medic_move_run / medic_move_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 7)],
                    steps=[18.0, 22.5, 25.4, 23.4, 24.0, 35.6]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 13)],
                    steps=[6.2, 18.1, 1.0, 9.0, 10.0, 9.0, 11.0, 11.6, 2.0, 9.9, 14.0, 9.3]
                ),
                duck_frames=["duck" + str(i) for i in range(1, 17)],
                duck_down=2,
                duck_hold=3,
                duck_up=6,
                health=300,
                width=24.0,
                idle_frames=["wait" + str(i) for i in range(1, 91)],
                pain_variants=[
                    ["paina" + str(i) for i in range(1, 9)],
                    ["painb" + str(i) for i in range(1, 16)]
                ],
                pain_variant_durations=[0.8, 1.5],
                pain_interval=3.0,
                death_frames=["death" + str(i) for i in range(1, 31)],
                sight_sound="sound/medic/medsght1.wav",
                pain_sounds=["sound/medic/medpain1.wav", "sound/medic/medpain2.wav"],
                death_sound="sound/medic/meddeth1.wav",
                idle_sound="sound/medic/idle.wav",
                medic=True,
                attacks=[
                    # medic_move_attackCable (attack33-60): the hook launches
                    # at attack42, the cable holds from attack43 to 51 and the
                    # corpse stands up at attack50; then it retracts.
                    AttackProfile(
                        name="cable",
                        kind="revive",
                        max_range=160.0,
                        times=[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8],
                        revive_at=1.7,
                        duration=2.8,
                        frames=["attack" + str(i) for i in range(33, 61)],
                        steps=[
                            2.0, 3.0, 5.0, 4.4, 4.7, 5.0, 6.0, 4.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -15.0,
                            -1.5, -1.2, -3.0, -2.0, 0.3, 0.7, 1.2, 1.3
                        ],
                        sound="sound/medic/medatck2.wav",
                        sound_times=[0.9],
                        extra_sound="sound/medic/medatck4.wav",
                        extra_sound_times=[1.1]
                    ),
                    AttackProfile(
                        name="blaster",
                        kind="ranged",
                        max_range=1000.0,
                        times=[
                            0.8,
                            1.1,
                            1.8,
                            1.9,
                            2.0,
                            2.1,
                            2.2,
                            2.3,
                            2.4,
                            2.5,
                            2.6,
                            2.7,
                            2.8,
                            2.9
                        ],
                        duration=3.0,
                        frames=["attack" + str(i) for i in range(1, 31)],
                        sound="sound/medic/medatck1.wav",
                        sound_times=[
                            0.8,
                            1.1,
                            1.8,
                            1.9,
                            2.0,
                            2.1,
                            2.2,
                            2.3,
                            2.4,
                            2.5,
                            2.6,
                            2.7,
                            2.8,
                            2.9
                        ],
                        damage=2,
                        missile_speed=1000.0,
                        missile_effect="q2_bolt",
                        muzzles=[Vec3(x=12.1, y=5.4, z=16.5)],
                        flash=Q2_GUN_FLASH
                    )
                ]
            );
        }
        if kind == "monster_flipper" {
            return OpponentRule(
                hull_bottom=0.0,
                hull_top=32.0,
                model="models/monsters/flipper/tris.md2",
                # m_flipper.c flipper_move_run_loop (FLIPPER_RUN_SPEED) / flipper_move_walk.
                run=Gait(
                    frames=["flpver" + two(i) for i in range(6, 30)],
                    steps=[24.0 for i in range(24)]
                ),
                walk=Gait(
                    frames=["flphor" + two(i) for i in range(1, 25)],
                    steps=[4.0 for i in range(24)]
                ),
                health=50,
                movement="swim",
                stop_range=48.0,
                idle_frames=["flphor" + two(i) for i in range(1, 25)],
                pain_variants=[
                    ["flppn10" + str(i) for i in range(1, 6)],
                    ["flppn20" + str(i) for i in range(1, 6)]
                ],
                pain_variant_durations=[0.5, 0.5],
                pain_interval=3.0,
                death_frames=["flpdth" + two(i) for i in range(1, 57)],
                sight_sound="sound/flipper/flpsght1.wav",
                pain_sounds=["sound/flipper/flppain1.wav", "sound/flipper/flppain2.wav"],
                death_sound="sound/flipper/flpdeth1.wav",
                attacks=[
                    AttackProfile(
                        name="bite",
                        kind="melee",
                        max_range=80.0,
                        reach=80.0,
                        times=[1.3, 1.8],
                        duration=2.0,
                        frames=["flpbit" + two(i) for i in range(1, 21)],
                        sound="sound/flipper/flpatck1.wav",
                        sound_times=[0.0],
                        extra_sound="sound/flipper/flpatck2.wav",
                        extra_sound_times=[1.3, 1.8],
                        damage=5
                    )
                ]
            );
        }
        if kind in ["monster_tank", "monster_tank_commander"] {
            return OpponentRule(
                hull_bottom=-16.0,
                hull_top=72.0,
                model="models/monsters/tank/tris.md2",
                # m_tank.c tank_move_run / tank_move_walk.
                run=Gait(
                    frames=["walk" + two(i) for i in range(5, 21)],
                    steps=[4.0, 5.0, 3.0, 2.0, 5.0, 5.0, 4.0, 4.0, 3.0, 5.0, 4.0, 5.0, 7.0, 7.0, 6.0, 6.0]
                ),
                walk=Gait(
                    frames=["walk" + two(i) for i in range(5, 21)],
                    steps=[4.0, 5.0, 3.0, 2.0, 5.0, 5.0, 4.0, 4.0, 3.0, 5.0, 4.0, 5.0, 7.0, 7.0, 6.0, 6.0]
                ),
                skin=2 if kind == "monster_tank_commander" else 0,
                health=1000 if kind == "monster_tank_commander" else 750,
                width=32.0,
                stop_range=100.0,
                idle_frames=["stand" + two(i) for i in range(1, 31)],
                pain_threshold=11,
                pain_variants=[
                    ["pain10" + str(i) for i in range(1, 5)],
                    ["pain20" + str(i) for i in range(1, 6)],
                    ["pain3" + two(i) for i in range(1, 17)]
                ],
                pain_variant_damage=[30, 60],
                pain_variant_durations=[0.4, 0.5, 1.6],
                pain_interval=3.0,
                death_frames=["death1" + two(i) for i in range(1, 33)],
                sight_sound="sound/tank/sight1.wav",
                pain_sounds=["sound/tank/tnkpain2.wav"],
                death_sound="sound/tank/death.wav",
                attacks=[
                    AttackProfile(
                        name="blaster",
                        kind="ranged",
                        weight=0.4,
                        max_range=1000.0,
                        times=[0.9, 1.2, 1.5],
                        duration=2.2,
                        frames=["attak1" + two(i) for i in range(1, 23)],
                        sound="sound/tank/tnkatck1.wav",
                        sound_times=[0.9, 1.2, 1.5],
                        damage=30,
                        missile_speed=800.0,
                        missile_effect="q2_bolt",
                        muzzles=[
                            Vec3(x=20.7, y=-18.5, z=28.7),
                            Vec3(x=16.6, y=-21.5, z=30.1),
                            Vec3(x=11.8, y=-23.9, z=32.1)
                        ],
                        flash=Q2_GUN_FLASH
                    ),
                    AttackProfile(
                        name="machinegun",
                        kind="ranged",
                        weight=0.4,
                        max_range=1000.0,
                        times=[
                            0.5,
                            0.6,
                            0.7,
                            0.8,
                            0.9,
                            1.0,
                            1.1,
                            1.2,
                            1.3,
                            1.4,
                            1.5,
                            1.6,
                            1.7,
                            1.8,
                            1.9,
                            2.0,
                            2.1,
                            2.2,
                            2.3
                        ],
                        duration=2.9,
                        frames=["attak4" + two(i) for i in range(1, 30)],
                        sound="sound/tank/tnkatk2b.wav",
                        sound_times=[0.5, 0.9, 1.3, 1.7, 2.1],
                        damage=20,
                        spread=300.0 / 8192.0,
                        vertical_spread=500.0 / 8192.0,
                        # TankMachineGun: MZ2_TANK_MACHINEGUN_1 to 19 as the gun sweeps.
                        muzzles=[
                            Vec3(x=22.9, y=-0.7, z=25.3),
                            Vec3(x=22.2, y=6.2, z=22.3),
                            Vec3(x=19.4, y=13.1, z=18.6),
                            Vec3(x=19.4, y=18.8, z=18.6),
                            Vec3(x=17.9, y=25.0, z=18.6),
                            Vec3(x=14.1, y=30.5, z=20.6),
                            Vec3(x=9.3, y=35.3, z=22.1),
                            Vec3(x=4.7, y=38.4, z=22.1),
                            Vec3(x=-1.1, y=40.4, z=24.1),
                            Vec3(x=-6.5, y=41.2, z=24.1),
                            Vec3(x=3.2, y=40.1, z=24.7),
                            Vec3(x=11.7, y=36.7, z=26.0),
                            Vec3(x=18.9, y=31.3, z=26.0),
                            Vec3(x=24.4, y=24.4, z=26.4),
                            Vec3(x=27.1, y=17.1, z=27.2),
                            Vec3(x=28.5, y=9.1, z=28.0),
                            Vec3(x=27.1, y=2.2, z=28.0),
                            Vec3(x=24.9, y=-2.8, z=28.0),
                            Vec3(x=21.6, y=-7.0, z=26.4)
                        ],
                        flash=Q2_GUN_FLASH,
                        missile_yaw=[
                            40.0,
                            32.0,
                            24.0,
                            16.0,
                            8.0,
                            0.0,
                            -8.0,
                            -16.0,
                            -24.0,
                            -32.0,
                            -24.0,
                            -16.0,
                            -8.0,
                            0.0,
                            8.0,
                            16.0,
                            24.0,
                            32.0,
                            40.0
                        ]
                    ),
                    AttackProfile(
                        name="rockets",
                        kind="ranged",
                        weight=0.3,
                        min_range=250.0,
                        max_range=1000.0,
                        times=[2.3, 2.6, 2.9],
                        duration=5.3,
                        frames=["attak3" + two(i) for i in range(1, 54)],
                        sound="sound/tank/tnkatck3.wav",
                        sound_times=[2.3, 2.6, 2.9],
                        damage=50,
                        splash=50,
                        radius=70.0,
                        missile_speed=550.0,
                        missile_effect="q2_rocket",
                        muzzles=[
                            Vec3(x=6.2, y=29.1, z=49.1),
                            Vec3(x=6.9, y=23.8, z=49.1),
                            Vec3(x=8.3, y=17.8, z=49.5)
                        ],
                        flash=Q2_ROCKET_FLASH
                    )
                ]
            );
        }
        if kind == "monster_supertank" {
            return OpponentRule(
                explodes=True,
                hull_bottom=0.0,
                hull_top=112.0,
                model="models/monsters/boss1/tris.md2",
                # m_supertank.c supertank_move_run / supertank_move_forward.
                run=Gait(
                    frames=["forwrd" + str(i) for i in range(1, 19)],
                    steps=[12.0 for i in range(18)]
                ),
                walk=Gait(
                    frames=["forwrd" + str(i) for i in range(1, 19)],
                    steps=[4.0 for i in range(18)]
                ),
                health=1500,
                width=64.0,
                stop_range=160.0,
                idle_frames=["stand" + str(i) for i in range(1, 61)],
                pain_variants=[
                    ["paina" + str(i) for i in range(1, 5)],
                    ["painb" + str(i) for i in range(5, 9)],
                    ["painc" + str(i) for i in range(9, 13)]
                ],
                pain_variant_damage=[10, 25],
                pain_variant_durations=[0.4, 0.4, 0.4],
                pain_interval=3.0,
                death_frames=["death" + str(i) for i in range(1, 25)],
                pain_sounds=[
                    "sound/bosstank/btkpain1.wav",
                    "sound/bosstank/btkpain2.wav",
                    "sound/bosstank/btkpain3.wav"
                ],
                death_sound="sound/bosstank/btkdeth1.wav",
                attacks=[
                    AttackProfile(
                        name="chaingun",
                        kind="ranged",
                        weight=0.3,
                        max_range=1000.0,
                        times=[0.0, 0.1, 0.2, 0.3, 0.4, 0.5],
                        duration=2.0,
                        frames=["attaka" + str(i) for i in range(1, 21)],
                        repeat_start=0.0,
                        repeat_end=0.6,
                        repeat_chance=0.9,
                        damage=6,
                        spread=300.0 / 8192.0,
                        vertical_spread=500.0 / 8192.0,
                        muzzles=[Vec3(x=30.0, y=30.0, z=88.5)],
                        flash=Q2_GUN_FLASH
                    ),
                    AttackProfile(
                        name="rockets",
                        kind="ranged",
                        weight=0.7,
                        min_range=160.0,
                        max_range=1000.0,
                        times=[0.7, 1.0, 1.3],
                        duration=2.7,
                        frames=["attakb" + str(i) for i in range(1, 28)],
                        damage=50,
                        splash=50,
                        radius=70.0,
                        missile_speed=500.0,
                        missile_effect="q2_rocket",
                        muzzles=[
                            Vec3(x=16.0, y=-22.5, z=91.2),
                            Vec3(x=16.0, y=-33.4, z=86.7),
                            Vec3(x=16.0, y=-42.8, z=83.3)
                        ],
                        flash=Q2_ROCKET_FLASH
                    )
                ]
            );
        }
        if kind == "monster_boss2" {
            return OpponentRule(
                explodes=True,
                hull_bottom=0.0,
                hull_top=80.0,
                model="models/monsters/boss2/tris.md2",
                # m_boss2.c boss2_move_run / boss2_move_walk.
                run=Gait(
                    frames=["walk" + str(i) for i in range(1, 21)],
                    steps=[8.0 for i in range(20)]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 21)],
                    steps=[8.0 for i in range(20)]
                ),
                health=2000,
                width=56.0,
                movement="fly",
                slides=True,
                stop_range=160.0,
                idle_frames=["stand" + str(i) for i in range(30, 51)],
                pain_variants=[
                    ["pain" + str(i) for i in range(20, 24)],
                    ["pain" + str(i) for i in range(2, 20)]
                ],
                pain_variant_damage=[30],
                pain_variant_durations=[0.4, 1.8],
                pain_interval=3.0,
                death_frames=["death" + str(i) for i in range(2, 51)],
                pain_sounds=[
                    "sound/bosshovr/bhvpain1.wav",
                    "sound/bosshovr/bhvpain2.wav",
                    "sound/bosshovr/bhvpain3.wav"
                ],
                death_sound="sound/bosshovr/bhvdeth1.wav",
                attacks=[
                    AttackProfile(
                        name="machineguns",
                        kind="ranged",
                        weight=0.6,
                        max_range=1000.0,
                        times=[0.9, 1.0, 1.1, 1.2, 1.3],
                        duration=1.9,
                        frames=["attack" + str(i) for i in range(1, 20)],
                        repeat_start=0.9,
                        repeat_end=1.5,
                        repeat_chance=0.7,
                        damage=5,
                        pellets=3,
                        spread=300.0 / 8192.0,
                        vertical_spread=500.0 / 8192.0,
                        aim_lag=0.2,
                        # Boss2MachineGun: the left and right guns together.
                        muzzles=[Vec3(x=32.0, y=-40.0, z=70.0), Vec3(x=32.0, y=40.0, z=70.0)],
                        volley=True,
                        flash=Q2_GUN_FLASH
                    ),
                    AttackProfile(
                        name="rockets",
                        kind="ranged",
                        weight=0.4,
                        min_range=125.0,
                        max_range=1000.0,
                        times=[1.2],
                        duration=2.1,
                        frames=["attack" + str(i) for i in range(20, 41)],
                        damage=50,
                        splash=50,
                        radius=70.0,
                        missile_speed=500.0,
                        missile_effect="q2_rocket",
                        missile_count=4,
                        # Boss2Rocket: MZ2_BOSS2_ROCKET_1 to 4 at once.
                        muzzles=[
                            Vec3(x=22.0, y=16.0, z=10.0),
                            Vec3(x=22.0, y=8.0, z=10.0),
                            Vec3(x=22.0, y=-8.0, z=10.0),
                            Vec3(x=22.0, y=-16.0, z=10.0)
                        ],
                        volley=True,
                        flash=Q2_ROCKET_FLASH
                    )
                ]
            );
        }
        if kind == "monster_jorg" {
            return OpponentRule(
                explodes=True,
                hull_bottom=0.0,
                hull_top=140.0,
                model="models/monsters/boss3/jorg/tris.md2",
                # m_boss31.c jorg_move_run / jorg_move_walk.
                run=Gait(
                    frames=["walk" + two(i) for i in range(6, 20)],
                    steps=[17.0, 0.0, 0.0, 0.0, 12.0, 8.0, 10.0, 33.0, 0.0, 0.0, 0.0, 9.0, 9.0, 9.0]
                ),
                walk=Gait(
                    frames=["walk" + two(i) for i in range(6, 20)],
                    steps=[17.0, 0.0, 0.0, 0.0, 12.0, 8.0, 10.0, 33.0, 0.0, 0.0, 0.0, 9.0, 9.0, 9.0]
                ),
                health=3000,
                width=80.0,
                stop_range=200.0,
                idle_frames=["stand" + two(i) for i in range(1, 52)],
                pain_variants=[
                    ["pain10" + str(i) for i in range(1, 4)],
                    ["pain20" + str(i) for i in range(1, 4)],
                    ["pain3" + two(i) for i in range(1, 26)]
                ],
                pain_variant_damage=[50, 100],
                pain_variant_durations=[0.3, 0.3, 2.5],
                pain_interval=3.0,
                pain_sounds=[
                    "sound/boss3/bs3pain1.wav",
                    "sound/boss3/bs3pain2.wav",
                    "sound/boss3/bs3pain3.wav"
                ],
                death_sound="sound/boss3/bs3deth1.wav",
                successor="monster_makron",
                attacks=[
                    AttackProfile(
                        name="chainguns",
                        kind="ranged",
                        weight=0.75,
                        max_range=1000.0,
                        times=[0.8, 0.9, 1.0, 1.1, 1.2, 1.3],
                        duration=1.8,
                        frames=["attak1" + two(i) for i in range(1, 19)],
                        repeat_start=0.8,
                        repeat_end=1.4,
                        repeat_chance=0.9,
                        sound="sound/boss3/bs3atck1.wav",
                        sound_times=[0.0],
                        damage=6,
                        pellets=2,
                        spread=300.0 / 8192.0,
                        vertical_spread=500.0 / 8192.0,
                        aim_lag=0.2,
                        # jorg_firebullet: the left and right arm guns together.
                        muzzles=[Vec3(x=78.5, y=-47.1, z=96.0), Vec3(x=78.5, y=46.7, z=96.0)],
                        volley=True,
                        flash=Q2_GUN_FLASH
                    ),
                    AttackProfile(
                        name="bfg",
                        kind="ranged",
                        weight=0.25,
                        max_range=1000.0,
                        times=[0.6],
                        duration=1.3,
                        frames=["attak2" + two(i) for i in range(1, 14)],
                        sound="sound/boss3/bs3atck2.wav",
                        sound_times=[0.0],
                        damage=50,
                        splash=50,
                        radius=200.0,
                        missile_speed=300.0,
                        missile_effect="q2_bfg",
                        beam_damage=10,
                        beam_radius=256.0,
                        burst_damage=50,
                        burst_radius=200.0,
                        muzzles=[Vec3(x=6.3, y=-9.0, z=111.2)],
                        flash=Q2_BFG_FLASH
                    )
                ]
            );
        }
        if kind == "monster_makron" {
            return OpponentRule(
                hull_bottom=0.0,
                hull_top=90.0,
                model="models/monsters/boss3/rider/tris.md2",
                # m_boss32.c makron_move_run / makron_move_walk.
                run=Gait(
                    frames=["walk2" + two(i) for i in range(4, 14)],
                    steps=[3.0, 12.0, 8.0, 8.0, 8.0, 6.0, 12.0, 9.0, 6.0, 12.0]
                ),
                walk=Gait(
                    frames=["walk2" + two(i) for i in range(4, 14)],
                    steps=[3.0, 12.0, 8.0, 8.0, 8.0, 6.0, 12.0, 9.0, 6.0, 12.0]
                ),
                health=3000,
                width=30.0,
                stop_range=160.0,
                idle_frames=["stand2" + two(i) for i in range(1, 61)],
                pain_variants=[
                    ["pain40" + str(i) for i in range(1, 5)],
                    ["pain50" + str(i) for i in range(1, 5)],
                    ["pain6" + two(i) for i in range(1, 28)]
                ],
                pain_variant_damage=[40, 110],
                pain_variant_durations=[0.4, 0.4, 2.7],
                pain_interval=3.0,
                death_frames=["death2" + two(i) for i in range(1, 96)],
                sight_sound="sound/makron/voice.wav",
                pain_sounds=[
                    "sound/makron/pain3.wav",
                    "sound/makron/pain2.wav",
                    "sound/makron/pain1.wav"
                ],
                death_sound="sound/makron/death.wav",
                attacks=[
                    AttackProfile(
                        name="bfg",
                        kind="ranged",
                        weight=0.3,
                        max_range=1000.0,
                        times=[0.3],
                        duration=0.8,
                        frames=["attak30" + str(i) for i in range(1, 9)],
                        sound="sound/makron/bfg_fire.wav",
                        sound_times=[0.3],
                        damage=50,
                        splash=50,
                        radius=300.0,
                        missile_speed=300.0,
                        missile_effect="q2_bfg",
                        beam_damage=10,
                        beam_radius=256.0,
                        burst_damage=50,
                        burst_radius=300.0,
                        muzzles=[Vec3(x=17.0, y=-19.5, z=62.9)],
                        flash=Q2_BFG_FLASH
                    ),
                    AttackProfile(
                        name="hyperblaster",
                        kind="ranged",
                        weight=0.3,
                        max_range=1000.0,
                        times=[
                            0.4,
                            0.5,
                            0.6,
                            0.7,
                            0.8,
                            0.9,
                            1.0,
                            1.1,
                            1.2,
                            1.3,
                            1.4,
                            1.5,
                            1.6,
                            1.7,
                            1.8,
                            1.9,
                            2.0
                        ],
                        duration=2.6,
                        frames=["attak4" + two(i) for i in range(1, 27)],
                        damage=15,
                        missile_speed=1000.0,
                        missile_effect="q2_bolt",
                        # MakronHyperblaster: MZ2_MAKRON_BLASTER_1 to 17 by frame.
                        muzzles=[
                            Vec3(x=-3.6, y=-24.1, z=59.5),
                            Vec3(x=-1.6, y=-19.3, z=59.5),
                            Vec3(x=-0.1, y=-14.4, z=59.5),
                            Vec3(x=2.0, y=-7.6, z=59.5),
                            Vec3(x=3.4, y=1.3, z=59.5),
                            Vec3(x=3.7, y=11.1, z=59.5),
                            Vec3(x=-0.3, y=22.3, z=59.5),
                            Vec3(x=-6.0, y=33.0, z=59.5),
                            Vec3(x=-9.3, y=36.4, z=59.5),
                            Vec3(x=-7.0, y=35.0, z=59.5),
                            Vec3(x=-2.1, y=29.0, z=59.5),
                            Vec3(x=3.9, y=17.3, z=59.5),
                            Vec3(x=6.1, y=5.8, z=59.5),
                            Vec3(x=5.9, y=-4.4, z=59.5),
                            Vec3(x=4.2, y=-14.1, z=59.5),
                            Vec3(x=2.4, y=-18.8, z=59.5),
                            Vec3(x=-1.8, y=-25.5, z=59.5)
                        ],
                        flash=Q2_GUN_FLASH,
                        missile_yaw=[
                            80.0,
                            70.0,
                            60.0,
                            50.0,
                            40.0,
                            30.0,
                            20.0,
                            10.0,
                            0.0,
                            -70.0,
                            -60.0,
                            -50.0,
                            -40.0,
                            -30.0,
                            -20.0,
                            -10.0,
                            0.0
                        ]
                    ),
                    AttackProfile(
                        name="railgun",
                        kind="ranged",
                        weight=0.4,
                        max_range=1000.0,
                        times=[0.8],
                        duration=1.6,
                        frames=["attak5" + two(i) for i in range(1, 17)],
                        sound="sound/makron/rail_up.wav",
                        sound_times=[0.0],
                        damage=50,
                        rail=True,
                        lock_aim=True,
                        muzzles=[Vec3(x=-17.3, y=7.8, z=72.4)],
                        flash=Q2_RAIL_FLASH
                    )
                ]
            );
        }
        if kind == "misc_insane" {
            # m_insane.c: harmless marines (AI_GOOD_GUY) that never hunt the
            # player; they moan and scream, crawl with spawnflag 4, and hang
            # crucified with spawnflag 8. All of them can be killed.
            if flags & 8 {
                return OpponentRule(
                    model="models/monsters/insane/tris.md2",
                    health=100,
                    movement="none",
                    passive=True,
                    good_guy=True,
                    speed=0.0,
                    idle_frames=["cross" + str(i) for i in range(1, 16)],
                    death_frames=["cross1"],
                    pain_sounds=["sound/insane/insane5.wav"],
                    idle_sound="sound/insane/insane7.wav"
                );
            }
            crawls = flags & 4 != 0;
            # insane_run / insane_walk: the crawl (insane_move_runcrawl) or the
            # normal walk (insane_move_run_normal), both stepping with ai_walk.
            gait = Gait(
                frames=["walk" + str(i) for i in range(27, 40)],
                steps=[0.0, 2.5, 3.5, 1.7, 2.3, 2.4, 2.2, 4.2, 5.6, 3.3, 2.4, 0.9, 0.0]
            );
            if crawls {
                gait = Gait(
                    frames=["crawl" + str(i) for i in range(1, 10)],
                    steps=[0.0, 1.5, 2.1, 3.6, 2.0, 0.9, 3.0, 3.4, 2.4]
                );
            }
            return OpponentRule(
                model="models/monsters/insane/tris.md2",
                run=gait,
                walk=gait,
                health=100,
                stop_range=120.0,
                idle_frames=["crawl" + str(i) for i in range(1, 10)]
                    if crawls
                    else ["stand" + str(i) for i in range(60, 66)],
                pain_frames=["cr_pain" + str(i) for i in range(2, 11)]
                    if crawls
                    else ["st_pain" + str(i) for i in range(2, 13)],
                pain_duration=0.9 if crawls else 1.1,
                pain_interval=3.0,
                death_frames=["cr_death" + str(i) for i in range(10, 17)]
                    if crawls
                    else ["st_death" + str(i) for i in range(2, 19)],
                pain_sounds=["sound/insane/insane1.wav", "sound/insane/insane2.wav", "sound/insane/insane3.wav"],
                idle_sound="sound/insane/insane9.wav",
                passive=True,
                good_guy=True
            );
        }
        if kind == "monster_commander_body" {
            return OpponentRule(
                model="models/monsters/commandr/tris.md2",
                health=1,
                movement="none",
                decoration=True,
                speed=0.0,
                idle_frames=["inactive"]
            );
        }
        if kind == "monster_boss3_stand" {
            return OpponentRule(
                model="models/monsters/boss3/rider/tris.md2",
                health=1,
                movement="none",
                decoration=True,
                speed=0.0,
                idle_frames=["stand2" + two(i) for i in range(1, 61)]
            );
        }
        if kind == "monster_chick" {
            return OpponentRule(
                hull_bottom=0.0,
                hull_top=56.0,
                sight_sound="sound/chick/chksght1.wav",
                pain_sounds=["sound/chick/chkpain1.wav", "sound/chick/chkpain2.wav", "sound/chick/chkpain3.wav"],
                death_sound="sound/chick/chkdeth1.wav",
                idle_sound="sound/chick/chkidle1.wav",
                model="models/monsters/bitch/tris.md2",
                # m_chick.c chick_move_run / chick_move_walk.
                run=Gait(
                    frames=["walk" + two(i) for i in range(11, 21)],
                    steps=[6.0, 8.0, 13.0, 5.0, 7.0, 4.0, 11.0, 5.0, 9.0, 7.0]
                ),
                walk=Gait(
                    frames=["walk" + two(i) for i in range(11, 21)],
                    steps=[6.0, 8.0, 13.0, 5.0, 7.0, 4.0, 11.0, 5.0, 9.0, 7.0]
                ),
                duck_frames=["duck" + two(i) for i in range(1, 8)],
                duck_down=0,
                duck_hold=2,
                duck_up=4,
                pain_duration=0.5,
                pain_interval=3.0,
                pain_frames=["pain" + str(i) for i in range(101, 106)],
                repeat_start=1.3,
                repeat_end=2.7,
                repeat_chance=0.6,
                melee_repeat_start=0.3,
                melee_repeat_end=1.2,
                melee_repeat_chance=0.9,
                health=175,
                damage=50,
                missile_speed=500.0,
                missile_effect="q2_rocket",
                muzzles=[Vec3(x=24.8, y=-9.0, z=39.0)],
                flash=Q2_ROCKET_FLASH,
                splash=50,
                radius=70.0,
                attack_times=[1.3],
                attack_duration=3.2,
                attack_frames=["attak" + str(i) for i in range(101, 133)],
                attack_steps=[
                    0.0,
                    0.0,
                    0.0,
                    4.0,
                    0.0,
                    -3.0,
                    3.0,
                    5.0,
                    7.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    19.0,
                    -6.0,
                    -5.0,
                    -2.0,
                    -7.0,
                    0.0,
                    1.0,
                    10.0,
                    4.0,
                    5.0,
                    6.0,
                    6.0,
                    4.0,
                    3.0,
                    -3.0,
                    0.0,
                    -6.0,
                    -4.0,
                    -2.0
                ],
                attack_sound="sound/chick/chkatck1.wav",
                melee=10,
                melee_max=15,
                melee_knockback=100.0,
                melee_range=80.0,
                melee_times=[0.4],
                melee_duration=1.6,
                melee_frames=["attak" + str(i) for i in range(201, 217)],
                melee_steps=[
                    1.0,
                    8.0,
                    3.0,
                    1.0,
                    7.0,
                    -7.0,
                    1.0,
                    -1.0,
                    1.0,
                    0.0,
                    1.0,
                    -2.0,
                    -6.0,
                    -1.0,
                    -6.0,
                    0.0
                ],
                melee_sound="sound/chick/chkatck3.wav",
                melee_sound_times=[0.4]
            );
        }
        if kind == "monster_berserk" {
            return OpponentRule(
                sight_sound="sound/berserk/sight.wav",
                pain_sounds=["sound/berserk/berpain2.wav"],
                death_sound="sound/berserk/berdeth2.wav",
                idle_sound="sound/berserk/beridle1.wav",
                model="models/monsters/berserk/tris.md2",
                # m_berserk.c berserk_move_run1 / berserk_move_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 7)],
                    steps=[21.0, 11.0, 21.0, 25.0, 18.0, 19.0]
                ),
                walk=Gait(
                    frames=["walkc" + str(i) for i in range(1, 12)],
                    steps=[9.1, 6.3, 4.9, 6.7, 6.0, 8.2, 7.2, 6.1, 4.9, 4.7, 4.7]
                ),
                pain_duration=0.4,
                pain_interval=3.0,
                pain_frames=["painc" + str(i) for i in range(1, 5)],
                melee_sound="sound/berserk/attack.wav",
                melee_sound_times=[0.2],
                alternate_melee_sound_times=[0.4],
                health=240,
                stop_range=60.0,
                attack_range=80.0,
                melee_range=80.0,
                melee=15,
                melee_max=20,
                melee_knockback=400.0,
                melee_times=[0.3],
                melee_duration=0.8,
                melee_frames=["att_c" + str(i) for i in range(1, 9)],
                alternate_melee_times=[0.8],
                alternate_melee_duration=1.2,
                alternate_melee_frames=["att_c" + str(i) for i in range(9, 21)],
                alternate_melee_damage=5,
                alternate_melee_max=10
            );
        }
        if kind == "monster_gladiator" {
            return OpponentRule(
                width=32.0,
                hull_bottom=-24.0,
                hull_top=64.0,
                sight_sound="sound/gladiator/sight.wav",
                pain_sounds=["sound/gladiator/pain.wav", "sound/gladiator/gldpain2.wav"],
                death_sound="sound/gladiator/glddeth2.wav",
                idle_sound="sound/gladiator/gldidle1.wav",
                model="models/monsters/gladiatr/tris.md2",
                # m_gladiator.c gladiator_move_run / gladiator_move_walk.
                run=Gait(
                    frames=["run" + str(i) for i in range(1, 7)],
                    steps=[23.0, 14.0, 14.0, 21.0, 12.0, 13.0]
                ),
                walk=Gait(
                    frames=["walk" + str(i) for i in range(1, 17)],
                    steps=[15.0, 7.0, 6.0, 5.0, 2.0, 0.0, 2.0, 8.0, 12.0, 8.0, 5.0, 5.0, 2.0, 2.0, 1.0, 8.0]
                ),
                pain_duration=0.6,
                pain_interval=3.0,
                pain_frames=["pain" + str(i) for i in range(1, 7)],
                attack_sound="sound/gladiator/railgun.wav",
                melee_sound="sound/gladiator/melee1.wav",
                melee_sound_times=[0.4, 1.0],
                health=400,
                damage=50,
                lock_aim=True,
                rail=True,
                muzzles=[Vec3(x=30.0, y=18.0, z=28.0)],
                flash=Q2_RAIL_FLASH,
                ranged_min=112.0,
                stop_range=64.0,
                attack_times=[0.3],
                attack_duration=0.9,
                attack_frames=["attack" + str(i) for i in range(1, 10)],
                melee_range=80.0,
                melee=20,
                melee_max=24,
                melee_knockback=300.0,
                melee_times=[0.6, 1.3],
                melee_duration=1.7,
                melee_frames=["melee" + str(i) for i in range(1, 18)]
            );
        }
        if kind == "monster_infantry" {
            return OpponentRule(
                sight_sound="sound/infantry/infsght1.wav",
                pain_sounds=["sound/infantry/infpain1.wav", "sound/infantry/infpain2.wav"],
                death_sound="sound/infantry/infdeth1.wav",
                idle_sound="sound/infantry/infidle1.wav",
                model="models/monsters/infantry/tris.md2",
                # m_infantry.c infantry_move_run / infantry_move_walk.
                run=Gait(
                    frames=["run" + two(i) for i in range(1, 9)],
                    steps=[10.0, 20.0, 5.0, 7.0, 30.0, 35.0, 2.0, 6.0]
                ),
                walk=Gait(
                    frames=["walk" + two(i) for i in range(3, 15)],
                    steps=[5.0, 4.0, 4.0, 5.0, 4.0, 5.0, 6.0, 4.0, 4.0, 4.0, 4.0, 5.0]
                ),
                duck_frames=["duck" + two(i) for i in range(1, 6)],
                duck_down=0,
                duck_hold=1,
                duck_up=3,
                pain_duration=1.0,
                pain_interval=3.0,
                pain_frames=["pain" + str(i) for i in range(101, 111)],
                melee=5,
                melee_max=9,
                melee_range=80.0,
                melee_knockback=50.0,
                melee_times=[0.5],
                melee_duration=0.8,
                melee_frames=["attak" + str(i) for i in range(201, 209)],
                melee_steps=[3.0, 6.0, 0.0, 8.0, 5.0, 8.0, 6.0, 3.0],
                health=100,
                damage=3,
                spread=300.0 / 8192.0,
                vertical_spread=500.0 / 8192.0,
                aim_lag=0.2,
                muzzles=[Vec3(x=26.6, y=7.1, z=13.1)],
                flash=Q2_GUN_FLASH,
                attack_times=[1.0],
                attack_duration=1.5,
                burst_min=4,
                burst_max=19,
                hold_frame=10,
                attack_frames=["attak" + str(i) for i in range(101, 116)],
                attack_sound="sound/infantry/infatck1.wav",
                attack_sound_times=[1.0],
                melee_sound="sound/infantry/infatck2.wav",
                melee_sound_times=[0.3]
            );
        }
        if kind in ["monster_soldier_light", "monster_soldier", "monster_soldier_ss"] {
            rule = OpponentRule(
                sight_sound="sound/soldier/solsght1.wav",
                pain_sounds=["sound/soldier/solpain2.wav"],
                death_sound="sound/soldier/soldeth2.wav",
                attack_sound="sound/soldier/solatck2.wav",
                attack_sound_times=[0.2],
                idle_sound="sound/soldier/solidle1.wav",
                model="models/monsters/soldier/tris.md2",
                # m_soldier.c soldier_move_run and soldier_move_walk1, which soldier_walk1_random loops at walk110 nine times in ten; MODEL_SCALE 1.2.
                run=Gait(
                    frames=["run" + two(i) for i in range(3, 9)],
                    steps=[10.0, 11.0, 11.0, 16.0, 10.0, 15.0]
                ),
                walk=Gait(
                    frames=["walk1" + two(i) for i in range(1, 11)],
                    steps=[3.0, 6.0, 2.0, 2.0, 2.0, 1.0, 6.0, 5.0, 3.0, -1.0]
                ),
                step_scale=1.2,
                duck_frames=["duck" + two(i) for i in range(1, 6)],
                duck_down=0,
                duck_hold=1,
                duck_up=3,
                # attak301-309, looping back from 306 to 303 once while the
                # one-second duck lasts: shots at 303, crouched from 303 to 307.
                crouch_frames=["attak30" + str(i) for i in [1, 2, 3, 4, 5, 6, 3, 4, 5, 6, 7, 8, 9]],
                crouch_times=[0.2, 0.6],
                crouch_duration=1.3,
                crouch_start=0.2,
                crouch_end=1.0,
                pain_duration=0.5,
                pain_interval=3.0,
                pain_frames=["pain" + str(i) for i in range(101, 106)],
                health=20,
                damage=5,
                missile_speed=600.0,
                missile_effect="q2_bolt",
                aim_spread=1000.0 / 8192.0,
                aim_vertical=500.0 / 8192.0,
                # soldier_fire: flash 1 standing (attack1), 3 crouched
                # (attack3), 4 for the machine gunner (attack4), scaled 1.2.
                muzzles=[Vec3(x=12.72, y=9.24, z=9.36)],
                crouch_muzzles=[Vec3(x=24.96, y=12.12, z=-3.24)],
                flash=Q2_GUN_FLASH,
                attack_times=[0.2],
                attack_duration=1.2,
                attack_frames=["attak" + str(i) for i in range(101, 113)]
            );
            if kind == "monster_soldier" {
                rule.pain_sounds = ["sound/soldier/solpain1.wav"];
                rule.death_sound = "sound/soldier/soldeth1.wav";
                rule.attack_sound = "sound/soldier/solatck1.wav";
                rule.health = 30;
                rule.skin = 2;
                rule.damage = 2;
                rule.missile_speed = 0.0;
                rule.missile_effect = "";
                rule.pellets = 12;
                rule.spread = 1000.0 / 8192.0;
                rule.vertical_spread = 500.0 / 8192.0;
            } elif kind == "monster_soldier_ss" {
                rule.pain_sounds = ["sound/soldier/solpain3.wav"];
                rule.death_sound = "sound/soldier/soldeth3.wav";
                rule.attack_sound = "sound/soldier/solatck3.wav";
                rule.health = 40;
                rule.skin = 4;
                rule.damage = 2;
                rule.missile_speed = 0.0;
                rule.missile_effect = "";
                rule.spread = 300.0 / 8192.0;
                rule.vertical_spread = 500.0 / 8192.0;
                rule.attack_duration = 0.6;
                rule.attack_frames = ["attak" + str(i) for i in range(401, 407)];
                rule.burst_min = 4;
                rule.burst_max = 11;
                rule.hold_frame = 2;
                rule.muzzles = [Vec3(x=9.12, y=11.16, z=0.96)];
            }
            return rule;
        }
    }
    return None;
}
