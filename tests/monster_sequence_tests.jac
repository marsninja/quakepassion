"""Pain and death sequences: each monster's tables against the originals', the
selection rules of its pain and die functions, and the strides they carry."""
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Aim,
    CombatState,
    CombatTick,
    damage_opponent,
    actor_overlap,
    ensure_profiles,
    pain_length,
    pain_stagger,
    death_stride,
    corpse_settled
}
import from engine.world.opponent_rule { OpponentRule, Reaction }
import from engine.world.gibs { GibRule }
import from engine.world.speakers { Speaker }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

# Each original pain and death sequence as "frames:net stride:total stride",
# pains then deaths, read from the mmove_t tables of m_*.c and the frame
# functions of the v101 QuakeC (ai_painforward and ai_forward ahead, ai_pain
# and ai_back behind).
glob ORIGINAL_SEQUENCES: dict[str, list[list[str]]] = {
    "q1:monster_army": [["6:-1:1", "13:21:25", "14:20:24"], ["10:0:0", "11:-29:29"]],
    "q1:monster_dog": [["6:0:0", "16:-44:44"], ["9:0:0", "9:0:0"]],
    "q1:monster_knight": [["3:0:0", "11:21:21"], ["10:0:0", "11:0:0"]],
    "q1:monster_hell_knight": [["5:0:0"], ["9:0:0", "12:46:46"]],
    "q1:monster_enforcer": [["4:0:0", "5:0:0", "8:0:0", "19:4:8"], ["11:0:0", "14:34:34"]],
    "q1:monster_ogre": [["3:0:0", "5:0:0", "6:0:0", "15:-23:23", "16:-23:23"], ["10:41:41", "14:0:0"]],
    "q1:monster_wizard": [["4:0:0"], ["8:0:0"]],
    "q1:monster_demon1": [["6:0:0"], ["9:0:0"]],
    "q1:monster_shambler": [["6:0:0"], ["11:0:0"]],
    "q1:monster_zombie": [["12:-1:9", "13:-1:1", "18:-2:6", "28:-17:19"], []],
    "q1:monster_shalrath": [["5:0:0"], ["7:0:0"]],
    "q1:monster_fish": [["9:-48:48"], ["21:0:0"]],
    "q2:monster_soldier_light": [["5:3:9", "7:-1:27", "17:9:45", "18:10:42"], ["10:0:0", "24:-15:15", "35:-15:15", "36:-35:35", "45:-15:15", "53:0:0"]],
    "q2:monster_infantry": [["10:0:18", "10:0:20"], ["9:-31:31", "20:14:50", "25:-16:68"]],
    "q2:monster_berserk": [["4:0:0", "20:0:0"], ["8:0:0", "13:0:0"]],
    "q2:monster_gladiator": [["6:0:0", "7:0:0"], ["22:0:0"]],
    "q2:monster_chick": [["5:0:0", "5:0:0", "21:9:69"], ["12:8:22", "23:37:83"]],
    "q2:monster_gunner": [["5:0:6", "8:0:38", "18:0:20"], ["11:-1:29"]],
    "q2:monster_brain": [["6:0:12", "8:0:8", "21:0:30"], ["5:9:9", "18:7:11"]],
    "q2:monster_medic": [["8:0:0", "15:0:0"], ["30:0:0"]],
    "q2:monster_mutant": [["5:0:22", "6:0:52", "11:0:44"], ["9:0:0", "10:0:0"]],
    "q2:monster_parasite": [["11:9:35"], ["7:0:0"]],
    "q2:monster_flyer": [["4:0:0", "4:0:0", "9:0:0"], []],
    "q2:monster_floater": [["7:0:0", "8:0:0"], []],
    "q2:monster_hover": [["9:0:0", "12:0:0", "28:11:61"], ["11:9:29"]],
    "q2:monster_flipper": [["5:0:0", "5:0:0"], ["56:0:0"]],
    "q2:monster_tank": [["4:0:0", "5:0:0", "16:0:14"], ["32:-48:76"]],
    "q2:monster_supertank": [["4:0:0", "4:0:0", "4:0:0"], ["24:0:0"]],
    "q2:monster_boss2": [["4:0:0", "18:0:0"], ["49:0:0"]],
    "q2:monster_jorg": [["3:0:0", "3:0:0", "25:1:137"], ["50:0:0"]],
    "q2:monster_makron": [["4:0:0", "4:0:0", "27:0:0"], ["95:9:215"]]
};

"""A sequence list as the table above writes one, each sequence once."""
def signatures(sequences: list[Reaction]) -> list[str] {
    seen: list[str] = [];
    result: list[str] = [];
    for sequence in sequences {
        if sequence.frames[0] in seen {
            continue;
        }
        seen.append(sequence.frames[0]);
        net = 0.0;
        total = 0.0;
        for step in sequence.steps {
            net += step;
            total += abs(step);
        }
        result.append(str(len(sequence.frames)) + ":" + str(int(net)) + ":" + str(int(total)));
    }
    return sorted(result);
}

"""A monster of `kind` with a speaker for every sound its pain and death make."""
def sequenced(game: str, kind: str, seed: int = 1, skill: int = 1) -> Opponent {
    rule = enemy_rule(game, kind);
    assert rule is not None;
    paths: list[str] = [path for path in rule.pain_sounds];
    for sequence in rule.pains + rule.deaths + [rule.knockdown] {
        if sequence.sound and sequence.sound not in paths {
            paths.append(sequence.sound);
        }
        for event in sequence.events {
            for path in event.sounds {
                if path not in paths {
                    paths.append(path);
                }
            }
        }
    }
    if rule.death_sound {
        paths.append(rule.death_sound);
    }
    return Opponent(
        rule=rule,
        kind=kind,
        game=game,
        skill=skill,
        health=rule.health,
        max_health=rule.health,
        shot_random=1 + seed * 7919,
        pos=Vec3(z=22.01),
        grounded=True,
        speakers=[Speaker(path=path, origin=Vec3()) for path in paths],
        speaker_paths=paths
    );
}

"""The name of the pain a hit of `damage` draws, or "" for none."""
def pain_drawn(game: str, kind: str, damage: int, seed: int, skill: int = 1) -> str {
    enemy = sequenced(game, kind, seed, skill);
    damage_opponent(enemy, damage);
    if enemy.pain_wait <= 0.0 {
        return "";
    }
    return enemy.rule.pains[enemy.pain_variant - 1].name;
}

"""The name of the death a killing hit of `damage` draws."""
def death_drawn(game: str, kind: str, damage: int, seed: int) -> str {
    enemy = sequenced(game, kind, seed);
    enemy.health = 1;
    damage_opponent(enemy, damage);
    assert enemy.health == 0 and enemy.death_variant > 0;
    return enemy.rule.deaths[enemy.death_variant - 1].name;
}

