"""Original campaign/arena pickups adapted to shared engine item behavior."""
import math;
import from .weapons { weapon_rules }
import from engine.world.signals { Signal, HasSignal }
import from engine.world.pickups { PickupRule, Pickup, HasPickup }
import from engine.world.powerups { powerup_rule }
import from engine.world.models {
    ModelResource,
    HasModelResource,
    UsesModel,
    attach_model
}
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level }
import from engine.assets.catalog { AssetCatalog }
import from engine.math.vec3 { Vec3 }


def health_sound(size: str) -> str {
    return {
        "stimpack": "sound/items/s_health.wav",
        "small": "sound/items/s_health.wav",
        "medium": "sound/items/n_health.wav",
        "large": "sound/items/l_health.wav",
        "mega": "sound/items/m_health.wav"
    }.get(size, "sound/items/n_health.wav");
}

"""Pickup sounds from Q1 items.qc/weapons.qc, Q2 g_items.c itemlist and Q3
bg_misc.c bg_itemlist, for rules that do not name their own."""
def pickup_sound(game: str, rule: PickupRule, worldtype: int) -> str {
    kind = rule.kind;
    ammo = ["shells", "nails", "rockets", "cells", "bullets", "grenades", "slugs", "lightning", "bfg"];
    if game == "q1" {
        if kind.startswith("weapon_") {
            return "sound/weapons/pkup.wav";
        }
        if kind in ammo {
            return "sound/weapons/lock4.wav";
        }
        if kind == "armor" {
            return "sound/items/armor1.wav";
        }
        if kind.startswith("key_") {
            return "sound/misc/"
                + ("medkey" if worldtype == 0 else ("runekey" if worldtype == 1 else "basekey"))
                + ".wav";
        }
        if kind == "runes" {
            return "sound/misc/runekey.wav";
        }
    } elif game in ["q2", "q3"] {
        if kind.startswith("weapon_") {
            return "sound/misc/w_pkup.wav";
        }
        if kind in ammo {
            return "sound/misc/am_pkup.wav";
        }
        if kind == "armor" {
            return "sound/misc/ar1_pkup.wav" if game == "q2" else "sound/misc/ar2_pkup.wav";
        }
        if kind.startswith("key_") {
            return "sound/items/pkup.wav";
        }
    }
    return "";
}

# Q2 g_items.c itemlist pickup names and status bar icons (pics/*.pcx).
glob Q2_PICKUPS: dict[str, tuple[str, str]] = {
    "weapon_shotgun": ("Shotgun", "w_shotgun"),
    "weapon_supershotgun": ("Super Shotgun", "w_sshotgun"),
    "weapon_machinegun": ("Machinegun", "w_machinegun"),
    "weapon_chaingun": ("Chaingun", "w_chaingun"),
    "weapon_grenadelauncher": ("Grenade Launcher", "w_glauncher"),
    "weapon_rocketlauncher": ("Rocket Launcher", "w_rlauncher"),
    "weapon_hyperblaster": ("HyperBlaster", "w_hyperblaster"),
    "weapon_railgun": ("Railgun", "w_railgun"),
    "weapon_bfg": ("BFG10K", "w_bfg"),
    "ammo_shells": ("Shells", "a_shells"),
    "ammo_bullets": ("Bullets", "a_bullets"),
    "ammo_grenades": ("Grenades", "a_grenades"),
    "ammo_rockets": ("Rockets", "a_rockets"),
    "ammo_cells": ("Cells", "a_cells"),
    "ammo_slugs": ("Slugs", "a_slugs"),
    "item_health": ("Health", "i_health"),
    "item_health_small": ("Health", "i_health"),
    "item_health_large": ("Health", "i_health"),
    "item_health_mega": ("Health", "i_health"),
    "item_armor_jacket": ("Jacket Armor", "i_jacketarmor"),
    "item_armor_combat": ("Combat Armor", "i_combatarmor"),
    "item_armor_body": ("Body Armor", "i_bodyarmor"),
    "item_armor_shard": ("Armor Shard", "i_jacketarmor"),
    "item_power_screen": ("Power Screen", "i_powerscreen"),
    "item_power_shield": ("Power Shield", "i_powershield"),
    "item_quad": ("Quad Damage", "p_quad"),
    "item_invulnerability": ("Invulnerability", "p_invulnerability"),
    "item_silencer": ("Silencer", "p_silencer"),
    "item_breather": ("Rebreather", "p_rebreather"),
    "item_enviro": ("Environment Suit", "p_envirosuit"),
    "item_ancient_head": ("Ancient Head", "i_fixme"),
    "item_adrenaline": ("Adrenaline", "p_adrenaline"),
    "item_bandolier": ("Bandolier", "p_bandolier"),
    "item_pack": ("Ammo Pack", "i_pack"),
    "key_data_cd": ("Data CD", "k_datacd"),
    "key_power_cube": ("Power Cube", "k_powercube"),
    "key_pyramid": ("Pyramid Key", "k_pyramid"),
    "key_data_spinner": ("Data Spinner", "k_dataspin"),
    "key_pass": ("Security Pass", "k_security"),
    "key_blue_key": ("Blue Key", "k_bluekey"),
    "key_red_key": ("Red Key", "k_redkey"),
    "key_commander_head": ("Commander's Head", "k_comhead"),
    "key_airstrike_target": ("Airstrike Marker", "i_airstrike")
};

