# Q3 player bodies

Q3 players are drawn as `cg_players.c` draws them: legs, torso and head are
separate MD3 models, each on its own animation, joined through their tags
every frame. Bots, podium figures, bodies left behind (the body queue) and
the player's own body in mirrors, portal views and the death view all use
this rig.

## The rig (`engine/world/models.jac`, `engine/world/player_rig.jac`, `games/arena_character.jac`)

- A `PlayerRig` is a `Visual`. It wears its character's shared part models
  through `Wears` edges (`lower`, `upper`, `head`) and holds a `WeaponKit`
  through a `Holds` edge; the kit links gun, barrel and flash models through
  `KitPart` edges.
- `animation.cfg` is read as `CG_ParseAnimationFile` does: first frame, count
  (negative plays backwards), looping frames and fps; legs frames shifted past
  the torso-only ones; the derived backward walk and crouch; footstep type and
  sex; `headoffset` (for the 3D head icon, `CG_DrawHead`), `fixedlegs` and
  `fixedtorso` (no stock model sets either).
- The `PoseRig` walker picks sequences as `bg_pmove.c` does:
  - legs: idle, run, backpedal, walk, crouch, swim, jump and land (forward and
    back), turn in place, and the land timer;
  - torso: an attack per shot (the gauntlet's own), drop and raise on a weapon
    switch, stand once the weapon is ready, and the gesture;
  - deaths: one of three sequences, then its last frame held.
- `run_lerp_frame` is `CG_RunLerpFrame`: each part at its sequence's own
  rate, haste at 1.5x, and a new sequence blending in from the frame on show.
- `turn_parts` is `CG_PlayerAngles`: legs swing toward the movement direction
  (0, ±22 or ±45 degrees) and the torso a quarter of that; the head looks
  along the view and the torso takes three quarters of the pitch; the legs
  lean into their motion and hits twitch the torso.
- `GatherModels.add_rig` attaches the parts every frame: `tag_torso`,
  `tag_head` and `tag_weapon` lerped between frames
  (`CG_PositionRotatedEntityOnTag`), the barrel spun on `tag_barrel`
  (`CG_MachinegunSpinAngle`), and the flash at `tag_flash` for 30 ms after a
  shot, or throughout while the lightning gun or gauntlet fires. A muzzle
  flash also adds a dynamic light in the weapon's colour
  (`engine/world/light_effects.jac`).

## Lighting (`engine/world/lighting.jac`)

Q3 bots, items, gibs and the view weapon take the map's light grid; every
part of a rig shares one sample.
- `R_LoadLightGrid` reads the grid lump over the world model's bounds at
  worldspawn `gridsize` (64×64×128 by default). Ambient and directed colours
  are shifted for overbright like the lightmaps (`R_ColorShiftLightingBytes`).
- `R_SetupEntityLightingGrid` blends the eight surrounding points, skipping
  those inside walls, scales ambient by `r_ambientScale` 0.6, adds the
  minimum light of 32 and clamps.
- Muzzle flashes, explosions and glowing missiles add dynamic light as in the
  other games.

## Bodies, sounds and powerups

- The player's own body (`engine/world/reflection.jac`) follows the player
  on the same rig. It is drawn where the player can see themselves: in
  mirrors and portal views (`RF_THIRD_PERSON`) and, once dead, in the main
  view, which Q3 then renders from outside
  ([player feedback](player-feedback-status.md)). There it plays one of the
  three deaths and lies on its last frame, holding no weapon (`player_die`:
  `WP_NONE`); a body gibbed is not drawn at all (`GibEntity`:
  `ET_INVISIBLE`). The sounds its poses cue wait on the body until the game
  loop plays them, whichever view posed it first.
- Body queue (`engine/world/body_queue.jac`, `CopyToBodyQue`): a respawning
  player or bot leaves a copy of its body where it lies, still finishing its
  death sequence. After 5 s it sinks (`BodySink`) and is gone at 6.5 s; at most
  eight (`BODY_QUEUE_SIZE`) are kept.
  - A body keeps the dead player's health and gib models. As
    `CONTENTS_CORPSE`, it is struck by hitscan, missiles and splash but not by
    movement (`CONTENTS_CORPSE` is not in `MASK_PLAYERSOLID`).
  - At `GIB_HEALTH` (-40) it bursts into gibs with the gib sound
    (`body_die`); a gibbed body takes no more damage.
  - A dead bot keeps falling (its pmove runs on), so the copy is left where it
    came to rest. None is left in a `CONTENTS_NODROP` void such as the one
    around q3dm17, and a player or bot killed there is not gibbed by that
    blow and drops nothing (`player_die`); a later hit on the falling body
    still bursts it.
- Sounds (`cg_event.c`): each rig names its character's voice and footstep
  type: pain tiers (at most two a second), three deaths, jumps, landings (a
  thud, `pain100` or `fall1` by impact speed), footsteps every 320 ms while
  running, splashes and a gasp on surfacing. Voices fall back to Sarge's. The
  player's own body plays the same cues.
- Powerups (`CG_AddRefEntityWithPowerups`): an invisible player is drawn only
  with the invisibility shader; quad, battle suit and regeneration add shells
  pushed out by their shaders' `deformVertexes`; weapons, the view weapon
  included, use the weapon shells.
- Shadows (`CG_PlayerShadow`, `engine/world/shadows.jac`): with `cg_shadows 1`
  (the default) the `CastShadows` walker visits the human, the bots and the
  bodies left behind each frame and drops a box (30 units square, 2 high)
  128 units down through the world from each one's origin. Where it lands the
  `markShadow` shader is laid as one of `CG_ImpactMark`'s temporary marks: 24
  units in radius, cut to the faces it lies on, turned with the legs and
  fading with the height the player is at. An invisible player casts none.
- Head sprites (`CG_PlayerSprites`, `CG_PlayerFloatSprite`), 10 units in
  radius 48 units over a bot's origin: `sprites/balloon3` while it types a
  chat line (`EF_TALK`); otherwise the medal of an award it just earned
  (`medal_impressive`, `medal_excellent`, `medal_gauntlet`) for two seconds
  (`REWARD_SPRITE_TIME`), a newer award replacing the one showing and
  Excellent going up over a gauntlet frag's when one frag earns both.
- Taunts: a bot that just killed may gesture (`TORSO_GESTURE`) with its
  model's `taunt.wav` (`EV_TAUNT`).
- Q3 players never stop to flinch when hit; the torso twitches and the pain
  sound plays (`engine/world/combat.jac`).

## Validation

- `tests/player_rig_tests.jac`: lerp frames, `animation.cfg` keywords, swing
  angles, legs and torso choices, deaths, sound cues, tag attachment with
  barrel and flash, the body queue, the quad shell.
- `tests/gib_tests.jac`: Q3 bodies soaking shots until they gib, no body in a
  nodrop void, a bot killed there not gibbed, bodies not blocking movement.
- `tests/lighting_tests.jac`: the light grid. `tests/item_drop_tests.jac`:
  powerup shaders on bodies and weapons.
- `tests/podium_tests.jac` and `tests/portal_tests.jac`: podium figures, the
  player's body in portal views, and the dead body shown dying, unarmed, and
  not at all once gibbed.
- `tests/shadow_tests.jac`: the shadow's trace, strength and mark, the human
  and bodies, invisible and dormant players, `cg_shadows`.
  `tests/effect_quads_tests.jac`: award sprites and the talk balloon.
- `scripts/bot_bodies_smoke.jac`: captures a bot running, strafing,
  backpedalling, firing with a flash, aiming up and down, dying, a body left
  behind, a quad shell, a dropped item, an award's medal and the spawn effect,
  each on its blob shadow.
- `scripts/bot_render_profile.jac`: model-pass cost with every bot drawn each
  frame (culling off, 1280x720). Measured 2026-09-24 against the baked bodies
  the rig replaced:

  | Map | Bots | Baked models ms/frame | Rig models ms/frame |
  | --- | ---: | ---: | ---: |
  | q3dm7 | 4 | 7.88 | 8.39 |
  | q3dm6 | 5 | 5.18 | 6.74 |

## Limitations

- `cg_shadows` 2 and 3 (the original's stencil and projection shadows) draw
  no shadow. Shadows fall on the world only, not on doors and platforms (as in
  the original), and are not drawn in mirrors and portal views.
- The human's own head sprite, which the original shows only in third person
  and mirrors, is not drawn.