"""How often each name comes up over `trials` seeds."""
def tally(names: list[str]) -> dict[str, int] {
    counts: dict[str, int] = {};
    for name in names {
        counts[name] = counts.get(name, 0) + 1;
    }
    return counts;
}

"""How many times the speaker for `path` has been asked to play."""
def heard(enemy: Opponent, path: str) -> int {
    for i in range(len(enemy.speaker_paths)) {
        if enemy.speaker_paths[i] == path {
            return enemy.speakers[i].requests;
        }
    }
    return 0;
}

"""A floor from `back` to `front` along x, its top at z 0."""
def strip(back: float, front: float) -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=back, y=-200.0, z=-16.0), Vec3(x=front, y=200.0, z=0.0), Vec3(), Vec3(), Vec3()
    );
    return collision;
}

"""Play out the pain a monster is in, in 20 Hz slices, and return its x."""
def stagger(enemy: Opponent, collision: CollisionMap, seconds: float = 100.0) -> float {
    elapsed = 0.0;
    while enemy.pain_wait > 0.000001 and elapsed < seconds - 0.000001 {
        pain_stagger(enemy, collision, 0.05);
        enemy.pain_wait = max(0.0, enemy.pain_wait - 0.05);
        elapsed += 0.05;
    }
    return enemy.pos.x;
}

test "every monster's pain and death tables match the originals" {
    for (key, expected) in ORIGINAL_SEQUENCES.items() {
        game = key.split(":")[0];
        kinds = [key.split(":")[1]];
        if kinds[0] == "monster_soldier_light" {
            kinds = kinds + ["monster_soldier", "monster_soldier_ss"];
        } elif kinds[0] == "monster_tank" {
            kinds.append("monster_tank_commander");
        } elif kinds[0] == "monster_ogre" {
            kinds.append("monster_ogre_marksman");
        }
        for kind in kinds {
            rule = enemy_rule(game, kind);
            assert rule is not None;
            assert signatures(rule.pains) == sorted(expected[0]) , kind + " pains " + str(signatures(rule.pains));
            assert signatures(rule.deaths) == sorted(expected[1]) , kind + " deaths " + str(signatures(rule.deaths));
            for sequence in rule.pains + rule.deaths {
                assert not sequence.steps or len(sequence.steps) == len(sequence.frames) , kind + ":" + sequence.name;
            }
        }
    }
    # zombie_paine, the knockdown: thirty frames, 15 back in all.
    zombie = enemy_rule("q1", "monster_zombie");
    assert zombie is not None;
    assert len(zombie.knockdown.frames) == 30 and len(zombie.knockdown.steps) == 30;
    assert sum(zombie.knockdown.steps) == -15.0;
    # paine11 waits five seconds (nextthink + 5) before it gets up.
    assert zombie.knockdown.hold_frame == 10 and zombie.knockdown.hold_time == 5.0;
    # m_insane.c: the standing or the crawling sequences, by its stance.
    stands = enemy_rule("q2", "misc_insane");
    crawls = enemy_rule("q2", "misc_insane", 4);
    assert stands is not None and crawls is not None;
    assert len(stands.pains[0].frames) == 11 and len(stands.deaths[0].frames) == 17;
    assert len(crawls.pains[0].frames) == 9 and len(crawls.deaths[0].frames) == 7;
    # Only the soldiers and the gladiator have a pain for being thrown.
    for (key, expected) in ORIGINAL_SEQUENCES.items() {
        rule = enemy_rule(key.split(":")[0], key.split(":")[1]);
        assert rule is not None;
        airborne = [sequence.name for sequence in rule.pains if sequence.airborne];
        if key == "q2:monster_soldier_light" {
            assert airborne == ["pain4"];
        } elif key == "q2:monster_gladiator" {
            assert airborne == ["pain_air"];
        } else {
            assert not airborne , key;
        }
    }
}

test "pain sequences are drawn by damage where the originals do" {
    # chick_pain, gunner_pain, tank_pain, supertank_pain: damage brackets.
    for row in [
        ("monster_chick", 10, "pain1"), ("monster_chick", 11, "pain2"), ("monster_chick", 25, "pain2"),
        ("monster_chick", 26, "pain3"), ("monster_gunner", 10, "pain3"), ("monster_gunner", 25, "pain2"),
        ("monster_gunner", 26, "pain1"), ("monster_tank", 31, "pain2"), ("monster_tank", 60, "pain2"),
        ("monster_tank", 61, "pain3"), ("monster_supertank", 26, "pain3"), ("monster_boss2", 30, "pain_heavy"),
        ("monster_jorg", 51, "pain2"), ("monster_jorg", 100, "pain2"), ("monster_makron", 41, "pain5"),
        ("monster_makron", 110, "pain5"), ("monster_hover", 26, "pain1")
    ] {
        for seed in range(6) {
            assert pain_drawn("q2", row[0], row[1], seed) == row[2] , row[0] + " " + str(row[1]);
        }
    }
    # tank_pain ignores 10 damage or less; up to 30 it flinches one time in five.
    assert pain_drawn("q2", "monster_tank", 10, 1) == "";
    light = tally([pain_drawn("q2", "monster_tank", 30, seed) for seed in range(300)]);
    assert sorted(light.keys()) == ["", "pain1"] and light["pain1"] > 30 and light["pain1"] < 90;
    # supertank_pain and makron_pain shrug off a fifth of hits up to 25, jorg_pain
    # six in ten up to 40.
    for row in [("monster_supertank", 10, "pain1", 200, 270), ("monster_supertank", 25, "pain2", 200, 270),
        ("monster_makron", 25, "pain4", 200, 270), ("monster_jorg", 40, "pain1", 80, 160)] {
        counts = tally([pain_drawn("q2", row[0], row[1], seed) for seed in range(300)]);
        assert sorted(counts.keys()) == ["", row[2]] , row[0];
        assert counts[row[2]] > row[3] and counts[row[2]] < row[4] , row[0] + " " + str(counts[row[2]]);
    }
    # jorg_pain: pain3 three times in ten past 100 damage, and the wait is
    # spent either way. makron_pain: pain6 from 111 to 150, nothing above.
    heavy = tally([pain_drawn("q2", "monster_jorg", 101, seed) for seed in range(300)]);
    assert sorted(heavy.keys()) == ["", "pain3"] and heavy["pain3"] > 55 and heavy["pain3"] < 125;
    spent = sequenced("q2", "monster_jorg", 2);
    damage_opponent(spent, 500);
    assert spent.pain_cooldown == 3.0;
    popped = tally([pain_drawn("q2", "monster_makron", 150, seed) for seed in range(300)]);
    assert popped["pain6"] > 160 and popped["pain6"] < 225;
    assert tally([pain_drawn("q2", "monster_makron", 151, seed) for seed in range(50)]) == {"": 50};
    # berserk_pain: pain1 under 20 damage, either from there up.
    assert tally([pain_drawn("q2", "monster_berserk", 19, seed) for seed in range(50)]) == {"pain1": 50};
    either = tally([pain_drawn("q2", "monster_berserk", 20, seed) for seed in range(300)]);
    assert either["pain1"] > 110 and either["pain2"] > 110;
    # hover_pain: pain3 or pain2 at even odds up to 25 damage.
    small = tally([pain_drawn("q2", "monster_hover", 25, seed) for seed in range(300)]);
    assert sorted(small.keys()) == ["pain2", "pain3"] and small["pain2"] > 110 and small["pain3"] > 110;
    # tank_pain, supertank_pain: on Hard, none while the rockets fire.
    for skill in [1, 2] {
        tank = sequenced("q2", "monster_tank", 1, skill);
        ensure_profiles(tank);
        tank.attack_profile = [i for i in range(len(tank.profiles)) if tank.profiles[i].name == "rockets"][0];
        tank.attack_clock = 0.5;
        damage_opponent(tank, 100);
        assert (tank.pain_wait > 0.0) == (skill == 1);
    }
}

