# Validation tooling

How QuakePassion is checked: asset-free unit tests under `jac test`, and
asset-backed native harnesses that load the original maps, drive the real game
loop and check screenshots. The original game files are never in the
repository; harnesses read them from `~/quake-assets/{id1,baseq2,baseq3}`.

Setup (the pinned compiler source, `scripts/stage_compiler.sh`, and raylib
with JPG/TGA, `scripts/stage_raylib.sh`) is in the [README](../README.md).
Native harnesses are built and run from the repository root:

```sh
jac build scripts/<name>.jac --native -o .jac/<name>
DYLD_LIBRARY_PATH=vendor .jac/<name>        # LD_LIBRARY_PATH on Linux
```

## Unit tests

`tests/*_tests.jac`, one file per area. They need no game assets or window
(the one check that reads original Q2 films, in `cinematic_tests`, returns
early without them).

```sh
jac test tests/console_shell_tests.jac                  # one file
ls tests/*_tests.jac | xargs -P 4 -n 1 jac test         # all, one process per file
```

One `jac test` process over the whole suite needs far more memory than one per
file. CI (`.github/workflows/jac-test.yml`) builds the pinned compiler kernel
(cached per pin), builds the repros in `repros/` and `scripts/repros/` and the
native `qp`, then runs every test file in its own process twice: cold, then
with a warm cache.

## Hosted runners

These run with `jac run`; each builds a native binary, runs it on an active
desktop and checks the PNG captures it writes. `scripts/png_checks.jac`
decodes PNGs (all five filters, RGB and RGBA), rejects blank images and counts
differing pixels (`tests/validation_images_tests.jac`).

| Runner | Checks | Output |
|---|---|---|
| `scripts/validate_quake.jac --game q1\|q2\|q3 [maps]` | `qp` with `QP_SMOKE=1` per map: five captures (PVS on/off at spawn, a turn, PVS on/off after moving); PVS pairs differ by at most 16 pixels; the turn and move change the view | `.jac/screenshots/<game>/<map>/` |
| `scripts/validate_menu.jac` | `scripts/menu_smoke.jac` with a disposable `HOME`: console, settings, bindings, resize, level list, game switching, failed load, Quit (see [menu and console](menu-console-status.md)) | `.jac/screenshots/menu/` |
| `scripts/validate_gameplay.jac` | The `persistence`, `gameplay`, `campaign` and `combat` smokes with isolated saves | `.jac/screenshots/gameplay/` |
| `scripts/validate_passion.jac` | `scripts/passion_smoke.jac`: a generated route, mixed assets, saves and the menu | `.jac/screenshots/passion/` |

`validate_quake` builds nothing; build `qp` first (`jac build main.jac
--native -o qp`, or pass `--binary`).

## Asset-backed native checks

Headless checks of engine systems on original maps (no window). Most select a
game with `QP_GAME` and a directory with `QP_ASSETS`.

| Script | Checks |
|---|---|
| `validate_doors.jac`, `validate_platforms.jac`, `validate_trains.jac`, `validate_secret_doors.jac`, `validate_buttons.jac`, `validate_brush_objects.jac` | Movers and brush entities on real maps; trains, secret doors and Q2 destructibles also through save and restore |
| `validate_triggers.jac`, `validate_events.jac`, `validate_progress.jac`, `validate_exits.jac` | Triggers, signal scheduling, secrets and objectives, level exits and their spawn points |
| `validate_movement.jac`, `validate_traversal.jac`, `validate_swimming.jac`, `validate_ladders.jac` (`QP_MAPS`) | Player movement, teleporter and launch destinations, liquids, Q2 ladders and currents |
| `validate_hazards.jac` | Damage volumes and their persistence |
| `validate_collision_index.jac` | Indexed collision queries against exhaustive ones |
| `validate_models.jac`, `validate_alias_models.jac` | Every Q2 MD2 and skin; Q1 MDL and Q3 MD3 archives |
| `validate_generation.jac` | Passion's generator (no assets): every seed softlock-free and completable |
| `audit_campaigns.jac`, `chain_audit.jac` (Q1/Q2; `QP_AUDIT_GAMES`, `QP_AUDIT_MAPS`) | Entity inventory of the installed maps; per-map exits, disabled movers and triggers, unactivated targets |

## Whole-game sweeps and walkthroughs

- **`scripts/map_sweep.jac`** (`QP_SWEEP_GAMES=q3` limits it): every original
  Q1, Q2 and Q3 map loads through the `App` as the menu loads it, simulates two
  seconds with its monsters, bots, movers and effects, and renders a frame to
  `.jac/screenshots/sweep/<game>_<map>.png`. Failures are reported per map;
  the sweep never stops at the first. On 2026-09-23 all 121 maps passed
  (every Q1 and Q2 map, and all 36 Q3 maps including CTF and test maps). The
  sweep found and led to fixes for q3tourney6's fog indices past its fog list
  and q3dm19's AAS version 4 bot file.
- **`scripts/campaign_walkthrough.jac`** (`QP_WALK_GAMES`, `QP_WALK_ONLY`):
  follows every Q1 and Q2 level exit through the real game loop, placing the
  player in the exit or a trigger chain that reaches it and passing stats
  screens; exits no touch trigger reaches are fired directly and reported.
  Every map is also played for a few seconds in god mode.
- **`scripts/arena_ladder_walkthrough.jac`** (`QP_LADDER_ONLY`,
  `QP_SECONDS`): plays each Q3 ladder arena with the bots fighting, then gives
  the player the frag limit and checks the podium, postgame and the next
  arena.

## Graphical smokes and galleries

`scripts/*_smoke.jac` are native harnesses for one area each (models, enemies,
weapons, HUD, portals, fog, bots, movers and more); each doc's Validation
section names its own. They drive the `App` with scripted input and save
captures. Comparison tools:

- `scripts/effects_gallery.jac`: one still frame per game with every effect
  kind posed at fixed ages (`effects_<game>.png`), for comparing effect
  renderers by eye.
- `scripts/model_gpu_smoke.jac`: the same models through the GPU and legacy
  paths (`model_gpu_smoke_gpu.png`, `model_gpu_smoke_cpu.png`).
- `scripts/render_benchmark.jac` with `QP_BENCH_SHOTS=1` and `QP_BENCH_DT`:
  four views per map at the same animation moment, for comparing renderers.
- Profiling harnesses are listed in [performance](performance-status.md).

## Capture modes of `qp`

- `QP_SMOKE=1`: a deterministic capture sequence (`qp_quake_pvs.png`,
  `_all`, `_turn`, `_moved_pvs`, `_moved_all` in the working directory) that
  prints face counts and exits; the user's bindings are not loaded.
- `QP_CAPTURE=<frame>:<file.png>`: play normally and save one full screenshot
  (HUD and view weapon included) at that frame, then exit.
- Both need a graphical display; so do the hosted runners and smokes.

## Limitations

- Screenshot checks establish that views render, change and cull
  consistently; they do not compare against the original games' renderers.
- Graphical checks are run by hand on a desktop; CI runs only the unit tests
  and native builds.
