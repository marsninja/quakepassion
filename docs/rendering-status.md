# Rendering status

What the renderer does on the GPU, what still goes through raylib's
immediate-mode batch, and where the picture differs from before.

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