test "pain sequences are drawn at the originals' odds with their own waits and sounds" {
    # army_pain: 0.2 pain (pain_finished 0.6), 0.4 painb and 0.4 painc (1.1).
    counts: dict[str, int] = {};
    for seed in range(500) {
        grunt = sequenced("q1", "monster_army", seed);
        damage_opponent(grunt, 5);
        name = grunt.rule.pains[grunt.pain_variant - 1].name;
        counts[name] = counts.get(name, 0) + 1;
        assert grunt.pain_cooldown == (0.6 if name == "pain" else 1.1);
        assert abs(grunt.pain_wait - {"pain": 0.6, "painb": 1.4, "painc": 1.3}[name]) < 0.0001;
        assert heard(grunt, "sound/soldier/pain1.wav") == (1 if name == "pain" else 0);
        assert heard(grunt, "sound/soldier/pain2.wav") == (0 if name == "pain" else 1);
    }
    assert counts["pain"] > 70 and counts["pain"] < 130;
    assert counts["painb"] > 160 and counts["painb"] < 240;
    assert counts["painc"] > 160 and counts["painc"] < 240;
    # knight_pain: painb 15 times in 100. ogre_pain: paind and paine a quarter
    # between them, with two seconds' pain_finished.
    knights = tally([pain_drawn("q1", "monster_knight", 5, seed) for seed in range(500)]);
    assert knights["painb"] > 45 and knights["painb"] < 110;
    long_pains = 0;
    for seed in range(400) {
        ogre = sequenced("q1", "monster_ogre", seed);
        damage_opponent(ogre, 5);
        name = ogre.rule.pains[ogre.pain_variant - 1].name;
        assert ogre.pain_cooldown == (2.0 if name in ["paind", "paine"] else 1.0);
        long_pains += 1 if name in ["paind", "paine"] else 0;
    }
    assert long_pains > 65 and long_pains < 135;
    # enf_pain: one random() picks sequence and sound, so paina and painb are
    # heard with pain1, paind with pain2 and painc with either.
    both = 0;
    for seed in range(400) {
        guard = sequenced("q1", "monster_enforcer", seed);
        damage_opponent(guard, 5);
        name = guard.rule.pains[guard.pain_variant - 1].name;
        first = heard(guard, "sound/enforcer/pain1.wav");
        assert first + heard(guard, "sound/enforcer/pain2.wav") == 1;
        if name in ["paina", "painb"] {
            assert first == 1;
        } elif name == "paind" {
            assert first == 0 and guard.pain_cooldown == 2.0;
        } else {
            both += first;
        }
    }
    assert both > 15 and both < 70;
    # dog_pain and fish_pain have no pain_finished: every hit starts the pain again.
    dog = sequenced("q1", "monster_dog");
    damage_opponent(dog, 2);
    dog.pain_wait = 0.1;
    damage_opponent(dog, 2);
    assert dog.pain_wait > 0.5 and dog.pain_cooldown == 0.0;
    # floater_pain: pain1 one time in three. flipper_pain, infantry_pain,
    # medic_pain: even odds, each with its sound.
    floats = tally([pain_drawn("q2", "monster_floater", 5, seed) for seed in range(300)]);
    assert floats["pain1"] > 65 and floats["pain1"] < 135 and floats["pain2"] > 165;
    for seed in range(40) {
        guard = sequenced("q2", "monster_infantry", seed);
        damage_opponent(guard, 5);
        assert heard(guard, "sound/infantry/infpain" + str(guard.pain_variant) + ".wav") == 1;
        assert heard(guard, "sound/infantry/infpain" + str(3 - guard.pain_variant) + ".wav") == 0;
    }
    # boss2_pain: the light pain's sound changes at 10 damage.
    for row in [(9, "sound/bosshovr/bhvpain3.wav"), (10, "sound/bosshovr/bhvpain1.wav"),
        (29, "sound/bosshovr/bhvpain1.wav"), (30, "sound/bosshovr/bhvpain2.wav")] {
        hornet = sequenced("q2", "monster_boss2");
        damage_opponent(hornet, row[0]);
        assert heard(hornet, row[1]) == 1 , str(row[0]);
        assert hornet.rule.pains[hornet.pain_variant - 1].name == ("pain_heavy" if row[0] >= 30 else "pain_light");
    }
}

