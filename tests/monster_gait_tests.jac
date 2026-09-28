"""Per-frame monster locomotion: Q1 ai_run/ai_walk distances and Q2 mframe_t
move tables drive each monster's pace frame by frame."""
import from games.enemies { enemy_rule }
import from engine.world.world { Player }
import from engine.world.combat { Opponent, gait_speed, striding }
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
