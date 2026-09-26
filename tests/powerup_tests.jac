import from engine.world.powerups {
    Powerup,
    Empowered,
    GrantPowerup,
    PowerupTick,
    UseItem,
    effect,
    empowered,
    powerup_left,
    damage_scale,
    owned_items
}
import from engine.world.damage { Damage }
import from engine.world.environment { EnvironmentTick }
import from engine.world.pickups { Pickup, PickupRule, HasPickup, PickupTick }
import from engine.world.models { ModelResource, GatherModels, attach_model }
import from engine.formats.animated { AnimatedModel }
import from engine.world.combat { CombatState, Opponent, HasOpponent, fire_weapon, CombatTick }
import from engine.world.world { World, Player, Area, In, move_to_area }
import from engine.world.level { Level }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from games.items { pickup_rule, item_spin }
import from games.weapons { equip_player }

def collect(player: Player, game: str, fields: dict[str, str]) -> PickupTick {
    rule = pickup_rule(game, fields);
    assert rule is not None;
    world = World();
    world +>:HasPickup:+> Pickup(rule=rule);
    return world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
}

test "Q1 artifacts grant thirty seconds with original cues and no stacking" {
    player = Player();
    result = collect(player, "q1", {"classname": "item_artifact_super_damage"});
    assert result.collected == 1 and powerup_left(player, "quad") == 30.0;
    assert result.sounds == ["sound/items/damage.wav"];
    assert result.messages == ["You got the Quad Damage"];
    player spawn PowerupTick(game="q1", dt=20.0);
    collect(player, "q1", {"classname": "item_artifact_super_damage"});
    assert powerup_left(player, "quad") == 30.0;
    assert damage_scale(player, "q1") == 4.0 and damage_scale(player, "q3") == 3.0;
}

test "expiry warnings follow each game and expired effects leave the graph" {
    player = Player();
    player spawn GrantPowerup(kind="invisibility", duration=30.0);
    early = player spawn PowerupTick(game="q1", dt=26.0);
    assert not early.cues;
    warned = player spawn PowerupTick(game="q1", dt=1.5);
    assert warned.cues == ["sound/items/inv2.wav"];
    assert warned.messages == ["Ring of Shadows magic is fading"];
    done = player spawn PowerupTick(game="q1", dt=3.0);
    assert done.expired == ["invisibility"] and effect(player, "invisibility") is None;
    arena = Player();
    arena spawn GrantPowerup(kind="quad", duration=10.0, additive=True);
    arena spawn GrantPowerup(kind="quad", duration=10.0, additive=True);
    assert powerup_left(arena, "quad") == 20.0;
    cues: list[str] = [];
    for i in range(40) {
        cues.extend((arena spawn PowerupTick(game="q3", dt=0.5)).cues);
    }
    assert cues.count("sound/items/wearoff.wav") == 5;
}

test "invulnerability blocks harm except telefrags and cues protected hits" {
    player = Player(health=100, armor=50, armor_ratio=0.3);
    player spawn GrantPowerup(kind="invulnerability", duration=30.0);
    hit = player spawn Damage(amount=80);
    assert hit.protected and player.health == 100 and player.armor == 50;
    tick = player spawn PowerupTick(game="q2", dt=0.01);
    assert tick.cues == ["sound/items/protect4.wav"];
    player spawn Damage(amount=80);
    assert not (player spawn PowerupTick(game="q2", dt=0.01)).cues;
    player spawn Damage(amount=100000, bypass_armor=True, bypass_protection=True);
    assert player.health == 0;
}

test "battle suit ignores splash environment and falls and halves direct damage" {
    player = Player(health=100);
    player spawn GrantPowerup(kind="battlesuit", duration=30.0);
    for means in ["splash", "environment", "drown", "fall"] {
        player spawn Damage(amount=50, means=means);
    }
    assert player.health == 100;
    player spawn Damage(amount=41);
    assert player.health == 80;
    player spawn Damage(amount=1);
    assert player.health == 79;
}

