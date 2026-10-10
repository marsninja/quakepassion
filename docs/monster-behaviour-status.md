# Monster behaviour

Campaign monsters follow the originals' rules for noticing the player,
difficulty, idle patrols, fighting each other and dying messily. All of this runs
on the world graph. Monsters link to their path corners, combat points and gib
models through edges. Walkers drive patrols, gib flight and combat. The
per-game rosters are in [q1-roster-status.md](q1-roster-status.md) and
[q2-roster-status.md](q2-roster-status.md).

## Skill

- The menu's **Skill (next level)** row cycles five settings: Easy, Normal,
  Hard, Nightmare, and Q3's fifth, Nightmare!, which Q1 and Q2 play as
  Nightmare (choosing it on a Q3 map plays `sound/misc/nightmare.wav`, as
  `ui_spskill.c` does). The row also shows the Q3 name of each setting. The
  choice is saved in the preferences and applies from the next level load.
  `trigger_setskill` changes it too, as Q1's start map does.
- Spawn filtering drops entities flagged "not in easy/normal/hard" (spawnflags
  256/512/1024) for the current skill.
- Q1 Nightmare removes every wait to attack, as `SUB_AttackFinished` sets none
  on skill 3: the wait after an attack, the second a newly woken monster
  waits before firing (`HuntTarget`) and the Hell Knight charge's 2 s. Q2 Easy
  halves the attack chances below, and Hard or above doubles them.
- On Nightmare every hit puts a monster's next pain 5 s off (Q1 and Q2
  `T_Damage`), and Q2 monsters skip their pain frames; which of them still cry
  out is in [q2-roster-status.md](q2-roster-status.md).
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
  other use (`Use_Areaportal`), so a closed door stops the sound.
- Ambush monsters (spawnflag 1) wait for sight.
- A monster that spots the player wakes others that can see it (Q1
  `sight_entity`, Q2 `sight_client`).
- An invisible player is not newly noticed.

## Fighting on the move

Each 10 Hz decision rolls the originals' attack chance, and a monster that
holds its fire keeps running at its target, so fights are spent moving between
attacks. How it runs is in [navigation-status.md](navigation-status.md).

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
  shamblers 2–4 s and the Scrag exactly 2 s. A Hell Knight's charge holds off
  its next attack until 2 s after the charge began (`SUB_AttackFinished(2)`);
  its spike volley takes the ordinary 0–2 s wait.
- A newly woken Q1 monster waits one second before first firing (`HuntTarget`).
- Ranged attacks wait for a clear shot. Another monster in the way holds fire.
- A Q2 flier that holds its fire slides sideways three checks in ten
  (`M_CheckAttack`), and the Q1 Scrag whenever its shot is clear and its
  enemy nearer than 500 units (`WizardCheckAttack`); both strafe by
  `ai_run_slide` and change sides when blocked. Every other monster runs
  straight at its enemy and stops only where its next step would reach the
  enemy's box (`SV_CloseEnough`), running in place there.
- The Q1 dog leaps between 100 and 150 units (`CheckDogJump`).
- `scripts/engagement_probe.jac` fights 25 monsters on e1m1, e1m2, e2m1, base1 and
  base2 for 10 s each against a standing player and reports how much of the
  fight they spend moving and how often they attack. On 2026-10-09 they ran
  the 300-400 units to the player in two to three seconds, stood against
  its box for the rest of the fight (a quarter of the time moving) and
  attacked 4.8 times per 10 s.

## Turning and walking

