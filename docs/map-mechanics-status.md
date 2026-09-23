# Map mechanics: rotating movers, triggers, traps, fixtures and targets

This milestone fills most of the gaps found by a census of every installed map's
entity classes. All new behavior uses the shared activation graph: each
activatable entity has a `Signal`, and walkers advance the entities.

## Rotating and periodic movers

- Collision hulls and faces can turn about their entity origin. As in Q2's
  `CM_TransformedBoxTrace`, traces move into the model's frame and the player box
  keeps its size; hit normals are turned back.
- Q2 `func_door_rotating` (96 in 25 maps) reuses the door state machine with
  the original `distance`, axis, reverse, start-open, toggle and crusher flags.
- Q2/Q3 `func_rotating`, Q3 `func_bobbing` and `func_pendulum` run as `Rotator`
  nodes. Their pose is a function of a saved clock: steady spin, `TR_SINE`
  bobbing, and a pendulum period derived from model length and gravity. They
  carry riders, push actors when there is room, and otherwise deal `dmg` while
  blocked. Q2 `TOUCH_PAIN` blades hurt on contact.
- Blocked doors and plats now deal their authored crush damage (Q1 plats 1,
  otherwise 2), at most ten times a second, and reverse. Crushers and doors with
  a negative wait keep pushing.

## Triggers and activation

- `trigger_once`, `trigger_multiple` and `trigger_onlyregistered` are relays of
  their own. Touch, use by `targetname`, and shooting all fire the same targets
  (Q1 `multi_trigger`, Q2 `Touch_Multi`).
- Newly supported: directional triggers (`angle`, facing test from
  `InitTrigger`), Q1 `NOTOUCH`, Q1 shootable triggers (`health`, solid until
  destroyed), Q2 `TRIGGERED` triggers that must be used before touching works, Q3
  `random` waits, and `trigger_setskill`.
- `killtarget` is a `Kills` edge. Firing the source retires each victim:
  triggers, relays, timers, doors, trains, walls, pickups, speakers, hazards,
  pushes, teleporters, shooters and lasers. A killtarget naming an entity without
  a graph identity is ignored instead of disabling the whole chain.
- Authored `message` text and activation sounds are shown and played (trigger
  `sounds`, Q2 `noise`/`misc/talk1`, secret cues). Counters use the original
  "Only 2 more to go..." and "Sequence completed!" wording.
- Named Q1 teleporters only work just after they are used, as `tele_touch`
  requires (used for monster teleport-ins). Q1 `info_player_start2` is used on the
  start map once a rune is held.
- Q2 `target_crosslevel_trigger` records unit flags. `target_crosslevel_target`
  fires on level entry once all its flags are set. The flags clear when a new
  unit starts.
- Activation chains are now resolved once, after every activatable entity is
  loaded, so chains that end at shooters, targets, movers or teleporters no longer
  disable themselves.
- `trigger_monsterjump` launches grounded walking monsters at `speed`/`height`.

## Traps, targets and destructibles

- Q1 `trap_spikeshooter`/`trap_shooter` (spikes 9, superspikes 18, lasers 15),
  `misc_fireball` lava balls (20), Q2 `target_blaster` and Q3 `shooter_*` launch
  world-owned projectiles. These hit players and monsters alike, with no kill credit.
- Q2 `target_explosion` (radius damage `dmg`, radius `dmg`+40),
  `target_splash`, `target_earthquake` (shoves grounded players for `count`
  seconds with the original quake sound), `target_laser` (toggled beams in their
  palette colours, damaging each frame) and `target_help`. **F1** shows the Q2
  help computer's objectives.
- Q2 `target_spawner` items and monsters appear when the spawner is used,
  including the `key_pass` used for progression.
- Q1 and Q2 exploding barrels (`misc_explobox`) take damage from any source and
  explode (Q1 160, Q2 150 radius damage). They do not count as kills.

## Fixtures and ambience

- Q1 torches and flames show their original animated models with their fire
  loops. Fluorescent lights and `ambient_*` entities play their static loops. Q2
  dead bodies, mine lights, banners and novelty models are placed and animated.
- Q1's automatic water and sky ambience follows the BSP leaf's ambient levels,
  ramping as `S_UpdateAmbientSounds` does.
- Looping emitters beyond their audible range hold no audio stream, so maps with
  hundreds of torches stay cheap. Sound files are decoded once per level.

Snapshot format **20** stores mover clocks, shooter timing and trap projectiles.

## Limits

Rotating-mover collision uses Q2's approximation, which keeps the player's box
unrotated. Pushing actors along a rotation checks their destination, not the
swept arc. Q2 `func_water`, `func_object`, `func_killbox`, `func_clock`,
`target_lightramp`, `target_character`, misc fly-by ships, turrets and monster
`point_combat` routes remain open; turrets and combat points belong with the
monster AI milestone. Q2 `MONSTER`-only triggers are not yet activated by
monsters. Q3 portal surfaces are not rendered.
