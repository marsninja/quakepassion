# Doors, buttons and plats

`func_door`, Q2 `func_door_rotating` and `func_water`, `func_button` and
`func_plat` run as one mover state machine in all three games: proximity,
touch, use, shot and key activation, start-open and toggle flags, linked
groups, crushing, Q2 accelerated moves, messages and sounds. Each step goes
through the shared pusher (`engine/world/pusher.jac`), which carries the
player, monsters and items and crushes what it cannot move. Trains, secret
doors and rotating movers are in [map mechanics](map-mechanics-status.md).

## How it works

`engine/world/doors.jac`:

- A `Door` node per brush entity, `kind` door, button or platform, linked from
  the world by `HasDoor`. `DoorLink` edges join touching Q1 doors (unless
  `DONT_LINK`) and same-`team` Q2/Q3 doors; `AssembleDoors` walks them and
  hangs the members off the leader by `DoorMember` edges. Members finish
  together at the longest travel time.
- Travel comes from the brush model's box as the game loads it: the BSP
  model's stored bounds spread a unit each way (`Mod_LoadSubmodels`,
  `CMod_LoadSubmodels`, `CM_LoadSubmodels`), counting brushes without faces,
  less `lip`. `model_bounds` and `mover_origin` sit with the BSP records
  (`engine/formats/bsp.jac`) and serve every brush mover: doors, trains,
  rotators and pendulums, secret doors, walls and falling objects. Rotating
  doors turn `distance` degrees (90 by default) about their origin, with the
  REVERSE and axis flags.
- Defaults follow the spawn functions: doors speed 100 and wait 3 (Q3 400 and
  2), buttons speed 40 and wait 1 (Q2 3), lip 8 (buttons 4). Negative wait
  stays open.
- `DoorTick` advances each group every 120 Hz tick. Each step goes through the
  shared pusher (`engine/world/pusher.jac`, see
  [map mechanics](map-mechanics-status.md)): riders and anything the new pose
  catches move with it, each in its own box, or the whole group stays put.
  A blocked mover crushes the obstacle for its `dmg` (default 2, Q1 plats 1)
  at most ten times a second and reverses (Q1 `door_blocked`, Q2
  `door_blocked`); Q2/Q3 CRUSHER doors and doors with a negative wait keep
  pushing. Q2/Q3 doors and plats clear an item in their way (Q2 with an
  explosion); Q1 items never block.
- Render and collision share one transform per member; collision bounds
  include the whole travel.

Activation:

- Unnamed doors open when the player or a living monster is inside the
  team's opening field, sized from the whole team's starting bounds as each
  game does (`door_field`): Q1 `spawn_field` grows them 60 units sideways and
  8 up and down; Q2 `Think_SpawnDoorTrigger` 60 sideways only; Q3
  `Think_SpawnNewDoorTrigger` 120 each way along the team's thinnest axis,
  whichever of the three it is. Q1 reads the model's own bounds, which a
  start-open door's move does not shift; Q2 and Q3 read the linked bounds, at
  the starting position and a unit wider (`door_start_bounds`).
  `field_reach` adds the toucher's box and the unit by which Q1 and Q2 widen
  every linked box. Toggle doors take one proximity request a second (saved).
- Named doors open when used: a trigger, button, relay or delay fires their
  `Signal` (see [map mechanics](map-mechanics-status.md)). Q1/Q2 doors fire
  their targets as they start opening; buttons and Q3 doors at the open
  endpoint.
- Shootable Q1/Q2 doors (`health`) open when their health is shot or blasted
  away; Q1 linked parts share the leader's threshold, Q2 team members keep
  their own. Partial damage is saved.
- A Q3 mover has no health of its own: any damage uses one that rests at its
  first position (`G_Damage`). That covers doors and buttons given `health`
  and every door that opens by its own field
  (`Think_SpawnNewDoorTrigger` marks the whole team), so shooting or
  blasting an ordinary Q3 door opens it; a targeted door is left to its
  target. Splash reaches a Q3 mover by the nearest point of its box
  (`G_RadiusDamage`), whatever the damage comes to.
- Q1 key doors (`GOLD_KEY`, `SILVER_KEY`) take the key, say "You need the
  silver key/runekey/keycard" by `worldtype` every 2 s and play the
  `med`/`rune`/`base` `try` and `use` sounds. Q2 keys go through
  `trigger_key`.
- Start-open doors begin at the far end of the reversed path; Q1/Q2 toggle
  doors wait at either end and reverse mid-travel.
- Door messages show on touch until the first use: Q1 `door_touch` for any
  door every 2 s with `misc/talk.wav`, Q2 for named, unshot doors every 5 s
  with `misc/talk1.wav`.
- Q2 `func_door` ANIMATED flags only animate textures. Q2 plats, and doors and
  `func_water` whose `accel`/`decel` differ from their speed, ramp as
  `Think_AccelMove` does (`engine/world/mover_ramp.jac`).
- A mover whose lip swallows its size still runs its cycle and fires its
  targets. killtarget, accel and decel load on doors, buttons and plats.

Buttons:

- A button presses on physical contact (a one-unit probe around the player
  box); named Q2 buttons need a use, Q1/Q3 named buttons still take touch.
  Reaching the pressed end fires the targets and prints the button's message
  (`misc/talk.wav`/`talk1.wav`); after its wait it returns.
