"""The budget: health, armour and ammunition along the route a proof found.

A ledger is walked along the sure route. Supplies standing in the places it
passes, or in sight a short detour off it, are taken; each monster is fought when the route first comes where
it stands or sees it within 640 units. A fight is won with the best weapon
held that has the ammunition for it (the melee weapon at worst): it costs
the monster's health in ammunition, and its damage a second for as long as
killing it takes (twice that in melee), armour taking its share. The ledger
says how low health fell and what was left; it is an estimate of the
fights, not a simulation of them.

`stage_budget` sums what each progression stage of a level holds (the
threat of its monsters, the health, armour and damage in ammunition of its
supplies): the curve a level made from it is cast to."""
import from ..math.vec3 { Vec3 }
import from ..physics.collision { CollisionMap }
import from .graph { LevelGraph, Place, Thing, graph_places, graph_things, thing_place }

"""A weapon for the ledger: the ammunition it spends, the damage a unit of
it does, the damage a second it deals (melee: no ammunition)."""
obj Arm {
    has ammo: str = "",
        per: float = 0.0,
        rate: float = 0.0;
}

glob BUDGET_ARMS: dict[str, Arm] = {
         "q1:axe": Arm(rate=40.0),
         "q1:weapon_shotgun": Arm(ammo="shells", per=24.0, rate=48.0),
         "q1:weapon_supershotgun": Arm(ammo="shells", per=28.0, rate=80.0),
         "q1:weapon_nailgun": Arm(ammo="nails", per=9.0, rate=90.0),
         "q1:weapon_supernailgun": Arm(ammo="nails", per=9.0, rate=180.0),
         "q1:weapon_grenadelauncher": Arm(ammo="rockets", per=100.0, rate=160.0),
         "q1:weapon_rocketlauncher": Arm(ammo="rockets", per=100.0, rate=125.0),
         "q1:weapon_lightning": Arm(ammo="cells", per=30.0, rate=300.0),
         "q2:weapon_blaster": Arm(rate=25.0),
         "q2:weapon_shotgun": Arm(ammo="shells", per=48.0, rate=48.0),
         "q2:weapon_supershotgun": Arm(ammo="shells", per=60.0, rate=110.0),
         "q2:weapon_machinegun": Arm(ammo="bullets", per=8.0, rate=80.0),
         "q2:weapon_chaingun": Arm(ammo="bullets", per=6.0, rate=180.0),
         "q2:weapon_grenadelauncher": Arm(ammo="grenades", per=120.0, rate=110.0),
         "q2:weapon_rocketlauncher": Arm(ammo="rockets", per=100.0, rate=125.0),
         "q2:weapon_hyperblaster": Arm(ammo="cells", per=20.0, rate=200.0),
         "q2:weapon_railgun": Arm(ammo="slugs", per=100.0, rate=70.0),
         "q2:weapon_bfg": Arm(ammo="cells", per=10.0, rate=250.0),
         "q3:weapon_gauntlet": Arm(rate=50.0),
         "q3:weapon_machinegun": Arm(ammo="bullets", per=7.0, rate=70.0),
         "q3:weapon_shotgun": Arm(ammo="shells", per=110.0, rate=110.0),
         "q3:weapon_grenadelauncher": Arm(ammo="grenades", per=100.0, rate=125.0),
         "q3:weapon_rocketlauncher": Arm(ammo="rockets", per=100.0, rate=125.0),
         "q3:weapon_lightning": Arm(ammo="lightning", per=8.0, rate=400.0),
         "q3:weapon_railgun": Arm(ammo="slugs", per=100.0, rate=67.0),
         "q3:weapon_plasmagun": Arm(ammo="cells", per=20.0, rate=200.0),
         "q3:weapon_bfg": Arm(ammo="bfg", per=100.0, rate=100.0)
     };

"""How far off the route a supply in sight is fetched, and the share of a
fight a player stands exposed to a foe's fire (the rest is cover and
dodging)."""
glob BUDGET_DETOUR: float = 320.0,
     BUDGET_EXPOSURE: float = 0.5;

