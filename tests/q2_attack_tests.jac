import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    attack_pose_time,
    attack_duration,
    attack_charge,
    advance_attack,
    begin_attack,
    choose_attack,
    ensure_profiles,
    crouching,
    damage_opponent,
    muzzle_origin,
    muzzle_flash_age,
    launch_missile
}
import from engine.world.speakers { Speaker }
import from engine.world.opponent_rule { AttackProfile, rule_profiles }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3, forward_from, right_from }

"""Start one of a monster's attack sequences by name, as its decision would."""
def start_sequence(enemy: Opponent, name: str, target: Vec3) -> AttackProfile {
    ensure_profiles(enemy);
    for i in range(len(enemy.profiles)) {
        if enemy.profiles[i].name == name {
            begin_attack(enemy, i, target);
            return enemy.profiles[i];
        }
    }
    raise ValueError("No attack sequence " + name);
}

"""Run a started sequence on for `seconds` in 20 Hz slices."""
def run_sequence(world: World, enemy: Opponent, player: Player, seconds: float) {
    collision = CollisionMap();
    for i in range(int(seconds * 20.0 + 0.5)) {
        advance_attack(world, enemy, player, collision, 0.05);
    }
}

"""A soldier of `kind` with a speaker for its cocking sound."""
def refire_soldier(kind: str, skill: int, seed: int = 1) -> Opponent {
    rule = enemy_rule("q2", kind);
    assert rule is not None;
    cock = Speaker(path="sound/infantry/infatck3.wav", origin=Vec3());
    return Opponent(
        rule=rule, game="q2", skill=skill, shot_random=seed, speakers=[cock],
        speaker_paths=[cock.path]
    );
}

test "Q2 light soldiers wind up before firing a spread blaster bolt" {
    rule = enemy_rule("q2", "monster_soldier_light");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0));
    state = CombatState();
    collision = CollisionMap();
    enemy = Opponent(rule=rule, attack_wait=10.0);
    world +>:HasOpponent:+> enemy;
    start_sequence(enemy, "attack1", player.pos);
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert not [world->:HasProjectile:->];
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    bolts = [world->:HasProjectile:->][?:Projectile];
    assert len(bolts) == 1 and bolts[0].damage == 5 and bolts[0].hostile;
    assert abs(bolts[0].velocity.length() - 600.0) < 0.001;
    assert abs(bolts[0].velocity.y) > 0.001;
    assert player.health == 100;
}

test "Q2 shotgun soldiers use twelve pellets with distinct horizontal and vertical spread" {
    rule = enemy_rule("q2", "monster_soldier");
    assert rule is not None;
    for shot in rule.attacks {
        assert shot.pellets == 12 and shot.damage == 2 and shot.missile_speed == 0.0;
        assert shot.spread == 2.0 * shot.vertical_spread;
    }
    world = World();
    player = Player(pos=Vec3(x=40.0));
    state = CombatState();
    enemy = Opponent(rule=rule, attack_wait=10.0);
    world +>:HasOpponent:+> enemy;
    start_sequence(enemy, "attack1", player.pos);
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.2
    );
    assert player.health >= 76 and player.health < 100;
    assert not [world->:HasProjectile:->];
}

test "Q2 machinegun burst holds its pose and survives save restore without duplicate shots" {
    rule = enemy_rule("q2", "monster_soldier_ss");
    assert rule is not None;
    world = World();
    level = Level(name="burst");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=200.0), god_mode=True);
    state = CombatState();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.2
    );
    assert enemy.attack_event == 1
        and enemy.burst_count >= 4
        and enemy.burst_count <= 11;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert enemy.attack_event == 2 and abs(attack_pose_time(enemy) - 2.0) < 0.00001;
    saved = snapshot(world, level, player, state);
    count = enemy.burst_count;
    stream = enemy.shot_random;
    enemy.burst_count = 1;
    enemy.shot_random = 1;
    restore(world, level, player, state, saved);
    assert enemy.burst_count == count
        and enemy.shot_random == stream
        and enemy.attack_event == 2;
    enemy.decision_wait = 10.0;
    for i in range(30) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=state, dt=0.1
        );
    }
    assert enemy.attack_event == count and enemy.attack_clock < 0.0;
}

