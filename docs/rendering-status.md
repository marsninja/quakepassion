# Rendering status

What the renderer does on the GPU, what still goes through raylib's
immediate-mode batch, and where the picture differs from the immediate-mode
renderer it replaced. For models and effects, `QP_RENDER_LEGACY=1` switches
back to the old CPU and immediate-mode drawing for comparison; the world
has no such switch.

## World (BSP surfaces) — `engine/render/quake.jac`, `engine/render/world_mesh.jac`

### On the GPU

- **Static geometry.** At level load every drawable face of the world and
  of the brush models is packed once into vertex chunks of at most 65535
  vertices (84 bytes each: position, texture and lightmap coordinates,
  colour, normal, per-face flags, fog volume, light styles, autosprite
  data), sorted by surface batch (pass × texture) so a batch's faces share
  chunks.
- **Per frame** the CPU only gathers the prebuilt 16-bit index runs of the
  visible faces into one index buffer per chunk and batch, and only when the
  visible set changes (`Level.visible` keeps a few recent sets, so the main
  view and a portal view both keep theirs). Each batch then draws with one
  call per chunk. No per-vertex work or FFI call remains per frame.
- **Brush models** (doors, plats, trains, rotators, turrets) draw from the
  same chunks through their own index buffer, grouped by placement: models
  at rest together, each moved model with a model matrix (turn about its
  pivot, then its motion). Groups are rebuilt only when a model starts or
  stops moving or a face is hidden or shown.
- **Q1/Q2 lightmapped surfaces**: one pass — texture × lightmap light
  styles × 2 (clamped), plus up to eight dynamic lights per pixel, and Q1
  palette fullbrights (marked by texture alpha) left unlit. Each light style
  layer of a face sits side by side in the atlas, raw; the shader scales
  each by its style's current value, so flickering and switched lights no
  longer re-upload the atlas (`animate_styles` only updates the values).
- **Liquids and Q2 translucent surfaces**: the EmitWaterPolys turbulence
  and SURF_FLOWING scroll in the fragment shader.
- **Q1 sky**: both layers in one pass, the flattened-sphere mapping per
  vertex in the vertex shader.
- **Q3 surfaces**: single-pass lightmap/vertex light with alphaFunc and
  dynamic lights; additive shaders; layered shaders stage by stage with
  tcGen (base, lightmap, environment, vector), tcMods (scroll, scale,
  rotate, stretch, transform folded into affine steps, turb between them),
  rgbGen/alphaGen (identity, wave, const, vertex, portal, lightingSpecular),
  deformVertexes (wave, move, bulge, autosprite, autosprite2) and the
  translucent stages' fog adjustment, all in the vertex shader, one draw per
  stage and chunk. Each stage's GL state and time-independent uniforms are
  planned at level load; uniforms are only set when they change.
- **Q3 fog pass** (RB_FogPass) and **cloud layers** (the dome is a vertex
  chunk; the stage shader applies the layer's tcMods).

### Still through raylib's batch

- The Q2/Q3 sky box (six quads) and Q3 portal backdrops (the view through a
  portal or mirror, a few faces) — both rare and cheap.

### Differences from the immediate-mode renderer

Screenshots of every default benchmark map and of the smoke scripts'
views (portals, fog, movers, light styles, shader stages) match the old
renderer pixel for pixel at the same moment (`QP_BENCH_DT`), except:

- **Two-sided fog surfaces** (a fog volume's surface seen from inside it)
  now fade with distance as RB_FogPass does. Before, a batch flush between
  the one-sided and two-sided fog groups dropped the fog image, so they drew
  solid fog colour.
- **Environment-mapped and specular stages on moving brush models** reflect
  from where the model is now; before they used its rest position with the
  current eye.

### Measured

`scripts/render_benchmark.jac`, old and new renderer run back to back twice
on the same machine (macOS arm64); world stage median ms and frame rate:

| map | world ms before → after | fps before → after |
|---|---|---|
| q1 e1m1 | 0.32 → 0.08 | 894–909 → 1351–1361 |
| q1 e4m7 | 0.36 → 0.06 | 256–312 → 375–380 |
| q2 base1 | 0.94 → 0.20 | 296 → 429–470 |
| q2 bunk1 | 1.48 → 0.45 | 201–213 → 285–286 |
| q2 train | 1.63 → 0.37 | 158–166 → 244 |
| q3 q3dm1 | 1.16 → 0.15 | 255–266 → 481–498 |
| q3 q3dm7 | 1.51 → 0.20 | 130 → 165–168 |
| q3 q3dm11 | 2.16 → 0.36 | 125–130 → 171–172 |
| q3 q3dm12 | 4.43 → 0.43 | 68–71 → 129 |
| q3 q3tourney2 | 1.41 → 0.12 | 222–226 → 471 |

The world stage includes starting the frame (clearing the screen). What
remains is mostly one texture bind and draw call per visible batch (Q2 maps
have many textures) and the brush groups' placements.

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
