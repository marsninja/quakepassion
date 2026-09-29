# Navigation and frame pacing

A record of the navigation costs that stalled frames, the fixes, and how to
measure them again. The simulation budget at 120 Hz is 8.33 ms per tick. How
monster navigation works is in [navigation-status.md](navigation-status.md);
Q3 bot routing is in [bot-tactics-status.md](bot-tactics-status.md).

## Budgeted ground search

A crowded-enemy probe in September 2026 found a synchronous ground search that
stalled one combat tick for 588 ms. The fixes, all still in place:

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
- Steering checks the next segment once and stops at the first clear preferred
  heading. Crowd separation uses 64-unit buckets. At most eight actors make a
  new perception or steering decision per tick.
- Q1/Q2 monsters request a route only when out of sight or when the straight
  heading is blocked.

### Measurements (2026-09-22)

`scripts/profile_navigation.jac` alerts every actor in Q1 e1m1, Q2 base1 and
Q3 q3dm1, holds attacks, and reports combat tick mean, median, p95 and maximum,
with and without route searches (`no_route_search` is a diagnostic mode, not a
gameplay option). Q1 e1m1, 23 enemies, 600 ticks:

| Version | Mean | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Synchronous searches | 26.20 ms | 46.60 ms | 588.32 ms |
| Budgeted searches | 5.22 ms | 10.90 ms | 13.50 ms |

Q2 base1 (17 enemies) measured 4.32 ms mean / 9.38 ms maximum; Q3 q3dm1 (3
bots) 1.79 ms / 5.00 ms. The crowded Q1/Q2 p95 still exceeded the 8.33 ms
tick budget: the change removed the search spikes, not every cost.

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
cache reuse and invalidation, crowd buckets),
`tests/navigation_revision_tests.jac` (invalidation through a shared hull view),
`tests/navigation_save_tests.jac` (restore cancels obsolete jobs),
`tests/travel_table_tests.jac` (a table built a budget at a time matches one
built at once).
