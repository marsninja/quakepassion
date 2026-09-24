import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    ProjectileTick,
    attack_charge,
    damage_opponent
}
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "chick rocket winds up and saved release deals direct damage only once" {
    rule = enemy_rule("q2", "monster_chick");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    world = World();
    level = Level(name="rocket");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=1.2
    );
    assert not [world->:HasProjectile:->];
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    shots = [world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 1 and shots[0].damage == 50 and shots[0].splash == 50;
    assert shots[0].radius == 70.0 and shots[0].effect == "q2_rocket";
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert len([world->:HasProjectile:->]) == 1;
    world spawn ProjectileTick(
        player=player, collision=level.collision, state=state, dt=1.0
    );
    assert player.health == 50 and not [world->:HasProjectile:->];
}

test "chick rocket windup is interrupted by pain" {
    rule = enemy_rule("q2", "monster_chick");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    world = World();
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    collision = CollisionMap();
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=collision, state=state, dt=1.2);
    damage_opponent(enemy, 1);
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert enemy.attack_clock < 0.0 and not [world->:HasProjectile:->];
}

test "chick slash uses melee timeline and can be escaped" {
    for escape in [False, True] {
        rule = enemy_rule("q2", "monster_chick");
        assert rule is not None;
        # Attack the moment it may, to time the sequence itself.
        rule.near_chance = 1.0;
        rule.mid_chance = 1.0;
        world = World();
        player = Player(pos=Vec3(x=60.0));
        enemy = Opponent(rule=rule, attack_wait=0.0);
        world +>:HasOpponent:+> enemy;
        collision = CollisionMap();
        state = CombatState(game="q2");
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.3);
        assert player.health == 100 and enemy.attack_melee;
        if escape {
            player.pos.x = 300.0;
        }
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
        if escape {
            assert player.health == 100;
        } else {
            assert player.health >= 85 and player.health <= 90;
            assert abs(player.velocity.x - 100.0) < 0.001;
        }
        assert not [world->:HasProjectile:->];
    }
}

test "authored recovery can move backward but stops at walls and ledges" {
    for obstruction in [0, 1, 2] {
        rule = enemy_rule("q2", "monster_chick");
        assert rule is not None;
        # Attack the moment it may, to time the sequence itself.
        rule.near_chance = 1.0;
        rule.mid_chance = 1.0;
        collision = CollisionMap();
        collision.add_box(
            Vec3(x=-1.0 if obstruction == 2 else -100.0, y=-100.0, z=-10.0),
            Vec3(x=400.0, y=100.0, z=0.0),
            Vec3(),
            Vec3(),
            Vec3()
        );
        if obstruction == 1 {
            collision.add_box(
                Vec3(x=-2.0, y=-100.0, z=0.0),
                Vec3(x=-1.0, y=100.0, z=100.0),
                Vec3(),
                Vec3(),
                Vec3()
            );
        }
        enemy = Opponent(rule=rule, pos=Vec3(z=22.01), grounded=True, attack_clock=0.5);
        player = Player(pos=Vec3(x=300.0, z=22.01));
        for i in range(2) {
            attack_charge(enemy, player, collision, 0.05);
            enemy.attack_clock += 0.05;
        }
        if obstruction == 0 {
            assert abs(enemy.pos.x + 3.0) < 0.001;
        } else {
            assert enemy.pos.x >= -1.0001;
        }
    }
}

test "chick repeats rocket body without replaying initial windup and saves cursor" {
    rule = enemy_rule("q2", "monster_chick");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    world = World();
    level = Level(name="refire");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, shot_random=1);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=2.7
    );
    assert len([world->:HasProjectile:->]) == 2;
    assert abs(enemy.attack_clock - 1.3) < 0.001 and enemy.attack_event == 1;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert len([world->:HasProjectile:->]) == 2;
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert len([world->:HasProjectile:->]) == 2;
    player.pos.x = 60.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=1.8
    );
    assert enemy.attack_clock < 0.0 and len([world->:HasProjectile:->]) == 2;
}

test "chick declines repeat for random choice or lost sight" {
    for blocked in [False, True] {
        rule = enemy_rule("q2", "monster_chick");
        assert rule is not None;
        # Attack the moment it may, to time the sequence itself.
        rule.near_chance = 1.0;
        rule.mid_chance = 1.0;
        world = World();
        player = Player(pos=Vec3(x=500.0));
        enemy = Opponent(rule=rule, attack_wait=0.0, shot_random=30000);
        world +>:HasOpponent:+> enemy;
        collision = CollisionMap();
        state = CombatState(game="q2");
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.3);
        if blocked {
            enemy.shot_random = 1;
            collision.add_box(
                Vec3(x=100.0, y=-100.0, z=-100.0),
                Vec3(x=101.0, y=100.0, z=100.0),
                Vec3(),
                Vec3(),
                Vec3()
            );
        }
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.9);
        assert len([world->:HasProjectile:->]) == 1 and enemy.attack_clock < 0.0;
    }
}

test "chick repeated slash resumes after save and stops when player escapes" {
    rule = enemy_rule("q2", "monster_chick");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    world = World();
    level = Level(name="reslash");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, shot_random=1);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=1.2
    );
    assert enemy.attack_melee and abs(enemy.attack_clock - 0.3) < 0.001;
    assert enemy.attack_event == 0 and player.health < 100;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    health = player.health;
    assert enemy.attack_event == 1;
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert player.health == health and enemy.attack_event == 1;
    player.pos.x = 300.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=1.2
    );
    assert enemy.attack_clock < 0.0 and player.health == health;
}
