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
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "enforcer burst has windup and resumes without replay after saving" {
    world = World();
    level = Level(name="timing");
    level.bsp.game = "q1";
    player = Player(pos=Vec3(x=120.0));
    state = CombatState();
    rule = enemy_rule("q1", "monster_enforcer");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert not [world->:HasProjectile:->];
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert len([world->:HasProjectile:->]) == 1;
    saved = snapshot(world, level, player, state);
    enemy.attack_clock = -1.0;
    restore(world, level, player, state, saved);
    assert enemy.attack_event == 1 and abs(enemy.attack_clock - 0.5) < 0.00001;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert len([world->:HasProjectile:->]) == 2;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.2
    );
    assert len([world->:HasProjectile:->]) == 2;
}

test "windup can be interrupted and fresh walls block an already scheduled shot" {
    world = World();
    player = Player(pos=Vec3(x=120.0));
    state = CombatState();
    collision = CollisionMap();
    rule = enemy_rule("q1", "monster_enforcer");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.2);
    damage_opponent(enemy, 1);
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    assert not [world->:HasProjectile:->] and enemy.attack_clock < 0.0;
    enemy.attack_wait = 0.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.2);
    collision.add_box(
        Vec3(x=50.0, y=-100.0, z=-100.0),
        Vec3(x=51.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    assert not [world->:HasProjectile:->] and enemy.attack_event == 1;
}

test "knight swing checks range for each of its three strikes" {
    world = World();
    player = Player(pos=Vec3(x=40.0));
    state = CombatState();
    collision = CollisionMap();
    rule = enemy_rule("q1", "monster_knight");
    assert rule is not None;
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.4);
    assert player.health == 100;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    first_health = player.health;
    assert first_health >= 92 and first_health < 100;
    player.pos.x = 200.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert player.health == first_health;
    player.pos.x = 40.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert player.health >= first_health - 8 and player.health <= first_health;
    assert enemy.attack_event == 3;
}

test "dog charge follows frame distance and cannot cross a blocking wall" {
    world = World();
    player = Player(pos=Vec3(x=80.0, z=22.0));
    state = CombatState();
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-100.0, y=-100.0, z=-10.0),
        Vec3(x=100.0, y=100.0, z=0.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    rule = enemy_rule("q1", "monster_dog");
    assert rule is not None;
    enemy = Opponent(rule=rule, pos=Vec3(z=22.01), grounded=True, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    for i in range(10) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.01
        );
    }
    assert enemy.pos.x > 9.0 and enemy.pos.x < 11.0;
    assert player.health == 100;
    collision.add_box(
        Vec3(x=15.0, y=-100.0, z=-1.0),
        Vec3(x=16.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    for i in range(30) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.01
        );
    }
    assert enemy.pos.x <= 15.0001 , str(enemy.pos.x);
    assert player.health == 100;
}
