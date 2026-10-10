import from engine.world.world { World, Player, Area, move_to_area }
import from engine.world.pickups {
    PickupRule,
    Pickup,
    HasPickup,
    PickupTick,
    ItemTeam,
    TeamMember,
    InTeam,
    respawn_wait,
    start_item_team,
    remove_pickup
}
import from engine.world.drops {
    ItemDrop,
    HasItemDrop,
    DropsAs,
    toss_items,
    TossTick,
    in_flight,
    restore_drop,
    dropped_items,
    flight_of
}
import from engine.core.savegame { snapshot, restore }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.world.powerups { Powerup, Empowered, powerup_left }
import from engine.world.inventory { quantity, AdjustInventory }
import from engine.world.models { ModelResource, powerup_shaders }
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

test "a Q2 item team starts with one member chosen at random and keeps to it" {
    # droptofloor hides the whole team and DoRespawn shows rand() % count;
    # nothing respawns in single player (mine3's megahealth or body armour).
    shown: list[int] = [];
    for seed in range(1, 40) {
        world = World();
        team = ItemTeam(name="lala", seed=seed);
        members = [armor(0.0), armor(1000.0)];
        for item in members {
            item.respawn = 0.0;
            team +>:TeamMember:+> item;
            item +>:InTeam:+> team;
            world +>:HasPickup:+> item;
        }
        chosen = start_item_team(team);
        assert chosen is not None;
        present = [i for i in range(2) if members[i].active];
        assert len(present) == 1 and members[present[0]] is chosen;
        absent = members[1 - present[0]];
        assert absent.benched and not absent.visual.visible and not chosen.benched;
        if present[0] not in shown {
            shown.append(present[0]);
        }
        # The one that is away cannot be picked up and never comes back.
        player = Player(health=100, pos=absent.pos.add(Vec3(z=10.0)));
        tick(world, player, 30.0);
        assert player.armor == 0 and not absent.active;
        player.pos = chosen.pos.add(Vec3(z=10.0));
        tick(world, player, 0.1);
        assert player.armor == 100 and not chosen.active;
        tick(world, player, 30.0);
        assert not any([item.active for item in members]);
    }
    assert len(shown) == 2;
    # A team of one is simply present.
    alone = ItemTeam(name="adren", seed=3);
    only = armor(0.0);
    alone +>:TeamMember:+> only;
    assert start_item_team(alone) is only and only.active and not only.benched;
}

test "an untouchable item is shown and stays where it is" {
    # ITEM_NO_TOUCH: droptofloor takes its touch away (a power cube in its
    # socket, shown once its trigger spawns it).
    world = World();
    cube = armor(0.0);
    cube.untouchable = True;
    cube.active = False;
    cube.waiting_for_use = True;
    cube.activate_on_use = True;
    world +>:HasPickup:+> cube;
    player = Player(health=100, pos=Vec3(z=10.0));
    tick(world, player, 0.5);
    assert not cube.active and player.armor == 0;
    cube.activation.pending = 1;
    tick(world, player, 0.5);
    assert cube.active and cube.visual.visible and player.armor == 0;
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
    # The body's origin stands 24 units over the floor, its eye 26 above that.
    victim = Player(health=0, pos=Vec3(z=50.0));
    move_to_area(victim, area);
    victim.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1, capacity=1);
    victim.inventory spawn AdjustInventory(kind="slugs", amount=3, capacity=200);
    victim +>:Empowered:+> Powerup(kind="quad", remaining=12.6);
    index = ArenaContactIndex();
    index.prepare(world);
    assert not index.pickups;
    items = toss_items(world, victim, "railgun", collision, 26.0);
    assert len(items) == 2 and all([item.dropped and item.active for item in items]);
    # Drop_Item throws each from the body's origin: the weapon straight
    # ahead, the powerup 45 degrees round, rising at first.
    assert all([in_flight(item) and abs(item.pos.z - 24.0) < 0.001 for item in items]);
    peak = 0.0;
    for step in range(200) {
        world spawn TossTick(collision=collision, dt=0.01);
        peak = max(peak, items[0].pos.z);
    }
    assert peak > 40.0;
    # They land a unit off the floor (their boxes reach 15 down) some way out.
    for item in items {
        assert not in_flight(item) and abs(item.pos.z - 16.0) < 0.5;
        assert item.pos.sub(Vec3()).length() > 60.0 and item.pos.sub(Vec3()).length() < 130.0;
    }
    assert abs(items[0].pos.y) < 0.001 and items[0].pos.x > 60.0;
    assert abs(items[1].pos.x - items[1].pos.y) < 0.5;
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
    # A dropped item stops dead against a wall (physicsBounce 0) and drops.
    wall = floor_map();
    wall.add_box(Vec3(x=40.0, y=-100.0, z=0.0), Vec3(x=48.0, y=100.0, z=200.0), Vec3(), Vec3(), Vec3());
    wall.reindex();
    victim.inventory spawn AdjustInventory(kind="slugs", amount=3, capacity=200);
    thrown = toss_items(world, victim, "railgun", wall, 26.0);
    for step in range(200) {
        world spawn TossTick(collision=wall, dt=0.01);
    }
    assert thrown[0].pos.x < 40.0 and thrown[0].pos.x > 30.0 and abs(thrown[0].pos.z - 16.0) < 0.5;
    victim.inventory spawn AdjustInventory(kind="slugs", amount=-3, capacity=200);
    # Machine guns, gauntlets and empty weapons stay with the body.
    assert not toss_items(world, victim, "machinegun", collision, 26.0);
    victim.inventory spawn AdjustInventory(kind="slugs", amount=-3, capacity=200);
    assert not toss_items(world, victim, "railgun", collision, 26.0);
}

