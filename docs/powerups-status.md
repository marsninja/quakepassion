# Powerups and holdables

All three games have their original powerups. Each active effect is a
`Powerup` node attached to its actor by an `Empowered` edge
(`engine/world/powerups.jac`). Walkers grant, advance and use these nodes;
damage, movement, weapons and AI query them instead of keeping separate flags.
Item tables are in `games/items.jac`.

## Behaviour

| Game | Items | Rules |
| --- | --- | --- |
| Q1 | Quad Damage, Pentagram, Ring of Shadows, Biosuit | Taken on pickup; 30 s, reset rather than stacked |
| Q2 | Quad, Invulnerability, Rebreather, Environment Suit, Silencer, Power Screen/Shield | Stored (two each on Normal); used from the inventory; use extends an active timer |
| Q3 | Quad, Battle Suit, Haste, Invisibility, Regeneration, Flight; Medkit and Personal Teleporter | Pickup adds to remaining time; one holdable at a time |

- Quad multiplies weapon damage when fired (x4 Q1/Q2, x3 Q3), including
  projectiles, splash and hand grenades. Haste speeds movement and shortens
  refire intervals by 1.3. Flight removes gravity.
- Invulnerability blocks all damage except telefrags and Q2/Q3 `NO_PROTECTION`
  hurt volumes. The Battle Suit ignores splash, liquids, drowning and falls and
  halves other damage.
- The Biosuit prevents drowning and slime damage and slows lava damage to once a
  second. The Q2 Environment Suit takes one point per depth from lava. The
  Rebreather only supplies air.
- Q2 power armor spends cells: the screen absorbs a third of frontal hits (one
  cell per point), the shield two thirds from every side (two points per cell).
- The Q2 Silencer plays the player's shots at 0.2 gain, and silenced shots do
  not alert monsters that hear gunfire.
- Invisible players are not newly noticed; monsters already hunting keep
  hunting (Q1 `FindTarget`). A Q3 bot loses an invisible enemy that is not
  shooting one time in five at each think.
- Megahealth decays one point a second after five seconds (Q1/Q2). Q3
  Regeneration adds 15 health a second up to 110% of maximum, then 5 up to
  double; otherwise Q3 health and armor above 100 decay one point a second.
- Adrenaline, Ancient Head, Bandolier, Ammo Pack and armor shards follow the Q2
  item table. The Q3 armor shard grants 5 armor.
- Q3 powerups first appear 30-60 s into a match and respawn after 120 s. Bots
  prefer powerups even during a fight, carry one holdable, teleport away below
  40 health and use the medkit below 60 (`ai_dmq3.c`). A dying Q3 player drops
  its powerups with their remaining time (see
  [weapons-status.md](weapons-status.md#items)).
- The Q3 Personal Teleporter follows `TeleportPlayer`: a random spawn from the
  furthest half of the deathmatch spawns nobody stands on, 10 units above it,
  facing its angle, pushed out at 400 units a second; `G_KillBox` telefrags
  anyone there.
- Q1 level transitions clamp carried health to 50-100 (`SetChangeParms`). Timed
  effects, like the originals, do not survive a map change. Active effects and
  rot clocks are saved.

## Presentation

Expiry cues and messages follow each game: Q1/Q2 warn three seconds before
expiry, Q3 in each of the last five. Q1/Q2 screen tints flash in the final
seconds. Pickups play their own original sounds. Items spin on the world clock
(Q1 `EF_ROTATE` models, Q2 item-table flags, all Q3 items), Q3 items bob, and
Q3 powerups, health and shards draw their ring or sphere model. Q3 bodies and
weapons are drawn with their powerup shells (quad, battle suit, invisibility).
Status-bar icons are covered in [presentation-status.md](presentation-status.md).

## Validation

- `tests/powerup_tests.jac`: Q1 artifacts, expiry warnings, invulnerability,
  battle suit, Q2 power screen and shield, Q2 storage and use, Q2 item tables,
  megahealth rot and Q3 regeneration, Q3 holdables, suits, quad and haste,
  flight, invisibility, snapshots, respawn rules, spin and bob, pickup sounds.
- `tests/item_drop_tests.jac`: powerup shaders on bodies and weapons, drops on
  death.
- Native: `scripts/powerups_smoke.jac` spawns, renders, collects and applies
  original-map powerups.

References: [Q1 items.qc](https://github.com/id-Software/Quake/blob/master/QW/progs/items.qc),
[Q2 g_items.c](https://github.com/id-Software/Quake-2/blob/master/game/g_items.c),
[Q3 g_items.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_items.c).
