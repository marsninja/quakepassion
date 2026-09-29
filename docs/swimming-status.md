# Liquids and swimming

Bodies know how deep they stand in water, slime or lava, swim by each game's
water movement, and take each game's drowning and burning damage. The
per-game swim rules live in `MovementProfile` (see
[player movement](player-movement-status.md)).

## How it works

- Immersion (`Level.immersion`, `engine/world/level.jac`; `Immersion` in
  `engine/world/liquids.jac`) samples the feet, waist and eye for a depth of 0
  to 3 (Q1 `SV_CheckWater`, Q2 `PM_CatagorizePosition`, Q3
  `PM_SetWaterLevel`). The waist is half the view height (Q2/Q3) or 4 units up
  the box (Q1). The worst liquid touched wins (lava over slime over water), and
  the Q2 current at the feet is kept as a direction.
- Q1 reads the BSP leaf contents (its `CONTENTS_CURRENT_*` leaves count as
  water). Q2/Q3 build `LiquidVolume` nodes, one per liquid kind and current in
  each model, linked from a `LiquidSpace` by `HasLiquid` edges, from the exact
  brush planes; the `SampleLiquid` walker tests a point against them and
  `TraceLiquid` sweeps a box into them. A Q2 `func_water` carries its volumes
  with its brush, so pools fill and drain.
- `MovePlayer.swim` (`engine/physics/movement.jac`) runs at waist depth or
  deeper: view-relative thrust, sinking at 60 with no input, no gravity, water
  friction, per-game speed (Q1 0.7, Q2 0.5 of max speed, Q3 capped at
  `pm_swimScale`) and acceleration. Q1/Q2 swim with the stair-stepping move,
  Q3 slides. Q1/Q2 jumping lifts a swimmer at 100 (80 in slime, 50 in lava);
  Q2 currents push at 400 (half for a wader on the ground). Q3 slows waders
  by depth.
  Up and down come from `+moveup`/`+jump` and `+movedown`.
- Water jumps (`check_water_jump`): see the per-game table in
  [player movement](player-movement-status.md).
- `EnvironmentTick` (`engine/world/environment.jac`) drowns a submerged body
  after 12 seconds of air (2 more damage each second, capped at Q1 10 / Q2-Q3
  15; Q2/Q3 through armor), and burns it in slime and lava by depth (Q1 4 or
  10, Q2 1 or 3 each 0.1 s, Q3 10 or 30). The suit, breather, enviro suit and
  battlesuit protect as each game's `P_WorldEffects`/`WaterMove` does.
- `ImmerseBots` (`engine/world/wading.jac`) samples Q3 bots the same way, so
  they swim, drown and burn.
- Entry, exit and underwater sounds and the underwater tint are in
  [player feedback](player-feedback-status.md).

## Validation

- `tests/liquid_tests.jac`: depths, Q1 leaf contents, oblique Q2/Q3 liquid
  brushes and priority, ascent/descent, drag, bounded speed, collision and
  pause while swimming, gravity restored on exit, box sweeps into liquid, bots.
- `tests/movement_profile_tests.jac`: per-game swim speeds and drift, swim
  jumps, Q2 currents at the feet.
- `scripts/validate_swimming.jac` (`QP_GAME=q1|q2|q3`): samples clear
  submerged standing spots on five Q1, five Q2 and six Q3 maps, swims up for
  30 ticks and checks displacement and nonpenetration. Maps without a clear
  sample report as skipped.
- `scripts/swimming_smoke.jac`: held ascent and pause through the app loop on
  e1m2, base1 and q3dm12. `scripts/validate_ladders.jac` also feels each Q2
  current volume.

## Limitations

- Burn intervals are approximations where the original ties them to other
  timers: Q3's 0.7 s stands in for the `pain_debounce_time` that
  `P_WorldEffects` checks.
