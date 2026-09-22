"""Original campaign/arena pickups adapted to shared engine item behavior."""
import math;
import from .weapons { weapon_rules }
import from engine.world.signals { Signal, HasSignal }
import from engine.world.pickups { PickupRule, Pickup, HasPickup }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level }
import from engine.assets.catalog { AssetCatalog }
import from engine.math.vec3 { Vec3 }


def pickup_rule(
    game: str, fields: dict[str, str], worldtype: int = 0
) -> PickupRule | None {
    kind = fields.get("classname", "");
    flags = int(fields.get("spawnflags", "0"));
    if kind.startswith("weapon_") {
        for weapon in weapon_rules(game) {
            if kind == "weapon_" + weapon.key and weapon.model {
                return PickupRule(
                    kind=kind,
                    amount=1,
                    capacity=1,
                    model=weapon.model,
                    ammo=weapon.ammo,
                    ammo_amount=weapon.pickup_ammo,
                    ammo_capacity=weapon.capacity
                );
            }
        }
    }
    ammo: dict[str, PickupRule] = {};
    if game == "q1" {
        for pair in [
            ("spikes", "nails", "nail", 25, 50, 200),
            ("rockets", "rockets", "rock", 5, 10, 100),
            ("cells", "cells", "batt", 6, 12, 100)
        ] {
            ammo["item_" + pair[0]] = PickupRule(
                kind=pair[1],
                amount=pair[4] if flags & 1 else pair[3],
                capacity=pair[5],
                model="maps/b_" + pair[2] + ("1" if flags & 1 else "0") + ".bsp"
            );
        }
    } elif game == "q2" {
        for pair in [
            ("bullets", 50, 200),
            ("grenades", 5, 50),
            ("rockets", 5, 50),
            ("cells", 50, 200),
            ("slugs", 10, 50)
        ] {
            ammo["ammo_" + pair[0]] = PickupRule(
                kind=pair[0],
                amount=pair[1],
                capacity=pair[2],
                model="models/items/ammo/" + pair[0] + "/medium/tris.md2"
            );
        }
    } elif game == "q3" {
        for pair in [
            ("bullets", "machinegun", 50),
            ("grenades", "grenade", 5),
            ("rockets", "rocket", 5),
            ("lightning", "lightning", 60),
            ("cells", "plasma", 30),
            ("slugs", "railgun", 10),
            ("bfg", "bfg", 15)
        ] {
            ammo["ammo_" + pair[0]] = PickupRule(
                kind=pair[0],
                amount=pair[2],
                capacity=200,
                model="models/powerups/ammo/" + pair[1] + "am.md3"
            );
        }
    }
    if kind in ammo {
        return ammo[kind];
    }
    if game == "q1" {
        if kind == "item_sigil" and flags & 15 {
            index = 1;
            for i in range(4) {
                if flags & (1 << i) {
                    index = i + 1;
                }
            }
            return PickupRule(
                kind="runes",
                amount=1,
                capacity=15,
                bitmask=flags & 15,
                model="progs/end" + str(index) + ".mdl"
            );
        }
        if kind in ["item_key1", "item_key2"] {
            theme = "b" if worldtype == 2 else ("m" if worldtype == 1 else "w");
            metal = "s" if kind == "item_key1" else "g";
            return PickupRule(
                kind="key_silver" if kind == "item_key1" else "key_gold",
                amount=1,
                capacity=1,
                model="progs/" + theme + "_" + metal + "_key.mdl"
            );
        }
        if kind == "item_health" {
            amount = 100 if flags & 2 else (15 if flags & 1 else 25);
            model = "b_bh100" if flags & 2 else ("b_bh10" if flags & 1 else "b_bh25");
            return PickupRule(
                kind="health",
                amount=amount,
                capacity=250 if flags & 2 else 100,
                model="maps/" + model + ".bsp"
            );
        }
        if kind == "item_shells" {
            return PickupRule(
                kind="shells",
                amount=40 if flags & 1 else 20,
                capacity=100,
                model="maps/b_shell" + ("1" if flags & 1 else "0") + ".bsp"
            );
        }
        if kind in ["item_armor1", "item_armor2", "item_armorInv"] {
            skin = 0 if kind == "item_armor1" else (1 if kind == "item_armor2" else 2);
            return PickupRule(
                kind="armor",
                amount=100 + skin * 50,
                capacity=200,
                model="progs/armor.mdl",
                skin=skin,
                armor_ratio=0.3 if skin == 0 else (0.6 if skin == 1 else 0.8)
            );
        }
    } elif game == "q2" {
        key_models = {
            "key_data_cd": "data_cd",
            "key_power_cube": "power",
            "key_pyramid": "pyramid",
            "key_data_spinner": "spinner",
            "key_pass": "pass",
            "key_blue_key": "key",
            "key_red_key": "red_key",
            "key_airstrike_target": "target"
        };
        if kind in key_models {
            return PickupRule(
                kind=kind,
                amount=1,
                capacity=8 if kind == "key_power_cube" else 1,
                model="models/items/keys/" + key_models[kind] + "/tris.md2"
            );
        }
        if kind == "key_commander_head" {
            return PickupRule(
                kind=kind,
                amount=1,
                capacity=1,
                model="models/monsters/commandr/head/tris.md2"
            );
        }
        if kind
            in [
                "item_health",
                "item_health_small",
                "item_health_large",
                "item_health_mega"
            ] {
            size = "medium";
            amount = 10;
            cap = 100;
            if kind == "item_health_small" {
                size = "stimpack";
                amount = 2;
                cap = 200;
            }
            if kind == "item_health_large" {
                size = "large";
                amount = 25;
            }
            if kind == "item_health_mega" {
                size = "mega";
                amount = 100;
                cap = 200;
            }
            return PickupRule(
                kind="health",
                amount=amount,
                capacity=cap,
                model="models/items/healing/" + size + "/tris.md2"
            );
        }
        if kind == "ammo_shells" {
            return PickupRule(
                kind="shells",
                amount=10,
                capacity=100,
                model="models/items/ammo/shells/medium/tris.md2"
            );
        }
        if kind in ["item_armor_jacket", "item_armor_combat", "item_armor_body"] {
            size = "jacket"
                if kind == "item_armor_jacket"
                else ("combat" if kind == "item_armor_combat" else "body");
            return PickupRule(
                kind="armor",
                amount=25 if size == "jacket" else (50 if size == "combat" else 100),
                capacity=50 if size == "jacket" else (100 if size == "combat" else 200),
                armor_mode="salvage",
                model="models/items/armor/" + size + "/tris.md2",
                armor_ratio=0.3
                    if size == "jacket"
                    else (0.6 if size == "combat" else 0.8)
            );
        }
    } elif game == "q3" {
        if kind
            in [
                "item_health",
                "item_health_small",
                "item_health_large",
                "item_health_mega"
            ] {
            size = "medium";
            amount = 25;
            if kind == "item_health_small" {
                size = "small";
                amount = 5;
            }
            if kind == "item_health_large" {
                size = "large";
                amount = 50;
            }
            if kind == "item_health_mega" {
                size = "mega";
                amount = 100;
            }
            return PickupRule(
                kind="health",
                amount=amount,
                capacity=200 if size in ["small", "mega"] else 100,
                model="models/powerups/health/" + size + "_cross.md3"
            );
        }
        if kind == "ammo_shells" {
            return PickupRule(
                kind="shells",
                amount=10,
                capacity=200,
                model="models/powerups/ammo/shotgunam.md3"
            );
        }
        if kind in ["item_armor_body", "item_armor_combat"] {
            return PickupRule(
                kind="armor",
                amount=100 if kind == "item_armor_body" else 50,
                capacity=200,
                armor_mode="add",
                model="models/powerups/armor/armor_"
                    + ("red" if kind == "item_armor_body" else "yel")
                    + ".md3",
                armor_ratio=2.0 / 3.0
            );
        }
    }
    return None;
}


