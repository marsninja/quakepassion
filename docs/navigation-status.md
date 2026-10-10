# Monster movement and navigation

Q1 and Q2 monsters move as the originals' monsters do: once every 0.1 s
frame of its walk or run cycle a monster takes one whole step of that frame's
authored distance, or none of it, in its own collision box. It keeps its
heading while it can step that way and otherwise picks another of eight
compass headings; it plans no routes. The steps are in
`engine/world/monster_move.jac` (Q1 `sv_move.c`, Q2 `m_move.c`); the thinks
that take them are in the `CombatTick` walker (`engine/world/combat.jac`, Q1
`ai.qc`, Q2 `g_ai.c`). Q3 bots share the body and mover code but move as
players and route over the map's AAS; see
[bot-tactics-status.md](bot-tactics-status.md).

## Frames and steps

- **Per-frame distances.** Each rule carries a `run` and a `walk` `Gait`
  (`engine/world/opponent_rule.jac`): the model frames played at 10 Hz and the
  distance each frame steps the monster, from Q1 `ai_run(dist)` /
  `ai_walk(dist)` and Q2 `mframe_t` tables. `frame_step` returns the current
  frame's distance, scaled for Q2 models by `step_scale`
  (`monsterinfo.scale`, `MODEL_SCALE`). The cycle restarts when the pose
  changes. Negative distances step backwards. Alerted monsters run; unalerted
  ones (patrols) walk.
- **One think a frame.** Each new frame of a walk or run cycle is one think
  (`CombatTick.stride_frame`, as Q1 `ai_walk` / `ai_run` and Q2 `ai_walk` /
  `ai_run`). A monster with an enemy stays on its run frames whether or not
  the frame's step can be taken, so a blocked monster runs in place. The
  first frame of a cycle thinks one tick after the cycle is entered.
- **The step** (`movestep`, as `SV_movestep`). A walker's box is pushed down
  from 18 units above the wished place to 18 below it. The step is refused
  if the box is in solid there, if no floor is within a step below (walked
  off an edge), or if `SV_CheckBottom` fails: with any corner of the box not
  over solid, the floor under the middle must be within two steps and the
  floor under each corner within one step of that. So monsters climb and
  descend stairs of up to 18 units and never step off a ledge. A Q2 walker on
  dry ground does not step into water. A monster whose floor has been pulled
  out (`FL_PARTIALGROUND`) steps out and falls.
- **Chase direction** (`MoveToGoal`, as `SV_MoveToGoal` / `M_MoveToGoal`). No
  step is taken if it would reach the enemy's box (`SV_CloseEnough`).
  Otherwise the monster steps along `ideal_yaw` (`SV_StepDirection`); one
  time in four, and whenever that step is refused, `SV_NewChaseDir` picks a
  new heading: the diagonal toward the goal, the two axes toward it, the old
  heading, every compass heading one way round or the other, and last the way
  back. Each attempt first turns the monster `yaw_speed` degrees toward the
  heading (`ChangeYaw`), and a step is taken only once the monster has turned
  to within 45 degrees of it, measured one way round as `sv_move.c` does. The
  south-west diagonal is 215 degrees, as in the original.
- **Other steps.** `WalkMove` is `PF_walkmove` / `M_walkmove`: one step
  along a yaw, all or nothing. `SlideMove` is `ai_run_slide`: turn to the
  enemy and step square to it, changing sides when blocked.
- **Carried over the ticks.** A step moves the monster at once, as the C
  does. `MonsterBody.stride` then carries the drawn and shootable body from
  where the frame began to where its step ended over the frame's remaining
  120 Hz ticks, turning it with the same share, and leaves it exactly on the
  step's end. `MonsterBody.standing` is where the box already is for every
  other step, the pusher and the neighbour buckets. Anything else that moves
  a body in mid step (a lift, an attack's charge) is kept and the step still
  ends as far ahead; a knock, a fall or lost support finishes the step at
  once before the body slides or falls; a teleporter drops it.
- **Randomness.** `SV_MoveToGoal`'s and `SV_NewChaseDir`'s `rand()` choices
  come from the monster's own `step_random` stream, seeded from its
  `shot_random` beside its attack rolls, so chases repeat and survive saves
  without disturbing attack sequences.
- **Walk branches.** A `Gait` can branch back (Q2 `soldier_walk1_random`:
  walk110 returns to walk101 nine times in ten). `other_walks` lets a monster
  pick among walks when it sets off (Q2 `soldier_walk`: walk1 or walk2).
- **Turning out of the cycle.** Holding an attack, attacking or in pain, a
  monster turns toward its target by `yaw_speed` degrees per 0.1 s frame,
  spread over the frame's ticks (`change_yaw`, as Q1 `ChangeYaw` / Q2
  `M_ChangeYaw`). Walkers use 20 (`walkmonster_start`), fliers and swimmers
  10 (`flymonster_start`, `swimmonster_start`), Chthon 20 (`boss_awake`).

## Chasing

- **Heading.** A newly alerted monster's `ideal_yaw` is turned on its enemy
  (`HuntTarget`), a monster leaving an attack is turned on it again
  (`ai_face`, `ai_charge`), and a monster taking a path corner or combat
  point is turned on that (`t_movetarget`, `path_corner_touch`).
