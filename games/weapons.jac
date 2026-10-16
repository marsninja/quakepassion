"""Original base-game arsenals expressed as shared weapon rules.

Animation timing, charged hand grenades and the Q2 BFG secondary laser phase
remain separate fidelity work; ballistic effects use the common simulation.
"""
import from engine.formats.sprite { EffectRule, effect_game }
import from engine.math.vec3 { Vec3 }
import from engine.world.weapons { WeaponRule, passion_slot, owned_kind }
import from engine.world.world { Player }
import from engine.world.combat { CombatState }
import from engine.world.inventory { AdjustInventory }

"""A game's weapons, each knowing its game and its own slot; a Passion
level's are all three games' together (passion_arsenal)."""
def weapon_rules(game: str) -> list[WeaponRule] {
    if game == "passion" {
        return passion_arsenal();
    }
    rules = game_weapon_rules(game);
    for rule in rules {
        rule.game = game;
        rule.game_slot = rule.slot;
    }
    return rules;
}

"""Which number key takes up each game's weapon in a Passion level, in the
order a key steps through them: 1 melee, 2 the blaster and machine guns,
3 shotguns, 4 nail and chain guns, 5 grenades, 6 rockets, 7 energy, 8 rail,
9 the BFG."""
glob PASSION_ROLES: list[tuple[str, str, int]] = [
    ("q1", "axe", 1),
    ("q3", "gauntlet", 1),
    ("q2", "blaster", 2),
    ("q2", "machinegun", 2),
    ("q3", "machinegun", 2),
    ("q1", "shotgun", 3),
    ("q2", "shotgun", 3),
    ("q3", "shotgun", 3),
    ("q1", "supershotgun", 3),
    ("q2", "supershotgun", 3),
    ("q1", "nailgun", 4),
    ("q1", "supernailgun", 4),
    ("q2", "chaingun", 4),
    ("q1", "grenadelauncher", 5),
    ("q2", "grenadelauncher", 5),
    ("q3", "grenadelauncher", 5),
    ("q2", "handgrenade", 5),
    ("q1", "rocketlauncher", 6),
    ("q2", "rocketlauncher", 6),
    ("q3", "rocketlauncher", 6),
    ("q1", "lightning", 7),
    ("q3", "lightning", 7),
    ("q2", "hyperblaster", 7),
    ("q3", "plasmagun", 7),
    ("q2", "railgun", 8),
    ("q3", "railgun", 8),
    ("q2", "bfg", 9),
    ("q3", "bfg", 9)
];

"""How much of each kind of ammunition a Passion player can carry: one pool
for each kind, whichever game's guns spend it."""
glob PASSION_AMMO_CAPS: dict[str, int] = {
    "shells": 100,
    "nails": 200,
    "bullets": 200,
    "grenades": 50,
    "rockets": 100,
    "cells": 200,
    "slugs": 50,
    "lightning": 200,
    "bfg": 100
};

"""A Passion level's arsenal: every weapon of the three games, each with
its own game's rules, numbered apart (passion_slot), held as
weapon_<game>:<key> and taken up by its role's number key."""
def passion_arsenal -> list[WeaponRule] {
    arsenal: list[WeaponRule] = [];
    for (game, key, role) in PASSION_ROLES {
        for rule in game_weapon_rules(game) {
            if rule.key == key and rule.slot > 0 {
                rule.game = game;
                rule.game_slot = rule.slot;
                rule.slot = passion_slot(game, rule.slot);
                rule.role = role;
                rule.item = "weapon_" + game + ":" + key;
                if rule.ammo in PASSION_AMMO_CAPS {
                    rule.capacity = PASSION_AMMO_CAPS[rule.ammo];
                }
                arsenal.append(rule);
            }
        }
    }
    return arsenal;
}

"""The game a level's things come from most (their asset_game), which a
Passion player starts out armed for; Quake's when none says."""
def lead_game(sources: list[str], planned: str = "") -> str {
    # A generated level keeps its planned kit as rewards change item counts.
    if planned in ["q1", "q2", "q3"] { return planned; }
    counts: dict[str, int] = {"q1": 0, "q2": 0, "q3": 0};
    for source in sources {
        if source in counts {
            counts[source] += 1;
        }
    }
    lead = "q1";
    for game in ["q2", "q3"] {
        if counts[game] > counts[lead] {
            lead = game;
        }
    }
    return lead;
}

