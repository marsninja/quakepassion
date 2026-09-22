"""Native hub revisits, campaign saves and original-map key gates."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.campaign { Visited, MapState }
import from engine.render.renderer { Renderer }
import from engine.world.trains { ShootMover }
import from engine.world.signals { SignalTick, progress_for }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, select_weapon, weapon_input }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.math.vec3 { Vec3 }

with entry {
    save_path = ".jac/campaign-validation-save.txt";
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(),
        player=Player(),
        renderer=renderer,
        clock=Clock(),
        save_path=save_path
    );
    try {
        app.load_destination("q2", "base1");
        assert not app.menu.opened , app.menu.message;
        app.world spawn SignalTick(dt=1.0);
        assert progress_for(app.world).secrets == 0;
        print("SPAWN RULES PASS: Q2 base1 excludes campaign-disabled startup secret");
        buttons = [
            door
            for door in [app.world->:HasDoor:->][?:Door]
            if door.model == 13
        ];
        assert len(buttons) == 1 and buttons[0].max_health == 1;
        app.world spawn ShootMover(model=13, amount=1);
        for i in range(120) {
            app.world spawn DoorTick(
                bsp=app.level.bsp,
                collision=app.level.collision,
                player_origin=app.player.pos.sub(
                    Vec3(z=app.level.collision.eye_height)
                ),
                player=app.player,
                dt=1.0 / 120.0
            );
        }
        assert progress_for(app.world).secrets == 1;
        print(
            "SHOOT BUTTON PASS: Q2 base1 authored secret only after damage and motion"
        );
        enemies = [app.world->:HasOpponent:->][?:Opponent];
        pickups = [app.world->:HasPickup:->][?:Pickup];
        assert enemies and pickups;
        enemies[0].health = 0;
        pickups[0].active = False;
        app.player.inventory spawn AdjustInventory(
            kind="grenades", amount=3, capacity=50
        );
        assert select_weapon(app.player, app.combat, 11);
        weapon_input(
            app.world, app.player, app.level.collision, app.combat, True, 0.01
        );
        weapon_input(app.world, app.player, app.level.collision, app.combat, True, 1.0);
        weapon_input(app.world, app.player, app.level.collision, app.combat, True, 0.5);
        fuse = app.combat.grenade_remaining;
        app.load_destination("q2", "base2", carry=True);
        assert app.combat.weapon == 11
            and app.combat.grenade_phase == 2
            and app.combat.grenade_remaining == fuse;
        assert not app.menu.opened , app.menu.message;
        app.player.health = 41;
        app.player.inventory spawn AdjustInventory(
            kind="shells", amount=5, capacity=100
        );
        app.quicksave();
        assert app.notice == "Saved - F9 to load" , app.notice;
        app.load_destination("q1", "e1m1");
        app.quickload();
        assert app.notice == "Loaded" , app.notice;
        assert app.level.name == "base2" and app.player.health == 41;
        assert app.combat.weapon == 11
            and app.combat.grenade_phase == 2
            and app.combat.grenade_remaining == fuse;
        app.load_destination("q2", "base1", carry=True);
        assert not app.menu.opened , app.menu.message;
        enemies = [app.world->:HasOpponent:->][?:Opponent];
        pickups = [app.world->:HasPickup:->][?:Pickup];
        assert enemies[0].health == 0 and not enemies[0].visual.visible;
        assert not pickups[0].active and not pickups[0].visual.visible;
        assert app.player.health == 41
            and quantity(app.player.inventory, "shells") == 5;
        before = len([app.campaign->:Visited:->][?:MapState]);
        app.load_destination("q2", "missing-campaign-map", carry=True);
        assert app.menu.opened and app.level.name == "base1";
        assert len([app.campaign->:Visited:->][?:MapState]) == before;
        app.load_destination("q2", "base1", carry=True, new_unit=True);
        assert not app.menu.opened and not [app.campaign->:Visited:->][?:MapState];
        enemies = [app.world->:HasOpponent:->][?:Opponent];
        assert enemies[0].health > 0;
        print("HUB PASS: revisits, inventory carry, saves, rollback, unit reset");
        app.load_destination("q1", "e1m2");
        assert not app.menu.opened , app.menu.message;
        keyed = [
            door
            for door in [app.world->:HasDoor:->][?:Door]
            if door.keys
        ];
        assert keyed , "Expected a key door in e1m2";
        door = keyed[0];
        key = door.keys[0];
        items = [
            item
            for item in [app.world->:HasPickup:->][?:Pickup]
            if item.rule.kind == key
        ];
        assert items , "Missing authored key pickup";
        item = items[0];
        app.world spawn PickupTick(
            player=app.player, start=item.pos, finish=item.pos, dt=0.01
        );
        assert quantity(app.player.inventory, key) == 1 and not item.active;
        app.player.pos = door.trigger.mins.lerp(door.trigger.maxs, 0.5).add(
            Vec3(z=app.level.collision.eye_height)
        );
        app.world spawn DoorTick(
            bsp=app.level.bsp,
            collision=app.level.collision,
            player=app.player,
            player_origin=app.player.pos,
            dt=0.01
        );
        assert door.unlocked and quantity(app.player.inventory, key) == 0;
        app.player.inventory spawn AdjustInventory(kind="key_gold", amount=1);
        app.load_destination("q1", "e1m3", carry=True);
        assert not app.menu.opened and quantity(app.player.inventory, "key_gold") == 0;
        print("KEY ROUTE PASS: Q1 e1m2 pickup/unlock to e1m3");
    } finally {
        app.audio.close();
        app.effects.close();
        app.models.close();
        app.quake.close();
        renderer.close();
        if os.path.exists(save_path) {
            os.remove(save_path);
        }
    }
}
