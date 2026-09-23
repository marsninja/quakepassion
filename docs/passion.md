# Passion expeditions

Passion is the fourth game mode of the shared QuakePassion engine. Version 2
generates seeded expeditions from original Quake, Quake II and Quake III assets:
a cyclic mission of keys, switches and guardians is embedded as rooms and stair
corridors, dressed with recipe interiors and cover, populated by an encounter
director, lit, and chosen from several candidates by quality and diversity.
Every expedition is proven completable in its own geometry before it is played.

## Run

With the compiler setup in the README and all three original games installed:

```sh
jac build main.jac --native -o qp
QP_GAME=passion QP_SEED=42 DYLD_LIBRARY_PATH="$PWD/vendor" ./qp
```

Linux uses `LD_LIBRARY_PATH` instead. `QP_MAP=v2-42` is the equivalent explicit
level name; seeds range from 1 through 2147483646. The Escape menu lists twelve
fresh seeds when Passion is selected. The HUD briefing names the districts the
route crosses and the objectives (for example "Stone Keep > Deep Mines | Recover
2 keys, slay 1 guardian, reach extraction"). Enter replays after death or
completion. F5/F9 preserve the generated world. Version 1 saves are rejected;
the level name carries the generator version.

## Pipeline

Generation is deterministic and runs in well under a second natively.

1. **Seed to niche.** A seed hashes to one of 81 niches in a descriptor grid
   (loopiness, verticality, combat density, size) plus an objective archetype:
   keys, relays, guardians or a mix. Consecutive seeds land in unrelated
   niches.
2. **Candidates.** Six complete candidates are built toward the niche (up to
   eighteen when some fail). Each is measured, scored for quality and distance
   to the niche, and the best is compiled.
3. **Compile, visibility, physics check, bake.** The winner becomes BSP data,
   cluster visibility is computed, corridor floors and hull clearance are
   checked against real collision, and lighting is baked or loaded from the
   cache.

### Randomness (`random.jac`)

A counter-based stream (`mix32(key ^ mix32(counter))`) with labelled substreams.
Subsystems draw independently, so changing how many numbers one subsystem uses
never reshuffles another. Arithmetic stays in 32-bit words split into 16-bit
halves, so native and interpreted builds produce identical levels. Bounded
draws use rejection sampling and carry no modulo bias.

### Mission grammar (`mission.jac`)

Missions are Jac graphs: `Expedition` holds `Beat` nodes joined by `Link` edges.
The structure is `start -> sections -> gate -> goal`, and every section is a
cycle pattern after Dormans' cyclic dungeon generation:

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

Long arcs expand into chains of rooms or nested cycles. Side content adds
secret caches, recovery rooms and vistas. Links carry the tokens they need and
beats grant tokens, so a single exhaustive search over (beat, token set) states
proves that the goal is reachable and that no reachable state can softlock.
Beats get a progression order and a tension value: a rising curve with three
swells, and recovery beats after peaks.

### Spatial embedding (`layout.jac`)

Rooms are rectangles on a macro grid of 5x5 columns, 32 units per column,
sized by role. They are placed in progression order beside already placed
neighbors, with a deterministic ring search when the neighborhood is crowded.
Every link is routed as an A* corridor through free macro cells with turn
costs, or opened directly through a shared wall. Links that cannot be routed
fall back to paired teleporters when their semantics allow it.

Floor heights are a system of difference constraints over room floors and
per-socket landing tiers: stair capacity, ledge drops of 80 to 208 units for
one-way valves, and interior slope limits. Bellman-Ford solves them exactly,
anchored to tension-driven targets with a widening tolerance. Nearby unlinked
rooms gain sightline slits that are 40 units tall and cannot be passed.

### Interiors (`interior.jac`)

Each room picks a recipe: hall, clipped, cross, court, cavern (cellular
automata), pit (water, slime or lava, with stairs out), balcony, terraces,
split, arena or colonnade. Socket landings are pinned to their solved heights,
and a geodesic Lipschitz envelope turns the recipe's desired shape into a
heightfield whose neighbors, diagonals included, differ by at most one step.
Lanes between sockets and the stage are locked before decoration. Objective
rooms get a dais, large rooms get sniper perches, and cover comes from a small
wave-function-collapse pass over 2x2 tiles with adjacency rules. Connectivity
is verified, and a failing recipe falls back to a hall.

### World blueprint and compile (`blueprint.jac`, `compile.jac`)

The expedition is a column heightfield: each column is solid, or open with a
floor and a ceiling. Corridors become slices whose floors change by at most
one 16-unit step, with flat turn landings and ledges at valve ends. Door leaves
occupy line slices:

- **key doors** use the `key` field;
- **switch and relay doors** are `targetname` doors fired by a floor-plate
  `func_button`;
- **guardian doors** open when the guardian's `target` fires on death;
- **shortcuts** open from a `trigger_once` on their far side;
- **secrets** open by shooting a panel beside a wall-textured door.

Compilation merges equal columns greedily into brushes. Walls and pillars
always extend past every neighboring air interval, which keeps the world
watertight by construction. A face is emitted only when it faces real air and
is listed in every leaf whose air it faces. Liquids are non-solid content
brushes, and lamp fixtures are emissive panels.

### Director (`director.jac`)

Room threat budgets follow tension, room size, progression ramp and the
niche's density. Encounter templates place a roster by role:

- **patrol:** a few foes spread out;
- **snipers:** ranged foes on perches;
- **horde:** many weaker foes;
- **arena:** heavier mixed encounters.

The roster draws Q1 and Q2 monsters and Q3 bots, weighted toward the
district's game. Key and switch rooms answer the objective with trigger-spawned
Quake II ambushes. Guardians are shamblers, shalraths, gladiators or tanks.
High-tension arenas can lock down: reaching the arena's heart fires a
`trigger_once` that closes START_OPEN doors on every free entrance and
teleports in Quake II reinforcements, and the doors reopen after their timer.
A resource simulation walks the intended route and places health, shells and
armor to keep expected health inside a band; secret caches hold megahealth.

### Proof, visibility and lighting (`playtest.jac`, `visibility.jac`, `lighting.jac`)

The playtester models the 32-unit hull exactly. The agent stands on column
corners, and a corner is standable only when its four columns are open, share
a floor within one step and leave headroom. Moves climb one step, drop from
ledges, respect door tokens, and are forced through any teleporter whose
trigger the hull touches. An objective counts only from corners where the hull
rests on the stage column at its height, so it can press a plate or take a
pickup. A token-carrying flood proves the mission in the real geometry, and a
candidate that fails is rejected. Plates and switch buttons are sized to flat
footprints, so they never overhang a drop and become ledges.

Cluster visibility uses the blueprint's portals. A portal chain survives only
while some line still passes through all of its portals, an exact 2D stabbing
test. The result is conservative: tests sample clear sightlines and require the
PVS to include them.

Lighting uses per-cluster probe grids, looked up through the floor plan.
Lightmaps gather only lamps whose cluster can see the face. Shadow rays walk
the column grid (Amanatides-Woo) instead of general collision traces; they
agree with traces on more than 98% of sampled lamp-texel pairs and bake a whole
expedition in a fraction of a second. The engine exposes this as a pluggable
`Occluder`.

## Districts and assets

There are six districts, each with five material slots (floor, wall, ceiling,
trim, accent):

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

Lighting bakes are cached under `~/.cache/quakepassion/lighting`.
`QP_LIGHT_CACHE` selects another directory, and an empty value disables disk
caching.

## Validation

```sh
jac test -j0 tests/passion_tests.jac tests/lighting_tests.jac
jac build scripts/validate_generation.jac --native -o .jac/qp-generation
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-generation
jac build scripts/lighting_smoke.jac --native -o .jac/qp-lighting-cache
QP_LIGHT_TEST_CACHE="$(mktemp -d /tmp/qp-lighting-check-XXXXXX)" .jac/qp-lighting-cache
jac run scripts/validate_passion.jac
```

- **Unit tests** cover:
  - stream determinism and independence;
  - softlock-free missions across archetypes, with every pattern and link mode
    exercised;
  - embedding success;
  - deterministic expeditions proven completable;
  - entity wiring;
  - stair walking under real physics;
  - PVS soundness against sampled sightlines;
  - shadow-ray agreement;
  - niche spread and strict version parsing.
- **The generation gauntlet** runs 202 seeds natively. Each one gets a mission
  proof, a hull playtest, corridor physics and cluster culling, and the run
  reports rejection reasons and descriptor coverage.

  Latest run: all 202 seeds passed in 76 s (0.76 s worst case, candidate search
  included). The averages per expedition were:

  | Measure | Average |
  | --- | --- |
  | Rooms | 27.5 |
  | Faces | 4,728 |
  | Hostiles | 66 |
  | Cluster pairs culled | 81% |
  | Sightline windows | 2.7 |
  | Teleporter links | 0.18 |

  Of the candidates tried, 66% were valid. The chosen expeditions occupied 35
  of the 81 descriptor cells. Across the 202 seeds the four archetypes appeared
  47 to 56 times each, and all eleven room recipes were used.
- **The desktop runner** builds a native smoke. A scripted bot drives the real
  game loop in god mode along playtest routes to every objective in order:
  keys, switches and guardians, then extraction. It also exercises save/load,
  replay, menu seeds and version rollback, and captures the spawn, menu,
  district, vertical, flash and completion views.

  Seeds 7, 13, 21, 42 and 99 passed. Between them they covered keys (including
  three-key vaults), relay switches, single and double guardian gates, an
  arena lockdown, teleporters and liquids. A full load, including a cold
  lighting bake, took 1.1 to 1.8 s.

Validation uses the local jac compiler described in the README plus these
upstream fixes found during this work:

| Upstream fix | What failed natively |
| --- | --- |
| [jac#9443](https://github.com/jaseci-labs/jac/pull/9443) | A user `obj Slot` beside a walker, because OSP kernel records used the same names |
| [jac#9447](https://github.com/jaseci-labs/jac/pull/9447) | `sum` over float and bool lists |
| [jac#9448](https://github.com/jaseci-labs/jac/pull/9448) | Imported `:priv` functions shadowing public ones |
| [jac#9449](https://github.com/jaseci-labs/jac/pull/9449) | `round` halves and `ndigits` |

## Limits

- Rooms are rectangles on the macro grid, and space is a 2.5D heightfield:
  corridors never cross over one another, and nothing overhangs walkable floor
  except the sightline slits.
- Passion weapons remain the engine's two basic weapons, and the resource
  economy balances against them.
- The director's damage model is a heuristic, not a combat simulation; the
  bot validates routes and objectives, not fight difficulty.
- Descriptor coverage is measured, not guaranteed: niches steer candidates,
  and the best-scoring candidate is chosen even when it misses its niche.
- Visibility ignores height and treats rooms as convex. That keeps it sound,
  but it culls less than an exact volumetric solution.