"""What a Passion player starts with: the weapons held, the one taken up,
and its ammunition."""
obj PassionKit {
    has weapons: list[str] = [],
        held: int = 0,
        ammo: str = "",
        rounds: int = 0;
}

"""The start when the level draws most on `lead`: that game's melee weapon
(Quake II has none) and its first gun, and the gun's own ammunition."""
def passion_start(lead: str) -> PassionKit {
    if lead == "q2" {
        return PassionKit(weapons=["weapon_q2:blaster"], held=passion_slot("q2", 1));
    }
    if lead == "q3" {
        return PassionKit(
            weapons=["weapon_q3:gauntlet", "weapon_q3:machinegun"], held=passion_slot("q3", 2), ammo="bullets", rounds=100
        );
    }
    return PassionKit(weapons=["weapon_q1:axe", "weapon_q1:shotgun"], held=passion_slot("q1", 2), ammo="shells", rounds=25);
}

def game_weapon_rules(game: str) -> list[WeaponRule] {
    if game == "q1" {
        return [
            WeaponRule(
                slot=1,
                key="axe",
                muzzle=Vec3(z=-6.0),
                name="Axe",
                damage=20,
                interval=0.5,
                reach=64.0
            ),
            WeaponRule(
                slot=2,
                key="shotgun",
                muzzle=Vec3(x=10.0, z=-6.8),
                muzzle_level=True,
                name="Shotgun",
                punch=2.0,
                punch_time=0.2,
                ammo="shells",
                capacity=100,
                pickup_ammo=5,
                damage=4,
                interval=0.5,
                pellets=6,
                spread=0.04,
                vertical_spread=0.04
            ),
            WeaponRule(
                slot=3,
                key="supershotgun",
                muzzle=Vec3(x=10.0, z=-6.8),
                muzzle_level=True,
                name="Super shotgun",
                punch=4.0,
                punch_time=0.4,
                ammo="shells",
                capacity=100,
                pickup_ammo=5,
                cost=2,
                damage=4,
                interval=0.7,
                pellets=14,
                spread=0.14,
                vertical_spread=0.08,
                model="progs/g_shot.mdl"
            ),
            WeaponRule(
                slot=4,
                key="nailgun",
                muzzle=Vec3(y=4.0, z=-6.0),
                muzzle_alternates=True,
                name="Nailgun",
                punch=2.0,
                punch_time=0.2,
                ammo="nails",
                capacity=200,
                pickup_ammo=30,
                damage=9,
                interval=0.1,
                speed=1000.0,
                model="progs/g_nail.mdl",
                effect="q1_nail"
            ),
            WeaponRule(
                slot=5,
                key="supernailgun",
                muzzle=Vec3(z=-6.0),
                name="Super nailgun",
                punch=2.0,
                punch_time=0.2,
                ammo="nails",
                capacity=200,
                pickup_ammo=30,
                cost=2,
                damage=18,
                interval=0.1,
                speed=1000.0,
                model="progs/g_nail2.mdl",
                effect="q1_supernail"
            ),
            WeaponRule(
                slot=6,
                key="grenadelauncher",
                muzzle=Vec3(z=-22.0),
                name="Grenade launcher",
                punch=2.0,
                punch_time=0.2,
                ammo="rockets",
                capacity=100,
                pickup_ammo=5,
                damage=120,
                interval=0.6,
                speed=600.0,
                splash=120,
                radius=160.0,
                gravity=True,
                fuse=2.5,
                model="progs/g_rock.mdl",
                effect="q1_grenade"
            ),
            WeaponRule(
                slot=7,
                key="rocketlauncher",
                muzzle=Vec3(x=8.0, z=-6.0),
                name="Rocket launcher",
                punch=2.0,
                punch_time=0.2,
                ammo="rockets",
                capacity=100,
                pickup_ammo=5,
                damage=100,
                interval=0.8,
                speed=1000.0,
                splash=120,
                radius=160.0,
                model="progs/g_rock2.mdl",
                effect="q1_rocket"
            ),
            WeaponRule(
                slot=8,
                key="lightning",
                muzzle=Vec3(z=-6.0),
                name="Thunderbolt",
                punch=2.0,
                punch_time=0.2,
                ammo="cells",
                capacity=100,
                pickup_ammo=15,
                damage=30,
                interval=0.1,
                reach=600.0,
                model="progs/g_light.mdl",
                avoid_underwater=True
            )
        ];
    }
    if game == "q2" {
        return [
            WeaponRule(
                slot=1,
                key="blaster",
                muzzle=Vec3(x=24.0, y=8.0, z=-8.0),
                name="Blaster",
                punch=1.0,
                punch_time=0.1,
                raise_time=0.4,
                lower_time=0.3,
                damage=10,
                kick=1,
                interval=0.5,
                speed=1000.0,
                effect="q2_bolt"
            ),
            WeaponRule(
                slot=2,
                key="shotgun",
                muzzle=Vec3(y=8.0, z=-8.0),
                name="Shotgun",
                punch=2.0,
                punch_time=0.1,
                raise_time=0.7,
                lower_time=0.3,
                ammo="shells",
                capacity=100,
                pickup_ammo=10,
                damage=4,
                kick=8,
                interval=1.0,
                pellets=12,
                spread=0.0625,
                vertical_spread=0.0625,
                model="models/weapons/g_shotg/tris.md2"
            ),
            WeaponRule(
                slot=3,
                key="supershotgun",
                muzzle=Vec3(y=8.0, z=-8.0),
                name="Super shotgun",
                punch=2.0,
                punch_time=0.1,
                raise_time=0.6,
                lower_time=0.4,
                ammo="shells",
                capacity=100,
                pickup_ammo=10,
                cost=2,
                damage=6,
                kick=12,
                interval=1.0,
                pellets=20,
                spread=0.125,
                vertical_spread=0.0625,
                model="models/weapons/g_shotg2/tris.md2"
            ),
            WeaponRule(
                slot=4,
                key="machinegun",
                muzzle=Vec3(y=8.0, z=-8.0),
                name="Machinegun",
                raise_time=0.3,
                lower_time=0.4,
                ammo="bullets",
                capacity=200,
                pickup_ammo=50,
                damage=8,
                kick=2,
                interval=0.1,
                spread=0.037,
                vertical_spread=0.061,
                model="models/weapons/g_machn/tris.md2"
            ),
            WeaponRule(
                slot=5,
                key="chaingun",
                muzzle=Vec3(y=7.0, z=-8.0),
                muzzle_jitter=4.0,
                name="Chaingun",
                raise_time=0.4,
                lower_time=0.3,
                ammo="bullets",
                capacity=200,
                pickup_ammo=50,
                damage=8,
                kick=2,
                interval=0.1,
                spread=0.037,
                vertical_spread=0.061,
                model="models/weapons/g_chain/tris.md2"
            ),
            WeaponRule(
                slot=6,
                key="grenadelauncher",
                muzzle=Vec3(x=8.0, y=8.0, z=-8.0),
                name="Grenade launcher",
                punch=1.0,
                punch_time=0.1,
                raise_time=0.5,
                lower_time=0.5,
                ammo="grenades",
                capacity=50,
                pickup_ammo=5,
                damage=120,
                interval=1.0,
                speed=600.0,
                splash=120,
                radius=160.0,
                gravity=True,
                fuse=2.5,
                model="models/weapons/g_launch/tris.md2",
                effect="q2_grenade"
            ),
            WeaponRule(
                slot=7,
                key="rocketlauncher",
                muzzle=Vec3(x=8.0, y=8.0, z=-8.0),
                name="Rocket launcher",
                punch=1.0,
                punch_time=0.1,
                raise_time=0.4,
                lower_time=0.4,
                ammo="rockets",
                capacity=50,
                pickup_ammo=5,
                damage=100,
                interval=0.8,
                speed=650.0,
                splash=120,
                radius=120.0,
                model="models/weapons/g_rocket/tris.md2",
                effect="q2_rocket"
            ),
            WeaponRule(
                slot=8,
                key="hyperblaster",
                muzzle=Vec3(x=24.0, y=8.0, z=-8.0),
                muzzle_orbit=4.0,
                name="Hyperblaster",
                punch=1.0,
                punch_time=0.1,
                raise_time=0.5,
                lower_time=0.4,
                ammo="cells",
                capacity=200,
                pickup_ammo=50,
                damage=20,
                kick=1,
                interval=0.1,
                speed=1000.0,
                model="models/weapons/g_hyperb/tris.md2",
                # fire_blaster(hyper): EF_HYPERBLASTER, lit but trailless.
                effect="q2_hyperbolt"
            ),
            WeaponRule(
                slot=9,
                key="railgun",
                muzzle=Vec3(y=7.0, z=-8.0),
                name="Railgun",
                punch=3.0,
                punch_time=0.1,
                raise_time=0.3,
                lower_time=0.5,
                ammo="slugs",
                capacity=50,
                pickup_ammo=10,
                damage=150,
                kick=250,
                interval=1.5,
                piercing=True,
                model="models/weapons/g_rail/tris.md2"
            ),
            WeaponRule(
                slot=10,
                key="bfg",
                muzzle=Vec3(x=8.0, y=8.0, z=-8.0),
                name="BFG10K",
                punch=40.0,
                punch_time=0.5,
                raise_time=0.8,
                lower_time=0.3,
                ammo="cells",
                capacity=200,
                pickup_ammo=50,
                cost=50,
                damage=200,
                interval=2.0,
                speed=400.0,
                splash=200,
                radius=100.0,
                beam_damage=10,
                beam_radius=256.0,
                burst_damage=500,
                burst_radius=1000.0,
                fuse=20.0,
                model="models/weapons/g_bfg/tris.md2",
                effect="q2_bfg"
            ),
            WeaponRule(
                slot=11,
                key="handgrenade",
                muzzle=Vec3(x=8.0, y=8.0, z=-8.0),
                name="Hand grenades",
                ammo="grenades",
                capacity=50,
                pickup_ammo=5,
                damage=125,
                interval=1.0,
                speed=400.0,
                splash=125,
                radius=165.0,
                gravity=True,
                fuse=3.2,
                hand_thrown=True,
                model="models/items/ammo/grenades/medium/tris.md2",
                effect="q2_handgrenade"
            )
        ];
    }
    if game == "q3" {
        return [
            WeaponRule(
                slot=1,
                key="gauntlet",
                muzzle=Vec3(x=14.0),
                name="Gauntlet",
                raise_time=0.25,
                lower_time=0.2,
                damage=50,
                interval=0.4,
                reach=32.0
            ),
            WeaponRule(
                slot=2,
                key="machinegun",
                muzzle=Vec3(x=14.0),
                name="Machinegun",
                circular=True,
                raise_time=0.25,
                lower_time=0.2,
                ammo="bullets",
                capacity=200,
                pickup_ammo=40,
                damage=7,
                interval=0.1,
                spread=0.0244,
                vertical_spread=0.0244,
                model="models/weapons2/machinegun/machinegun.md3"
            ),
            WeaponRule(
                slot=3,
                key="shotgun",
                muzzle=Vec3(x=14.0),
                name="Shotgun",
                raise_time=0.25,
                lower_time=0.2,
                ammo="shells",
                capacity=200,
                pickup_ammo=10,
                damage=10,
                interval=1.0,
                pellets=11,
                spread=0.085,
                vertical_spread=0.085,
                model="models/weapons2/shotgun/shotgun.md3"
            ),
            WeaponRule(
                slot=4,
                key="grenadelauncher",
                muzzle=Vec3(x=14.0),
                name="Grenade launcher",
                raise_time=0.25,
                lower_time=0.2,
                ammo="grenades",
                capacity=200,
                pickup_ammo=10,
                damage=100,
                interval=0.8,
                speed=700.0,
                splash=100,
                radius=150.0,
                gravity=True,
                fuse=2.5,
                model="models/weapons2/grenadel/grenadel.md3",
                effect="q3_grenade"
            ),
            WeaponRule(
                slot=5,
                key="rocketlauncher",
                muzzle=Vec3(x=14.0),
                name="Rocket launcher",
                fuse=15.0,
                raise_time=0.25,
                lower_time=0.2,
                ammo="rockets",
                capacity=200,
                pickup_ammo=10,
                damage=100,
                interval=0.8,
                speed=900.0,
                splash=100,
                radius=120.0,
                model="models/weapons2/rocketl/rocketl.md3",
                effect="q3_rocket"
            ),
            WeaponRule(
                slot=6,
                key="lightning",
                muzzle=Vec3(x=14.0),
                name="Lightning gun",
                raise_time=0.25,
                lower_time=0.2,
                ammo="lightning",
                capacity=200,
                pickup_ammo=100,
                damage=8,
                interval=0.05,
                reach=768.0,
                model="models/weapons2/lightning/lightning.md3"
            ),
            WeaponRule(
                slot=7,
                key="railgun",
                muzzle=Vec3(x=14.0),
                name="Railgun",
                raise_time=0.25,
                lower_time=0.2,
                ammo="slugs",
                capacity=200,
                pickup_ammo=10,
                damage=100,
                interval=1.5,
                piercing=True,
                model="models/weapons2/railgun/railgun.md3"
            ),
            WeaponRule(
                slot=8,
                key="plasmagun",
                muzzle=Vec3(x=14.0),
                name="Plasma gun",
                fuse=10.0,
                raise_time=0.25,
                lower_time=0.2,
                ammo="cells",
                capacity=200,
                pickup_ammo=50,
                damage=20,
                interval=0.1,
                speed=2000.0,
                splash=15,
                radius=20.0,
                model="models/weapons2/plasma/plasma.md3",
                effect="q3_plasma"
            ),
            WeaponRule(
                slot=9,
                key="bfg",
                muzzle=Vec3(x=14.0),
                name="BFG10K",
                fuse=10.0,
                raise_time=0.25,
                lower_time=0.2,
                ammo="bfg",
                capacity=200,
                pickup_ammo=20,
                damage=100,
                interval=0.2,
                speed=2000.0,
                splash=100,
                radius=120.0,
                model="models/weapons2/bfg/bfg.md3",
                effect="q3_bfg"
            )
        ];
    }
    return [];
}

