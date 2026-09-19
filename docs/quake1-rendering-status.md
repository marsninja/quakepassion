# Quake 1 level viewer: running and validated

The native viewer loads original Quake PAK archives and BSP29 maps. The default
is `~/quake-assets/id1`, map `e1m1`. Run `JAC_COMPILER_LIB=off jac build main.jac --native -o qp`, then
`./qp`. Use `QP_MAP=start ./qp` to change maps and `QP_ASSETS=/path/to/id1` to
change the asset directory.

## Implemented

- Checked BSP lump/record decoding, entities, polygon reconstruction, embedded
  textures, palette conversion, lightmap UVs, and compressed PVS decoding.
- BSP splits, front/back edges, and leaf nodes; `Locate` and `CollectFaces`
  walkers perform spatial queries and visible-face collection.
- Correct Quake-to-raylib triangle winding, texture repetition, static baked
  lightmaps with filtered atlas borders, and a separate fullbright pass.
- Static brush geometry at entity origins, excluding invisible trigger models.
  The world model's visibility leaf count excludes appended brush-model leaves.
- Static sky layers composited without exposing the foreground's black mask.
- Player-start positioning, free-flight controls, culling/debug toggles, and the
  existing graybox mode (`QP_GRAYBOX=1`).

## Validation

Validated locally on macOS arm64 with raylib 6.0 and the patched Jac 0.37.19 binary.

- Native build succeeds, and the viewer opens and closes normally.
- The unit tests pass, including BSP/entity/PVS parsing, spatial plane traversal,
  shared-face deduplication, and exclusion of appended brush leaves.
- Six real maps complete the graphical smoke sequence: `e1m1`, `start`, `e1m2`,
  `e2m1`, `e3m1`, and `e4m1`. All produce textured, nonblank images and visibly
  different views after turning and moving the camera.
- PVS comparisons use the same camera with culling enabled and disabled at both
  positions. All twelve pairs are pixel-identical in the latest Q2/Q3 regression run.
  The test permits at most 16 edge pixels out of 921,600. This checks culling consistency, not pixel parity with id's renderer.
- At the `e1m1` spawn, PVS reduces submitted front-facing polygons from 2,917 to
  399 while preserving the image exactly. Flight changes the BSP leaf from
  1141 to 1116; the moved view also matches exactly.

A later launch check found zero active macOS displays, preventing window
initialization for both launch methods. The viewer now reports that condition
before attempting GPU uploads. The successful graphical captures above were
completed while the display was active.

Reproduce with `python3 scripts/validate_quake.py` on an active desktop. Per-map images and logs live
in `.jac/screenshots/q1/<map>/`; those generated files are ignored by git. The
script also accepts explicit map names. Real assets are not needed by unit tests
and are never copied into the repository.

## Limits of this first version

This is a static level viewer with noclip movement, not a playable source port.
Doors and lifts remain at their initial positions. Models for monsters, pickups,
and weapons, collision/gameplay, animated textures and lightstyles, water warp,
and scrolling/projected sky layers remain unimplemented. Sky is a static
composite and lightstyle samples use a fixed contribution. Screenshots validate
representative views, not every viewpoint in every map. The atlas currently has
a fixed 2048-square capacity and reports an error if a map exceeds it.

Quake II BSP38 and Quake III BSP46/PK3 now also render; see
[their validation report](quake2-quake3-rendering-status.md).

## Compiler fixes

Two fixes used by the local binary are merged upstream:

- [Jac #9318](https://github.com/jaseci-labs/jac/pull/9318): native OSP visit
  coercion and ownership.
- [Jac #9321](https://github.com/jaseci-labs/jac/pull/9321): directory enumeration,
  whitespace splitting, and checked integer-to-bytearray assignment.

The current shared viewer additionally needs newer native ZIP and C-call fixes;
follow the source-staging instructions in [README](../README.md). The original
standalone reproductions are in `repros/`. No engine graph traversal was replaced
to avoid compiler defects.

Format references: id Software's original
[bspfile.h](https://github.com/id-Software/Quake/blob/master/WinQuake/bspfile.h)
and [gl_rsurf.c](https://github.com/id-Software/Quake/blob/master/WinQuake/gl_rsurf.c).
