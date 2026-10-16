"""Generation uses the same item amounts, ammo pools and weapon damage as
play. Forecasts are conservative budgets, not a simulation of a human fight.
"""
import math;
import from games.items { item_rule }
import from games.weapons { weapon_rules, PASSION_AMMO_CAPS }
import from engine.world.weapons { WeaponRule }
import from engine.world.pickups { PickupRule }

glob WEAPON_PROGRESSION: dict[str, list[str]] = {
         "q1": ["supershotgun", "nailgun", "grenadelauncher"],
         "q2": ["shotgun", "machinegun", "rocketlauncher"],
         "q3": ["shotgun", "plasmagun", "rocketlauncher"]
     };

def progression_weapon(source: str, tier: int) -> WeaponRule {
    key = WEAPON_PROGRESSION[source][max(0, min(2, tier))];
    for rule in weapon_rules(source) {
        if rule.key == key {
            return rule;
        }
    }
    raise ValueError("No progression weapon " + source + ":" + key);
}

def ammo_class(source: str, kind: str) -> str {
    if source == "q1" {
        return {
            "shells": "item_shells",
            "nails": "item_spikes",
            "rockets": "item_rockets",
            "cells": "item_cells"
        }.get(
            kind, ""
        );
    }
    return "ammo_" + kind if kind in PASSION_AMMO_CAPS else "";
}

def supply_rule(source: str, classname: str, flags: str = "0") -> PickupRule {
    rule = item_rule(source, {"classname": classname, "spawnflags": flags});
    if rule is None {
        raise ValueError("No pickup rule for " + source + ":" + classname);
    }
    return rule;
}

def health_after(health: float, rule: PickupRule) -> float {
    ceiling = rule.capacity if rule.capacity > 0 else 100;
    return max(health, min(float(ceiling), health + float(rule.amount)));
}

"""Budget direct hits at 55 percent accuracy, including multi-pellet
shots and ammo cost. Splash damage and monster drops are spare capacity.
"""
def fight_rounds(weapon: WeaponRule, enemy_health: int) -> int {
    if enemy_health <= 0 or not weapon.ammo {
        return 0;
    }
    damage = max(1.0, float(weapon.damage * max(1, weapon.pellets)) * 0.55);
    return (int(math.ceil(float(enemy_health) / damage)) + 2) * max(1, weapon.cost);
}