test "infantry gun has a longer windup and damage interrupts held bursts" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0), god_mode=True);
    state = CombatState();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.9
    );
    assert enemy.attack_event == 0;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.1
    );
    assert enemy.attack_event == 1
        and enemy.burst_count >= 4
        and enemy.burst_count <= 19;
    assert abs(attack_pose_time(enemy) - 10.0) < 0.00001;
    damage_opponent(enemy, 1);
    assert enemy.attack_clock < 0.0;
    enemy.decision_wait = 10.0;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.4
    );
    assert enemy.attack_event == 1;
}

"""Where a monster's `index`th shot should leave, from its origin."""
def expected_muzzle(enemy: Opponent, offset: Vec3) -> Vec3 {
    origin = enemy.pos.sub(Vec3(z=enemy.eye_height));
    return origin.add(forward_from(enemy.yaw, 0.0).scale(offset.x))
        .add(right_from(enemy.yaw).scale(offset.y))
        .add(Vec3(z=offset.z));
}

test "monster shots leave their muzzles and light a flash there" {
    rule = enemy_rule("q2", "monster_soldier_light");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0));
    state = CombatState();
    collision = CollisionMap();
    enemy = Opponent(rule=rule, attack_wait=10.0);
    world +>:HasOpponent:+> enemy;
    start_sequence(enemy, "attack1", player.pos);
    for step in range(2) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    bolts = [world->:HasProjectile:->][?:Projectile];
    assert len(bolts) == 1;
    # MZ2_SOLDIER_BLASTER_1: 10.6, 7.7, 7.8 scaled by 1.2.
    muzzle = expected_muzzle(enemy, Vec3(x=12.72, y=9.24, z=9.36));
    assert bolts[0].pos.sub(muzzle).length() < 0.01;
    assert muzzle_flash_age(enemy) >= 0.0;
    assert enemy.flash_origin.sub(muzzle).length() < 0.01;
    assert enemy.flash_color.x == 1.0 and enemy.flash_color.y == 1.0 and enemy.flash_color.z == 0.0;
    # The flash is gone a tenth of a second later.
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert muzzle_flash_age(enemy) < 0.0;
}

test "a volley fires each rocket from its own tube and walls stop muzzles short" {
    rule = enemy_rule("q2", "monster_boss2");
    assert rule is not None;
    enemy = Opponent(rule=rule, pos=Vec3(z=22.0), yaw=0.5);
    profile = [profile for profile in rule_profiles(rule) if profile.name == "rockets"][0];
    assert profile.volley and len(profile.muzzles) == 4;
    world = World();
    player = Player(pos=Vec3(x=400.0, z=22.0));
    for shot in range(4) {
        launch_missile(
            world, enemy, Vec3(x=1.0), profile, player, muzzle_origin(enemy, profile, shot)
        );
    }
    rockets = [world->:HasProjectile:->][?:Projectile];
    assert len(rockets) == 4;
    for shot in range(4) {
        assert rockets[shot].pos.sub(expected_muzzle(enemy, profile.muzzles[shot])).length() < 0.01;
    }
    # Q1 enforcer_fire: a wall between the origin and the muzzle holds the shot.
    enforcer = enemy_rule("q1", "monster_enforcer");
    assert enforcer is not None;
    guard = Opponent(rule=enforcer, pos=Vec3(z=22.0));
    laser = rule_profiles(enforcer)[0];
    open_start = muzzle_origin(guard, laser, 0, CollisionMap());
    assert open_start.sub(expected_muzzle(guard, Vec3(x=30.0, y=8.5, z=16.0))).length() < 0.01;
    walled = CollisionMap();
    walled.add_box(Vec3(x=20.0, y=-100.0, z=-100.0), Vec3(x=24.0, y=100.0, z=100.0), Vec3(), Vec3(), Vec3());
    blocked = muzzle_origin(guard, laser, 0, walled);
    assert blocked.x < 20.0 and blocked.x > 0.0;
    # Without muzzles a shot still leaves the eye.
    assert muzzle_origin(guard, AttackProfile(), 0, walled).sub(guard.pos).length() < 0.001;
}

