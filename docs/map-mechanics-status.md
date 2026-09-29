# Map mechanics: movers, triggers and activation

Everything a map's entities do between the player and the exit: the
activation graph (targets, killtargets, relays, delays, timers, counters),
touch and shot triggers, trains, rotating and bobbing movers, the shared
pusher, Q1 secret doors, damage volumes, secrets and goals, traps, targets,
destructible and toggle walls, Q2 turrets and fly-bys, fixtures and sound
emitters. Doors, buttons and plats are in [doors](doors-status.md) and
[platforms](platforms-status.md); teleporters and pushes in
[traversal](traversal-status.md); exits and campaign flow in
[level flow](level-flow-status.md).

## Activation graph

`engine/world/signals.jac`: every activatable entity has a `Signal` node
(linked from the world by `HasSignal`). `Targets` edges carry uses and `Kills`
edges carry `killtarget`; the `Fire` walker follows them, visiting each
recipient once so cycles end and diamond fan-outs do not double-fire. Chains
are connected once, after every activatable entity has loaded
(`connect_targets`, `engine/world/doors.jac`).

- A recipient with no `use` is skipped and the rest of the chain fires, as
  `SUB_UseTargets`/`G_UseTargets` do; a `ChainNote` records why. Passive
  markers (`info_null`, `info_notnull`, `target_position`, `point_combat`,
  path corners, teleport destinations, `worldspawn`, `misc_explobox`,
  `trigger_monsterjump`) take uses as no-ops.
- `killtarget` retires its victims: triggers, relays, timers, doors, trains,
  walls, pickups, speakers, hazards, pushes, teleporters, shooters and lasers.
- Delays: Q1/Q2 `delay` queues independent uses (`DelayedUse`), each keeping
  its activator's inventory; Q3 `target_delay` restarts its pending timer.
  `SignalTick` collects then emits, so registration order does not matter.
- `trigger_relay`/`target_relay`, Q2/Q3 `trigger_always` (after each game's
  startup delay), Q2/Q3 `func_timer` (bounded random variance from an
  entity-local stream, at most one emission a tick), and `trigger_counter`
  with the original "Only 2 more to go..." and "Sequence completed!" prints.
- Q2 `target_crosslevel_trigger` sets unit flags; `target_crosslevel_target`
  fires on level entry once its flags are set.
- Messages and activation sounds: trigger `message` and `sounds`, Q2
  `noise`/`misc/talk1`, secret cues. A message needs a player activator.
- Named monsters are part of the roster; Q2 `TRIGGER_SPAWN` makes a dormant,
  hidden opponent that a use wakes, and Q2 `deathtarget` fires on death.

## Touch and shot triggers

`engine/world/triggers.jac`: `TouchTrigger` nodes reach door leaders or
signals through `Activates` edges. `TriggerTick` sweeps the body's box from
its previous to its current position against the brush volume each tick, so a
thin trigger is not skipped. Q1 uses its standing clip hull, Q2/Q3 the exact
brushes.

- `trigger_once`, `trigger_multiple`, `trigger_onlyregistered`: touch, use by
  `targetname`, and shooting all fire the same targets (Q1 `multi_trigger`,
  Q2 `Touch_Multi`); `wait` (negative is one-shot) and Q3 `random` waits.