- Shootable buttons (`health`, including Q3's) take weapon damage and
  unobstructed blast damage, and are deaf to damage while pressed.
- A pressed button shows its alternate (Q1 `+a`) or next (Q2) texture.

Plats (`func_plat`, kind `platform`):

- A plat travels straight up: its `height`, or the model's height less `lip`
  (8). Q2 `base3`'s cage lift has lip 132 on a model 322 units tall as
  loaded (its brushes reach far below the car it draws), so it rises 190
  units; its other lift rises 154.
- Defaults: speed 150 (Q1) or 200 (Q2/Q3); a plat holds 3 s at the top (Q3
  1 s); Q1 plats crush for 1. Q2 plats ramp as `Think_AccelMove` does (above).
- Unnamed plats start lowered and rise when the player or a living monster
  steps into the touch field: the car inset 25 units a side (Q3 33), in
  Q1/Q2 from the lowered top to 8 above the raised top, or only the bottom 8
  units with `PLAT_LOW_TRIGGER` (`plat_spawn_inside_trigger`,
  `SpawnPlatTrigger`).
- Named Q1/Q2 plats start at the top, locked; their first use lowers and
  unlocks them. Named Q3 plats start lowered, have no touch field and move
  only when used.
- Anyone standing on a raised plat holds it up (`plat_center_touch`); it
  descends after its wait, carrying whoever is aboard. A jump leaves the plat
  behind. A blocked plat reverses, and the whole group's step is undone
  first, so no rider is left part-moved.

Sounds: `mover_voices` gives each mover its start, moving (looped) and stop
sounds as positional speakers: Q1 `sounds` tables in doors.qc, plats.qc,
buttons.qc and func_train; Q2 `dr1_*`, `pt1_*` and `butn2` unless `sounds` is
1, a train's `noise`, and `func_water`'s `mov_watr`/`stp_watr`. Q3 doors play
`sound/movers/doors/dr1_strt` as they set off either way and `dr1_end` as
they arrive, and buttons `switches/butn2` when pressed (g_mover.c); nothing
loops. Q3 plats name `plats/pt1_strt` and `pt1_end`, which the Q3 archives do
not hold. A mover turned back in mid travel plays its start sound again (Q2
`door_blocked`, Q3 `Use_BinaryMover`).

## Validation

- Tests: `tests/door_tests.jac` (timing, blocking, groups, defaults, targets,
  each game's opening field),
  `tests/door_flag_tests.jac` (start-open, toggle), `tests/shoot_door_tests.jac`
  (health doors, Q3 doors shot at rest, Q3 splash by box),
  `tests/platform_tests.jac` (carrying up and down without drift in all three
  games, blocked riders, named plats, jumping and crouched riders, travel from
  model bounds), `tests/q1_mover_bounds_tests.jac`,
  `tests/enemy_door_tests.jac` (monsters opening doors and riding plats),
  `tests/button_tests.jac`, `tests/shoot_button_tests.jac`,
  `tests/mover_push_tests.jac`, `tests/mover_ramp_tests.jac`,
  `tests/rotation_tests.jac` (rotating doors, crushers),
  `tests/campaign_flow_tests.jac` (door messages, key wording, mover sounds).
- Asset scripts (build natively as the README describes):
  `scripts/validate_doors.jac` and `scripts/validate_buttons.jac`
  (`QP_GAME=q1|q2|q3`) cycle real doors and buttons;
  `scripts/shoot_door_smoke.jac` shoots authored health doors;
  `scripts/mover_flags_smoke.jac` checks start-open and toggle groups;
  `scripts/door_smoke.jac` captures closed/open doors through the app loop
  (`QP_BUTTON_TEST=1` for buttons, `QP_TRIGGER_TEST=1` for triggered doors).
- Plat scripts: `scripts/validate_platforms.jac` (`QP_GAME=q1|q2|q3`) cycles
  every plat on six Q1, six Q2 and five Q3 maps and rides each from sampled
  standing points; on 2026-09-20 it passed 17 Q1 and 16 Q2 cycles, 16 and 14 of them with a
  ride (the rest had no standing point among the samples). None of the 36
  maps in the Q3 archives has a `func_plat` (checked 2026-09-29), so it
  reports a skip for Q3 and Q3 plats are covered by tests only.
  `scripts/platform_smoke.jac` rides a lift on e1m1 and on base3 through the
  desktop app loop, checks that the open menu pauses it and that the rider
  ends clear of the world, and captures the bottom and top;
  `scripts/platform_walk_smoke.jac` rides every e1m1 and base3 lift under
  the walking simulation without sinking into it, then walks off;
  `scripts/enemy_mover_smoke.jac` checks monsters opening doors and riding
  plats. A probe of both base3 lifts with a gunner aboard (2026-09-28)
  carried it the full 190 and 154 units.
- `scripts/chain_audit.jac` counts every Q1 and Q2 mover that loads (see
  [level flow](level-flow-status.md)).

## Limitations

- Monsters open a door through the same field as the player, sized for the
  player's box rather than their own.
- A Q3 door team's slaves do not add the smaller fields
  `Think_SpawnNewDoorTrigger` also spawns around each of them.
- A Q2/Q3 door team that includes another mover class stays static; no
  shipped map has one.
