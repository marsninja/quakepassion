# Monster movement and navigation

Q1 and Q2 monsters stride each frame's authored distance, turn at their own
`yaw_speed`, move in their own collision boxes, open doors, ride and block
movers, and find bounded ground detours when local steering fails. All of it
runs in the `CombatTick` walker (`engine/world/combat.jac`) over the world
graph. Q3 bots share the body and mover code but route over the map's AAS; see
[bot-tactics-status.md](bot-tactics-status.md).

## Strides and turning

- **Per-frame distances.** Each rule carries a `run` and a `walk` `Gait`
  (`engine/world/opponent_rule.jac`): the model frames played at 10 Hz and the
  distance each frame carries the monster, from Q1 `ai_run(dist)` /
  `ai_walk(dist)` and Q2 `mframe_t` tables. `gait_speed` returns the current
  frame's step times ten, scaled for Q2 models by `step_scale`
  (`monsterinfo.scale`, `MODEL_SCALE`). The cycle restarts when the pose
  changes. Negative steps move backwards. Alerted monsters run; unalerted ones
  (patrols) walk.
- **Monster movestep.** Monsters move by the stride directly, with no player
  acceleration or friction (`striding`, as Q1 `SV_movestep` / Q2
  `M_walkmove`). Stepping up stairs uses the movement integrator with the
  walker's profile.
- **Walk branches.** A `Gait` can branch back (Q2 `soldier_walk1_random`:
  walk110 returns to walk101 nine times in ten). `other_walks` lets a monster
  pick among walks when it sets off (Q2 `soldier_walk`: walk1 or walk2).
- **Turning.** The monster turns toward where it is going, or its target, by
  `yaw_speed` degrees per 0.1 s frame, the short way round, spread over the
  frame's ticks (`change_yaw`, as Q1 `ChangeYaw` / Q2 `M_ChangeYaw`). Walkers
  use 20 (`walkmonster_start`), fliers and swimmers 10 (`flymonster_start`,
  `swimmonster_start`), Chthon 20 (`boss_awake`).

## Steering and pursuit

- **Local steering.** A walking monster tries its heading, then 45 and 90
  degrees either side, probing 48 units ahead with `walk_edge` (collision,
  18-unit steps, support every 12 units). Crowds are separated by a soft push
  over 64-unit buckets. At most eight actors make a new perception or steering
  decision per tick; movement and attack events run every tick.
- **Pursuit out of sight.** A Q1 monster keeps its enemy and steers at the
  player's current position (`movetogoal`), so it follows through the level. A
  Q2 monster that reaches where it lost the player follows the player trail
  (`engine/world/trail.jac`, `p_trail.c`).
- **Fliers and swimmers** (`movement` `fly` / `swim`): steer in the plane and
  hold 30-40 units above the target's origin (as `SV_movestep`'s `FL_FLY`
  adjustment), or fly straight at a path corner. Velocity eases toward the wish
  and slides along walls. A swimmer out of water falls.

## Ground routes

`engine/world/navigation.jac`. When a walker has lost sight of its target, or
its straight heading is blocked, it requests a ground route:

- The search samples a 48-unit lattice with separate height layers (by 18
  units) and expands up to 96 points (hard cap 256). Each connection is walked
  with the monster's own body: 18-unit steps, ground checks every 12 units, no
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

See [navigation-performance.md](navigation-performance.md) for the budget's
measurements.

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
- **Other game's maps** (Passion): monsters keep the player's box, with the
  model lowered to the floor.
- **Stance isolation.** Each opponent stores its own eye height at load, so
  player crouching never changes monster movement, hit bounds, blast centres,
  door contact or carrying. Player hit queries use the crouched hull's top.
- **Solidity.** Living monsters are solid to the player (`SOLID_SLIDEBOX`): the
  player is pushed out of them, and a monster cannot step into the player
  (`SV_movestep`). Charges refuse steps into the target's box. Corpses are
  passable. Monsters are not solid to each other.
- **Ducking.** A Q2 dodge lowers the hit box top by 32 units; the movement box
  is unchanged.

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
  pushed but never block.
- Riding a mover clears a monster's route so it replans at the new height.

## Validation

- `tests/monster_gait_tests.jac`: per-frame distances, pace, exact strides, Q2
  knockback, yaw speeds, the soldier's two walks.
- `tests/monster_hull_tests.jac`: a boss box stopped by a gap a player passes,
  stopping at its own edge, Q1 hull 2.
- `tests/navigation_tests.jac`, `navigation_hull_tests.jac`,
  `navigation_budget_tests.jac`, `navigation_revision_tests.jac`,
  `navigation_save_tests.jac`, `navigation_jump_tests.jac`: detours, pits, step
  height, narrow passages and headroom, search budgets, cache invalidation,
  restoration.
- `tests/trail_tests.jac`: Q2 crumbs.
- `tests/enemy_stance_tests.jac`, `tests/actor_body_integration_tests.jac`:
  stance isolation, remembered stance, trains carrying monsters.
- `tests/enemy_door_tests.jac`: doors opening for monsters, forbidden and dormant
  monsters, key doors, closing-door reversal, plat carrying, a blocked rider.
- `tests/mover_push_tests.jac`: a lift carrying a large monster, items, Q3
  rotating riders, turret push and crush.
- Native: `scripts/navigation_smoke.jac` (detour),
  `scripts/enemy_mover_smoke.jac`, `scripts/enemy_stance_smoke.jac`, and
  `scripts/monster_hull_smoke.jac` (power1 supertank, boss2 Jorg, jail2 tanks,
  e1m5 shambler settle on the floor and stop at gaps; captures in
  `.jac/screenshots/hulls/`).

## Limitations

- Local steering, not Q1 `SV_StepDirection` / `SV_NewChaseDir`: monsters try
  five fixed headings instead of the originals' chase-direction rules.
- Ground routes are bounded local detours, not map-wide routing. The lattice can
  miss narrow or irregular passages.
- Fliers and swimmers have no route search; they steer only.
- Monsters do not plan through elevators or trains, operate remote switches, or
  use jump or swim links (jump links exist only for arena searches).
- Monsters are not solid to one another; crowds are separated by steering.
