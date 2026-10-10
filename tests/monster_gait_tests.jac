"""Per-frame monster locomotion: Q1 ai_run/ai_walk distances and Q2 mframe_t
move tables give each frame of a monster's cycle its one step."""
import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    CombatState,
    CombatTick,
    frame_step,
    striding,
    choose_walk,
    walk_frames,
    faces_to_attack,
    facing_ideal
}
import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }

glob GAITED: dict[str, list[str]] = {
    "q1": [
        "monster_army",
        "monster_dog",
        "monster_knight",
        "monster_hell_knight",
        "monster_enforcer",
        "monster_ogre",
        "monster_ogre_marksman",
        "monster_wizard",
        "monster_demon1",
        "monster_shambler",
        "monster_zombie",
        "monster_shalrath",
        "monster_tarbaby",
        "monster_fish"
    ],
    "q2": [
        "monster_soldier_light",
        "monster_soldier",
        "monster_soldier_ss",
        "monster_infantry",
        "monster_gunner",
        "monster_berserk",
        "monster_gladiator",
        "monster_chick",
        "monster_flyer",
        "monster_floater",
        "monster_hover",
        "monster_mutant",
        "monster_parasite",
        "monster_brain",
        "monster_medic",
        "monster_flipper",
        "monster_tank",
        "monster_tank_commander",
        "monster_supertank",
        "monster_boss2",
        "monster_jorg",
        "monster_makron",
        "misc_insane"
    ]
};

def gait_floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-4000.0, y=-4000.0, z=-64.0),
        Vec3(x=4000.0, y=4000.0, z=0.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    collision.reindex();
    return collision;
}

def gaited(game: str, kind: str) -> Opponent {
    rule = enemy_rule(game, kind);
    assert rule is not None;
    return Opponent(
        rule=rule,
        game=game,
        kind=kind,
        health=rule.health,
        animation=list(range(len(rule.run.frames))),
        walk_animation=list(range(len(rule.walk.frames)))
    );
}

test "every moving Q1 and Q2 monster has run and walk distances for each frame" {
    for game in ["q1", "q2"] {
        for kind in GAITED[game] {
            rule = enemy_rule(game, kind);
            assert rule is not None;
            assert rule.run.frames and len(rule.run.steps) == len(rule.run.frames) , kind;
            assert rule.walk.frames and len(rule.walk.steps) == len(rule.walk.frames) , kind;
        }
    }
    # m_soldier.h and m_gunner.h MODEL_SCALE; Q1 moves by the raw distance.
    assert gaited("q2", "monster_soldier").rule.step_scale == 1.2;
    assert gaited("q2", "monster_gunner").rule.step_scale == 1.15;
    assert gaited("q1", "monster_ogre").rule.step_scale == 1.0;
}

test "each frame of the cycle steps the monster that frame's distance" {
    ogre = gaited("q1", "monster_ogre");
    ogre.alert = 5.0;
    # ogre_run4: ai_run(22).
    ogre.pose_name = "run";
    ogre.animation_time = 3.5;
    assert frame_step(ogre) == 22.0;
    # The cycle wraps: frame 9 is run2, ai_run(12).
    ogre.animation_time = 9.2;
    assert frame_step(ogre) == 12.0;
    # Unalerted it walks: ogre_walk6, ai_walk(5).
    ogre.alert = 0.0;
    ogre.pose_name = "walk";
    ogre.animation_time = 5.9;
    assert frame_step(ogre) == 5.0;
    # Q2 M_MoveFrame scales distances: soldier run03 is 10 * 1.2.
    soldier = gaited("q2", "monster_soldier");
    soldier.alert = 5.0;
    soldier.pose_name = "run";
    assert abs(frame_step(soldier) - 12.0) < 0.0001;
    # A backwards frame steps back (soldier walk110, ai_walk(-1)).
    soldier.alert = 0.0;
    soldier.pose_name = "walk";
    soldier.animation_time = 9.0;
    assert abs(frame_step(soldier) + 1.2) < 0.0001;
    # Bots have no frame tables: they run, at their rule's speed.
    assert striding(ogre) and not striding(Opponent(arena=True));
}

