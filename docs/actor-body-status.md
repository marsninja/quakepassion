# Actor body and player stance isolation

Enemy eye height is now stored with each opponent when the map populates its
roster. Player crouching no longer changes the coordinate conversion used for
enemy movement, routes, authored attack steps, hit bounds, blast centers, door
contact, or platform/train carrying.

`CollisionMap.for_body` creates a stance-specific view over the same hulls,
spatial index, live mover offsets, and disabled-hull set. Geometry is shared;
stance fields are independent. The combat walker reuses a view for opponents
with the same eye height during a tick. Enemy movement keeps the standing hull
instead of borrowing the player's crouched clearance.

Remembered targets retain the eye height at the time they were seen, so crouching
out of sight cannot move an enemy's remembered ground destination. Player hit
queries now also account for the lowered top of the crouched hull, including
enemy hitscan fire and hostile projectiles.

Coverage: `tests/enemy_stance_tests.jac` checks stable grounded enemy height,
independent hit bounds, standing headroom, shared mover offsets, and a platform
ride while the player crouches. `scripts/enemy_stance_smoke.jac` exercises native
Q2/Q3 body isolation. Map population determines enemy eye height, so no snapshot
layout change is required; the current format remains 14.

Validation: the full suite passed **311 tests**. Two additional integration cases
for shot-alert memory and train riders then passed alongside the eight existing
train tests (10 focused checks), for **313 distinct tests across these runs**.
The standalone native Q2/Q3 stance harness passed. The final rebuilt viewer
completed Q1 `e1m1`, Q2 `base1`, and Q3 `q3dm1` startup/render smoke checks.
These results use the documented local source compiler; they are not full
campaign playthrough or released-toolchain acceptance.

Per-monster movement boxes came later (see
[monster behaviour](monster-behaviour-status.md#bodies)). This does not implement monster duck
animations, flying/swimming AI, or global navigation. Those remain part of the
unfinished original-game scope.
