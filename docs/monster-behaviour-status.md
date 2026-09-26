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
- Q1 Nightmare removes the wait after an attack, and pain animations can replay
  no sooner than every 5 s. Q2 Easy halves the attack chances below, and Hard or
  above doubles them. On Nightmare, Q2 monsters cry out but skip pain animations.
- Saves record the skill; loading a save made at another skill is refused.

## Noticing the player

- Idle monsters never notice anything beyond 1000 units. From 500 to 1000 units
  they need to be facing the player. Closer than that, a fresh shot is enough.
  Within melee range, sight alone is enough (Q1 `FindTarget`, Q2 `FindTarget`).
- Q2 monsters also hear gunfire within 1000 units (`PlayerNoise`), but only from
  clusters in the map's potentially hearable set (PHS), so walls and floors
  stop it, and only across open area portals (`gi.AreasConnected`): the map's
  areas and area portals are parsed, a `func_areaportal` is open while a door
  that targets it is not shut (`door_use_areaportals`) and toggles with each
  other use (`Use_Areaportal`), so a closed door stops the sound. A relay-
  toggled portal's state is not saved (door-held portals follow their doors).
- Ambush monsters (spawnflag 1) wait for sight.
- A monster that spots the player wakes others that can see it (Q1
  `sight_entity`, Q2 `sight_client`).
- An invisible player is not newly noticed.

## Fighting on the move

Monsters no longer attack the moment they are able to. Each 10 Hz decision rolls
the originals' attack chance, and a monster that holds its fire keeps running at
its target, so fights are spent moving between attacks.

- Chances by range (Q1 `CheckAttack`, Q2 `M_CheckAttack`):

  | Game | Melee | Near (<500) | Mid (<1000) | Far |
  | --- | --- | --- | --- | --- |
  | Q1 | 0.9 | 0.4 (0.2 with a melee attack) | 0.1 (0.05) | never |
  | Q2 | 0.2 | 0.1 | 0.02 | never |

  Monsters with their own checks override these:
  - Q1: soldier 0.4/0.05, ogre 0.1/0.05, Scrag 0.6/0.2, shambler always within
    reach; the fiend and dog leap whenever in range.
  - Q2: a monster standing its ground rolls 0.4.
- Melee reach always attacks (Q2 Easy: one time in four).
- After a ranged attack a monster waits a random 0–2 s before the next
  (`SUB_AttackFinished`, `attack_finished`). Soldiers wait 1–2 s, ogres 1–3 s,
  shamblers 2–4 s, the Scrag and hell knight at least 2 s.
- A newly woken Q1 monster waits one second before first firing (`HuntTarget`).
- Ranged attacks wait for a clear shot. Another monster in the way holds fire.
- Fliers and the Scrag slide sideways about a third of the times they hold fire
  (`ai_run_slide`). Every monster that has closed to its stopping range circles
  its target instead of standing still, and turns back when blocked.
- The Q1 dog leaps between 100 and 150 units (`CheckDogJump`).
- `scripts/engagement_probe.jac` fights 25 monsters on e1m1, e1m2, e2m1, base1 and
  base2 for 10 s each against a standing player:

  | | Share of fight spent moving | Attacks per 10 s |
  | --- | --- | --- |
  | Before | 6% | 6.8 |
  | Now | 51% | 4.4 |

  Before, most monsters never moved at all.

## Waking and hunting

- Any hit from the player wakes a monster and turns it on the player, even
  over a monster it was fighting. This includes projectiles and splash, not just
  hitscan (Q1 `T_Damage`, Q2 `M_ReactToDamage`).
- A Q1 monster keeps its enemy until one of them dies. Out of sight it heads for
  the player's current position (`movetogoal`), so it follows the player through
  the level. Q2 monsters follow the player trail (below).
- Unalerted monsters mutter their idle sound every 15–30 s.
- Common monsters that were silent now have their sight, pain, death, idle and
  weapon sounds: Q1 soldier, dog, knight, enforcer, ogre and hell knight; Q2
  soldiers, infantry, berserker, gladiator, iron maiden and medic. Burst fire
  sounds on every shot.

## Medics, power screens and drops

- A Q2 medic takes the healthiest-born corpse it can see within 1024 units as its
  enemy (`medic_FindDeadMonster`). A `Mends` edge marks the claim. The medic runs
  to the corpse and plays its cable sequence. If the corpse is within 256 units
  and in sight at `attack50`, it stands up as a fresh monster hunting the medic's
  old enemy. Raised monsters keep no targets, so a second death fires nothing.