# Q3 bg_misc.c bg_itemlist pickup names and icons.
glob Q3_PICKUPS: dict[str, tuple[str, str]] = {
    "weapon_shotgun": ("Shotgun", "icons/iconw_shotgun"),
    "weapon_machinegun": ("Machinegun", "icons/iconw_machinegun"),
    "weapon_grenadelauncher": ("Grenade Launcher", "icons/iconw_grenade"),
    "weapon_rocketlauncher": ("Rocket Launcher", "icons/iconw_rocket"),
    "weapon_lightning": ("Lightning Gun", "icons/iconw_lightning"),
    "weapon_railgun": ("Railgun", "icons/iconw_railgun"),
    "weapon_plasmagun": ("Plasma Gun", "icons/iconw_plasma"),
    "weapon_bfg": ("BFG10K", "icons/iconw_bfg"),
    "ammo_shells": ("Shells", "icons/icona_shotgun"),
    "ammo_bullets": ("Bullets", "icons/icona_machinegun"),
    "ammo_grenades": ("Grenades", "icons/icona_grenade"),
    "ammo_cells": ("Cells", "icons/icona_plasma"),
    "ammo_lightning": ("Lightning", "icons/icona_lightning"),
    "ammo_rockets": ("Rockets", "icons/icona_rocket"),
    "ammo_slugs": ("Slugs", "icons/icona_railgun"),
    "ammo_bfg": ("Bfg Ammo", "icons/icona_bfg"),
    "item_health_small": ("5 Health", "icons/iconh_green"),
    "item_health": ("25 Health", "icons/iconh_yellow"),
    "item_health_large": ("50 Health", "icons/iconh_red"),
    "item_health_mega": ("Mega Health", "icons/iconh_mega"),
    "item_armor_shard": ("Armor Shard", "icons/iconr_shard"),
    "item_armor_combat": ("Armor", "icons/iconr_yellow"),
    "item_armor_body": ("Heavy Armor", "icons/iconr_red"),
    "item_quad": ("Quad Damage", "icons/quad"),
    "item_enviro": ("Battle Suit", "icons/envirosuit"),
    "item_haste": ("Speed", "icons/haste"),
    "item_invis": ("Invisibility", "icons/invis"),
    "item_regen": ("Regeneration", "icons/regen"),
    "item_flight": ("Flight", "icons/flight"),
    "holdable_teleporter": ("Personal Teleporter", "icons/teleporter"),
    "holdable_medkit": ("Medkit", "icons/medkit")
};

# Q1 items.qc / weapons.qc netnames for "You got the ..." (id 1.06).
glob Q1_NAMES: dict[str, str] = {
    "weapon_supershotgun": "Double-barrelled Shotgun",
    "weapon_nailgun": "nailgun",
    "weapon_supernailgun": "Super Nailgun",
    "weapon_grenadelauncher": "Grenade Launcher",
    "weapon_rocketlauncher": "Rocket Launcher",
    "weapon_lightning": "Thunderbolt",
    "item_shells": "shells",
    "item_spikes": "nails",
    "item_rockets": "rockets",
    "item_cells": "cells",
    "item_artifact_invulnerability": "Pentagram of Protection",
    "item_artifact_envirosuit": "Biosuit",
    "item_artifact_invisibility": "Ring of Shadows",
    "item_artifact_super_damage": "Quad Damage"
};

