"""Campaign enemy definitions; behavioral special cases remain explicit work."""
import from engine.world.opponent_rule { OpponentRule }

def enemy_rule(game: str, kind: str) -> OpponentRule | None {
    if game == "q1" {
        if kind == "monster_boss" {
            return OpponentRule(
                model="progs/boss.mdl", script="chthon", health=3, speed=0.0
            );
        }
        if kind == "monster_hell_knight" {
            return OpponentRule(
                model="progs/hknight.mdl",
                health=250,
                speed=190.0,
                damage=9,
                missile_speed=300.0,
                missile_effect="q1_knightspike",
                missile_yaw=[-12.0, -6.0, 0.0, 6.0, 12.0, 18.0],
                aim_vertical=0.05,
                attack_times=[0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                attack_duration=1.1,
                attack_frames=["magicc" + str(i) for i in range(1, 12)],
                attack_sound="sound/hknight/attack1.wav",
                attack_sound_times=[0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                melee_random_scale=3.0,
                melee_range=60.0,
                melee_times=[0.4, 0.5, 0.6, 0.7, 0.8],
                melee_duration=1.0,
                melee_frames=["slice" + str(i) for i in range(1, 11)],
                melee_steps=[9.0, 6.0, 13.0, 4.0, 7.0, 15.0, 8.0, 2.0, 0.0, 3.0],
                melee_sound="sound/hknight/slash1.wav"
            );
        }
        if kind == "monster_army" {
            return OpponentRule(
                model="progs/soldier.mdl",
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
                aim_lag=0.2
            );
        }
        if kind == "monster_dog" {
            return OpponentRule(
                model="progs/dog.mdl",
                melee_sound="sound/dog/dattack1.wav",
                melee_sound_times=[0.3],
                attack_steps=[10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0],
                attack_times=[0.3],
                attack_duration=0.8,
                attack_frames=[
                    "attack1",
                    "attack2",
                    "attack3",
                    "attack4",
                    "attack5",
                    "attack6",
                    "attack7",
                    "attack8"
                ],
                health=25,
                speed=180.0,
                melee=12,
                melee_random_scale=8.0,
                attack_range=100.0,
                melee_range=100.0,
                stop_range=48.0
            );
        }
        if kind == "monster_knight" {
            return OpponentRule(
                model="progs/knight.mdl",
                melee_sound="sound/knight/sword1.wav",
                attack_steps=[0.0, 7.0, 4.0, 0.0, 3.0, 4.0, 1.0, 3.0, 1.0, 5.0],
                attack_times=[0.5, 0.6, 0.7],
                attack_duration=1.0,
                attack_frames=[
                    "attackb1",
                    "attackb2",
                    "attackb3",
                    "attackb4",
                    "attackb5",
                    "attackb6",
                    "attackb7",
                    "attackb8",
                    "attackb9",
                    "attackb10"
                ],
                health=75,
                speed=160.0,
                melee=9,
                melee_random_scale=3.0,
                melee_range=60.0,
                attack_range=64.0,
                stop_range=40.0
            );
        }
        if kind == "monster_enforcer" {
            return OpponentRule(
                model="progs/enforcer.mdl",
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
                missile_effect="q1_laser"
            );
        }
        if kind in ["monster_ogre", "monster_ogre_marksman"] {
            return OpponentRule(
                model="progs/ogre.mdl",
                attack_sound="sound/weapons/grenade.wav",
                attack_sound_times=[0.3],
                melee_sound="sound/ogre/ogsawatk.wav",
                health=200,
                speed=120.0,
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
                interval=1.0
            );
        }
    } elif game == "q2" {
        if kind == "monster_chick" {
            return OpponentRule(
                model="models/monsters/bitch/tris.md2",
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
                speed=75.0,
                run_frames=["walk" + str(i) for i in range(11, 21)],
                damage=50,
                missile_speed=500.0,
                missile_effect="q2_rocket",
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
                model="models/monsters/berserk/tris.md2",
                pain_duration=0.4,
                pain_interval=3.0,
                pain_frames=["painc" + str(i) for i in range(1, 5)],
                melee_sound="sound/berserk/attack.wav",
                melee_sound_times=[0.2],
                alternate_melee_sound_times=[0.4],
                health=240,
                speed=191.666667,
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
                model="models/monsters/gladiatr/tris.md2",
                pain_duration=0.6,
                pain_interval=3.0,
                pain_frames=["pain" + str(i) for i in range(1, 7)],
                attack_sound="sound/gladiator/railgun.wav",
                melee_sound="sound/gladiator/melee1.wav",
                melee_sound_times=[0.4, 1.0],
                health=400,
                speed=161.666667,
                damage=50,
                lock_aim=True,
                rail=True,
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
                model="models/monsters/infantry/tris.md2",
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
                attack_times=[1.0],
                attack_duration=1.5,
                burst_min=4,
                burst_max=19,
                hold_frame=10,
                attack_frames=["attak" + str(i) for i in range(101, 116)]
            );
        }
        if kind in ["monster_soldier_light", "monster_soldier", "monster_soldier_ss"] {
            rule = OpponentRule(
                model="models/monsters/soldier/tris.md2",
                pain_duration=0.5,
                pain_interval=3.0,
                pain_frames=["pain" + str(i) for i in range(101, 106)],
                health=20,
                damage=5,
                missile_speed=600.0,
                missile_effect="q2_bolt",
                aim_spread=1000.0 / 8192.0,
                aim_vertical=500.0 / 8192.0,
                attack_times=[0.2],
                attack_duration=1.2,
                attack_frames=["attak" + str(i) for i in range(101, 113)]
            );
            if kind == "monster_soldier" {
                rule.health = 30;
                rule.skin = 2;
                rule.damage = 2;
                rule.missile_speed = 0.0;
                rule.missile_effect = "";
                rule.pellets = 12;
                rule.spread = 1000.0 / 8192.0;
                rule.vertical_spread = 500.0 / 8192.0;
            } elif kind == "monster_soldier_ss" {
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
            }
            return rule;
        }
    }
    return None;
}
