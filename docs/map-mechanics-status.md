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
  requires. Monsters use them too (closet teleport-ins); see
  [level flow](level-flow-status.md). Q1 `info_player_start2` is used on the
  start map once a rune is held.
- Q2 `target_crosslevel_trigger` records unit flags. `target_crosslevel_target`
  fires on level entry once all its flags are set. The flags clear when a new
  unit starts.
- Activation chains are now resolved once, after every activatable entity is
  loaded, so chains that end at shooters, targets, movers or teleporters no longer
  disable themselves.
- `trigger_monsterjump` launches grounded walking monsters at `speed`/`height`.
- Q2 `func_areaportal`s open and close with their doors and relays; they
  gate hearing (see [monster behaviour](monster-behaviour-status.md)), not
  rendering.
- Recipients whose use does nothing here (`info_null`,
  `info_notnull`, `target_position`, `point_combat`, path corners and teleport
  destinations) accept uses as no-ops, so chains through them stay enabled.
  Switchable Q1/Q2 lights keep a saved on/off state; rendering the switched light
  style belongs to the presentation milestone.
- Q3 `target_give` hands its targeted items straight to the player,
  `target_remove_powerups` strips timed powerups (used by death pits) and
  `target_print` shows its message.

On the original maps, nearly every activation chain now resolves (Q1 e2m6 268 of
268 signals, Q2 jail4 433 of 436, Q2 security 647 of 649; previously 247/257,
378/411 and 462/576). Q2 jail4 enables 44 mover groups instead of 24.
`scripts/mechanics_smoke.jac` checks rotating doors, movers, shooters, lasers and
fixtures on Q1 e2m6/e1m6, Q2 jail4/security and Q3 q3dm19/q3dm15, with captures.

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

## Q2 entities from the loose-ends pass

- `func_water` moves like a door, and its liquid volume moves with its brush, so
  pools fill and drain.
- `func_killbox`, when used, telefrags everything inside its box, the player
  included.
- `func_object` brushes drop under gravity shortly after spawning, or appear and
  drop when used if flagged `TRIGGER_SPAWN`. They land on the first floor below
  them and crush what they fall on for `dmg` (100 by default).
- `func_clock` counts up or down each second. It writes its time into a
  `target_string`, which switches the texture frames of its team of
  `target_character` brushes. A finished timer fires its `pathtarget` and
  restarts if flagged `MULTI_USE`.
- `target_lightramp` ramps a light style between two letters over `speed`
  seconds (a `Ramps` edge to the light).
- `misc_viper` and `misc_strogg_ship` appear when used and fly their
  `path_corner` chain at 300 units a second, firing each corner's `pathtarget`.
  `misc_viper_bomb` falls with the viper's velocity and bursts on impact.
- `turret_breach`, `turret_base` and `turret_driver` (jail1, strike;
  `engine/world/turrets.jac`):
  - The driver is an infantry soldier riding behind the gun (a `Mans` edge). It
    spots the player as a monster would and aims the breach at their eyes.
  - The breach turns at most `speed` degrees a second on each axis, within its
    pitch limits (30° up and down by default) and yaw limits. The base turns with
    it in yaw.
  - Once the reaction time has passed (3 − skill seconds from sighting), the
    breach fires a 100–150 damage rocket at 550 + 50 × skill units a second from
    its muzzle point, then waits a second longer before firing again.
  - The driver moves with the gun, rising as the gun tilts down, snapped to
    eighths as `turret_breach_think` does. When it dies, the gun levels off and
    stays idle.
- `trigger_multiple` and `trigger_once` flagged `MONSTER` also fire for monsters
  standing in them, and `NOT_PLAYER` ones ignore the player. fact2 uses both,
  one of them for a crusher door only monsters trip.
- Texture animation follows `R_TextureAnimation` for Q1 and texinfo `nexttexture`
  chains for Q2, and buttons show their pressed frames.
- `scripts/turret_smoke.jac` shows each turret swinging toward the player and
  firing on jail1 and strike. `tests/turret_tests.jac`, `tests/clock_tests.jac`,
  `tests/loose_ends_tests.jac` and `tests/trail_tests.jac` cover the rest.

## Limits

Rotating-mover collision uses Q2's approximation, which keeps the player's box
unrotated. Pushing actors along a rotation checks their destination, not the
swept arc. A turning turret does not push or crush what it swings into
(`turret_blocked`), and a save does not keep a turret's current aim.
`target_actor` is not implemented: the only one in the shipped maps (biggun) has
no `misc_actor` to drive. Q3 portal surfaces are not rendered.