- A walking or running monster is turned by its steps: each frame it turns
  by its own `yaw_speed` toward the heading it is stepping along
  (`SV_StepDirection`'s `ChangeYaw`), so it runs on the eight compass
  headings as the originals' monsters do. Holding an attack, attacking or in
  pain it turns toward its target instead (Q1 `ChangeYaw`, Q2 `M_ChangeYaw`,
  through the shared `change_yaw`). The speed is data on each rule: 20
  degrees a frame for walking monsters (`walkmonster_start`), 10 for fliers
  and swimmers (`flymonster_start`, `swimmonster_start`) and 20 for Chthon
  (`boss_awake`). Each frame's turn is spread over its ticks, as its step is.
- A monster whose check chooses an attack state holds the attack it picked
  and turns in place on its run frames until it faces its enemy within 45
  degrees, then launches it (`ai_run_missile`, `ai_run_melee`,
  `FacingIdeal`). That is every Q2 monster (`M_CheckAttack` and the bosses'
  own checks) and Q1's ogre, shambler, fiend, dog and Scrag. Q1's plain
  `CheckAttack` and `SoldierCheckAttack` launch at once, and their attack
  frames turn them as they go (`ai_face`); the marksman ogre keeps its own
  classname and takes the plain check. A held attack outlives a change of
  enemy and waits out pain.
- Q2 soldiers set off walking on `walk1` or `walk2`, half the time each
  (`soldier_walk`). `walk1` goes back from walk110 to walk101 nine times in
  ten; otherwise the soldier stands through walk111-133
  (`soldier_walk1_random`). A `Gait` can branch this way, and a rule can list
  other walks to choose among.

## Pain and death sequences

Each rule lists the sequences its pain and die functions choose among as
`Reaction` objects (`pains` and `deaths` in `engine/world/opponent_rule.jac`):
model frames at 10 Hz, the distance each frame strides, the sequence's own
sound, and how it is picked. The tables for each monster are in the roster
docs.

- `choose_reaction` draws a sequence by weight among those whose damage
  bracket (`min_damage`, `max_damage`) holds the hit; `chance` is how often
  the one drawn then plays at all. An `airborne` pain is taken instead while
  the monster is thrown upward faster than 100 units a second, and a
  `head_shot` death for a hit within 4 units of the eye.
- `feel_pain` is the pain function. In order it applies the rule's damage
  threshold and knockdown, the wait since the last pain (`pain_interval`, or
  the drawn sequence's own `interval`; zero for monsters that never check
  it), a shrug-off chance for light hits (`pain_shrug_damage`,
  `pain_shrug_chance`), immunity while firing named attacks on Hard and above
  (`pain_immune`) and the Q1 flinch roll (`pain_chance_scale`, skipped once
  `pain_sure_after` seconds have gone since pain was last due), then draws
  the sequence. A sequence's own sound plays with its frames; otherwise the
  rule's pain sound is cried. `pain_cry` makes the rule's sound play on every
  hit, or whenever pain is due, without a flinch.
- `begin_death` is the die function for a death that leaves a body. A monster
  that gibs draws no sequence.
- Pain and death frames stride along the monster's facing (Q1 `ai_painforward`
  and `ai_forward` ahead, `ai_pain` and `ai_back` behind; Q2
  `{ai_move, dist}` by the model scale) through `sequence_stride`, the same
  walk-move attack `steps` use. It moves with the monster's own box over
  steps and along walls, and not at all when the ground would end under it,
  when the monster is in the air, or into its target's box. Fliers and
  swimmers take the whole step or none (`SV_movestep`), and a swimmer out of
  the water stays put.
- A body with no authored sequences (a hand-built one, or a class without a
  rule) flinches for `pain_duration` on its model's first pain family and
  falls on its first death family.

## Waking and hunting

- Any hit from the player wakes a monster and turns it on the player, even
  over a monster it was fighting. This includes projectiles and splash, not just
  hitscan (Q1 `T_Damage`, Q2 `M_ReactToDamage`).
- A Q1 monster keeps its enemy until one of them dies. Out of sight it heads for
  the player's current position (`movetogoal`), so it follows the player through
  the level as far as its steps can take it. A Q2 monster that has seen its
  enemy keeps it too, and follows the player trail (below); one that has only
  heard a noise runs to it, stands there and gives up after 8 s.
- Unalerted monsters mutter their idle sound every 15–30 s.
- Monsters play the sight, pain, death, idle and weapon sounds their
  originals have (`scripts/roster_smoke.jac` checks each against the
  archives). Burst fire sounds on every shot.

## Medics, power screens and drops

