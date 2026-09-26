# Q3 player bodies

Q3 players are drawn the way `cg_players.c` draws them. The legs, torso and
head are separate MD3 models, each on its own animation, joined through their
tags every frame. This applies to bots, podium finishers, bodies left behind
and the player's own mirror body.

## The rig (`engine/world/models.jac`, `engine/world/player_rig.jac`)

- A `PlayerRig` is a `Visual`. It wears its character's shared part models
  through `Wears` edges (roles `lower`, `upper`, `head`). It holds a
  `WeaponKit` through a `Holds` edge, and the kit links the gun, barrel and
  flash models through `KitPart` edges.
- `games/arena_character.jac` reads `animation.cfg` as `CG_ParseAnimationFile`
  does:
  - first frame, count (negative plays backwards), looping frames and fps;
  - legs frames shifted past the torso-only frames;
  - the derived backward walk and crouch sequences;
  - the footstep type and sex;
  - `headoffset`, which moves the head in its 3D icon (`CG_DrawHead`: the
    status bar and scoreboard heads), and `fixedlegs` and `fixedtorso`.
    Fixed legs keep the torso's yaw with no lean, and a fixed torso never
    pitches (`CG_PlayerAngles`). No stock model sets either.
- The `PoseRig` walker picks the sequences, following `bg_pmove.c`:
  - legs: idle, run, backpedal, walk, crouch, swim, jump and land (forward and
    backward), turn in place, and the land timer;
  - torso: an attack per shot (the gauntlet's own attack), drop and raise on a
    weapon switch, stand again once the weapon is ready, and the gesture;
  - deaths: one of the three sequences, then its last frame held.
- `run_lerp_frame` is `CG_RunLerpFrame`. Each part plays at its sequence's own
  rate, with haste at 1.5x. A new sequence blends in from the frame on show.
- `turn_parts` is `CG_PlayerAngles`:
  - the legs swing toward the movement direction (0, ±22 or ±45 degrees) and
    the torso a quarter of that;
  - the head looks exactly along the view, and the torso takes three quarters
    of the pitch;
  - the legs lean into their motion, and hits twitch the torso.
- `GatherModels.add_rig` attaches the parts every frame:
  - it lerps `tag_torso`, `tag_head` and `tag_weapon` between the frames shown
    (`CG_PositionRotatedEntityOnTag`);
  - the barrel spins on `tag_barrel` (`CG_MachinegunSpinAngle`);
  - the muzzle flash shows at `tag_flash` for 30 ms after a shot, or all the
    while the lightning gun or gauntlet fires;
  - every part shares one lighting sample, taken from the map's light grid
    (below).
- A muzzle flash also adds a 300-unit light in the weapon's colour
  (`light_effects.jac`).

## Lighting

Q3 bots, items, gibs and the view weapon are lit from the map's light grid
(`engine/world/lighting.jac`). Before, they were drawn full bright.
- `R_LoadLightGrid` reads the grid lump over the world model's bounds, at the
  worldspawn `gridsize` (64×64×128 by default).
- Its ambient and directed colours are shifted for overbright like the
  lightmaps (`R_ColorShiftLightingBytes`, ×4, overflowing colours scaled back
  whole).
- `R_SetupEntityLightingGrid` blends the eight surrounding points, leaving
  out those inside walls. Ambient light is scaled by `r_ambientScale` 0.6,
  with the minimum light add of 32, and kept in range.
- Muzzle flashes, explosions and glowing missiles add their light as in the
  other games.

Next to a lightmapped wall a bot now matches the world's brightness. It
has a lit side and a darker side (`scripts/arena_screens_smoke.jac` captures
a bot with the grid and full bright). `tests/lighting_tests.jac` covers the
grid.

## Bodies, sounds and powerups

- **Body queue** (`engine/world/body_queue.jac`): a respawning bot leaves a
  copy of its body where it fell (`CopyToBodyQue`). The copy finishes its death
  sequence, sinks after five seconds and goes after 6.5 (`BodySink`). Eight
  bodies are kept at most.
  - A body keeps the dead player's health and its gib models.
  - Hitscan shots, missiles and splash from players and bots strike it, as
    `CONTENTS_CORPSE` does. The shots stop at its lowered box.
  - At `GIB_HEALTH` (-40) it bursts into gibs with the gib sound (`body_die`).
  - A body that was gibbed takes no more damage.
- **Sounds** (`cg_event.c`): each rig names its character's voice and footstep
  type. Its cues are the pain tier (at most two a second), the three deaths,
  jumps, landings (a thud, `pain100`, or `fall1` by impact speed), footsteps
  every 320 ms while running, splashes, and a gasp on surfacing. Voices fall
  back to Sarge's. The Q3 player's own body plays the same cues.
- **Powerups** (`CG_AddRefEntityWithPowerups`): an invisible player is drawn
  only with the invisibility shader. Quad, battle suit and regeneration
  (flashing) add shells pushed out along the normals by their shaders'
  `deformVertexes` amount. Weapons, the view weapon included, use the weapon
  shells.
- Q3 players no longer stop to flinch when hit.
- The Q3 view weapon has its muzzle flash and a spinning barrel.

## Validation

- `tests/player_rig_tests.jac`:
  - lerp frames, looping and holds;
  - swing angles and movement directions;
  - legs, torso and death choices, and sound cues;
  - tag attachment, including barrel and flash;
  - the body queue.
- `tests/podium_tests.jac` and `tests/portal_tests.jac` cover finishers and the
  mirror body on the rig.
- `scripts/bot_bodies_smoke.jac` fights bots on q3dm7 and q3dm1 and captures a
  bot running, strafing, backpedalling, firing with a flash, aiming up and
  down, dying, and a body left behind.
- `scripts/bot_render_profile.jac` times the model pass with every bot drawn
  each frame (culling off, 1280x720). Against the baked bodies it replaced:

  | Map | Bots | Baked models ms/frame | Rig models ms/frame |
  | --- | ---: | ---: | ---: |
  | q3dm7 | 4 | 7.88 | 8.39 |
  | q3dm6 | 5 | 5.18 | 6.74 |

  Posing adds up to 0.3 ms per bot, and fewer with culling on.

## Limits

- Bots' powerup shells and invisibility are not drawn yet: native
  `isinstance(here, Actor)` in `GatherModels` is false for `Opponent`, whose
  module `models.jac` does not import (a Jac defect with a minimal repro, to be
  fixed upstream). The player's view weapon shows its shells.
- Bodies are not solid to movement.
- The powerup shaders drop their texture rotation and turbulence.
