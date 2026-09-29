# Translating platforms and player carrying

`func_plat` now uses the shared door/button mover graph, render transforms and
collision hulls. A standing player is carried by the same displacement, upward
or downward. A jump detaches the player. The entire move is checked before any
player, rendered face or collision offset changes; an obstruction reverses the
platform without leaving a partially moved rider. Escape pauses the simulation.

A plat's travel (and a door's or button's) comes from the brush model's box as
the game sees it: the BSP model's stored bounds spread a unit each way
(`Mod_LoadSubmodels`, `CMod_LoadSubmodels`, `CM_LoadSubmodels`), which counts
brushes without faces too. Q2 `base3`'s cage lift has lip 132 on a model
reaching 320 units below its 144-unit car, so it rises 190 units; face bounds
gave it 12. Q2 and Q3 movers travel 2 units further than before; Q1's stored
bounds sit a unit inside the brush, so Q1 travel is unchanged. Trains put
these bounds' mins at each corner (`train_next`, `train_resume`). A probe of
both `base3` lifts with a gunner aboard carried it the full 190 and 154 units.

Q1/Q2 unnamed platforms start lowered and rise on contact. Named platforms start
at the authored upper position; their first signal lowers and unlocks them.
Q3 platforms start lowered, including named platforms, which require a signal.
Riders hold a raised platform open until they leave. Platforms descend after the
wait, carrying any player who steps aboard during descent.

This is initial translating-platform support, not full mover parity. Q2 plats
ramp up and down as `Think_AccelMove` does (see [level flow](level-flow-status.md)).
Platform teams, trains,
rotating movers, crushing damage, sounds and arbitrary map scripting remain
unsupported. Unsupported target chains stay disabled. There is no platform
velocity transfer on jumping off.

## Validation

- Full suite: 86 tests, including carrying up/down without drift, blocked-carry
  rollback, jumping, and named-platform differences across all three games.
- Native asset checks: 17 Q1 and 16 Q2 full platform cycles; 16 Q1 and 14 Q2
  successful player-carry probes. The remaining platforms did not provide a
  clear standing point among the sampled positions; those cover transforms only.
- The supplied Q3 map archives contain no `func_plat` entities. Q3 semantics are
  unit-tested; no Q3 asset-backed lift or graphical lift pass is claimed.
- Desktop app checks (before model-bounds travel): Q1 `e1m1` and Q2 `base3`, both a 152-unit rise under the
  fixed-step walking simulation. Escape pause and final nonpenetration pass.
  Bottom/top screenshots were visually inspected and are local artifacts under
  `.jac/screenshots/platforms/`.

Use the local compiler described in
[native-cache-section-merge-blocker.md](native-cache-section-merge-blocker.md):

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-cache-sections/jac
export JAC_COMPILER_LIB=off
jac test
jac build scripts/validate_platforms.jac --native -o .jac/qp-platform-check
QP_GAME=q1 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-platform-check
QP_GAME=q2 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-platform-check
jac build scripts/platform_smoke.jac --native -o .jac/qp-platform-smoke
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-platform-smoke
```
