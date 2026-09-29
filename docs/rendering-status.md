# Rendering

The engine loads each game's own level format (Q1 BSP29, Q2 BSP38, Q3 BSP46)
from the original archives and draws it with one GPU renderer: the world from
static vertex chunks, models animated in a vertex shader, and effects as
instanced quads. Frames draw moving bodies between their last two physics
ticks. Each game's shading (light styles, liquid warp, skies, Q3 shader stages
and fog) is described in [presentation](presentation-status.md); model formats
and lighting in [models](models-status.md).

`QP_RENDER_LEGACY=1` switches models and plain projectile cubes back to CPU
posing and raylib immediate mode for comparison. The world and effects have no
such switch.

## Per-game level loading

`engine/world/level.jac` `load_level` reads a map through the game's archives
and builds the level graph.

- **Archives.** `engine/assets/pak.jac` reads PAK directories with
  case-insensitive lookup (`base2` mixes cases in texture names); later paks
  override earlier ones. `engine/assets/library.jac` `AssetLibrary` then looks
  for loose files in the game directory, as `FS_FOpenFile` does (Q2 keeps
  `video/` and `music/` there). `engine/assets/pk3.jac` opens Q3 PK3s in name
  order, later archives overriding earlier ones, and parses every shader
  script (`engine/assets/materials.jac`).
- **Quake (BSP29, `engine/formats/q1/bsp.jac`).** Embedded miptex textures
  through `gfx/palette.lmp`, with fullbright palette entries marked in the
  texture alpha; mono lightmaps with up to four light styles; `+0`..`+9`
  animated textures and their `+a`..`+j` alternates (`R_TextureAnimation`);
  compressed per-leaf PVS. The world model's leaf count excludes the leaves
  appended for brush models. Brush-model BSPs without a player start are not
  listed as levels (`engine/core/menu.jac` `is_q1_level`).
- **Quake II (BSP38, `engine/formats/q2/bsp.jac`).** WAL textures through
  `pics/colormap.pcx`; RGB lightmaps with light styles; texinfo flags
  (`SURF_WARP`, `SURF_FLOWING`, `SURF_TRANS33/66`, `SURF_SKY`) and
  `nexttexinfo` animation chains; cluster PVS; six-image sky boxes from
  `env/<sky><side>.tga`, turned by the worldspawn's `skyrotate` and `skyaxis`.
  Brush models whose head is a leaf (negative index) load.
- **Quake III (BSP46, `engine/formats/q3/bsp.jac`).** JPG and TGA images
  decoded by raylib (built with both decoders by `scripts/stage_raylib.sh`;
  the prebuilt raylib has neither); 128×128 RGB lightmaps with the overbright
  shift; planar surfaces, triangle soups and quadratic patches (tessellated at
  eight steps per quadratic piece for drawing; collision uses cm_patch's
  adaptive facets, `engine/physics/patch_collide.jac`); the light grid for
  models; cluster PVS; fog volumes. Flare surfaces are skipped.
- **The BSP graph.** Every game's tree becomes `Split` and `BspArea` (leaf)
  nodes joined by `Front`/`Back` edges. `Locate` walks to the eye's leaf and
  `CollectFaces` gathers the faces of the visible leaves.

## Visibility

- `Level.visible` decodes the PVS (Q1 leaves, Q2/Q3 clusters, including
  cluster 0 and leaf 0) and collects the visible faces. Sets are cached per
  leaf, and three recent sets are kept so a portal view and the main view each
  keep theirs. Brush-model faces are always included and use live transforms.
- `r_novis 1` (Settings: Visibility culling Off) draws every face and model.
- Models are gathered from the areas that hold entities (`GatherModels`,
  `engine/world/models.jac`) and culled by a bounding sphere covering every
  frame (`sphere_in_view`, `engine/render/models.jac`).

## World surfaces

`engine/render/quake.jac`, `engine/render/world_mesh.jac`.

- **Static geometry.** At level load every drawable face of the world and the
  brush models is packed once into vertex chunks of at most 65535 vertices
  (84 bytes each: position, texture and lightmap coordinates, colour, normal,
  per-face flags, fog volume, light styles, autosprite data), sorted by surface
  batch (pass × texture).
- **Per frame** the CPU only concatenates the prebuilt 16-bit index runs of the
  visible faces per chunk and batch, and only when the visible set changes.
  Each batch draws with one call per chunk.
