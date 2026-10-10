# Navigation and frame pacing

A record of what monster movement and navigation cost, the fixes for the
costs that stalled frames, and how to measure them again. The simulation budget at 120 Hz is 8.33 ms per tick. How
monster navigation works is in [navigation-status.md](navigation-status.md);
Q3 bot routing is in [bot-tactics-status.md](bot-tactics-status.md).

## Monster steps (2026-10-09)

Q1 and Q2 monsters no longer steer by probes or search for ground routes.
Each takes one step per 0.1 s frame of its walk or run cycle
([navigation-status.md](navigation-status.md)), and between steps it is only
carried along, with no traces at all. What a think costs:

- With the way clear: one box trace down and `SV_CheckBottom`'s four point
  tests (five more point traces when a corner is not over solid).
- Blocked: `SV_NewChaseDir` tries up to twelve headings, a box trace or two
  each. On e1m1 with every monster alerted, many of them shut in, a think
  averaged about 0.22 ms.
- The bodies near a step come from the 64-unit buckets; no step scans every
  opponent.

A monster's cycle keeps time with its own 10 Hz decision clock, and those
clocks are spread over the ticks at load, so monsters woken together (a
trigger, a sight cascade) do not all think on one tick. Before that was done,
24 monsters alerted on the same tick put all their thinks into one tick in
twelve: 5.4 ms at p95 and 7.9 ms at worst on e1m1.

`scripts/profile_navigation.jac` alerts every actor in Q1 e1m1, Q2 base1 and
Q3 q3dm1, holds attacks, and reports the combat tick's mean, median, p95 and
maximum over 600 ticks. Before and after, three runs each taken turn about,
best of each (ms per combat tick):

| Map | Version | Mean | Median | p95 | Maximum |
| --- | --- | ---: | ---: | ---: | ---: |
| Q1 e1m1, 24 monsters | Steering and route searches | 3.08 | 2.93 | 5.91 | 6.55 |
| | Steps | 0.55 | 0.47 | 1.35 | 3.52 |
| Q2 base1, 26 monsters | Steering and route searches | 1.64 | 1.54 | 2.82 | 6.75 |
| | Steps | 0.23 | 0.21 | 0.46 | 5.54 |
| Q3 q3dm1, 1 bot | Before | 0.09 | 0.04 | 0.40 | 5.57 |
| | After | 0.08 | 0.04 | 0.38 | 1.12 |

`scripts/profile_campaign_maps.jac`, with every monster within 1500 units of
the start awake and fighting, two runs each taken turn about, best of each.
The combat tick is the `CombatTick` walker spawned alone; the frame is the
whole game loop:

| Map (monsters, awake) | Combat tick before | after | Frame median before | after | Frame p90 before | after |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Q1 e4m7 (54, 18) | 3.83 | 0.73 | 5.53 | 1.06 | 8.11 | 3.52 |
| Q1 e1m3 (47, 22) | 3.57 | 0.77 | 0.94 | 0.94 | 5.06 | 2.25 |
| Q1 e2m6 (63, 9) | 2.45 | 0.42 | 1.60 | 1.63 | 6.24 | 3.41 |
| Q2 bunk1 (73, 14) | 1.50 | 0.40 | 4.64 | 2.27 | 5.72 | 4.19 |
| Q2 train (40, 10) | 3.02 | 0.43 | 5.31 | 1.78 | 7.27 | 3.47 |
| Q2 ware1 (47, 12) | 2.29 | 0.36 | 2.02 | 2.05 | 6.42 | 3.89 |
| Q2 ware2 (35, 9) | 1.67 | 0.24 | 1.84 | 1.80 | 4.70 | 3.09 |
| Q2 jail4 (39, 1) | 2.30 | 0.26 | 1.61 | 1.49 | 5.39 | 3.19 |
| Q2 boss1 (3, 0) | 0.01 | 0.02 | 0.98 | 1.00 | 1.79 | 1.88 |
| Q2 base1 (24, 16) | 1.48 | 0.19 | 1.37 | 1.22 | 3.51 | 2.35 |

With the level as loaded (nothing awake) the combat tick fell too, from
1.79 to 0.53 ms on e4m7 and from 1.66 to 0.32 ms on train. These runs were
made on the development machine while it was busy with other builds, so the
absolute times are high; the before and after columns were measured under
the same load.

