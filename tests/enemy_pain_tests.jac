import from games.enemies { enemy_rule }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    CombatState,
    CombatTick,
    damage_opponent
}
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.math.vec3 { Vec3 }
import from engine.core.savegame { snapshot, restore }

test "infantry pain lasts for its full sequence and does not wrap the last pose" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    level = Level(name="pain");
    player = Player(pos=Vec3(x=300.0));
    enemy = Opponent(
        rule=rule, pain_animation=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    damage_opponent(enemy, 1);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.95
    );
    assert enemy.pain_wait > 0.0 and enemy.attack_clock < 0.0;
    assert enemy.visual.first == 19 and enemy.visual.second == 19;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.05
    );
    assert enemy.pain_wait < 0.000001;
}

test "pain cooldown allows damage without repeatedly resetting recovery" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    level = Level(name="pain");
    player = Player(pos=Vec3(x=300.0));
    enemy = Opponent(rule=rule);
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    damage_opponent(enemy, 1);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    damage_opponent(enemy, 1);
    assert enemy.health == 98 and abs(enemy.pain_wait - 0.6) < 0.001;
    assert abs(enemy.pain_cooldown - 2.6) < 0.001;
}

test "saved pain resumes at the elapsed pose rather than restarting" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    level = Level(name="pain");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=300.0));
    enemy = Opponent(
        rule=rule, pain_animation=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    damage_opponent(enemy, 1);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.5
    );
    saved = snapshot(world, level, player, state);
    enemy.animation_time = 0.0;
    enemy.pose_name = "run";
    enemy.pain_wait = 0.0;
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert enemy.visual.first == 16;
    assert abs(enemy.pain_cooldown - 2.4) < 0.001;
}