test "powerups dress bodies and weapons in their shaders" {
    assert powerup_shaders([], 0.0) == [""];
    assert powerup_shaders(["quad"], 0.0) == ["", "powerups/quad"];
    assert powerup_shaders(["quad", "battlesuit"], 0.0, True) == ["", "powerups/quadWeapon", "powerups/battleWeapon"];
    # Invisibility replaces the model; regeneration flashes a tenth of the time.
    assert powerup_shaders(["invisibility", "quad"], 0.0) == ["powerups/invisibility"];
    assert powerup_shaders(["regen"], 0.15) == ["", "powerups/regen"];
    assert powerup_shaders(["regen"], 0.25) == [""];
}

test "dropped items are kept in saves: where they lie, the time they have left and a throw in the air" {
    world = World();
    area = Area(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    drop_table(world);
    collision = floor_map();
    victim = Player(health=0, pos=Vec3(z=50.0));
    move_to_area(victim, area);
    victim.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1, capacity=1);
    victim.inventory spawn AdjustInventory(kind="slugs", amount=3, capacity=200);
    victim +>:Empowered:+> Powerup(kind="quad", remaining=12.6);
    items = toss_items(world, victim, "railgun", collision, 26.0);
    # The railgun comes to rest; the quad is thrown again and still flying.
    for step in range(300) {
        world spawn TossTick(collision=collision, dt=0.01);
    }
    items[0].lifetime = 21.5;
    flying = restore_drop(world, "quad", Vec3(x=5.0, z=80.0), 0.5, area, 29.0, 7.0, Vec3(x=10.0, z=-20.0));
    assert flying is not None and in_flight(flying);
    remove_pickup(world, items[1]);
    level = Level();
    level.name = "test";
    player = Player(health=100);
    data = snapshot(world, level, player, CombatState());
    assert len([line for line in data.splitlines() if line.startswith("DROP ")]) == 2;
    # A fresh level has the drop table and none of the dropped items.
    fresh = World();
    drop_table(fresh);
    stray = restore_drop(fresh, "quad", Vec3(), 0.0, None, 30.0, 30.0);
    assert stray is not None;
    restore(fresh, level, player, CombatState(), data);
    kept = dropped_items(fresh);
    assert len(kept) == 2 and stray not in kept and not stray.active;
    rail = kept[0];
    assert rail.rule.kind == "weapon_railgun" and rail.active and not in_flight(rail);
    assert abs(rail.lifetime - 21.5) < 0.001 and rail.pos.sub(items[0].pos).length() < 0.001;
    quad = kept[1];
    carrier = flight_of(quad);
    assert quad.rule.powerup == "quad" and abs(quad.duration - 7.0) < 0.001 and abs(quad.lifetime - 29.0) < 0.001;
    assert carrier is not None and abs(carrier.velocity.x - 10.0) < 0.001 and abs(carrier.velocity.z + 20.0) < 0.001;
    assert abs(quad.yaw - 0.5) < 0.001 and abs(quad.pos.z - 80.0) < 0.001;
    # Bots are told of them again (BotUpdateEntityItems watches the serial).
    assert fresh.item_serial > 0;
}
