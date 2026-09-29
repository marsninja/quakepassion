# Q3 arena matches and the single-player ladder

Q3 levels run as local free-for-all matches from the original ladder data,
with Q3's scoring, announcer, scoreboard, podium, postgame awards and music.
An `ArenaMatch` node links each competitor, human or bot, through a
`Competes` edge carrying its name, frags, deaths and award counts. Spawn
points are `SpawnPoint` nodes. The `MatchTick`, `ChooseSpawn` and
`RankScores` walkers (`engine/world/arena.jac`) credit frags, announce,
choose spawns and rank.

Bot behaviour is in [Q3 bot tactics](bot-tactics-status.md); bodies and the
podium figures' rigs are in [Q3 player bodies](player-bodies-status.md).

## Match setup (`games/arenas.jac`, `games/opponents.jac`)

- `scripts/arenas.txt` gives each arena's bots, frag limit and long name;
  `scripts/bots.txt` maps each bot to its model and skin (Hossman is
  `biker/hossman`). A map outside the ladder gets Sarge, Grunt and Major and a
  20-frag limit.
- `prepare_arena` turns `info_player_deathmatch` entities into `SpawnPoint`
  nodes, builds the bots' AAS routes and level items, and starts a 4 s warmup.
- The level menu lists Q3's ladder first (training, tiers, final) with arena
  names and the best finish from `~/.quakepassion-arena.txt`.

## Rules

- Warmup: *Prepare to fight*, three, two, one and *Fight!*; nobody scores
  before it ends. Bots start seeking at FIGHT!.
- Spawns (`SelectRandomFurthestSpawnPoint`): a random pick among the furthest
  half of the spawn points from other competitors, skipping occupied spots
  (`SpotWouldTelefrag`). `ClientSpawn`'s `G_KillBox` telefrags anyone still on
  the spot. Competitors spawn with 125 health, which decays to 100.
- Scoring (`g_combat.c`): every death records its killer. A frag credits the
  killer; suicides and world deaths cost the victim a frag. The match ends at
  the frag limit.
- Announcer (`CG_CheckLocalSounds`, `CG_Obituary`): lead taken, tied and lost,
  the last three frags, "You fragged X / Tied for 2nd place with 4", then
  *You win* or `<bot>_wins`.
- Awards on the `Competes` edge: Excellent (two frags within 3 s), Impressive
  (two railgun hits in a row), Humiliation (a gauntlet frag) and Perfect (a
  win without dying), each with its announcer sound.
- The player respawns with fire or jump after 1.7 s, and automatically after
  20 s (`g_forcerespawn`), with the standard loadout.
- Saves keep the match clock, warmup, lead state and every competitor's frags
  and deaths (`MATCH`, `SCORE`), and each bot's weapon, ammo and holdables
  (`BOTARM`, `BOTITEM`).

## Items (`engine/world/drops.jac`, `engine/world/pickups.jac`)

- Drops (`TossClientItems`, `Drop_Item`): a dying player or bot throws its
  held weapon (not the gauntlet or machine gun, and only with ammo left) and
  every powerup it carried, with the time left on it. Items fly under gravity
  (`G_RunItem`, no bounce), never respawn, and vanish after 30 s. Dropped
  items are not saved.
- Item teams (`G_FindTeams`, `RespawnItem`): items sharing a `team` key show
  one member at a time and respawn a random one. Saves keep which member is
  out.
- The `random` key spreads each respawn by up to that many seconds either way,
  never under one second.

## Scoreboard (`engine/render/arena_screens.jac`)

`CG_DrawOldScoreboard` in Q3's own art, shown with the scores key (Tab,
`+scores`), during the warmup and while dead:
- "Fragged by" the killer while dead, and the player's place.
- The score, time and name tabs (`menu/tab`), and a line per competitor,
  highest first: bot skill mark (`menu/art/skill1-5`), head (the 3D head
  model with `headoffset` under `cg_draw3dIcons`, else `icon_<skin>`), score,
  minutes and name, the player's own line highlighted by rank.
