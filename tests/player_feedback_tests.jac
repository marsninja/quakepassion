"""The player's own weapons, damage and movement: knockback, rocket jumps,
jumping, falling, weapon handling, trails, explosions and view feedback."""
import from games.weapons { equip_player }
import from games.items { pickup_rule }
import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    ProjectileTick,
    fire_weapon,
    weapon_input,
    select_weapon,
    change_weapon,
    cycle_weapon,
    pickup_switch,
    blast_actors,
    strike
}
import from engine.world.world { World, Player }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from engine.world.particles { ShotTrail, HasTrail, Explosion, HasExplosion }
import from engine.world.vitals { CrashLand, VoiceTick }
import from engine.world.damage { Damage, Heal }
import from engine.render.view_feedback { ViewFeedback }
import from engine.physics.collision { HullCell, HullFront, HullBack, CollisionMap }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }

def pf_floor() -> CollisionMap {
    cell = HullCell(normal=Vec3(z=1.0), distance=24.0);
    cell +>:HullFront:+> HullCell(contents=-1);
    cell +>:HullBack:+> HullCell(contents=-2);
    return CollisionMap(hulls=[cell], offsets=[Vec3()]);
}

def pf_armed(game: str) -> tuple[Player, CombatState] {
    player = Player();
    state = CombatState();
    equip_player(player, state, game);
    return (player, state);
}

test "knockback follows each game's rules" {
    # Q1 T_Damage: a monster's hit pushes the player dir * damage * 8.
    world = World();
    ogre = Opponent(pos=Vec3(x=100.0), game="q1", kind="monster_ogre");
    player = Player();
    strike(player, 10, ogre, source=ogre.pos);
    assert abs(player.velocity.x + 80.0) < 0.01;
    # Q1 monsters are not pushed by the player's shots.
    (player, state) = pf_armed("q1");
    grunt = Opponent(pos=Vec3(x=70.0), health=100, game="q1");
    world +>:HasOpponent:+> grunt;
    assert fire_weapon(world, player, CollisionMap(), state);
    assert grunt.velocity.length() < 0.001;
    # Q2 fire_rail: kick 250 on a 100-mass soldier is 1250 u/s.
    world = World();
    (player, state) = pf_armed("q2");
    soldier = Opponent(pos=Vec3(x=100.0), health=500, kind="monster_soldier", game="q2");
    world +>:HasOpponent:+> soldier;
    player.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1);
    player.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=50);
    assert select_weapon(player, state, 9);
    assert fire_weapon(world, player, CollisionMap(), state);
    assert abs(soldier.velocity.x - 1250.0) < 1.0;
    # Q3 G_Damage: a 100 point rail pushes a bot 500 u/s along the shot.
    world = World();
    (player, state) = pf_armed("q3");
    bot = Opponent(pos=Vec3(x=100.0), health=300, arena=True, game="q3");
    world +>:HasOpponent:+> bot;
    player.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1);
    player.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=200);
    assert select_weapon(player, state, 7);
    assert fire_weapon(world, player, CollisionMap(), state);
    assert abs(bot.velocity.x - 500.0) < 1.0;
}

test "own rockets launch the player: Q2 1600 per mass, Q3 before halving" {
    for game in ["q1", "q2", "q3"] {
        world = World();
        (player, state) = pf_armed(game);
        player.pos = Vec3(z=22.0);
        collision = CollisionMap();
        # A rocket bursting on the floor under the player's feet.
        blast_actors(world, Vec3(z=-20.0), 120 if game != "q3" else 100, 120.0, False, player, collision, state);
        if game == "q1" {
            # 120 - 0.5 * 24, halved: 54 points, * 8.
            assert abs(player.velocity.z - 432.0) < 1.0;
            assert player.health == 46;
        } elif game == "q2" {
            assert abs(player.velocity.z - 432.0) < 1.0;
            assert player.health == 46;
        } else {
            # Inside the box: all 100 points push 500 u/s; damage is halved.
            assert player.velocity.z > 490.0 and player.velocity.z < 501.0;
            assert player.health == 50 and player.knockback_time > 0.19;
        }
    }
}

