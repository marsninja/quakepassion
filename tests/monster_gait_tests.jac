"""Per-frame monster locomotion: Q1 ai_run/ai_walk distances and Q2 mframe_t
move tables drive each monster's pace frame by frame."""
import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    CombatState,
    CombatTick,
    gait_speed,
    striding,
    choose_walk,
    walk_frames
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

test "the pace is the shown frame's distance each tenth of a second" {
    ogre = gaited("q1", "monster_ogre");
    ogre.alert = 5.0;
    # ogre_run4: ai_run(22).
    ogre.pose_name = "run";
    ogre.animation_time = 3.5;
    assert gait_speed(ogre) == 220.0;
    # A monster only now setting off starts from run1: ai_run(9).
    ogre.pose_name = "stand";
    assert gait_speed(ogre) == 90.0;
    # The cycle wraps: frame 9 is run2, ai_run(12).
    ogre.pose_name = "run";
    ogre.animation_time = 9.2;
    assert gait_speed(ogre) == 120.0;
    # Unalerted it walks: ogre_walk6, ai_walk(5).
    ogre.alert = 0.0;
    ogre.pose_name = "walk";
    ogre.animation_time = 5.9;
    assert gait_speed(ogre) == 50.0;
    # Q2 M_MoveFrame scales distances: soldier run03 is 10 * 1.2.
    soldier = gaited("q2", "monster_soldier");
    soldier.alert = 5.0;
    soldier.pose_name = "run";
    assert abs(gait_speed(soldier) - 120.0) < 0.0001;
    # A backwards frame steps back (soldier walk110, ai_walk(-1)).
    soldier.alert = 0.0;
    soldier.pose_name = "walk";
    soldier.animation_time = 9.0;
    assert abs(gait_speed(soldier) + 12.0) < 0.0001;
    # Bots have no frame tables and run at their rule's speed.
    assert striding(ogre) and not striding(Opponent(arena=True));
}

test "a striding body covers exactly its frames' distances" {
    collision = gait_floor();
    ogre = gaited("q1", "monster_ogre");
    body = Player(pos=Vec3(z=collision.eye_height), grounded=True);
    dt = 1.0 / 120.0;
    for frame in range(len(ogre.rule.run.steps)) {
        body.walk_speed = ogre.rule.run.steps[frame] * 10.0;
        for tick in range(12) {
            body spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), steady=True, dt=dt);
        }
    }
    # ogre_run1-8: 9 + 12 + 8 + 22 + 16 + 4 + 13 + 24 = 108 units in 0.8 s.
    assert abs(body.pos.x - 108.0) < 0.001;
    assert body.velocity.length() == 0.0 and body.grounded;
}

test "a Q2 knockback slides on under friction beside the stride" {
    collision = gait_floor();
    body = Player(
        pos=Vec3(z=collision.eye_height),
        grounded=True,
        walk_speed=100.0,
        velocity=Vec3(x=300.0)
    );
    dt = 1.0 / 120.0;
    body spawn MovePlayer(collision=collision, wish=Vec3(y=1.0), steady=True, dt=dt);
    # SV_Physics_Step friction takes 6 * speed a second off the knock.
    knock = 300.0 - 300.0 * 6.0 * dt;
    assert abs(body.velocity.x - knock) < 0.001 and abs(body.velocity.y) < 0.000001;
    assert abs(body.pos.y - 100.0 * dt) < 0.001;
    assert abs(body.pos.x - knock * dt) < 0.001;
    for tick in range(240) {
        body spawn MovePlayer(collision=collision, wish=Vec3(y=1.0), steady=True, dt=dt);
    }
    assert body.velocity.length() == 0.0;
    assert abs(body.pos.y - 241.0 * 100.0 * dt) < 0.01;
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
    # Alerted to a player square to the left, a grunt turns 20 degrees in a
    # 0.1 s frame and a Scrag 10, over the frame's twelve ticks.
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
        # On walk2 the pace is its own frames' (walk209: 4, scaled 1.2).
        if soldier.walk_cycle == 1 {
            soldier.pose_name = "walk";
            soldier.animation_time = 0.5;
            assert abs(gait_speed(soldier) - 48.0) < 0.0001;
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
            soldier.steering = Vec3(x=1.0);
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