- **Q1.** A monster keeps its enemy until one of them dies and moves at the
  enemy itself, seen or not (`movetogoal`).
- **Q2.** A monster moves at an enemy in sight. One it has seen keeps it
  until one of them dies; out of sight (`CombatTick.pursue`, as `ai_run`) it
  makes for where it last saw the enemy (`AI_LOST_SIGHT`,
  `AI_PURSUIT_LAST_SEEN`), then takes the player trail crumb by crumb
  (`PlayerTrail_PickFirst`, `PlayerTrail_PickNext`,
  `engine/world/trail.jac`), turning to each crumb's own heading. A new goal
  its box cannot reach in a straight line is corrected by tracing 16 units
  to the left and right of the line and making for the side that reaches
  further (`AI_PURSUE_TEMP`). Twenty seconds after `search_time` it takes one
  step at the enemy itself. A monster with only a noise to go on
  (`AI_SOUND_TARGET`) runs to it and stands within 64 units.
- **Corners.** Path corners and Q2 combat points are reached by `MoveToGoal`
  like any goal.
- **Sliding.** A Q2 flier that holds its fire slides three checks in ten
  (`M_CheckAttack`, `AS_SLIDING`); the Q1 Scrag slides whenever its shot is
  clear and the enemy nearer than 500 units (`WizardCheckAttack`), on its
  hover frames at 8 units a frame (`wiz_side1`-`8`).
- **No planning.** As in the originals, monsters do not plan through lifts,
  trains or doors, press switches or jump gaps. A monster that cannot step
  toward its goal bumps along by chase directions; `trigger_monsterjump`
  volumes throw monsters where the map says; automatic doors open for them
  and movers carry them (below).

## Fliers and swimmers

Fliers and swimmers (`movement` `fly` / `swim`) take the same thinks; their
step is `SV_movestep`'s `FL_FLY` / `FL_SWIM` branch, a straight trace of the
box:

- With an enemy, the step first tries 8 units of fall or rise toward 30-40
  units above the enemy's origin, then tries again level. Q2 holds 30-40
  above a player but comes level with any other goal, to the unit.
- Q1: a swimmer's step that would leave the water is refused outright.
- Q2: a flier out of the water never steps into it; a swimmer less than
  waist deep never steps out of it or rises.
- Without an enemy (a path corner) the step keeps its height.
- A knocked flier's velocity dies away as it slides. A swimmer out of its
  depth falls.

## Bodies

- **Own boxes.** On their own game's maps monsters move in their
  `SP_monster_*` / `setsize` box (`width`, `hull_bottom`, `hull_top` on the
  rule), through `monster_collision`. `CollisionMap.for_body(height, drop, mins,
  maxs)` returns a view sharing the level's hulls, index and mover offsets. For
  Q2/Q3 its `BodyBox` shifts each brush plane by the difference from the
  player's box, as `CM_BoxTrace` does. On Q1 a box wider than 32 units traces
  clip hull 2 (`SV_HullForEntity`). Monsters of one size share a view per tick
  (`monster_body_key`). Q2 bosses with mins z 0 stand with their feet at their
  origin.
- **Other game's maps** (Passion): monsters keep the map's box
  (`CollisionMap.hull_box`), with the model lowered to the floor, and chase
  by the same steps.
- **Stance isolation.** Each opponent stores its own eye height at load, so
  player crouching never changes monster movement, hit bounds, blast centres,
  door contact or carrying. Player hit queries use the crouched hull's top.
- **Solidity.** A step is traced against the world and against the other
  solid bodies (`StepSpace.solids`, as `SV_Move` clips to `SOLID_SLIDEBOX` and
  `SOLID_BBOX` entities and Q2's `MASK_MONSTERSOLID`): living monsters and
  barrels, each where its own step ends, and the living player. So monsters
  block each other and the player, and a walker can come to rest on another
  body's head only where the floor is there too. Corpses (Q1 `SOLID_NOT`, Q2
  `SVF_DEADMONSTER`), gibs, heads and items never block a step. The bodies
  near a step come from `CombatTick`'s 64-unit buckets, widened for the
  widest living body. The player is pushed back out of living monsters and
  bots (`ClearActors`).
- **Ducking.** A Q2 dodge lowers the hit box top by 32 units; the movement box
  is unchanged.

## Ground routes for Q3 characters without AAS

`engine/world/navigation.jac`. Bodies that move as players (Q3 characters)
use it where the map has no AAS: Passion's maps and hand-built test worlds.
Campaign monsters never do. When such a body has lost sight of its target, or
its straight heading is blocked, it requests a ground route:

- The search samples a 48-unit lattice with separate height layers (by 18
  units) and expands up to 96 points (hard cap 256). Each connection is walked
  with the body's own box: 18-unit steps, ground checks every 12 units, no
  unsupported drops. Several risers may form one connection. An exhausted budget
  returns no route rather than a partial one.
