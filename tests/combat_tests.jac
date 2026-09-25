import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    fire_weapon,
    actor_fraction,
    attack_pause,
    attack_chance,
    damage_opponent
}
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.world.signals { Signal, Targets, Fire }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "weapons hit nearest living target consume shells and obey cooldown" {
    world = World();
    far = Opponent(pos=Vec3(x=200.0), health=60);
    near = Opponent(pos=Vec3(x=100.0), health=60);
    objective = Signal(relay=True, remaining=1, once=True);
    destination = Signal();
    near.activation +>:Targets:+> objective;
    objective +>:Targets:+> destination;
    world +>:HasOpponent:+> far;
    world +>:HasOpponent:+> near;
    player = Player();
    state = CombatState();
    collision = CollisionMap();
    assert fire_weapon(world, player, collision, state);
    assert near.health == 45 and far.health == 60;
    assert destination.pending == 0;
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
    assert destination.pending == 1 and not objective.enabled;
    assert quantity(player.inventory, "shells") == 1;
    world spawn CombatTick(
        player=player, collision=collision, state=state, dt=0.7, active=False
    );
    assert fire_weapon(world, player, collision, state);
    assert far.health == 10 and state.kills == 1;
    assert destination.pending == 1;
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
    # g_client.c ClientSpawn: arena competitors return with 25 extra health.
    assert bot.health == bot.max_health + 25 and campaign.health == 0;
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

test "opponents remember last sight and stop at expired alert" {
    world = World();
    # Facing the player: idle monsters only notice what is in front of them.
    enemy = Opponent(pos=Vec3(x=300.0), attack_wait=10.0, yaw=3.14159);
    world +>:HasOpponent:+> enemy;
    player = Player();
    collision = CollisionMap();
    state = CombatState();
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert enemy.alert > 0.0 and enemy.steering.x < 0.0;
    collision.add_box(Vec3(x=140.0, y=-100.0, z=-1000.0), Vec3(x=150.0, y=100.0, z=1000.0), Vec3(), Vec3(), Vec3());
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert not enemy.pursuing and enemy.alert > 0.0 and enemy.last_seen.x == 0.0;
    enemy.alert = 0.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert enemy.steering.length() == 0.0;
}

test "triggered opponents stay hidden and unhittable until their spawn delay expires" {
    world = World(); player = Player(); state = CombatState(); collision = CollisionMap();
    enemy = Opponent(pos=Vec3(x=100.0),dormant=True,health=60,attack_wait=5.0);
    enemy.visual.visible = False;
    world +>:HasOpponent:+> enemy;
    assert fire_weapon(world,player,collision,state);
    assert enemy.health == 60;
    world spawn CombatTick(player=player,collision=collision,state=state,dt=1.0);
    assert enemy.dormant and not enemy.visual.visible;
    enemy.activation spawn Fire(emit=False);
    world spawn CombatTick(player=player,collision=collision,state=state,dt=0.05);
    assert enemy.dormant and not enemy.visual.visible;
    world spawn CombatTick(player=player,collision=collision,state=state,dt=0.05);
    assert not enemy.dormant and enemy.visual.visible;
    state.cooldown = 0.0;
    assert fire_weapon(world,player,collision,state);
    assert enemy.health == 45;
}

test "opponent activation and spawn countdown survive save restore" {
    world = World(); player = Player(); state = CombatState(); level = Level(name="fixture");
    enemy = Opponent(pos=Vec3(x=100.0),dormant=True,spawn_wait=0.075);
    enemy.visual.visible = False;
    world +>:HasOpponent:+> enemy;
    data = snapshot(world,level,player,state);
    world spawn CombatTick(player=player,collision=level.collision,state=state,dt=0.1);
    assert not enemy.dormant;
    restore(world,level,player,state,data);
    assert enemy.dormant and not enemy.visual.visible and enemy.spawn_wait == 0.075;
}

test "idle monsters notice by facing, range, gunfire and each other" {
    world = World();
    player = Player();
    collision = CollisionMap();
    state = CombatState();
    behind = Opponent(pos=Vec3(x=300.0), attack_wait=10.0, game="q1");
    far = Opponent(pos=Vec3(x=-1200.0), attack_wait=10.0, game="q1");
    world +>:HasOpponent:+> behind;
    world +>:HasOpponent:+> far;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert behind.alert == 0.0 and far.alert == 0.0;
    # Q1 show_hostile: a fresh shot lets near monsters notice without facing.
    state.noise = 1.0;
    behind.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert behind.alert > 0.0 and far.alert == 0.0;
    # Q2 hearing reaches 1000 units, but never ambush monsters.
    q2 = World();
    listener = Opponent(pos=Vec3(x=-800.0), attack_wait=10.0, game="q2", yaw=3.14159);
    ambusher = Opponent(pos=Vec3(y=-800.0), attack_wait=10.0, game="q2", ambush=True);
    q2 +>:HasOpponent:+> listener;
    q2 +>:HasOpponent:+> ambusher;
    noisy = CombatState(noise=1.0);
    q2 spawn CombatTick(player=player, collision=collision, state=noisy, dt=0.01);
    assert listener.alert > 0.0 and ambusher.alert == 0.0;
    # A monster that spots the player wakes others that can see it.
    chain = World();
    spotter = Opponent(pos=Vec3(x=300.0), attack_wait=10.0, yaw=3.14159, game="q1");
    watcher = Opponent(pos=Vec3(x=600.0, y=300.0), attack_wait=10.0, yaw=3.14159, game="q1");
    chain +>:HasOpponent:+> spotter;
    chain +>:HasOpponent:+> watcher;
    # The wall hides the player from the watcher but not the spotter.
    collision.add_box(Vec3(x=150.0, y=60.0, z=-500.0), Vec3(x=200.0, y=110.0, z=500.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    calm = CombatState();
    chain spawn CombatTick(player=player, collision=collision, state=calm, dt=0.01);
    assert spotter.alert > 0.0;
    watcher.decision_wait = 0.0;
    chain spawn CombatTick(player=player, collision=collision, state=calm, dt=0.01);
    assert watcher.alert > 0.0;
}

test "skill shortens or lengthens attack pauses as the originals do" {
    q1 = Opponent(game="q1", skill=3);
    assert attack_pause(q1) == 0.0;
    # SUB_AttackFinished (2*random()) after a ranged attack; none after melee.
    q1.skill = 1;
    for sample in range(20) {
        pause = attack_pause(q1);
        assert pause >= 0.0 and pause <= 2.0;
    }
    assert attack_pause(q1, melee=True) == 0.0;
    # Q2 skill scales the attack chance rather than the pause.
    easy = Opponent(game="q2", skill=0);
    hard = Opponent(game="q2", skill=2);
    assert attack_chance(easy, 300.0, False) == 0.05;
    assert attack_chance(hard, 300.0, False) == 0.2;
    nightmare = Opponent(game="q1", skill=3, health=100);
    damage_opponent(nightmare, 20);
    assert nightmare.pain_cooldown >= 5.0;
}
