import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    fire_weapon,
    actor_fraction
}
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "weapons hit nearest living target consume shells and obey cooldown" {
    world = World();
    far = Opponent(pos=Vec3(x=200.0), health=60);
    near = Opponent(pos=Vec3(x=100.0), health=60);
    world +>:HasOpponent:+> far;
    world +>:HasOpponent:+> near;
    player = Player();
    state = CombatState();
    collision = CollisionMap();
    assert fire_weapon(world, player, collision, state);
    assert near.health == 45 and far.health == 60;
    assert not fire_weapon(world, player, collision, state);
    assert state.shots == 1;
    world spawn CombatTick(
        player=player, collision=collision, state=state, dt=0.3, active=False
    );
    state.weapon = 2;
    assert not fire_weapon(world, player, collision, state);
    player.inventory spawn AdjustInventory(kind="shells", amount=2, capacity=100);
    assert fire_weapon(world, player, collision, state);
    assert near.health == 0 and state.kills == 1 and not near.visual.visible;
    assert quantity(player.inventory, "shells") == 1;
    world spawn CombatTick(
        player=player, collision=collision, state=state, dt=0.7, active=False
    );
    assert fire_weapon(world, player, collision, state);
    assert far.health == 10 and state.kills == 1;
    player.health = 0;
    state.cooldown = 0.0;
    assert not fire_weapon(world, player, collision, state);
}

test "world geometry blocks both player and opponent shots" {
    world = World();
    enemy = Opponent(pos=Vec3(x=100.0), health=60, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    player = Player();
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=40.0, y=-100.0, z=-100.0),
        Vec3(x=50.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    state = CombatState();
    assert fire_weapon(world, player, collision, state);
    assert enemy.health == 60 and abs(state.target.x - 40.0) < 0.001;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert player.health == 100;
}

test "arena opponents respawn campaign opponents remain dead" {
    world = World();
    bot = Opponent(health=0, arena=True, home=Vec3(x=200.0), respawn_wait=0.5);
    campaign = Opponent(health=0, home=Vec3(x=200.0));
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> campaign;
    player = Player();
    state = CombatState();
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.25
    );
    assert bot.health == 0;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.25
    );
    assert bot.health == bot.max_health and campaign.health == 0;
}

test "actor ray bounds reject grazing misses and accept inside starts" {
    assert actor_fraction(Vec3(), Vec3(x=100.0), Vec3(x=50.0), 22.0) < 1.0;
    assert actor_fraction(Vec3(y=17.0), Vec3(x=100.0, y=17.0), Vec3(x=50.0), 22.0)
        == 1.0;
    assert actor_fraction(Vec3(), Vec3(), Vec3(), 22.0) == 0.0;
}

test "cached pursuit never permits an attack through newly blocking geometry" {
    world = World();
    enemy = Opponent(pos=Vec3(x=100.0), attack_wait=0.0, grounded=True);
    world +>:HasOpponent:+> enemy;
    player = Player();
    collision = CollisionMap();
    state = CombatState();
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert player.health == 96 and enemy.pursuing;
    collision.add_box(
        Vec3(x=40.0, y=-100.0, z=-100.0),
        Vec3(x=50.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    enemy.attack_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert player.health == 96;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert player.health == 96 and not enemy.pursuing;
}

test "settled opponents detect lost support and resume per tick gravity" {
    world = World();
    enemy = Opponent(pos=Vec3(x=2000.0), grounded=True, support_wait=0.05);
    world +>:HasOpponent:+> enemy;
    player = Player();
    collision = CollisionMap();
    state = CombatState();
    for i in range(7) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=1.0 / 120.0
        );
    }
    assert not enemy.grounded and enemy.velocity.z < 0.0;
    prior = enemy.pos.z;
    world spawn CombatTick(
        player=player, collision=collision, state=state, dt=1.0 / 120.0
    );
    assert enemy.pos.z < prior;
}
