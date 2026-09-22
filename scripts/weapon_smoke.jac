"""Native acceptance for owned weapon assets and every base-game weapon path."""
import os;
import from games.weapons { equip_player, weapon_rules }
import from games.items { pickup_rule }
import from engine.assets.catalog { AssetCatalog }
import from engine.world.world { World, Player }
import from engine.world.combat {
    CombatState,
    Opponent,
    HasOpponent,
    HasProjectile,
    ProjectileTick,
    fire_weapon,
    select_weapon
}
import from engine.world.inventory { AdjustInventory }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

with entry {
    for pair in [("q1", "id1"), ("q2", "baseq2"), ("q3", "baseq3")] {
        game = pair[0];
        catalog = AssetCatalog(
            game=game, directory=os.getenv("HOME", "") + "/quake-assets/" + pair[1]
        );
        assets: set[str] = set();
        for rule in weapon_rules(game) {
            if rule.model {
                assets.add(rule.model);
            }
            if rule.ammo {
                name = "item_" + ("spikes" if rule.ammo == "nails" else rule.ammo)
                    if game == "q1"
                    else "ammo_" + rule.ammo;
                pickup = pickup_rule(game, {"classname": name});
                assert pickup is not None;
                assets.add(pickup.model);
                if game == "q1" {
                    large = pickup_rule(game, {"classname": name, "spawnflags": "1"});
                    assert large is not None;
                    assets.add(large.model);
                }
            }
            world = World();
            player = Player();
            state = CombatState();
            level = Level(name="weapons");
            equip_player(player, state, game);
            player.inventory spawn AdjustInventory(kind="weapon_" + rule.key, amount=1);
            if rule.ammo {
                player.inventory spawn AdjustInventory(
                    kind=rule.ammo, amount=rule.capacity, capacity=rule.capacity
                );
            }
            assert select_weapon(player, state, rule.slot);
            enemy = Opponent(pos=Vec3(x=24.0), health=2000, max_health=2000);
            world +>:HasOpponent:+> enemy;
            assert fire_weapon(world, player, level.collision, state);
            if rule.speed > 0.0 {
                assert enemy.health == 2000;
                data = snapshot(world, level, player, state);
                restore(world, level, player, state, data);
                assert snapshot(world, level, player, state) == data;
                world spawn ProjectileTick(
                    player=player, collision=level.collision, state=state, dt=0.05
                );
                assert not [world->:HasProjectile:->];
            }
            assert enemy.health < 2000;
        }
        for asset in sorted(assets) {
            model = catalog.model(game + ":" + asset, 0);
            assert len(model.model.surfaces) > 0;
        }
        catalog.close();
        print(
            "WEAPONS PASS",
            game,
            len(weapon_rules(game)),
            "weapons",
            len(assets),
            "assets"
        );
    }
}