test "soldier attack tables follow m_soldier.c" {
    for kind in ["monster_soldier_light", "monster_soldier", "monster_soldier_ss"] {
        rule = enemy_rule("q2", kind);
        assert rule is not None;
        light = kind == "monster_soldier_light";
        table: dict[str, AttackProfile] = {};
        for profile in rule_profiles(rule) {
            table[profile.name] = profile;
            # Frames play at 10 Hz for the whole sequence.
            assert len(profile.frames) == int(profile.duration * 10.0 + 0.5);
        }
        if kind == "monster_soldier_ss" {
            # soldier_attack: skin 4 and up only has attack4.
            assert sorted(table.keys()) == ["attack3", "attack4", "attack6"];
            burst = table["attack4"];
            assert burst.frames == ["attak" + str(i) for i in range(401, 407)];
            assert burst.times == [0.2] and burst.hold_frame == 2;
            assert burst.burst_min == 4 and burst.burst_max == 11;
            # The burst resets soldier_attack3_refire's pause: no loop.
            assert table["attack3"].frames == ["attak30" + str(i) for i in range(1, 10)];
            assert table["attack3"].hold_frame == 2 and table["attack6"].hold_frame == 3;
        } else {
            assert sorted(table.keys()) == ["attack1", "attack2", "attack3", "attack6"];
            first = table["attack1"];
            second = table["attack2"];
            # attak101-112 with soldier_fire1 on attak103; attak201-218 with
            # soldier_fire2 on attak205.
            assert first.frames == ["attak" + str(i) for i in range(101, 113)];
            assert second.frames == ["attak" + str(i) for i in range(201, 219)];
            assert first.times == [0.2] and second.times == [0.4];
            assert first.weight == second.weight;
            # MZ2_SOLDIER_BLASTER_1/_2 and _SHOTGUN_1/_2, scaled by 1.2.
            assert first.muzzles[0].sub(Vec3(x=12.72, y=9.24, z=9.36)).length() < 0.001;
            assert second.muzzles[0].sub(Vec3(x=25.32, y=4.32, z=22.8)).length() < 0.001;
            # soldier_cock on attak108 and attak213.
            assert first.extra_sound == "sound/infantry/infatck3.wav";
            assert first.extra_sound_times == [0.7] and second.extra_sound_times == [1.2];
            for attack in [first, second] {
                assert attack.repeat_near == 80.0 and attack.repeat_skill == 3;
                assert attack.repeat_chance == 0.5 and attack.repeat_unseen;
            }
            # refire1 (blaster) on attak106/attak208 goes back to attak102/
            # attak204 or on to attak110/attak216; refire2 (shotgun) on
            # attak109/attak215 goes back or plays on.
            assert first.repeat_start == 0.1 and second.repeat_start == 0.3;
            if light {
                assert first.repeat_end == 0.6 and first.repeat_skip == 0.9;
                assert second.repeat_end == 0.8 and second.repeat_skip == 1.5;
            } else {
                assert first.repeat_end == 0.9 and first.repeat_skip < 0.0;
                assert second.repeat_end == 1.5 and second.repeat_skip < 0.0;
            }
            # attak301-309 going back once from attak306 to attak303.
            assert len(table["attack3"].frames) == 13 and table["attack3"].times == [0.2, 0.6];
        }
        assert table["attack3"].dodge_only and table["attack3"].crouch_start == 0.2;
        # soldier_move_attack6: runs01-14, soldier_fire8 on runs04.
        charge = table["attack6"];
        assert charge.frames == ["runs" + ("0" if i < 10 else "") + str(i) for i in range(1, 15)];
        assert charge.steps == [10.0, 4.0, 12.0, 11.0, 13.0, 18.0, 15.0, 14.0, 11.0, 8.0, 11.0, 12.0, 12.0, 17.0];
        assert charge.times == [0.3] and charge.trigger == "sight" and charge.min_skill == 1;
        assert charge.trigger_chance == 0.5 and charge.min_range == 500.0;
        assert charge.repeat_start == 0.2 and charge.repeat_end == charge.duration;
        assert charge.repeat_skill == 3 and charge.repeat_from == 500.0;
        # MZ2_SOLDIER_BLASTER_8, or _SHOTGUN_8 / _MACHINEGUN_8.
        muzzle = Vec3(x=37.8, y=11.52, z=12.12) if light else Vec3(x=41.4, y=11.52, z=7.32);
        assert charge.muzzles[0].sub(muzzle).length() < 0.001;
    }
}

