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
    damage_opponent
}
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "Q2 light soldiers wind up before firing a spread blaster bolt" {
    rule = enemy_rule("q2", "monster_soldier_light");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0));
    state = CombatState();
    collision = CollisionMap();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
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
    assert rule.pellets == 12 and rule.damage == 2 and rule.missile_speed == 0.0;
    assert rule.spread == 2.0 * rule.vertical_spread;
    world = World();
    player = Player(pos=Vec3(x=40.0));
    state = CombatState();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
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