- Directional triggers (`angle`, `InitTrigger`'s facing test), Q1 `NOTOUCH`,
  Q1 shootable triggers (`health`, solid until destroyed), Q2 `TRIGGERED`
  triggers that must be used before touch works, Q2 `MONSTER` and
  `NOT_PLAYER` flags, `trigger_setskill`.
- `trigger_monsterjump` (`MonsterJump`) launches grounded walking monsters at
  `speed`/`height`.
- Fly mode does not touch triggers; the menu pauses them.

## Trains

`engine/world/trains.jac`: `path_corner` (and Q2 `point_combat`) entities are
`TrackPoint` nodes joined by `TrackNext` edges; `Train` nodes follow them under
`TrainTick` (Q1 `train_next`/`train_wait`, Q2 `train_next`, Q3
`Think_BeginMoving`). Q1/Q2 trains put their model box's mins at each corner
(`train_next`, `train_resume`), Q3 trains their origin. Trains use the
corner's `wait` and `speed`; Q1/Q2 named trains wait for a use, Q2 toggle
trains resume mid-segment and stop at negative waits, Q2 teleport corners
jump, and Q3 corner events fire on arrival. Q2 `trigger_elevator` sends an
idle train to the caller's `pathtarget`. Blocked trains roll back; Q1/Q2 ones
hurt what blocks them (`dmg`, Q2 default 100).
Q1 trains `sounds` 1 and Q2 trains' `noise` play as positional speakers.

## Rotating and periodic movers

`engine/world/rotators.jac`: Q2/Q3 `func_rotating`, Q3 `func_bobbing` and
`func_pendulum` are `Rotator` nodes whose pose is a function of a saved clock:
steady spin at `speed` degrees a second, `TR_SINE` bobbing, and a pendulum
period from model length and gravity. A blocked Q2 `func_rotating` hurts by
`dmg` and waits, a Q3 one only waits; bobbing and pendulum movers kill what
they meet and never stop. Q2 `TOUCH_PAIN` blades hurt on contact. Q2
`func_door_rotating` uses the door state machine
([doors](doors-status.md)).

## The shared pusher

`engine/world/pusher.jac` moves what every brush mover carries or runs into:
doors, buttons, plats, `func_water`, trains, rotators and turrets (Q1
`SV_PushMove`, Q2 `SV_Push`, Q3 `G_MoverPush`).

- A mover's step is a list of `HullStep`s (each hull's offset and turn before
  and after). Bodies near the whole move's bounds are gathered once a tick
  (`GatherPushables`, cached in a `PushRoster` node until monsters or items
  come or go), then tested hull by hull.
- Riders standing on a hull, and bodies the new pose overlaps, go along by the
  mover's translation and its turn about the model origin, each traced in its
  own box: the player's, each monster's hull, each item's box.
- As in the originals, the destination is tested, not the swept arc. Q1
  `SV_PushEntity` moves a body as far as the world allows; Q2/Q3 leave a rider
  behind when it can stay where it was.
- If a living body cannot go, the whole move is undone and the body is handed
  to the mover's blocked rule (crush, reverse or wait). Q1 items and corpses
  are left where they were pushed; Q2/Q3 doors and plats clear an item in the
  way.
- A Q2/Q3 player's view turns with a rotating mover (`delta_angles`); Q1
  turns nobody.

## Q1 secret doors

`engine/world/secret_doors.jac` builds `func_door_secret` as a train route:
two-stage travel with corner pauses, open-once, named activation, shooting
(the trace identifies the brush actually hit), blasts in sight, and the
first-left/first-down flags. The step clears by the brush's full extent.
Touching one prints its message (`secret_touch`); its `sounds` set plays
through the train's speakers.

## Damage volumes, secrets and goals

- `engine/world/hazards.jac`: `trigger_hurt` `Hazard` nodes damage players,
  monsters and bots. Q1 hurts once a second; Q2/Q3 support `START_OFF`,
  `TOGGLE`, `SLOW` and armor bypass. Every hurt can be killtargeted; only
  TOGGLE ones respond to a use.
- Q1 `trigger_secret` and Q2 `target_secret`/`target_goal` count once in a
  shared `Progress` node and forward their targets.

## Traps, targets and destructibles

- Q1 `trap_spikeshooter`/`trap_shooter` (spikes 9, superspikes 18, lasers 15),
  `misc_fireball` (20), Q2 `target_blaster` and Q3 `shooter_*` launch
  world-owned projectiles (`engine/world/shooters.jac`).
- `engine/world/targets.jac`: Q2 `target_explosion`, `target_splash`,
  `target_earthquake`, `target_laser` (toggled beams in their palette colours),
  `target_temp_entity` (TE_BOSSTPORT with `misc/bigtele.wav`), `target_help`
  (the `HelpComputer` node), `func_killbox`; Q3 `target_give`,
  `target_remove_powerups` and `target_print`.
- Q2 `target_spawner` places its item or monster when used (including
  `key_pass`). Q2 `target_lightramp` ramps a light style.
- Q1/Q2 exploding barrels (`misc_explobox`) take damage from any source and
  explode (Q1 160, Q2 150); they are not kills.
- `engine/world/brushes.jac`: Q2 `func_wall` toggles visibility and collision
  together; `func_explosive` takes shots or uses, disappears, fires its
  targets and can blast and chain. Plain walls (every named Q1 `func_wall`,
  Q2 walls without TRIGGER_SPAWN, TOGGLE or START_ON) can be killtargeted; Q1
  `func_wall_use` swaps to the alternate textures.
- Q2 `func_object` (`engine/world/falling.jac`) drops and crushes for `dmg`;
  `func_clock` (`engine/world/clocks.jac`) counts into its `target_string`
  glyphs and fires its `pathtarget`; `misc_viper`, `misc_strogg_ship` and
  `misc_viper_bomb` fly their corners (`engine/world/flyers.jac`).
