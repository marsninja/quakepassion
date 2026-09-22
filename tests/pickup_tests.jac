import from engine.world.pickups {
    Pickup,
    PickupRule,
    PickupTick,
    HasPickup,
    pickup_contact
}
import from engine.world.world { World, Player }
import from engine.world.inventory { quantity }
import from engine.math.vec3 { Vec3 }


test "health pickup stays at full health and hides only after accepted healing" {
    world = World();
    item = Pickup(rule=PickupRule(kind="health", amount=25, capacity=100, model=""));
    world +>:HasPickup:+> item;
    player = Player();
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert item.active and item.visual.visible;
    player.health = 80;
    result = world spawn PickupTick(
        player=player, start=Vec3(), finish=Vec3(), dt=0.01
    );
    assert result.collected == 1 and player.health == 100;
    assert not item.active and not item.visual.visible;
    player.health = 50;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=60.0);
    assert player.health == 50;
}

test "arena pickups pause respawn and ignore dead or flying players" {
    world = World();
    item = Pickup(
        rule=PickupRule(kind="shells", amount=10, capacity=100, model=""), respawn=1.0
    );
    world +>:HasPickup:+> item;
    player = Player();
    world spawn PickupTick(
        player=player, start=Vec3(), finish=Vec3(), dt=0.1, touching=False
    );
    assert item.active;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.1);
    assert quantity(player.inventory, "shells") == 10 and not item.active;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.0);
    assert item.remaining == 1.0;
    player.health = 0;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=1.0);
    assert item.active
        and item.visual.visible
        and quantity(player.inventory, "shells") == 10;
}

test "pickup sweeps include fast crossings and the shorter crouch hull" {
    assert pickup_contact(Vec3(x=-100.0), Vec3(x=100.0), Vec3(), 0.0);
    assert not pickup_contact(
        Vec3(x=-100.0, y=33.0), Vec3(x=100.0, y=33.0), Vec3(), 0.0
    );
    assert pickup_contact(Vec3(), Vec3(), Vec3(z=40.0), 0.0);
    assert not pickup_contact(Vec3(), Vec3(), Vec3(z=40.0), 28.0);
}

test "armor supports Q2 salvage and Q3 capped accumulation" {
    world = World();
    armor = Pickup(
        rule=PickupRule(
            kind="armor",
            amount=100,
            capacity=200,
            model="",
            armor_ratio=0.8,
            armor_mode="salvage"
        )
    );
    world +>:HasPickup:+> armor;
    player = Player(armor=50, armor_ratio=0.3, armor_capacity=50);
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert player.armor == 118
        and player.armor_ratio == 0.8
        and player.armor_capacity == 200;
    armor.active = True;
    armor.rule = PickupRule(
        kind="armor",
        amount=25,
        capacity=50,
        model="",
        armor_ratio=0.3,
        armor_mode="salvage"
    );
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert player.armor == 127 and player.armor_ratio == 0.8;
    armor.active = True;
    armor.rule = PickupRule(
        kind="armor",
        amount=100,
        capacity=200,
        model="",
        armor_ratio=2.0 / 3.0,
        armor_mode="add"
    );
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert player.armor == 200;
}

test "trigger spawn items await use and Q2 one use does not resurrect consumed items" {
    world = World();
    player = Player(health=50);
    item = Pickup(
        rule=PickupRule(kind="health", amount=25, capacity=100, model=""),
        active=False,
        waiting_for_use=True,
        activate_on_use=True
    );
    item.visual.visible = False;
    world +>:HasPickup:+> item;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=100.0);
    assert player.health == 50 and item.waiting_for_use and not item.active;
    item.activation.pending = 1;
    world spawn PickupTick(
        player=player, start=Vec3(), finish=Vec3(), dt=0.01, touching=False
    );
    assert item.active and item.visual.visible and not item.activate_on_use;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert player.health == 75 and not item.active;
    item.activation.pending = 1;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=1.0);
    assert player.health == 75 and not item.active;
}

test "Q3 targeted items do not time-spawn before activation and support reuse" {
    world = World();
    player = Player(health=10);
    item = Pickup(
        rule=PickupRule(kind="health", amount=25, capacity=100, model=""),
        active=False,
        waiting_for_use=True,
        activate_on_use=True,
        reusable_use=True,
        respawn=35.0
    );
    world +>:HasPickup:+> item;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=100.0);
    assert player.health == 10 and item.waiting_for_use;
    item.activation.pending = 1;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert player.health == 35 and not item.active and not item.waiting_for_use;
    item.activation.pending = 1;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert player.health == 60 and not item.active and item.remaining == 35.0;
}