test "soldier_attack picks attack1 or attack2 at even odds" {
    for kind in ["monster_soldier_light", "monster_soldier", "monster_soldier_ss"] {
        rule = enemy_rule("q2", kind);
        assert rule is not None;
        counts: dict[str, int] = {};
        for seed in range(400) {
            enemy = Opponent(rule=rule, game="q2", shot_random=1 + seed * 7919);
            name = enemy.profiles[choose_attack(enemy, 300.0)].name
                if choose_attack(enemy, 300.0) >= 0
                else "";
            counts[name] = counts.get(name, 0) + 1;
        }
        if kind == "monster_soldier_ss" {
            assert counts == {"attack4": 400};
        } else {
            # Never the dodge's attack3 or the sighting's attack6.
            assert sorted(counts.keys()) == ["attack1", "attack2"];
            assert counts["attack1"] > 150 and counts["attack2"] > 150;
        }
    }
}

test "a blaster soldier refires up close or by skill and otherwise skips the cocking frames" {
    world = World();
    far = Player(pos=Vec3(x=300.0));
    # Past attak106 with the enemy out of RANGE_MELEE: on to attak110.
    enemy = refire_soldier("monster_soldier_light", 1);
    start_sequence(enemy, "attack1", far.pos);
    run_sequence(world, enemy, far, 0.6);
    assert abs(enemy.attack_clock - 0.9) < 0.001 and enemy.attack_event == 1;
    assert len([world->:HasProjectile:->]) == 1;
    run_sequence(world, enemy, far, 0.3);
    assert enemy.attack_clock < 0.0 and enemy.speakers[0].requests == 0;
    # In RANGE_MELEE: back to attak102, and the bolt leaves again on attak103.
    near = Player(pos=Vec3(x=60.0), god_mode=True);
    enemy = refire_soldier("monster_soldier_light", 1);
    start_sequence(enemy, "attack1", near.pos);
    run_sequence(world, enemy, near, 0.6);
    assert abs(enemy.attack_clock - 0.1) < 0.001 and enemy.attack_event == 0;
    run_sequence(world, enemy, near, 0.1);
    assert enemy.attack_event == 1 and len([world->:HasProjectile:->]) == 3;
    # attack2 goes back to attak204 or on to attak216.
    enemy = refire_soldier("monster_soldier_light", 1);
    start_sequence(enemy, "attack2", near.pos);
    run_sequence(world, enemy, near, 0.8);
    assert abs(enemy.attack_clock - 0.3) < 0.001;
    enemy = refire_soldier("monster_soldier_light", 1);
    start_sequence(enemy, "attack2", far.pos);
    run_sequence(world, enemy, far, 0.8);
    assert abs(enemy.attack_clock - 1.5) < 0.001;
    # Skill 3 goes back half the time at any range, without needing sight.
    repeats = 0;
    for seed in range(200) {
        enemy = refire_soldier("monster_soldier_light", 3, 1 + seed * 7919);
        start_sequence(enemy, "attack1", far.pos);
        run_sequence(world, enemy, far, 0.6);
        if abs(enemy.attack_clock - 0.1) < 0.001 {
            repeats += 1;
        } else {
            assert abs(enemy.attack_clock - 0.9) < 0.001;
        }
    }
    assert repeats > 60 and repeats < 140;
    # A dead enemy: the frames play on, through soldier_cock on attak108.
    dead = Player(pos=Vec3(x=60.0), health=0);
    enemy = refire_soldier("monster_soldier_light", 3);
    start_sequence(enemy, "attack1", dead.pos);
    run_sequence(world, enemy, dead, 0.75);
    assert abs(enemy.attack_clock - 0.75) < 0.001 and enemy.speakers[0].requests == 1;
}

