# Enemy navigation and frame pacing

The September 2026 crowded-enemy probe exposed a synchronous ground search that
could stall one combat tick for 588 ms. The simulation budget at 120 Hz is 8.33 ms.

## Runtime design

- A level's `CombatState` owns a round-robin `RouteQueue` and reusable navigation
  graph. At most twelve search advances run per physics tick. Each advance does
  at most one movement sample, rather than a complete A* expansion. A single
  collision query's duration still depends on the level's collision geometry;
  this is a deterministic work budget, not a hard wall-clock deadline.
- Live actors never invoke the synchronous `ground_route` validation helper.
  Requests are capped at eight outstanding jobs. Cancelled and finished jobs
  leave the queue; dead/dormant actors cancel requests and restored actors replan.
- Connections are learned on a common 48-unit grid, including separate floor
  heights, and cached for the level. This is lazy construction, not an exhaustive
  startup bake or a persistent disk navmesh. Cached entries preserve stance and
  endpoints. Collision changes invalidate affected cached results; connections
  near moving submodels are always checked live. Cache capacity is bounded.
- Collision mutations report revisions through `set_offset` and `set_disabled`;
  body-specific collision views share those revisions. Unchanged levels return
  immediately from cache validation instead of copying every brush offset each
  tick. Runtime geometry changes must use these mutation methods.
- Ground steering checks support and steps over the next segment once and stops
  at an unobstructed preferred direction. Crowd separation uses nearby 64-unit
  buckets. At most eight actors make a new perception/steering decision per tick;
  actor movement, collision and scheduled attack events still run every tick.
- Q1/Q2 favor local pursuit. They request a route when sight is lost or local
  steering is blocked; they do not gain arena jumping or item-seeking behavior.
- Q3 requests may include collision-validated jump actions. Flight validation is
  incremental and uses the movement integrator's gravity and fixed timestep.
  Authored teleport and jump-pad connections are prepared at level load. Arena
  goals can choose a useful health/armor pickup or a travel shortcut, while shared
  contact walkers execute item collection and traversal. Item respawn timers
  advance only once per world tick. A per-world spatial index limits bot contact
  checks to nearby items and triggers while retaining live availability state.
- Door/platform collision and carrying remain shared with the existing mover
  implementation. Navigation cache entries do not freeze mover positions.

## Reproduction

Build `scripts/profile_navigation.jac` with the local native Jac compiler and run
with `DYLD_LIBRARY_PATH="$PWD/vendor"`. It alerts all actors in Q1 e1m1, Q2 base1
and Q3 q3dm1, holds attacks, and reports combat tick mean, median, p95 and maximum.
The no-search phase is a diagnostic comparison, not a shipped gameplay option.
`scripts/profile_gameplay.jac` additionally measures rendering and full app frames.

The final Q1 comparison (23 enemies, 600 ticks) was:

| Version | Mean | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Synchronous searches | 26.20 ms | 46.60 ms | 588.32 ms |
| Final implementation | 5.22 ms | 10.90 ms | 13.50 ms |

These are controlled stress timings on the development machine, not guarantees
for every map or a reproduction of the user's exact room. Q2 base1 (17 enemies)
measured 4.32 ms mean / 9.38 ms maximum; Q3 q3dm1 (3 bots) measured 1.79 ms mean /
5.00 ms maximum. Expensive actor physics and rendering remain
separate costs; the catch-up limit and simulation frequency were not reduced.

The separate full-app probe (240 frames after warm-up at each map's spawn) gave:

| Map | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Q1 e1m1 | 4.19 ms | 6.37 ms | 8.31 ms |
| Q2 base1 | 7.33 ms | 9.22 ms | 11.84 ms |
| Q3 q3dm1 | 7.78 ms | 8.59 ms | 9.73 ms |

Q3's earlier full-app baseline was 8.32 ms median / 10.85 ms maximum.
These spawn-view measurements include rendering but are not crowded-room frame
benchmarks. The crowded Q1/Q2 combat p95 still exceeds the 8.33 ms simulation
budget; this change removes the large synchronous-search spikes, not every
possible source of slowdown.

Validation: 372 Jac tests passed, including incremental search budgets, cache
invalidation through shared collision views, arena jump physics, item/portal
contacts, and snapshot restoration. Native Q3 traversal smoke checks cover
q3dm6 (3 links/pads) and q3dm17 (15 links, 13 pads).

## Limits

The learned grid is bounded local navigation, not full Q3 AAS equivalence.
Authored arena shortcuts currently use a travel-distance heuristic, and item
selection covers health and armor. Arbitrary multi-portal shortest paths,
weapon/ammo tactics, and planned elevator timetables are not implemented.
The infrastructure supports all three original games; Passion integration is
intentionally deferred.

Arena armor is included in snapshot version 17. Earlier snapshot versions are
rejected explicitly. Navigation jobs, routes and selected arena goals remain
transient and are rebuilt after restoration.

The new jump test also exposed a native Jac compiler defect in boolean
comprehension storage (`any([item.value > 0.0 for item in items])`). Validation
uses the proper local compiler fix; the engine keeps the idiom unchanged.

Upstream compiler fix: https://github.com/jaseci-labs/jac/pull/9441.