"""Monsters: [health, damage a second to a player it fights]."""
glob BUDGET_FOES: dict[str, list[float]] = {
         "q1:monster_army": [30.0, 6.0],
         "q1:monster_dog": [25.0, 8.0],
         "q1:monster_knight": [75.0, 8.0],
         "q1:monster_enforcer": [80.0, 8.0],
         "q1:monster_wizard": [80.0, 6.0],
         "q1:monster_zombie": [60.0, 5.0],
         "q1:monster_fish": [25.0, 6.0],
         "q1:monster_ogre": [200.0, 14.0],
         "q1:monster_demon1": [300.0, 20.0],
         "q1:monster_hell_knight": [250.0, 14.0],
         "q1:monster_shalrath": [400.0, 12.0],
         "q1:monster_tarbaby": [80.0, 10.0],
         "q1:monster_shambler": [600.0, 30.0],
         "q2:monster_soldier_light": [20.0, 5.0],
         "q2:monster_soldier": [30.0, 6.0],
         "q2:monster_soldier_ss": [40.0, 8.0],
         "q2:monster_infantry": [100.0, 10.0],
         "q2:monster_gunner": [175.0, 14.0],
         "q2:monster_berserk": [240.0, 16.0],
         "q2:monster_gladiator": [400.0, 20.0],
         "q2:monster_tank": [750.0, 25.0],
         "q2:monster_tank_commander": [1000.0, 30.0],
         "q2:monster_medic": [300.0, 10.0],
         "q2:monster_chick": [175.0, 14.0],
         "q2:monster_parasite": [175.0, 12.0],
         "q2:monster_flyer": [50.0, 6.0],
         "q2:monster_floater": [200.0, 10.0],
         "q2:monster_hover": [240.0, 12.0],
         "q2:monster_mutant": [300.0, 18.0],
         "q2:monster_brain": [300.0, 14.0],
         "q2:monster_flipper": [50.0, 6.0],
         "q2:monster_supertank": [1500.0, 35.0],
         "q3:info_player_deathmatch": [100.0, 12.0]
     };

"""A foe's [health, damage a second]; unknown ones are middling."""
def foe_stats(game: str, classname: str) -> list[float] {
    return BUDGET_FOES.get(game + ":" + classname, [150.0, 12.0]);
}

"""A weapon's rules; None for one not known."""
def arm_of(game: str, classname: str) -> Arm | None {
    return BUDGET_ARMS.get(game + ":" + classname, None);
}