test "a running monster takes one whole step a frame, carried over the frame's ticks" {
    collision = gait_floor();
    world = World();
    player = Player(pos=Vec3(x=1000.0, z=22.0), health=100000, god_mode=True);
    ogre = gaited("q1", "monster_ogre");
    ogre.pos = Vec3(z=22.0);
    ogre.grounded = True;
    ogre.alert = 8.0;
    ogre.attack_wait = 100.0;
    ogre.last_seen = player.pos;
    world +>:HasOpponent:+> ogre;
    state = CombatState(game="q1");
    # A tick of 1/128 s keeps the frame clock exact: the cycle is entered
    # on the first tick, its first frame thinks on the second, and frame n
    # begins on tick ceil(12.8 n).
    dt = 1.0 / 128.0;
    for tick in range(1, 104) {
        before = ogre.pos.x;
        world spawn CombatTick(player=player, collision=collision, state=state, dt=dt);
        # Between thinks the body only glides toward where its step ended.
        assert ogre.pos.x >= before and ogre.pos.x - before < 2.0 , str(tick);
        if tick == 2 {
            # ogre_run1's ai_run(9) is already taken: other steps find the
            # ogre there, though it is drawn at its start.
            assert ogre.pose_name == "run" and ogre.pos.x == 0.0 and ogre.standing().x == 9.0;
        }
        if tick == 13 {
            # run2 begins: the first step has ended, exactly.
            assert ogre.pos.x == 9.0 and ogre.standing().x == 21.0;
        }
    }
    # ogre_run1-8: 9 + 12 + 8 + 22 + 16 + 4 + 13 + 24 = 108 units, and run1
    # again has begun.
    assert ogre.pos.x == 108.0 and ogre.standing().x == 117.0;
    assert ogre.velocity.length() == 0.0 and ogre.grounded;
}

test "a Q2 knockback slides on under friction" {
    collision = gait_floor();
    body = Player(pos=Vec3(z=collision.eye_height), grounded=True, velocity=Vec3(x=300.0));
    dt = 1.0 / 120.0;
    body spawn MovePlayer(collision=collision, dt=dt);
    # SV_Physics_Step friction takes 6 * speed a second off the knock.
    knock = 300.0 - 300.0 * 6.0 * dt;
    assert abs(body.velocity.x - knock) < 0.001 and abs(body.velocity.y) < 0.000001;
    assert abs(body.pos.x - knock * dt) < 0.001 and body.pos.y == 0.0;
    for tick in range(240) {
        body spawn MovePlayer(collision=collision, dt=dt);
    }
    assert body.velocity.length() == 0.0;
    # A knocked monster's carried step ends at once, and the knock slides
    # it on from there.
    world = World();
    soldier = gaited("q2", "monster_soldier");
    soldier.pos = Vec3(z=22.0);
    soldier.grounded = True;
    start = soldier.pos;
    soldier.pos = Vec3(x=12.0, z=22.0);
    soldier.stride(start, 0.1);
    soldier.velocity = Vec3(y=300.0);
    world +>:HasOpponent:+> soldier;
    world spawn CombatTick(
        player=Player(pos=Vec3(x=-5000.0)), collision=collision, state=CombatState(game="q2"), dt=dt
    );
    assert soldier.stride_time == 0.0 and soldier.pos.x == 12.0;
    assert abs(soldier.pos.y - knock * dt) < 0.001;
}

test "each monster turns by its own yaw speed a frame" {
    # walkmonster_start 20; flymonster_start and swimmonster_start 10;
    # Chthon's boss_awake 20.
    speeds = {
        "q1": {"monster_army": 20.0, "monster_wizard": 10.0, "monster_fish": 10.0, "monster_boss": 20.0},
        "q2": {"monster_soldier": 20.0, "monster_flyer": 10.0, "monster_boss2": 10.0, "monster_flipper": 10.0, "monster_tank": 20.0}
    };
    for game in speeds {
        for kind in speeds[game] {
            rule = enemy_rule(game, kind);
            assert rule is not None and rule.yaw_speed == speeds[game][kind] , kind;
        }
    }
    # Alerted to a player square to the left, a grunt's first step turns it
    # 20 degrees and a Scrag's 10 (SV_StepDirection's ChangeYaw), carried
    # over the frame's twelve ticks.
    for scenario in [("monster_army", 20.0), ("monster_wizard", 10.0)] {
        world = World();
        player = Player(pos=Vec3(y=600.0, z=22.0), health=100000, god_mode=True);
        enemy = gaited("q1", scenario[0]);
        enemy.pos = Vec3(z=22.0);
        enemy.grounded = True;
        enemy.alert = 8.0;
        enemy.attack_wait = 5.0;
        enemy.last_seen = player.pos;
        world +>:HasOpponent:+> enemy;
        state = CombatState(game="q1");
        for tick in range(12) {
            world spawn CombatTick(player=player, collision=gait_floor(), state=state, dt=1.0 / 120.0);
        }
        assert abs(math.degrees(enemy.yaw) - scenario[1]) < 0.001 , scenario[0];
    }
}

