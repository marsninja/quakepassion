"""Check original Q2 attack poses and held bursts with the native compiler."""
import os;
import from engine.assets.library { AssetLibrary }
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    HasProjectile,
    CombatState,
    CombatTick,
    attack_pose_time
}
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

with entry {
    library = AssetLibrary(game="q2");
    library.open(os.getenv("HOME", "") + "/quake-assets/baseq2");
    try {
        for kind in [
            "monster_soldier_light",
            "monster_soldier",
            "monster_soldier_ss",
            "monster_infantry",
            "monster_berserk",
            "monster_gladiator",
            "monster_chick"
        ] {
            rule = enemy_rule("q2", kind);
            assert rule is not None;
            model = library.model(rule.model, skin=rule.skin).model;
            names = [frame.name for frame in model.surfaces[0].frames];
            for name in rule.attack_frames
                + rule.melee_frames
                + rule.alternate_melee_frames
                + rule.run_frames
                + rule.pain_frames {
                assert name in names , kind + ":" + name;
            }
            if rule.attack_frames {
                assert len(rule.attack_frames) == int(rule.attack_duration * 10.0);
            }
            for path in [rule.attack_sound, rule.melee_sound] {
                if path {
                    assert len(library.read(path)) > 44;
                }
            }
            print("Q2 ATTACK ASSET PASS " + kind);
        }
    } finally {
        library.close();
    }
    world = World();
    player = Player(pos=Vec3(x=200.0), god_mode=True);
    state = CombatState();
    collision = CollisionMap();
    rule = enemy_rule("q2", "monster_soldier_ss");
    assert rule is not None;
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.2);
    assert enemy.attack_event == 1;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert enemy.attack_event == 2 and abs(attack_pose_time(enemy) - 2.0) < 0.00001;
    enemy.decision_wait = 10.0;
    for i in range(30) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    assert enemy.attack_event == enemy.burst_count and enemy.attack_clock < 0.0;
    print("Q2 NATIVE BURST PASS");
    rockets = World();
    rocket_rule = enemy_rule("q2", "monster_chick");
    assert rocket_rule is not None;
    rocket_enemy = Opponent(rule=rocket_rule, attack_wait=0.0, shot_random=1);
    rockets +>:HasOpponent:+> rocket_enemy;
    rockets spawn CombatTick(player=player, collision=collision, state=state, dt=2.7);
    assert len([rockets->:HasProjectile:->]) == 2;
    assert abs(rocket_enemy.attack_clock - 1.3) < 0.001;
    rockets spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert len([rockets->:HasProjectile:->]) == 2;
    print("Q2 NATIVE ROCKET REFIRE PASS");
}