"""What picking the item up says and shows: Q1 sprints ("You got the Rocket
Launcher", "You receive 25 health", "You got armor", centerprinted "You got
the rune!"); Q2 and Q3 put the item's icon and name on the status bar
(STAT_PICKUP_ICON/STRING, CG_DrawPickupItem). Q3 weapons top up their ammo
(Pickup_Weapon) and items announce their respawn."""
def present_pickup(game: str, kind: str, rule: PickupRule, worldtype: int) {
    if game == "q1" {
        if kind == "item_health" {
            rule.message = "You receive " + str(rule.amount) + " health";
        } elif kind.startswith("item_armor") {
            rule.message = "You got armor";
        } elif kind in ["item_key1", "item_key2"] {
            metal = "silver" if kind == "item_key1" else "gold";
            rule.message = "You got the "
                + metal
                + [" key", " runekey", " keycard"][max(0, min(2, worldtype))];
        } elif kind == "item_sigil" {
            rule.message = "You got the rune!";
        } elif kind in Q1_NAMES {
            rule.message = "You got the " + Q1_NAMES[kind];
        }
        return;
    }
    table = Q2_PICKUPS if game == "q2" else Q3_PICKUPS;
    if kind in table {
        rule.label = table[kind][0];
        rule.icon = table[kind][1];
    }
    if game == "q3" {
        if kind.startswith("weapon_") {
            rule.topup = True;
        }
        rule.respawn_sound = "sound/items/poweruprespawn.wav"
            if rule.kind == "powerup"
            else "sound/items/respawn1.wav";
    }
}

def pickup_rule(
    game: str, fields: dict[str, str], worldtype: int = 0
) -> PickupRule | None {
    rule = item_rule(game, fields, worldtype);
    if rule is not None and not rule.sound {
        rule.sound = pickup_sound(game, rule, worldtype);
    }
    if rule is not None {
        present_pickup(game, fields.get("classname", ""), rule, worldtype);
    }
    return rule;
}