test "a shotgun soldier cocks its gun and refires after it" {
    world = World();
    far = Player(pos=Vec3(x=300.0), god_mode=True);
    near = Player(pos=Vec3(x=60.0), god_mode=True);
    # Out of RANGE_MELEE below skill 3 the twelve frames play straight through.
    enemy = refire_soldier("monster_soldier", 2);
    start_sequence(enemy, "attack1", far.pos);
    run_sequence(world, enemy, far, 0.65);
    assert abs(enemy.attack_clock - 0.65) < 0.001 and enemy.speakers[0].requests == 0;
    run_sequence(world, enemy, far, 0.5);
    assert abs(enemy.attack_clock - 1.15) < 0.001 and enemy.speakers[0].requests == 1;
    run_sequence(world, enemy, far, 0.05);
    assert enemy.attack_clock < 0.0 and enemy.attack_event == 1;
    # Up close it goes back from attak109 to attak102, having cocked.
    enemy = refire_soldier("monster_soldier", 2);
    start_sequence(enemy, "attack1", near.pos);
    run_sequence(world, enemy, near, 0.9);
    assert abs(enemy.attack_clock - 0.1) < 0.001 and enemy.speakers[0].requests == 1;
    run_sequence(world, enemy, near, 0.1);
    assert enemy.attack_event == 1;
    # attack2: soldier_cock on attak213, back from attak215 to attak204.
    enemy = refire_soldier("monster_soldier", 2);
    start_sequence(enemy, "attack2", near.pos);
    run_sequence(world, enemy, near, 1.15);
    assert enemy.speakers[0].requests == 0;
    run_sequence(world, enemy, near, 0.35);
    assert abs(enemy.attack_clock - 0.3) < 0.001 and enemy.speakers[0].requests == 1;
    assert not [world->:HasProjectile:->];
}

test "soldiers that sight a distant enemy run and shoot half the time above Easy" {
    for trial in [(1, 600.0, True), (0, 600.0, False), (1, 300.0, False)] {
        started = 0;
        for seed in range(40) {
            rule = enemy_rule("q2", "monster_soldier_light");
            assert rule is not None;
            world = World();
            player = Player(pos=Vec3(x=trial[1]));
            enemy = Opponent(
                rule=rule, game="q2", skill=trial[0], attack_wait=10.0,
                shot_random=1 + seed * 7919
            );
            world +>:HasOpponent:+> enemy;
            world spawn CombatTick(
                player=player, collision=CollisionMap(), state=CombatState(game="q2"), dt=0.05
            );
            assert enemy.sighted;
            if enemy.attack_clock >= 0.0 {
                assert enemy.profiles[enemy.attack_profile].name == "attack6";
                started += 1;
            }
        }
        if trial[2] {
            assert started > 8 and started < 32;
        } else {
            assert started == 0;
        }
    }
}