test "Q2 power screen spends cells only against frontal hits and shield covers all" {
    player = Player(health=100, yaw=0.0);
    player.inventory spawn AdjustInventory(kind="cells", amount=50, capacity=200);
    player.inventory spawn AdjustInventory(kind="power_screen", amount=1);
    used = player spawn UseItem(game="q2", kind="power_screen");
    assert used.used and effect(player, "power_screen") is not None;
    assert quantity(player.inventory, "power_screen") == 1;
    front = player spawn Damage(amount=30, source=Vec3(x=100.0));
    assert front.shielded == 10 and player.health == 80;
    assert quantity(player.inventory, "cells") == 40;
    behind = player spawn Damage(amount=30, source=Vec3(x=-100.0));
    assert behind.shielded == 0 and player.health == 50;
    player.inventory spawn AdjustInventory(kind="power_shield", amount=1);
    player spawn UseItem(game="q2", kind="power_shield");
    assert effect(player, "power_screen") is None;
    side = player spawn Damage(amount=30, source=Vec3(y=-100.0));
    assert side.shielded == 20 and player.health == 40;
    assert quantity(player.inventory, "cells") == 30;
    player spawn UseItem(game="q2", kind="power_shield");
    assert effect(player, "power_shield") is None;
}

test "Q2 stores powerups by skill limit and use extends active timers" {
    player = Player();
    for i in range(3) {
        collect(player, "q2", {"classname": "item_quad"});
    }
    assert quantity(player.inventory, "powerup_quad") == 2;
    assert owned_items(player.inventory, "q2") == ["powerup_quad"];
    first = player spawn UseItem(game="q2", kind="powerup_quad");
    assert first.used and first.cue == "sound/items/damage.wav";
    player spawn UseItem(game="q2", kind="powerup_quad");
    assert powerup_left(player, "quad") == 60.0;
    assert quantity(player.inventory, "powerup_quad") == 0;
    collect(player, "q2", {"classname": "item_silencer"});
    player spawn UseItem(game="q2", kind="powerup_silencer");
    silencer = effect(player, "silencer");
    assert silencer is not None and silencer.count == 30;
}

test "Q2 adrenaline bandolier pack and shards follow their original tables" {
    player = Player(health=40);
    collect(player, "q2", {"classname": "item_adrenaline"});
    assert player.max_health == 101 and player.health == 101;
    collect(player, "q2", {"classname": "item_ancient_head"});
    assert player.max_health == 103 and player.health == 101;
    collect(player, "q2", {"classname": "item_bandolier"});
    assert quantity(player.inventory, "bullets") == 50;
    player.inventory spawn AdjustInventory(kind="shells", amount=500);
    assert quantity(player.inventory, "shells") == 150;
    collect(player, "q2", {"classname": "item_pack"});
    player.inventory spawn AdjustInventory(kind="rockets", amount=500);
    assert quantity(player.inventory, "rockets") == 100;
    shard = collect(player, "q2", {"classname": "item_armor_shard"});
    assert player.armor == 2 and player.armor_ratio == 0.3;
    assert shard.sounds == ["sound/misc/ar2_pkup.wav"];
}

test "megahealth rots after five seconds and Q3 regeneration overcharges" {
    player = Player(health=100);
    collect(player, "q2", {"classname": "item_health_mega"});
    assert player.health == 200;
    player spawn PowerupTick(game="q2", dt=4.5);
    assert player.health == 200;
    player spawn PowerupTick(game="q2", dt=1.0);
    assert player.health == 199;
    player.health = 101;
    player spawn PowerupTick(game="q2", dt=5.0);
    assert player.health == 100 and effect(player, "megahealth") is None;
    arena = Player(health=50, armor=103);
    arena spawn GrantPowerup(kind="regen", duration=30.0);
    tick = arena spawn PowerupTick(game="q3", dt=1.0);
    assert arena.health == 65 and arena.armor == 102;
    assert tick.cues == ["sound/items/regen.wav"];
    arena.health = 105;
    arena spawn PowerupTick(game="q3", dt=1.0);
    assert arena.health == 110;
    arena spawn PowerupTick(game="q3", dt=30.0);
    assert arena.health == 100 and effect(arena, "regen") is None;
}