test "who cries out and who flinches follows each pain function" {
    # On Nightmare a Q2 monster has no pain frames. Those whose sound comes
    # before that test still cry; the rest are silent. boss2_pain has no test.
    soldier = sequenced("q2", "monster_soldier", 1, 3);
    damage_opponent(soldier, 5);
    assert soldier.pain_wait == 0.0 and heard(soldier, "sound/soldier/solpain1.wav") == 1;
    # T_Damage: every hit on Nightmare puts the next pain five seconds off.
    assert soldier.pain_cooldown == 5.0;
    guard = sequenced("q2", "monster_infantry", 1, 3);
    damage_opponent(guard, 5);
    assert guard.pain_wait == 0.0;
    assert heard(guard, "sound/infantry/infpain1.wav") + heard(guard, "sound/infantry/infpain2.wav") == 0;
    hornet = sequenced("q2", "monster_boss2", 1, 3);
    damage_opponent(hornet, 50);
    assert hornet.pain_wait > 0.0 and heard(hornet, "sound/bosshovr/bhvpain2.wav") == 1;
    # g_combat.c T_Damage: a ducked monster's pain function is not called.
    ducked = sequenced("q2", "monster_infantry");
    ducked.duck_animation = [0, 1, 2, 3, 4];
    ducked.duck_wait = 1.3;
    damage_opponent(ducked, 5);
    assert ducked.pain_wait == 0.0 and ducked.duck_wait == 1.3 and ducked.health == 95;
    # Wiz_Pain and sham_pain cry on every hit, flinch or not.
    flinched = 0;
    for seed in range(60) {
        scrag = sequenced("q1", "monster_wizard", seed);
        damage_opponent(scrag, 20);
        assert heard(scrag, "sound/wizard/wpain.wav") == 1;
        flinched += 1 if scrag.pain_wait > 0.0 else 0;
        shambler = sequenced("q1", "monster_shambler", seed);
        damage_opponent(shambler, 20);
        assert heard(shambler, "sound/shambler/shurt2.wav") == 1;
    }
    assert flinched > 5 and flinched < 35;
    # hknight_pain and demon1_pain cry when pain is due, before the flinch
    # roll. A Hell Knight left alone for more than 5 s flinches without it.
    stoic = 0;
    for seed in range(60) {
        rested = sequenced("q1", "monster_hell_knight", seed);
        damage_opponent(rested, 1);
        assert rested.pain_wait > 0.0;
        knight = sequenced("q1", "monster_hell_knight", seed);
        knight.pain_rested = 4.0;
        damage_opponent(knight, 10);
        assert heard(knight, "sound/hknight/pain1.wav") == 1;
        stoic += 1 if knight.pain_wait == 0.0 else 0;
        if knight.pain_wait > 0.0 {
            # Not again until pain_finished.
            damage_opponent(knight, 10);
            assert heard(knight, "sound/hknight/pain1.wav") == 1;
        }
    }
    assert stoic > 20 and stoic < 55;
    # A turret's driver never flinches.
    driver = sequenced("q2", "turret_driver");
    damage_opponent(driver, 20);
    assert driver.pain_wait == 0.0;
}

test "pain frames stagger a monster along its facing without leaving its ground" {
    open_floor = strip(-400.0, 400.0);
    # soldier_move_pain2: 13 back on the first frame by MODEL_SCALE 1.2,
    # ending 1 back in all.
    soldier = sequenced("q2", "monster_soldier");
    soldier.pain_variant = 2;
    soldier.pain_wait = pain_length(soldier);
    assert abs(soldier.pain_wait - 0.7) < 0.0001;
    assert abs(stagger(soldier, open_floor, 0.1) + 13.0 * 1.2) < 0.01;
    assert abs(stagger(soldier, open_floor) + 1.0 * 1.2) < 0.01;
    # army_painb: ai_painforward 13 and 9, then ai_pain 2.
    grunt = sequenced("q1", "monster_army");
    grunt.pain_variant = 2;
    grunt.pain_wait = pain_length(grunt);
    assert abs(stagger(grunt, open_floor, 0.3) - 22.0) < 0.01;
    assert abs(stagger(grunt, open_floor) - 20.0) < 0.01;
    # The stride follows the facing.
    turned = sequenced("q1", "monster_dog");
    turned.yaw = 1.5707963267948966;
    turned.pain_variant = 2;
    turned.pain_wait = pain_length(turned);
    stagger(turned, open_floor);
    assert abs(turned.pos.y + 44.0) < 0.01 and abs(turned.pos.x) < 0.01;
    # mutant_move_pain2 throws it 24 back in its first frame. With the
    # floor ending, or a wall standing, 18 behind it, it takes the half of
    # that stride that keeps it on the ground and out of the wall and no
    # more (a stride is taken whole or not at all).
    for obstacle in ["ledge", "wall"] {
        ground = strip(-18.0 if obstacle == "ledge" else -400.0, 400.0);
        if obstacle == "wall" {
            ground.add_box(
                Vec3(x=-30.0, y=-200.0, z=0.0), Vec3(x=-18.0, y=200.0, z=200.0), Vec3(), Vec3(), Vec3()
            );
        }
        mutant = sequenced("q2", "monster_mutant");
        mutant.pain_variant = 2;
        mutant.pain_wait = pain_length(mutant);
        lowest = 0.0;
        while mutant.pain_wait > 0.000001 {
            pain_stagger(mutant, ground, 0.05);
            mutant.pain_wait = max(0.0, mutant.pain_wait - 0.05);
            lowest = min(lowest, mutant.pos.x);
            assert abs(mutant.pos.z - 22.01) < 0.5;
        }
        assert abs(lowest + 12.0) < 0.01 , obstacle + " " + str(lowest);
    }
    # A monster in the air does not stride.
    falling = sequenced("q2", "monster_soldier");
    falling.grounded = False;
    falling.pain_variant = 2;
    falling.pain_wait = pain_length(falling);
    assert stagger(falling, open_floor) == 0.0;
    # fish_pain backs a swimming fish away 6 a frame (SV_movestep's swim
    # move: the whole step or none); out of the water it stays put.
    for depth in [3, 0] {
        fish = sequenced("q1", "monster_fish");
        fish.grounded = False;
        fish.water_depth = depth;
        fish.pain_variant = 1;
        fish.pain_wait = pain_length(fish);
        assert abs(stagger(fish, CollisionMap()) - (-48.0 if depth == 3 else 0.0)) < 0.01;
    }
    # zombie_paine: the knockdown slides back before it lies still, and
    # shuffles forward as it gets up after the hold.
    zombie = sequenced("q1", "monster_zombie");
    damage_opponent(zombie, 30);
    assert zombie.pain_down and zombie.pain_wait == 8.0;
    assert abs(stagger(zombie, open_floor, 1.0) + 23.0) < 0.01;
    assert abs(stagger(zombie, open_floor, 5.0) + 23.0) < 0.01;
    assert abs(stagger(zombie, open_floor) + 15.0) < 0.01;
    # The combat tick drives it.
    world = World();
    victim = sequenced("q2", "monster_infantry");
    victim.attack_wait = 10.0;
    world +>:HasOpponent:+> victim;
    damage_opponent(victim, 5);
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=3000.0, z=22.01), god_mode=True);
    for tick in range(6) {
        world spawn CombatTick(player=player, collision=open_floor, state=state, dt=1.0 / 60.0);
    }
    # infantry_move_pain1 and pain2 both start 3 back.
    assert abs(victim.pos.x + 3.0) < 0.05 , str(victim.pos.x);
}

