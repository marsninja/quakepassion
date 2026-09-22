import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    CombatState,
    CombatTick,
    attack_duration,
    attack_pose_time
}
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "infantry punch winds up and applies bounded damage and knockback" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(
        rule=rule,
        attack_wait=0.0,
        melee_animation=[20, 21, 22, 23, 24, 25, 26, 27],
        attack_animation=[1, 2, 3]
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    collision = CollisionMap();
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    assert enemy.attack_melee
        and enemy.burst_count == 1
        and attack_duration(enemy) == 0.8;
    assert enemy.visual.first == 24 and player.health == 100;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert player.health >= 91 and player.health <= 95;
    assert abs(player.velocity.x - 50.0) < 0.001;
    assert enemy.attack_event == 1 and enemy.visual.first == 25;
}

test "infantry punch can be dodged and never turns into a gun shot mid swing" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    collision = CollisionMap();
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    player.pos.x = 200.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert player.health == 100 and player.velocity.length() == 0.0;
    assert enemy.attack_melee and enemy.attack_event == 1;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    enemy.attack_wait = 0.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert not enemy.attack_melee and enemy.burst_count >= 4;
}

test "infantry melee selection and random damage survive save restore" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    level = Level(name="punch");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    health = player.health;
    stream = enemy.shot_random;
    enemy.attack_melee = False;
    enemy.burst_count = 10;
    restore(world, level, player, state, saved);
    assert enemy.attack_melee and enemy.burst_count == 1;
    assert abs(attack_pose_time(enemy) - 4.0) < 0.001;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert player.health == health and enemy.shot_random == stream;
}

test "god mode blocks infantry punch damage and knockback" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=60.0), god_mode=True);
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=CombatState(), dt=0.5
    );
    assert enemy.attack_event == 1
        and player.health == 100
        and player.velocity.length() == 0.0;
}
