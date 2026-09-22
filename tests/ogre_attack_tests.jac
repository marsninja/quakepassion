import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick
}
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

test "ogre grenade waits for shoot3 and uses monster blast strength" {
    rule = enemy_rule("q1", "monster_ogre_marksman");
    assert rule is not None;
    world = World();
    level = Level(name="ogre");
    player = Player(pos=Vec3(x=300.0));
    state = CombatState(game="q1");
    enemy = Opponent(
        rule=rule, attack_wait=0.0, attack_animation=[1, 2, 2, 3, 4, 5, 6]
    );
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.2
    );
    assert not [world->:HasProjectile:->] and enemy.visual.first == 2;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    shots = [world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 1 and enemy.visual.first == 3;
    assert shots[0].gravity and shots[0].hostile;
    assert shots[0].splash == 40 and shots[0].radius == 80.0;
    assert shots[0].velocity.z == 200.0 and shots[0].remaining == 2.5;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert len([world->:HasProjectile:->]) == 1 and enemy.attack_clock < 0.0;
}

test "ogre chainsaw has seven timed strikes and deterministic save restoration" {
    rule = enemy_rule("q1", "monster_ogre");
    assert rule is not None;
    world = World();
    level = Level(name="ogre");
    level.bsp.game = "q1";
    player = Player(pos=Vec3(x=60.0));
    state = CombatState(game="q1");
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.3
    );
    assert enemy.attack_melee and player.health == 100;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.7
    );
    assert enemy.attack_event == 7 and player.health < 100 and player.health >= 23;
    assert not [world->:HasProjectile:->];
    health = player.health;
    stream = enemy.shot_random;
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.7
    );
    assert player.health == health and enemy.shot_random == stream;
}

test "escaping an ogre swing prevents remaining strikes without firing a grenade" {
    rule = enemy_rule("q1", "monster_ogre");
    assert rule is not None;
    world = World();
    level = Level(name="ogre");
    player = Player(pos=Vec3(x=60.0));
    state = CombatState(game="q1");
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    health = player.health;
    player.pos.x = 300.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.6
    );
    assert player.health == health and enemy.attack_event == 7;
    assert not [world->:HasProjectile:->];
}

test "ogre smash selects and restores its own frames and six strike timeline" {
    rule = enemy_rule("q1", "monster_ogre");
    assert rule is not None;
    world = World();
    level = Level(name="ogre");
    level.bsp.game = "q1";
    player = Player(pos=Vec3(x=60.0));
    state = CombatState(game="q1");
    enemy = Opponent(
        rule=rule,
        attack_wait=0.0,
        shot_random=30000,
        melee_animation=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
        alternate_melee_animation=[
            21,
            22,
            23,
            24,
            25,
            26,
            27,
            28,
            29,
            30,
            31,
            32,
            33,
            34
        ]
    );
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert enemy.alternate_melee and enemy.visual.first == 25 and player.health == 100;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.6
    );
    assert enemy.attack_event == 6 and player.health < 100;
    health = player.health;
    enemy.alternate_melee = False;
    restore(world, level, player, state, saved);
    assert enemy.alternate_melee;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.6
    );
    assert player.health == health and enemy.attack_event == 6;
}