test "a monster thrown into the air takes its airborne pain" {
    # soldier_pain: pain4 when velocity z is over 100, even on Nightmare.
    for skill in [1, 3] {
        soldier = sequenced("q2", "monster_soldier_light", 1, skill);
        soldier.velocity = Vec3(z=150.0);
        soldier.grounded = False;
        damage_opponent(soldier, 5);
        assert soldier.rule.pains[soldier.pain_variant - 1].name == "pain4";
        assert abs(soldier.pain_wait - 1.7) < 0.0001;
        assert heard(soldier, "sound/soldier/solpain2.wav") == 1;
    }
    slow = sequenced("q2", "monster_soldier_light");
    slow.velocity = Vec3(z=100.0);
    damage_opponent(slow, 5);
    assert slow.rule.pains[slow.pain_variant - 1].name != "pain4";
    # Thrown while it flinches on pain1-3, it changes to pain4; the cry and
    # the wait are not repeated.
    slow.pain_wait = 0.2;
    slow.velocity = Vec3(z=150.0);
    damage_opponent(slow, 5);
    assert slow.rule.pains[slow.pain_variant - 1].name == "pain4";
    assert abs(slow.pain_wait - 1.7) < 0.0001 and heard(slow, "sound/soldier/solpain2.wav") == 1;
    slow.pain_wait = 0.4;
    damage_opponent(slow, 5);
    assert abs(slow.pain_wait - 0.4) < 0.0001;
    # gladiator_pain tests Nightmare first.
    for skill in [1, 3] {
        gladiator = sequenced("q2", "monster_gladiator", 1, skill);
        gladiator.velocity = Vec3(z=150.0);
        damage_opponent(gladiator, 5);
        if skill == 3 {
            assert gladiator.pain_wait == 0.0;
        } else {
            assert gladiator.rule.pains[gladiator.pain_variant - 1].name == "pain_air";
            assert abs(gladiator.pain_wait - 0.7) < 0.0001;
        }
    }
    standing = sequenced("q2", "monster_gladiator");
    damage_opponent(standing, 5);
    assert standing.rule.pains[standing.pain_variant - 1].name == "pain";
    standing.velocity = Vec3(z=150.0);
    damage_opponent(standing, 5);
    assert standing.rule.pains[standing.pain_variant - 1].name == "pain_air";
}

test "death sequences are drawn by each die function's rule" {
    # soldier_die: death3 for a hit within 4 units of the eye (origin plus
    # viewheight 25), otherwise one of the other five.
    for row in [(3.0, True), (6.5, True), (-0.5, True), (7.5, False), (-20.0, False)] {
        soldier = sequenced("q2", "monster_soldier_light");
        soldier.struck = Vec3(z=soldier.pos.z + row[0]);
        damage_opponent(soldier, 25);
        name = soldier.rule.deaths[soldier.death_variant - 1].name;
        assert (name == "death3") == row[1] , str(row[0]);
        # The point is the hit's alone.
        assert soldier.struck is None;
    }
    spread = tally([death_drawn("q2", "monster_soldier", 25, seed) for seed in range(500)]);
    assert sorted(spread.keys()) == ["death1", "death2", "death4", "death5", "death6"];
    for name in spread.keys() {
        assert spread[name] > 60 and spread[name] < 140 , name;
    }
    # berserk_die: by the killing hit's damage.
    assert tally([death_drawn("q2", "monster_berserk", 50, seed) for seed in range(20)]) == {"death1": 20};
    assert tally([death_drawn("q2", "monster_berserk", 49, seed) for seed in range(20)]) == {"death2": 20};
    # infantry_die: rand() % 3; death2 has the other sound. chick_die: each its own.
    for seed in range(60) {
        guard = sequenced("q2", "monster_infantry", seed);
        damage_opponent(guard, 120);
        name = guard.rule.deaths[guard.death_variant - 1].name;
        assert heard(guard, "sound/infantry/infdeth1.wav") == (1 if name == "death2" else 0);
        assert heard(guard, "sound/infantry/infdeth2.wav") == (0 if name == "death2" else 1);
        maiden = sequenced("q2", "monster_chick", seed);
        damage_opponent(maiden, 200);
        assert heard(maiden, "sound/chick/chkdeth" + str(maiden.death_variant) + ".wav") == 1;
    }
    thirds = tally([death_drawn("q2", "monster_infantry", 10, seed) for seed in range(300)]);
    assert thirds["death1"] > 65 and thirds["death2"] > 65 and thirds["death3"] > 65;
    # Even odds: army_die, dog_die, knight_die, hknight_die, enf_die,
    # ogre_die, brain_die, mutant_die, chick_die.
    for row in [("q1", "monster_army", "die", "cdie"), ("q1", "monster_dog", "die", "dieb"),
        ("q1", "monster_knight", "die", "dieb"), ("q1", "monster_hell_knight", "die", "dieb"),
        ("q1", "monster_enforcer", "die", "fdie"), ("q1", "monster_ogre", "die", "bdie"),
        ("q2", "monster_brain", "death1", "death2"), ("q2", "monster_mutant", "death1", "death2"),
        ("q2", "monster_chick", "death1", "death2")] {
        halves = tally([death_drawn(row[0], row[1], 10, seed) for seed in range(300)]);
        assert sorted(halves.keys()) == sorted([row[2], row[3]]) , row[1];
        assert halves[row[2]] > 110 and halves[row[3]] > 110 , row[1];
    }
    # A death sound, whichever falls: the rule's where the sequence has none.
    ogre = sequenced("q1", "monster_ogre");
    damage_opponent(ogre, 220);
    assert heard(ogre, "sound/ogre/ogdth.wav") == 1;
    # A monster that gibs draws no sequence.
    burst = sequenced("q2", "monster_soldier");
    burst.gib_rule = GibRule(threshold=-30);
    damage_opponent(burst, 200);
    assert burst.gibbed and burst.death_variant == 0;
}