- **Brush models** (doors, plats, trains, rotators, turrets) draw from the same
  chunks through their own index buffer, grouped by placement: models at rest
  together, each moving model with a model matrix. Groups rebuild only when a
  model starts or stops moving or a face is hidden or shown.
- **Q1/Q2 lightmapped surfaces**: one pass of texture × light-style layers.
  Each layer is stored raw in the atlas and scaled in the shader by its
  style's current value, so animating styles uploads only the values. Up to
  eight dynamic lights per pixel use the originals' octagonal distance. Q1
  fullbrights stay unlit.
- **Liquids and Q2 translucent surfaces**: `EmitWaterPolys` turbulence and
  `SURF_FLOWING` scroll in the fragment shader.
- **Q1 sky**: both layers in one pass, the flattened-sphere mapping per vertex.
- **Q3 surfaces**: single-pass lightmap or vertex light with alphaFunc and
  dynamic lights; multi-stage shaders draw stage by stage with tcGen, tcMods,
  rgbGen/alphaGen, deformVertexes and the translucent stages' fog adjustment in
  the vertex shader. Each stage's GL state and time-independent uniforms are
  planned at level load.
- **Q3 fog pass** (`RB_FogPass`) and **cloud layers** (the sky dome is a vertex
  chunk; the stage shader applies the layer's tcMods). Two-sided fog surfaces
  seen from inside fade with distance as `RB_FogPass` does.
- **Still through raylib's rlgl batch**: the Q2/Q3 sky box (six quads) and Q3
  portal backdrops (the portal view shown on its surface).

## Models

`engine/render/models.jac` (`ModelRenderer`, `ModelScene`).

- **Keyframes.** At upload every surface's frames go into one RGBA32F texture
  per model: position in xyz and the vertex normal in w (octahedral, 12 bits
  per axis). MD3 frames carry normals; Q1 MDL and Q2 MD2 vertices index the
  162 `anorms.h` normals. Texels run in rows of 4096, so no frame count hits
  `GL_MAX_TEXTURE_SIZE`.
- **Corners** are static, non-indexed vertex records (frame-0 texel, vertices
  per frame, texture coordinates), so there is no 16-bit index limit.
- **Per draw** the CPU sends one `vec4[8]` uniform (placement, the two frames
  and blend, shell inflate, ambient and directed light, direction and rear
  factor, opacity, the eye in model space) and one `vec4` per stage. The
  vertex shader lerps position and normal, pushes powerup shells out along the
  normal, computes environment-mapped coordinates, the light (Q1/Q2 shade from
  the lightmaps, Q3 light grid, the RF_GLOW pulse) and Q3 fog coordinates.
- **Passes.** `ModelScene.draw` and the view weapon open one model pass for
  all their draws; other callers (effects, HUD icons) get one per draw.
- Covered: monsters, items, gibs, corpses, Q3 bots' legs, torso and head with
  weapons, barrels and flashes on tags, portal views, the view weapon with its
  powerup shells, the Q3 3D status-bar icons and scoreboard heads, and effect
  models.
- On the CPU per draw: gathering, MD3 tag transforms (`lerp_tag`), sphere
  culling, lighting (`Lighting.light_model`) and fog volume selection.

## Effects

`engine/render/effects.jac`, `engine/render/particles.jac`,
`engine/render/polygons.jac`, `engine/render/cubes.jac`.

- **Quads.** Sprites, explosion sprites, rail and lightning ribbons, rail
  rings and talk balloons are instances of one unit quad: a 76-byte record
  each (centre, axes, extent, texture rectangle, tint, spin), packed per frame.
  A record without axes is a camera-facing billboard. Runs of equal texture
  and blend draw with one instanced draw; instance buffers rotate through 16
  meshes so a frame never rewrites one the GPU may still be reading.
- **Q1/Q2 particles** (`ParticleRing`) are uploaded once when spawned; the
  vertex shader computes position, colour and fade from the same closed forms
  as `particle_state`. Q1 draws `D_DrawParticle`'s solid squares, Q2
  `GL_DrawParticles`' round dot; Q3 and Passion sparks are plain squares.
  Missile and gib trails are laid each frame up to where the frame draws the
  missile (`EmitTrails`, `engine/world/missile_trails.jac`).
- **Q3 wall marks** are polygons cut to the faces they lie on
  (`R_MarkFragments`) and drawn through `ScenePolygons` (`RE_AddPolyToScene`),
  darkening or alpha-blended by mark type.
- **Plain projectiles** without an effect model are instanced cubes
  (`CubeBatch`). Trails and beams without an effect style fall back to raylib
  lines, and `Renderer.draw_opponents` draws placeholder boxes for a monster
  whose model is missing.
- Effects drawn as models (Q1 lightning bolts, Q2 explosions and blaster bolts,
  missile models) go through `ModelRenderer`.

## Render interpolation

Physics ticks at 120 Hz. Each moving body keeps its pose at the start of the
tick in progress (`TickPose`, captured by `CaptureMotion`), and a frame draws
it `Clock.alpha` of the way to where the tick left it (`TickBlend`,
`engine/math/interpolation.jac`), one tick behind, as Q1 `CL_RelinkEntities`,
Q2 `CL_AddPacketEntities` and Q3 `CG_InterpolateEntityPosition` do. A move of
more than 100 units in one tick is a teleport and is not interpolated. Brush
models, missiles, trails, dynamic lights and the player's view use the same
blend.

## Measured (2026-09-27)

`scripts/render_benchmark.jac` on macOS arm64, free-running, 600 frames turning
a full circle; the former immediate-mode renderer against the GPU renderer, run
back to back twice. Frame rate at the median frame, mean speed-up, median and
95th percentile frame ms:

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
view):

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
4.4 → 0.4, models 3.6 → 0.5). The rest of the frame also shrank (4.8 → 0.2 ms
on q3dm12), partly from Q3 bot travel-table and sight changes. These runs
predate Q1/Q2 model lighting and the native cycle-collector fix; see
[performance](performance-status.md).

