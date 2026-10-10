# Campaign level flow

The Quake and Quake II campaigns play from their first map to their endings:
exits load as the originals' do, intermissions and unit summaries show, what
the player carries follows each game's rules, Q2 units remember their levels,
Q2 films play between them, and saves keep the whole session. Q1's runes open
the start map's gates. Quake III's films play at start-up and as its ladder's
tiers are completed.

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
- **Q2 units**: an exit to a new unit (`*`) pauses at one of the first four
  `info_player_intermission` spots (a player start when the map has none),
  with the status bar up and nothing laid over the view. Any key leaves
  after five seconds (`ClientThink`), and the unit's closing film plays
  (`eou1_.cin` to `eou8_.cin`). Other Q2 exits
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
  are saved. Unread news blinks the status-bar icon and beeps
  `misc/pc_up.wav` three times, on the level's every 64th server frame.
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
  formats. Saving needs a living player in walk mode. Tagged records
  (`TURRET`, `PORTAL` for each area portal's toggle) may be missing from an
  older save of the same format; what they describe then stays as the level
  loads it.
- Items that are not the map's own are saved by tag: a Q2 item still
  falling (`FALL`), and what dying Q3 players dropped (`DROP`: the item, its
  place and remaining time, and its throw while in the air).

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

- **One player, two decoders.** `CinematicPlayer`
  (`engine/core/cinematic.jac`) shows every film, stretched over the window,
  and queues its sound through `RawStream` (`engine/audio/streams.jac`,
  `S_RawSamples`). A decoder is a `Film` (`engine/formats/film.jac`): it hands
  over one picture at a time and states the rules its game's client ran it
  by (frame rate, whether the screen trails the reader, when a key ends it,
  whether the last picture holds). A missing film goes straight on.
- **Q2 films** (`engine/formats/q2/cin.jac`): `.cin` files are read as
  `client/cl_cin.c` does (the header, the 256 order-1 Huffman trees of
  `Huff1TableInit`, then each frame's palette, `Huff1Decompress`ed picture
  and sound). The film runs on the real clock at 14 frames a second, one
  frame ahead as `SCR_RunCinematic` reads; a slow frame stretches it. The
  menu pauses and blanks it. Any key finishes it after its first second
  (`BUTTON_ANY`). New Q2 games (`QP_GAME=q2` without `QP_MAP`) start with
  `ntro.cin`. Films are loose files in `baseq2/video/`; Q1/Q2 loose files are
  searched after the paks (`FS_FOpenFile`).
- **Q3 films** (`engine/formats/q3/roq.jac`): RoQ files from the pk3s' `video/`
  are read as `code/client/cl_cin.c` does. Each chunk is copied to the front
  of one 65536-byte buffer with the next chunk's header and run from there
  (`RoQInterrupt`): codebooks of 2x2 cells (YUV to RGB through
  `ROQ_GenYUVTables`) and 4x4 cells, also kept pixel-doubled as 8x8
  (`decodeCodeBook`); pictures as the quad tree's two-bit codes (skip, move
  from the picture before, a cell, or split: `blitVQQuad32fs`), alternating
  between the two halves of one buffer; mono and stereo DPCM sound at 22050 Hz
  (`RllDecode*`). What the original reads past a chunk's end is read the same
  way (a codebook with argument 0, the header after the last chunk). A film
  runs at 30 pictures a second (`CIN_RunCinematic`), reading on until it has
  caught the clock up; any key, Escape included, ends it.
  - **Start-up** (`Com_Init`): `QP_GAME=q3` without `QP_MAP` or `+commands`
    plays `idlogo.RoQ`, and the first time (`com_introplayed`) goes on to
    `intro.RoQ` through `nextmap`, then into the arena.
  - **Postgame** (`UI_SPPostgameMenu_MenuDraw`): when the awards are over, a
    first place that completed something plays its film once (`g_spVideos`):
    `tier1.RoQ` after the training arena, `tier2.RoQ` to `tier7.RoQ` once
    all four arenas of tiers 1 to 6 are won (`UI_TierCompleted`), each
    followed by the level menu on the next arena (`levelselect`); the final
    arena plays `end.RoQ`, which holds its last picture until a key
    (`CIN_hold`), then the menu.
  - `cinematic <name>` plays any film from the console; `nextmap` holds the
    command a film runs when it ends (`RoQShutdown`).
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
  `tests/cinematic_tests.jac` (`.cin` and RoQ decoding against hand-built
  films and the originals' first pictures, the player's two timings, tier
  completion and film bookkeeping), `tests/level_teardown_tests.jac`.
- `scripts/cinematic_smoke.jac` plays every original film (ten RoQ, three
  `.cin`) to its end through the player and saves chosen pictures to
  `.jac/screenshots/films/`; with `QP_FILM_FLOW=1` it also runs the Q3
  start-up chain and a won training match's `tier1.RoQ` and `end.RoQ`
  through the game loop. All ten RoQ films are 512x256: `idlogo` 238
  pictures, `intro` 2695, `tier1` to `tier7` 366 each, `end` 1922
  (2026-10-09, about 0.5 ms a picture).
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

- A film's sound that falls behind after a long stall plays late; the
  originals drop what overflows `S_RawSamples`.
- Q3's postgame films close onto the level menu with the finished match
  still behind it, where the original has disconnected.
