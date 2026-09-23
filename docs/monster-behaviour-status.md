# Monster behaviour

Campaign monsters now follow the originals' rules for noticing the player,
difficulty, idle patrols, fighting each other and dying messily. All of this runs
on the world graph. Monsters link to their path corners, combat points and gib
models through edges. Walkers drive patrols, gib flight and combat.

## Skill

- The menu's **Skill (next level)** row selects Easy, Normal, Hard or Nightmare.
  The choice is saved in the preferences and applies from the next level load.
  `trigger_setskill` changes it too, as Q1's start map does.
- Spawn filtering drops entities flagged "not in easy/normal/hard" (spawnflags
  256/512/1024) for the current skill.
- Q1 Nightmare removes the pause between attacks, and pain animations can replay
  no sooner than every 5 s. Q2 Easy doubles the pause between attacks, and Hard
  or above halves it.
- Saves record the skill; loading a save made at another skill is refused.

## Noticing the player

- Idle monsters never notice anything beyond 1000 units. From 500 to 1000 units
  they need to be facing the player. Closer than that, a fresh shot is enough.
  Within melee range, sight alone is enough (Q1 `FindTarget`, Q2 `FindTarget`).
- Q2 monsters also hear gunfire within 1000 units (`PlayerNoise`).
- Ambush monsters (spawnflag 1) wait for sight.
- A monster that spots the player wakes others that can see it (Q1
  `sight_entity`, Q2 `sight_client`).
- An invisible player is not newly noticed.

## Patrols and combat points

- A monster whose `target` names a `path_corner` walks the corner chain while
  idle. It uses the original walk cycle (Q1 `walk`/`prowl_`, Q2 `walk1`) at
  walk-cycle speed, summed from each monster's `ai_walk` distances.
- Corners are reached by the original box touch.
- Q2 corners fire their `pathtarget` and pause for their `wait`.
- A Q2 monster with a `combattarget` runs its `point_combat` chain once alerted,
  holding fire until it arrives (`AI_COMBAT_POINT`).
- Walking uses fixed-stride stepping, like the originals' `movestep`, so slow
  walks are not swallowed by player friction.
- Path corners and combat points share the `TrackPoint` graph with trains.
  `Patrols` and `Holds` edges are rewired at each corner, and saves record them.

## Infighting

- Monster hitscan, beams, missiles and splash damage now hit whatever is in the
  way, including other monsters. Only the shooter itself is ever skipped.
- A monster hurt by another monster turns on it by the original rules:
  - Q1 `T_Damage`: any other class, and soldiers even at their own kind.
  - Q2 `M_ReactToDamage`: another class with the same walk, fly or swim
    movement. Tanks, the Supertank, Makron and Jorg never provoke it.
  - Q2 monsters also shoot back at an attacker aiming at them, and otherwise
    join the attacker's own fight.
- When the rival dies, a monster that was already hunting the player goes back
  to it. Otherwise it returns to idle, like Q1/Q2 `oldenemy`.
- Every monster death counts toward the kill total, whoever caused it (Q1/Q2
  `Killed`).

## Gibs

- A monster killed far enough past zero health bursts into its head and gibs.
  Thresholds come from each original die function (for example Q1 soldiers
  below -35, ogres below -80; Q2 soldiers at -30, tanks at -200; Q3 at
  `GIB_HEALTH` -40). Q1 zombies always gib.
- The gibs are the original models, and the original gib sound plays:
  - Q1: `h_*` heads and `gib1`–`gib3`, with `player/udeath.wav`
    (`zombie/z_gib.wav` for zombies).
  - Q2: `head2`, bone, meat, chest and metal pieces, with `misc/udeath.wav`.
  - Q3: the player gib set, with `gibsplt1.wav`.
- Gibs are `Gib` entities with the original physics:
  - Q1 `VelocityForDamage` and bounce clipping.
  - Q2 toss, `ClipGibVelocity` and the victim's momentum.
  - Q3 0.6 reflection.
  - Q1/Q2 gibs tumble in all three axes; visuals now carry pitch and roll.
- Q1 heads stay where they land. Other pieces fade after 10–20 s (Q3: 5–8 s).
- Q2 and Q3 corpses remain shootable with a lowered box and keep taking damage
  until they gib. Q1 monster corpses take no damage, as in the original.
- Snapshot format **21** records corpse health and gibbing, patrol progress and
  the skill. Flying gibs are not saved.

## Trail hunting

Q2's player trail (`p_trail.c`) is a graph of up to eight `TrailMark` crumbs
hanging off a `PlayerTrail` node (`engine/world/trail.jac`). The player drops a
crumb every half second once they are 32 units from the last one. A Q2 monster
that reaches the spot where it lost the player follows the crumbs laid since
then, oldest first, instead of giving up.

## Dodging

Q2 `check_dodge` (`g_weapon.c`) runs on each player blaster, hyperblaster and
rocket shot.

- It warns the first monster along the shot's line, but only if that monster
  faces the shooter. On easy the warning comes only a quarter of the time.
- A warned soldier, infantry, gunner, iron maiden, medic or brain ducks a
  quarter of the time, interrupting whatever it was doing, and takes the
  shooter as its enemy.
- The duck plays the model's `duck` frames and holds its hold frame until a
  second after the duck-down frame, as `monster_duck_down` sets `pausetime`.
- Between the duck-down and duck-up frames the monster's box top is 32 units
  lower, so eye-level shots pass over it. It neither moves nor attacks while
  ducking, and pain cuts the duck short.
- On medium a soldier answers a third of its dodges by crouching and firing
  (`attack3`), and on hard two thirds. It fires at `attak303`, loops back once
  while the second-long duck lasts, and stays crouched from the first shot to
  `attak307`.
- On hard a gunner lobs a grenade half the time as it ducks
  (`gunner_duck_down`).

## Validation

- Tests:
  - `tests/infighting_tests.jac`: provocation rules, line of fire, missile owners,
    kill counting, return to the player.
  - `tests/gib_tests.jac`: thresholds, corpse damage, flight, landing and fading.
  - `tests/patrol_tests.jac`: corner loops, Q2 waits and pathtargets, combat
    points, saves.
  - `tests/combat_tests.jac`: awareness and skill.
  - `tests/trail_tests.jac`: crumb laying and following.
  - `tests/dodge_tests.jac`: duck timing and box, facing checks, soldier
    crouch-fire by skill.
- `scripts/monsters_smoke.jac` runs on `e1m1`, `e1m2`, `base1` and `q3dm1`. It
  gibs a monster and renders the flying pieces, walks every patroller along its
  corners, and stages a fight between two monster kinds.

## Limits

- No shipped map in the smoke set uses `point_combat`; that behaviour is covered
  by tests only.
- Q2 `turret_breach`/`turret_driver` are not implemented yet.