def equip_player(player: Player, state: CombatState, game: str, fresh: bool = True, lead: str = "q1") {
    state.rules = weapon_rules(game);
    state.game = game;
    state.fallback = [8, 5, 3, 4, 2, 1]
        if game == "q1"
        else ([9, 8, 5, 4, 3, 2, 1] if game == "q2" else [9, 8, 7, 6, 5, 4, 3, 2, 1]);
    if game == "passion" {
        # Out of ammunition, the strongest held weapon first, by role.
        ranked = sorted([(-rule.role, rule.slot) for rule in state.rules]);
        state.fallback = [pair[1] for pair in ranked];
    }
    if not state.rules or not fresh {
        return;
    }
    if game == "passion" {
        kit = passion_start(lead);
        for kind in kit.weapons {
            player.inventory spawn AdjustInventory(kind=kind, amount=1, capacity=1);
        }
        if kit.ammo {
            player.inventory spawn AdjustInventory(kind=kit.ammo, amount=kit.rounds, capacity=PASSION_AMMO_CAPS[kit.ammo]);
        }
        state.weapon = kit.held;
        return;
    }
    for rule in state.rules {
        if rule.slot == 1 or (game in ["q1", "q3"] and rule.slot == 2) {
            player.inventory spawn AdjustInventory(
                kind="weapon_" + rule.key, amount=1, capacity=1
            );
        }
    }
    if game == "q1" {
        player.inventory spawn AdjustInventory(kind="shells", amount=25, capacity=100);
        state.weapon = 2;
    } elif game == "q3" {
        player.inventory spawn AdjustInventory(
            kind="bullets", amount=100, capacity=200
        );
        state.weapon = 2;
    } else {
        state.weapon = 1;
    }
}