test "a Q2 soldier sets off on either walk and walk1 mostly loops at walk110" {
    rule = enemy_rule("q2", "monster_soldier");
    assert rule is not None;
    # soldier_move_walk1 (walk101-133) and soldier_move_walk2 (walk209-218).
    assert len(rule.walk.frames) == 33 and rule.walk.frames[9] == "walk110";
    assert rule.walk.branch == 9 and rule.walk.branch_to == 0 and rule.walk.branch_chance == 0.9;
    assert len(rule.other_walks) == 1 and rule.other_walks[0].frames[0] == "walk209";
    walks = [0, 0];
    loops = 0;
    stands = 0;
    for seed in range(1, 201) {
        soldier = gaited("q2", "monster_soldier");
        soldier.walk_animations = [list(range(100, 110))];
        soldier.shot_random = seed * 7919;
        choose_walk(soldier);
        walks[soldier.walk_cycle] += 1;
        # On walk2 the steps are its own frames' (walk209: 4, scaled 1.2).
        if soldier.walk_cycle == 1 {
            soldier.pose_name = "walk";
            soldier.animation_time = 0.5;
            assert abs(frame_step(soldier) - 4.8) < 0.0001;
            assert walk_frames(soldier) == list(range(100, 110));
        }
        # Once walk110 has played, soldier_walk1_random: back to walk101
        # nine times in ten, else on into walk111.
        if soldier.walk_cycle == 0 {
            collision = gait_floor();
            world = World();
            soldier.pos = Vec3(z=24.0);
            soldier.grounded = True;
            soldier.pose_name = "walk";
            soldier.animation_time = 9.95;
            soldier.patrol_goal = Vec3(x=1000.0, z=24.0);
            world +>:HasOpponent:+> soldier;
            world spawn CombatTick(player=Player(pos=Vec3(z=-10000.0)), collision=collision, state=CombatState(game="q2"), dt=1.0 / 120.0);
            shown = int(soldier.animation_time);
            assert shown in [0, 10] , str(soldier.animation_time);
            if shown == 0 { loops += 1; } else { stands += 1; }
        }
    }
    # Both walks are taken about as often; walk1 goes round far more often
    # than it stands.
    assert walks[0] > 70 and walks[1] > 70;
    assert loops > stands * 4 and stands > 0;
}

"""A monster on open ground with its enemy square behind it, ready to attack."""
def turning_fight(game: str, kind: str) -> tuple[World, Opponent, Player, CombatState] {
    world = World();
    player = Player(pos=Vec3(x=-200.0, z=22.0), health=100000, god_mode=True);
    enemy = gaited(game, kind);
    enemy.pos = Vec3(z=22.0);
    enemy.grounded = True;
    enemy.alert = 8.0;
    enemy.sighted = True;
    enemy.attack_wait = 0.0;
    enemy.last_seen = player.pos;
    world +>:HasOpponent:+> enemy;
    return (world, enemy, player, CombatState(game=game));
}

test "a Q2 monster turns in place to face its enemy before it attacks" {
    (world, enemy, player, state) = turning_fight("q2", "monster_gunner");
    # Always take the shot when it rolls for one.
    enemy.rule.near_chance = 1.0;
    assert faces_to_attack(enemy) and not facing_ideal(enemy, player.pos);
    started = -1;
    readied_at = -1;
    for tick in range(240) {
        world spawn CombatTick(player=player, collision=gait_floor(), state=state, dt=1.0 / 120.0);
        if readied_at < 0 and enemy.readied >= 0 {
            readied_at = tick;
        }
        if enemy.readied >= 0 {
            # Held: it stays where it is, turning toward its enemy.
            assert abs(enemy.pos.x) < 0.000001 and abs(enemy.pos.y) < 0.000001;
        }
        if enemy.attack_clock >= 0.0 {
            started = tick;
            break;
        }
    }
    assert readied_at >= 0 and started > readied_at;
    # ai_run_missile launched it only once within 45 degrees: 135 degrees
    # at 20 a frame takes the turn into its seventh frame.
    assert facing_ideal(enemy, player.pos) and enemy.readied < 0;
    assert started - readied_at >= 66;
}

test "Q1 CheckAttack launches at once while the ogre's check waits to face" {
    (world, grunt, player, state) = turning_fight("q1", "monster_army");
    assert not faces_to_attack(grunt);
    ogre = gaited("q1", "monster_ogre");
    assert faces_to_attack(ogre);
    marksman = gaited("q1", "monster_ogre_marksman");
    assert not faces_to_attack(marksman);
    # FacingIdeal's 45 degrees either way round.
    ogre.pos = Vec3();
    ogre.yaw = math.radians(44.0);
    assert facing_ideal(ogre, Vec3(x=100.0));
    ogre.yaw = math.radians(-46.0);
    assert not facing_ideal(ogre, Vec3(x=100.0));
    ogre.yaw = math.radians(316.0);
    assert facing_ideal(ogre, Vec3(x=100.0));
    # A monster in pain holds its attack until the pain is over.
    (world, held, player, state) = turning_fight("q2", "monster_gunner");
    held.yaw = math.pi;
    held.readied = 0;
    held.pain_wait = 0.05;
    world spawn CombatTick(player=player, collision=gait_floor(), state=state, dt=1.0 / 120.0);
    assert held.readied == 0 and held.attack_clock < 0.0;
    for tick in range(12) {
        world spawn CombatTick(player=player, collision=gait_floor(), state=state, dt=1.0 / 120.0);
    }
    assert held.readied < 0 and held.attack_clock >= 0.0;
}
