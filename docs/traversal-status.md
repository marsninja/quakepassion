# Teleporters and jump pads

Teleporters, Q2 teleporter pads and push triggers move players and monsters
as the originals' `trigger_teleport`, `misc_teleporter` and `trigger_push`
do, with each game's arrival speed, sounds, particles and telefrags.

## How it works

`engine/world/traversal.jac`: `Traversal` nodes (linked from the world by
`HasTraversal`) point to `Destination` nodes by `ArrivesAt` edges, or to a Q1
`misc_teleporttrain` by `FollowsTrain`. `TraversalTick` runs for the player
after walking and touch triggers each 120 Hz tick; `TeleportMonsters` runs
for monsters. Contact is a swept box test against the trigger's brush volume,
so a fast body cannot skip a thin trigger between ticks; crouching shortens
the tested box.

Teleporters:

- Q1 `trigger_teleport` to `info_teleport_destination` (arrival 27 units up,
  300 units a second along the view); Q3 `trigger_teleport` to
  `target_position`, `misc_teleporter_dest` or `info_notnull` (1 unit up, 400
  along the view); Q2 `misc_teleporter` pads to `misc_teleporter_dest` (10 up,
  velocity cleared, a 160 ms hold as `pm_time` does). Position, view and
  velocity change together.
- A destination inside solid rejects the teleport. Arrival telefrags whoever
  stands there (Q1 `spawn_tdeath`, Q2 `KillBox`, Q3 `G_KillBox`), through
  armour and invulnerability, credited to the arriving player; Q3 telefrags
  only players and bots.
- Q1 teleporters take monsters unless `PLAYER_ONLY` (closet teleport-ins); a
  named Q1 teleporter works only for 0.2 s after it is used (`teleport_use`,
  `force_retouch`). A monster arriving on the player dies itself. Q2
  teleporters and Q3 ones take players only.
- Q1 `misc_teleporttrain` (the end map) carries the player to the train's
  spot and telefrags what is there.
- Sounds and effects: Q1 one of `misc/r_tele1-5` at the destination
  (`play_teleport`) and `R_TeleportSplash`; Q2 `misc/tele1.wav` and
  `CL_TeleportParticles`; Q3 `world/teleout.wav` and `world/telein.wav`. Q1
  teleporters hum `ambience/hum1.wav` unless SILENT, and Q2 pads show the
  `dmspot` model, its `EF_TELEPORTER` particles and the `world/amb10.wav` loop
  (`games/fixtures.jac`, `engine/world/particle_field.jac`).

Pushes:

- Q1/Q2 `trigger_push`: `speed * 10` along the trigger's angle (default 1000),
  `PUSH_ONCE` honoured; they launch monsters and Q1/Q2 grenades too, and play
  windfly at most every 1.5 s.
- Q3 `trigger_push` aims at its target as `AimAtTarget` does: from the brush
  model's centre to the target's apex under 800 gravity. `world/jumppad.wav`
  and the jump grunt play once per contact (`BG_TouchJumpPad`).
- `trigger_monsterjump` is in [map mechanics](map-mechanics-status.md).

## Validation

- `tests/traversal_tests.jac`: swept contact, blocked exits, pause/fly/cooldown,
  one-shot pushes, the Q3 apex, invalid destinations, Q2 pad volumes, arrival
  disc and hold.
- `tests/telefrag_tests.jac`, `tests/crouch_tests.jac` (crouched arrival),
  `tests/speaker_tests.jac` (teleporter hums), `tests/map_mechanics_tests.jac`
  (named Q1 teleporters), `tests/campaign_flow_tests.jac` (gated monster
  teleports, pushes on monsters).
- `scripts/validate_traversal.jac` (`QP_GAME=q1|q2|q3`): every traversal
  contact on the sampled maps, safe destinations and launch velocities.
  `scripts/traversal_smoke.jac` teleports and launches through the app loop
  (e1m2, jail1, q3dm6, q3dm7, base3). `scripts/campaign_flow_smoke.jac` checks
  the e1m3 closet teleport-ins.

## Limitations

- After a teleport the player cannot trigger another for 0.2 s. This is the
  engine's own guard, not an original rule.
- Q1 `teleport_time` (no backward movement for 0.7 s after a teleport) and
  Q3's 160 ms `PMF_TIME_KNOCKBACK` from `TeleportPlayer` are not applied.
- Q3's teleport effect (`CG_SpawnEffect`, the `teleportEffect` model and
  shader) is drawn as a spark spray.
- Some shipped teleporters cannot work in the originals either and stay
  inactive: one each in Q1 e4m5, e4m8 and start targets an `info_null`; Q2
  city1 and cool1 have a pad whose destination only spawns in deathmatch.