test "Q3 holdables are exclusive and the medkit heals past maximum" {
    player = Player(health=20);
    collect(player, "q3", {"classname": "holdable_medkit"});
    assert collect(player, "q3", {"classname": "holdable_teleporter"}).collected == 0;
    used = player spawn UseItem(game="q3", kind="holdable_medkit");
    assert used.used and player.health == 125;
    assert used.cue == "sound/items/use_medkit.wav";
    assert collect(player, "q3", {"classname": "holdable_teleporter"}).collected == 1;
    assert (player spawn UseItem(game="q3", kind="holdable_teleporter")).teleport;
}

test "suits protect from liquids and drowning with original damage rates" {
    player = Player(health=100, water_depth=3, liquid_kind=2);
    player spawn GrantPowerup(kind="suit", duration=30.0);
    player spawn EnvironmentTick(game="q1", dt=20.0);
    assert player.health == 100 and player.air_remaining == 12.0;
    player.liquid_kind = 3;
    player spawn EnvironmentTick(game="q2", dt=0.01);
    assert player.health == 97;
    lava = Player(health=100, water_depth=1, liquid_kind=3);
    lava spawn GrantPowerup(kind="suit", duration=30.0);
    lava spawn EnvironmentTick(game="q1", dt=0.01);
    assert lava.health == 90 and lava.hazard_wait == 1.0;
    diver = Player(health=100, water_depth=3, liquid_kind=1);
    diver spawn GrantPowerup(kind="breather", duration=30.0);
    diver spawn EnvironmentTick(game="q2", dt=20.0);
    assert diver.health == 100;
}

test "quad scales hitscan damage and haste shortens the refire interval" {
    world = World();
    player = Player();
    state = CombatState();
    collision = CollisionMap();
    equip_player(player, state, "q1");
    enemy = Opponent(pos=Vec3(x=70.0), health=200);
    world +>:HasOpponent:+> enemy;
    player spawn GrantPowerup(kind="quad", duration=30.0);
    assert fire_weapon(world, player, collision, state);
    assert enemy.health == 200 - 24 * 4;
    normal = state.cooldown;
    state.cooldown = 0.0;
    player spawn GrantPowerup(kind="haste", duration=30.0);
    fire_weapon(world, player, collision, state);
    assert abs(state.cooldown - normal / 1.3) < 0.0001;
}

test "haste raises walking speed and flight removes gravity" {
    collision = CollisionMap();
    runner = Player(pos=Vec3(z=1000.0));
    runner spawn GrantPowerup(kind="haste", duration=30.0);
    runner.grounded = True;
    for i in range(240) {
        runner spawn MovePlayer(collision=collision, wish=Vec3(x=1.0), dt=1.0 / 120.0);
        runner.velocity.z = 0.0;
        runner.pos.z = 1000.0;
    }
    assert runner.velocity.x > 330.0;
    flyer = Player(pos=Vec3(z=1000.0));
    flyer spawn GrantPowerup(kind="flight", duration=60.0);
    for i in range(120) {
        flyer spawn MovePlayer(collision=collision, swim_wish=Vec3(z=1.0), dt=1.0 / 120.0);
    }
    assert flyer.pos.z > 1100.0 and flyer.velocity.z > 0.0;
}

test "invisible players are not newly noticed but hunters keep pursuing" {
    world = World();
    player = Player(pos=Vec3(x=300.0));
    player spawn GrantPowerup(kind="invisibility", duration=30.0);
    enemy = Opponent(pos=Vec3(), health=50);
    world +>:HasOpponent:+> enemy;
    state = CombatState();
    collision = CollisionMap();
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.2);
    assert enemy.alert == 0.0 and not enemy.sighted;
    enemy.alert = 5.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.2);
    assert enemy.sighted;
}

