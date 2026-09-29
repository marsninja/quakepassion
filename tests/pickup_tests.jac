import from engine.world.pickups {
    Pickup,
    PickupRule,
    PickupTick,
    HasPickup,
    pickup_contact,
    touch_reach
}
import from engine.world.world { World, Player }
import from engine.world.inventory { quantity }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }


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

def reach_at(game: str, rule: PickupRule, top_drop: float = 0.0) -> AABB {
    return touch_reach(
        game,
        rule,
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0 - top_drop)
    );
}

test "pickup sweeps include fast crossings and the shorter crouch hull" {
    rule = PickupRule(kind="shells", amount=10, capacity=100, model="");
    # Q2 boxes: the item 15 each way and the player's, each a unit bigger.
    reach = reach_at("q2", rule);
    assert reach.mins.x == -33.0 and reach.maxs.x == 33.0;
    assert reach.mins.z == -49.0 and reach.maxs.z == 41.0;
    assert pickup_contact(Vec3(x=-100.0), Vec3(x=100.0), reach);
    assert not pickup_contact(Vec3(x=-100.0, y=34.0), Vec3(x=100.0, y=34.0), reach);
    # Crouched (a 28-unit shorter box) the player no longer reaches up to an
    # item 40 units above its origin.
    under = Vec3(z=-40.0);
    assert pickup_contact(under, under, reach);
    assert not pickup_contact(under, under, reach_at("q2", rule, 28.0));
}

test "each game touches an item where its own boxes meet" {
    health = PickupRule(kind="health", amount=25, capacity=100, model="");
    # Q1 health and ammo reach from their origin to '32 32 56', widened 15
    # across (FL_ITEM): touched from 64 to one side and only 32 to the other.
    reach = reach_at("q1", health);
    assert reach.mins.x == -32.0 and reach.maxs.x == 64.0;
    assert reach.mins.z == -33.0 and reach.maxs.z == 81.0;
    assert pickup_contact(Vec3(x=60.0), Vec3(x=60.0), reach);
    assert not pickup_contact(Vec3(x=-40.0), Vec3(x=-40.0), reach);
    # Keys and artifacts reach from '-16 -16 -24'.
    key = PickupRule(kind="key", amount=1, capacity=1, model="", mins=Vec3(x=-16.0, y=-16.0, z=-24.0));
    reach = reach_at("q1", key);
    assert reach.mins.x == -48.0 and reach.maxs.x == 48.0;
    assert reach.mins.z == -57.0 and reach.maxs.z == 57.0;
    # Q3 BG_PlayerTouchesItem: 44 ahead and 50 behind across x, 36 otherwise.
    reach = reach_at("q3", health);
    assert pickup_contact(Vec3(x=-48.0), Vec3(x=-48.0), reach);
    assert not pickup_contact(Vec3(x=46.0), Vec3(x=46.0), reach);
    assert not pickup_contact(Vec3(y=37.0), Vec3(y=37.0), reach);
    # The whole tick goes by the item's own box: a Q1 player 60 units off to
    # the far side of a health box takes it, 40 units before it does not.
    for scenario in [(60.0, True), (-40.0, False)] {
        world = World();
        item = Pickup(rule=PickupRule(kind="health", amount=25, capacity=100, model=""));
        world +>:HasPickup:+> item;
        player = Player(health=50);
        spot = Vec3(x=scenario[0], y=16.0);
        result = world spawn PickupTick(player=player, start=spot, finish=spot, dt=0.01, game="q1");
        assert (result.collected == 1) == scenario[1];
    }
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