test "Q2 and Q3 jump before friction; Q1 rubs speed off first; jumps need a release" {
    for game in ["q1", "q2", "q3"] {
        player = Player(pos=Vec3(z=46.03125), velocity=Vec3(x=400.0), grounded=True);
        player spawn MovePlayer(collision=pf_floor(), jump=True, game=game);
        assert player.velocity.z > 200.0;
        if game == "q1" {
            assert player.velocity.x < 390.0;
        } else {
            assert player.velocity.x > 399.0;
        }
    }
    player = Player(pos=Vec3(z=46.03125), grounded=True);
    floor = pf_floor();
    first = player spawn MovePlayer(collision=floor, jump=True, game="q3");
    assert first.jumped;
    for i in range(120) {
        player spawn MovePlayer(collision=floor, jump=True, game="q3");
    }
    assert player.grounded and player.velocity.z <= 0.0;
    player spawn MovePlayer(collision=floor, jump=False, game="q3");
    again = player spawn MovePlayer(collision=floor, jump=True, game="q3");
    assert again.jumped;
}

test "landing reports its speed and falling hurts by each game's thresholds" {
    player = Player(pos=Vec3(z=200.0), velocity=Vec3(z=-700.0));
    floor = pf_floor();
    landed = 0.0;
    for i in range(60) {
        moved = player spawn MovePlayer(collision=floor, game="q1");
        landed = max(landed, moved.landed);
    }
    assert landed > 690.0;
    cases = [
        ("q1", 700.0, 5, "sound/player/land2.wav"),
        ("q1", 400.0, 0, "sound/player/land.wav"),
        ("q1", 250.0, 0, ""),
        ("q2", 700.0, 9, "sound/player/male/fall2.wav"),
        ("q2", 800.0, 17, "sound/player/male/fall1.wav"),
        ("q2", 500.0, 0, "sound/player/land1.wav"),
        ("q3", 800.0, 10, "sound/player/sarge/fall1.wav"),
        ("q3", 700.0, 5, "sound/player/sarge/fall1.wav"),
        ("q3", 400.0, 0, "sound/player/land1.wav")
    ];
    for row in cases {
        body = Player();
        land = body spawn CrashLand(game=row[0], speed=row[1]);
        assert 100 - body.health == row[2];
        assert land.cue == row[3];
    }
    deep = Player();
    deep spawn CrashLand(game="q3", speed=900.0, water_depth=3);
    assert deep.health == 100;
}

test "picked-up weapons switch per game; empty weapons refuse; cycling skips them" {
    (player, state) = pf_armed("q2");
    player.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1);
    player.inventory spawn AdjustInventory(kind="rockets", amount=5, capacity=50);
    assert pickup_switch(player, state, "rocketlauncher", True) and state.weapon == 7;
    assert state.cooldown > 0.69;
    state.weapon = 1;
    assert not pickup_switch(player, state, "rocketlauncher", False);
    (player, state) = pf_armed("q3");
    assert not pickup_switch(player, state, "machinegun", False);
    (player, state) = pf_armed("q1");
    player.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1);
    assert not change_weapon(player, state, 7);
    assert state.messages == ["not enough ammo."];
    assert not change_weapon(player, state, 6);
    assert state.messages[-1] == "no weapon.";
    # From the shotgun forward: the rocket launcher lacks ammo, so the axe.
    assert cycle_weapon(player, state, 1) and state.weapon == 1;
    assert cycle_weapon(player, state, -1) and state.weapon == 2;
    player.inventory spawn AdjustInventory(kind="rockets", amount=5, capacity=100);
    assert change_weapon(player, state, 7) and state.weapon == 7;
    assert state.cooldown < 0.001;
}

test "chaingun spins up from one to three shots a frame" {
    world = World();
    (player, state) = pf_armed("q2");
    player.inventory spawn AdjustInventory(kind="weapon_chaingun", amount=1);
    player.inventory spawn AdjustInventory(kind="bullets", amount=200, capacity=200);
    assert select_weapon(player, state, 5);
    collision = CollisionMap();
    used: list[int] = [];
    for frame in range(12) {
        before = quantity(player.inventory, "bullets");
        weapon_input(world, player, collision, state, True, 0.1);
        used.append(before - quantity(player.inventory, "bullets"));
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1, active=False);
    }
    assert used == [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3];
    assert "sound/weapons/Chngnu1a.wav" in state.cues;
    weapon_input(world, player, collision, state, False, 0.1);
    assert state.spin == 0 and "sound/weapons/Chngnd1a.wav" in state.cues;
}

