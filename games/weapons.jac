"""Original base-game arsenals expressed as shared weapon rules.

Animation timing, charged hand grenades and the Q2 BFG secondary laser phase
remain separate fidelity work; ballistic effects use the common simulation.
"""
import from engine.formats.sprite { EffectRule }
import from engine.world.weapons { WeaponRule }
import from engine.world.world { Player }
import from engine.world.combat { CombatState }
import from engine.world.inventory { AdjustInventory }

def weapon_rules(game: str) -> list[WeaponRule] {
    if game == "q1" {
        return [
            WeaponRule(
                slot=1, key="axe", name="Axe", damage=20, interval=0.5, reach=64.0
            ),
            WeaponRule(
                slot=2,
                key="shotgun",
                name="Shotgun",
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
                name="Super shotgun",
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
                name="Nailgun",
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
                name="Super nailgun",
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
                name="Grenade launcher",
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
                name="Rocket launcher",
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
                name="Thunderbolt",
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
                name="Blaster",
                damage=10,
                interval=0.5,
                speed=1000.0,
                effect="q2_bolt"
            ),
            WeaponRule(
                slot=2,
                key="shotgun",
                name="Shotgun",
                ammo="shells",
                capacity=100,
                pickup_ammo=10,
                damage=4,
                interval=1.0,
                pellets=12,
                spread=0.0625,
                vertical_spread=0.0625,
                model="models/weapons/g_shotg/tris.md2"
            ),
            WeaponRule(
                slot=3,
                key="supershotgun",
                name="Super shotgun",
                ammo="shells",
                capacity=100,
                pickup_ammo=10,
                cost=2,
                damage=6,
                interval=1.0,
                pellets=20,
                spread=0.125,
                vertical_spread=0.0625,
                model="models/weapons/g_shotg2/tris.md2"
            ),
            WeaponRule(
                slot=4,
                key="machinegun",
                name="Machinegun",
                ammo="bullets",
                capacity=200,
                pickup_ammo=50,
                damage=8,
                interval=0.1,
                spread=0.037,
                vertical_spread=0.061,
                model="models/weapons/g_machn/tris.md2"
            ),
            WeaponRule(
                slot=5,
                key="chaingun",
                name="Chaingun",
                ammo="bullets",
                capacity=200,
                pickup_ammo=50,
                damage=8,
                interval=0.05,
                spread=0.037,
                vertical_spread=0.061,
                model="models/weapons/g_chain/tris.md2"
            ),
            WeaponRule(
                slot=6,
                key="grenadelauncher",
                name="Grenade launcher",
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
                name="Rocket launcher",
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
                name="Hyperblaster",
                ammo="cells",
                capacity=200,
                pickup_ammo=50,
                damage=20,
                interval=0.1,
                speed=1000.0,
                model="models/weapons/g_hyperb/tris.md2",
                effect="q2_bolt"
            ),
            WeaponRule(
                slot=9,
                key="railgun",
                name="Railgun",
                ammo="slugs",
                capacity=50,
                pickup_ammo=10,
                damage=150,
                interval=1.5,
                piercing=True,
                model="models/weapons/g_rail/tris.md2"
            ),
            WeaponRule(
                slot=10,
                key="bfg",
                name="BFG10K",
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
                name="Gauntlet",
                damage=50,
                interval=0.4,
                reach=32.0
            ),
            WeaponRule(
                slot=2,
                key="machinegun",
                name="Machinegun",
                ammo="bullets",
                capacity=200,
                pickup_ammo=40,
                damage=7,
                interval=0.1,
                spread=0.0073,
                vertical_spread=0.0073,
                model="models/weapons2/machinegun/machinegun.md3"
            ),
            WeaponRule(
                slot=3,
                key="shotgun",
                name="Shotgun",
                ammo="shells",
                capacity=200,
                pickup_ammo=10,
                damage=10,
                interval=1.0,
                pellets=11,
                spread=0.043,
                vertical_spread=0.043,
                model="models/weapons2/shotgun/shotgun.md3"
            ),
            WeaponRule(
                slot=4,
                key="grenadelauncher",
                name="Grenade launcher",
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
                name="Rocket launcher",
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
                name="Lightning gun",
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
                name="Railgun",
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
                name="Plasma gun",
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
                name="BFG10K",
                ammo="bfg",
                capacity=200,
                pickup_ammo=20,
                damage=100,
                interval=0.2,
                speed=2000.0,
                splash=100,
                radius=120.0,
                model="models/weapons2/bfg/bfg.md3"
            )
        ];
    }
    return [];
}

def equip_player(player: Player, state: CombatState, game: str, fresh: bool = True) {
    state.rules = weapon_rules(game);
    state.game = game;
    state.fallback = [8, 5, 3, 4, 2, 1]
        if game == "q1"
        else ([9, 8, 5, 4, 3, 2, 1] if game == "q2" else [9, 8, 7, 6, 5, 4, 3, 2, 1]);
    if not state.rules or not fresh {
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


def weapon_effects(game: str) -> list[EffectRule] {
    if game == "q1" {
        return [
            EffectRule(key="q1_nail", flight="progs/spike.mdl"),
            EffectRule(key="q1_laser", flight="progs/laser.mdl"),
            EffectRule(key="q1_lavaball", flight="progs/lavaball.mdl"),
            EffectRule(key="q1_supernail", flight="progs/s_spike.mdl"),
            EffectRule(key="q1_grenade", flight="progs/grenade.mdl", spin=5.235987756),
            EffectRule(key="q1_rocket", flight="progs/missile.mdl")
        ];
    }
    if game == "q2" {
        return [
            EffectRule(
                key="q2_bfg", flight="sprites/s_bfg1.sp2", burst="sprites/s_bfg3.sp2"
            ),
            EffectRule(key="q2_bolt", flight="models/objects/laser/tris.md2"),
            EffectRule(
                key="q2_grenade",
                flight="models/objects/grenade/tris.md2",
                spin=5.235987756
            ),
            EffectRule(
                key="q2_handgrenade",
                flight="models/objects/grenade2/tris.md2",
                spin=5.235987756
            ),
            EffectRule(key="q2_rocket", flight="models/objects/rocket/tris.md2")
        ];
    }
    if game == "q3" {
        return [
            EffectRule(key="q3_rocket", flight="models/ammo/rocket/rocket.md3"),
            EffectRule(
                key="q3_grenade", flight="models/ammo/grenade1.md3", spin=4.36332313
            ),
            EffectRule(
                key="q3_plasma",
                flight="sprites/plasma1",
                sprite_size=32,
                additive=True,
                rotate=931.0
            )
        ];
    }
    return [];
}
