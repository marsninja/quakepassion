# Rendering status

What the renderer does on the GPU, what still goes through raylib's
immediate-mode batch, and where the picture differs from the immediate-mode
renderer it replaced. For models and effects, `QP_RENDER_LEGACY=1` switches
back to the old CPU and immediate-mode drawing for comparison; the world
has no such switch.

## All together

`scripts/render_benchmark.jac` on the default maps, the immediate-mode
renderer against the GPU renderer (world, models and effects together with
the Q3 frame-spike fixes), run back to back twice on the same machine
(macOS arm64, free-running, 600 frames turning a full circle). Frame rate at
the median frame, mean speed-up, and median / 95th percentile frame ms:

| map | fps before → after | speed-up | median ms | p95 ms |
|---|---|---|---|---|
| q1 e1m1 | 858–913 → 1832–1852 | 2.1× | 1.14 → 0.55 | 2.9 → 1.3 |
| q1 e4m7 | 307–311 → 1072–1078 | 3.5× | 3.23 → 0.93 | 7.7 → 4.9 |
| q2 base1 | 284–299 → 1129–1145 | 3.9× | 3.43 → 0.88 | 5.8 → 2.0 |
| q2 bunk1 | 200–207 → 617–630 | 3.1× | 4.92 → 1.60 | 11.7 → 3.7 |
| q2 train | 160–168 → 771–775 | 4.7× | 6.11 → 1.29 | 8.9 → 4.5 |
| q3 q3dm1 | 268–275 → 1264–1279 | 4.7× | 3.69 → 0.79 | 4.8 → 1.3 |
| q3 q3dm7 | 130–132 → 848–864 | 6.5× | 7.64 → 1.17 | 13.1 → 2.6 |
| q3 q3dm11 | 130–131 → 715–741 | 5.6× | 7.67 → 1.38 | 18.3 → 3.3 |
| q3 q3dm12 | 71 → 668–696 | 9.6× | 14.12 → 1.47 | 19.5 → 4.1 |
| q3 q3tourney2 | 221–228 → 1193–1218 | 5.4× | 4.46 → 0.83 | 5.8 → 1.4 |

With `QP_BENCH_COMBAT=1` (explosions, trails, sprays, marks and missiles in
view), same conditions:

| map | fps before → after | speed-up | median ms | p95 ms |
|---|---|---|---|---|
| q1 e1m1 | 268–270 → 799–803 | 3.0× | 3.71 → 1.25 | 6.4 → 2.6 |
| q1 e4m7 | 120–121 → 418–525 | 3.9× | 8.29 → 2.15 | 14.1 → 7.7 |
| q2 base1 | 134 → 496–504 | 3.7× | 7.46 → 2.00 | 10.6 → 4.1 |
| q2 bunk1 | 111 → 385–392 | 3.5× | 9.02 → 2.58 | 15.8 → 5.3 |
| q2 train | 94–98 → 469–472 | 4.9× | 10.46 → 2.12 | 14.6 → 5.8 |
| q3 q3dm1 | 166–167 → 610–620 | 3.7× | 6.00 → 1.62 | 7.7 → 2.9 |
| q3 q3dm7 | 94–95 → 458–467 | 4.9× | 10.54 → 2.16 | 17.5 → 5.9 |
| q3 q3dm11 | 81–84 → 401–402 | 4.9× | 12.12 → 2.49 | 22.0 → 6.5 |
| q3 q3dm12 | 57–59 → 384–412 | 6.9× | 17.30 → 2.52 | 26.1 → 6.5 |
| q3 q3tourney2 | 134 → 542–543 | 4.1× | 7.48 → 1.85 | 8.6 → 4.2 |

On q3dm12 the render stages went from about 9.3 ms to 1.3 ms a frame (world
4.4 → 0.4, models 3.6 → 0.5). The rest of the frame (game logic, bots,
anything outside the timed stages) shrank on every map too, from about
4.8 ms to 0.2 ms on q3dm12 and 2.8 ms to 0.1 ms on q2 train; in Q3 the bot
travel-table and sight changes are part of that, so not all of the gain is
rendering.

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
