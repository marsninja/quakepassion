# Passion expeditions

Passion is the fourth game mode of the shared engine (`games/passion/`). It
generates seeded expeditions from original Quake, Quake II and Quake III
assets: a cyclic mission of keys, switches and guardians is embedded as rooms
and stair corridors, dressed with recipe interiors and cover, populated by an
encounter director, lit, and chosen from several candidates by quality and
diversity. Every expedition is proven completable in its own geometry before
it is played. The generator version is `v2` (`generate.jac` `VERSION`).

## Run

With the build in the README and all three games under one asset directory
(`~/quake-assets` by default; `QP_ASSETS` names another parent):

```sh
QP_GAME=passion QP_SEED=42 DYLD_LIBRARY_PATH=vendor ./qp
```

- `QP_SEED` picks the seed (default 1); `QP_MAP=v2-42` is the equivalent
  level name. Seeds run from 1 to 2147483646, and names with another version
  prefix are rejected (`seed_from`), so saves from an older generator do not
  load.
- `QP_LIGHT_CACHE` sets the baked-lighting cache directory (default
  `~/.cache/quakepassion/lighting`); an empty value disables disk caching.
  Cache files are keyed by a hash of every bake input and verified by SHA-256
  on load.
- The Escape menu lists twelve fresh seeds when Passion is selected. The HUD
  briefing names the districts the route crosses and the objectives (for
  example "Stone Keep > Deep Mines | Recover 2 keys, slay 1 guardian, reach
  extraction"). Enter replays after death or completion; quick save and load
  keep the generated world.

## Pipeline (`generate.jac`)

1. Seed to niche: a seed hashes to one of 81 niches in a descriptor grid
   (loopiness, verticality, combat density, size; three bins each) plus an
   objective archetype: keys, relays, guardian or mixed. Consecutive seeds land
   in unrelated niches.
2. Candidates: six complete candidates are built toward the niche (up to
   eighteen when some fail). Each is re-proven by the playtester, measured,
   and scored for quality and distance to the niche; the best is compiled.
3. Compile, visibility, physics check, bake: the winner becomes BSP data,
   cluster visibility is computed, corridor floors and hull clearance are
   checked against real collision, and lighting is baked or loaded from the
   cache.

### Randomness (`random.jac`)

A counter-based stream (`mix32(key ^ mix32(counter))`) with labelled
substreams, so one subsystem's draws never reshuffle another's. Arithmetic
stays in 32-bit words split into 16-bit halves, so native and interpreted
builds produce identical levels. Bounded draws use rejection sampling.

### Mission grammar (`mission.jac`)

Missions are graphs: an `Expedition` holds `Beat` nodes joined by `Link`
edges, `start -> sections -> gate -> goal`, each section a cycle pattern after
Dormans' cyclic dungeon generation:

| Pattern | Shape |
| --- | --- |
| alternatives | Short dangerous arc and long safe arc |
| lock_key | Key on one arc; drop back to the lock on the other |
| far_key | Deep key, one-way drop home, lock beside the entrance |
| shortcut | Long arc out; a door that opens only from the far side |
| hidden | Long arc plus a shootable secret door |
| foreshadow | The destination is seen through a window first |
| switch | Remote switch opens a door back near the entry |
| gambit | Optional high-danger reward room on a side loop |

Long arcs expand into chains of rooms or nested cycles; side content adds
secret caches, recovery rooms and vistas. Links carry the tokens they need
and beats grant tokens, so an exhaustive search over (beat, token set) states
proves the goal reachable and no reachable state a softlock. Beats get a
progression order and a tension value: a rising curve with three swells and
recovery beats after peaks.

### Spatial embedding (`layout.jac`)

- Rooms are rectangles on a macro grid of 5×5 columns, 32 units per column,
  sized by role and placed in progression order beside placed neighbours
  (with a deterministic ring search when crowded).
- Each link is an A* corridor through free macro cells with turn costs, or a
  direct opening through a shared wall; links that cannot be routed fall back
  to paired teleporters when their semantics allow.
- Floor heights are difference constraints over room floors and per-socket
  landings (stair capacity, 80-208 unit ledge drops for one-way valves,
  interior slope limits), solved exactly by Bellman-Ford toward
  tension-driven targets. Nearby unlinked rooms gain impassable sightline
  slits.

### Interiors (`interior.jac`)

Each room picks a recipe: hall, clipped, cross, court, cavern (cellular
automata), pit (water, slime or lava, with stairs out), balcony, terraces,
split, arena or colonnade. Socket landings are pinned to their solved
heights, and a geodesic Lipschitz envelope turns the desired shape into a
heightfield whose neighbours (diagonals included) differ by at most one step.
Lanes between sockets and the stage are locked before decoration. Objective
rooms get a dais, large rooms sniper perches, and cover comes from a
wave-function-collapse pass over 2×2 tiles. Connectivity is verified; a
failing recipe falls back to a hall.

### Blueprint and compile (`blueprint.jac`, `compile.jac`)

The expedition is a column heightfield: each column is solid, or open with a
floor and ceiling. Corridor floors change by at most one 16-unit step, with
flat turn landings and ledges at valve ends. Doors:

- key doors use the `key` field;
- switch and relay doors are `targetname` doors fired by a floor-plate
  `func_button`;
- guardian doors open when the guardian's `target` fires on death;
- shortcuts open from a `trigger_once` on their far side;
- secrets open by shooting a panel beside a wall-textured door.

Compilation merges equal columns greedily into brushes. Walls and pillars
extend past every neighbouring air interval, so the world is watertight by
construction. A face is emitted only where it faces air and is listed in
every leaf whose air it faces. Liquids are non-solid content brushes; lamp
fixtures are emissive panels.

### Director (`director.jac`)

- Room threat budgets follow tension, room size, progression and the niche's
  density. Templates: patrol, snipers (on perches), horde, and arena for
  large arena and guardian rooms.
- The roster mixes Q1 and Q2 monsters and Q3 bots, weighted toward each
  district's game. Guardians are shamblers, shalraths, tanks, tank
  commanders or gladiators.
- Key and switch rooms answer the objective with trigger-spawned Q2 ambushes.
  High-tension arenas can lock down: a `trigger_once` at the arena's heart
  closes START_OPEN doors on its free entrances and teleports in Q2
  reinforcements; the doors reopen on their timer.
- A resource simulation walks the intended route and places health, shells
  and armor to keep expected health inside a band; secret caches hold
  megahealth.

### Proof, visibility and lighting (`playtest.jac`, `visibility.jac`, `lighting.jac`)

- The playtester models the 32-unit hull: the agent stands on column corners
  whose four columns are open, share a floor within one step and leave
  headroom; it climbs one step, drops from ledges, respects door tokens, and
  is forced through any teleporter trigger it touches. An objective counts
  only where the hull rests on the stage column. A token-carrying flood proves
  the mission in the real geometry; a failing candidate is rejected.
- Cluster visibility flows through blueprint portals; a portal chain survives
  only while some line passes through all its portals (an exact 2D stabbing
  test). The result is conservative.
- Lightmaps (32-unit luxels) and per-cluster probe grids gather only lamps
  whose cluster can see the face. Shadow rays walk the column grid
  (Amanatides-Woo) through the engine's pluggable `Occluder`
  (`ColumnOccluder`), softened by offset samples.

## Districts and assets (`materials.jac`)

Six districts, each with five material slots (floor, wall, ceiling, trim,
accent):

| District | Source game |
| --- | --- |
| Stone Keep | Q1 |
| Slipgate Base | Q1 |
| Strogg Outpost | Q2 |
| Deep Mines | Q2 |
| Gothic Ruin | Q3 |
| Arena Works | Q3 |

Special surfaces cover liquids, the teleporter, buttons, the shootable panel,
the key door, the extraction sign and sixteen lamp tints. Material indices do
not depend on assets, so headless generation and tests need none. Original
assets load locally and are never copied into the repository.

## Validation

```sh
jac test -j0 tests/passion_tests.jac tests/lighting_tests.jac
jac build scripts/validate_generation.jac --native -o .jac/qp-generation
DYLD_LIBRARY_PATH=vendor .jac/qp-generation
jac build scripts/lighting_smoke.jac --native -o .jac/qp-lighting-cache
QP_LIGHT_TEST_CACHE="$(mktemp -d /tmp/qp-lighting-check-XXXXXX)" .jac/qp-lighting-cache
jac run scripts/validate_passion.jac
```

- `tests/passion_tests.jac`: stream determinism and independence,
  softlock-free missions across archetypes, rejection of unreachable goals,
  embedding, deterministic proven expeditions, entity wiring, stair walking
  under real physics, PVS soundness against sampled sightlines, shadow-ray
  agreement with collision traces, locked key doors, niche spread and strict
  version parsing, asset manifests in saves, and brush-seam point traces.
- `scripts/validate_generation.jac` (headless, no assets): seeds 1-200 plus
  104729 and 2147483646, each with a mission proof, hull playtest, corridor
  physics and cluster culling, reporting rejections and descriptor coverage.
  Run of 2026-09-23: all 202 passed in 76 s (0.76 s worst, candidate search
  included); per expedition on average 27.5 rooms, 4,728 faces, 66 hostiles,
  81% of cluster pairs culled, 2.7 sightline windows and 0.18 teleporter
  links. 66% of candidates were valid, the chosen expeditions filled 35 of the
  81 niches, each archetype appeared 47-56 times, and all eleven recipes were
  used.
- `scripts/lighting_smoke.jac`: a cold bake and a cache hit of `v2-42` into
  an isolated directory.
- `scripts/validate_passion.jac` builds `scripts/passion_smoke.jac` natively
  and runs it on a desktop with the assets: a scripted player drives the real
  game loop in god mode along playtest routes to every objective and
  extraction, and exercises save/load, replay, menu seeds and version
  rollback, capturing the spawn, menu, districts, tallest room, a combat flash
  and completion (`QP_SEED`, default 42). On 2026-09-23 seeds 7, 13, 21, 42
  and 99 passed, covering key vaults, relay switches, single and double
  guardian gates, an arena lockdown, teleporters and liquids; a full load
  with a cold bake took 1.1-1.8 s.

Jac compiler defects found while building Passion are recorded in
[jac native fixes](jac-native-fixes.md).

## Limitations

- Space is a 2.5D heightfield of rectangular rooms on the macro grid:
  corridors never cross over one another, and nothing overhangs walkable
  floor except the sightline slits.
- Passion has no weapon table of its own (`weapon_rules("passion")` is
  empty): the player has the engine's two basic weapon slots, and the
  resource economy balances against them.
- The director's damage model is a heuristic, not a combat simulation; the
  smoke validates routes and objectives, not fight difficulty.
- Niche coverage is measured, not guaranteed: the best-scoring candidate is
  chosen even when it misses its niche.
- Visibility ignores height and treats rooms as convex, which keeps it sound
  but culls less than an exact volumetric solution.
- Lighting is direct light from the lamps over a fixed ambient floor (0.12,
  `shade` in `engine/world/lighting.jac`); there is no bounced light. Doors
  are left out of the static shadow rays (they are lit from probes as they
  move), and dynamic lights cast no shadows.