Benchmark options: `QP_BENCH_MAPS`, `QP_BENCH_FRAMES`, `QP_BENCH_SHOTS=1`
(four views per map saved as `bench_<map>_<n>.png`), `QP_BENCH_DT` (a fixed
time step, so two renderers show the same moment) and `QP_BENCH_COMBAT=1`.

## Validation

- `jac run scripts/validate_quake.jac --game q1|q2|q3 [maps]` runs the native
  `qp` with `QP_SMOKE=1` on each map (defaults: Q1 e1m1, start, e1m2, e2m1,
  e3m1, e4m1; Q2 base1-3; Q3 q3dm1, q3dm7, q3tourney2). Each map yields five
  non-blank captures (PVS on and off at the spawn, a turn, PVS on and off after
  moving) in `.jac/screenshots/<game>/<map>/`. PVS on/off pairs may differ in
  at most 16 pixels; the turn and the move must change the image. This checks
  culling consistency, not pixel parity with id's renderers.
- `scripts/map_sweep.jac` loads, simulates and renders every original map
  (see [validation tooling](validation-tooling-status.md)).
- Tests: `phase2_bsp_tests` and `phase2_level_tests` (BSP bounds, PVS, leaf
  counts), `phase2_pak_tests`, `phase3_formats_tests` (WAL bounds, patch
  geometry and winding, cluster 0 visibility), `world_mesh_tests` (vertex
  packing, batches, index runs), `render_culling_tests`, `model_gpu_tests`,
  `effect_quads_tests`, `lightfx_render_tests` (Q2 sky rotation, particle
  records), `render_interpolation_tests`, `fog_tests`, `portal_tests`.
- Native comparisons: `scripts/model_gpu_smoke.jac` draws the same scene
  through the GPU and legacy model paths (they differ in under 0.01% of
  pixels); `scripts/gpu_smoke.jac` exercises `engine/render/gpu.jac`;
  `scripts/effects_gallery.jac` poses every effect kind per game;
  `scripts/fog_smoke.jac` and `scripts/portal_smoke.jac` render fog volumes and
  every portal shader.

## Limitations

- Only the PVS culls world faces. Q2/Q3 area portals
  (`engine/world/area_portals.jac`) gate sound but not drawing, so faces
  behind a closed areaportal door are still drawn.
- Patches draw at a fixed eight steps per quadratic piece (no LOD).
- The lightmap atlas is a fixed 2048×2048; a map that overflows it fails to
  load ("Lightmap atlas capacity exceeded"). Every original map fits.
- Q3 shaders: flare surfaces are not drawn; `deformVertexes normal` is parsed
  and ignored; directives the parser does not know are recorded in
  `material.unsupported` and skipped.
- The world shader holds 16 fog volumes (`WORLD_FOG_LIMIT`); faces in a
  later volume draw unfogged.
- The sky box and Q3 portal backdrops still use raylib's immediate batch.
- Repeated models are not instanced (the model draw loop costs 0.05-0.3 ms a
  frame on the benchmark maps).
