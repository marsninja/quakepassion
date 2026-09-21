# Shared point collision

`CollisionMap.trace_point(start, finish, exclude=[])` queries level geometry
without the player hull expansion or movement skin offset. It returns the
nearest fraction, endpoint, normal, start-solid state, hull index and BSP model
index. Exclusions use collision hull indices, as movement traces do.

All three games use the existing `Sweep` walker and mover offsets:

- Q1 supplies the render BSP nodes/leaves alongside its standing clip hull.
- Q2/Q3 retain authored brush plane distances alongside expanded planes.
- Q3 patches use double-sided triangle intersections, including barycentric
  bounds, rather than the expanded triangle hull used for movement.
- Point queries ignore playerclip, retain solids, and retain Q2 window brushes.

Moving doors/platforms share their existing collision offsets and broadphase
envelopes. Player movement and crouch still use expanded hulls. Patch triangles
are zero-thickness surfaces, so a point on a triangle has no inside-volume state.

## Validation

Focused fixtures cover actual versus expanded surfaces, start-solid and stationary
queries, exclusions, translated hulls, contents masks, and triangle bounds and
orientations. `scripts/point_trace_smoke.jac` builds and runs natively with the
local integration compiler containing upstream fixes #9354, #9357 and #9358:

```text
POINT TRACE PASS q1 e1m1 6 surfaces
POINT TRACE PASS q2 base1 5 surfaces
POINT TRACE PASS q3 q3dm1 6 surfaces
```

The asset check casts six axial rays from each spawn, verifies normals and hit
identity, then checks endpoints just before and beyond each surface. These are
geometry checks; no rendering changes or weapon effects are claimed.

## Remaining combat work

Actor hitboxes, weapon input, ammo/cooldowns, damage, impact effects and enemy
behavior are not implemented by this change. The initial point contents mask is
for solid level geometry, not complete original-game weapon trace semantics.