def populate_pickups(world: World, level: Level, directory: str) -> int {
    catalog = AssetCatalog(game=level.bsp.game, directory=directory);
    resources: dict[str, ModelResource] = {};
    count = 0;
    try {
        for index in range(len(level.bsp.entities)) {
            fields = level.bsp.entities[index].fields;
            source = fields.get("asset_game", level.bsp.game);
            rule = pickup_rule(
                source,
                fields,
                int(level.bsp.entities[0].fields.get("worldtype", "0"))
                    if level.bsp.entities
                    else 0
            );
            if rule is None {
                continue;
            }
            # Team selection still needs linked randomized respawn semantics.
            if fields.get("team", "") {
                continue;
            }
            flags = int(fields.get("spawnflags", "0"));
            if level.bsp.game == "q1" and flags & 512 {
                continue;
            }
            if level.bsp.game == "q2" and (flags & 512 or flags & 2) {
                continue;
            }
            if level.bsp.game == "q3" and fields.get("notfree", "0") == "1" {
                continue;
            }
            parts = fields.get("origin", "0 0 0").split();
            if len(parts) != 3 {
                raise ValueError("Invalid pickup origin");
            }
            position = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            key = source + ":" + rule.model + ":" + str(rule.skin);
            if key not in resources {
                loaded = catalog.model(source + ":" + rule.model, rule.skin);
                resource = ModelResource(
                    name=key, model=loaded.model, skins=loaded.skins
                );
                resources[key] = resource;
                world +>:HasModelResource:+> resource;
            }
            waiting_for_use = (level.bsp.game == "q2" and flags & 1 != 0)
                or (level.bsp.game == "q3" and bool(fields.get("targetname", "")));
            respawn = 0.0;
            if level.bsp.game == "q3" {
                respawn = 5.0
                    if rule.kind.startswith("weapon_")
                    else (
                        35.0
                            if rule.kind == "health"
                            else (25.0 if rule.kind == "armor" else 40.0)
                    );
                if "wait" in fields {
                    respawn = max(0.0, float(fields["wait"]));
                }
            }
            pickup = Pickup(
                rule=rule,
                pos=position,
                yaw=float(fields.get("angle", "0")) * math.pi / 180.0,
                respawn=respawn,
                active=not waiting_for_use,
                waiting_for_use=waiting_for_use,
                activate_on_use=waiting_for_use or level.bsp.game == "q3",
                reusable_use=level.bsp.game == "q3"
            );
            for signal in [world->:HasSignal:->][?:Signal] {
                if index in signal.entities {
                    pickup.activation = signal;
                }
            }
            pickup.visual = attach_model(pickup, resources[key]);
            pickup.visual.visible = pickup.active;
            move_to_area(pickup, level.areas[level.locate(position)]);
            world +>:HasPickup:+> pickup;
            count += 1;
        }
    } finally {
        catalog.close();
    }
    return count;
}