"""What a supply gives, as (kind, amount) pairs: `health`, `mega` (health
over the maximum), `armor:<share it takes>`, an ammunition's kind, or
`weapon` (amount ignored)."""
def supply_of(game: str, name: str, spawnflags: int) -> list[tuple[str, float]] {
    big = spawnflags & 1 != 0;
    if game == "q1" {
        if name == "item_health" {
            return [("health", 15.0)] if spawnflags & 1 else ([("mega", 100.0)] if spawnflags & 2 else [("health", 25.0)]);
        }
        if name in ["item_armor1", "item_armor2", "item_armorInv"] {
            return [("armor:" + {"item_armor1": "0.3", "item_armor2": "0.6", "item_armorInv": "0.8"}[name], {"item_armor1": 100.0, "item_armor2": 150.0, "item_armorInv": 200.0}[name])];
        }
        for (item, kind, small) in [("item_shells", "shells", 20.0), ("item_spikes", "nails", 25.0), ("item_rockets", "rockets", 5.0), ("item_cells", "cells", 6.0)] {
            if name == item {
                return [(kind, small * (2.0 if big else 1.0))];
            }
        }
        for (weapon, kind, amount) in [
            ("weapon_supershotgun", "shells", 5.0),
            ("weapon_nailgun", "nails", 30.0),
            ("weapon_supernailgun", "nails", 30.0),
            ("weapon_grenadelauncher", "rockets", 5.0),
            ("weapon_rocketlauncher", "rockets", 5.0),
            ("weapon_lightning", "cells", 15.0)
        ] {
            if name == weapon {
                return [("weapon", 1.0), (kind, amount)];
            }
        }
        return [];
    }
    if game == "q2" {
        healths = {"item_health": 10.0, "item_health_small": 2.0, "item_health_large": 25.0};
        if name in healths {
            return [("health", healths[name])];
        }
        if name == "item_health_mega" {
            return [("mega", 100.0)];
        }
        armors = {"item_armor_shard": ("0.3", 2.0), "item_armor_jacket": ("0.3", 25.0), "item_armor_combat": ("0.6", 50.0), "item_armor_body": ("0.8", 100.0)};
        if name in armors {
            return [("armor:" + armors[name][0], armors[name][1])];
        }
        ammo = {"ammo_shells": ("shells", 10.0), "ammo_bullets": ("bullets", 50.0), "ammo_grenades": ("grenades", 5.0), "ammo_rockets": ("rockets", 5.0), "ammo_cells": ("cells", 50.0), "ammo_slugs": ("slugs", 10.0)};
        if name in ammo {
            return [(ammo[name][0], ammo[name][1])];
        }
        arms = {
            "weapon_shotgun": ("shells", 10.0),
            "weapon_supershotgun": ("shells", 10.0),
            "weapon_machinegun": ("bullets", 50.0),
            "weapon_chaingun": ("bullets", 50.0),
            "weapon_grenadelauncher": ("grenades", 10.0),
            "weapon_rocketlauncher": ("rockets", 5.0),
            "weapon_hyperblaster": ("cells", 50.0),
            "weapon_railgun": ("slugs", 10.0),
            "weapon_bfg": ("cells", 50.0)
        };
        if name in arms {
            return [("weapon", 1.0), (arms[name][0], arms[name][1])];
        }
        return [];
    }
    healths = {"item_health": 25.0, "item_health_small": 5.0, "item_health_large": 50.0};
    if name in healths {
        return [("health", healths[name])];
    }
    if name == "item_health_mega" {
        return [("mega", 100.0)];
    }
    plates = {"item_armor_shard": 5.0, "item_armor_combat": 50.0, "item_armor_body": 100.0};
    if name in plates {
        return [("armor:0.66", plates[name])];
    }
    ammo = {
        "ammo_bullets": ("bullets", 50.0),
        "ammo_shells": ("shells", 10.0),
        "ammo_grenades": ("grenades", 5.0),
        "ammo_cells": ("cells", 30.0),
        "ammo_lightning": ("lightning", 60.0),
        "ammo_rockets": ("rockets", 5.0),
        "ammo_slugs": ("slugs", 10.0),
        "ammo_bfg": ("bfg", 15.0)
    };
    if name in ammo {
        return [(ammo[name][0], ammo[name][1])];
    }
    arms = {
        "weapon_machinegun": ("bullets", 40.0),
        "weapon_shotgun": ("shells", 10.0),
        "weapon_grenadelauncher": ("grenades", 10.0),
        "weapon_rocketlauncher": ("rockets", 10.0),
        "weapon_lightning": ("lightning", 100.0),
        "weapon_railgun": ("slugs", 10.0),
        "weapon_plasmagun": ("cells", 50.0),
        "weapon_bfg": ("bfg", 20.0)
    };
    if name in arms {
        return [("weapon", 1.0), (arms[name][0], arms[name][1])];
    }
    return [];
}

"""What a player starts with in each game: weapons (game:classname) and
ammunition."""
def start_kit(game: str) -> Budget {
    kit = Budget();
    if game == "q2" {
        kit.weapons = ["q2:weapon_blaster"];
    } elif game == "q3" {
        kit.weapons = ["q3:weapon_gauntlet", "q3:weapon_machinegun"];
        kit.ammo["bullets"] = 100.0;
    } else {
        kit.weapons = ["q1:axe", "q1:weapon_shotgun"];
        kit.ammo["shells"] = 25.0;
    }
    return kit;
}

"""The ledger along a route."""
obj Budget {
    has health: float = 100.0,
        armor: float = 0.0,
        share: float = 0.0,
        ammo: dict[str, float] = {},
        weapons: list[str] = [],
        lowest: float = 100.0,
        fights: int = 0,
        melee: int = 0,
        worst: str = "",
        lines: list[str] = [];

    """Take a supply."""
    def take(game: str, name: str, spawnflags: int) {
        for (kind, amount) in supply_of(game, name, spawnflags) {
            if kind == "health" {
                if self.health < 100.0 {
                    self.health = min(100.0, self.health + amount);
                }
            } elif kind == "mega" {
                self.health = min(250.0, self.health + amount);
            } elif kind.startswith("armor:") {
                share = float(kind[6:]);
                if amount * share > self.armor * self.share {
                    self.armor = amount;
                    self.share = share;
                }
            } elif kind == "weapon" {
                key = game + ":" + name;
                if key not in self.weapons {
                    self.weapons.append(key);
                }
            } else {
                self.ammo[kind] = self.ammo.get(kind, 0.0) + amount;
            }
        }
        self.lines.append("take " + game + ":" + name + " health " + str(int(self.health)) + " armor " + str(int(self.armor)));
    }

    """Fight a monster: with the best weapon that can kill it, else in melee."""
    def fight(game: str, name: str) {
        stats = foe_stats(game, name);
        health = stats[0];
        best = "";
        best_arm = Arm(rate=30.0);
        for weapon in self.weapons {
            arm = BUDGET_ARMS.get(weapon, None);
            if arm is None {
                continue;
            }
            usable = not arm.ammo or self.ammo.get(arm.ammo, 0.0) * arm.per >= health;
            if usable and (not best or (arm.ammo and not best_arm.ammo) or (bool(arm.ammo) == bool(best_arm.ammo) and arm.rate > best_arm.rate)) {
                best = weapon;
                best_arm = arm;
            }
        }
        seconds = health / best_arm.rate;
        damage = stats[1] * seconds * BUDGET_EXPOSURE * (2.0 if not best_arm.ammo else 1.0);
        if best_arm.ammo {
            self.ammo[best_arm.ammo] = self.ammo.get(best_arm.ammo, 0.0) - health / best_arm.per;
        } else {
            self.melee += 1;
        }
        saved = min(self.armor, damage * self.share);
        self.armor -= saved;
        self.health -= damage - saved;
        self.fights += 1;
        if self.health < self.lowest {
            self.lowest = self.health;
            self.worst = game + ":" + name;
        }
        self.lines.append("fight " + game + ":" + name + " with " + (best or "fists") + " health " + str(int(self.health)) + " armor " + str(int(self.armor)));
    }
}

