# Campaign level flow

The Quake and Quake II campaigns play from their first map to their endings:
exits load as the originals' do, intermissions and unit summaries show, what
the player carries follows each game's rules, Q2 units remember their levels,
Q2 films play between them, and saves keep the whole session. Q1's runes open
the start map's gates.

## Exits

`engine/world/exits.jac` and `engine/core/impl/app.impl.jac`:

- Every `trigger_changelevel` and `target_changelevel` loads. Q1
  `changelevel_touch` runs `SUB_UseTargets` before the change (e1m7's exit
  fires relay `t18`). Q2 `use_target_changelevel` ignores the exit's own
  `target`, `killtarget`, `delay` and spawnflags. A map request of the form
  `name.cin+next` plays `video/name.cin` first (`SV_Map`), and a `.pcx`
  destination shows a still.
- **Q1 intermission** (`execute_changelevel`, `IntermissionThink`): a normal
  exit moves the view to a random `info_intermission` and shows
  `Sbar_IntermissionOverlay` (the `complete.lmp` and `inter.lmp` plaques, time,
  secrets and kills in the big digits). A key continues after 2 s; an
  episode's end shows its text. `NO_INTERMISSION` exits (the start map's)
  change level at once. The scoreboard and plaque show the server clock, which
  starts at 1.2 s (`SV_SpawnServer`).
- **Q1 end**: `engine/world/finale.jac` runs the end map's spiked
  `misc_teleporttrain`, the telefrag into Shub-Niggurath, the finale timeline
  and its cameras and texts.
- **Q2 units**: an exit to a new unit (`*`) pauses at
  `info_player_intermission` with a unit summary (kills, goals, secrets), then
  plays the unit's closing film (`eou1_.cin` to `eou8_.cin`). Other Q2 exits
  change level at once, as `BeginIntermission` does in single player. boss2's
  exit plays `end.cin` and shows `victory.pcx` until a key, then the menu.
- **Monster tally**: counted on entry, including closet, trigger-spawned and
  boss monsters (Chthon and Shub-Niggurath add to `total_monsters`), but not
  Q2's `AI_GOOD_GUY` `misc_insane` marines. F1 in Q1 shows
  `Sbar_SoloScoreboard` (as does death); in Q2 it toggles the help computer
  (see [presentation](presentation-status.md)).

## What carries between levels

- Q1 `SetChangeParms`: keys are dropped, health is clamped to 50-100 and at
  least 25 shells carry. `DecodeLevelParms` resets the loadout on return to
  start with a rune held; the runes stay.
- Q2: health, armor and inventory carry. Keys carry between units in single
  player (only coop strips them). A new unit clears the hub and the
  cross-level trigger flags (`target_crosslevel_trigger`).
- Q2 hubs (`engine/core/campaign.jac`): each visited level of the unit is kept
  as a snapshot in a `MapState` node linked to the `Campaign` by `Visited`
  edges (`Remember`/`Recall` walkers). Returning restores its items, monsters,
  movers, triggers, signals and its own clock (`level.time`); the player
  arrives at the destination's authored spot.
- The Q2 help computer (`HelpComputer` in `engine/world/targets.jac`) belongs
  to the game, not the level: its objectives (`game.helpmessage1/2`), news
  count and unread reminders carry from level to level and across units, and
  are saved. News beeps `misc/pc_up.wav` and blinks the status-bar icon; the
  reminder repeats every 6.4 s, three times.
- A failed load leaves the current level and hub intact. Choosing a map from
  the menu starts a fresh session.

## Death restart and saves

- Each level entry takes an autosave (a campaign envelope with a snapshot).
  Dying and pressing Enter reloads it, as Q1's `restart` with the entry parms
  and Q2's entry autosave do: the inventory, keys, unit flags and help
  computer as they entered, with the Q2 hub as it was.
- The `save`/`load` commands (quick save when unnamed) write
  `~/.quakepassion-save.txt` or `~/.quakepassion-save-<name>.txt`: a
  `QUAKEPASSION CAMPAIGN 1` envelope holding the active snapshot and the Q2
  hub's visited snapshots. Snapshots carry the header in
  `engine/core/save_format.jac` (currently `QUAKEPASSION 22`); a snapshot with
  another header is rejected, since positional entity records change between
  formats. Saving needs a living player in walk mode.

## Q1 runes and gates

- The four sigils (`item_sigil`, `progs/end1.mdl` to `end4.mdl`) add their
  rune bits to the inventory, fire their targets and say "You got the rune!"
  with `misc/runekey.wav`. The status bar shows the held sigils (`sb_sigil`).
- `engine/world/gates.jac`: `CampaignGate` nodes for the start map's
  `func_episodegate` (solid and visible once its episode is done) and
  `func_bossgate` (solid until all four runes are held). `ApplyGates` sets
  faces and collision from the inventory on load and after a restore.
- With a rune held, the start map uses `info_player_start2`
  (`SelectSpawnPoint`).

