# Presentation

Each game draws its own status bar, animated lighting, skies, liquids, fog,
portals and Q3 shader surfaces from its original art, following its original
renderer. How the surfaces reach the GPU is in [rendering](rendering-status.md).

## Status bars

`engine/render/hud.jac` draws each game's status bar from its own art, scaled
up by a whole factor and centred on its virtual screen; `games/hud_art.jac`
loads the art. The `crosshair` cvar (`cg_drawCrosshair`) hides the crosshair.
The text status line remains for Passion levels and whenever art is missing.

- **Quake** (`sbar.c`, art from `gfx.wad` through `engine/formats/q1/wad.jac`):
  - Big digits (`num_*`), switching to the red `anum_*` set at 25 health or
    armor and at 10 ammo.
  - The armor icon matching its strength; faces by health band, with pain
    frames and the quad, invisibility and invulnerability faces
    (invulnerability shows 666 armor); the ammo icon.
  - Owned and selected weapons, all four ammo counts in the small `conchars`
    digits, keys, powerups and sigils.
  - `Sbar_SoloScoreboard` while scores are held or the player is dead, and the
    `Sbar_IntermissionOverlay` plaque.
  - The crosshair: the `conchars` `+` at the centre of the view.
- **Quake II** (the single-player statusbar layout from `g_spawn.c`):
  - Health, ammo and armor fields in `num_`/`anum_` digits, flashing when low,
    with their icons.
  - `field_3` behind the health or armor number for a server frame after a
    hit to it (`STAT_FLASHES`, `P_DamageFeedback`), including cells spent by
    power armor.
  - Running power armor (`G_SetStats`): the cell count with `i_powershield`,
    taking turns (`level.framenum & 8`) with worn armor.
  - The held weapon's icon, or `i_help` blinking while the help computer has
    unread news (`STAT_HELPICON`, `pers.helpchanged`).
  - The pickup icon and name for three seconds (`STAT_PICKUP_ICON/STRING`),
    the selected item's icon, and the seconds left on a running powerup.
  - The crosshair `pics/ch1.pcx` (`SCR_DrawCrosshair`).
- **Quake II layouts.** `HudRenderer.draw_layout` runs
  `SCR_ExecuteLayoutString` programs (`xl`/`xr`/`xv`, `yt`/`yb`/`yv`, `picn`,
  `string`, `string2`, `cstring`, `cstring2`) with the Q2 `conchars`,
  high-bit characters in the alternate set. `games/q2_layouts.jac` writes the
  programs.
  - F1 (`cmd help`): the help computer, `p_hud.c HelpComputer`'s layout on
    `help.pcx` (skill, level name, both objectives, kills/goals/secrets).
    Opening it reads the news; `misc/pc_up.wav` sounds when news arrives and
    twice more, 6.4 s apart, while it stays unread. Objectives persist across
    levels and in saves.
  - The end-of-unit summary uses the same frame ("Unit complete", the time,
    the unit's last level's tallies). The original shows only the
    intermission view here.
  - Tab (`inven`): the inventory (`cl_inv.c CL_DrawInventory`) on
    `inventory.pcx`, "hotkey ### item" rows in `itemlist` order, 17 at a time
    around the selected item, the selection plain with a blinking cursor.
    `invprev`, `invnext` and `invuse` select and use stored items.
  - Entity `message` values turn `\n` into line breaks at load
    (`ED_NewString`/`G_NewString`).
- **Quake III** (`cg_draw.c`, with `cg_draw3dIcons 1`,
  `engine/render/hud_models.jac`):
  - Ammo, health and armor in the 32×48 digits: orange, red and flashing when
    health is low, white over 100, grey while firing.
  - The held weapon's ammo box swings, the yellow armor spins, and Sarge's
    head glances about, easing to a new angle every 0.1–2.1 s.
  - The head kicks only for real damage (`cg.damageTime` from
    `CG_DamageFeedback`), toward the side the hit came from (`cg.damageX`): it
    swells from 1.5 times its size over half a second and turns up to 45
    degrees (`CG_DrawStatusBarHead`).
  - Each icon is `CG_Draw3DModel`: a 30° view of the model alone, rendered
    offscreen into its box, with the 2D icons as the fallback.
  - The default crosshair.

## Light styles

`engine/world/lightstyles.jac`.

- Q1 and Q2 lightmaps keep one layer per light style. The fixed styles
  (flicker, pulses, candles, strobes, fluorescent) play at 10 Hz
  (`R_AnimateLight`); the world shader scales each layer by its style's value.
- Targetable lights (styles 32–62) become `LightSwitch` nodes in the signal
  graph. They start dark when flagged `START_OFF` and toggle when triggered,
  as `light_use` does.
- Models lit from the lightmaps follow the same style values (see
  [models](models-status.md)).

## Skies

- **Quake:** the sky texture splits into its solid back layer and masked front
  layer, each mapped by view direction onto the flattened sky dome and
  scrolled at the original speeds (`EmitSkyPolys`). Clear texels take the back
  layer's average colour, as `R_InitSky` does.
- **Quake II:** six-image sky boxes, turned by the worldspawn's `skyrotate`
  degrees a second about `skyaxis`.
- **Quake III:** each sky shader's `skyParms` gives the far-box images and the
  cloud layers drawn on the sky dome. Each dome direction meets a cloud sphere
  `cloudheight` above a 4096-unit world, and the texture coordinates are the
  arccosines of that direction (`tr_sky.c`); the stage's tcMods, blends and
  colour waves then apply. `SURF_SKY` faces open onto the sky.