test "death frames carry their strides and stay on the ground" {
    floor = strip(-400.0, 400.0);
    # army_cdie backs away 29; enf_die lunges 34; ogre_bdie steps 41;
    # hknight_die lurches 46; soldier_move_death1 falls back 35 by 1.2.
    for row in [("q1", "monster_army", "cdie", -29.0), ("q1", "monster_enforcer", "die", 34.0),
        ("q1", "monster_ogre", "bdie", 41.0), ("q1", "monster_hell_knight", "die", 46.0),
        ("q2", "monster_soldier", "death1", -42.0), ("q1", "monster_army", "die", 0.0)] {
        body = sequenced(row[0], row[1]);
        body.health = 0;
        body.death_variant = 1 + [sequence.name for sequence in body.rule.deaths].index(row[2]);
        for tick in range(100) {
            death_stride(body, floor, 0.05);
            body.animation_time += 0.5;
        }
        assert abs(body.pos.x - row[3]) < 0.01 , row[1] + " " + str(body.pos.x);
    }
    # Not off a ledge: the backing grunt stops where the floor ends 12
    # behind it.
    brink = strip(-12.0, 400.0);
    body = sequenced("q1", "monster_army");
    body.health = 0;
    body.death_variant = 2;
    for tick in range(100) {
        death_stride(body, brink, 0.05);
        body.animation_time += 0.5;
    }
    assert body.pos.x >= -12.01 and body.pos.x < -8.99 and abs(body.pos.z - 22.01) < 0.01;
    # The combat tick plays the death it drew and strides it.
    world = World();
    grunt = sequenced("q1", "monster_army", 3);
    grunt.death_animations = [[10 + i for i in range(10)], [30 + i for i in range(11)]];
    grunt.death_animation = grunt.death_animations[0];
    world +>:HasOpponent:+> grunt;
    damage_opponent(grunt, 40);
    backs = grunt.death_variant == 2;
    assert grunt.death_animation == grunt.death_animations[grunt.death_variant - 1];
    state = CombatState(game="q1");
    player = Player(pos=Vec3(x=3000.0, z=22.01), god_mode=True);
    for tick in range(120) {
        world spawn CombatTick(player=player, collision=floor, state=state, dt=1.0 / 60.0);
    }
    assert grunt.visual.first == grunt.death_animation[-1];
    assert abs(grunt.pos.x - (-29.0 if backs else 0.0)) < 0.05;
}

test "a corpse keeps its box until its death ends and is then left its dead box" {
    world = World();
    soldier = sequenced("q2", "monster_soldier");
    soldier.pos = Vec3(x=200.0, z=22.0);
    soldier.gib_rule = GibRule(threshold=-30);
    soldier.death_animations = [[i for i in range(len(sequence.frames))] for sequence in soldier.rule.deaths];
    world +>:HasOpponent:+> soldier;
    damage_opponent(soldier, 35);
    assert soldier.health == 0 and not soldier.gibbed and not corpse_settled(soldier);
    # Falling, it is still hit at eye height.
    high = world spawn Aim(start=Vec3(z=22.0), finish=Vec3(x=600.0, z=22.0), height=22.0);
    assert high.target is soldier;
    soldier.animation_time = float(len(soldier.death_animation));
    assert corpse_settled(soldier);
    # soldier_dead: -16 -16 -24 to 16 16 -8.
    high = world spawn Aim(start=Vec3(z=22.0), finish=Vec3(x=600.0, z=22.0), height=22.0);
    assert high.target is None;
    low = world spawn Aim(start=Vec3(z=-16.0), finish=Vec3(x=600.0, z=-16.0), height=22.0);
    assert low.target is soldier;
    # tank_dead: -16 -16 -16 to 16 16 0 from a body 32 wide and 72 tall.
    tank_rule = enemy_rule("q2", "monster_tank");
    assert tank_rule is not None;
    assert [tank_rule.dead_width, tank_rule.dead_bottom, tank_rule.dead_top] == [16.0, -16.0, 0.0];
    for row in [("monster_chick", 16.0, 0.0, 16.0), ("monster_supertank", 60.0, 0.0, 72.0),
        ("monster_boss2", 56.0, 0.0, 80.0), ("monster_makron", 60.0, 0.0, 72.0),
        ("monster_infantry", 16.0, -24.0, -8.0)] {
        rule = enemy_rule("q2", row[0]);
        assert rule is not None;
        assert [rule.dead_width, rule.dead_bottom, rule.dead_top] == [row[1], row[2], row[3]] , row[0];
    }
}

test "a death in progress and a held attack survive a save" {
    world = World();
    level = Level(name="sequences");
    level.bsp.game = "q2";
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=3000.0, z=22.0), god_mode=True);
    soldier = sequenced("q2", "monster_soldier", 5);
    soldier.death_animations = [
        [100 * (i + 1) + j for j in range(len(soldier.rule.deaths[i].frames))]
        for i in range(len(soldier.rule.deaths))
    ];
    soldier.death_animation = soldier.death_animations[0];
    holder = sequenced("q2", "monster_infantry");
    holder.attack_wait = 10.0;
    world +>:HasOpponent:+> soldier;
    world +>:HasOpponent:+> holder;
    soldier.struck = Vec3(z=soldier.pos.z + 3.0);
    damage_opponent(soldier, 35);
    assert soldier.rule.deaths[soldier.death_variant - 1].name == "death3";
    for tick in range(63) {
        world spawn CombatTick(player=player, collision=level.collision, state=state, dt=1.0 / 60.0);
    }
    assert soldier.visual.first == soldier.death_animations[5][10];
    holder.readied = 1;
    saved = snapshot(world, level, player, state);
    assert "SEQUENCE" in [line.split()[0] for line in saved.splitlines()[3:]];
    drawn = soldier.death_variant;
    played = soldier.animation_time;
    soldier.death_variant = 0;
    soldier.death_animation = soldier.death_animations[0];
    soldier.animation_time = 0.0;
    holder.readied = -1;
    restore(world, level, player, state, saved);
    assert soldier.death_variant == drawn and abs(soldier.animation_time - played) < 0.0001;
    assert holder.pain_rested == 1000.0;
    assert soldier.death_animation == soldier.death_animations[5];
    assert soldier.visual.first == soldier.death_animations[5][10];
    assert holder.readied == 1;
    # It falls on from where it was.
    for tick in range(6) {
        world spawn CombatTick(player=player, collision=level.collision, state=state, dt=1.0 / 60.0);
    }
    assert soldier.visual.first == soldier.death_animations[5][11];
    # A save without the record leaves no death drawn and no attack held.
    plain = "\n".join([line for line in saved.splitlines() if not line.startswith("SEQUENCE")]) + "\n";
    restore(world, level, player, state, plain);
    assert soldier.death_variant == 0 and holder.readied == -1;
    assert soldier.visual.first == soldier.death_animations[0][-1];
}

"""Give a monster the named pain to play from its first frame."""
def in_pain(game: str, kind: str, name: str, seed: int = 1) -> Opponent {
    enemy = sequenced(game, kind, seed);
    enemy.pain_variant = 1 + [sequence.name for sequence in enemy.rule.pains].index(name);
    enemy.pain_wait = pain_length(enemy);
    return enemy;
}