## Films and music

- **Q2 films** (`engine/formats/q2/cin.jac`, `engine/core/cinematic.jac`):
  `.cin` files are read as `client/cl_cin.c` does (the header, the 256
  order-1 Huffman trees of `Huff1TableInit`, then each frame's palette,
  `Huff1Decompress`ed picture and sound). The film runs on the real clock at
  14 frames a second, one frame ahead as `SCR_RunCinematic` reads, stretched
  over the window; the menu pauses and blanks it. Any key finishes it after its
  first second (`BUTTON_ANY`). A missing film goes straight on. New Q2 games
  (`QP_GAME=q2` without `QP_MAP`) start with `ntro.cin`. Films are loose files
  in `baseq2/video/`; Q1/Q2 loose files are searched after the paks
  (`FS_FOpenFile`).
- Film sound goes through `RawStream` (`engine/audio/streams.jac`,
  `S_RawSamples`).
- **Q3 music**: `CG_StartMusic` reads worldspawn `music` (an intro and an
  optional loop track); `BackgroundTrack` streams the intro and goes on to the
  loop with no gap (`S_UpdateBackgroundTrack`). The postgame plays `music/win`
  or `music/loss` once. The level is `s_musicvolume` (0.25).
- **Q1/Q2 CD music**: worldspawn `sounds` names the track (`svc_cdtrack`,
  `CS_CDTRACK`); Q1 plays track 3 over the intermission and track 2 under an
  episode's closing text. A `music/trackNN.ogg` or `.wav` file stands in for
  the disc; without one the levels are silent, as without a CD.

## Chain audit

`scripts/chain_audit.jac` loads every Q1 and Q2 map without rendering and
reports exits loaded against the entity lump's changelevels, movers, touch
triggers, teleporters and trains that did not load (and why), signals left
disabled, and targeted entities with no activation. `QP_AUDIT_MAPS=e1m7,jail1`
narrows the run; `QP_AUDIT_VERBOSE=0` hides per-entity lines.

Totals on 2026-09-24:

| | Q1 | Q2 |
|---|---|---|
| Exits | 46/46 | 85/85 |
| Movers | 1044/1044 | 1226/1226 |
| Touch triggers | 627/627 | 785/785 |
| Teleporters | 295/298 | |
| Trains | 39/39 | 195/195 |
| Disabled signals | 0 | 0 |
| Targeted entities with no activation | 0 | 0 |

The audit's mover count covers `func_door`, `func_button`, `func_plat`, Q2
`func_door_rotating` and `func_water`; it does not count Q2
`func_door_secret` (see [doors](doors-status.md)). The three Q1 teleporters
that do not load target an `info_null`, which removes itself, so the originals
cannot use them either ([traversal](traversal-status.md)).

## Validation

- Tests: `tests/campaign_flow_tests.jac` (chains skipping targets with no use,
  Q2 exits with targets/delays/flags, Q1 exits and NO_INTERMISSION,
  `trigger_elevator`, gated monster teleports, killtargeted walls, door
  messages, key wording, mover sounds, `trigger_key`), `tests/campaign_tests.jac`,
  `tests/exit_tests.jac`, `tests/finale_tests.jac`, `tests/rune_tests.jac`,
  `tests/savegame_tests.jac`, `tests/savegame_tags_tests.jac`,
  `tests/cinematic_tests.jac`, `tests/level_teardown_tests.jac`.
- `scripts/campaign_walkthrough.jac` follows every Q1 and Q2 campaign exit
  through the real game loop.
- `scripts/campaign_flow_smoke.jac`: e1m7's exit, jail1/base2/boss1 exits,
  the lab and mine2 elevators, and e1m3's closet teleport-ins on hard skill.
- `scripts/level_flow_smoke.jac` (captures in `.jac/screenshots/flow/`): the
  Q1 scoreboard, e1m7's plaque then episode text then start, Q1 and Q2 death
  restarts that keep the entry inventory, the Q2 help computer, and a Q2 unit
  exit that keeps keys and clears unit flags.
- `scripts/campaign_smoke.jac` (Q1 key gates, Q2 hub revisits and saves),
  `scripts/exits_smoke.jac` (transitions and failed-load rollback),
  `scripts/persistence_smoke.jac`, `scripts/validate_gameplay.jac`,
  `scripts/validate_exits.jac`, `scripts/finale_smoke.jac`,
  `scripts/rune_smoke.jac` (each sigil in e1m7, e2m6, e3m6 and e4m7, then the
  five gates in start and a save round-trip), `scripts/chain_audit.jac`.

## Limitations

- The Q2 unit summary is drawn in the help computer's frame; single-player Q2
  shows only the intermission view.
- Q3's RoQ cinematics (`video/intro.RoQ`, the tier films) are not played.
- The help computer's reminder beeps count from when the news arrives rather
  than from the next `level.framenum & 63`.
