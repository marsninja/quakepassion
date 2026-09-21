# Gameplay performance investigation

Measured on the local macOS ARM64 desktop with the native integration compiler
at `qp-prototype-validation` (`41db5f4851`), original assets, a 1280x720 window,
uncapped rendering, and the default spawn view. These are local diagnostic
samples, not guarantees across maps, views, hardware, or larger enemy rosters.

| Map | Original render ms/frame | Optimized render ms/frame | Original combat ms/tick | Optimized combat ms/tick |
| --- | ---: | ---: | ---: | ---: |
| Q1 e1m1 | 12.54–12.59 | 2.79–2.86 | 27.90 | 0.371 |
| Q2 base1 | 11.26–11.35 | 4.40–4.42 | 27.84 | 0.431 |
| Q3 q3dm1 | 6.98–7.40 | 4.16–4.19 | 5.30 | 0.122 |

Rendering samples exclude simulation, with 30 warmup frames and 180 measured
frames per mode. Combat samples cover 120 fixed ticks. The full app loop also
has a 240-frame sample after warmup: median/p95 frame times were 2.84/6.04 ms
(Q1), 5.26/8.31 ms (Q2), and 4.44/7.81 ms (Q3). These measure stationary gameplay,
not worst-case encounters. No frame cap or rendering resolution change was used.

## Changes

- Batch opaque model stages across the scene; retain flushes at transparent
  blend/depth transitions. Standalone model draws still restore render state.
- Cull models using conservative spheres covering every animation frame,
  tested against the camera frustum. The menu culling toggle disables this.
- Cache immutable PVS face membership until the camera changes BSP leaf or
  culling mode. Moving brush faces remain included and use live transforms.
- Skip stair-step probes when the ordinary slide already achieves the desired
  horizontal motion.
- Give Q1 brush models conservative expanded bounds and use the shared spatial
  index. Keep the world hull unbounded, including its solid exterior. Door
  loading expands bounds over mover travel before rebuilding the index.
- Reject individual nonintersecting hulls within broad-phase batches before
  spawning narrow-phase walkers.
- Run staggered opponent sight decisions at 10 Hz; attacks require fresh sight
  checks. Moving/falling opponents and player physics stay on the 120 Hz
  timestep. Resting opponents check support at 20 Hz and resume per-tick
  integration on waking. Animation and weapon cooldowns continue every tick.

## Reproduce

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-prototype-validation/jac
export JAC_COMPILER_LIB=off
jac build scripts/profile_gameplay.jac --native -o .jac/qp-profile-gameplay
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-profile-gameplay
```

Run without concurrent builds/tests for comparable timings. The harness also
prints rendering results without model resources as a diagnostic control. It
does not load or save personal settings. Keep the window foreground and avoid
input during the app-loop sample.

## Correctness evidence

- `scripts/validate_collision_index.jac`: 312 indexed/exhaustive comparisons
  pass across the three maps, for both player-sized and point queries.
- `scripts/combat_smoke.jac`: all three games pass combat, save/restore and Q3
  respawn checks with original resources. Q1/Q2 captures were inspected.
- `scripts/alias_models_smoke.jac`: Q1 models and Q3 multi-stage armor pass;
  time-separated Q3 captures retain the required animated pixel difference.
- Added frustum-edge, cached-sight attack and lost-support regression cases.
- Full sequential unit suite: 151 passed (154.45 seconds). An earlier mixed
  build/test run hit a cached renderer import failure; its cache was preserved
  under `.jac/cache-before-perf-jit`. Clean and warm focused runs, an AOT-build
  then focused-test run, and the final sequential full suite pass. No compiler
  workaround or test suppression was added.

The known settings `splitlines` blocker is separate. Broad map/encounter
stress testing is still needed before claiming all performance problems are
eliminated; remaining immediate-mode world geometry can also limit throughput.