- A Q2 medic takes the healthiest-born corpse it can see within 1024 units as its
  enemy (`medic_FindDeadMonster`). A `Mends` edge marks the claim. The medic runs
  to the corpse and plays its cable sequence. If the corpse is within 256 units
  and in sight at `attack50`, it stands up as a fresh monster hunting the medic's
  old enemy. Raised monsters keep no targets, so a second death fires nothing.
- The Q2 brain's power screen (`CheckPowerArmor`) absorbs a third of frontal
  damage from its 100 cells. It is off while the brain ducks.
- Q1 grunts, enforcers and ogres drop a backpack with 5 shells, 5 cells or 2
  rockets (`DropBackpack`) on the third frame of their death, so one that
  gibs drops nothing. Q2 monsters drop their `item` key as they are killed
  (`Drop_Item` in `monster_death_use`). Drops are hidden `Pickup`s linked by
  `Drops` edges (marked `released` once shown) and revealed where the
  monster's body is.
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
  is pushed back out of them and stopped. Monsters are solid to each other
  and to the player in their steps (`SV_movestep`'s trace): a monster cannot
  step into another living monster, a barrel or the player. Corpses, gibs
  and items stay passable.
- Monsters move with their own box on their own game's maps
  (`monster_collision` in `engine/world/combat.jac`):
  - Q2/Q3 brush hulls are stored expanded by the player's box. A view made by
    `CollisionMap.for_body(height, drop, mins, maxs)` carries a `BodyBox`, and
    each brush plane moves by the difference between the two boxes at the
    corner facing it, as `CM_BoxTrace` does. The broad phase widens every
    stored bound by the same difference. No extra hulls are built.
  - Q1 maps load clip hull 2 next to hull 1; a monster wider than 32 units
    (shambler, ogre, fiend, vore, dog, Chthon and Shub-Niggurath) traces it
    (`SV_HullForEntity`, `CollisionMap.fit_body`).
  - The monster's origin is its real origin. Q2 bosses whose mins z is 0
    (supertank, Jorg, Makron, Hornet, the chick, flipper) stand with their
    feet at it.
  - Boxes follow each monster's `setsize`/`VectorSet` values, including the
    ogre, dog, gladiator, flipper and Q2 barrel.
  - Monsters on another game's maps (Passion) keep the player's box; their
    model is lowered so a Q2 model with mins z 0 stands on the floor.

## Patrols and combat points

- A monster whose `target` names a `path_corner` walks the corner chain while
  idle. It uses the original walk cycle (Q1 `walk`/`prowl_`, Q2 `walk1`; Q2
  soldiers choose `walk1` or `walk2`, above) and each frame steps that
  frame's own `ai_walk` distance toward the corner (`frame_step`,
  `movetogoal`), as the run cycle does.
- Corners are reached by the original box touch.
- Q2 corners fire their `pathtarget` and pause for their `wait`.
- A Q2 monster with a `combattarget` runs its `point_combat` chain once alerted,
  holding fire until it arrives (`AI_COMBAT_POINT`).
- Path corners and combat points share the `TrackPoint` graph with trains.
  `Patrols` and `Holds` edges are rewired at each corner, and saves record them.

## Infighting

- Monster hitscan, beams, missiles and splash damage hit whatever is in the
  way, including other monsters. Only the shooter itself is ever skipped.
- A monster's missile carries its `owner` through flight and saves (as an
  opponent index), so a direct hit or its splash is credited to the monster
  that fired it: a monster it hurts turns on that monster, and a player it
  kills records it as the killer (Q3 match scoring and obituaries).
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
  - Q1/Q2 gibs tumble in all three axes, drawn with their pitch and roll.
- Q1 heads stay where they land. Other pieces fade after 10–20 s (Q3: 5–8 s).
- Q2 and Q3 corpses remain shootable and keep taking damage until they gib. A
  Q2 corpse keeps its standing box while its death sequence plays and is then
  left its `*_dead` box (`dead_width`, `dead_bottom`, `dead_top`); a Q3 body's
  top drops at once. Q1 monster corpses take no damage, as in the original.
