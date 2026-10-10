# Weapons and items

Q1 (8 weapons), Q2 (11) and Q3 (9) use their original arsenals, described as
data in `games/weapons.jac` and run by one shared combat simulation in
`engine/world/combat.jac`. Items and pickups are in `games/items.jac` and
`engine/world/pickups.jac`; powerups in
[powerups-status.md](powerups-status.md); first-person models in
[viewweapons-status.md](viewweapons-status.md); impact effects, trails and
lights in [combat-feedback-status.md](combat-feedback-status.md).

Weapon parameters follow [Q1 weapons.qc](https://github.com/id-Software/Quake/blob/master/QW/progs/weapons.qc),
[Q2 p_weapon.c](https://github.com/id-Software/Quake-2/blob/master/game/p_weapon.c)
and [g_weapon.c](https://github.com/id-Software/Quake-2/blob/master/game/g_weapon.c),
and [Q3 g_weapon.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_weapon.c)
and [g_missile.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_missile.c).

## Selection

- Owned weapon inventory, original starting loadouts, weapon and ammo pickups
  and per-game ammo capacities.
- Bindings come from each game's own `default.cfg` plus a small layer
  (`games/controls.jac`): the number keys, the mouse wheel and
  `weapnext`/`weapprev`. Q2's `use BFG10K` and `use grenades` select slots 10
  and 11.
- A weapon change holds fire for the old weapon's lower time and the new one's
  raise time (`swap_weapon`). An empty weapon falls back through the game's own
  order to an owned, usable weapon; Q1 avoids the lightning gun underwater.

## Firing

- **Muzzles.** Every shot, traced or thrown, starts at its weapon's muzzle
  rather than the eye (`WeaponRule.muzzle`, `launch_point`). Q1 weapons.qc:
  rockets 8 ahead and 6 below the eye, grenades from the origin (22 below),
  nails 6 below and 4 to the right and left in turn, bullets 10 ahead at
  seven tenths of the player's height (`FireBullets`). Q2 p_weapon.c
  `P_ProjectSource`: 8 to the right and 8 below (the railgun and chaingun 7),
  the blasters 24 ahead and the launchers and BFG 8, the chaingun scattered
  up to 4 either way and the hyperblaster carried round a 4-unit circle. Q3
  g_weapon.c `CalcMuzzlePoint`: 14 ahead of the eye for every weapon, and a
  missile starts 50 ms into its flight (`MISSILE_PRESTEP_TIME`). A muzzle a
  wall cuts off from the eye fires from the eye.
- **Hitscan.** Pellet spread uses a saved random stream (Q2's machine-gun climb,
  Q3 `Bullet_Fire` spread). Damage from all pellets aggregates before armor and
  death callbacks. Rails pierce actors and stop at world geometry.
- **Projectiles.** Nails, bolts, rockets, grenades, plasma and BFG orbs are
  `Projectile` nodes on the world graph, swept against the world and actors,
  and saved. Grenades take gravity, bounce and fuse. Splash needs a clear line
  from the blast; self-damage and knockback follow each game. Monster missiles
  use the same graph.
- **Q1 lightning underwater** (`W_FireLightning`): every cell discharges at once
  as 35 damage per cell of radius damage, the shooter taking half.
- **Q2 BFG** (`fire_bfg`): 10 Hz piercing laser tendrils, a 200-point core hit
  and short-radius blast, then a delayed 500-point burst with square-root
  falloff that needs a line from both the orb and the shooter. Phase, timers and
  random state are saved; kill callbacks run once.
- **Q2 hand grenade** (`Weapon_Grenade`): priming, cooking, release, throw delay
  and fuse-dependent throw speed. The pin sound (`hgrena1b`) plays at gunframe
  5; the grenade ticks (`hgrenc1b`) from release until the throw and in flight.
  Switching cannot cancel a live grenade. A player who dies with the pin out
  lets it burst in the hand. Cook state survives saves and level changes.
- **World damage.** Shots and blasts damage Q2 destructible brushes and open Q1
  shootable secret doors. Deaths go through the shared kill-credit path.
- Firing sounds are decoded at level load, so the firing path reads no assets.

## Projectile rendering

Q1 nails, grenades and rockets, Q2 bolts, grenades and rockets, and Q3
grenades, rockets and plasma draw their original models, following projectile
pitch and yaw with grenade roll from simulation age. The Q2 BFG flies and
explodes as its animated SP2 sprites (PCX palette transparency, depth-tested
billboards); Q3 plasma is its additive rotating sprite and the Q3 BFG is
`models/weaphits/bfg.md3`, its ball an autosprite turned to the viewer
(see [models](models-status.md#q3-model-shaders)). Q3 rocket flares use their additive two-sided
surfaces, and model `animMap` stages keep their image sequence and frequency
([Q3 tr_shader.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/renderer/tr_shader.c)).

## Items

- Items settle as their game spawns them (Q1 `PlaceItem`/`droptofloor`, where
  an item starting partly in solid is carried out to the floor as `SV_Move`
  does; Q2 `droptofloor`; Q3 `FinishSpawningItem`) and ride movers. Q2 and
  Q3 put an item down with `MASK_SOLID`, so one standing in a clip brush is
  kept and comes down through it onto the floor (all 28 items of q3dm19 sit
  over thin player clip, as do one of q3dm11's, two of q3tourney2's and one
  each in Q2's city3 and ware1). A thrown Q3 item is stopped by player clip
  (`G_RunItem`: `MASK_PLAYERSOLID` less bodies); a thrown or falling Q2 item
  goes through clip (`SV_Physics_Toss`). A falling Q2 item and every item's
  place are saved.
- Touch uses each game's boxes: Q1 the item box widened 15 units (`FL_ITEM`)
  against the player (`SV_TouchLinks`), Q2 both boxes a unit bigger
  (`G_TouchTriggers`), Q3 `BG_PlayerTouchesItem`'s 44/50/36-unit reach.
- Q2 trigger-spawned items wait for their use; Q3 targeted items do not appear
  from their respawn timer before first activation. Q3 item categories have
  their own respawn delays, overridden by `wait` and spread by `random`. Q3
  `team` items show one member and respawn a random one (`G_FindTeams`,
  `RespawnItem`). A Q2 `team` starts with one member chosen at random and
  keeps to it, since nothing respawns in single player (`droptofloor`,
  `DoRespawn`; mine3 shows its megahealth or its body armour). Q2
  `ITEM_NO_TOUCH` items are shown, still and without the item glow, and
  cannot be picked up: the power cubes that appear in their sockets in bunk1
  and ware2.
- A dying Q3 player or bot drops its held weapon (not the gauntlet or machine
  gun) and its powerups; drops do not respawn and vanish after 30 s
  (`TossClientItems`, `engine/world/drops.jac`).

References: [Q2 g_items.c](https://github.com/id-Software/Quake-2/blob/master/game/g_items.c),
[Q3 g_items.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_items.c).

## Passion

Passion has no weapon table. `selected_weapon` builds two rules
(`engine/world/combat.jac`): slot 1 "Basic", an unlimited 15-damage hitscan
shot every 0.3 s, and slot 2 "Heavy", a 50-damage shot every 0.7 s that uses
shells. Only those two slots can be selected.

## Validation

- `tests/weapon_tests.jac`: loadouts, pickups, pellet aggregation and rail
  piercing, blaster sweeps, splash exclusion and occlusion, grenade bounce and
  saves, spread saves, BFG tendrils, core and burst.
- `tests/hand_grenade_tests.jac`: release, held detonation, pause and saves,
  empty-weapon fallback, pin and tick sounds, death with the pin out.
- `tests/pickup_tests.jac`, `tests/item_drop_tests.jac`: touch boxes, armor
  rules, trigger-spawned and targeted items, Q3 teams and `random`, death
  drops, a thrown item on player clip per game. `tests/mover_push_tests.jac`:
  items settling, and one put down through a clip brush. Native:
  `scripts/validate_item_clip.jac` counts the items each map in `QP_MAPS`
  keeps and those placed in a clip brush, and takes one of them.
- `tests/orientation_tests.jac`, `tests/model_material_tests.jac`: projectile
  transforms and animated model stages.
- Native: `scripts/weapon_smoke.jac` (every weapon's assets and firing path),
  `scripts/weapon_audio_smoke.jac` (decodes and plays every firing sound),
  `scripts/projectile_scene_smoke.jac` (every configured projectile effect),
  `scripts/combat_smoke.jac` (starting weapons in Q1 e1m1, Q2 base1 and Q3
  q3dm1, the Q2 BFG phases), `scripts/gameplay_smoke.jac` and
  `scripts/validate_gameplay.jac`.

## Limitations

- A Q2 item team's choice comes from a stream seeded by the map, so a map
  shows the same member each time; the original draws `rand()`.
- Q2 `ITEM_NO_TOUCH` items are not solid (`SOLID_BBOX` in the original).