test "Q2 BFG leaves 0.8 seconds after the trigger; machinegun climbs" {
    world = World();
    (player, state) = pf_armed("q2");
    player.inventory spawn AdjustInventory(kind="weapon_bfg", amount=1);
    player.inventory spawn AdjustInventory(kind="cells", amount=60, capacity=200);
    assert select_weapon(player, state, 10);
    collision = CollisionMap();
    assert weapon_input(world, player, collision, state, True, 0.01);
    assert not [world->:HasProjectile:->] and quantity(player.inventory, "cells") == 60;
    for tick in range(78) {
        weapon_input(world, player, collision, state, True, 0.01);
    }
    assert not [world->:HasProjectile:->];
    for tick in range(3) {
        weapon_input(world, player, collision, state, True, 0.01);
    }
    assert len([world->:HasProjectile:->]) == 1 and quantity(player.inventory, "cells") == 10;
    (player, state) = pf_armed("q2");
    player.inventory spawn AdjustInventory(kind="weapon_machinegun", amount=1);
    player.inventory spawn AdjustInventory(kind="bullets", amount=50, capacity=200);
    assert select_weapon(player, state, 4);
    for shot in range(3) {
        state.cooldown = 0.0;
        assert weapon_input(world, player, collision, state, True, 0.01);
    }
    assert state.climb == 3 and abs(state.punch - 3.0) < 0.001;
    weapon_input(world, player, collision, state, False, 0.01);
    assert state.climb == 0;
}

test "Q1 Thunderbolt discharges under water; beams and rails leave trails" {
    world = World();
    (player, state) = pf_armed("q1");
    player.inventory spawn AdjustInventory(kind="weapon_lightning", amount=1);
    player.inventory spawn AdjustInventory(kind="cells", amount=20, capacity=100);
    assert select_weapon(player, state, 8);
    fish = Opponent(pos=Vec3(x=80.0), health=100, game="q1");
    world +>:HasOpponent:+> fish;
    player.water_depth = 2;
    assert fire_weapon(world, player, CollisionMap(), state);
    assert quantity(player.inventory, "cells") == 0;
    assert player.health == 0 and fish.health == 0;
    world = World();
    (player, state) = pf_armed("q1");
    player.inventory spawn AdjustInventory(kind="weapon_lightning", amount=1);
    player.inventory spawn AdjustInventory(kind="cells", amount=20, capacity=100);
    assert select_weapon(player, state, 8);
    assert fire_weapon(world, player, CollisionMap(), state);
    kinds = [trail.kind for trail in [world->:HasTrail:->][?:ShotTrail]];
    assert kinds == ["player_lightning"];
    for game in ["q2", "q3"] {
        world = World();
        (player, state) = pf_armed(game);
        slot = 9 if game == "q2" else 7;
        player.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1);
        player.inventory spawn AdjustInventory(kind="slugs", amount=10, capacity=200);
        assert select_weapon(player, state, slot);
        assert fire_weapon(world, player, CollisionMap(), state);
        trails = [world->:HasTrail:->][?:ShotTrail];
        assert len(trails) == 1 and trails[0].kind == game + "_rail";
    }
}

test "missiles burst into each game's explosion" {
    for game in ["q1", "q2", "q3"] {
        world = World();
        (player, state) = pf_armed(game);
        collision = CollisionMap();
        collision.add_box(
            Vec3(x=300.0, y=-100.0, z=-100.0), Vec3(x=310.0, y=100.0, z=100.0), Vec3(), Vec3(), Vec3()
        );
        rocket = Projectile(
            pos=Vec3(x=200.0), velocity=Vec3(x=1000.0), damage=100, splash=120, radius=120.0,
            effect=game + "_rocket"
        );
        world +>:HasProjectile:+> rocket;
        world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.2);
        blasts = [world->:HasExplosion:->][?:Explosion];
        assert len(blasts) == 1;
        expected = {"q1": "q1_explosion", "q2": "q2_explosion", "q3": "q3_rocket_explosion"}[game];
        assert blasts[0].kind == expected and blasts[0].sound;
        world spawn CombatTick(player=player, collision=collision, state=state, dt=2.0, active=False);
        assert not [world->:HasExplosion:->];
    }
}

