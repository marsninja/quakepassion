# Player movement and collision

The player walks, jumps, crouches, swims, climbs and flies by each game's own
movement code: Q1 `SV_ClientThink`/`SV_WalkMove` with QuakeC's `PlayerJump`
and `CheckWaterJump`, Q2 `Pmove` (`qcommon/pmove.c`) and Q3 `PmoveSingle`
(`game/bg_pmove.c`). One shared walker runs all three; a per-game
`MovementProfile` selects the rules. Physics runs at a fixed 120 Hz with
bounded catch-up, and frames draw bodies between ticks (see
[player feedback](player-feedback-status.md)).

## How it works

- `engine/physics/movement.jac`: `MovementProfile` (one typed object per game,
  from `movement_profile(game)`, chosen once per level in
  `engine/world/level.jac`), the `MovePlayer` walker (one fixed step: flight,
  water jump, swimming, ladder or walking) and the `SetStance` walker
  (crouching).
- `engine/physics/collision.jac`: `CollisionMap`, `HullCell` nodes joined by
  `HullFront`/`HullBack` edges, the `Sweep` narrow-phase walker, and a spatial
  tree of `HullGroup` nodes and `HullChild` edges searched by `FindHulls`. The
  tree splits at the median hull centre.
- `engine/physics/patch_collide.jac`: Q3 patch facets (pure geometry).
- Format adapters: `engine/formats/q1/collision.jac` and
  `engine/formats/brush_collision.jac` (Q2/Q3). The physics layer imports
  neither game formats nor rendering.

Monsters walk with the default profile (`movement_profile("")`, a steady
stride per frame); Q3 bots move by the Q3 profile. F4 (`noclip`) toggles the
engine's free-flying camera, which ignores collision and triggers.

### Per-game rules (`MovementProfile`)

| | Q1 | Q2 | Q3 |
|---|---|---|---|
| Max speed | 320 | 300 | 320 |
| Ground friction | 4, doubled over a drop-off (`sv_edgefriction`), on the flat speed | 6, on the full speed | 6, on the flat speed |
| Air acceleration | 10 toward a wish capped at 30 (`SV_AirAccelerate`: air strafing, bunny hopping) | 1 (`pm_airaccelerate` 0 falls back to `PM_Accelerate` at 1) | 1 |
| Jump | adds 270, after friction | adds 270 (at least 270), before friction; `PMF_TIME_LAND` | sets 270, before friction |
| 18-unit steps | on the ground or in water; takes any step onto a floor; `SV_WallFriction` | also in the air | also in the air, never while rising clear of the ground |
| Crouch | none | capped at 100, needs the ground, eye 22 to -2 | capped at 80 (`pm_duckScale`) while walking |
| Swimming | 0.7 of max speed, adding only what the whole speed lacks | 0.5 of max speed | capped at max * `pm_swimScale` |
| Water jump | 225 up, pushed into the wall until clear of the water | 350 up, 50 level with the view | 350 up, 200 along the view |
| Extras | | ladders, water currents, conveyors | wading slowdown, knockback skid (`PMF_TIME_KNOCKBACK`), flight powerup (`PM_FlyMove`) |

Details the profile encodes:

- Friction follows `SV_UserFriction` / `PM_Friction`: `max(speed, stopspeed)
  * friction` a second on the ground, plus water friction (Q2/Q3 scaled by
  depth and applied to waders; Q1 to swimmers only), plus Q3 flight friction.
  Q1's edge test looks 16 units ahead and 34 below the feet.
- Walk and run speeds come from the move command
  (`engine/input/impl/input.impl.jac`, `CL_BaseMove`): `cl_forwardspeed`,
  `cl_sidespeed`, `cl_movespeedkey` and `cl_run`. Q1 `SV_ClientThink` and Q2
  `PM_AirMove` wish the command's length (a diagonal is faster until the cap);
  Q3 `PM_CmdScale` wishes the top speed times the largest axis.
- The ground is walkable at a normal of 0.7 or more; rising faster than 180
  (Q2) or 10 (Q3) off its plane leaves it. Q1/Q2 walks keep to the floor over
  a ramp's crest (`follow_ground`, as `PM_StepSlideMove` traces down); Q3
  kicks off it.
- Jumps need the button released first (Q1 `FL_JUMPRELEASED`, Q2/Q3
  `PMF_JUMP_HELD`). In Q2 a landing faster than 200 blocks jumps and water
  jumps for 144 ms (200 ms above 400).
- Q2 ladders (`CONTENTS_LADDER`; `PM_CheckSpecialMovement`, `PM_AddCurrents`):
  a ladder brush within a unit ahead; pressing forward while looking 15
  degrees up or down climbs at 200, as do jump and crouch; sideways drift is
  held to 25; no gravity.
- Q2 currents (`PM_AddCurrents`): `CONTENTS_CURRENT_*` in water push at 400
  (half for a wader on the ground); on a solid brush they make a conveyor at
  100. Traces carry `climbable` and `conveyor` from the brush they hit.
- Crouching (`PM_CheckDuck`): the hull top drops (Q2 28, Q3 16 units) and the
  eye lowers; standing needs room. The view eases the eye down and up over
  100 ms (`ViewFeedback.duck`, `engine/render/view_feedback.jac`).
