import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    ProjectileTick
}
import from engine.math.vec3 { Vec3 }
import from engine.physics.collision { CollisionMap }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }

test "melee opponents must approach before damage and cannot attack through walls" {
    world = World();
    player = Player(pos=Vec3(x=200.0));
    state = CombatState();
    rule = enemy_rule("q1", "monster_dog");
    assert rule is not None;
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    collision = CollisionMap();
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert player.health == 100;
    player.pos = Vec3(x=40.0);
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert player.health == 88;
    collision.add_box(
        Vec3(x=15.0, y=-100.0, z=-100.0),
        Vec3(x=16.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    enemy.attack_wait = 0.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert player.health == 88;
}

test "enemy bolts travel hit the player and preserve ownership across saves" {
    world = World();
    player = Player(pos=Vec3(x=120.0));
    state = CombatState();
    level = Level(name="enemy");
    level.bsp.game = "q1";
    rule = enemy_rule("q1", "monster_enforcer");
    assert rule is not None;
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.01
    );
    assert player.health == 100;
    missiles = [world->:HasProjectile:->][?:Projectile];
    assert len(missiles) == 1 and missiles[0].hostile and missiles[0].damage == 15;
    saved = snapshot(world, level, player, state);
    restore(world, level, player, state, saved);
    assert [world->:HasProjectile:->][?:Projectile][0].hostile;
    for i in range(30) {
        world spawn ProjectileTick(
            player=player, collision=level.collision, state=state, dt=0.01
        );
    }
    assert player.health == 85 and enemy.health == 100 and state.kills == 0;
    assert not [world->:HasProjectile:->];
}

test "hostile projectiles stop at walls and explosions respect god mode" {
    world = World();
    player = Player(pos=Vec3(x=100.0));
    state = CombatState(game="q1");
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=50.0, y=-100.0, z=-100.0),
        Vec3(x=51.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    world +>:HasProjectile:+> Projectile(
        pos=Vec3(), velocity=Vec3(x=600.0), damage=15, hostile=True
    );
    for i in range(30) {
        world spawn ProjectileTick(
            player=player, collision=collision, state=state, dt=0.01
        );
    }
    assert player.health == 100 and not [world->:HasProjectile:->];
    collision = CollisionMap();
    player.god_mode = True;
    world +>:HasProjectile:+> Projectile(
        pos=Vec3(x=75.0),
        velocity=Vec3(x=600.0),
        damage=0,
        splash=120,
        radius=160.0,
        hostile=True
    );
    world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.1);
    assert player.health == 100;
    player.god_mode = False;
    world +>:HasProjectile:+> Projectile(
        pos=Vec3(x=75.0),
        velocity=Vec3(x=600.0),
        damage=0,
        splash=120,
        radius=160.0,
        hostile=True
    );
    world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.1);
    assert player.health < 50;
}