test "Q3 weapons top up their ammo; Q2 health stops at max_health" {
    world = World();
    (player, state) = pf_armed("q3");
    rule = pickup_rule("q3", {"classname": "weapon_rocketlauncher"});
    assert rule is not None and rule.topup and rule.icon == "icons/iconw_rocket";
    player.inventory spawn AdjustInventory(kind="rockets", amount=200, capacity=200);
    player.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    item = Pickup(rule=rule);
    world +>:HasPickup:+> item;
    result = world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert not item.active and result.weapons == ["rocketlauncher"] and not result.fresh_weapons;
    player.inventory spawn AdjustInventory(kind="rockets", amount=-197);
    item.active = True;
    world spawn PickupTick(player=player, start=Vec3(), finish=Vec3(), dt=0.01);
    assert quantity(player.inventory, "rockets") == 10;
    health = pickup_rule("q2", {"classname": "item_health"});
    assert health is not None and health.label == "Health";
    body = Player(health=95);
    body spawn Heal(amount=health.amount, cap=health.capacity);
    assert body.health == 100;
    body.max_health = 120;
    body spawn Heal(amount=health.amount, cap=health.capacity);
    assert body.health == 110;
    q1 = pickup_rule("q1", {"classname": "item_health"});
    assert q1 is not None and q1.message == "You receive 25 health";
}

test "a player killed past the gib health gibs with each game's sound" {
    gibs = {
        "q1": ["sound/player/gib.wav", "sound/player/udeath.wav"],
        "q2": ["sound/misc/udeath.wav"],
        "q3": ["sound/player/gibsplt1.wav"]
    };
    for game in ["q1", "q2", "q3"] {
        body = Player(health=50);
        body spawn VoiceTick(game=game, dt=0.01);
        body spawn Damage(amount=95, bypass_armor=True);
        voice = body spawn VoiceTick(game=game, dt=0.01);
        assert body.death_overkill == 45;
        assert len(voice.cues) == 1 and voice.cues[0] in gibs[game];
        # Just past zero is an ordinary death.
        whole = Player(health=50);
        whole spawn VoiceTick(game=game, dt=0.01);
        whole spawn Damage(amount=80, bypass_armor=True);
        voice = whole spawn VoiceTick(game=game, dt=0.01);
        assert not [cue for cue in voice.cues if cue in gibs[game]];
    }
    # Q1 GibPlayer: a telefrag's own sound.
    fragged = Player(health=50);
    fragged spawn VoiceTick(game="q1", dt=0.01);
    fragged spawn Damage(amount=50000, bypass_armor=True, means="telefrag");
    voice = fragged spawn VoiceTick(game="q1", dt=0.01);
    assert voice.cues == ["sound/player/teledth1.wav"];
}

test "the voice notices water, pain and death; the view flashes and kicks" {
    player = Player();
    player spawn VoiceTick(game="q1", dt=0.01);
    player.water_depth = 1;
    player.liquid_kind = 1;
    voice = player spawn VoiceTick(game="q1", dt=0.01);
    assert "sound/player/inh2o.wav" in voice.cues;
    player spawn Damage(amount=10);
    voice = player spawn VoiceTick(game="q1", dt=0.01);
    assert len(voice.cues) == 1 and voice.cues[0].startswith("sound/player/pain");
    player spawn Damage(amount=100);
    voice = player spawn VoiceTick(game="q1", dt=0.01);
    assert len(voice.cues) == 1 and voice.cues[0].startswith("sound/player/death");
    voice = player spawn VoiceTick(game="q1", dt=0.0);
    assert not voice.cues;
    view = ViewFeedback();
    view.reset("q1");
    hurt = Player();
    hurt spawn Damage(amount=20, source=Vec3(x=100.0));
    view.take_damage(hurt);
    layers = view.tints(0, False);
    assert len(layers) == 1 and layers[0].r == 255 and layers[0].a == 30;
    assert view.pitch() > 0.0 and hurt.damage_blood == 0;
    view.advance(1.0);
    assert not view.tints(0, False) and view.pitch() == 0.0;
    assert len(view.tints(2, True)) == 1;
}