"""A weapon's shot as heard: in a Passion level its own game's sound
(game:path), "" when it has none."""
def fire_sound(rule: WeaponRule) -> str {
    sounds = weapon_sounds(rule.game);
    index = rule.game_slot - 1;
    if index < 0 or index >= len(sounds) {
        return "";
    }
    return rule.game + ":" + sounds[index];
}

# Archive spelling is preserved: original Q2 PAK filenames are case-sensitive.
def weapon_sounds(game: str) -> list[str] {
    names: list[str] = [];
    if game == "q1" {
        names = [
            "ax1.wav",
            "guncock.wav",
            "shotgn2.wav",
            "rocket1i.wav",
            "spike2.wav",
            "grenade.wav",
            "sgun1.wav",
            "lstart.wav"
        ];
    } elif game == "q2" {
        names = [
            "BLASTF1A.WAV",
            "Shotgf1b.wav",
            "Sshotf1b.wav",
            "Machgf1b.wav",
            "Machgf2b.wav",
            "GRENLF1A.WAV",
            "ROCKLF1A.WAV",
            "Hyprbf1a.wav",
            "RAILGF1A.WAV",
            "Bfg__f1y.wav",
            "HGRENT1A.WAV"
        ];
    } elif game == "q3" {
        names = [
            "melee/fstatck.wav",
            "machinegun/machgf1b.wav",
            "shotgun/sshotf1b.wav",
            "grenade/grenlf1a.wav",
            "rocket/rocklf1a.wav",
            "lightning/lg_fire.wav",
            "railgun/railgf1a.wav",
            "plasma/hyprbf1a.wav",
            "bfg/bfg_fire.wav"
        ];
    }
    return ["sound/weapons/" + name for name in names];
}