test "the run-and-shoot strides its frames, fires on runs04 and runs on only on skill 3" {
    floor = CollisionMap();
    floor.add_box(
        Vec3(x=-100.0, y=-100.0, z=-10.0), Vec3(x=2000.0, y=100.0, z=0.0), Vec3(), Vec3(), Vec3()
    );
    player = Player(pos=Vec3(x=1500.0, z=22.01), god_mode=True);
    for kind in ["monster_soldier_light", "monster_soldier_ss"] {
        rule = enemy_rule("q2", kind);
        assert rule is not None;
        enemy = Opponent(rule=rule, game="q2", skill=1, pos=Vec3(z=22.01), grounded=True);
        charge = start_sequence(enemy, "attack6", player.pos);
        # The machine gunner holds runs04 for its burst and does not move then.
        held = float(enemy.burst_count - 1) * 0.1;
        assert (held > 0.0) == (kind == "monster_soldier_ss");
        stood = -1.0;
        for i in range(int((charge.duration + held) * 20.0 + 0.5)) {
            if abs(enemy.attack_clock - 0.3) < 0.001 {
                stood = enemy.pos.x;
            }
            if held > 0.0 and abs(enemy.attack_clock - (0.3 + held)) < 0.001 {
                assert abs(enemy.pos.x - stood) < 0.001;
            }
            attack_charge(enemy, player, floor, 0.05);
            enemy.attack_clock += 0.05;
        }
        # The fourteen ai_charge distances, by MODEL_SCALE 1.2.
        assert abs(enemy.pos.x - 168.0 * 1.2) < 0.01 , str(enemy.pos.x);
        assert abs(stood - 26.0 * 1.2) < 0.01;
    }
    # soldier_attack6_refire: back to runs03 on skill 3 with the enemy still
    # at RANGE_MID or beyond; otherwise the sequence ends.
    world = World();
    for trial in [(3, 1500.0, True), (2, 1500.0, False), (3, 400.0, False)] {
        enemy = refire_soldier("monster_soldier_light", trial[0]);
        target = Player(pos=Vec3(x=trial[1]), god_mode=True);
        start_sequence(enemy, "attack6", target.pos);
        run_sequence(world, enemy, target, 1.4);
        if not trial[2] {
            run_sequence(world, enemy, target, 0.05);
        }
        if trial[2] {
            assert abs(enemy.attack_clock - 0.2) < 0.001 and enemy.attack_event == 0;
            run_sequence(world, enemy, target, 0.1);
            assert enemy.attack_event == 1 and enemy.attack_flash > 0.0;
        } else {
            assert enemy.attack_clock < 0.0;
        }
    }
}

test "a crouched machine gunner holds attak303 for its burst and a refire survives a save" {
    rule = enemy_rule("q2", "monster_soldier_ss");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0), god_mode=True);
    enemy = Opponent(rule=rule, game="q2");
    start_sequence(enemy, "attack3", player.pos);
    held = float(enemy.burst_count - 1) * 0.1;
    run_sequence(world, enemy, player, 0.25);
    assert crouching(enemy) and enemy.attack_event == 1;
    # soldier_duck_up on attak307, the burst's hold later.
    run_sequence(world, enemy, player, 0.3 + held);
    assert crouching(enemy) and enemy.attack_event == enemy.burst_count;
    run_sequence(world, enemy, player, 0.1);
    assert not crouching(enemy) and enemy.attack_clock >= 0.0;
    # A sequence sent back by its refire resumes from the saved clock.
    level = Level(name="refire");
    level.bsp.game = "q2";
    near = Player(pos=Vec3(x=60.0), god_mode=True);
    shotgun = refire_soldier("monster_soldier", 1);
    shotgun.attack_wait = 10.0;
    scene = World();
    scene +>:HasOpponent:+> shotgun;
    start_sequence(shotgun, "attack2", near.pos);
    run_sequence(scene, shotgun, near, 1.55);
    assert abs(shotgun.attack_clock - 0.35) < 0.001 and shotgun.attack_event == 0;
    state = CombatState(game="q2");
    saved = snapshot(scene, level, near, state);
    stream = shotgun.shot_random;
    shotgun.attack_clock = -1.0;
    shotgun.attack_profile = -1;
    shotgun.shot_random = 1;
    restore(scene, level, near, state, saved);
    assert shotgun.profiles[shotgun.attack_profile].name == "attack2";
    assert abs(shotgun.attack_clock - 0.35) < 0.001 and shotgun.shot_random == stream;
    run_sequence(scene, shotgun, near, 0.1);
    assert shotgun.attack_event == 1;
}