## Budgeted ground search

The ground route search now serves only bodies that move as players where
the map has no AAS (Q3 characters on Passion's maps). Its budget dates from a
crowded-enemy probe in September 2026, when monsters still used it and a
synchronous search stalled one combat tick for 588 ms. The fixes, all still in
place:

- Searches are incremental jobs on the level's `RouteQueue`
  (`engine/world/navigation.jac`): at most twelve advances per tick, each at
  most one 12-unit movement sample, and at most eight outstanding jobs. This is
  a deterministic work budget, not a wall-clock deadline: one collision query
  still costs what the level's geometry costs. Live actors never call the
  synchronous `ground_route` helper, which is for offline checks.
- Learned connections are cached per level and body box (up to 16384). Collision
  mutations bump a revision through `set_offset` and `set_disabled`, shared by
  every body view; an unchanged level validates the cache immediately.
  Runtime geometry changes must go through those methods.
- A bot's steering checks the next segment once and stops at the first clear
  preferred heading, and bots are kept apart over 64-unit buckets. At most
  eight actors make a new perception decision per tick.

### Measurements (2026-09-22)

With monsters still routing, Q1 e1m1, 23 enemies, 600 ticks:

| Version | Mean | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Synchronous searches | 26.20 ms | 46.60 ms | 588.32 ms |
| Budgeted searches | 5.22 ms | 10.90 ms | 13.50 ms |

Q2 base1 (17 enemies) measured 4.32 ms mean / 9.38 ms maximum; Q3 q3dm1 (3
bots) 1.79 ms / 5.00 ms.

`scripts/profile_gameplay.jac` measures rendering and full app frames. Full
app, 240 frames after warm-up at each map's spawn (not a crowded-room
benchmark):

| Map | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Q1 e1m1 | 4.19 ms | 6.37 ms | 8.31 ms |
| Q2 base1 | 7.33 ms | 9.22 ms | 11.84 ms |
| Q3 q3dm1 | 7.78 ms | 8.59 ms | 9.73 ms |

These were taken on the development machine with the compiler of the time. Later
fixes (for example the native cycle-collector fix in
[jac-native-fixes.md](jac-native-fixes.md)) changed frame costs, so rerun the
scripts before comparing.

## Q3 arena frame spikes (2026-09-27)

The arena ladder walkthrough showed one-off frames of 250-940 ms on the larger
arenas. `scripts/frame_spike_probe.jac` plays arenas with the bots fighting and
prints every frame over 50 ms (`QP_SPIKE_MS`) with its render stages and the
remaining simulation time. Timing each walker spawn in `App.step` found three
causes:

- **AAS travel tables.** `NavMesh.times_to` (`engine/world/bot_routes.jac`)
  relaxes the whole AAS graph for one goal area (6000 areas and 7600 passages on
  q3dm11: 15-40 ms each). The first navigation tick asked for every item's table
  at once (880 ms on q3dm11), and dropped weapons and chased enemies asked for
  new ones later (130-180 ms ticks on q3dm12). Item tables are now built while
  the level loads (`prepare_arena_links`). Any other table is queued and relaxed
  a frontier chunk at a time, 1500 passages per navigation tick
  (`advance_tables`). Until it is ready `reachable` says no and a planned route
  is `pending`; the bot retries in 50 ms and keeps its goal.
- **Bot sight.** `BotTactics` traced three lines to its enemy every 120 Hz tick;
  on q3dm11 a slow frame ran more ticks and frames climbed to the 250 ms
  catch-up limit. Sight is checked when the bot thinks (10 Hz, `bot_thinktime`)
  and at once for a new enemy.
- **First frame.** The first frame of a level (uploads, first draws) took
  100-200 ms and the next frame simulated all of it. `load_destination` draws
  the level once before play.

## Validation

`tests/navigation_budget_tests.jac` (shared sample budget, incremental probes,
cache reuse and invalidation, neighbour buckets),
`tests/navigation_revision_tests.jac` (invalidation through a shared hull view),
`tests/navigation_save_tests.jac` (restore cancels obsolete jobs),
`tests/travel_table_tests.jac` (a table built a budget at a time matches one
built at once).