- Steps ease the eye instead of jumping it (Q1 `V_CalcRefdef`'s oldz, Q2
  `cl.predicted_step`, Q3 `cg.stepChange`); landings report their speed for
  falling damage. View bob, strafe roll and landing effects are in
  [player feedback](player-feedback-status.md); swimming and liquids in
  [swimming](swimming-status.md).

## Collision

All three games share `CollisionMap`, `HullCell` leaves and the `Sweep`
walker:

- Q1 uses BSP29's pre-expanded clip hulls: hull 1 for the player, hull 2 for
  bodies wider than 32 units (`SV_HullForEntity`). Submodel bounds keep the
  one-unit spread of `Mod_LoadSubmodels`.
- Q2/Q3 load convex brush planes expanded by the standing box (Q2 32 wide,
  eye 22; Q3 30 wide, eye 26; both -24..+32), and shift the planes for any
  other box (crouching, monsters) as `CM_BoxTrace` does. Q2 collides with
  solid, window and playerclip brushes; Q3 with solid and playerclip.
- Rotating movers trace in the model's frame (`CM_TransformedBoxTrace`): the
  box keeps its size and the hit normal is turned back.
- An escaping trace runs out of the solid it starts in, as Q1 `SV_Move`
  does; `SV_CheckStuck` lifts a start embedded in the floor
  (`engine/world/level.jac`).

### Point traces

`CollisionMap.trace_point` queries level geometry with no hull expansion,
returning fraction, endpoint, normal, start-solid, hull index and BSP model.
Q1 traces the render BSP nodes and leaves; Q2/Q3 keep the authored plane
distances beside the expanded ones. Point traces ignore playerclip and stop on
solids (Q2 also on windows), as `MASK_SHOT` does. Shots, water-jump probes and
Q1's edge test use them. Movers share their offsets with both kinds of trace.

### Q3 curved surfaces

Patches collide as `cm_patch.c` builds and traces them
(`engine/physics/patch_collide.jac`), independent of the rendered
tessellation:

- `CM_GeneratePatchCollide` subdivides the control grid until every point is
  within 16 units of the curve, drops degenerate columns (detecting closed
  tubes), and turns each cell into one quad facet or two triangle facets.
- A facet is its surface plane, border planes, the axial and edge bevels of
  `CM_AddFacetBevels`, and the flipped surface plane closing its back.
- `CollisionMap.add_patch` stores each facet as its own `HullCell` leaf,
  expanded for the standing box like a brush.
- The narrow phase follows `CM_TraceThroughPatchCollide` (`CM_CheckFacetPlane`,
  stopping `SURFACE_CLIP_EPSILON` short): a moving box hits only from in front
  and never starts solid; a still box is inside when behind every plane
  (`CM_PositionTestInPatchCollide`); a point trace hits only from in front,
  within the borders (`CM_TracePointThroughPatchCollide`). Facets are
  one-sided, as in Q3.
- Only surfaces whose shader contents are solid or playerclip collide (shots
  stop only on solid ones), hidden ones included. Inline models apply their
  translation. `SURF_NOIMPACT`/`SURF_NOMARKS` keep shots from leaving impacts
  or marks.

## Validation

- `tests/movement_profile_tests.jac`: per-game friction, Q1 edge friction and
  air control, run/crouch and move-command speeds, wading, swim speeds and
  drift, swim jumps, Q2 ladders (climbing and topping out), currents and
  conveyors, Q1 wall friction, Q3 knockback skid.
- `tests/collision_tests.jac` (sweeps, sliding, steps, slopes, ramp crests,
  escaping traces), `tests/crouch_tests.jac`, `tests/unstick_tests.jac`,
  `tests/q1_mover_bounds_tests.jac`, `tests/rotation_tests.jac` (turned hulls),
  `tests/step_view_tests.jac` (step and crouch easing).
- `tests/point_trace_tests.jac`: actual versus expanded surfaces, playerclip
  and windows, translated submodels, patch facets from behind, Q1 render-BSP
  queries.
- `tests/patch_collision_tests.jac`: grid subdivision, front/back and
  point/box rules, position tests, curved landing, a ramp walked smoothly, a
  pillar slid around, seams, solid-only surfaces, surface flags, and a large
  brush bound that must not collapse the spatial tree.
- Asset scripts (build natively as the README describes):
  - `scripts/validate_movement.jac` (`QP_GAME=q1|q2|q3`): lands, jumps and
    walks four ways from spawn on six Q1, three Q2 and four Q3 maps. On Q3 maps
    it shoots every solid patch from in front of its rendered surface and walks
    off up to 24 patch spots per map.
  - `scripts/validate_ladders.jac`: climbs every `CONTENTS_LADDER` brush to
    the top and feels each current volume (`QP_MAPS`, default base1, city2,
    ware2, cool1).
  - `scripts/validate_collision_index.jac` compares indexed and exhaustive
    queries; `scripts/point_trace_smoke.jac` casts axial rays on e1m1, base1
    and q3dm1; `scripts/crouch_smoke.jac` crouches through the app loop.

These are representative spawn-area and per-brush checks, not full-map
traversal.

## Limitations

- Rules are matched to the original source function by function; movement has
  not been compared against recorded demos or the original executables frame
  by frame.