- No ping column; each line lists that competitor's excellent, impressive and
  gauntlet awards instead.
- Ranks come from `RankScores` (`CalculateRanks`: by how many score higher,
  ties marked).

## Podium and intermission (`engine/world/podium.jac`)

When a match ends (`g_arenas.c`):
- The view moves to `info_player_intermission`, aimed at its target. As
  `BeginIntermission` does, the dead are respawned first, so the camera keeps
  no death roll.
- The podium model (`models/mapobjects/podium/podium4.md3`) stands 80 units
  ahead of the view and 70 below, turned toward it
  (`SpawnModelsOnVictoryPads`). The top three finishers' stand-ins take the
  pads at the original offsets, each holding the weapon it held (a machine gun
  if none).
- Two seconds later the winner plays its torso gesture and taunt
  (`CelebrateStart`), and stands again when the gesture timer runs out
  (`CelebrateStop`).
- Bots stay put, their talk balloons down; their end-of-level lines show in
  the notify lines (`Con_DrawNotify` during `PM_INTERMISSION`).

## Postgame (`q3_ui/ui_sppostgame.c`)

1. The top three names stand over their pads in the proportional font
   (`menu/art/font1_prop`) for five seconds.
2. Each award takes the stage for two seconds with its medal (`menu/medals`)
   and announcer line; the awards phase lasts at least five seconds.
3. Earned medals stay along the top with counts; Menu, Replay and Next appear.

- With more than three players, score lines roll along the top right every
  1.5 s.
- Keys are ignored for 1.5 s; then any key skips the podium, then the awards.
  Left/Right choose a button and Enter presses it: Next (a winner's default)
  loads the next ladder arena, Replay (otherwise the default) restarts, Menu
  opens the level menu.
- The status bar, view weapon and frag line are hidden.
- Awards (`UI_SPPostgameMenu_f`): accuracy of 50% or better (counted as
  `FireWeapon` and `LogAccuracyHit` count: every shot but the gauntlet's, one
  hit per shot that strikes a living opponent, one each for a missile's direct
  hit and its splash), impressives, excellents, gauntlet frags, a frags medal
  each time the career total passes another hundred, and Perfect (first place
  alone without a death). Totals persist across matches in
  `~/.quakepassion-awards.txt` (`UI_LogAwardData`). Accuracy is not saved in
  snapshots.

## Music (`engine/audio/streams.jac`)

- In-level music: worldspawn `music` gives the intro track and an optional
  loop track (`CG_StartMusic`); Q1 and Q2 take a CD track from worldspawn
  `sounds`, played from `music/trackNN`.
- `music/win` or `music/loss` plays once when the podium starts.

## Validation

- `tests/arena_match_tests.jac`: ladder order and model paths, frag credit and
  world deaths, frags-left and bot-win cues, warmup, spawn selection, bot
  damage credit, target choice, joining and saves, awards, ranking, postgame
  medals, phases and buttons.
- `tests/podium_tests.jac`: placement facing the intermission view.
- `tests/item_drop_tests.jac`: item teams, respawn spread, drops, powerup
  shaders.
- `tests/telefrag_tests.jac`: Q3 telefrags and occupied spawns.
- `tests/cinematic_tests.jac`: worldspawn music and CD tracks.
- `scripts/arena_match_smoke.jac`: ladder rosters, models, spawns and a
  simulated bot match.
- `scripts/arena_screens_smoke.jac`: captures the scoreboard and the three
  postgame phases on q3dm7.
- `scripts/arena_ladder_walkthrough.jac`: plays each ladder arena through the
  real game loop, then gives the player the frag limit and checks the podium,
  postgame and the next arena (`QP_SECONDS`, `QP_LADDER_ONLY`).

## Limitations

- Only free-for-all: no tournament rules (`GT_TOURNAMENT`), team modes or CTF.
- The original single-player arenas set no time limit, and none is
  implemented.
