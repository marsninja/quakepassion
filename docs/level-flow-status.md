# Campaign level flow

This milestone makes the Quake and Quake II campaigns completable from start to
finish and makes moving between levels behave like the originals.

## Activation chains

- **Targets without a use are skipped.** Q1 `SUB_UseTargets` and Q2
  `G_UseTargets` only call a recipient's `use` when it has one; the rest of
  the chain still fires. Before, `connect_targets` switched off any signal that
  had an unsupported recipient, and that switch-off spread up the chain. Now an
  unsupported recipient only gets a `ChainNote` saying why it was skipped.
- `worldspawn`, `misc_explobox` and `trigger_monsterjump` take uses as no-ops,
  as they have no `use` in the originals. The same goes for the passive markers
  listed in [map mechanics](map-mechanics-status.md).
- Plain walls now have a signal of their own: every named Q1 `func_wall`, and Q2
  walls without TRIGGER_SPAWN, TOGGLE or START_ON. This lets a `killtarget`
  remove them (base2 `block`, city2 `pylon`, cool1 `prevent`, the Q1 start
  map's registered-only wall). Q1 `func_wall_use` switches the wall to its
  alternate textures.
- Every `trigger_hurt` can now be killtargeted (space `killme1`/`killme2`,
  boss1, power2). Only TOGGLE hurts respond to a use.
- `target_temp_entity` shows its client effect when used. TE_BOSSTPORT (style
  22) gets a larger burst and `misc/bigtele.wav`, as on the boss1 exit.
- `misc_blackhole` disappears when used (`misc_blackhole_use`), as command's
  exit force field does. `misc_satellite_dish` plays its 38 frames once
  (base3).
- Q1 `misc_teleporttrain` waits for its first use when it has a targetname
  (`func_train_find`), as in end.bsp.
- Q1 and Q2 touch triggers no longer drop spawnflag bits that the originals
  never read (command's `wheel2` trigger).

## Exits

- Every `trigger_changelevel` and `target_changelevel` loads.
  - Q1 `changelevel_touch` runs `SUB_UseTargets` before the level changes. This
    fixes e1m7's exit, which targets relay `t18`; without it, episode 1 could
    not be finished.
  - Q2 `use_target_changelevel` ignores the exit's own `target`, `killtarget`,
    `delay` and spawnflags. Before, these kept the exits of base2, jail1, mine3,
    power2, city3 (two), jail2 and jail3 from loading, including the ends of
    units 1, 4 and 6 and jail1's only exit.
- Q2 `trigger_elevator` (lab ×3, mine2): a use from a caller that has a
  `pathtarget` sends the idle `func_train` straight to that path corner. This
  follows `trigger_elevator_use` and `train_resume`. The caller's pathtarget
  goes along the `Targets` edge to the elevator's signal. A train that is busy
  moving or waiting ignores the call.

## Movers

- Q2 func_door ANIMATED (16) and ANIMATED_FAST (64) only animate the door's
  textures, so these doors now move. This covers the key doors in base3,
  jail4, power1, power2, lab and command. Q2 func_door's unused bit 2 is
  accepted, and so is spawnflag 1 on Q1 buttons.
- Doors, buttons and plats that have `killtarget`, `accel` or `decel` now load.
  Their killtarget is a `Kills` edge that fires with their targets.
  Acceleration (`Think_AccelMove`) is simplified to the constant `speed`.
- A mover whose lip is as large as its size, or larger, still runs its cycle
  and fires its targets. Before, such movers stayed static, including space's
  arm buttons and many other Q2 buttons. Negative `distance` values reverse a
  rotating door. A member that has no clip
  hull still moves on screen (mine4's gears).
- Shootable Q2 rotating doors load.

## Monsters in teleporters and pushes

`TeleportMonsters` in `engine/world/traversal.jac` walks the level's
teleporters and pushes for the level's monsters:

- Q1 `teleport_touch` takes any living monster unless the teleporter is
  PLAYER_ONLY. A named teleporter only works for 0.2 s after it is used
  (`teleport_use`, whose `force_retouch` catches monsters already waiting
  inside).
- A monster touches a trigger's bounding box, as in `SV_TouchLinks`. The box
  has a one-unit margin, and the monster's own size counts. The box is swept
  from where the previous check left it, so a leaping or charging monster
  cannot pass through a thin trigger between ticks; a monster placed more than
  256 units away (a respawn, another teleport) is tested where it stands.
- On arrival the monster faces the destination's angle and keeps its alert
  state. A tfog sound (`misc/r_tele1-5`) plays at the destination, with a
  flash of sparks.
- `spawn_tdeath`: a monster that arrives on top of the player dies itself. Any
  other monster standing there is telefragged.
- `trigger_push` launches monsters and Q1/Q2 grenades as well as players
  (`trigger_push_touch`).
- A teleporter's `delay` only delays its own targets, so e2m7's `t117` now
  loads.

This unblocks the closet monsters that wait in named Q1 teleporters, and the
death chains that go through them. In e1m3, the closet fiends feed counter
`t175`, which teleports in a shambler.

## Level flow

- **Q1 intermission** (`execute_changelevel`, `IntermissionThink`): a normal
  exit moves the view to a random `info_intermission` and shows
  `Sbar_IntermissionOverlay`. That is the `complete.lmp` and `inter.lmp`
  plaques, with the time, secrets and kills in the big status-bar digits. A key
  (fire, jump, Enter) continues once 2 s have passed. At the end of an episode,
  the episode text follows. `NO_INTERMISSION` exits (the start map's) change
  level at once.
- **Q2 units**: an exit to a new unit (`*`) pauses at `info_player_intermission`
  with a unit summary (kills, goals and secrets). Other Q2 exits change level
  at once, as `BeginIntermission` does in single player.
- **Monster tally**: the level's monsters are counted on entry, including
  closet and trigger-spawned monsters and Q1's Chthon and Shub-Niggurath (whose
  QuakeC spawns add them to `total_monsters`), but not Q2's AI_GOOD_GUY
  `misc_insane` marines, which neither count nor add a kill when they die.
  Holding F1 in Q1 shows `Sbar_SoloScoreboard` (monsters, secrets, time, level
  name) in place of the status bar, and so does death. F1 now toggles the Q2
  help computer, which shows skill, level name, objectives and
  kills/goals/secrets, as `HelpComputer` does.
- **Death restart**: each level entry takes an autosave (the campaign envelope
  with a snapshot). Dying and pressing Enter reloads it. This works like Q1's
  `restart` with the level-entry parms and Q2's entry autosave. Before, a death
  restart gave the player a fresh starting loadout, and in Q2 lost keys, power
  cubes and unit flags.
- **Carry rules**:
  - Q1 `SetChangeParms` drops keys and gives at least 25 shells.
  - Q1 `DecodeLevelParms` resets the loadout when you return to start with a
    rune held; the runes stay.
  - Q2 keeps keys between units in single player (only coop strips them).
    A new unit still clears the cross-level trigger flags.

## Messages and sounds

- Door messages ("This door opens elsewhere...", "You must press the three
  buttons...") show when the player touches the door, until its first use. Q1
  `door_touch` does this for any door's message, every 2 s, with
  `misc/talk.wav`. Q2 `door_touch` does it for named doors that can't be shot,
  every 5 s, with `misc/talk1.wav`. Q1 secret doors do the same
  (`secret_touch`: "Shoot this secret door...").
- A button's message is printed when the button fires. Q1 messages without a
  `noise` play `misc/talk.wav`.
- Q1 key doors say "You need the silver key/runekey/keycard" depending on
  `worldtype`, and play `med/rune/base` `try` and `use` sounds.
- Q2 `trigger_key` says "You need the Data CD" (the item's pickup name) with
  `misc/keytry.wav` at most every 5 s, and plays `misc/keyuse.wav` when the key
  is used.
- Doors, plats, buttons, trains, func_water and Q1 secret doors play their
  start, moving and stop sounds as positional speakers:
  - Q1: the `sounds` tables in doors.qc, plats.qc, buttons.qc and func_train.
    The moving sound loops by its cue point until the stop sound replaces it.
  - Q2: `dr1_*`, `pt1_*` and `butn2` unless `sounds` is 1, a train's `noise`
    loop, and func_water's `mov_watr`/`stp_watr`.
- Teleport sounds and flashes:
  - Q1: `misc/r_tele1-5` at the destination.
  - Q2: `misc/tele1.wav`.
  - Q3: `world/teleout.wav` and `world/telein.wav`.
  - A spark flash appears at every destination.
- Q3 jump pads play `world/jumppad.wav` and the jump grunt once per contact.
  Q1/Q2 pushes play windfly at most every 1.5 s.

## Chain audit

`scripts/chain_audit.jac` loads every Q1 and Q2 map without rendering. For
each map it reports:

- exits loaded against changelevels in the entity lump
- movers, touch triggers, teleporters and trains that did not load, and why
- signals left disabled
- targeted entities that have no activation

`QP_AUDIT_MAPS=e1m7,jail1` narrows the run, and `QP_AUDIT_VERBOSE=0` hides the
per-entity lines. A full run takes about a minute.

| | before (main) | after |
|---|---|---|
| Q1 exits | 45/46 (e1m7 missing) | 46/46 |
| Q1 movers | 1036/1044 | 1044/1044 |
| Q1 touch triggers | 624/627 | 627/627 |
| Q1 teleporters | 294/298 | 295/298 |
| Q1 disabled signals | 5 | 0 |
| Q2 exits | 77/85 | 85/85 |
| Q2 movers | 1105/1226 | 1226/1226 |
| Q2 touch triggers | 742/785 | 785/785 |
| Q2 trains | not counted | 195/195 (Q1 39/39) |
| Q2 disabled signals | 120 | 0 |
| targeted entities with no activation | Q1 4, Q2 123 | 0 |

The remaining teleporters are ones the originals can't use either:

- Q1 e4m5, e4m8 and start have one teleporter each that targets an
  `info_null`. `info_null` removes itself, so `teleport_touch` finds no
  destination.
- Q2 city1 and cool1 each have a `misc_teleporter` whose destination only
  spawns in deathmatch.

## Validation

- `jac test tests/campaign_flow_tests.jac` covers:
  - chains skipping a target that has no use
  - Q2 exits with targets, delays and flags
  - Q1 exits firing their targets, and NO_INTERMISSION
  - trigger_elevator
  - gated monster teleports, including dying on the player
  - pushes on monsters, and teleporters that only take players
  - killtargeted plain walls
  - door touch messages, key wording and mover sounds
  - Q2 trigger_key wording and debounce
- `jac run scripts/campaign_flow_smoke.jac` runs on the original maps:
  - the e1m7 exit fires relay `t18` and asks for start
  - the exits of jail1, base2 (after its relay's 1 s delay) and boss1 (after
    arming and touching its TRIGGERED trigger) fire; boss1 also shows the
    teleport sparks
  - the elevators in lab (e2 → e1) and mine2 (p1 → p3, called by a button that
    used to be static) reach their called corners
  - on hard skill in e1m3, the closet fiends arrive at their destinations
    after the guards die, and the shambler teleports in after the closet
    fiends die
- `jac run scripts/level_flow_smoke.jac` goes through the real game loop and
  saves captures to `.jac/screenshots/flow/`:
  - the Q1 scoreboard
  - e1m7's intermission plaque, then the episode text, then start
  - Q1 and Q2 death restarts that keep the entry inventory, keys and unit
    flags
  - the Q2 help computer
  - a Q2 unit exit that keeps keys and clears unit flags
- `jac run scripts/chain_audit.jac` gives the totals above.

## Limits

- Q2 `accel`/`decel` ramps are approximated by the constant speed.
- Q2's help computer is a text panel, not the `help.pcx` art.
- The Q2 unit summary is a text panel. The single-player original shows only
  the intermission view.
- The Q1 intermission time is the level's simulation time.
