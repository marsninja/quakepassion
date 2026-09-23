# Presentation

The three games now draw their own status bars, animated lighting, skies,
liquids and Q3 shader surfaces, following each original renderer.

## Status bars

`engine/render/hud.jac` draws each game's original status bar from its own art,
scaled up by a whole factor and centred on its virtual screen. `games/hud_art.jac`
loads the art.

- **Quake:** `sbar.c`'s status bar and inventory bar from `gfx.wad`.
  - Big digits: `num_*`, switching to the red `anum_*` set at 25 health or armor
    and at 10 ammo.
  - The armor icon matching the armor's strength.
  - Faces by health band, with pain frames and the quad, invisibility and
    invulnerability faces (invulnerability shows 666 armor).
  - The ammo icon.
  - Owned and selected weapons.
  - All four ammo counts in the small `conchars` digits.
  - Keys, powerups and sigils.

  `engine/formats/q1/wad.jac` reads WAD2 and qpic lumps.
- **Quake II:** the single-player statusbar layout from `g_spawn.c`.
  - Health, ammo and armor fields in `num_`/`anum_` digits, flashing when low.
  - The health, ammo and armor icons.
  - The held weapon's icon.
  - The seconds left on a running powerup, with its icon.
- **Quake III:** `cg_draw.c`'s status bar with 2D icons (`cg_draw3dIcons 0`).
  - Ammo, health and armor in the 32×48 digits: orange, red and flashing when
    health is low, white over 100, grey while firing.
  - The ammo icon, the player's head icon and the armor icon.
  - The default crosshair.

The text status line remains for Passion levels and whenever art is missing.

## Light styles

Q1 and Q2 lightmaps keep one layer per light style.

- The fixed styles (flicker, pulses, candles, strobes, fluorescent) play at
  10 Hz. Only the lightmaps of faces that use them are relit (`R_AnimateLight`,
  `R_BuildLightMap`).
- Targetable lights (styles 32–62) become `LightSwitch` nodes in the signal
  graph. They start dark when flagged `START_OFF` and toggle when triggered, as
  `light_use` does.
- e1m1 and base1 each relight hundreds of faces.

## Skies

- Quake's sky textures split into their solid back layer and masked front
  layer. Each is mapped by view direction onto the flattened sky dome and
  scrolled at the original speeds (`EmitSkyPolys`). Clear texels take the back
  layer's average colour, as `R_InitSky` does, so no fringe shows.
- Q2 keeps its sky boxes.
- Q3 reads each sky shader's `skyParms`: the far-box images, and the cloud
  layers drawn on the sky dome.
  - Each dome direction meets a cloud sphere `cloudheight` above a 4096-unit
    world, and the texture coordinates are the arccosines of that direction, as
    `tr_sky.c` computes them.
  - The stage's `tcMod`s, blends and colour waves then apply.
  - `SURF_SKY` faces open onto the sky rather than drawing a texture.
  - q3dm1's red hell sky and q3dm7's toxic clouds drift as in the original.

## Liquids and translucency

- Q1 `*` textures and Q2 `SURF_WARP` surfaces sway with `EmitWaterPolys`'
  turbulence, computed per pixel.
- Q2 `SURF_FLOWING` surfaces scroll.
- `SURF_TRANS33` and `SURF_TRANS66` faces blend over the world unlit.

## Fog

Q3 fog volumes draw as `tr_shade.c` does:
- Each surface's fog number comes from the BSP. A volume's bounds and visible
  side come from its fog brush, and its colour and `distanceToOpaque` come from
  its shader's `fogParms`.
- Opaque surfaces inside a volume, and the fog shaders' own surfaces, take a fog
  pass. The pass blends the fog colour at the density read from the original
  256×32 fog image (`R_CreateFogImage`, with the square-root fog table).
- The fog coordinates are `RB_CalcFogTexCoords`': depth along the view over
  eight times `distanceToOpaque`, cut at the visible surface when the eye is
  outside the fog.