- Snapshot format **22** records corpse health and gibbing, patrol progress, the
  skill, power-screen cells, raised monsters, dropped items and each
  monster's chase (`STEP` lines: heading, the step in progress, its random
  stream and flags). A `SEQUENCE` record carries the death a corpse drew and
  how far it has played, an attack a monster is holding until it faces its
  enemy, and how long ago its pain was last due. Pain in progress is in the
  monster's own row. Flying gibs are not saved.

## Trail hunting

Q2's player trail (`p_trail.c`) is a graph of up to eight `TrailMark` crumbs
hanging off a `PlayerTrail` node (`engine/world/trail.jac`). The player drops a
crumb every half second once they are 32 units from the last one; each
records the heading it was reached on. A Q2 monster that reaches the spot
where it lost the player takes the first crumb laid since
(`PlayerTrail_PickFirst`: that crumb, or the one before it if only that one
is in sight) and then each next one (`PlayerTrail_PickNext`), turning to the
crumb's heading. With no newer crumb the ring comes round to its oldest
again, as the original's does.

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
  ducking, and while it is down its pain function is not called (`T_Damage`
  skips it for `AI_DUCKED`).
- On medium a soldier answers a third of its dodges by crouching and firing
  (`attack3`), and on hard two thirds. It fires at `attak303`, loops back once
  while the second-long duck lasts, and stays crouched from the first shot to
  `attak307`. A machine gunner holds `attak303` for its burst instead and
  does not loop.
- On hard a gunner lobs a grenade half the time as it ducks
  (`gunner_duck_down`).

## Validation

- Tests:
  - `tests/monster_tactics_tests.jac`: attack chances, moving between attacks,
    waking on player hits, Q1 hunting, medic revival, dropped items (the Q1
    drop frame, nothing from a gibbed grunt, Q2 at once).
  - `tests/monster_sequence_tests.jac`: pain and death tables, selection,
    sounds, strides, airborne pain, corpse boxes and saves.
  - `tests/monster_move_tests.jac`, `tests/monster_chase_tests.jac`: the
    originals' steps and chase directions, bodies blocking each other, Q2's
    pursuit, the chase in saves (see
    [navigation-status.md](navigation-status.md)).
  - `tests/infighting_tests.jac`: provocation rules, line of fire, missile owners,
    kill counting, return to the player.
  - `tests/gib_tests.jac`: thresholds, corpse damage, flight, landing and fading.
  - `tests/patrol_tests.jac`: corner loops, Q2 waits and pathtargets, combat
    points, saves.
  - `tests/combat_tests.jac`: awareness and skill.
  - `tests/monster_gait_tests.jac`: per-frame steps, yaw speeds, the
    soldier's two walks, and turning to face before attacking (Q2, and Q1's
    ogre check against the plain `CheckAttack`).
  - `tests/trail_tests.jac`: crumb laying, headings and following.
  - `tests/dodge_tests.jac`: duck timing and box, facing checks, soldier
    crouch-fire by skill.
  - `tests/monster_hull_tests.jac`: a supertank box standing at its feet,
    stopped by an 80-unit gap a player-sized box passes, and Q1 hull 2 for
    wide monsters.
- `scripts/monster_hull_smoke.jac` loads power1 (supertank), boss2 (Jorg),
  jail2 (tank) and e1m5 (shambler). On 2026-10-09 each started clear of the floor and settled
  with its feet on it (within 0.04 units). The supertank, walked by 4-unit
  monster steps toward an opening a player-sized box crosses, was refused its
  seventh step (24 units) where a player box could go 681 further; Jorg
  stopped after 32 units with 714 to spare. Screenshots are saved in
  `.jac/screenshots/hulls/`.
- `scripts/monsters_smoke.jac` runs on `e1m1`, `e1m2`, `base1` and `q3dm1`. It
  gibs a monster and renders the flying pieces, walks every patroller along its
  corners, and stages a fight between two monster kinds.

## Limits

- No shipped map in the smoke set uses `point_combat`; that behaviour is covered
  by tests only.