## Liquids and translucency

- Q1 `*` textures and Q2 `SURF_WARP` surfaces sway with `EmitWaterPolys`'
  turbulence, computed per pixel.
- Q2 `SURF_FLOWING` surfaces scroll.
- `SURF_TRANS33` and `SURF_TRANS66` faces blend over the world unlit.

## Fog

Q3 fog volumes draw as `tr_shade.c` does:

- Each surface's fog number comes from the BSP (an index past the fog list,
  as on q3tourney6, means unfogged). A volume's bounds and visible side come
  from its fog brush; its colour and `distanceToOpaque` from its shader's
  `fogParms`.
- Opaque surfaces inside a volume, and the fog shaders' own surfaces, take a
  fog pass at the density read from the original 256×32 fog image
  (`R_CreateFogImage`). The fog coordinates are `RB_CalcFogTexCoords`': depth
  along the view over eight times `distanceToOpaque`, cut at the visible
  surface when the eye is outside the fog.
- Models whose bounding sphere dips into a fog volume (`R_ComputeFogNum`)
  take the same fog pass.
- Translucent shaders take no fog pass; their stages fade by what the fog
  hides (`adjustColorsForFog`): colour for additive blends, alpha for alpha
  blends, both for premultiplied ones.

## Portals and mirrors

Q3 mirrors and camera portals render the view through them before the main
view, one a frame, as `R_SortDrawSurfs` does (`engine/world/portals.jac`,
`engine/render/portal.jac`).

- A `misc_portal_surface` within 64 units of a `portal` shader's plane selects
  that surface. Without a target it is a mirror; with one it looks out of the
  `misc_portal_camera`, oriented as `locateCamera` and `CG_Portal` set it up
  (aim quantized through the 162 `bytedirs`, `roll`, and a four-degree sway or
  25/75 degree-a-second spin by its flags).
- The view transform is `R_GetPortalOrientations` and `R_MirrorPoint` /
  `R_MirrorVector`; visibility floods from the camera.
- The view renders into its own framebuffer with the near plane tilted onto
  the portal plane (standing in for Q3's clip plane); a mirror's image is
  flipped. The portal surface shows that image, then its own stages blend
  over it; `alphaGen portal` fades them in with distance, and a camera portal
  renders only within its shader's `portalRange` (`SurfIsOffscreen`).
- In a Q3 arena the player's own body is drawn only in these views
  (`RF_THIRD_PERSON`).

## Q3 shaders

- Surface shaders that need more than one lightmapped pass draw stage by stage
  (`RB_StageIteratorGeneric`):
  - `animMap` frames and `$lightmap` stages; every blend function.
  - `rgbGen` identity, vertex, const and waves (sin, triangle, square,
    sawtooth, inverse sawtooth, noise).
  - `alphaGen` const, wave, vertex, portal and `lightingSpecular`.
  - `tcMod` scroll, scale, rotate, turb, stretch and transform, in order;
    `tcGen environment` and `tcGen vector`.
  - `alphaFunc` and `depthWrite`.
- `deformVertexes` `wave`, `move` and `bulge` sway vertices; `autosprite` and
  `autosprite2` turn quads toward the viewer.
- Model shaders (powerup shells, armor, weapons) run the same tcMods,
  including rotate and turb.

## Effects and dynamic lights

- Dynamic lights come from each game's client rules
  (`engine/world/light_effects.jac`: muzzle flashes, rockets, explosions,
  Q2 blaster and BFG, Q3 quad), eight nearest the viewer. They light world
  surfaces and models.
- Particles, trails, beams, sprites and Q3 wall marks are described in
  [combat feedback](combat-feedback-status.md) (what each game emits) and
  [rendering](rendering-status.md#effects) (how they are drawn).

## Validation

- `tests/q2_presentation_tests.jac`: layout tokenizer, help computer and unit
  summary programs, inventory rows, help beeps, status flashes.
  `scripts/q2_presentation_smoke.jac` drives base1 and saves the help icon,
  help computer, inventory, power armor bar and unit summary to
  `.jac/screenshots/q2hud/`.
- `scripts/presentation_smoke.jac` draws each game's status bar art on e1m1,
  base1 and q3dm1, animates light styles on Q1 and Q2 maps and uploads every
  layered Q3 shader.
- `tests/lightstyle_tests.jac`: style letters, 10 Hz animation, switches and
  WAD pictures. `tests/hud_head_tests.jac`: the Q3 head kick.
- `tests/fog_tests.jac`: `fogParms`, the density table and fog coordinates.
  `scripts/fog_smoke.jac` renders the fog volumes of q3dm9, q3tourney2 and
  q3dm12 from above and inside.
- `tests/portal_tests.jac`: mirror and camera views, camera sway and quantized
  aim. `scripts/portal_smoke.jac` renders every portal shader on q3tourney6,
  q3dm0 and q3dm7.
- `tests/lightfx_render_tests.jac`: Q2 sky rotation, model texture steps.
  `tests/model_material_tests.jac`: model shader stages.

## Limitations

- The Q2 inventory's hotkey column comes from a fixed table of Q2's default
  binds (`games/q2_layouts.jac` `Q2_INVENTORY_BINDS`), not from the current
  bindings.
- Q2 item selection (`invnext`/`invprev`) steps through stored items only;
  the original's `SelectNextItem` also steps through weapons.
- Q3 flares, `deformVertexes normal` and unknown shader directives are not
  drawn (see [rendering](rendering-status.md#limitations)).
