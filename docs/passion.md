# Passion expeditions

Passion is a fourth game mode using the shared QuakePassion engine. Version 1
creates bounded twenty-room expeditions with deterministic passage layouts,
loops, separated key objectives, three visual districts, cover, recovery rooms,
raised optional caches and an elevated bridge. Collect both keys, unlock the
signed extraction gate, then enter the final chamber. Enter replays after death
or completion; Escape opens the game/seed menu.

## Run

With the compiler setup in the README and all three original games installed:

```sh
jac build main.jac --native -o qp
QP_GAME=passion QP_SEED=42 DYLD_LIBRARY_PATH="$PWD/vendor" ./qp
```

Linux uses `LD_LIBRARY_PATH` instead. `QP_MAP=v1-42` is the equivalent explicit
level name. Seeds range from 1 through 2147483646. In the Escape menu, select
Passion and choose an expedition. Clicking Passion refreshes the seed choices;
opening the menu from a run keeps its current seed in the list. Selecting a seed
starts fresh; F5/F9 preserves the generated world, inventory, enemies, gate and
completion state. Saves identify the generator version through the level name
and verify an asset-reference manifest on restore. The manifest lists references,
not content hashes; it does not certify modified archives are identical.

Expected asset directories are `~/quake-assets/id1`, `baseq2` and `baseq3`.
`QP_GAME=passion QP_ASSETS=/another/quake-assets` overrides the common parent.
Original assets are loaded locally and are never copied into this repository.

## Architecture

- `games/passion/plan.jac`: mission graph using Expedition/Chamber nodes and
  Passage edges. A deterministic random stream builds a spanning tree plus
  loops; a separate stream chooses district/room variation. Keys are selected
  using route distance, including separation from each other. Extraction is a
  leaf behind a shared two-key door.
- `games/passion/generate.jac`: compile rooms, connectors, stairs, cover, the
  bridge and entities into shared geometry. Runtime checks inspect floor support,
  player clearance and step heights along every ordinary connector.
- `games/passion/geometry.jac`: shared Face/Brush/Plane/Model records and balanced
  spatial partitions. The engine's existing collision, doors, rendering and
  spatial walkers handle the result.
- `games/passion/materials.jac`: curated original floor/wall palettes plus the
  extraction sign. Indexed Q1/Q2 materials become explicit RGBA images so each
  can keep its own palette alongside Q3 images.
- `engine/assets/catalog.jac`: independent source archives and namespaced model
  references. Pickup/opponent adapters now read an entity's asset namespace
  separately from its game mode. Q3 characters in Passion do not arena-respawn.
- `games/levels.jac`: imported maps and generated worlds share a level-source
  interface. `prepare_level` builds the same runtime systems for either source.

Version 1 uses directional vertex brightness and conservative visibility (all
regions potentially visible), with the existing texture batching, backface
rejection, model culling and indexed collision. It does not reuse baked lighting
or PVS data from unrelated original maps. Generation runs before entering a
level; there is no per-frame geometry generation.

## Validation

```sh
jac test -j0 tests/passion_tests.jac
jac build scripts/validate_generation.jac --native -o .jac/qp-generation
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-generation
jac run scripts/validate_passion.jac
```

The first two checks need no game assets or display. The desktop runner uses a
disposable HOME linked to installed assets. It exercises actual mixed resources,
menu seed selection, ordinary movement through both key objectives to extraction,
save/load from another game, replay and invalid-version rollback. It captures
all three themes, the menu and completion. Evidence goes to
`.jac/screenshots/passion`. The route harness drives physics and contacts; it
does not test player combat skill or subjective encounter pacing.

## Scope of this version

The layout occupies a five-by-four coarse room grid. Connectivity and room
patterns vary by seed; it is not arbitrary freeform architecture or an infinite
world. Optional caches reward exploration but are not hidden-wall secrets.
The small shared combat roster and two existing weapons remain. More mission
archetypes, moving-room transformations, global navigation, additional room
patterns, baked/dynamic lighting and streaming can build on this implementation.
No WFC dependency or online generation service is required.

### Verified checkpoint

On the local source compiler (upstream main plus Jac #9388):

- Full suite: 164 tests passed in 211 seconds. Five focused image tests also pass
  after adding a flat-interface palette threshold; textured-world checks retain
  their original threshold.
- Native generation: 102 seeds pass, including 2147483646.
- Native Passion acceptance: seed 42 walks to both objectives and extraction;
  mixed models/materials, completion, persistence, replay, fresh menu seeds and
  invalid-version rollback pass. Theme/bridge/menu/completion captures inspected.
- Existing Q1/Q2/Q3 persistence, gameplay input, campaign and combat harnesses
  pass, as does the existing menu/settings/switching/quit regression.
- Main viewer builds natively. Released-compiler CI still depends on the same
  upstream release as the preceding gameplay PR; these are source-compiler results.

The isolated fixed-view timing harness measured Passion seed 42 at 447–453 FPS
for rendering with models, 0.119 ms per combat tick, and 2.58 ms median / 4.32 ms
p95 application frame time on this Mac. These are sampled local measurements,
not guarantees across all seeds or hardware. `scripts/profile_gameplay.jac` now
includes Passion alongside the three imported games.
