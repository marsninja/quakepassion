# Doors, buttons and plats

`func_door`, Q2 `func_door_rotating` and `func_water`, `func_button` and
`func_plat` run as one mover state machine in all three games: proximity,
touch, use, shot and key activation, start-open and toggle flags, linked
groups, crushing, Q2 accelerated moves, messages and sounds. Plats are
described in [platforms](platforms-status.md); trains, Q1 secret doors and
rotating movers in [map mechanics](map-mechanics-status.md).

## How it works

`engine/world/doors.jac`:

- A `Door` node per brush entity, `kind` door, button or platform, linked from
  the world by `HasDoor`. `DoorLink` edges join touching Q1 doors (unless
  `DONT_LINK`) and same-`team` Q2/Q3 doors; `AssembleDoors` walks them and
  hangs the members off the leader by `DoorMember` edges. Members finish
  together at the longest travel time.
- Travel comes from the brush model's box as the game loads it: the BSP
  model's stored bounds spread a unit each way (`Mod_LoadSubmodels`,
  `CMod_LoadSubmodels`, `CM_LoadSubmodels`, `model_bounds`), counting brushes
  without faces, less `lip`. Rotating doors turn `distance` degrees (90 by
  default) about their origin, with the REVERSE and axis flags.
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
  proximity box: the model box grown 60 units across and 8 up and down, plus
  the player box (Q1 `spawn_field`). Toggle doors take one proximity request a
  second (saved).
- Named doors open when used: a trigger, button, relay or delay fires their
  `Signal` (see [map mechanics](map-mechanics-status.md)). Q1/Q2 doors fire
  their targets as they start opening; buttons and Q3 doors at the open
  endpoint.
- Shootable Q1/Q2 doors (`health`) open when their health is shot or blasted
  away; Q1 linked parts share the leader's threshold, Q2 team members keep
  their own. Partial damage is saved.
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

Sounds: `mover_voices` gives each mover its start, moving (looped) and stop
sounds as positional speakers: Q1 `sounds` tables in doors.qc, plats.qc,
buttons.qc and func_train; Q2 `dr1_*`, `pt1_*` and `butn2` unless `sounds` is
1, a train's `noise`, and `func_water`'s `mov_watr`/`stp_watr`.

## Validation

- Tests: `tests/door_tests.jac` (timing, blocking, groups, defaults, targets),
  `tests/door_flag_tests.jac` (start-open, toggle), `tests/shoot_door_tests.jac`,
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
- `scripts/chain_audit.jac` counts every Q1 and Q2 mover that loads (see
  [level flow](level-flow-status.md)).

## Limitations

- One proximity box serves all three games: Q1 `spawn_field`'s 60 units across
  and 8 vertically. Q2 `Think_SpawnDoorTrigger` grows only 60 horizontally,
  and Q3 `Think_SpawnNewDoorTrigger` grows 120 along the thinnest horizontal
  axis.
- Q3 movers are silent: `sound/movers/doors`, `plats` and `switches` are not
  played.
- Q3 `func_door` with `health` stays static (no shipped Q3 map has one).
- Q2 `func_door_secret` is not loaded; city3 has one (a shoot-to-open door
  with `ALWAYS_SHOOT` and `1ST_LEFT`), which stays shut.
- A Q2/Q3 door team that includes another mover class stays static.
