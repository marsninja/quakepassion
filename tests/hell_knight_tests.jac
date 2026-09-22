import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    damage_opponent
}
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

test "hell knight fires six distinct directions after windup" {
    rule = enemy_rule("q1", "monster_hell_knight");
    assert rule is not None;
    world = World();
    level = Level(name="fan");
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert not [world->:HasProjectile:->];
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.6
    );
    shots = [world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 6;
    for i in range(6) {
        angle = math.atan2(shots[i].velocity.y, shots[i].velocity.x) * 180.0 / math.pi;
        assert abs(angle - (-12.0 + float(i) * 6.0)) < 0.001;
        assert shots[i].damage == 9 and shots[i].effect == "q1_knightspike";
        assert abs(shots[i].velocity.length() - 300.0) < 0.001;
    }
}

test "hell knight saves the volley cursor and vertical scatter stream" {
    rule = enemy_rule("q1", "monster_hell_knight");
    assert rule is not None;
    world = World();
    level = Level(name="fan");
    level.bsp.game = "q1";
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.7
    );
    assert len([world->:HasProjectile:->]) == 3;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.3
    );
    z = [world->:HasProjectile:->][?:Projectile][-1].velocity.z;
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.3
    );
    assert len([world->:HasProjectile:->]) == 6;
    assert abs([world->:HasProjectile:->][?:Projectile][-1].velocity.z - z) < 0.001;
}

test "hell knight sword hits can be escaped and pain cancels pending spikes" {
    rule = enemy_rule("q1", "monster_hell_knight");
    assert rule is not None;
    world = World();
    level = Level(name="sword");
    player = Player(pos=Vec3(x=50.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert enemy.attack_melee and player.health >= 92 and player.health < 100;
    health = player.health;
    player.pos.x = 500.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert player.health == health and not [world->:HasProjectile:->];
    enemy.attack_clock = -1.0;
    enemy.attack_wait = 0.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    damage_opponent(enemy, 1);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert not [world->:HasProjectile:->];
}
