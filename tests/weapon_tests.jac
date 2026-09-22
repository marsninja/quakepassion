import from games.weapons { equip_player, weapon_rules }
import from games.items { pickup_rule }
import from engine.world.combat {
    CombatState,
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    ProjectileTick,
    fire_weapon,
    select_weapon
}
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from engine.physics.collision { CollisionMap }

test "original loadouts require owned weapons and grant appropriate starting ammo" {
    for game in ["q1", "q2", "q3"] {
        player = Player();
        state = CombatState();
        equip_player(player, state, game);
        assert quantity(player.inventory, "weapon_" + state.rules[0].key) == 1;
        assert not select_weapon(player, state, 7);
        assert select_weapon(player, state, 1);
        if game == "q1" {
            assert quantity(player.inventory, "shells") == 25;
        } elif game == "q3" {
            assert quantity(player.inventory, "bullets") == 100;
        } else {
            assert quantity(player.inventory, "shells") == 0;
        }
    }
}

test "weapon pickup grants ownership and ammo and remains when both are full" {
    rule = pickup_rule("q2", {"classname": "weapon_railgun"});
    assert rule is not None;
    world = World();
    player = Player();
    state = CombatState();
    equip_player(player, state, "q2");
    item = Pickup(rule=rule);
    world +>:HasPickup:+> item;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert not item.active and select_weapon(player, state, 9);
    assert quantity(player.inventory, "slugs") == 10;
    player.inventory spawn AdjustInventory(kind="slugs", amount=100, capacity=50);
    item.active = True;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert item.active;
    player.inventory spawn AdjustInventory(kind="slugs", amount=-1);
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert not item.active and quantity(player.inventory, "slugs") == 50;
}

test "pellets aggregate before armor and rail hits pierce actors but stop at walls" {
    world = World();
    player = Player();
    state = CombatState();
    collision = CollisionMap();
    equip_player(player, state, "q1");
    enemy = Opponent(pos=Vec3(x=70.0), health=100, armor=100, armor_ratio=0.3);
    world +>:HasOpponent:+> enemy;
    assert fire_weapon(world, player, collision, state);
    assert enemy.health == 84 and enemy.armor == 92;
    equip_player(player, state, "q2");
    state.cooldown = 0.0;
    player.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1);
    player.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=50);
    assert select_weapon(player, state, 9);
    enemy.health = 200;
    enemy.armor = 0;
    second = Opponent(pos=Vec3(x=170.0), health=200);
    third = Opponent(pos=Vec3(x=300.0), health=200);
    world +>:HasOpponent:+> second;
    world +>:HasOpponent:+> third;
    collision.add_box(
        Vec3(x=220.0, y=-100.0, z=-100.0),
        Vec3(x=230.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    assert fire_weapon(world, player, collision, state);
    assert enemy.health == 50 and second.health == 50 and third.health == 200;
    assert quantity(player.inventory, "slugs") == 9;
}

test "blaster uses traveling projectiles and swept collision prevents tunneling" {
    world = World();
    player = Player();
    state = CombatState();
    collision = CollisionMap();
    equip_player(player, state, "q2");
    enemy = Opponent(pos=Vec3(x=100.0), health=60);
    world +>:HasOpponent:+> enemy;
    assert fire_weapon(world, player, collision, state) and enemy.health == 60;
    world spawn ProjectileTick(
        player=player, collision=collision, state=state, dt=0.01
    );
    assert enemy.health == 60;
    world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.2);
    assert enemy.health == 50 and not [world->:HasProjectile:->];
    state.cooldown = 0.0;
    collision.add_box(
        Vec3(x=40.0, y=-100.0, z=-100.0),
        Vec3(x=41.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    assert fire_weapon(world, player, collision, state);
    world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.2);
    assert enemy.health == 50 and not [world->:HasProjectile:->];
}

test "explosions exclude direct target from splash respect walls and credit once" {
    world = World();
    player = Player(pos=Vec3(x=-500.0));
    state = CombatState(game="q3");
    collision = CollisionMap();
    direct = Opponent(pos=Vec3(x=100.0), health=110);
    exposed = Opponent(pos=Vec3(x=100.0, y=50.0), health=30);
    sheltered = Opponent(pos=Vec3(x=100.0, y=-50.0), health=100);
    world +>:HasOpponent:+> direct;
    world +>:HasOpponent:+> exposed;
    world +>:HasOpponent:+> sheltered;
    collision.add_box(
        Vec3(x=0.0, y=-30.0, z=-100.0),
        Vec3(x=200.0, y=-25.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    world +>:HasProjectile:+> Projectile(
        pos=Vec3(), velocity=Vec3(x=1000.0), damage=100, splash=100, radius=120.0
    );
    world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.2);
    assert direct.health == 10 and exposed.health == 0 and sheltered.health == 100;
    assert state.kills == 1 and not [world->:HasProjectile:->];
}

test "grenades bounce retain fuse and resume identically after save" {
    world = World();
    player = Player(pos=Vec3(x=-500.0));
    state = CombatState();
    level = Level(name="fixture");
    level.collision.add_box(
        Vec3(x=40.0, y=-100.0, z=-100.0),
        Vec3(x=41.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    projectile = Projectile(
        pos=Vec3(),
        velocity=Vec3(x=500.0),
        damage=100,
        splash=100,
        radius=120.0,
        gravity=True,
        remaining=0.5
    );
    world +>:HasProjectile:+> projectile;
    world spawn ProjectileTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert projectile.velocity.x < 0.0 and projectile.remaining == 0.4;
    data = snapshot(world, level, player, state);
    world spawn ProjectileTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    expected = snapshot(world, level, player, state);
    restore(world, level, player, state, data);
    world spawn ProjectileTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert snapshot(world, level, player, state) == expected;
    world spawn ProjectileTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert not [world->:HasProjectile:->];
}

test "weapon spread resumes deterministically after save and all ammo types load" {
    world = World();
    player = Player();
    state = CombatState();
    level = Level(name="fixture");
    equip_player(player, state, "q1");
    before = snapshot(world, level, player, state);
    assert fire_weapon(world, player, level.collision, state);
    seed = state.random_state;
    point = state.target;
    restore(world, level, player, state, before);
    assert fire_weapon(world, player, level.collision, state);
    assert state.random_state == seed and state.target.sub(point).length() < 0.000001;
    for game in ["q1", "q2", "q3"] {
        for weapon in weapon_rules(game) {
            if weapon.model {
                assert pickup_rule(game, {"classname": "weapon_" + weapon.key})
                    is not None;
            }
            if weapon.ammo {
                name = "item_" + ("spikes" if weapon.ammo == "nails" else weapon.ammo)
                    if game == "q1"
                    else "ammo_" + weapon.ammo;
                assert pickup_rule(game, {"classname": name}) is not None;
            }
        }
    }
}
