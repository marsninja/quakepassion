# Animated model foundation

MDL, MD2 and MD3 adapters feed shared vertex-animation records and one model
renderer. MDL retains grouped skin/frame intervals and handles seam UVs. MD2
retains separate vertex/UV indices and decodes PCX skins. MD3 retains multiple
surfaces, shader names, signed compressed positions and per-frame attachment
tags, including valid tag-only weapon models.

Native archive validation passed:

| Format | Models | Frames | Additional checks |
|---|---:|---:|---|
| Q1 MDL | 79 | 1,746 | Embedded paletted skins and groups |
| Q2 MD2 | 119 | 5,671 | 154 referenced PCX skins |
| Q3 MD3 | 372 | 26,732 | Surfaces and attachment tags |

`scripts/validate_models.jac` checks Q2. `scripts/validate_alias_models.jac`
checks Q1/Q3. Synthetic fixtures cover interpolation, texture seams, compressed
signed coordinates, groups, tags, truncated tables and malformed PCX runs.

Native desktop captures from `scripts/models_smoke.jac` and
`scripts/alias_models_smoke.jac` show Q1 soldier/shambler and Q2 soldier/berserker
skins and geometry. Q3 armor now renders its ordered shader stages, including
environment-mapped reflection, the alpha overlay and scrolling additive energy.
MD3 normals are decoded and interpolated for view-dependent environment UVs.
This is initial model material support, not full Q3 material parity: unsupported
directives are reported, and their materials retain the static fallback.

Graph visual components and shared GPU resources pass a two-actor native scene
check (`scripts/model_scene_smoke.jac`). Health, armor and shell models are now
instantiated by the normal level loop through the shared asset library and visual
graph. Q1 brush-format item models also feed the common model renderer. Character
binding, animation selection, attachment composition, model lighting, full material passes,
weapons and monster behavior remain. GPU resources are explicitly released by
the shared model renderer.

The new time-separated PNG comparison in `scripts/alias_models_smoke.jac` is
blocked by [native Path.read_bytes](native-path-read-bytes-blocker.md). The captures
described above were produced before that comparison import was added; the new
comparison has not run. The main executable still builds.
