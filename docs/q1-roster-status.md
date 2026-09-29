# Quake 1 monster roster

Every monster class in the original Q1 campaign spawns and fights: the sixteen
`monster_*` classes of v101qc, plus `misc_explobox`/`misc_explobox2` barrels.
Each is an `OpponentRule` in `games/enemies.jac` (`enemy_rule("q1", kind)`)
built into an `Opponent` node by `games/opponents.jac` and driven by the shared
`CombatTick` walker in `engine/world/combat.jac`. The two bosses have their own
walkers, selected by `OpponentRule.script`.

Shared behaviour (noticing, attack chances, infighting, gibs, drops, patrols) is
in [monster-behaviour-status.md](monster-behaviour-status.md); movement, bodies
and movers are in [navigation-status.md](navigation-status.md).

## Roster

| Class | Health | Attacks (QuakeC source) |
| --- | ---: | --- |
| `monster_army` | 30 | four-pellet shot at 0.4 s (`army_fire`) |
| `monster_dog` | 25 | bite (random scale 8); leap from 100-150 units (`CheckDogJump`) |
| `monster_knight` | 75 | close swing within 80; running slash from 80-120, heading 30 units left (`ai_charge_side`) |
| `monster_hell_knight` | 250 | `magicc` volley of six 9-damage spikes, -12 to +18 degrees; slice/smash/wide swing in turn; charge |
| `monster_enforcer` | 80 | two 15-damage laser bolts at 0.5 and 0.9 s |
| `monster_ogre`, `monster_ogre_marksman` | 200 | grenade (40 splash); chainsaw sweep or smash |
| `monster_wizard` (Scrag) | 80 | flies; two spikes at 0.3 and 0.8 s; side slides |
| `monster_demon1` (Fiend) | 300 | claws; 40-50 damage leap |
| `monster_shambler` | 600 | smash and two swings (chosen by weight); lightning beam; takes half blast damage |
| `monster_zombie` | 60 | three flesh-throw sequences; see below |
| `monster_shalrath` (Vore) | 400 | homing pod (40 splash) |
| `monster_tarbaby` (Spawn) | 80 | hopping 10-20 damage leap; bursts for 120 when killed |
| `monster_fish` | 25 | swims only when submerged; three-bite pass |
| `monster_boss` (Chthon) | 3 (1 on Easy) | scripted, see below |
| `monster_oldone` (Shub-Niggurath) | 40000 | scripted, see below |

Attack profiles (`AttackProfile` in `engine/world/opponent_rule.jac`) carry the
10 Hz frame lists, event times, per-frame charge steps, muzzles and sounds from
each monster's `.qc` file. Melee damage uses QuakeC's three-sample random
formulas (`random_scale`), rounded down to integer health.

Details that follow the QuakeC:

- **Hell Knight** (`hknight.qc`): in melee range (`RANGE_MELEE`, 120) it takes
  the slice, smash and wide swing in turn on one count shared by every Hell
  Knight, as the global `hknight_type` is (saved). Each strike lands with
  `ai_melee` within 60. From the first frame of its run cycle it charges
  (`CheckForCharge`: target visible, attacks due, at least 80 away, within 20
  in height), running `char_a1-16` with `SUB_AttackFinished(2)`. `char_b` has no
  caller in the QuakeC and is not used. Charges refuse steps into the target's
  box, as `SV_movestep` does.
- **Zombie** (`zombie.qc`): pain resets health to 60 and ignores hits under 9;
  a hit of 25 or more knocks it down for up to 8 s, after which it rises. Only a
  single hit of 60 or more kills it, and it always gibs. Spawnflag 1 (crucified)
  is a harmless decoration.
- **Chthon** (`boss.qc`, `engine/world/chthon.jac`, `ChthonTick`): dormant until
  its map signal, then plays boss.qc frame by frame at 10 Hz. `boss_rise` plays
  `out1` and `sight1`. `boss_missile` turns 20 degrees a frame toward the player
  (`yaw_speed` 20) and throws a lava ball on attack9 and attack20 from the
  `makevectors` offsets, leading the player above Normal skill. `boss_idle` runs
  while the player is dead. Weapon damage is refused. An `event_lightning` node
  links to the two electrode doors through `Electrode` edges. `lightning_use`
  plays `misc/power.wav`, ignores uses while a bolt has just begun, and needs
  both electrodes at rest at the same end. `lightning_fire` draws a
  `q1_lightning3` beam every 0.1 s. A strike with the electrodes lowered costs
  one health and plays a shock family with `pain.wav`. Death plays `death.wav`,
  `out1` and an `R_LavaSplash`, then fires the boss's targets once and counts
  the kill. A `target` naming no entity (e1m7's `lightning` marker) is a no-op.
- **Shub-Niggurath** (`oldone.qc`, `engine/world/finale.jac`, `FinaleTick`):
  idles through `old1-46` and refuses weapon damage. The spiked teleport train
  (`TeleportTrain`, `TeleportTrainTick`) runs its corner loop. A telefrag inside
  the boss (`telefrag`) switches to the intermission camera, holds 3 s, then
  plays `shake1-20` with its death sound for 6 s. The boss then vanishes, the
  kill counts and the closing text shows.

Boss phase, timers, lightning interval and the teleport train's position are
saved.

## Validation

- `tests/q1_roster_tests.jac`: Scrag flight and spikes, fiend leap and claws,
  shambler beam and melee, zombie pain/knockdown and throws, vore homing, spawn
  hops and burst, rotfish swimming, sound cues, mid-leap save.
- `tests/hell_knight_tests.jac`: volley directions and saves, melee rotation,
  charge conditions, knight swing and run attack.
- `tests/attack_timing_tests.jac`, `tests/ogre_attack_tests.jac`: soldier, dog,
  knight, enforcer and ogre timelines.
- `tests/chthon_tests.jac`: activation, weapon immunity, sounds and skill health,
  yaw speed and leading, electrode alignment, idle over a dead player, saves.
- `tests/finale_tests.jac`: teleport train, telefrag finale, closing texts.
- Native: `scripts/roster_smoke.jac` checks every Q1/Q2 class's frames, sounds
  and missiles against the archives; `scripts/attack_timing_smoke.jac`,
  `scripts/chthon_smoke.jac` (e1m7 electrodes, death output, saves after every
  strike), `scripts/finale_smoke.jac` (end map), and the render captures
  `scripts/chthon_render_smoke.jac`, `scripts/hell_knight_render_smoke.jac`,
  `scripts/ogre_render_smoke.jac`.

## Limitations

- Each monster plays one death sequence: the authored `death_frames` or the
  model's first contiguous `death` family (`games/opponents.jac`). The
  originals' random choices (for example `army_die` / `army_cdie`) are not made.
- Q1 monsters other than the zombie play one pain family. The originals' random
  pain choices (for example `army_pain`'s three sequences) are not made.
- Shub-Niggurath's finale is a fixed hold-and-shake timeline. It is not a
  frame-by-frame reproduction of `finale_1`-`finale_4`.

References: [v101qc](https://github.com/id-Software/Quake-Tools/tree/master/qcc/v101qc)
(`soldier.qc`, `dog.qc`, `knight.qc`, `hknight.qc`, `enforcer.qc`, `ogre.qc`,
`wizard.qc`, `demon.qc`, `shambler.qc`, `zombie.qc`, `shalrath.qc`,
`tarbaby.qc`, `fish.qc`, `boss.qc`, `oldone.qc`).
