# Rendering status: what runs on the GPU

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