"""Walk a sure route with a ledger that starts as `kit` (copied)."""
def budget_route(atlas: LevelGraph, route: list[int], collision: CollisionMap, kit: Budget) -> Budget {
    ledger = Budget(health=kit.health, armor=kit.armor, share=kit.share, ammo=dict(kit.ammo), weapons=list(kit.weapons));
    by_area: dict[int, Place] = {};
    for place in graph_places(atlas) {
        by_area[place.area] = place;
    }
    things = graph_things(atlas);
    stands: list[int] = [];
    for thing in things {
        at = thing_place(thing);
        stands.append(at.area if at is not None else -1);
    }
    done = [False for _ in things];
    for area in route {
        place = by_area.get(area, None);
        if place is None {
            continue;
        }
        eye = place.center.add(Vec3(z=collision.eye_height));
        for index in range(len(things)) {
            if done[index] {
                continue;
            }
            thing = things[index];
            if thing.classname.startswith("monster_") or thing.classname == "info_player_deathmatch" {
                near = stands[index] == area;
                if not near and eye.sub(thing.point).length() < 640.0 {
                    near = collision.trace(eye, thing.point.add(Vec3(z=16.0)), [], -1.0, True).fraction >= 0.99;
                }
                if near {
                    done[index] = True;
                    ledger.fight(thing.game, thing.classname);
                }
            } else {
                # A supply on the way, or a short detour off it in sight.
                near = stands[index] == area;
                if not near and eye.sub(thing.point).length() < BUDGET_DETOUR {
                    near = collision.trace(eye, thing.point.add(Vec3(z=16.0)), [], -1.0, True).fraction >= 0.99;
                }
                if near {
                    done[index] = True;
                    ledger.take(thing.game, thing.classname, thing.spawnflags);
                }
            }
        }
    }
    return ledger;
}

"""What each progression stage holds: stage -> [threat (the monsters'
health), health, armour (as what it absorbs), ammunition (as damage it
does with the best weapon of its kind)]."""
def stage_budget(atlas: LevelGraph) -> dict[int, list[float]] {
    found: dict[int, list[float]] = {};
    for thing in graph_things(atlas) {
        at = thing_place(thing);
        if at is None or at.stage < 0 {
            continue;
        }
        row = found.get(at.stage, [0.0, 0.0, 0.0, 0.0]);
        if thing.classname.startswith("monster_") {
            row[0] += foe_stats(thing.game, thing.classname)[0];
        } else {
            for (kind, amount) in supply_of(thing.game, thing.classname, thing.spawnflags) {
                if kind in ["health", "mega"] {
                    row[1] += amount;
                } elif kind.startswith("armor:") {
                    row[2] += amount * float(kind[6:]);
                } elif kind != "weapon" {
                    row[3] += amount * ammo_damage(kind);
                }
            }
        }
        found[at.stage] = row;
    }
    return found;
}

"""The damage a unit of an ammunition does with the best weapon that
spends it."""
def ammo_damage(kind: str) -> float {
    best = 0.0;
    for arm in BUDGET_ARMS.values() {
        if arm.ammo == kind {
            best = max(best, arm.per);
        }
    }
    return best;
}
