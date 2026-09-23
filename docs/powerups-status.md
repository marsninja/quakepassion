# Powerups, holdables and item presentation

All three games now have their original powerups. Each active effect is a
`Powerup` node attached to its actor by an `Empowered` edge. Walkers grant,
advance and use these nodes. Damage, movement, weapons and AI query them
instead of keeping separate flags.

## Behavior

| Game | Items | Rules |
| --- | --- | --- |
| Q1 | Quad Damage, Pentagram, Ring of Shadows, Biosuit | Taken on pickup; 30 s, reset rather than stacked |
| Q2 | Quad, Invulnerability, Rebreather, Environment Suit, Silencer, Power Screen/Shield | Stored (two each on Normal skill); **Enter** uses the selected item, **[ ]** select |
| Q3 | Quad, Battle Suit, Haste, Invisibility, Regeneration, Flight; Medkit and Personal Teleporter | Pickup adds to remaining time; one holdable at a time, used with **Enter** |

- Quad multiplies weapon damage when fired (×4 Q1/Q2, ×3 Q3), including
  projectiles, splash and hand grenades. Haste speeds movement and shortens
  refire intervals by 1.3.
- Invulnerability blocks all damage except telefrags and Q2/Q3 `NO_PROTECTION`
  hurt volumes. The Battle Suit ignores splash, liquids, drowning and falls and
  halves other damage.
- The Biosuit prevents drowning and slime damage and slows lava damage to once a
  second. The Q2 suit takes one point per depth from lava. The Rebreather only
  supplies air.
- Q2 power armor spends cells: the screen absorbs a third of frontal hits
  (one cell per point), the shield two thirds from every side (two points per cell).
- Invisible players are not newly noticed. Monsters already hunting keep
  hunting (Q1 `FindTarget`); Q3 bots still spot a player who is firing.
- Megahealth decays one point a second after five seconds (Q1/Q2). Q3
  Regeneration adds 15 health a second up to 110% of maximum, then 5 up to double.
  Otherwise Q3 health and armor above 100 decay one point a second.
- Adrenaline, Ancient Head, Bandolier, Ammo Pack and armor shards follow the Q2
  item table. The Q3 armor shard grants 5 armor.
- Q3 powerups first appear 30–60 s into a match and respawn after 120 s. Bots
  prefer powerups even during a fight, carry one holdable, teleport away below
  40 health and use the medkit below 60 (`ai_dmq3.c`).
- Q1 level transitions clamp carried health to 50–100 (`SetChangeParms`).
  Timed effects, like the originals, do not survive a map change.

Expiry cues and messages follow each game: Q1/Q2 warn three seconds before
expiry, Q3 in each of the last five. Q1/Q2 screen tints flash during the final
seconds. Pickups now play their own original sound. Items spin on the world
clock (Q1 `EF_ROTATE` models, Q2 item-table flags, all Q3 items), Q3 items bob,
and Q3 powerups, health and shards draw their ring or sphere model.

Snapshot format **18** stores active effects, rot clocks and silencer shots. New
pickup entities change the positional records, so older saves are rejected.

## Fixes found on the way

- The Q2 Megahealth referenced a missing `healing/mega` model; it now uses
  `models/items/mega_h/tris.md2`.
- Native Jac returned corrupted values from dictionaries with tuple values (the
  powerup tables). Fixed upstream in
  [jac #9445](https://github.com/jaseci-labs/jac/pull/9445); see
  [native compiler dependencies](native-lighting-validation-blockers.md).

## Limits

The status bar is still the shared text HUD. Original status bar art and icons
belong to the presentation milestone. The silencer quiets the player's own shots,
but monsters do not yet hear gunfire, so it has no AI effect. The Q3 personal
teleporter picks a random deathmatch spawn other than the nearest; it does not
yet telefrag occupants.