- Searches are `RouteSearch` jobs on the level's round-robin `RouteQueue`: at
  most twelve advances per tick, one movement sample each; at most eight
  outstanding jobs; eight new searches per simulated second with at most one
  banked credit. The walker graph (route points and parent edges) is reused.
- Learned connections are cached per body box (`probe_key`), up to 16384.
  Collision revisions (`set_offset`, `set_disabled`) invalidate affected
  entries, and connections near moving submodels are always checked live.
- A route is dropped when its target moves more than 48 units, when riding a
  mover, on respawn, and on save restoration. Routes and jobs are transient.

See [navigation-performance.md](navigation-performance.md) for the measurements.

## Doors and movers

- Automatic doors open for living, non-dormant monsters (`engine/world/doors.jac`).
  Key doors stay locked. Q2 `NOMONSTER` (spawnflag 8) is honoured across linked
  groups.
- Brush movers push and carry through one shared pusher
  (`engine/world/pusher.jac`, Q1 `SV_PushMove`, Q2 `SV_Push`, Q3
  `G_MoverPush`): plats, doors, trains and rotators move every rider and every
  body they run into, each traced in its own box (the player's, each monster's,
  each item's). If one body cannot go, everything is put back and the mover
  crushes, reverses or waits as its game's blocked function does. Corpses are
  pushed but never block. A monster in mid step is pushed from where its step
  ends and keeps the rest of the step to take.

## Saves

Each campaign monster that has stepped writes a `STEP` line: `ideal_yaw`, the
yaw its steps have turned it to, the step it is part-way through (where it
ends and the time left), its `step_random` stream, `FL_PARTIALGROUND`,
`AS_SLIDING` and `lefty`, and Q2's pursuit flags, `saved_goal` and what is
left of `search_time`. Saves without the line load with a fresh chase.

## Validation

- `tests/monster_move_tests.jac`: `anglemod` and `vectoyaw`; a step taken
  whole or not at all; an 18-unit riser climbed and a 19-unit one refused; a
  ledge refused and a stair descended; a solid body in the way; turning
  before stepping; a table of `SV_NewChaseDir` cases worked by hand from
  `sv_move.c` (the diagonal, the 215 heading, the way back skipped, both
  search orders, every heading blocked); the one-in-four new heading;
  `SV_CloseEnough`; `FL_PARTIALGROUND`; fliers' 8-unit rises and falls per
  game; water rules; `ai_run_slide`; a step carried over its ticks, through a
  lift's push, ending exactly.
- `tests/monster_chase_tests.jac`: two monsters blocking each other in a
  corridor and a corpse that does not; stopping where the next step would
  reach the player; Q2's pursuit to the last sighting and along the trail; a
  noise investigated and given up; the chase in a save.
- `tests/monster_gait_tests.jac`: per-frame distances, one whole step a
  frame carried over its ticks, Q2 knockback, yaw speeds, the soldier's two
  walks.
- `tests/monster_hull_tests.jac`: a boss box stopped by a gap a player passes,
  stopping at its own edge, Q1 hull 2.
- `tests/navigation_tests.jac`, `navigation_hull_tests.jac`,
  `navigation_budget_tests.jac`, `navigation_revision_tests.jac`,
  `navigation_save_tests.jac`, `navigation_jump_tests.jac`: the ground route
  search: detours, pits, step height, narrow passages and headroom, search
  budgets, cache invalidation, restoration.
- `tests/trail_tests.jac`: Q2 crumbs, their headings and the pursuit taking
  the first.
- `tests/enemy_stance_tests.jac`, `tests/actor_body_integration_tests.jac`:
  stance isolation, remembered stance, trains carrying monsters.
- `tests/enemy_door_tests.jac`: doors opening for monsters, forbidden and dormant
  monsters, key doors, closing-door reversal, plat carrying, a blocked rider.
- `tests/mover_push_tests.jac`: a lift carrying a large monster, items, Q3
  rotating riders, turret push and crush.
- Native: `scripts/navigation_smoke.jac` (a route search and a Q3 character
  following its route), `scripts/enemy_mover_smoke.jac`,
  `scripts/enemy_stance_smoke.jac`, and `scripts/monster_hull_smoke.jac`
  (power1 supertank, boss2 Jorg, jail2 tanks, e1m5 shambler settle on the
  floor and stop at gaps; captures in `.jac/screenshots/hulls/`).

## Limitations

- The steps of attack frames (`ai_charge`, through `attack_charge`) still
  slide by the player's stair-stepping move rather than `WalkMove`, so a
  charging monster is stopped by its target's box but not by other monsters.
- Two bodies that already overlap (after a leap, a charge, a knock or a
  fall, none of which is traced against other bodies) do not block each
  other's steps, so that they can part; the originals leave such bodies stuck.
- Q2 monsters collide with player clip brushes and not with monster clip
  brushes (`CONTENTS_MONSTERCLIP`), which the level's hulls do not carry.
- The player trail is laid by time and distance travelled, not when the
  player loses sight of the last crumb as `p_client.c` does.
- Q2's course correction traces the world only, not other bodies.
- A knocked Q2 flier's velocity is eased away rather than rubbed off by
  `SV_Physics_Step`'s flying friction.
- Angles are not quantised to 16 bits as `anglemod` does.
