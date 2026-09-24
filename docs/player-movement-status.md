# Shared Q1/Q2/Q3 walking milestone

> Ordinary and linked proximity doors now move; see the [door milestone](doors-status.md).

Run `./qp` to start walking. **WASD** moves, **Space** jumps,
and **F4** returns to flight. `QP_GAME=q2 ./qp` starts walking in Q2;
use `q1` or `q3` for the other games. Changing levels resets to walking. Use `QP_WALK=0 ./qp` to start in flight.
The development arena remains fly-only.

## Compiler requirement

The current source requires the compiler fixes in
[Jac PR #9344](https://github.com/jaseci-labs/jac/pull/9344) and
[PR #9347](https://github.com/jaseci-labs/jac/pull/9347).
The local `qp` executable was built with that patched source. To rebuild with
this checkout while the upstream fix is being integrated:

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-layout-cache/jac
export JAC_COMPILER_LIB=off
jac build main.jac --native -o qp
```

These environment settings are local development instructions, not project
compiler staging or engine workarounds. See the
[compiler report](native-relative-type-blocker.md) for the underlying defects.

## Architecture and behavior

All three games share `CollisionMap`, `HullCell` nodes, front/back edges,
`Sweep` walkers, and `MovePlayer` walkers. Shared BSP records and binary readers
live in `engine/formats/bsp.jac`; Q2/Q3 no longer import data types from Q1.
The physics layer imports neither game formats nor rendering code.

Q1 uses BSP29's pre-expanded standing-player clipnodes. Q2/Q3 load convex brush
planes and expand them by each game's standing dimensions. Q2 uses a 32-unit
width and a 22-unit eye offset; Q3 uses a 30-unit width and a 26-unit eye offset.
Both use origin-relative vertical bounds of -24/+32. Q2 includes solid, window,
and playerclip brushes; Q3 includes solid and playerclip brushes.

An OSP tree of `HullGroup` nodes and `HullChild` edges bounds the expanded
brushes. A `FindHulls` walker selects candidates overlapping the swept path,
and the same hull walker used by Q1 resolves contact. Tests compare indexed
queries with exhaustive sweeps.

Movement supplies swept collision, wall sliding, corner clipping, gravity,
ground friction/acceleration, jumping, and an 18-unit step (Q2/Q3 also step
while falling). Q2/Q3 check the jump before friction, jumps need the button
released, and landings report their speed for falling damage (see
[player-feedback-status.md](player-feedback-status.md)). Walkable ground
requires an upward normal of at least 0.7. Physics runs at 120 Hz with bounded
catch-up; rendering remains uncapped. Menu pause suspends movement and discards
pending jump input. Walking cannot be enabled inside solid geometry; fly to a
clear location first.

## Q3 curved surfaces

Q3 patch faces retain their surface type. Solid and playerclip patches contribute
triangle hulls; non-colliding materials and other surface types do not. Hidden
solid surfaces still collide, and supported inline models apply their translation.
Degenerate triangles are skipped.

Each triangle is expanded for the standing player using its surface normal,
box axes, and triangle-edge/box-axis cross products. This supplies edge bevels
as well as the surface plane, so box corners collide correctly without filling
the triangle's entire rectangular bounds. The existing `Sweep` walker clips
against the convex planes stored in one `HullCell`; Q1 retains BSP traversal.
This compact representation also handles Q2/Q3 brushes.

The spatial tree splits at the median hull center. The previous bounds-midpoint
split collapsed on large brush bounds: in q3dm1, a spawn query selected 26,338
of 26,339 hulls. The same query now selects 110. A regression test covers a
large bound mixed with small facets.

The original [Q3 patch implementation](https://github.com/id-Software/Quake-III-Arena/blob/master/code/qcommon/cm_patch.c)
uses adaptive subdivision and directional facet rules. This implementation
instead matches our rendered triangle mesh and blocks from both sides.

## Validation

The 78-test unit suite passes with the patched compiler, including player-size
expansion, contents masks, translated solid entities, ignored triggers, and
spatial-query parity. Existing tests cover high-speed sweeps, solid starts,
wall/corner sliding, grounding/jumping, slopes, steps/ceilings, cyclic hull
rejection, and Q1 collision-lump validation.

```sh
jac build scripts/validate_movement.jac --native -o .jac/qp-movement-test
QP_GAME=q1 .jac/qp-movement-test
QP_GAME=q2 .jac/qp-movement-test
QP_GAME=q3 .jac/qp-movement-test
jac run scripts/validate_menu.jac
```

Landing, jumping and four-direction movement pass on six Q1 maps (e1m1, start,
e1m2, e2m1, e3m1, e4m1), three Q2 maps (base1, base2, base3), and three Q3 maps
(q3dm1, q3dm7, q3tourney2). Every directional-movement position is checked
against the standing collision hull. These are representative spawn-area
checks, not complete map traversal or original-game movement parity. The Q3
validator also sweeps both sides of 32 solid patch facets per map (96 total).
Synthetic tests cover curved landing height, fast sweeps, vertical facets, empty
triangle corners, degenerate triangles, seam traversal, contents masks, and
translated patch models.

The graphical menu harness exercises walking and grounding across all three
games, pause, flight toggling, level changes, load failure, and quit. Grounded
Q2/Q3 captures were visually inspected. Screenshots and logs are ignored under
`.jac/screenshots/menu/`.

Rendering checks also pass on all 12 maps. All 24 comparisons of visibility
culling enabled versus disabled match exactly, across spawn and moved views.

## Remaining work

- Patch collision uses two-sided triangles from the fixed rendering tessellation,
  not Q3's original adaptive, directional facet rules; exact parity remains future work.
- Ordinary linked doors translate; supported touch triggers activate named doors. Other special doors, lifts, trains and
  buttons still need behavior. Rotation and riding movers are not implemented.
- Initial teleporters and jump pads now work: see [traversal status](traversal-status.md).
- Initial swimming now works: see [swimming status](swimming-status.md). Crouching, water ledge exits and further trigger actions remain.
- Per-game movement tuning, render interpolation and full-map traversal checks.
- Exact original-game movement fidelity is not claimed.
