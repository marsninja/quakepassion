# Rendering status

What the renderer does on the GPU, what still runs on the CPU, and any
visual differences from the immediate-mode renderer it replaced.
`QP_RENDER_LEGACY=1` switches the moved paths back to the old CPU and
immediate-mode drawing for comparison.

## Models (Q1 MDL, Q2 MD2, Q3 MD3)

`engine/render/models.jac` (`ModelRenderer`, `ModelScene`).

On the GPU:

- **Keyframes.** At upload every surface's frames go into one RGBA32F
  texture per model: position in xyz and the vertex normal packed into w
  (octahedral, 12 bits per axis; -1 for formats without normals, i.e. Q1 MDL
  and Q2 MD2, which keep the flat `ambient + directed / 2` shade). Surface s,
  frame f, vertex v sits at texel `base[s] + f * vertices[s] + v`, in rows of
  4096 texels, so no surface or frame count hits `GL_MAX_TEXTURE_SIZE`.
- **Corners.** Every triangle corner is a static vertex record (its frame-0
  texel, the surface's vertices per frame, texture coordinates) in the
  immediate path's winding. Draws are non-indexed, so there is no 16-bit
  index limit.
- **Per draw** the CPU sends one `vec4[8]` uniform (placement axes and
  origin, the two frames and blend, shell inflate, ambient / directed light
  and direction, opacity, the eye in model space) and one `vec4` per stage
  (scroll offset, environment mapping, colour mode). The vertex shader lerps
  position and normal, pushes powerup shells out along the normal, computes
  environment-mapped texture coordinates, the light grid (or Q1/Q2) colour and
  Q3 fog texture coordinates (RB_FogPass). The fragment shader is skin times
  colour, as raylib's default shader was.
- **Passes.** `ModelScene.draw` and the view weapon open one model pass (one
  program bind and view-projection) for all their draws; other callers
  (effects, HUD icons) get a pass per draw automatically.
- **Covered:** world entities through `ModelScene` (monsters, items, gibs,
  corpses, Q3 bots' lower/upper/head, weapons, barrels and flashes on tags),
  portal views, the view weapon with its barrel, flash and powerup shells,
  the Q3 3D status bar icons and scoreboard heads, and effect models
  (`effects.jac` calls the same `ModelRenderer.draw`).

Still on the CPU, per draw: gathering visible models (`GatherModels`, now over
an area list made once per level instead of every leaf edge), MD3 tag
attachment transforms (`lerp_tag`, `Placement.on_tag`), bounding-sphere
culling, light grid / light probe sampling, and fog volume selection.

Not instanced: repeated items still cost one small uniform upload and one draw
per surface stage each; after the move the draw loop is 0.05-0.3 ms a frame on
the benchmark maps, so instancing was left out.

## Plain projectiles

`engine/render/cubes.jac` (`CubeBatch`), used by `Renderer.draw_projectiles`.
Projectiles without an effect model are instanced unit cubes (one record per
cube: centre, edge, RGBA) instead of raylib `DrawCube` calls. Impact and
explosion particles are drawn by the effect scene (below). Shot trails, beams and electrode lightning stay raylib lines, and the
placeholder boxes `Renderer.draw_opponents` draws for opponents without a
model stay immediate mode (only used when a monster's model is missing).

## Visual differences

- Models: none seen. GPU and legacy pictures from the same scene differ in
  under 0.01% of pixels (`scripts/model_gpu_smoke.jac`, the bot, monster, gib,
  pickup, view weapon and HUD icon smokes). Lighting colours are no longer
  quantised to bytes per vertex before interpolation, and normals are
  quantised to 12 bits per axis.
- Q3 status bar head: after a level change the head no longer swells across
  the view for its first seconds (a hit remembered from the previous level's
  clock counted as one from the future). The old renderer's benchmark
  screenshots show it (e.g. `bench_q3tourney2_0`). The head still kicks as
  the spawn health counts down from 125, which the original only does for
  real damage (`cg.damageTime`).

## Effects (engine/render/effects.jac)

Sprites, explosion sprites, rail and lightning ribbons, rail rings, Q2 rail
specks, Q3 wall marks and impact/explosion particles are instances of one
unit quad. Per frame the CPU packs a 76-byte record per quad (centre, two
axes, extent, texture rectangle, RGBA tint, texture spin) with
`struct.pack_into`; the vertex shader places the corners. A record with zero
axes is a billboard: the shader faces it along the camera's right and up
vectors. Marks carry their wall axes, ribbons their length and eye-facing
width.

- Quads are queued in the old draw order and drawn with one instanced draw per
  run of equal texture and blend (alpha, additive, or the marks' darkening
  `GL_ZERO, GL_ONE_MINUS_SRC_COLOR`). Blasts and missile sprites are still
  sorted back to front.
- GL 3.3 has no base instance, so each run re-points the instance attributes
  at its first record. Instance buffers rotate through 16 meshes so a frame
  never rewrites a buffer the GPU may still be reading (rlgl buffer updates
  wait for the GPU); each grows by doubling when a frame needs more.
- State as before: sprites, ribbons and marks test depth without writing it
  and draw both sides; particles also write depth, as the cubes did.
- `GatherEffects` walks the world's effect edges once per draw and collects
  particles, marks, trails, explosions and missiles.
- Particles moved from `Renderer.draw_projectiles` into
  `EffectScene.draw_particles`, so they are timed in the effects stage now,
  not the models stage. Unstyled line trails, fallback missile cubes and
  Chthon's lightning stay in `draw_projectiles`.

Unchanged: effects drawn as models (Q1 lightning bolts, Q2 explosions and
blaster bolts, missile models) go through `ModelRenderer`.

Visual differences: particles are camera-facing squares 1.2 times their old
cube's edge rather than cubes, so they no longer show a cube's changing
silhouette when seen edge-on. Everything else draws the same pixels (compared
with `scripts/effects_gallery.jac` and the benchmark's combat views).

Measure with `QP_BENCH_COMBAT=1` on `scripts/render_benchmark.jac`, which
keeps explosions, trails, sprays, marks and missiles in view. Compare the
models and effects stages together against older builds, since particles
changed stage.