test "pain and death frames make the sounds their frame functions do" {
    nothing = CollisionMap();
    # tank_footstep on the last frame of tank_move_pain3.
    tank = in_pain("q2", "monster_tank", "pain3");
    stagger(tank, nothing, 1.45);
    assert heard(tank, "sound/tank/step.wav") == 0;
    stagger(tank, nothing);
    assert heard(tank, "sound/tank/step.wav") == 1;
    # jorg_step_left and jorg_step_right through jorg_move_pain3.
    jorg = in_pain("q2", "monster_jorg", "pain3");
    stagger(jorg, nothing, 0.45);
    assert heard(jorg, "sound/boss3/step1.wav") == 1 and heard(jorg, "sound/boss3/step2.wav") == 1;
    stagger(jorg, nothing);
    assert heard(jorg, "sound/boss3/step1.wav") == 2 and heard(jorg, "sound/boss3/step2.wav") == 2;
    # makron_popup on pain616, then makron_taunt: voice4 and voice3 three
    # times in ten each, voice the rest.
    taunts: dict[str, int] = {};
    for seed in range(300) {
        makron = in_pain("q2", "monster_makron", "pain6", seed);
        stagger(makron, nothing, 2.25);
        assert heard(makron, "sound/makron/popup.wav") == 1;
        assert heard(makron, "sound/makron/voice.wav") + heard(makron, "sound/makron/voice3.wav") + heard(makron, "sound/makron/voice4.wav") == 0;
        stagger(makron, nothing);
        for path in ["sound/makron/voice4.wav", "sound/makron/voice3.wav", "sound/makron/voice.wav"] {
            taunts[path] = taunts.get(path, 0) + heard(makron, path);
        }
    }
    assert taunts["sound/makron/voice4.wav"] + taunts["sound/makron/voice3.wav"] + taunts["sound/makron/voice.wav"] == 300;
    assert taunts["sound/makron/voice4.wav"] > 60 and taunts["sound/makron/voice4.wav"] < 120;
    assert taunts["sound/makron/voice.wav"] > 90 and taunts["sound/makron/voice.wav"] < 150;
    # zombie_painb9's z_fall; the knockdown's on paine10, and z_idle as it
    # gets up after the five seconds on the ground.
    zombie = in_pain("q1", "monster_zombie", "painb");
    stagger(zombie, nothing, 0.75);
    assert heard(zombie, "sound/zombie/z_fall.wav") == 0;
    stagger(zombie, nothing, 0.1);
    assert heard(zombie, "sound/zombie/z_fall.wav") == 1;
    downed = sequenced("q1", "monster_zombie");
    damage_opponent(downed, 30);
    stagger(downed, nothing, 0.95);
    assert heard(downed, "sound/zombie/z_fall.wav") == 1 and heard(downed, "sound/zombie/z_idle.wav") == 0;
    stagger(downed, nothing, 5.0);
    assert heard(downed, "sound/zombie/z_idle.wav") == 0;
    stagger(downed, nothing, 0.3);
    assert heard(downed, "sound/zombie/z_fall.wav") == 1 and heard(downed, "sound/zombie/z_idle.wav") == 1;
    # tank_thud on death128, and the Makron's nine steps, makron_hit and
    # makron_brainsplorch through makron_move_death2.
    for row in [("monster_tank", "sound/tank/tnkdeth2.wav", 2.65, 0, 2.8, 1),
        ("monster_makron", "sound/makron/step1.wav", 5.75, 3, 9.5, 5)] {
        world = World();
        body = sequenced("q2", row[0]);
        world +>:HasOpponent:+> body;
        damage_opponent(body, body.rule.health + 5);
        assert body.health == 0 and body.death_variant == 1;
        state = CombatState(game="q2");
        player = Player(pos=Vec3(x=3000.0, z=22.0), god_mode=True);
        for tick in range(int(row[2] * 60.0 + 0.5)) {
            world spawn CombatTick(player=player, collision=nothing, state=state, dt=1.0 / 60.0);
        }
        assert heard(body, row[1]) == row[3] , row[0];
        for tick in range(int((row[4] - row[2]) * 60.0 + 0.5)) {
            world spawn CombatTick(player=player, collision=nothing, state=state, dt=1.0 / 60.0);
        }
        assert heard(body, row[1]) == row[5] , row[0];
        if row[0] == "monster_makron" {
            assert heard(body, "sound/makron/step2.wav") == 4;
            assert heard(body, "sound/makron/bhit.wav") == 1 and heard(body, "sound/makron/brain1.wav") == 1;
        }
    }
}

test "the fiend, the zombie and the Scrag follow their own pain and die functions" {
    # demon1_pain: none in mid-leap; otherwise pain_finished is set before
    # the flinch roll, so a hit shrugged off spends the second too.
    leaper = sequenced("q1", "monster_demon1");
    leaper.leaping = True;
    damage_opponent(leaper, 100);
    assert leaper.pain_wait == 0.0 and heard(leaper, "sound/demon/dpain1.wav") == 0;
    shrugged = 0;
    for seed in range(40) {
        fiend = sequenced("q1", "monster_demon1", seed);
        damage_opponent(fiend, 2);
        assert heard(fiend, "sound/demon/dpain1.wav") == 1 and fiend.pain_cooldown == 1.0;
        shrugged += 1 if fiend.pain_wait == 0.0 else 0;
        damage_opponent(fiend, 150);
        assert heard(fiend, "sound/demon/dpain1.wav") == 1;
    }
    assert shrugged > 30;
    # zombie_pain: under 9 damage is ignored. A quick pain sets no
    # pain_finished, so once it is over another may follow.
    zombie = sequenced("q1", "monster_zombie");
    damage_opponent(zombie, 8);
    assert zombie.pain_wait == 0.0 and zombie.health == 60;
    damage_opponent(zombie, 10);
    assert zombie.pain_wait > 0.0 and not zombie.pain_down and zombie.pain_cooldown == 0.0;
    zombie.pain_wait = 0.0;
    damage_opponent(zombie, 10);
    assert zombie.pain_wait > 0.0 and not zombie.pain_down;
    # Hit again while it flinches: the pain runs on, and for three seconds
    # after the next hit knocks it down.
    zombie.pain_wait = 0.4;
    damage_opponent(zombie, 10);
    assert abs(zombie.pain_wait - 0.4) < 0.0001 and zombie.pain_cooldown == 3.0 and not zombie.pain_down;
    zombie.pain_wait = 0.0;
    zombie.pain_cooldown = 2.0;
    damage_opponent(zombie, 10);
    assert zombie.pain_down and zombie.pain_wait == 8.0;
    # Down, it is hit by nothing more.
    damage_opponent(zombie, 30);
    assert zombie.pain_wait == 8.0;
    # wiz_death1 throws the Scrag's corpse.
    for seed in range(30) {
        scrag = sequenced("q1", "monster_wizard", seed);
        damage_opponent(scrag, 100);
        assert scrag.health == 0 and not scrag.grounded;
        assert abs(scrag.velocity.x) <= 200.0 and abs(scrag.velocity.y) <= 200.0;
        assert scrag.velocity.z >= 100.0 and scrag.velocity.z <= 200.0;
    }
}

