import from engine.world.world { World, Player, Area, move_to_area }
import from engine.world.pickups {
    PickupRule,
    Pickup,
    HasPickup,
    PickupTick,
    ItemTeam,
    TeamMember,
    InTeam,
    respawn_wait
}
import from engine.world.drops { ItemDrop, HasItemDrop, DropsAs, toss_items }
import from engine.world.powerups { Powerup, Empowered, powerup_left }
import from engine.world.inventory { quantity, AdjustInventory }
import from engine.world.models { ModelResource }
import from engine.world.arena_navigation { ArenaContactIndex }
import from engine.formats.animated { AnimatedModel }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

def armor(x: float) -> Pickup {
    return Pickup(pos=Vec3(x=x), respawn=25.0, rule=PickupRule(kind="armor", amount=100, capacity=200, model="", armor_mode="add", armor_ratio=0.66));
}

def tick(world: World, player: Player, seconds: float) {
    for step in range(int(seconds * 10.0 + 0.5)) {
        world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=0.1);
    }
}

test "a team shows one member and respawns a random one (RespawnItem)" {
    world = World();
    team = ItemTeam(name="armor", seed=7);
    members = [armor(0.0), armor(1000.0), armor(2000.0)];
    for i in range(3) {
        item = members[i];
        if i > 0 {
            item.benched = True;
            item.active = False;
        }
        team +>:TeamMember:+> item;
        item +>:InTeam:+> team;
        world +>:HasPickup:+> item;
    }
    player = Player(health=100, pos=Vec3(z=10.0));
    tick(world, player, 0.1);
    assert not members[0].active and player.armor == 100;
    # Benched members never come back on their own.
    player.pos = Vec3(z=-100000.0);
    tick(world, player, 10.0);
    assert not any([item.active for item in members]);
    seen: list[int] = [];
    for attempt in range(12) {
        tick(world, player, 26.0);
        shown = [i for i in range(3) if members[i].active];
        assert len(shown) == 1;
        if shown[0] not in seen {
            seen.append(shown[0]);
        }
        # Take it again wherever it appeared.
        player.pos = members[shown[0]].pos.add(Vec3(z=10.0));
        player.armor = 0;
        tick(world, player, 0.1);
        assert not members[shown[0]].active;
        player.pos = Vec3(z=-100000.0);
    }
    assert len(seen) >= 2;
}

test "the random key spreads respawn waits, never below a second" {
    item = armor(0.0);
    item.jitter = 15.0;
    item.respawn = 10.0;
    waits = [respawn_wait(item) for i in range(40)];
    assert min(waits) >= 1.0 and max(waits) <= 25.0 and max(waits) - min(waits) > 10.0;
    item.jitter = 0.0;
    assert respawn_wait(item) == 10.0;
}

def drop_table(world: World) {
    model = ModelResource(name="rail", model=AnimatedModel(), skins=[]);
    rail = ItemDrop(kind="weapon_railgun", rule=PickupRule(kind="weapon_railgun", amount=1, capacity=1, model="", ammo="slugs", ammo_amount=10, ammo_capacity=200));
    rail +>:DropsAs:+> model;
    quad = ItemDrop(kind="quad", rule=PickupRule(kind="powerup", amount=1, capacity=1, model="", powerup="quad", duration=30.0));
    quad +>:DropsAs:+> ModelResource(name="quad", model=AnimatedModel(), skins=[]);
    world +>:HasItemDrop:+> rail;
    world +>:HasItemDrop:+> quad;
}

def floor_map() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(Vec3(x=-2000.0, y=-2000.0, z=-64.0), Vec3(x=2000.0, y=2000.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    return collision;
}

test "a dying player drops its weapon and powerups, which vanish after 30 s" {
    world = World();
    area = Area(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    drop_table(world);
    collision = floor_map();
    victim = Player(health=0, pos=Vec3(z=26.0));
    move_to_area(victim, area);
    victim.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1, capacity=1);
    victim.inventory spawn AdjustInventory(kind="slugs", amount=3, capacity=200);
    victim +>:Empowered:+> Powerup(kind="quad", remaining=12.6);
    index = ArenaContactIndex();
    index.prepare(world);
    assert not index.pickups;
    items = toss_items(world, victim, "railgun", collision, 26.0);
    assert len(items) == 2 and all([item.dropped and item.active for item in items]);
    # Dropped items rest on the floor, and the bots' index sees them.
    assert abs(items[0].pos.z - 15.0) < 0.5;
    index.prepare(world);
    assert len(index.pickups) == 2;
    # The quad keeps the carrier's remaining whole seconds.
    taker = Player(health=100, pos=items[1].pos.add(Vec3(y=26.0, z=10.0)));
    tick(world, taker, 0.1);
    assert powerup_left(taker, "quad") == 12.0;
    assert len([world->:HasPickup:->][?:Pickup]) == 1;
    # The rest are freed after thirty seconds.
    taker.pos = Vec3(z=-100000.0);
    tick(world, taker, 30.0);
    assert not [world->:HasPickup:->][?:Pickup];
    # Machine guns, gauntlets and empty weapons stay with the body.
    assert not toss_items(world, victim, "machinegun", collision, 26.0);
    victim.inventory spawn AdjustInventory(kind="slugs", amount=-3, capacity=200);
    assert not toss_items(world, victim, "railgun", collision, 26.0);
}
