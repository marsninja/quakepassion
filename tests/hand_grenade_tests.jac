import from games.weapons { equip_player }
import from engine.world.world { World, Player }
import from engine.world.combat {
    CombatState,
    Projectile,
    HasProjectile,
    weapon_input,
    select_weapon,
    CombatTick
}
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }


def grenades(player: Player, state: CombatState) {
    equip_player(player, state, "q2");
    player.inventory spawn AdjustInventory(kind="grenades", amount=2, capacity=50);
    assert select_weapon(player, state, 11);
}

test "early release waits for priming and consumes one grenade on throw" {
    world = World();
    player = Player();
    state = CombatState();
    collision = CollisionMap();
    grenades(player, state);
    assert not weapon_input(world, player, collision, state, True, 0.01);
    assert state.grenade_phase == 1 and quantity(player.inventory, "grenades") == 2;
    assert not select_weapon(player, state, 1);
    shots = 0;
    for i in range(140) {
        if weapon_input(world, player, collision, state, False, 1.0 / 120.0) {
            shots += 1;
        }
    }
    missiles = [world->:HasProjectile:->][?:Projectile];
    assert shots == 1
        and len(missiles) == 1
        and quantity(player.inventory, "grenades") == 1;
    assert missiles[0].remaining > 3.0 and missiles[0].remaining < 3.2;
    assert missiles[0].velocity.x > 370.0 and missiles[0].velocity.x < 400.0;
    assert state.grenade_phase == 0 and state.cooldown == 1.0;
}

test "held grenade detonates once and cannot rearm until released" {
    world = World();
    player = Player();
    state = CombatState();
    collision = CollisionMap();
    grenades(player, state);
    shots = 0;
    for i in range(600) {
        if weapon_input(world, player, collision, state, True, 0.01) {
            shots += 1;
        }
    }
    assert shots == 1 and state.grenade_phase == 4 and not [world->:HasProjectile:->];
    assert player.health < 100 and quantity(player.inventory, "grenades") == 1;
    assert not select_weapon(player, state, 1);
    assert not weapon_input(world, player, collision, state, False, 0.01);
    assert state.grenade_phase == 0 and select_weapon(player, state, 1);
}

test "cooking pauses with simulation and save restores throw fuse and speed" {
    world = World();
    player = Player();
    state = CombatState();
    level = Level(name="grenade");
    level.bsp.game = "q2";
    grenades(player, state);
    assert not weapon_input(world, player, level.collision, state, True, 0.01);
    for i in range(300) {
        weapon_input(world, player, level.collision, state, True, 0.01);
    }
    assert state.grenade_phase == 2;
    timer = state.grenade_remaining;
    for i in range(10) {
        weapon_input(world, player, level.collision, state, True, 0.0);
    }
    assert state.grenade_remaining == timer;
    saved = snapshot(world, level, player, state);
    for i in range(12) {
        weapon_input(world, player, level.collision, state, False, 0.01);
    }
    expected = snapshot(world, level, player, state);
    missiles = [world->:HasProjectile:->][?:Projectile];
    assert len(missiles) == 1
        and missiles[0].velocity.x > 600.0
        and missiles[0].remaining < 1.3;
    restore(world, level, player, state, saved);
    for i in range(12) {
        weapon_input(world, player, level.collision, state, False, 0.01);
    }
    assert snapshot(world, level, player, state) == expected;
}

test "empty weapons fall back to an owned usable weapon" {
    for game in ["q1", "q2", "q3"] {
        world = World();
        player = Player();
        state = CombatState();
        collision = CollisionMap();
        equip_player(player, state, game);
        if game == "q1" {
            player.inventory spawn AdjustInventory(kind="shells", amount=-100);
        } elif game == "q2" {
            player.inventory spawn AdjustInventory(kind="weapon_railgun", amount=1);
            assert select_weapon(player, state, 9);
        } else {
            player.inventory spawn AdjustInventory(kind="bullets", amount=-200);
        }
        assert not weapon_input(world, player, collision, state, True, 0.01);
        assert state.weapon == 1;
        assert state.cooldown >= 0.2;
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.2, active=False
        );
        assert weapon_input(world, player, collision, state, True, 0.01);
    }
}