"""Each missile effect's looping flight sound; in a Passion level from its
own game's archive (game:path)."""
def missile_sounds(game: str) -> dict[str, str] {
    sounds: dict[str, str] = {};
    for rule in weapon_effects(game) {
        if rule.sound {
            sounds[rule.key] = (effect_game(rule.key) + ":" + rule.sound) if game == "passion" else rule.sound;
        }
    }
    return sounds;
}

"""Missiles, explosions and the like: a game's own, or in a Passion level
every game's (their keys never meet)."""
def weapon_effects(game: str) -> list[EffectRule] {
    if game == "passion" {
        return game_effects("q1") + game_effects("q2") + game_effects("q3");
    }
    return game_effects(game);
}

def game_effects(game: str) -> list[EffectRule] {
    if game == "q1" {
        return [
            EffectRule(key="q1_nail", flight="progs/spike.mdl"),
            EffectRule(key="q1_laser", flight="progs/laser.mdl"),
            EffectRule(key="q1_knightspike", flight="progs/k_spike.mdl"),
            EffectRule(key="q1_lavaball", flight="progs/lavaball.mdl"),
            EffectRule(key="q1_wizspike", flight="progs/w_spike.mdl"),
            EffectRule(key="q1_vorepod", flight="progs/v_spike.mdl", spin=5.235987756),
            EffectRule(key="q1_zombiegib", flight="progs/zom_gib.mdl", spin=8.0),
            EffectRule(key="q1_supernail", flight="progs/s_spike.mdl"),
            EffectRule(key="q1_grenade", flight="progs/grenade.mdl", spin=5.235987756),
            EffectRule(key="q1_rocket", flight="progs/missile.mdl"),
            # BecomeExplosion: s_explode1-6 at 10 Hz.
            EffectRule(key="q1_explosion", flight="progs/s_explod.spr", explosion=True),
            # Beam segments: shambler bolt.mdl, the player's bolt2.mdl.
            EffectRule(key="q1_bolt", flight="progs/bolt.mdl"),
            EffectRule(key="q1_bolt2", flight="progs/bolt2.mdl"),
            # Chthon's electrodes (TE_LIGHTNING3).
            EffectRule(key="q1_bolt3", flight="progs/bolt3.mdl")
        ];
    }
    if game == "q2" {
        return [
            # g_weapon.c: fire_bfg, fire_blaster, fire_grenade2 and fire_rocket
            # give their missiles a looping s.sound.
            EffectRule(
                key="q2_bfg",
                flight="sprites/s_bfg1.sp2",
                burst="sprites/s_bfg3.sp2",
                sound="sound/weapons/bfg__l1a.wav"
            ),
            EffectRule(
                key="q2_bolt",
                flight="models/objects/laser/tris.md2",
                sound="sound/misc/lasfly.wav"
            ),
            # fire_blaster(hyper): the same bolt, EF_HYPERBLASTER.
            EffectRule(
                key="q2_hyperbolt",
                flight="models/objects/laser/tris.md2",
                sound="sound/misc/lasfly.wav"
            ),
            EffectRule(
                key="q2_grenade",
                flight="models/objects/grenade/tris.md2",
                spin=5.235987756
            ),
            EffectRule(
                key="q2_handgrenade",
                flight="models/objects/grenade2/tris.md2",
                spin=5.235987756,
                sound="sound/weapons/hgrenc1b.wav"
            ),
            EffectRule(
                key="q2_rocket",
                flight="models/objects/rocket/tris.md2",
                sound="sound/weapons/rockfly.wav"
            ),
            # CL_AddBeams: the parasite's drain and the medic's cable.
            EffectRule(key="q2_segment", flight="models/monsters/parasite/segment/tris.md2"),
            # cl_tent.c: rocket bursts start on frame 0 or 15, grenades on 30.
            EffectRule(
                key="q2_explosion",
                flight="models/objects/r_explode/tris.md2",
                explosion=True,
                skins=7,
                frames=[0, 15]
            ),
            EffectRule(
                key="q2_grenade_explosion",
                flight="models/objects/r_explode/tris.md2",
                explosion=True,
                skins=7,
                frames=[30]
            )
        ];
    }
    if game == "q3" {
        return [
            # cg_weapons.c CG_RegisterWeapon: each missile's missileSound.
            EffectRule(
                key="q3_rocket",
                flight="models/ammo/rocket/rocket.md3",
                sound="sound/weapons/rocket/rockfly.wav"
            ),
            EffectRule(
                key="q3_grenade", flight="models/ammo/grenade1.md3", spin=4.36332313
            ),
            EffectRule(
                key="q3_plasma",
                flight="sprites/plasma1",
                sprite_size=32,
                additive=True,
                rotate=931.0,
                sound="sound/weapons/plasma/lasfly.wav"
            ),
            EffectRule(
                key="q3_bfg",
                flight="models/weaphits/bfg.md3",
                spin=6.0,
                sound="sound/weapons/rocket/rockfly.wav"
            ),
            # cg_weapons.c CG_MissileHitWall's explosions, drawn with their
            # gfx.shader shaders: the bullet, plasma and rail hits over their
            # models, the rocket, grenade and BFG blasts as sprites, and
            # CG_Bleed's blood.
            EffectRule(
                key="q3_bullet_explosion",
                flight="models/weaphits/bullet.md3",
                shader="bulletExplosion",
                explosion=True
            ),
            EffectRule(
                key="q3_plasma_explosion",
                flight="models/weaphits/ring02.md3",
                shader="plasmaExplosion",
                explosion=True
            ),
            EffectRule(
                key="q3_rail_explosion",
                flight="models/weaphits/ring02.md3",
                shader="railExplosion",
                explosion=True
            ),
            EffectRule(key="q3_rocket_explosion", flight="", shader="rocketExplosion", sprite_size=30, grow=42.0, explosion=True),
            EffectRule(key="q3_grenade_explosion", flight="", shader="grenadeExplosion", sprite_size=30, grow=42.0, explosion=True),
            EffectRule(key="q3_bfg_explosion", flight="", shader="bfgExplosion", sprite_size=30, grow=42.0, explosion=True),
            EffectRule(key="q3_blood", flight="", shader="bloodExplosion", sprite_size=24, explosion=True),
            # cg_main.c CG_RegisterGraphics registers these by shader name;
            # Quake III's draw gfx/misc/railcorethin_mono, raildisc_mono2 and
            # lightning3new, OpenArena's its own images.
            EffectRule(key="q3_railcore", flight="railCore", additive=True),
            EffectRule(key="q3_raildisc", flight="railDisc", additive=True),
            # lightningBoltNew, the 1.32 beam shader.
            EffectRule(key="q3_lightning", flight="lightningBoltNew", additive=True),
            # CG_SmokePuff shaders: the rocket and grenade smoke, gib blood.
            EffectRule(key="smokePuff", flight="gfx/misc/smokepuff3"),
            EffectRule(key="bloodTrail", flight="gfx/damage/blood_spurt"),
            # cg_main.c CG_RegisterGraphics: the impact mark shaders.
            EffectRule(key="gfx/damage/bullet_mrk", flight="gfx/damage/bullet_mrk"),
            EffectRule(key="gfx/damage/burn_med_mrk", flight="gfx/damage/burn_med_mrk"),
            EffectRule(key="gfx/damage/hole_lg_mrk", flight="gfx/damage/hole_lg_mrk"),
            EffectRule(key="gfx/damage/plasma_mrk", flight="gfx/damage/plasma_mrk"),
            # cgs.media.balloonShader: the talk balloon (CG_PlayerSprites).
            EffectRule(key="sprites/balloon3", flight="sprites/balloon3"),
            # cgs.media.medalImpressive, medalExcellent and medalGauntlet,
            # floated over a player they were just awarded to.
            EffectRule(key="medal_impressive", flight="menu/medals/medal_impressive"),
            EffectRule(key="medal_excellent", flight="menu/medals/medal_excellent"),
            EffectRule(key="medal_gauntlet", flight="menu/medals/medal_gauntlet"),
            # cgs.media.shadowMarkShader (CG_PlayerShadow).
            EffectRule(key="markShadow", flight="gfx/damage/shadow"),
            # cgs.media.teleportEffectModel and teleportEffectShader (CG_SpawnEffect).
            EffectRule(
                key="q3_teleport",
                flight="models/misc/telep.md3",
                shader="teleportEffect",
                explosion=True,
                entity_fade=True
            )
        ];
    }
    return [];
}