- Q2 turrets (`engine/world/turrets.jac`): `turret_breach`, `turret_base` and
  `turret_driver` (jail1, strike). The driver (a `Mans` edge) aims the breach
  within its pitch and yaw limits at `speed` degrees a second, fires a
  100-150 damage rocket at 550 + 50 × skill after 3 − skill seconds, rides
  with the gun, and the gun levels off when he dies. Turrets push and crush
  (`turret_blocked`, `dmg` 10); saves keep the aim and targeting.
- Switchable Q1/Q2 lights (styles 32-62) toggle and are saved
  (`engine/world/lightstyles.jac`). Q2 `func_areaportal`s open and close with
  their doors and relays (`engine/world/area_portals.jac`).

## Fixtures and sound emitters

- `games/fixtures.jac`, `engine/world/fixtures.jac`: Q1 torches and flames
  with their models and fire loops; fluorescent lights, `ambient_*` and
  teleporter hums as static loops; Q2 dead bodies, mine lights, banners,
  novelty models, `misc_blackhole`, `misc_satellite_dish` and teleporter pads.
- Q1's water and sky ambience follows the BSP leaf's ambient levels
  (`S_UpdateAmbientSounds`). Emitters out of earshot hold no audio stream.
- Q2/Q3 `target_speaker` (`engine/world/speakers.jac`) follows each game's
  `SP_target_speaker`: Q2 loops at volume 1 with the looping falloff,
  one-shots with their `volume` and `attenuation` (-1 everywhere), sexed `*`
  sounds in the male voice; Q3 global (4) and activator (8) speakers at full
  volume, and `random` of a tenth or more repeats every `wait` ± `random`
  (`CG_Speaker`).
- Positioned sounds fall off as each game mixes them (`sound_falloff`,
  `engine/audio/feedback.jac`): Q1 `SND_Spatialize`, Q2
  `S_SpatializeOrigin` (full within 80, then by attenuation; ATTN_STATIC and
  loops faster), Q3 full within 80 then 0.0008 a unit. Q2/Q3 missiles carry
  their flight sounds, and the Q2 player's own loop follows
  `G_SetClientSound`.

## Validation

- Tests: `tests/signal_tests.jac`, `tests/trigger_tests.jac`,
  `tests/map_mechanics_tests.jac`, `tests/train_tests.jac`,
  `tests/rotation_tests.jac`, `tests/mover_push_tests.jac` (monsters and items
  on lifts, Q3 rotating riders, turrets), `tests/secret_door_tests.jac`,
  `tests/hazard_tests.jac`, `tests/progress_tests.jac`,
  `tests/brush_object_tests.jac`, `tests/loose_ends_tests.jac`,
  `tests/clock_tests.jac`, `tests/turret_tests.jac`, `tests/speaker_tests.jac`,
  `tests/lightstyle_tests.jac`, `tests/idle_work_tests.jac`,
  `tests/campaign_flow_tests.jac`.
- Asset scripts (build natively as the README describes):
  `scripts/validate_triggers.jac`, `scripts/validate_events.jac` (event
  scheduling and snapshot round-trips), `scripts/validate_trains.jac`,
  `scripts/validate_secret_doors.jac`, `scripts/validate_hazards.jac`,
  `scripts/validate_progress.jac`, `scripts/validate_brush_objects.jac`,
  `scripts/mechanics_smoke.jac` (rotating doors, movers, shooters, lasers and
  fixtures with captures), `scripts/turret_smoke.jac`,
  `scripts/speaker_smoke.jac`, `scripts/train_smoke.jac`,
  `scripts/enemy_mover_smoke.jac`.
- `scripts/chain_audit.jac` checks that every Q1 and Q2 exit, mover, trigger,
  teleporter and train loads and no signal is left disabled
  ([level flow](level-flow-status.md)).

## Limitations

- Timers and random waits keep the original scheduling but draw from an
  entity-local random stream, not the original engine's global sequence.
- Closed Q2 area portals gate only sound for monsters; they do not cull
  rendering, and played sounds are not limited by the PHS
  (`MULTICAST_PHS`). A relay-toggled portal's state is not saved (portals
  held by doors follow their doors).
- `target_actor`/`misc_actor` are not implemented; no shipped map needs them
  (biggun's only `target_actor` has no actor to drive).
- Q2 `func_door_secret` and Q3 mover sounds: see [doors](doors-status.md).