test "snapshots round trip active powerups and rot clocks" {
    world = World();
    # Pickup records share the snapshot; their tags must not collide.
    world +>:HasPickup:+> Pickup(rule=PickupRule(kind="shells", amount=1, capacity=9, model=""));
    level = Level();
    level.name = "test";
    player = Player(health=150);
    player spawn GrantPowerup(kind="quad", duration=12.5);
    rot = Powerup(kind="megahealth", remaining=-1.0, clock=0.25);
    player +>:Empowered:+> rot;
    silence = Powerup(kind="silencer", remaining=-1.0, count=7);
    player +>:Empowered:+> silence;
    combat = CombatState();
    data = snapshot(world, level, player, combat);
    player spawn PowerupTick(game="q1", dt=20.0);
    restore(world, level, player, combat, data);
    assert powerup_left(player, "quad") == 12.5;
    restored = effect(player, "megahealth");
    assert restored is not None and restored.clock == 0.25;
    muted = effect(player, "silencer");
    assert muted is not None and muted.count == 7;
    assert len([player->:Empowered:->]) == 3;
    try {
        restore(world, level, player, combat, data.replace("POWER quad", "POWER bogus"));
        assert False;
    } except ValueError {}
}

test "original item tables resolve models and Q3 powerup respawn rules" {
    mega = pickup_rule("q2", {"classname": "item_health_mega"});
    assert mega is not None and mega.model == "models/items/mega_h/tris.md2" and mega.rot;
    q1mega = pickup_rule("q1", {"classname": "item_health", "spawnflags": "2"});
    assert q1mega is not None and q1mega.rot and q1mega.capacity == 250;
    flight = pickup_rule("q3", {"classname": "item_flight"});
    assert flight is not None and flight.duration == 60.0 and flight.additive;
    counted = pickup_rule("q3", {"classname": "item_quad", "count": "15"});
    assert counted is not None and counted.duration == 15.0;
    screen = pickup_rule("q2", {"classname": "item_power_screen"});
    assert screen is not None and screen.model == "models/items/armor/screen/tris.md2";
    assert pickup_rule("q1", {"classname": "item_quad"}) is None;
}

test "items spin and bob on the world clock per original client rules" {
    world = World();
    area = Area(name="a", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    item = Pickup(rule=PickupRule(kind="armor", amount=1, capacity=1, model=""), yaw=0.5);
    move_to_area(item, area);
    visual = attach_model(item, ModelResource(name="m", model=AnimatedModel(), skins=[]));
    still = world spawn GatherModels(seconds=1.0);
    assert still.draws[0].yaw == 0.5;
    visual.spin = 90.0;
    visual.bob = 4.0;
    turned = world spawn GatherModels(seconds=1.0);
    assert abs(turned.draws[0].yaw - 1.5707963) < 0.0001;
    assert turned.draws[0].origin.z > 0.0 and turned.draws[0].origin.z <= 8.0;
    shells = PickupRule(kind="shells", amount=1, capacity=1, model="");
    assert item_spin("q1", shells, 8) == 100.0 and item_spin("q1", shells, 0) == 0.0;
    assert item_spin("q2", shells, 0) == 0.0;
    assert item_spin("q2", PickupRule(kind="armor", amount=1, capacity=1, model=""), 0) == 100.0;
    assert abs(item_spin("q3", shells, 0) - 175.78125) < 0.0001;
}

test "pickups carry their original per-game sounds" {
    shotgun = pickup_rule("q1", {"classname": "weapon_supershotgun"});
    assert shotgun is not None and shotgun.sound == "sound/weapons/pkup.wav";
    key = pickup_rule("q1", {"classname": "item_key1"}, 2);
    assert key is not None and key.sound == "sound/misc/basekey.wav";
    medium = pickup_rule("q2", {"classname": "item_health"});
    assert medium is not None and medium.sound == "sound/items/n_health.wav";
    rockets = pickup_rule("q3", {"classname": "ammo_rockets"});
    assert rockets is not None and rockets.sound == "sound/misc/am_pkup.wav";
    orb = pickup_rule("q3", {"classname": "item_health_large"});
    assert orb is not None and orb.extra_model == "models/powerups/health/large_sphere.md3";
}
