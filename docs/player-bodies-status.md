# Q3 player bodies

Q3 players are drawn as `cg_players.c` draws them: legs, torso and head are
separate MD3 models, each on its own animation, joined through their tags
every frame. Bots, podium figures, bodies left behind (the body queue) and
the player's own body in mirrors and portal views all use this rig.

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

- Body queue (`engine/world/body_queue.jac`, `CopyToBodyQue`): a respawning
  bot leaves a copy of its body where it lies, still finishing its death
  sequence. After 5 s it sinks (`BodySink`) and is gone at 6.5 s; at most
  eight (`BODY_QUEUE_SIZE`) are kept.
  - A body keeps the dead player's health and gib models. As
    `CONTENTS_CORPSE`, it is struck by hitscan, missiles and splash but not by
    movement (`CONTENTS_CORPSE` is not in `MASK_PLAYERSOLID`).
  - At `GIB_HEALTH` (-40) it bursts into gibs with the gib sound
    (`body_die`); a gibbed body takes no more damage.
  - A dead bot keeps falling (its pmove runs on), so the copy is left where it
    came to rest. None is left in a `CONTENTS_NODROP` void such as the one
    around q3dm17.
- Sounds (`cg_event.c`): each rig names its character's voice and footstep
  type: pain tiers (at most two a second), three deaths, jumps, landings (a
  thud, `pain100` or `fall1` by impact speed), footsteps every 320 ms while
  running, splashes and a gasp on surfacing. Voices fall back to Sarge's. The
  player's own body plays the same cues.
- Powerups (`CG_AddRefEntityWithPowerups`): an invisible player is drawn only
  with the invisibility shader; quad, battle suit and regeneration add shells
  pushed out by their shaders' `deformVertexes`; weapons, the view weapon
  included, use the weapon shells.
- Talk balloon (`CG_PlayerSprites`, `EF_TALK`): `sprites/balloon3`, 48 units
  over the origin of a bot typing a chat line.
- Taunts: a bot that just killed may gesture (`TORSO_GESTURE`) with its
  model's `taunt.wav` (`EV_TAUNT`).
- Q3 players never stop to flinch when hit; the torso twitches and the pain
  sound plays (`engine/world/combat.jac`).

## Validation

- `tests/player_rig_tests.jac`: lerp frames, `animation.cfg` keywords, swing
  angles, legs and torso choices, deaths, sound cues, tag attachment with
  barrel and flash, the body queue, the quad shell.
- `tests/gib_tests.jac`: Q3 bodies soaking shots until they gib, no body in a
  nodrop void, bodies not blocking movement.
- `tests/lighting_tests.jac`: the light grid. `tests/item_drop_tests.jac`:
  powerup shaders on bodies and weapons.
- `tests/podium_tests.jac` and `tests/portal_tests.jac`: podium figures and
  the player's body in portal views.
- `scripts/bot_bodies_smoke.jac`: captures a bot running, strafing,
  backpedalling, firing with a flash, aiming up and down, dying, a body left
  behind, a quad shell and a dropped item.
- `scripts/bot_render_profile.jac`: model-pass cost with every bot drawn each
  frame (culling off, 1280x720). Measured 2026-09-24 against the baked bodies
  the rig replaced:

  | Map | Bots | Baked models ms/frame | Rig models ms/frame |
  | --- | ---: | ---: | ---: |
  | q3dm7 | 4 | 7.88 | 8.39 |
  | q3dm6 | 5 | 5.18 | 6.74 |

## Limitations

- No player shadows (`CG_PlayerShadow`, `cg_shadows`).
- No award sprites over players' heads (`CG_PlayerFloatSprite` for
  `EF_AWARD_EXCELLENT`, `EF_AWARD_IMPRESSIVE` and the like); the talk balloon
  is the only player sprite.