test "a Q1 body blocks until the frame its die function clears it" {
    # army_die3, knight_die3 and their like set SOLID_NOT on the third
    # frame, demon1_die6 on the sixth, f_death21 on the last; dog_die and
    # shalrath_die before any frame.
    for row in [("monster_army", 2), ("monster_knight", 2), ("monster_hell_knight", 2),
        ("monster_enforcer", 2), ("monster_ogre", 2), ("monster_wizard", 2), ("monster_shambler", 2),
        ("monster_demon1", 5), ("monster_fish", 20), ("monster_dog", 0), ("monster_shalrath", 0)] {
        rule = enemy_rule("q1", row[0]);
        assert rule is not None;
        for sequence in rule.deaths {
            assert sequence.unsolid_frame == row[1] , row[0] + ":" + sequence.name;
        }
    }
    grunt = sequenced("q1", "monster_army");
    grunt.visual.visible = True;
    beside = grunt.pos.sub(Vec3(x=20.0, z=22.0));
    assert actor_overlap(beside, 0.0, grunt) is not None;
    damage_opponent(grunt, 40);
    grunt.visual.visible = True;
    assert grunt.health == 0 and actor_overlap(beside, 0.0, grunt) is not None;
    grunt.animation_time = 1.9;
    assert actor_overlap(beside, 0.0, grunt) is not None;
    grunt.animation_time = 2.0;
    assert actor_overlap(beside, 0.0, grunt) is None;
    dog = sequenced("q1", "monster_dog");
    dog.visual.visible = True;
    damage_opponent(dog, 40);
    dog.visual.visible = True;
    assert actor_overlap(dog.pos.sub(Vec3(x=20.0, z=22.0)), 0.0, dog) is None;
    # A Q2 body does not block once it is dying.
    soldier = sequenced("q2", "monster_soldier");
    soldier.visual.visible = True;
    damage_opponent(soldier, 35);
    soldier.visual.visible = True;
    assert actor_overlap(soldier.pos.sub(Vec3(x=20.0, z=22.0)), 0.0, soldier) is None;
    # zombie_paine10 to paine12: flat on the ground the zombie is passable,
    # and it gets up only if nothing stands where it lies.
    nothing = CollisionMap();
    zombie = sequenced("q1", "monster_zombie");
    zombie.visual.visible = True;
    over = zombie.pos.sub(Vec3(x=20.0, z=22.0));
    damage_opponent(zombie, 30);
    stagger(zombie, nothing, 0.85);
    assert actor_overlap(over, 0.0, zombie) is not None;
    stagger(zombie, nothing, 0.1);
    assert actor_overlap(over, 0.0, zombie) is None;
    stagger(zombie, nothing, 5.0);
    assert actor_overlap(over, 0.0, zombie) is None;
    blocker = Player(pos=zombie.pos.add(Vec3(x=10.0)));
    for tick in range(4) {
        pain_stagger(zombie, nothing, 0.05, blocker);
        zombie.pain_wait = max(0.0, zombie.pain_wait - 0.05);
    }
    # Blocked: back on the ground for another five seconds.
    assert zombie.pain_wait > 6.5 and actor_overlap(over, 0.0, zombie) is None;
    assert heard(zombie, "sound/zombie/z_idle.wav") == 0;
    stagger(zombie, nothing, 5.3);
    assert heard(zombie, "sound/zombie/z_idle.wav") == 1;
    assert actor_overlap(over, 0.0, zombie) is not None;
}

test "an insane marine cries with the player's voice for its health" {
    # insane_pain: pain25, pain50, pain75 or pain100 by its health, either
    # of two, and it cries on Nightmare though it does not flinch.
    for row in [(100, 10, 100), (100, 30, 75), (60, 15, 50), (40, 20, 25), (100, 26, 75)] {
        for skill in [1, 3] {
            cried: dict[str, int] = {};
            for seed in range(30) {
                marine = sequenced("q2", "misc_insane", seed, skill);
                marine.health = row[0];
                damage_opponent(marine, row[1]);
                assert (marine.pain_wait > 0.0) == (skill == 1);
                for voice in [1, 2] {
                    path = "sound/player/male/pain" + str(row[2]) + "_" + str(voice) + ".wav";
                    cried[path] = cried.get(path, 0) + heard(marine, path);
                }
                assert len(marine.rule.pains[marine.pain_variant - 1].frames) == 11 or skill == 3;
            }
            counts = [count for count in cried.values()];
            assert counts[0] + counts[1] == 30 and counts[0] > 5 and counts[1] > 5 , str(row[2]);
        }
    }
    # Crawling it has its own frames; crucified it struggles and screams.
    crawler = enemy_rule("q2", "misc_insane", 4);
    hung = enemy_rule("q2", "misc_insane", 8);
    assert crawler is not None and hung is not None;
    assert len(crawler.pains) == 8 and len(crawler.pains[0].frames) == 9;
    assert hung.pains[0].frames == ["cross" + str(i) for i in range(16, 31)];
    assert len(hung.pains[0].events[0].sounds) == 8 and hung.pains[0].events[0].frame == 0;
    # insane_die: one of the player's four death cries.
    deaths: dict[str, int] = {};
    for seed in range(200) {
        marine = sequenced("q2", "misc_insane", seed);
        damage_opponent(marine, 120);
        for cry in range(1, 5) {
            path = "sound/player/male/death" + str(cry) + ".wav";
            deaths[path] = deaths.get(path, 0) + heard(marine, path);
        }
    }
    assert len(deaths) == 4 and sum([count for count in deaths.values()]) == 200;
    for count in deaths.values() {
        assert count > 25;
    }
}

test "Jorg shrugs off a little more pain while it attacks" {
    # jorg_pain: random() <= 0.005 through attak101-108 and attak201-208,
    # <= 0.00005 through attak109-114, and nothing extra after.
    rule = enemy_rule("q2", "monster_jorg");
    assert rule is not None;
    for profile in rule.attacks {
        if profile.name == "chainguns" {
            assert profile.pain_shrugs == [0.005] * 8 + [0.00005] * 6;
        } else {
            assert profile.name == "bfg" and profile.pain_shrugs == [0.005] * 8;
        }
    }
    # The shrug is taken frame by frame of the attack being played.
    for row in [(0.35, True), (0.95, False)] {
        jorg = sequenced("q2", "monster_jorg");
        ensure_profiles(jorg);
        sure = [profile for profile in jorg.profiles if profile.name == "bfg"][0];
        sure.pain_shrugs = [1.0] * 8;
        jorg.attack_profile = jorg.profiles.index(sure);
        jorg.attack_clock = row[0];
        damage_opponent(jorg, 80);
        assert (jorg.pain_wait == 0.0) == row[1];
    }
}
