# Models

Q1 MDL, Q2 MD2 and Q3 MD3 models load into one set of vertex-animation records
and draw through one GPU model renderer. Monsters, items, gibs, corpses, Q3
bots and view weapons animate between keyframes, move smoothly between physics
ticks, and are lit by each game's own rule: Q1 and Q2 from the lightmaps below
them (`R_LightPoint`), Q3 from the light grid, Passion from light probes, plus
the frame's dynamic lights.

## Formats

`engine/formats/animated.jac` holds the shared records (`AnimatedModel`,
`AnimatedSurface`, `AnimationFrame`, `AnimationGroup`, `ModelTag`).

- **MDL** (`engine/formats/q1/model.jac`, version 6): paletted skins with
  fullbright texels, grouped skins and frames with their intervals, seam
  texture coordinates, and each vertex's `lightnormalindex`.
- **MD2** (`engine/formats/q2/model.jac`): separate vertex and texture-coordinate
  indices, PCX skins (`parse_pcx`), `lightnormalindex` normals.
- **MD3** (`engine/formats/q3/model.jac`): several surfaces with their shader
  names, signed compressed positions, encoded normals, and per-frame tags
  (including tag-only weapon models).
- **Q1 brush pickups** (`engine/formats/q1/item_model.jac`): health and ammo
  boxes are small BSPs lit by their own baked lightmaps (`R_DrawBrushModel`),
  adapted to the same renderer.
- `engine/assets/library.jac` `AssetLibrary.model` loads a model and its skins
  from the archives; Q3 model shaders come from `Pk3Assets.model_stages`.

## Scene and animation

- A world entity draws through a `Visual` node linked to a shared
  `ModelResource` (`HasVisual`, `UsesModel`, `engine/world/models.jac`). The
  `GatherModels` walker visits only the areas that hold entities and produces
  one `ModelDraw` per part and powerup shell; items spin and bob on the shared
  world clock.
- Each `Visual` names two frames and a blend. Monsters step through their
  frames at 10 Hz and blend by the fraction of the current frame; Q3 bodies use
  `cg_players.c`'s `lerpFrame_t` per legs and torso, with the torso and head
  placed on the lower parts' tags by `lerp_tag` (`R_LerpTag`). Q3 bodies are
  covered in [Q3 player bodies](player-bodies-status.md), view weapons in
  [view weapons](viewweapons-status.md).
- Placement is interpolated between the last two 120 Hz physics ticks
  (`TickBlend`, `Clock.alpha`; see
  [rendering](rendering-status.md#render-interpolation)).
- Drawing (`engine/render/models.jac`): keyframes live in one float texture
  per model and the vertex shader lerps position and normal; see
  [rendering](rendering-status.md#models).

## Lighting

`engine/world/lighting.jac` `Lighting.light_model` returns an `Illumination`
(ambient, directed light, direction, rear factor):

- **Q1** (`R_AliasSetupLighting`): `TraceLightPoint` finds the lightmap sample
  on the first lit surface straight below (`RecursiveLightPoint`), each style
  layer scaled by its current value. Each dynamic light adds its radius less
  its distance to the ambient light; ambient is held to 128 and ambient plus
  shade to 192. The view weapon gets at least 24.
- **Q2** (`R_DrawAliasModel`): the coloured lightmap light below plus dynamic
  lights, times `shadedots` for the model's yaw in sixteenths of a turn.
  `RF_FULLBRIGHT`, `RF_MINLIGHT` and `RF_GLOW` (bonus items pulse) apply.
- **Q3**: the light grid (`R_LoadLightGrid`), with dynamic lights adding
  directed light toward themselves.
- Results are cached per origin, flags and yaw row until the light styles or
  dynamic lights change; traces are cached per point.
- Q2 monsters below half health show their bloodied skin
  (`tests/monster_skin_tests.jac`).

## Validation

- Archive checks (native, 2026-09-20):

  | Format | Models | Frames | Additional checks |
  |---|---:|---:|---|
  | Q1 MDL | 79 | 1,746 | Embedded paletted skins and groups |
  | Q2 MD2 | 119 | 5,671 | 154 referenced PCX skins |
  | Q3 MD3 | 372 | 26,732 | Surfaces and attachment tags |

  `scripts/validate_models.jac` checks every Q2 MD2 and referenced skin;
  `scripts/validate_alias_models.jac` checks Q1 and Q3.
- Tests: `model_tests` (MD2, PCX), `phase3_formats_tests`,
  `model_gpu_tests` (keyframe texture and normal packing),
  `model_lighting_tests` (`R_LightPoint`, the Q1 and Q2 shading rules, anorms
  normals, fullbright skins, baked brush pickups), `model_material_tests`
  (model shader stages), `visual_tests` (`GatherModels`),
  `render_interpolation_tests`, `monster_skin_tests`.
- Native captures: `scripts/models_smoke.jac` and
  `scripts/alias_models_smoke.jac` (Q2 soldier and berserker, Q1 soldier and
  shambler, Q3 red armor's stages in two time-separated captures that must
  differ),
  `scripts/model_scene_smoke.jac` (two actors sharing GPU resources),
  `scripts/model_gpu_smoke.jac` (GPU against the legacy CPU path).
- `scripts/profile_model_lighting.jac` measures the lighting cost (see
  [performance](performance-status.md)).

## Limitations

- Q3 model shaders draw their stages only when every stage feature is one the
  model renderer handles (tcMods, `tcGen environment`, `animMap`, the standard
  blends, `rgbGen`/`alphaGen` wave and const, `clampMap`). A shader that also
  uses, for example, `rgbGen lightingDiffuse`, `alphaFunc`, a custom
  `blendFunc` or `depthWrite` draws its plain skin; one with directives the
  parser does not know prints "Partial model material" and does the same
  (`Pk3Assets.model_stages`).
- Q1 model frames blend between keyframes, where Quake's own renderers showed
  each keyframe as is (Q2 lerps frames as here).
- Repeated models are not instanced.
