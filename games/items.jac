"""Initial campaign/arena pickup roster adapted to shared engine item behavior."""
import math;
import from engine.world.signals { Signal, HasSignal }
import from engine.world.pickups { PickupRule, Pickup, HasPickup }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level }
import from engine.assets.library { AssetLibrary }
import from engine.math.vec3 { Vec3 }


def pickup_rule(game: str, fields: dict[str, str], worldtype: int = 0) -> PickupRule | None {
    kind = fields.get("classname", "");
    flags = int(fields.get("spawnflags", "0"));
    if game == "q1" {
        if kind in ["item_key1", "item_key2"] {
            theme = "b" if worldtype == 2 else ("m" if worldtype == 1 else "w");
            metal = "s" if kind == "item_key1" else "g";
            return PickupRule(kind="key_silver" if kind == "item_key1" else "key_gold",
                amount=1, capacity=1, model="progs/" + theme + "_" + metal + "_key.mdl");
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
            "key_data_cd": "data_cd", "key_power_cube": "power", "key_pyramid": "pyramid",
            "key_data_spinner": "spinner", "key_pass": "pass", "key_blue_key": "key",
            "key_red_key": "red_key", "key_airstrike_target": "target"
        };
        if kind in key_models {
            return PickupRule(kind=kind, amount=1, capacity=8 if kind == "key_power_cube" else 1,
                model="models/items/keys/" + key_models[kind] + "/tris.md2");
        }
        if kind == "key_commander_head" {
            return PickupRule(kind=kind, amount=1, capacity=1,
                model="models/monsters/commandr/head/tris.md2");
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
    library = AssetLibrary(game=level.bsp.game);
    resources: dict[str, ModelResource] = {};
    count = 0;
    library.open(directory);
    try {
        for index in range(len(level.bsp.entities)) {
            fields = level.bsp.entities[index].fields;
            rule = pickup_rule(level.bsp.game, fields,
                int(level.bsp.entities[0].fields.get("worldtype", "0")) if level.bsp.entities else 0);
            if rule is None {
                continue;
            }
            # Trigger-spawn and team selection need their own activation semantics.
            if fields.get("targetname", "") or fields.get("team", "") {
                continue;
            }
            flags = int(fields.get("spawnflags", "0"));
            if level.bsp.game == "q1" and flags & 512 {
                continue;
            }
            if level.bsp.game == "q2" and (flags & 512 or flags & 3) {
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
            key = rule.model + ":" + str(rule.skin);
            if key not in resources {
                loaded = library.model(rule.model, rule.skin);
                resource = ModelResource(
                    name=key, model=loaded.model, skins=loaded.skins
                );
                resources[key] = resource;
                world +>:HasModelResource:+> resource;
            }
            pickup = Pickup(
                rule=rule,
                pos=position,
                yaw=float(fields.get("angle", "0")) * math.pi / 180.0,
                respawn=30.0 if level.bsp.game == "q3" else 0.0
            );
            for signal in [world->:HasSignal:->][?:Signal] {
                if index in signal.entities { pickup.activation = signal; }
            }
            pickup.visual = attach_model(pickup, resources[key]);
            move_to_area(pickup, level.areas[level.locate(position)]);
            world +>:HasPickup:+> pickup;
            count += 1;
        }
    } finally {
        library.close();
    }
    return count;
}