def item_rule(
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
                rot=flags & 2 != 0,
                model="maps/" + model + ".bsp",
                sound="sound/items/r_item2.wav"
                    if flags & 2
                    else (
                        "sound/items/r_item1.wav" if flags & 1 else "sound/items/health1.wav"
                    )
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
            # g_items.c Pickup_Health: capped at max_health, except the
            # stimpack and mega health (HEALTH_IGNORE_MAX).
            size = "medium";
            amount = 10;
            cap = 0;
            if kind == "item_health_small" {
                size = "stimpack";
                amount = 2;
                cap = 10000;
            }
            if kind == "item_health_large" {
                size = "large";
                amount = 25;
            }
            if kind == "item_health_mega" {
                return PickupRule(
                    kind="health",
                    amount=100,
                    capacity=10000,
                    rot=True,
                    model="models/items/mega_h/tris.md2",
                    sound="sound/items/m_health.wav"
                );
            }
            return PickupRule(
                kind="health",
                amount=amount,
                capacity=cap,
                model="models/items/healing/" + size + "/tris.md2",
                sound=health_sound(size)
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
                model="models/powerups/health/" + size + "_cross.md3",
                extra_model="models/powerups/health/" + size + "_sphere.md3",
                sound=health_sound(size)
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
    return special_rule(game, kind, fields);
}

# Powerups, holdables and capacity items from each game's original item table.
def special_rule(game: str, kind: str, fields: dict[str, str]) -> PickupRule | None {
    powerups: dict[str, tuple[str, str]] = {};
    if game == "q1" {
        powerups = {
            "item_artifact_super_damage": ("quad", "progs/quaddama.mdl"),
            "item_artifact_invulnerability": ("invulnerability", "progs/invulner.mdl"),
            "item_artifact_invisibility": ("invisibility", "progs/invisibl.mdl"),
            "item_artifact_envirosuit": ("suit", "progs/suit.mdl")
        };
    } elif game == "q3" {
        powerups = {
            "item_quad": ("quad", "models/powerups/instant/quad.md3"),
            "item_enviro": ("battlesuit", "models/powerups/instant/enviro.md3"),
            "item_haste": ("haste", "models/powerups/instant/haste.md3"),
            "item_invis": ("invisibility", "models/powerups/instant/invis.md3"),
            "item_regen": ("regen", "models/powerups/instant/regen.md3"),
            "item_flight": ("flight", "models/powerups/instant/flight.md3")
        };
    }
    if kind in powerups {
        spec = powerups[kind];
        rule = powerup_rule(game, spec[0]);
        if rule is None {
            return None;
        }
        duration = rule.duration;
        if game == "q3" and int(fields.get("count", "0")) > 0 {
            duration = float(int(fields["count"]));
        }
        return PickupRule(
            kind="powerup",
            amount=1,
            capacity=1,
            model=spec[1],
            extra_model=spec[1].replace(".md3", "_ring.md3") if game == "q3" else "",
            powerup=spec[0],
            duration=duration,
            additive=rule.additive,
            sound=rule.pickup_sound,
            label=rule.name
        );
    }
    if game == "q2" {
        # Normal skill stores at most two of each powerup (g_items.c Pickup_Powerup).
        stored: dict[str, tuple[str, str, int]] = {
            "item_quad": ("powerup_quad", "quaddama", 2),
            "item_invulnerability": ("powerup_invulnerability", "invulner", 2),
            "item_silencer": ("powerup_silencer", "silencer", 2),
            "item_breather": ("powerup_breather", "breather", 2),
            "item_enviro": ("powerup_suit", "enviro", 2),
            "item_power_screen": ("power_screen", "armor/screen", 1),
            "item_power_shield": ("power_shield", "armor/shield", 1)
        };
        labels = {
            "powerup_quad": "Quad Damage",
            "powerup_invulnerability": "Invulnerability",
            "powerup_silencer": "Silencer",
            "powerup_breather": "Rebreather",
            "powerup_suit": "Environment Suit",
            "power_screen": "Power Screen",
            "power_shield": "Power Shield"
        };
        if kind in stored {
            held = stored[kind];
            return PickupRule(
                kind=held[0],
                amount=1,
                capacity=held[2],
                model="models/items/" + held[1] + "/tris.md2",
                sound="sound/misc/ar3_pkup.wav"
                    if held[0].startswith("power_")
                    else "sound/items/pkup.wav",
                label=labels[held[0]]
            );
        }
        if kind == "item_adrenaline" {
            return PickupRule(
                kind="adrenaline",
                amount=1,
                capacity=1,
                max_health_bonus=1,
                model="models/items/adrenal/tris.md2",
                sound="sound/items/pkup.wav",
                label="Adrenaline"
            );
        }
        if kind == "item_ancient_head" {
            return PickupRule(
                kind="ancient_head",
                amount=1,
                capacity=1,
                max_health_bonus=2,
                model="models/items/c_head/tris.md2",
                sound="sound/items/pkup.wav",
                label="Ancient Head"
            );
        }
        if kind == "item_bandolier" {
            return PickupRule(
                kind="bandolier",
                amount=1,
                capacity=1,
                capacities={"bullets": 250, "shells": 150, "cells": 250, "slugs": 75},
                grants={"bullets": 50, "shells": 10},
                model="models/items/band/tris.md2",
                sound="sound/items/pkup.wav",
                label="Bandolier"
            );
        }
        if kind == "item_pack" {
            return PickupRule(
                kind="pack",
                amount=1,
                capacity=1,
                capacities={
                    "bullets": 300,
                    "shells": 200,
                    "rockets": 100,
                    "grenades": 100,
                    "cells": 300,
                    "slugs": 100
                },
                grants={
                    "bullets": 50,
                    "shells": 10,
                    "cells": 50,
                    "grenades": 5,
                    "rockets": 5,
                    "slugs": 10
                },
                model="models/items/pack/tris.md2",
                sound="sound/items/pkup.wav",
                label="Ammo Pack"
            );
        }
        if kind == "item_armor_shard" {
            return PickupRule(
                kind="armor",
                amount=2,
                capacity=0,
                armor_mode="shard",
                armor_ratio=0.3,
                model="models/items/armor/shard/tris.md2",
                sound="sound/misc/ar2_pkup.wav"
            );
        }
    } elif game == "q3" {
        if kind == "item_armor_shard" {
            return PickupRule(
                kind="armor",
                amount=5,
                capacity=200,
                armor_mode="shard",
                armor_ratio=2.0 / 3.0,
                model="models/powerups/armor/shard.md3",
                extra_model="models/powerups/armor/shard_sphere.md3",
                sound="sound/misc/ar1_pkup.wav"
            );
        }
        if kind in ["holdable_medkit", "holdable_teleporter"] {
            return PickupRule(
                kind=kind,
                amount=1,
                capacity=1,
                model="models/powerups/holdable/" + kind[len("holdable_"):] + ".md3",
                sound="sound/items/holdable.wav",
                label="Medkit" if kind == "holdable_medkit" else "Personal Teleporter"
            );
        }
    }
    return None;
}


# Q1 spins MDL items flagged EF_ROTATE, Q2 its EF_ROTATE item table entries,
# and Q3 every item with cg.autoAngles (one turn per 2048 ms).
def item_spin(game: str, rule: PickupRule, flags: int) -> float {
    if game == "q1" {
        return 100.0 if flags & 8 else 0.0;
    }
    if game == "q2" {
        still = rule.kind == "health"
            or (
                not rule.kind.startswith("weapon_")
                    and rule.kind
                        in ["shells", "bullets", "grenades", "rockets", "cells", "slugs"]
            );
        return 0.0 if still else 100.0;
    }
    if game == "q3" {
        return 360.0 / 2.048;
    }
    return 0.0;
}

def populate_pickups(world: World, level: Level, directory: str) -> int {
    catalog = AssetCatalog(game=level.bsp.game, directory=directory);
    resources: dict[str, ModelResource] = {};
    count = 0;
    try {
        for index in range(len(level.bsp.entities)) {
            fields = level.bsp.entities[index].fields;
            spawned = level.bsp.game == "q2"
                and fields.get("classname", "") == "target_spawner";
            if spawned {
                # The item appears at the spawner once the spawner is used.
                fields = {
                    "classname": fields.get("target", ""),
                    "origin": fields.get("origin", "0 0 0"),
                    "angle": fields.get("angle", "0"),
                    "spawnflags": "1"
                };
            }
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
            extra = source + ":" + rule.extra_model + ":0" if rule.extra_model else "";
            for name in [key, extra] {
                if not name or name in resources {
                    continue;
                }
                parts = name.rsplit(":", 1);
                loaded = catalog.model(parts[0], int(parts[1]));
                resource = ModelResource(
                    name=name, model=loaded.model, skins=loaded.skins
                );
                resources[name] = resource;
                world +>:HasModelResource:+> resource;
            }
            waiting_for_use = (level.bsp.game == "q2" and flags & 1 != 0)
                or (level.bsp.game == "q3" and bool(fields.get("targetname", "")));
            respawn = 0.0;
            first_delay = 0.0;
            if level.bsp.game == "q3" {
                # g_items.c RESPAWN_* values; powerups first appear 30-60 s in.
                respawn = 5.0
                    if rule.kind.startswith("weapon_")
                    else (
                        35.0
                            if rule.kind == "health"
                            else (
                                25.0
                                    if rule.kind == "armor"
                                    else (
                                        120.0
                                            if rule.kind == "powerup"
                                            else (
                                                60.0
                                                    if rule.kind.startswith("holdable_")
                                                    else 40.0
                                            )
                                    )
                            )
                    );
                if "wait" in fields {
                    respawn = max(0.0, float(fields["wait"]));
                }
                if rule.kind == "powerup" {
                    first_delay = 30.0 + float((index * 7919 + 17) % 31);
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
            if first_delay > 0.0 and pickup.active {
                pickup.active = False;
                pickup.remaining = first_delay;
            }
            pickup.visual = attach_model(pickup, resources[key]);
            if extra {
                pickup.visual +>:UsesModel:+> resources[extra];
            }
            pickup.visual.spin = item_spin(source, rule, resources[key].model.flags);
            if source == "q3" {
                # cg_ents.c CG_Item: bob 4 +/- 4 units at a per-entity rate.
                pickup.visual.bob = 4.0;
                pickup.visual.bob_rate = 5.0 + float(index) * 0.01;
            }
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

"""What a monster leaves when it dies. Q1 DropBackpack: grunts carry 5
shells, enforcers 5 cells and ogres 2 rockets (their ammo_* fields). Q2
monster_death_use: Drop_Item of the monster's `item` key."""
def monster_drop(game: str, kind: str, fields: dict[str, str]) -> PickupRule | None {
    if game == "q1" {
        packed = {
            "monster_army": "shells",
            "monster_enforcer": "cells",
            "monster_ogre": "rockets",
            "monster_ogre_marksman": "rockets"
        };
        if kind not in packed {
            return None;
        }
        ammo = packed[kind];
        return PickupRule(
            kind="backpack",
            amount=1,
            capacity=1,
            capacities={ammo: 100},
            grants={ammo: 2 if ammo == "rockets" else 5},
            model="progs/backpack.mdl",
            sound="sound/weapons/lock4.wav"
        );
    }
    if game == "q2" and fields.get("item", "") {
        return pickup_rule("q2", {"classname": fields["item"]});
    }
    return None;
}