- The Q2 brain's power screen (`CheckPowerArmor`) absorbs a third of frontal
  damage from its 100 cells. It is off while the brain ducks.
- Q1 grunts, enforcers and ogres drop a backpack with 5 shells, 5 cells or 2
  rockets (`DropBackpack`). Q2 monsters drop their `item` key (`Drop_Item`).
  Drops are hidden `Pickup`s linked by `Drops` edges (marked `released` once shown) and revealed where the
  monster falls.
- The supertank, boss2 and Jorg blow apart into metal and meat once their death
  animation ends (`BossExplode`).
- Q2's insane marines are harmless (`AI_GOOD_GUY`): they never hunt the player,
  crawlers crawl, and the crucified can be killed.

## Bodies

- A Q2 monster below half health shows its bloodied skin (`skinnum |= 1`).
- Hit boxes use each monster's `SP_monster_*` box instead of the player's.
  For example, Q1 shambler/ogre/fiend/vore boxes rise to 64, the Q2 tank to 72,
  the supertank to 112 and Jorg to 140.
- Living monsters and bots are solid to the player (`SOLID_SLIDEBOX`): the player
  is pushed back out of them and stopped. A monster cannot step into the player.
  Corpses stay passable.
- Monsters move with their own box on their own game's maps
  (`monster_collision` in `engine/world/combat.jac`):
  - Q2/Q3 brush hulls are stored expanded by the player's box. A view made by
    `CollisionMap.for_body(height, drop, mins, maxs)` carries a `BodyBox`, and
    each brush plane moves by the difference between the two boxes at the
    corner facing it, as `CM_BoxTrace` does. The broad phase widens every
    stored bound by the same difference. No extra hulls are built.
  - Q1 maps load clip hull 2 next to hull 1; a monster wider than 32 units
    (shambler, ogre, fiend, vore, dog) traces it (`SV_HullForEntity`).
  - The monster's origin is its real origin. Q2 bosses whose mins z is 0
    (supertank, Jorg, Makron, Hornet, the chick, flipper) stand with their
    feet at it. Before, the player's box put the supertank, Jorg and several
    tanks inside the floor, so they never moved, and the chick floated 24
    units up.
  - The ogre, dog, gladiator, flipper and Q2 barrel boxes now match their
    `setsize`/`VectorSet` values.
  - Monsters on another game's maps (Passion) keep the player's box; their
    model is lowered so a Q2 model with mins z 0 stands on the floor.
  - Navigation caches connections per body box.

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
- Snapshot format **22** records corpse health and gibbing, patrol progress, the
  skill, power-screen cells, raised monsters and dropped items. Flying gibs are
  not saved.

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
  - `tests/monster_tactics_tests.jac`: attack chances, moving between attacks,
    waking on player hits, Q1 hunting, medic revival, dropped items.
  - `tests/infighting_tests.jac`: provocation rules, line of fire, missile owners,
    kill counting, return to the player.
  - `tests/gib_tests.jac`: thresholds, corpse damage, flight, landing and fading.
  - `tests/patrol_tests.jac`: corner loops, Q2 waits and pathtargets, combat
    points, saves.
  - `tests/combat_tests.jac`: awareness and skill.
  - `tests/trail_tests.jac`: crumb laying and following.
  - `tests/dodge_tests.jac`: duck timing and box, facing checks, soldier
    crouch-fire by skill.
  - `tests/monster_hull_tests.jac`: a supertank box standing at its feet,
    stopped by an 80-unit gap a player-sized box passes, and Q1 hull 2 for
    wide monsters.
- `scripts/monster_hull_smoke.jac` loads power1 (supertank), boss2 (Jorg),
  jail2 (tank) and e1m5 (shambler). Each starts clear of the floor and settles
  with its feet on it (within 0.04 units). The supertank, walked toward an
  opening a player-sized box crosses, stops after 31 units while a player box
  could go 574 further; Jorg stops with 215 to spare. Screenshots are saved in
  `.jac/screenshots/hulls/`.
- `scripts/monsters_smoke.jac` runs on `e1m1`, `e1m2`, `base1` and `q3dm1`. It
  gibs a monster and renders the flying pieces, walks every patroller along its
  corners, and stages a fight between two monster kinds.

## Limits

- Mover pushes, platform riding and door blocking still test monsters with the
  player's box.

- No shipped map in the smoke set uses `point_combat`; that behaviour is covered
  by tests only.
