import from engine.world.world { Actor, Player }
import from engine.world.damage { Damage, Heal }
import from engine.world.environment { EnvironmentTick }
import from engine.world.inventory {
    AdjustInventory,
    quantity,
    InventorySlot,
    ItemStack
}


test "damage armor depletion bypass and death share actor behavior" {
    actor = Actor(health=100, armor=10, armor_ratio=0.8);
    hit = actor spawn Damage(amount=20);
    assert hit.absorbed == 10
        and hit.dealt == 10
        and actor.armor == 0
        and actor.health == 90;
    actor.armor = 100;
    hit = actor spawn Damage(amount=100, bypass_armor=True);
    assert hit.killed and actor.health == 0 and actor.armor == 100;
    repeated = actor spawn Damage(amount=10);
    assert not repeated.killed and repeated.dealt == 0;
}

test "player inherits actor health with normal and boosted healing caps" {
    player = Player(health=90);
    heal = player spawn Heal(amount=25);
    assert heal.restored == 10 and player.health == 100;
    player spawn Heal(amount=100, cap=200);
    assert player.health == 200;
    player spawn Heal(amount=25);
    assert player.health == 200;
    player.health = 0;
    player spawn Heal(amount=100);
    assert player.health == 0;
}

test "inventory slots clamp pickups and consumption without sharing between actors" {
    player = Player();
    other = Player();
    pickup = player.inventory spawn AdjustInventory(
        kind="shells", amount=30, capacity=100
    );
    assert pickup.accepted == 30 and quantity(player.inventory, "shells") == 30;
    pickup = player.inventory spawn AdjustInventory(
        kind="shells", amount=90, capacity=100
    );
    assert pickup.accepted == 70;
    used = player.inventory spawn AdjustInventory(kind="shells", amount=-120);
    assert used.accepted == -100 and quantity(player.inventory, "shells") == 0;
    assert quantity(other.inventory, "shells") == 0;
    assert len([player.inventory->:InventorySlot:->][?:ItemStack]) == 1;
    assert len([other.inventory->:InventorySlot:->][?:ItemStack]) == 0;
}

test "drowning has an air reserve ramps damage bypasses armor and resets above water" {
    player = Player(water_depth=3, liquid_kind=1, armor=100, armor_ratio=0.8);
    for i in range(1440) {
        player spawn EnvironmentTick(game="q2", dt=1.0 / 120.0);
    }
    assert player.health == 100;
    player spawn EnvironmentTick(game="q2", dt=1.0 / 120.0);
    assert player.health == 96 and player.armor == 100;
    for i in range(120) {
        player spawn EnvironmentTick(game="q2", dt=1.0 / 120.0);
    }
    assert player.health == 90;
    player.water_depth = 2;
    player spawn EnvironmentTick(game="q2", dt=1.0 / 120.0);
    assert player.air_remaining == 12.0 and player.drown_damage == 2;
}

test "liquid hazards respect game rates depth pause and noclip" {
    for game in ["q1", "q2", "q3"] {
        player = Player(health=1000, water_depth=2, liquid_kind=3);
        player spawn EnvironmentTick(game=game, dt=0.0);
        assert player.health == 1000;
        player spawn EnvironmentTick(game=game, dt=0.1, active=False);
        assert player.health == 1000;
        for i in range(120) {
            player spawn EnvironmentTick(game=game, dt=1.0 / 120.0);
        }
        expected = 900 if game == "q1" else (940 if game == "q2" else 880);
        assert player.health == expected;
    }
}
