# Shared liquid detection and initial swimming

The fixed-step walking loop now samples the player's feet, body and eyes to
classify immersion from dry (0) to fully submerged (3). Q1 reuses the BSP spatial
graph and leaf contents. Q2/Q3 use graph-connected water/slime/lava volumes built
from exact world brush planes, with point queries rather than expanded standing
hulls. Oblique brush boundaries are retained. Overlapping liquid contents prefer
lava, then slime, then water.

At body-depth immersion, the shared movement walker uses three-dimensional
input, liquid drag, slower acceleration and collision-aware sliding instead of
air gravity. Forward swimming follows the camera pitch; Space ascends and Left
Shift descends. No input gently sinks the player. Feet-only immersion retains
walking with additional drag. Leaving the water restores ordinary gravity.
Escape pauses movement; teleport arrival holds still apply.

This is initial shared swimming, not exact per-game physics parity. The current
160-unit input speed cap, water acceleration and drag are shared across games.
Currents, automatic ledge/water jumps, drowning, lava/slime damage, underwater
postprocessing, sounds and per-game movement tuning remain unfinished. Crouching
also remains separate work. Liquid types are recorded for future gameplay; they
do not yet cause damage.

## Validation

The full suite passes 100 tests. New fixtures cover all immersion depths, Q1
content mapping, oblique Q2/Q3 liquid brushes, overlapping liquid priority,
ascent/descent, drag, input speed limits, solid collision, pause and restored
gravity outside water.

The asset validator samples clear submerged standing hulls and swims upward for
30 ticks, then checks displacement and nonpenetration. Maps without a clear
submerged sample are explicitly reported as skipped. This is representative
coverage, not an exhaustive map or water-exit traversal test.

Build with the local compiler described in
[native-cache-section-merge-blocker.md](native-cache-section-merge-blocker.md):

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-cache-sections/jac
export JAC_COMPILER_LIB=off
jac test
jac build scripts/validate_swimming.jac --native -o .jac/qp-swim-check
QP_GAME=q1 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-swim-check
QP_GAME=q2 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-swim-check
QP_GAME=q3 DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-swim-check
jac build scripts/swimming_smoke.jac --native -o .jac/qp-swim-smoke
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-swim-smoke
```

Asset checks pass on ten maps: Q1 `start`, `e1m1`, `e1m2`, `e1m3`, `e2m1`;
Q2 `base1`, `base3`, `jail1`, `waste1`; Q3 `q3dm12`.
Desktop held-Space ascent and Escape pause checks pass on Q1 `e1m2`, Q2 `base1`
and Q3 `q3dm12`. The after-movement captures were inspected. Screenshots and
logs are local artifacts in `.jac/screenshots/swimming/`. These establish input,
movement and continued rendering, not complete underwater presentation.
