# Performance

How to measure frame and simulation cost, what keeps it low, and the dated
measurements that still describe the engine. Rendering benchmarks are in
[rendering](rendering-status.md#measured-2026-09-27); crowded navigation in
[navigation performance](navigation-performance.md).

## Measuring

All harnesses are native. Build with `jac build <script> --native -o
.jac/<name>` and run with `DYLD_LIBRARY_PATH=vendor` from the repository root.
None write settings or saves. Run them on a quiet machine and compare runs
made back to back.

| Script | Measures |
|---|---|
| `scripts/render_benchmark.jac` | Frame time and each render stage (`App.render_times`) over a full turn; `QP_BENCH_COMBAT=1` adds combat effects |
| `scripts/profile_gameplay.jac` | A fixed view's render cost and the combat tick on e1m1, base1 and q3dm1 |
| `scripts/profile_campaign_maps.jac` | The real game loop, the view alone and each simulation walker per tick, idle and with nearby monsters awake (`QP_PROFILE_MAPS`) |
| `scripts/profile_model_lighting.jac` | Q1/Q2 model lighting: alternating lit and unlit blocks of a map's start view |
| `scripts/profile_navigation.jac` | Every original-map actor alerted, attacks held, to isolate movement and routing |
| `scripts/bot_think_profile.jac` | Q3 bots' navigation, doors, combat and AI walkers per tick (`QP_MAPS`, `QP_SECONDS`) |
| `scripts/bot_render_profile.jac` | Q3 bot bodies drawn every frame, against the same frames without models |
| `scripts/frame_spike_probe.jac` | Q3 arena frames slower than `QP_SPIKE_MS` with their stages, plus percentiles and load time |
| `scripts/level_change_leak_probe.jac` | Frame times after each of a series of level loads (`QP_MAPS`, `QP_FRAMES`); it prints a `LOAD` line per map so a wrapper can read the process RSS (for example `ps -o rss= -p <pid>`) between loads |

To profile by function name, build with a compiler that keeps internal symbols
(jaseci-labs/jac#9635), hold one mode
(`QP_PROFILE_HOLD=lit QP_PROFILE_SECONDS=30` for the model-lighting profile)
and run `sample <pid> 8`.

## What keeps frames cheap

- The GPU renderer: static world chunks with per-leaf index runs, keyframe
  animation in the vertex shader, instanced effects (see
  [rendering](rendering-status.md)).
- Visible face sets are cached per BSP leaf; models are gathered only from
  areas that hold entities and culled by bounding spheres.
- Model lighting is cached per origin, yaw row and flags until light styles
  or dynamic lights change, and light traces per point.
- Collision queries first walk a bounding-box tree of hull groups
  (`HullGroup`, `FindHulls`, `engine/physics/collision.jac`), and a long trace
  keeps only the groups its segment passes through.
  `scripts/validate_collision_index.jac` compares indexed and exhaustive
  queries on e1m1, base1 and q3dm1.
- Monsters decide on attacks at 10 Hz, as the originals think, and bots look
  for enemies at their 10 Hz think rate. Movement and gravity run on
  the 120 Hz tick; resting actors probe their support at 20 Hz, and a settled
  one only once its place is disturbed.

## Model lighting and the cycle collector (2026-09-28)

Lighting Q1/Q2 models from the lightmaps (`TraceLightPoint`,
`Lighting.light_model`) seemed to cost about 1 ms a frame on e1m1 and
1.5-3.6 ms on base1. `scripts/profile_model_lighting.jac` showed the extra time
in the world and visibility stages, not the model stage, and it stayed when
the computed light was thrown away.

With internal symbols kept (jaseci-labs/jac#9635), `sample` put 85-90% of the
main thread in the native runtime's cycle collector: vectors, lists of ints
and graph rows were buffered as candidate cycle roots; every thousand of them
started a collection that retraced the level's live graph; and each traced
object's trace function was found by a linear search. Lighting released a few
more shared objects each frame, so collections came sooner. The fix is in the
collector (jaseci-labs/jac#9636): objects with nothing to trace are never
roots, collections are paced by the live graph they traced, and the trace
lookup probes the shared registry first.

Back to back, 1280×720, 3 blocks of 240 frames, ms per rendered frame
("after" built with jaseci-labs/jac#9635, #9636 and #9638; the `rc` column an
earlier run of the same view without the cycle collector):

| Map | Before, lit | Before, unlit | After, lit | After, unlit | `rc` profile |
| --- | ---: | ---: | ---: | ---: | ---: |
| Q1 e1m1 | 2.56 | 2.12 | 0.45 | 0.43 | 0.46 |
| Q2 base1 | 9.96 | 8.12 | 0.87 | 0.88 | 0.79 |

Model lighting costs at most 0.02 ms a frame, and whole frames run 5-10x
faster, about as fast as without the collector. The compiler fixes involved
are listed in [jac native fixes](jac-native-fixes.md).

## Limitations

- Measurements are single-machine samples (macOS arm64) on selected maps and
  views; broad encounter stress testing across all maps has not been done.
- Level loading and archive scanning are synchronous; a load stalls the frame.