- Models whose bounding sphere dips into a fog volume (`R_ComputeFogNum`) take
  the same fog pass over their opaque surfaces.
- Translucent shaders in fog take no fog pass. Their stages fade instead by what
  the fog hides (`adjustColorsForFog`): colour for additive blends, alpha for
  alpha blends, and both for premultiplied ones.
- Fifteen of the original maps have fog, such as the lava haze of q3dm9 and
  q3tourney2.

## Portals and mirrors

Q3 mirrors and camera portals render the view through them before the main
view, one a frame, as `R_SortDrawSurfs` does (`engine/world/portals.jac`,
`engine/render/portal.jac`).
- A `misc_portal_surface` within 64 units of a `portal` shader's plane selects
  that surface.
  - Without a target it is a mirror: the view reflects through the plane.
  - With one it looks out of the `misc_portal_camera`, oriented as `locateCamera`
    and `CG_Portal` set it up. The camera aims at its target or along its angle,
    quantized through the 162 `bytedirs` directions as the network byte is. It
    is rolled by `roll`, and sways four degrees or spins at 25 or 75 degrees a
    second by its flags.
- The view transform is `R_GetPortalOrientations` and `R_MirrorPoint` /
  `R_MirrorVector`, and visibility floods from the camera.
- The view renders into its own framebuffer. The near plane is tilted onto the
  portal plane (standing in for Q3's clip plane), and a mirror's image is
  flipped, with its faces winding the other way.
- The portal surface shows that image in screen space, then its own stages blend
  over it. `alphaGen portal` fades them in with distance.
- A camera portal only renders within its shader's `portalRange`, as
  `SurfIsOffscreen` allows.
- The original maps use this for the mirrors on q3dm0, q3dm8, q3tourney6 and
  q3ctf2, and the teleporter windows on q3dm0, q3dm7 and q3dm11.

## Q3 shaders

- Surface shaders that need more than one lightmapped pass draw stage by stage
  (`RB_StageIteratorGeneric`):
  - `animMap` frames and `$lightmap` stages.
  - Every blend function.
  - `rgbGen` identity, vertex, const and waves (sin, triangle, square, sawtooth,
    inverse sawtooth, noise).
  - `alphaGen` const, wave, vertex and `lightingSpecular`.
  - `tcMod` scroll, scale, rotate, turb, stretch and transform, in order.
  - `tcGen environment` and `tcGen vector`.
  - `alphaFunc` and `depthWrite`.
- `deformVertexes` `wave`, `move` and `bulge` sway vertices. `autosprite` and
  `autosprite2` turn quads toward the viewer.
- Examples on the original maps: q3dm1 animates its hell flames and pentagram
  lights, and q3dm7 its specular iron and glowing crosses.

## Bots

Q3 bots hold the weapon they are using. Each weapon is baked along the body's
poses. An `Arms` edge links a bot to each weapon model, and switching weapons
rewires the weapon visual. The weapon drops away on death.

## Validation

- `scripts/presentation_smoke.jac` loads and draws each game's status bar art on
  e1m1, base1 and q3dm1. It also animates light styles on Q1 and Q2 maps and
  uploads every layered Q3 shader.
- `tests/lightstyle_tests.jac` covers style letters, 10 Hz animation, switches
  and WAD pictures.
- `tests/fog_tests.jac` covers `fogParms`, the fog density table and the fog
  coordinates. `scripts/fog_smoke.jac` loads the fog volumes of q3dm9,
  q3tourney2 and q3dm12 and renders them from above and from inside.
- `tests/portal_tests.jac` covers mirror and camera views, camera sway and
  quantized aim. `scripts/portal_smoke.jac` renders through every portal shader
  on q3tourney6, q3dm0 and q3dm7.

## Limits

- The Q1 status bar's WAD parser needs native `bytes.find`, which comes from
  jac#9478 (open; applied to the local validation compiler).
- 3D HUD icons (`cg_draw3dIcons 1`) remain open.
- Mirrors do not show the player's own body; the player has no third-person
  model yet.
